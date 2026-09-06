# Mobile 首次安装缩略图与双平台一致性实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 优化 Mobile 首次安装后的时间线缩略图加载，建立 Android/iOS 一致性规范和全量差异审计，并在双端模拟器通过完整验证后合并到 `main`、清理 worktree。

**Architecture:** 以共享 Flutter/Dart 加载链路为行为控制面，通过 Drift 查询、Timeline 状态、ImageProvider、请求调度器和 Pigeon 原生实现的分段指标定位瓶颈；平台实现可以不同，但对缓存、取消、错误、重试和用户可见结果提供相同契约。审计矩阵覆盖整个 `mobile/**`，本轮阻断并修复缩略图相关及 P0/P1 差异。

**Tech Stack:** Flutter 3.44.9、Dart、Riverpod、Drift、Pigeon、Kotlin/Android、Swift/iOS、Flutter integration_test、真实 `photo-classifier` 服务。

**Spec:** `engineering/plans/2026-09-06-mobile-thumbnail-platform-parity-design.md`

## Global Constraints

- 在 `.worktrees/thumbnail-cross-platform` 和分支 `codex/thumbnail-cross-platform` 中实施；主工作区保持干净。
- 全部测试通过前不创建 commit。
- 不手工编辑 Pigeon、Drift、OpenAPI、translation、icon 或 splash 生成文件。
- 本轮审计覆盖整个 `mobile/**`；必须修复缩略图相关和 P0/P1 差异，P2/P3 写入审计报告。
- Android/iOS 的用户行为、错误、取消、缓存和生命周期语义必须等价；平台天然限制必须显式记录。
- 不修改实体 iPhone 数据；清除应用数据只在模拟器/模拟设备执行。
- 如需修改 `../photo-classifier` 或 OpenAPI contract，先停止并报告跨仓库影响。
- 所有测试日志、截图、trace 和临时数据放在仓库外的日期化临时目录，不提交凭据或运行产物。

## Execution Status

- [x] Task 1：worktree、依赖和设备基线完成。
- [x] Task 2：Android/iOS 一致性规范已写入并通过格式检查。
- [x] Task 3：静态审计矩阵已建立；动态结果待真实栈补充。
- [x] Task 4：刷新放大测试完成 RED/GREEN；MOB-REAL-079 已完成双端编译。
- [x] Task 5：共享层最小修复完成，相关窄测试与完整 Flutter 测试通过。
- [x] Task 6：静态审计未发现额外 P0/P1；等待模拟器动态验证。
- [x] Task 7：Android MOB-REAL-079 三轮、MOB-REAL-016 和 background sync 设备测试完成。
- [x] Task 8：iOS MOB-REAL-079 三轮和 background sync 设备测试完成；记录既有 MOB-REAL-016 inactive harness 问题。
- [ ] Task 9：DCM 许可证和真实栈验证完成后执行提交。
- [ ] Task 10：提交并验证后合并、清理。

---

### Task 1: 确认隔离工作区和工具链基线

**Files:**

- Read: `AGENTS.md`
- Read: `mobile/AGENTS.md`
- Read: `mobile/mise.toml`
- Read: `mobile/pubspec.yaml`
- Read: `engineering/plans/2026-09-06-mobile-thumbnail-platform-parity-design.md`

**Interfaces:**

- Consumes: 当前 `main`、现有 worktree、mise task graph、Flutter device list。
- Produces: 可复现的实施基线和仓库外证据目录。

- [ ] **Step 1: 验证 worktree 状态和来源**

Run:

```bash
git status --short
git rev-parse --show-toplevel
git rev-parse --git-dir
git rev-parse --git-common-dir
git branch --show-current
git merge-base --is-ancestor main HEAD
```

Expected: 工作区只有本设计和计划文件；当前分支为 `codex/thumbnail-cross-platform`，HEAD 基于最新 `main`。

- [ ] **Step 2: 确认任务和依赖**

Run:

```bash
mise tasks ls --all --name-only
mise //mobile:install
mise exec -- flutter doctor -v
mise exec -- flutter devices
```

Expected: Mobile tasks 存在，Flutter 依赖可解析，iOS 模拟器可见，Android AVD 可启动。

