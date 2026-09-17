# Mobile 模块

`mobile/` 是 Flutter client，负责 UI、本机媒体、后台上传、Drift local database、sync state 和 Android/iOS integration。Runtime backend 是同级 `photo-classifier`。

## 边界

- Remote API types 来自 `mobile/generated/openapi/`。
- Local state 和 migration 位于 Drift 层，不由服务器 database schema 直接生成。
- Pigeon 定义 Dart 与 native platform 的接口。
- Server endpoint 由用户配置；客户端必须保持 URL、auth、upload 和 sync compatibility。

## 生成代码

不要手改 OpenAPI、Drift、Pigeon、translation、icon 或 splash 生成输出。使用：

```bash
mise //mobile:codegen
mise //mobile:drift:migration
mise //mobile:codegen:pigeon
```

## 验证

```bash
mise //mobile:test
mise //mobile:analyze
mise //mobile:checklist
```

API/sync 变化需要同时验证 full-sync fallback、reset/reconnect、large-library batching、Live Photo upload ordering 和 retry/idempotency。

## 已启动任务的后台续传

服务器数据同步和手动照片/视频上传由共享的 `BackgroundTaskService` 管理原生后台执行时间。Pigeon 的 `BackgroundTaskMode` 显式区分 `limited` 与 `continued`，默认 `limited`。启动、回前台、WebSocket 触发的自动同步在 iOS 仅使用 UIKit 的有限后台时间，不创建灵动岛持续任务；时间耗尽后保留断点，回前台继续。设置页手动同步和手动上传明确使用 `continued`：iOS 26 使用 `BGContinuedProcessingTask`，较早版本或系统拒绝时回退到 UIKit。手动同步可原地升级已有自动同步，不重建其网络连接。Android 没有 UIKit 对等的有限执行租约，两种模式均保留 `dataSync` 前台服务及系统要求的通知，不人为缩短既有后台能力。这不会重新启用已移除的自动相册备份。

同步批处理在数量上限或两秒时间窗口到达时提交已有完整事件；网络空闲不制造工作进度，不完整 JSON 行继续缓冲。已提交记录数作为真实进度，未知总量用 Pigeon 的 `total = -1` 表示，原生进度使用不定总量，不以“已完成数 + 1”伪装接近 100%。上传总量已知时继续使用确定进度。系统过期或用户在系统任务卡片中取消仍按未完成结束，不能将其改报成功来隐藏灵动岛失败提示；已存在的系统失败卡片也不会因后续续传而改成成功。

正常切换前后台不会重建仍受保护的数据同步。系统收回后台执行时间时，当前请求中止；再次进入前台后，数据同步从已确认的批次继续，上传使用已有分块会话查询服务器偏移后续传。重试前必须等待旧同步线程完成数据库清理。退出登录先取消并等待同步、上传结束，再清理凭据。

前台恢复复用旧同步时，如果旧请求随后失败，只在仍处于前台且登录会话有效时重试一次；所有等待该同步的调用方共享重试结果。健康同步不重建，用户取消、退出登录和普通非恢复同步不会触发这次重试。系统触发的请求取消记录为信息日志，真实网络或数据错误仍保留失败日志；失败结果不会被同步状态页显示为成功。

后台执行仍受系统、电量和用户操作限制；强制结束 App 不保证继续运行。待上传列表目前属于当前进程，不能将分块检查点等同于 App 被终止后自动恢复整个上传队列。

实际前后台切换测试应在 Android、iOS 模拟器上分别、单独运行：

```bash
mise //mobile:test integration_test/background_transfer_continuation_test.dart -d <simulator-id> --reporter expanded
```

看到 `BACKGROUND_TRANSFER_READY` 后打开系统设置或返回桌面；看到 `BACKGROUND_TRANSFER_DONE` 后返回测试 App。测试先将同一个自动同步升级为手动持续任务，要求不重建连接，并让数据同步和 12 个上传分块都在实际后台状态完成。iOS 构建期间不要并行运行其他 Flutter 命令，它们可能重建 Swift Package 临时路径。iOS 模拟器不支持持续后台处理，可能返回 `BGTaskSchedulerErrorDomain Code=1`；该环境验证的是 UIKit 的有限后台时间，不能替代 iPhone 真机对持续后台任务的验证。

长时间后台恢复使用独立的集成用例：

```bash
mise //mobile:test integration_test/remote_sync_background_resume_test.dart -d <simulator-id> --reporter expanded
```

看到 `LONG_SYNC_READY` 后将 App 切到后台，用宿主机计时至少 60 秒再切回（建议 75 秒，不依赖可能被系统暂停的 Dart 计时器）。用例会先验证已有批次仍在，再主动断开恢复后的连接，要求仅新增一次连接并完成同步，最终输出 `LONG_SYNC_VERIFIED`。测试仅连接回环假服务器，使用唯一前缀数据，并在修改前通过 `VACUUM INTO` 备份本地数据库；测试设备应使用无用户数据的专用模拟器。

## 手动上传调度

手动上传与分享上传在同一个服务实例内共用 3 个传输槽。收到服务器的 queued-finalization 确认后，文件转入“等待处理”，释放传输槽供后续文件和新批次使用；处理轮询仍属于原任务，只有服务器返回稳定的资源 ID 才触发成功回调和本地关联。状态查询显式禁用缓存，避免 iOS 原生 HTTP 会话反复返回旧的 processing 状态。Live Photo 的 motion 必须先处理成功，still 再重新申请传输槽上传，并携带 motion 的资源 ID。

上传详情弹窗的“关闭”只收起进度，不取消任务；“取消”仅取消该弹窗所属批次。各批次只清理自己的进度，延迟错误清理不能覆盖新的上传尝试。存在活动批次时，不重复清理媒体临时缓存。取消、退出登录和系统后台时间耗尽仍沿用原任务生命周期；不能把这些进程内任务描述为应用被终止后自动恢复的持久队列。

真实 HTTP 的处理等待、跨批次限流回归可在 Android 和 iOS 专用模拟器分别运行。用例只使用内存数据库、临时文件和回环测试服务器，不访问用户服务器或图库：

```bash
mise //mobile:test integration_test/upload_processing_concurrency_test.dart -d <simulator-id> --reporter expanded
```

## 地图后端

照片详情中的地图缩略图在移动端可使用高德静态地图 Web API，避免中国区 MapLibre 瓦片不可达时出现黑色背景。构建时将部署环境中 `PC_AMAP_KEY` 的值注入为客户端 Dart define：

```bash
--dart-define=IMMICH_AMAP_WEB_KEY="$PC_AMAP_KEY"
```

客户端代码不直接读取部署侧变量。没有配置 `IMMICH_AMAP_WEB_KEY` 时，照片详情地图缩略图回退到 MapLibre。照片 EXIF 的 WGS84 坐标在传给高德静态图和高德 App 前会转换为 GCJ-02。

Android 真机 release 只构建 `arm64-v8a` APK：

```bash
cd mobile
PC_AMAP_KEY=<same-value-as-deployment> scripts/build_android_release_apk.sh
adb install --user 0 -r build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```
