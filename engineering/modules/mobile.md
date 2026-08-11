# Mobile 模块

> 用途：说明 Flutter Mobile 的分层迁移、本地数据库、远端/本机同步、原生接口和后台生命周期。  
> 权威来源：`mobile/lib/`、`mobile/pigeon/`、Android/iOS native code、`mobile/test/`、`mobile/integration_test/` 与 `mobile/mise.toml`。  
> 更新触发：Mobile bootstrap、目录分层、Drift schema、sync stream、Pigeon、native media、background worker 或 upload lifecycle 变化。

## 职责与启动流程

Mobile 是独立 Flutter 应用，负责：

- 本机媒体浏览、选择、备份和相册关联；
- 远端资产/相册/用户状态的本地缓存与同步；
- Drift/SQLite offline-capable local state；
- Android MediaStore 与 iOS PhotoKit integration；
- 前台/后台上传、下载与 sync；
- WebSocket 增量更新；
- platform-specific network、notification、widget 和 share extension behavior。

[`mobile/lib/main.dart`](../../mobile/lib/main.dart) 与 [`mobile/lib/utils/bootstrap.dart`](../../mobile/lib/utils/bootstrap.dart) 启动时初始化 localization、Drift、settings/cache、logging、native HTTP client 和 worker isolate pool，再通过根 `ProviderScope` 注入依赖。

启动顺序是多个 provider/service 的隐式前置条件。新增全局 initialization 必须说明失败、重试、logout 和 background engine 行为。

## 当前分层与迁移态

目标数据流：

```text
Page / Widget
  → Riverpod Provider
  → Service
  → Repository
  → Drift / Native API / Server API
```

新目录职责：

| 路径                            | 职责                                                        |
| ------------------------------- | ----------------------------------------------------------- |
| `lib/domain/`                   | domain model、service、action、domain utility               |
| `lib/infrastructure/`           | Drift entity/repository、API/network、mapping、image loader |
| `lib/presentation/`             | page、widget、user interaction                              |
| `lib/providers/infrastructure/` | Riverpod dependency composition                             |
| `packages/ui/`                  | 独立 Mobile Flutter UI package                              |

仓库仍保留 `models/`、`entities/`、`repositories/`、`services/`、`pages/`、`widgets/` 等 legacy 路径。当前是渐进迁移，不是已经完成的 strict Clean Architecture。

新增代码优先遵循新边界，但修改现有功能时先理解其实际依赖，不要为了“整理目录”顺带做大规模迁移。`domain/` 中仍存在直接依赖 concrete infrastructure/OpenAPI repository 的历史例外，应记录而不是假定隔离已完成。

## Drift 本地数据层

当前本地数据库是 Drift/SQLite，不是 Isar。主要实现见 [`mobile/lib/infrastructure/repositories/db.repository.dart`](../../mobile/lib/infrastructure/repositories/db.repository.dart)：

- schema version 是 31；
- 使用 SQLite WAL 与 async connection/pool；
- asset、album、user、stack、partner、memory、sync 等状态写入本地表；
- logs 使用独立数据库；
- repository/service 通过 stream/query 驱动 UI。

典型 timeline flow：scoped provider 覆盖具体 timeline → `TimelineFactory/TimelineService` → Drift repository query/watch → UI 响应 stream。

Schema 变化必须：

1. 修改 Drift table/entity。
2. 运行 `mise //mobile:drift:migration` 和相关 codegen。
3. 保存/更新 migration schema artifacts。
4. 扩展 `test/drift/main/migration_test.dart` 覆盖旧版本升级。
5. 检查 sync mapping、default、index 与大库性能。

不要只让当前空库测试通过；迁移必须覆盖用户已有数据库。

## 远端同步与 WebSocket

远端同步调用 `POST /sync/stream`。[`sync_api.repository.dart`](../../mobile/lib/infrastructure/repositories/sync_api.repository.dart) 建立 stream，[`sync_stream.service.dart`](../../mobile/lib/domain/services/sync_stream.service.dart) 解析 JSON Lines，按实体类型批量写入 Drift，并发送 acknowledgement。