- [ ] **Step 3: 建立仓库外证据目录**

Run:

```bash
evidence_root="$(mktemp -d /tmp/immich-mobile-parity-20260906.XXXXXX)"
printf '%s\n' "$evidence_root"
```

Expected: 后续日志、截图、性能数据只写入输出目录，不出现在 `git status`。

---

### Task 2: 写入 Android/iOS 一致性规范

**Files:**

- Modify: `mobile/AGENTS.md`

**Interfaces:**

- Consumes: 设计文档中的平台一致性原则。
- Produces: 对所有后续 Mobile 改动生效的 scoped instructions。

- [ ] **Step 1: 增加“Android/iOS 功能一致性”章节**

章节必须规定：默认双端等价、检查共享 Dart/Pigeon/双端原生实现、显式记录特例、禁止静默 no-op、平台敏感改动双端验证、未测平台不得标记完成。

- [ ] **Step 2: 检查文档约束**

Run:

```bash
wc -l mobile/AGENTS.md
python3 - <<'PY'
from pathlib import Path
p = Path('mobile/AGENTS.md')
assert p.exists()
assert len(p.read_text().splitlines()) <= 120
PY
git diff --check -- mobile/AGENTS.md
```

Expected: 文件不超过 120 行，无空白错误。

---

### Task 3: 建立全量平台差异审计矩阵

**Files:**

- Create: `engineering/mobile-platform-parity-audit.md`
- Read: `mobile/pigeon/*.dart`
- Read: `mobile/android/app/src/main/**`
- Read: `mobile/ios/Runner/**`
- Read: `mobile/lib/**`
- Read: `mobile/test/**`
- Read: `mobile/integration_test/**`

**Interfaces:**

- Consumes: Pigeon contract、Dart 平台分支、Android/iOS 注册点和实现、Manifest/Info.plist/entitlements、测试清单。
- Produces: 每项都有证据和处置结论的审计表。

- [ ] **Step 1: 生成 Pigeon 与注册点清单**

逐一核对 `background_worker_api.dart`、`background_worker_lock_api.dart`、`connectivity_api.dart`、`local_image_api.dart`、`native_sync_api.dart`、`network_api.dart`、`permission_api.dart`、`remote_image_api.dart` 和 `view_intent_api.dart` 的 Android/iOS 注册与方法覆盖。

- [ ] **Step 2: 枚举共享 Dart 的平台条件分支**

Run:

```bash
rg -n 'Platform\.is(Android|IOS)|TargetPlatform\.(android|iOS)|defaultTargetPlatform' \
  mobile/lib mobile/test mobile/integration_test
```

对每处记录用户行为、平台原因、现有测试和是否需要修复。

- [ ] **Step 3: 审计原生能力与配置**

覆盖图片、同步、后台任务、权限、网络、上传下载、Live/Motion Photo、intent/deep link、存储升级、Manifest、Info.plist、entitlements、Gradle、SPM 和 CocoaPods。

- [ ] **Step 4: 分级并处理结论**

将差异标记为 P0/P1/P2/P3。P0/P1 和缩略图差异进入本轮修复；P2/P3 写明平台原因、降级方式和后续建议。审计表不得存在空白结论或未解释的 skip。

- [ ] **Step 5: 验证报告完整性**

人工逐项对照 Pigeon 文件、平台条件文件列表和原生入口，确认每个条目均有 Android、iOS、测试与结论列，然后运行：

```bash
git diff --check -- engineering/mobile-platform-parity-audit.md
```

Expected: 审计覆盖设计文档列出的 12 类边界，无 P0/P1 未分配修复动作。

---

### Task 4: 为首次安装缩略图建立失败测试和测量入口

**Files:**

- Modify: `mobile/test/infrastructure/loaders/remote_image_request_scheduler_test.dart`
- Modify: `mobile/test/infrastructure/loaders/remote_image_request_test.dart`
- Modify: `mobile/test/presentation/widgets/images/thumbnail_widget_test.dart`
- Modify: `mobile/test/medium/repositories/timeline_repository_test.dart`
- Modify: `mobile/integration_test/real_stack_auth_test.dart`
- Test utility only if needed: `mobile/integration_test/test_utils/general_helper.dart`

