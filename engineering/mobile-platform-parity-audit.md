# Mobile Android/iOS 平台一致性审计

> 审计日期：2026-09-06
> 范围：`mobile/**` 共享 Dart 平台分支、Pigeon contracts、Android/iOS 原生实现与配置、自动化测试。
> 判定原则：要求用户可见行为和边界语义等价，不要求使用相同系统 API。

## 结论摘要

- 静态审计覆盖 9 个 Pigeon 定义文件、Android/iOS 插件注册点、45 个包含显式平台判断的共享 Dart 文件，以及两端的权限、后台、网络、媒体、分享、Widget 和构建配置。
- 所有双平台 Pigeon Host API 均能在 Android 与 iOS 找到实现。`BackgroundWorkerLockApi` 与 `ViewIntentHostApi` 只生成 Android 代码，调用方也有平台保护，属于显式平台专属能力。
- 暂未发现 P0 或 P1 的平台功能缺口。最终结论仍以 Android/iOS 模拟器真实栈测试为准。
- 首次同步存在共享层性能问题：同步期间连续 bucket 更新会把每一次首屏资产刷新都排入 mutex，过期查询仍逐个执行。该问题同时影响 Android/iOS，已由回归测试复现，进入本轮修复。
- Android 原生代码当前没有 `src/test` 或 `src/androidTest` 测试，而 iOS Swift package 有 3 个原生测试文件。这是 P2 测试覆盖差异；本轮缩略图行为通过共享 Dart 测试和 Android 模拟器真实 Pigeon 路径补足，不扩展为 Android 原生测试框架建设。

## 严重级别

| 级别 | 定义 | 合并策略 |
| --- | --- | --- |
| P0 | 数据损坏、安全问题、无法启动或核心流程完全不可用 | 必须修复并双端复测 |
| P1 | 主要用户流程在一个平台缺失、错误或明显不一致 | 必须修复并双端复测 |
| P2 | 有降级路径，但体验、可靠性或测试覆盖存在差异 | 记录并安排后续；与本功能直接相关时修复 |
| P3 | 系统能力或交互惯例导致的合理实现差异 | 记录理由和验证方法 |

## Pigeon 与插件注册

| Contract | Android | iOS | 结论 |
| --- | --- | --- | --- |
| BackgroundWorkerFgHostApi / BgHostApi / FlutterApi | WorkManager 与 background FlutterEngine；自动备份移除后入口主动取消旧任务 | BGTaskScheduler 与 background FlutterEngine；入口主动取消旧任务 | 等价；平台调度机制不同，当前均为兼容性安全退出 |
| BackgroundWorkerLockApi | Android 多 Engine 锁 | 未生成 Swift API | P3；调用方仅在 Android 调用 |
| ConnectivityApi | ConnectivityManager/NetworkCapabilities | NWPathMonitor | 等价；VPN 与 unmetered 推导方式不同，需模拟器验证网络策略 |
| LocalImageApi | MediaStore、ImageDecoder/Glide、CancellationSignal | Photos、ImageIO/vImage、OperationQueue | 等价目标；RAW/HDR、云端素材和取消实现不同 |
| NativeSyncApi | MediaStore，按 Android 版本选择实现 | PhotoKit/PHPersistentChangeToken | 等价目标；相册关系、delta 能力和 cloud ID 属平台差异 |
| NetworkApi | Cronet/OkHttp 与 Android 证书选择 | URLSession/CupertinoClient 与 Keychain | 等价目标；缓存和认证必须通过真实连接验证 |
| PermissionApi | 电池优化、MANAGE_MEDIA 和媒体权限 | Android-only 方法返回稳定的不支持结果 | P3；调用方必须保持平台保护，不得把 false 当作授权失败 |
| RemoteImageApi | Cronet/OkHttp、2 线程原生 decode pool | URLSession、ImageIO/vImage、系统 CPU 相关队列 | 缩略图重点项；共享 Dart 限流统一并发，原生错误和取消需双端验证 |
| ViewIntentHostApi | Android VIEW intent plugin | 未生成 Swift API；iOS 使用文档类型和 Share Extension | P3；入口机制不同，最终打开/分享能力需分别验证 |

## 功能矩阵