同步需要处理：

- entity version 与 DTO mapping；
- batch transaction；
- reset/重新同步；
- 本地 pending state；
- stream 中断、重试和 lifecycle cancellation；
- Server 与 Mobile schema/contract 兼容性。

[`websocket.provider.dart`](../../mobile/lib/providers/websocket.provider.dart) 对上传、编辑和远端变化执行增量更新或触发重新同步。WebSocket 不是持久化来源；reconnect 后必须能通过 sync 恢复。

## 本机媒体同步

[`NativeSyncApi`](../../mobile/pigeon/native_sync_api.dart) 通过 Pigeon 连接 Dart 与：

- Android MediaStore implementation；
- iOS PhotoKit implementation。

[`local_sync.service.dart`](../../mobile/lib/domain/services/local_sync.service.dart) 将本机 album/asset 的全量或 delta 变化写入 Drift。旧 Android API 和部分 iOS 情况会回退全量扫描。

修改本机同步时检查：

- permission scope 与 limited-library behavior；
- deleted/trashed/moved asset；
- Live Photo pair；
- burst/album mapping；
- identifier stability；
- full-sync fallback；
- 大图库的 batch/memory behavior。

## Pigeon 与原生平台

Pigeon source 位于 [`mobile/pigeon/`](../../mobile/pigeon/)，生成 Dart、Swift 与 Kotlin interfaces。原生注册入口包括：

- [`mobile/android/app/src/main/kotlin/app/alextran/immich/MainActivity.kt`](../../mobile/android/app/src/main/kotlin/app/alextran/immich/MainActivity.kt)
- [`mobile/ios/Runner/AppDelegate.swift`](../../mobile/ios/Runner/AppDelegate.swift)

修改 platform API 时：

1. 修改 Pigeon source，而不是 generated interface。
2. 运行 `mise //mobile:codegen:pigeon` 或完整 `mise //mobile:codegen`。
3. 更新 Android 和 iOS implementation。
4. 覆盖 unsupported platform/version 和 error mapping。
5. 运行相关 integration tests。

`AssetType` 等枚举顺序与 Pigeon/native protocol 绑定。不要重排已有值，除非同时设计并验证兼容迁移。

## 前后台任务与上传

Android 使用 WorkManager 监听媒体变化、周期调度并启动独立 FlutterEngine。iOS 使用 `BGAppRefreshTask`/`BGProcessingTask` 并同样创建独立 engine。

前后台执行的关键风险：

- 多个 FlutterEngine/ProviderContainer；
- shared SQLite 与 persisted settings；
- isolate 被 OS 暂停或终止；
- foreground resume 时取消旧 worker；
- upload concurrency 与 network policy；
- logout/account switch 后的资源清理；
- background URLSession/worker callback 生命周期。

前台 upload 使用并行 worker；Android background 路径与 iOS background transfer 的实现不同。Live Photo 通常先上传 video component，再上传 image component。

主要入口：

- [`mobile/lib/domain/utils/background_sync.dart`](../../mobile/lib/domain/utils/background_sync.dart)
- [`mobile/lib/providers/app_life_cycle.provider.dart`](../../mobile/lib/providers/app_life_cycle.provider.dart)
- [`mobile/lib/services/foreground_upload.service.dart`](../../mobile/lib/services/foreground_upload.service.dart)
- [`mobile/lib/services/background_upload.service.dart`](../../mobile/lib/services/background_upload.service.dart)
- [`mobile/android/app/src/main/kotlin/app/alextran/immich/background/`](../../mobile/android/app/src/main/kotlin/app/alextran/immich/background/)
- [`mobile/ios/Runner/Background/`](../../mobile/ios/Runner/Background/)

## 最小开发与测试入口