**Interfaces:**

- Consumes: `TimelineService.loadAssets`、`RemoteImageRequestScheduler.schedule`、`Thumbnail.fromAsset` 和现有 real-stack 配置。
- Produces: 能捕获首屏请求重复、队列失控、离屏任务未取消和首屏缩略图未渲染的测试。

- [ ] **Step 1: 写 Timeline 高频 bucket 更新回归测试**

测试使用真实 `TimelineService` 和可控 asset source，连续发送内容变化的 bucket，断言同一批首屏数据不会产生并行重复加载，最终 buffer 与最新 bucket 一致。

- [ ] **Step 2: 运行测试并确认 RED**

Run:

```bash
mise //mobile:test -- test/domain/services/timeline_service_test.dart
```

Expected: 测试因当前重复加载或缺少合并机制失败；如果立即通过，保留现有行为结论并转向下一项有证据的瓶颈，不制造无效测试。

- [ ] **Step 3: 写请求调度与 Widget 生命周期回归测试**

分别覆盖相同图片 provider 的重建去重、pending 请求取消后不进入平台通道、可见请求优先于 retry，以及最终图片替换 thumbhash。

- [ ] **Step 4: 运行相关测试并确认 RED**

Run:

```bash
mise //mobile:test -- \
  test/infrastructure/loaders/remote_image_request_scheduler_test.dart \
  test/infrastructure/loaders/remote_image_request_test.dart \
  test/presentation/widgets/images/thumbnail_widget_test.dart
```

Expected: 至少一个针对确认问题的新断言以预期原因失败。已经受现有代码保护的行为只记录为基线，不重复修改。

- [ ] **Step 5: 增加首次安装真实栈用例**

增加一个新的 `MOB-REAL-079-$_caseSuffix` 用例：创建固定远端图片集合、清空客户端 Store/Drift/image cache、走真实登录和首次 sync、等待主时间线，并通过真实 `ThumbnailTile` 下的 `RawImage.image` 验证首屏渲染。快速滚动后回到顶部，再次断言首屏没有永久空白。

- [ ] **Step 6: 在修改生产代码前运行新用例并保存基线**

分别运行 Android/iOS 新用例三次，保存计时和日志。用例若仅因尚未定义的性能断言失败，确认功能断言本身稳定后再进入实现。

---

### Task 5: 修复已确认的首次安装瓶颈

**Files:**

- Modify only when supported by Task 4 evidence:
  - `mobile/lib/providers/infrastructure/timeline.provider.dart`
  - `mobile/lib/domain/services/timeline.service.dart`
  - `mobile/lib/infrastructure/repositories/timeline.repository.dart`
  - `mobile/lib/presentation/widgets/images/image_provider.dart`
  - `mobile/lib/presentation/widgets/images/thumbnail.widget.dart`
  - `mobile/lib/presentation/widgets/images/remote_image_provider.dart`
  - `mobile/lib/infrastructure/loaders/remote_image_request.dart`
  - `mobile/lib/infrastructure/loaders/remote_image_request_scheduler.dart`
  - `mobile/android/app/src/main/kotlin/app/alextran/immich/images/RemoteImagesImpl.kt`
  - `mobile/ios/Runner/Images/RemoteImagesImpl.swift`

**Interfaces:**

- Consumes: Task 4 的失败测试和分段性能数据。
- Produces: 通过相同测试的最小实现，不改变无关功能。

- [ ] **Step 1: 修复最早出现的重复工作**

若重复发生在 bucket/timeline 层，合并同一同步批次造成的重载并保持最终版本；若发生在图片层，稳定 provider key、取消已离屏 pending 请求，并确保同一 cache key 只保留一个加载。两者都存在时先修上游 timeline churn，再修图片请求。

- [ ] **Step 2: 运行对应窄测试并确认 GREEN**

Run the exact failing test from Task 4, then its complete test file. Expected: 新断言通过，旧断言无回归。

- [ ] **Step 3: 修复平台原生差异**

只有 trace 显示原生层为瓶颈时才调整：统一 Android/iOS 的非 2xx 错误、取消终态、目标尺寸和缓存失效语义；保留 Android RAW/HDR 与 iOS Photos/ImageIO 所需的平台实现差异。