| 领域 | 共享入口 | Android | iOS | 级别 | 静态结论 | 动态验证 |
| --- | --- | --- | --- | --- | --- | --- |
| 首次同步与时间线 | `background_sync.dart`、`timeline.service.dart`、Drift repository | 相同 Dart/Drift 路径 | 相同 Dart/Drift 路径 | P1 性能 | bucket 更新可排队执行过期查询；本轮修复 | 待双端首次安装用例 |
| 远端缩略图调度 | `remote_image_provider.dart`、`remote_image_request_scheduler.dart` | Pigeon → Cronet/OkHttp | Pigeon → URLSession | P1 重点 | 共享层限制 8 active/64 pending，可见优先、retry 降级 | 待双端滚动与失败恢复 |
| 远端图片解码 | `remote_image_request.dart` | Android Q+ ImageDecoder；失败回退 encoded；处理 RAW orientation 与 10-bit | ImageIO thumbnail + vImage RGBA | P2 | 输出契约一致；实现针对平台格式能力分化 | 待 RAW/HDR/大图回归 |
| 本地缩略图 | `local_image_provider.dart` | MediaStore `loadThumbnail` 或旧版 thumbnail API | PhotoKit `requestImage` | P3 | 目标尺寸、取消和 encoded fallback 契约一致 | 待本地图库用例 |
| Thumbhash | `thumb_hash_provider.dart` | Java/Kotlin native decode | Swift native decode | P3 | 输出 RGBA 指针契约一致 | 共享 Widget 测试 + 双端首屏 |
| 图片缓存 | `custom_image_cache.dart`、`RemoteImageApi.clearCache` | Flutter 分层缓存 + Cronet/OkHttp disk cache | Flutter 分层缓存 + URLCache | P2 | 清理接口一致；底层容量和失效机制不同 | 待清缓存/重启用例 |
| 请求取消 | `CancellableImageProviderMixin` | CancellationSignal、Cronet/OkHttp cancel | RequestRegistry、URLSessionTask cancel | P1 重点 | 共享 lifecycle 一致；需验证快速滚动无悬挂 | 待首次安装滚动用例 |
| HTTP 错误与重试 | `RemoteImageProvider` | 非 2xx 转 `IOException` | 非 2xx 转 `PigeonError(IOException, HTTP nnn)` | P1 重点 | 404/408/429/500–504 由共享层重试 | 待双端错误注入 |
| 相册发现 | `local_sync.service.dart`、`local_album.repository.dart` | MediaStore bucket；单资产单 bucket 假设 | PhotoKit collection；资产可属于多个相册 | P3 | 数据模型差异已有分支处理 | MOB-REAL-005/006/007/035/051 |
| 增量同步 | `local_sync.service.dart` | Android 某些 album 删除无法增量识别，恢复前台执行 full local sync | PhotoKit change token；cloud album 需 full sync | P3 | 策略不同但目标为最终一致 | MOB-REAL-019/020/021/031 |
| Cloud ID | `migrate_cloud_ids.dart` | 无系统 cloud ID，native 返回空集合 | PhotoKit cloud identifier | P3 | iOS-only 能力且调用方有平台保护 | Sync maintenance 用例 |
| Hashing | `NativeSyncApi.hashAssets` | 16 并发、MediaStore original stream，默认 batch 512 | PhotoKit/iCloud，可允许网络访问，默认 batch 32 | P3 | 限制基于平台资源模型 | 上传与恢复用例 |
| Live/Motion Photo | upload/download/storage services | Motion Photo；部分 HEIC 由服务端拆分 | Apple Live Photo；PMLive/PhotoKit 保存 | P3 | 产物机制不同，逻辑资产结果应一致 | MOB-REAL-014、068–078 |
| 媒体删除/回收站 | asset media/service | Android 版本与 MANAGE_MEDIA 决定系统确认和 trash API | Photos 删除模型；共享相册关系不同 | P3 | 系统权限模型不同，最终资产状态需一致 | MOB-UI-049、MOB-MEDIA-072–078 |
| 后台任务 | background worker service | WorkManager、Engine lock | BGTaskScheduler | P3 | 自动备份已移除，两端均取消遗留任务并安全退出 | MOB-REAL-031/032 |
| 网络能力 | network repositories | ConnectivityManager，VPN 下补推断底层 Wi-Fi/cellular | NWPathMonitor，使用 expensive/constrained 判断计费 | P2 | 目标相同，VPN/热点边缘语义可能不同 | 待网络策略双端验证 |
| mTLS 与会话 | NetworkApi、ApiService | OkHttp/Cronet 和 Android credential UI | URLSession、Keychain 和 document picker | P2 | headers/token/app-group contract 对齐 | MOB-UI-062 + 手工证书场景 |
| 分享导入 | share action、foreground upload | SEND/SEND_MULTIPLE intents | Share Extension + app group | P3 | 入口不同，上传结果应一致 | MOB-UI-041/042 |
| 外部文件查看 | view intent provider | Android VIEW intent | iOS document type/系统打开流程，无 ViewIntent Pigeon | P3 | 平台入口不同 | MOB-UI-041 与平台手工检查 |
| 深链 | router、平台配置 | scheme + verified app links | URL scheme + associated domains | P3 | 路由目标应一致 | MOB-UI-034 |
| 下载保存 | file media/download services | 保存到 `DCIM/Immich`，Motion Photo 处理 | PhotoKit 保存，临时文件需要清理 | P3 | 最终图库可见性一致 | MOB-UI-041、MOB-MEDIA-068 |
| 地图 | map widgets/extensions | circle layer 与 geo URI | heatmap layer 与 Apple Maps URL | P3 | 图层实现和外部地图入口为平台惯例差异 | MOB-UI-060 |
| 系统 UI/手势 | main、asset viewer、app bars | Android navigation bar、clamping scroll | iOS immersive/detail 和 bouncing-like scroll | P3 | 平台交互惯例差异 | MOB-UI-033、viewer 用例 |
| 通知权限 | permission provider/manifest/plist | POST_NOTIFICATIONS 与 Android permission 状态 | permission_handler notifications | P2 | 初始状态表达不同，最终授权结果需验证 | 设置和后台场景 |
| 登录默认地址 | `login_defaults.dart` | 无保存值时为空 | 无保存值时使用本地 release server URL | P3 | 当前内部开发环境的显式差异；不改变认证能力 | login form tests |
| Home Screen Widgets | Android widget package | Random、Memory Glance widgets | Random、Memory WidgetKit extension | P3 | 两端均有同类能力，实现独立 | 平台手工 smoke |
| 升级与持久化 | Bootstrap、Drift、platform storage | Android app data/MediaStore | iOS container/app group/PhotoKit | P1 重点 | 迁移与登录保留是共同契约 | MOB-REAL-032 |

