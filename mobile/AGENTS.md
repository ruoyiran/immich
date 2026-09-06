# Mobile Agent 指南

## 适用范围

适用于 `mobile/**`。继承 [`../AGENTS.md`](../AGENTS.md) 中的仓库级规则。

## 开始前阅读

- [Mobile 模块指南](../engineering/modules/mobile.md)
- [系统架构](../engineering/architecture.md)
- [公开 setup 指南](../docs/docs/developer/setup.md)
- [公开测试指南](../docs/docs/developer/testing.md)

## 架构规则

- 新代码优先采用目标 Page/Widget → Riverpod Provider → Service → Repository 流程。
- 将仓库同级的 `../../photo-classifier/` 视为 runtime backend；本仓库只保留客户端与提交的 API contract。
- 将 codebase 视为 migration state：新的 `domain/infrastructure/presentation` 分层与 legacy 目录并存。
- 如果周边代码已经支持该边界，应将 domain intent 与 Drift、OpenAPI 和 platform mechanics 分离。
- 使用 Provider composition 管理依赖；不要创建隐藏的 global singleton。
- 保持 startup、logout、foreground-resume 和 background-engine 的 lifecycle 行为。

## Android/iOS 功能一致性

- Mobile 功能和修复默认必须同时适用于 Android 与 iOS；平台实现可以不同，但用户可见结果必须等价。
- 修改前检查共享 Dart、Pigeon contract、Android/iOS 原生实现、插件注册、权限、生命周期和构建配置。
- 错误分类、取消、重试、缓存失效、持久化和前后台恢复语义必须在双端保持一致。
- 平台能力不对等时，必须记录原因、用户可见差异、稳定降级和对应测试；不得用静默 no-op 伪装支持。
- 平台敏感变更必须分别在 Android 与 iOS 模拟器验证；单个平台通过不能代表完成。
- 无法测试的平台必须明确标记为未验证，不得推断其行为与已测试平台一致。

## 生成文件与联动变更

- 绝不要手工编辑 `generated/openapi/` 或生成的 Dart/Swift/Kotlin 文件。
- 生成 artifacts 时运行 `mise //mobile:codegen`；只有理解 dependency chain 后才能使用更窄的 codegen task。
- Drift schema 变更需要运行 `mise //mobile:drift:migration`、更新 saved schema，并执行从旧版本迁移的测试。
- Pigeon API 变更需要运行 `mise //mobile:codegen:pigeon`，并同步更新 Android 和 iOS 实现。
- Translation 变更从根目录 `i18n/` 开始，需要执行 Mobile generation 和受影响的 Web 检查。
- 保持与 Pigeon/native code 共享的 enum 顺序和值，包括 `AssetType`。
- 外部服务器的 sync/OpenAPI 变更必须先同步 contract，再验证本地 Drift mapping 及 reset/recovery 行为。

## 验证

优先选择最窄的相关命令：

- 测试：`mise //mobile:test`
- Static analysis：`mise //mobile:analyze`
- 完整 codegen：`mise //mobile:codegen`
- 完整 module gate：`mise //mobile:checklist`

对于 schema 工作，显式运行 migration tests。对于 background/native/sync 变更，如果其 lifecycle 假设有要求，应隔离运行相关 integration test。

如果修改 `mobile/packages/ui`，请另外在该 package 目录中运行 `flutter test`。

## 高风险检查

- 验证现有用户的 database migration，而不仅是全新数据库。
- Pigeon/native API 变更后检查 Android 和 iOS 实现。
- 检查跨多个 FlutterEngine/isolate lifecycle 的 cancellation 和 resource cleanup。
- sync 变更后检查 full-sync fallback、reset、reconnect 和 large-library batching。
- upload 变更后检查 Live Photo ordering、retry/idempotency 和 Wi-Fi/cellular policy。
- 不要把过时的 Isar 文档或已删除的 `module_template` 文档视为当前架构。