- [ ] **Step 4: 运行原生及 Dart 边界测试**

Run:

```bash
mise //mobile:test -- \
  test/infrastructure/loaders/remote_image_request_test.dart \
  test/presentation/widgets/images/local_image_provider_test.dart \
  test/presentation/widgets/images/thumbnail_widget_test.dart
(cd mobile/ios && swift test)
```

Expected: 全部退出码为 0；Android 原生行为通过 Android 模拟器上的 Pigeon/真实栈路径验证。

- [ ] **Step 5: 对比修复后性能**

按 Task 4 完全相同的数据和操作各运行三次。主瓶颈中位耗时至少改善 20%，其他阶段无超过 10% 的中位回退；若基线低于噪声，则必须证明重复请求/重复查询被消除且三个运行均无功能回退。

---

### Task 6: 修复审计发现的 P0/P1 差异

**Files:**

- Modify: Task 3 审计表中被标为 P0/P1 的具体 Dart/Kotlin/Swift 文件。
- Test: 与每个缺陷最近的 `mobile/test/**` 或 `mobile/integration_test/**`。

**Interfaces:**

- Consumes: 审计矩阵中的复现步骤和预期平台契约。
- Produces: 双端等价行为和对应回归测试。

- [ ] **Step 1: 每个差异先写一个失败测试**

测试名称明确指出错误平台行为，并验证用户可见结果或边界契约，不断言实现文本或 mock 自身。

- [ ] **Step 2: 逐个运行并确认 RED**

使用最窄 `mise //mobile:test -- <test-file>` 或目标模拟器 integration case。失败必须来自待修复差异。

- [ ] **Step 3: 实施最小修复并确认 GREEN**

不得把不同根因的重构混在同一修改中。涉及 Pigeon 时运行 `mise //mobile:codegen:pigeon` 并同时核对双端生成 diff。

- [ ] **Step 4: 更新审计结论**

将已修复项标记为“已修复”，附测试文件和双端结果；P2/P3 保持“已解释/后续”状态。

---

### Task 7: Android 模拟器完整验证

**Files:**

- Evidence only: repository-external Android logs, screenshots and timings.

**Interfaces:**

- Consumes: `ImmichTask9_API36`、真实服务地址、测试用户和唯一 Android case suffix。
- Produces: Android 目标用例及时间线、同步、冷启动相关回归结果。

- [ ] **Step 1: 启动并确认 AVD**

启动 `ImmichTask9_API36`，等待 `adb wait-for-device` 和 boot completion。确认实际安装 package id，不假设 release id。

- [ ] **Step 2: 准备媒体与权限**

将测试媒体放入 `/sdcard/DCIM/...` 或 `/sdcard/Pictures/...`，触发 MediaScanner；安装后对实际 package id 授予已声明的图片、视频、音频、媒体位置和通知权限。

- [ ] **Step 3: 运行首次安装用例三次**

每轮清除模拟器应用数据，使用 `IMMICH_E2E_CASE_ID=MOB-REAL-079-ANDROID` 和 Android 专属 suffix，保存完整日志和性能结果。

- [ ] **Step 4: 运行相关回归用例**

至少覆盖 MOB-REAL-004、007、010、016、017、019、020、029、031、032，以及本轮审计涉及的 case。

- [ ] **Step 5: 运行风险相关 real-stack 回归**

合并门槛为 MOB-REAL-079 连续三轮、`background_sync_teardown_test.dart` 和 MOB-REAL-016；若某平台的既有 UI harness 无法进入测试主体，记录日志并以 079 的无 UI 原生图片链路覆盖该平台。需要额外协作者账号、特殊媒体或外部服务的无关 case 不进入本次合并门槛，但必须标记为未运行。

---

### Task 8: iOS 模拟器完整验证

**Files:**

- Evidence only: repository-external iOS logs, screenshots and timings.

**Interfaces:**

- Consumes: `PhotoManagement iPhone 16 Pro`、相同真实服务数据、唯一 iOS case suffix。
- Produces: iOS 目标用例及时间线、同步、冷启动相关回归结果。