## 已确认问题与处置

### P1：首次同步期间时间线刷新放大

- 证据：`TimelineService` 对每个 bucket stream 事件调用 `_mutex.run`；当首个 asset query 尚未完成时，后续事件全部排队，测试中 10 次事件产生 10 次查询。
- 用户影响：全新安装首次远端同步期间，时间线数据库读取和 Widget 刷新可能反复执行，延后首屏稳定和缩略图显示。
- 处置：合并正在进行的刷新期间收到的事件，仅在当前刷新后针对最新 bucket 再执行一次；保留“内容相同的后续独立事件仍刷新资产”的语义。
- 测试：`mobile/test/domain/services/timeline_service_test.dart`。

### P2：原生单元测试覆盖不对称

- 证据：`mobile/ios` 有 PMLiveWriter 和 RemoteImageHTTPStatus Swift tests；`mobile/android` 没有 `src/test` 或 `src/androidTest` 测试文件。
- 风险：Android 原生图片、同步和网络回归主要依赖 Dart 边界测试与模拟器真实栈测试，定位速度低于 iOS。
- 处置：本轮不引入新的 Android 测试框架；缩略图路径必须通过 Android 模拟器真实 Pigeon 调用。后续适合为纯 Kotlin 的 HTTP 分类、buffer 和方向逻辑建立单测目标。

## 合理的平台特例

- Android 的电池优化、MANAGE_MEDIA、MediaStore trash 和后台 Engine lock 在 iOS 没有同构 API。
- iOS 的 PhotoKit cloud ID、limited library、iCloud 下载和 Apple Live Photo 写入在 Android 没有同构 API。
- Android View Intent 与 iOS Share Extension/document type 是不同系统入口。
- Android Motion Photo 与 iOS Live Photo 使用不同封装和保存协议。
- Android 与 iOS 地图图层、返回图标、滚动物理和系统栏遵循各自平台惯例。
- Android/iOS 的网络和图片缓存实现不同，但必须满足共享层定义的最终语义。