| 目的                       | 命令                            |
| -------------------------- | ------------------------------- |
| 安装 dependencies          | `mise //mobile:install`         |
| 启动 app                   | `mise //mobile:start`           |
| 完整 codegen               | `mise //mobile:codegen`         |
| Drift migration generation | `mise //mobile:drift:migration` |
| Dart/static analysis       | `mise //mobile:analyze`         |
| Mobile tests               | `mise //mobile:test`            |
| 完整 Mobile checklist      | `mise //mobile:checklist`       |

测试层次：

- `test/unit/`：service/action/utility 与 mock repository；
- `test/medium/`：in-memory Drift + real repository/service；
- `test/presentation/`：widget 与 interaction；
- `test/drift/main/migration_test.dart`：saved schema migration；
- `integration_test/`：真实 Drift、worker isolate、loopback fake server、login/sync lifecycle。

`mobile/packages/ui` 是独立 package。修改后在该目录单独运行 `flutter test`，不能假定根 Mobile test 自动覆盖。

## 生成物与高风险变更

| 变更                                 | 额外要求                                                                   |
| ------------------------------------ | -------------------------------------------------------------------------- |
| Drift table/schema                   | migration generation、saved schema、migration test、sync mapping           |
| Pigeon API                           | Dart/Swift/Kotlin regeneration、两端 implementation、integration test      |
| OpenAPI model/client                 | 根 OpenAPI generation；禁止手改 `mobile/generated/openapi/`                |
| Freezed/AutoRoute/build_runner input | Dart codegen、generated diff review                                        |
| Translation key                      | root i18n、Mobile loader/keys generation、Web 联动                         |
| Background lifecycle                 | Android/iOS platform behavior、engine/isolate cleanup、resume/logout tests |
| Upload protocol                      | Server contract、Live Photo ordering、network policy、retry/idempotency    |
| Protocol enum                        | 保留已有顺序和值，验证 native/generated compatibility                      |

## 已知文档偏差

- 部分旧架构文档仍描述 Isar；当前实现是 Drift/SQLite。
- `mobile/README.md` 中的 `module_template` 和 `modules` 目录已不存在。
- 代码同时包含目标分层和 legacy directories，不能把理想边界当作完整现状。
- custom lint 曾因版本兼容问题不作为当前主要 CI gate；以 workflow 和 `mobile/mise.toml` 的实际 task 为准。

## 源码导航

| 主题           | 路径                                                                                                                             |
| -------------- | -------------------------------------------------------------------------------------------------------------------------------- |
| Bootstrap      | [`mobile/lib/main.dart`](../../mobile/lib/main.dart)、[`mobile/lib/utils/bootstrap.dart`](../../mobile/lib/utils/bootstrap.dart) |
| Domain         | [`mobile/lib/domain/`](../../mobile/lib/domain/)                                                                                 |
| Infrastructure | [`mobile/lib/infrastructure/`](../../mobile/lib/infrastructure/)                                                                 |
| Presentation   | [`mobile/lib/presentation/`](../../mobile/lib/presentation/)                                                                     |
| Drift DB       | [`mobile/lib/infrastructure/repositories/db.repository.dart`](../../mobile/lib/infrastructure/repositories/db.repository.dart)   |
| Remote sync    | [`mobile/lib/domain/services/sync_stream.service.dart`](../../mobile/lib/domain/services/sync_stream.service.dart)               |
| Local sync     | [`mobile/lib/domain/services/local_sync.service.dart`](../../mobile/lib/domain/services/local_sync.service.dart)                 |
| Pigeon sources | [`mobile/pigeon/`](../../mobile/pigeon/)                                                                                         |
| Android native | [`mobile/android/app/src/main/kotlin/app/alextran/immich/`](../../mobile/android/app/src/main/kotlin/app/alextran/immich/)       |
| iOS native     | [`mobile/ios/Runner/`](../../mobile/ios/Runner/)                                                                                 |
| Tests          | [`mobile/test/`](../../mobile/test/)、[`mobile/integration_test/`](../../mobile/integration_test/)                               |
| Tasks          | [`mobile/mise.toml`](../../mobile/mise.toml)                                                                                     |