- [ ] **Step 1: 确认模拟器与 fixture**

只使用 iOS 模拟器；通过 `simctl addmedia` 准备图库 fixture，并验证 Photos 中可见。不得安装到实体 iPhone。

- [ ] **Step 2: 运行首次安装用例三次**

每轮卸载模拟器应用或清除其数据容器后重新安装，使用 `IMMICH_E2E_CASE_ID=MOB-REAL-079-IOS` 和 iOS 专属 suffix，保存完整日志和性能结果。

- [ ] **Step 3: 运行相关回归用例**

至少覆盖 MOB-REAL-004、005、006、007、010、016、017、019、020、029、031、032，以及本轮审计涉及的 case。

- [ ] **Step 4: 运行风险相关 real-stack 回归**

合并门槛为 MOB-REAL-079 连续三轮、`background_sync_teardown_test.dart` 和 MOB-REAL-016；若既有 UI harness 停在非 active 状态且未进入业务断言，保留日志并以 079 的无 UI 原生图片链路作为本次验证，不将该用例标为通过。平台天然不支持的行为必须由测试显式验证其降级结果，不允许无记录跳过。

- [ ] **Step 5: 运行 Swift tests**

Run:

```bash
(cd mobile/ios && swift test)
```

Expected: `PMLiveWriterTests` 和 `RemoteImageHTTPStatusCoreTests` 全部通过。

---

### Task 9: 完整门禁、审查和提交

**Files:**

- Review: all tracked changes in the worktree.

**Interfaces:**

- Consumes: 已通过的窄测试、Android/iOS 结果和审计矩阵。
- Produces: 可合并且无未验证 P0/P1 的提交。

- [ ] **Step 1: 运行完整 Mobile 门禁**

Run:

```bash
mise //mobile:format
mise //mobile:analyze
mise //mobile:test
mise //mobile:checklist
git diff --check
```

Expected: 所有命令退出码为 0。

- [ ] **Step 2: 审查完整 diff**

Run:

```bash
git status --short
git diff --stat
git diff -- mobile engineering
```

确认没有 secrets、模拟器产物、日志、截图、构建输出或无关重构；生成文件仅来自相应 generator。

- [ ] **Step 3: 对照设计逐项验收**

确认首次安装性能、AGENTS 规范、完整审计、Android/iOS 模拟器、P0/P1 清零及证据路径均已完成。

- [ ] **Step 4: 测试通过后创建提交**

Run:

```bash
git add mobile engineering
git commit -m "perf(mobile): align first-install thumbnail loading"
```

Expected: 提交只包含本计划范围内文件。

---

### Task 10: 合并 main 并清理 worktree

**Files:**

- No source changes expected.

**Interfaces:**

- Consumes: 已验证提交和明确的 base branch `main`。
- Produces: 已验证的 `main`，无遗留 feature worktree 或分支。

- [ ] **Step 1: 确认主工作区干净且 main 未意外前进**

Run:

```bash
git -C /Users/bytedance/workspace/AI/immich status --short
git -C /Users/bytedance/workspace/AI/immich log -1 --oneline
```

如果 `main` 已前进，将其 fast-forward/merge 到功能分支，并重新运行受影响门禁。

- [ ] **Step 2: 合并功能分支**

从主工作区运行：

```bash
git merge --ff-only codex/thumbnail-cross-platform
```

Expected: fast-forward 成功；若不能 fast-forward，停止并检查分叉，不自动创建 merge commit。

- [ ] **Step 3: 在合并后的 main 上重新验证**

Run:

```bash
mise //mobile:checklist
git diff --check HEAD^ HEAD
```

并分别重新运行 Android/iOS 的 MOB-REAL-079 smoke case。所有结果必须为绿色。

- [ ] **Step 4: 安全清理**

先从主工作区外确认 worktree 无修改：

```bash
git -C .worktrees/thumbnail-cross-platform status --short
git worktree remove .worktrees/thumbnail-cross-platform
git worktree prune
git branch -d codex/thumbnail-cross-platform
git worktree list
```

Expected: worktree 和已合并分支消失，`main` 保留最终提交。若 removal 报告未提交文件，立即停止，不使用 `--force`。