## 验证状态

| 验证项 | 状态 |
| --- | --- |
| Pigeon 定义、实现与注册静态检查 | 完成 |
| 45 个共享 Dart 平台条件文件分类 | 完成 |
| Android/iOS 配置与扩展静态检查 | 完成 |
| 缩略图与时间线窄测试 | 60 项通过 |
| 时间线刷新放大回归测试 | RED 已复现；修复后 GREEN |
| 完整 Flutter 单元/Widget/medium 测试 | 1458 项通过，3 项按既有条件跳过 |
| Dart analyzer | 通过 |
| iOS Swift package tests | 5 项通过，1 项因未提供外部 Live Photo fixture 按设计跳过 |
| Android 模拟器 | background sync 3 项通过；MOB-REAL-079 连续 3 轮通过，12 张缩略图 1219/1122/1116ms（中位数 1122ms）；MOB-REAL-016 在 5 分钟预算下通过 |
| iOS 模拟器 | background sync 3 项通过；MOB-REAL-079 连续 3 轮通过，12 张缩略图 947/926/902ms（中位数 926ms）；旧 MOB-REAL-016 UI harness 停在 inactive 状态，未进入 fixture 上传 |
| DCM / 完整 Mobile checklist | 本机 DCM 未激活，待许可证可用后执行 |

## 合并门槛

- P0/P1 列表为空或全部关闭。
- 首次安装缩略图用例在 Android/iOS 各连续通过三次。
- 两端完整真实栈队列无未解释失败或静默 skip。
- `mise //mobile:checklist`、iOS `swift test` 和 `git diff --check` 全部通过。

## 显式平台分支清单

以下 45 个共享 Dart 文件中的平台判断已纳入上述分类：

- Core/config：`main.dart`、`constants/constants.dart`、`extensions/platform_extensions.dart`、`utils/upload_source_metadata.dart`、`utils/user_agent.dart`。
- Domain：`domain/models/feature_message.model.dart`、`domain/services/asset.service.dart`、`domain/services/background_worker.service.dart`、`domain/services/device_permission.service.dart`、`domain/services/local_sync.service.dart`、`domain/utils/migrate_cloud_ids.dart`。
- Infrastructure/repositories：`infrastructure/repositories/local_album.repository.dart`、`infrastructure/repositories/network.repository.dart`、`infrastructure/repositories/storage.repository.dart`、`repositories/asset_media.repository.dart`、`repositories/download.repository.dart`、`repositories/file_media.repository.dart`、`repositories/network.repository.dart`、`repositories/permission.repository.dart`。
- Services/providers：`services/api.service.dart`、`services/cleanup.service.dart`、`services/download.service.dart`、`services/foreground_upload.service.dart`、`providers/app_life_cycle.provider.dart`、`providers/permission.provider.dart`、`providers/view_intent/view_intent_handler.provider.dart`。
- Actions/pages：`presentation/actions/delete.action.dart`、`presentation/actions/share.action.dart`、`presentation/pages/drift_asset_troubleshoot.page.dart`。
- Asset viewer/map：`presentation/widgets/asset_viewer/asset_viewer.page.dart`、`presentation/widgets/asset_viewer/motion_photo_button.widget.dart`、`presentation/widgets/asset_viewer/video_viewer.widget.dart`、`presentation/widgets/map/map.widget.dart`、`extensions/maplibrecontroller_extensions.dart`、`widgets/asset_viewer/detail_panel/exif_map.dart`。
- UI/settings/login：`widgets/common/app_bar_dialog/server_update_notification.dart`、`widgets/common/immich_sliver_app_bar.dart`、`widgets/common/mesmerizing_sliver_app_bar.dart`、`widgets/common/person_sliver_app_bar.dart`、`widgets/common/remote_album_sliver_app_bar.dart`、`widgets/forms/login/login_defaults.dart`、`widgets/forms/login/login_form.dart`、`widgets/settings/advanced_settings.dart`、`widgets/settings/beta_sync_settings/sync_status_and_actions.dart`、`widgets/settings/free_up_space_settings.dart`。
