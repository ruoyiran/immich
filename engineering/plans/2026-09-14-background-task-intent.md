# 后台任务意图隔离 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 自动同步不创建 iOS 灵动岛持续任务，手动同步及上传保留持续执行能力，并及时报告真实进度。

**Architecture:** 共享后台服务显式携带 limited/continued 模式。iOS limited 仅申请 UIKit 时间；continued 才提交 BGContinuedProcessingTask。Android 两种模式均保留平台要求的 dataSync 前台服务，不降低既有后台能力。

**Tech Stack:** Dart/Flutter、Pigeon、Swift BackgroundTasks、Kotlin foreground service、Drift。

**Spec:** 本线程 2026-09-14 用户确认的自动/手动任务分离方案，具体边界见本文件“批准方案”。

## 批准方案

- 自动启动、回前台、WebSocket 触发的同步默认 limited；后台时间耗尽后保留断点，回前台继续。
- 设置页主动点击同步及手动上传使用 continued。点击同步时若自动同步正在执行，升级同一个原生任务，不取消健康请求。
- 系统取消仍按取消处理，不能改报成功；已有重试、退出登录和清理语义保持不变。
- 同步按数量上限或两秒时间窗口提交已有数据；空闲且没有数据时不制造进度。总量未知时使用不定总量进度，上传继续报告已知总量。
- 不修改服务器、数据库 schema、翻译 key；不提交、不创建分支、不卸载真机应用。保留当前未提交改动。

## Task 1: 显式后台模式与原生策略

**Files:** `mobile/pigeon/background_task_api.dart`、`mobile/lib/domain/services/background_task.service.dart`、`mobile/ios/Runner/Background/BackgroundTaskSession.swift`、`mobile/ios/Runner/Background/BackgroundTaskApiImpl.swift`、`mobile/android/app/src/main/kotlin/app/alextran/immich/background/BackgroundTaskPlugin.kt`、对应 service/mock/Swift 测试。

**Interfaces:** `BackgroundTaskMode { limited, continued }`；Pigeon `start(taskId, title, description, mode)`；服务 `run`/`execute` 默认 limited；`BackgroundTask.requestContinuedProcessing()` 原地升级。`execute` 的 `onTaskCreated` 回调交出已有任务句柄。

- [x] 添加并运行失败测试：默认模式、显式 continued、升级不重启 action、模式在过期恢复后保留。Swift 验证 limited 不提交 continuation、升级只提交一次、完成后不提交。

```dart
expect(host.modes, [BackgroundTaskMode.limited]);
await task.requestContinuedProcessing();
expect(host.modes, [BackgroundTaskMode.limited, BackgroundTaskMode.continued]);
expect(attempts, 1);
```

- [x] 实现参数传递和 native 分支，运行 `mise //mobile:codegen:pigeon` 生成 Dart/Swift/Kotlin；禁止手工编辑生成文件。
- [x] 运行 `mise //mobile:test test/domain/services/background_task_service_test.dart` 与 `swift test --package-path mobile/ios --filter BackgroundTaskCoreTests`。

## Task 2: 同步入口与手动升级

**Files:** `mobile/lib/domain/utils/background_sync.dart`、`mobile/lib/widgets/settings/beta_sync_settings/sync_status_and_actions.dart`、`mobile/lib/services/foreground_upload.service.dart`、`mobile/test/domain/utils/background_sync_test.dart`、上传测试。

**Interfaces:** `syncRemote({bool enqueue = false, bool userInitiated = false})`；手动入口传 true；上传传 continued。记录当前意图及后台句柄，原地升级及恢复重试沿用意图，排队的自动增量仍默认 limited。

- [x] 先写并运行默认自动、手动、运行中升级、保护启动尚未完成时升级、恢复重试保持 continued 的失败测试。

```dart
final automatic = manager.syncRemote();
final manual = manager.syncRemote(userInitiated: true);
expect(attempts, hasLength(1));
expect(host.modes.last, BackgroundTaskMode.continued);
```

- [x] 实现意图路由及所有取消/完成路径的句柄清理；手动操作不重置数据库或同步游标。
- [x] 运行 manager、lifecycle、upload 相关测试。

## Task 3: 有界批处理与真实进度

**Files:** `mobile/lib/infrastructure/repositories/sync_api.repository.dart`、manager 的进度调用、Swift session、Android manager 及相应测试。

**Interfaces:** `streamChanges(batchFlushInterval: Duration(seconds: 2))`；只 flush 完整 JSON 行，保留残片；`total = -1` 表示未知总量，双端保留实际 completed。

- [x] 添加失败测试：不足 5000 条但有完整行时在期限内提交；没有新数据不增加进度；残缺行、取消和重置保持原行为；未知总量不会显示接近 100% 的假精度。

```dart
await committed.future.timeout(const Duration(seconds: 1));
expect(batches.map((batch) => batch.length), [2, 1]);
expect(streamClosed, isFalse);
```

- [x] 实现串行数量/时间双阈值 flush，网络空闲事件只触发已有缓冲提交，不作为收到数据或实际工作计数。
- [x] 运行 sync repository、stream service、Swift session、Android manager 测试。

## Task 4: 验收与文档

**Files:** `mobile/integration_test/remote_sync_background_resume_test.dart`、`mobile/integration_test/background_transfer_continuation_test.dart`、`engineering/modules/mobile.md`。

- [x] 集成测试覆盖自动 limited、运行中手动升级、短后台上传、75 秒后台自动恢复；单独在 Android/iOS 专用模拟器运行，不能以模拟器结果代替 iOS 26 真机持续任务 UI 验收。
- [x] 更新唯一 owner 文档，明确自动同步有限后台及 Android 平台差异。
- [x] 运行全量 `mise //mobile:test`、变更文件静态分析及格式化、Swift/Kotlin 测试、文档链接检查及 `git diff --check`；记录真实执行结果与未验证项。

## 验证结果（2026-09-14）

- 全量 Dart 测试：1626 通过，3 个既有跳过项。13 个本轮变更的 Dart 文件静态分析无问题。
- Swift `BackgroundTaskCoreTests`：11 通过；Android `BackgroundTaskManagerTest`：9 通过。
- iOS、Android 的短后台集成用例均通过：自动同步原地升级手动模式，不重建连接，同步与 12 个上传分块都在后台完成。
- iOS、Android 的长后台集成用例均通过：宿主在后台等待 75 秒，确认已提交数据保留、旧连接失败后恢复，最终均为 5513 条记录；所有自动同步请求均为 limited。iOS 还实际触发一次 UIKit 后台时间到期。
- Pigeon 已通过仓库 generator 重新生成双端接口，Android/iOS 集成构建成功。Dart、Swift、Markdown 格式检查及 tracked diff 空白检查通过；文档无待验证的相对 Markdown 链接，所用 mise task 名称已与任务列表核对。
- 真机边界：本轮未覆盖安装到 iPhone，也未验证 iOS 26 真机灵动岛显示。模拟器仅证明 UIKit 降级和生命周期逻辑，不代表持续处理任务 UI 已通过验收。
- 未修改生产服务器、真机应用数据或数据库 schema；未创建分支、commit。
