# 开发入口与跨模块变更指南

> 用途：按变更类型选择最小开发入口，并固定 API、database、Mobile native/codegen 与 i18n 的跨模块更新顺序。
> 权威来源：根 [`mise.toml`](../mise.toml)、[`server/mise.toml`](../server/mise.toml)、[`web/mise.toml`](../web/mise.toml)、[`mobile/mise.toml`](../mobile/mise.toml) 与各模块最近的 `AGENTS.md`。
> 更新触发：task 名称、generated artifact、contract consumer 或跨模块依赖链变化。

## 使用边界

本文不是环境安装手册，也不复制完整测试矩阵。首次准备环境、确认目录职责或提交前检查时，以这些公开文档为准：

- [开发环境配置](../docs/docs/developer/setup.md)
- [目录说明](../docs/docs/developer/directories.md)
- [测试指南](../docs/docs/developer/testing.md)
- [数据库迁移](../docs/docs/developer/database-migrations.md)
- [PR checklist](../docs/docs/developer/pr-checklist.md)

本文只回答两个问题：本次变更从哪个入口开始，以及跨模块产物按什么顺序更新。

## 变更前检查

1. 从 repository root 运行 `git status --short`，确认当前 branch/worktree 与已有未提交变更；不要覆盖、格式化或删除不属于本次任务的文件。
2. 阅读 root 和目标目录最近的 `AGENTS.md`，再用 `mise tasks ls --all` 核对当前 task 名称。文档中的命令不是替代 [`mise.toml`](../mise.toml) 的第二份配置。
3. 先标出 authoritative input、generated output 和 downstream consumer。例如 API 变更的 input 是 Server controller/DTO，SDK 文件只是生成结果。
4. 把预期变更路径写成 scope：业务源码、contract/migration、generated artifacts、consumer、tests/docs。生成器产生 scope 外 diff 时先查明原因，不顺手纳入。
5. 对 API、database、Mobile persistence/native bridge 或 i18n 变更，先选择下文对应流程，再开始修改 consumer。

## 开发入口选择矩阵

| 变更类型                                | 推荐入口                                                            | 进入条件与后续动作                                                                                                                                                    |
| --------------------------------------- | ------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Server + Web + infrastructure 联调      | `mise dev`                                                          | 按[开发环境配置](../docs/docs/developer/setup.md)准备 Docker 环境；适合需要本地 database、jobs、WebSocket 或完整 request path 的变更。                                |
| 仅 Web，复用现有 backend contract       | `IMMICH_SERVER_URL=<url> mise //web:start`                          | task 会安装 Web 与 TypeScript SDK；连接官方 demo 时可用 `mise //web:start-demo`。若 API contract 也变化，改走完整 OpenAPI 流程。                                      |
| 仅 Mobile UI/业务逻辑                   | `mise //mobile:install`，然后 `mise //mobile:start`                 | 初次或 dependency 变化时安装；若涉及 Freezed、AutoRoute、Drift、Pigeon 或 translations，先运行对应 codegen。                                                          |
| Server controller/DTO/API contract      | `mise //:open-api`                                                  | 先改 Server source，再同步 spec 并生成 TypeScript/Dart SDK；不要先在 Web 或 Mobile 中补临时类型。                                                                     |
| 仅调试 TypeScript/Dart generator        | `mise //:open-api-typescript` 或 `mise //:open-api-dart`            | 仅在 [`open-api/immich-openapi-specs.json`](../open-api/immich-openapi-specs.json) 已与 Server 同步时使用；跨 consumer contract 变更默认仍用完整 `mise //:open-api`。 |
| Server database schema/function/trigger | `pnpm --dir server run migrations:generate <name>`                  | input 位于 [`server/src/schema/`](../server/src/schema/)；生成后按[数据库迁移](../docs/docs/developer/database-migrations.md)放置并审查 migration。                   |
| Mobile Dart generated code              | `mise //mobile:codegen`                                             | 默认入口，覆盖 Dart build runner、Drift schema test code、Pigeon、translations 与 Dart SDK dependency chain。只有明确理解依赖时才使用窄 task。                        |
| Mobile Drift schema/migration           | `mise //mobile:drift:migration`，然后 `mise //mobile:codegen`       | 同时更新 saved schema、generated migration helpers、旧版本升级测试和 sync mapping。                                                                                   |
| Mobile Pigeon API                       | `mise //mobile:codegen:pigeon` 或完整 `mise //mobile:codegen`       | source 位于 [`mobile/pigeon/`](../mobile/pigeon/)；生成后必须同步 Android/iOS implementation 和 registration。                                                        |
| Translation key/catalog                 | `mise //:i18n:format-fix`，然后 `mise //mobile:codegen:translation` | source 从 [`i18n/en.json`](../i18n/en.json) 开始；同时验证 Web typed keys/loaders 与 Mobile generated files。                                                         |
| 仅文档或内部指南                        | 不启动应用 stack                                                    | 只格式化目标文档、验证相对链接和命令名；测试选择见[内部测试指南](testing-guide.md)。                                                                                  |

## 跨模块变更顺序

### API 与 SDK

API contract 的依赖方向固定为：

`Server controller/DTO` → `OpenAPI spec` → `TypeScript SDK + Dart SDK` → `Web/Mobile/CLI/E2E consumers`

1. 在 Server 中修改 controller、DTO、validation 与 service behavior，并先补 Server tests。
2. 运行 `mise //:open-api`。该入口会 build Server、同步 [`open-api/immich-openapi-specs.json`](../open-api/immich-openapi-specs.json)，再生成 TypeScript 与 Dart clients。
3. 审查 spec 和 generated diff，特别是 required/optional、nullable、enum、pagination、response shape 与 operation name。
4. TypeScript client 生成到 [`packages/sdk/src/fetch-client.ts`](../packages/sdk/src/fetch-client.ts)，Dart client 生成到 `mobile/generated/openapi/`。不要直接修补这些文件；generator 行为应修改 [`open-api/`](../open-api/) 中的 templates、patches 或 scripts。
5. 最后更新 Web、Mobile、CLI、E2E 与公开 API 文档等 affected consumers，并按[内部测试指南](testing-guide.md)选择验证层。

如果 contract 还依赖 database 变化，先完成下节 migration，再回到上述 API 顺序；不要让 SDK 描述一个尚未有持久化升级路径的行为。

### Server database migration

Database 变更的顺序是：

`server/src/schema` → `generated migration` → `repository/service` → `API contract` → `SDK/consumers`

1. 修改 [`server/src/schema/`](../server/src/schema/) 中的 authoritative schema、function 或 trigger。
2. 运行 `pnpm --dir server run migrations:generate <migration-name>`，按[数据库迁移](../docs/docs/developer/database-migrations.md)移动生成文件，并审查 SQL 是否只包含预期差异。
3. 评估 index build、table lock、data backfill、nullable/default transition、large library cost 与 upgrade compatibility。不要只验证空 database。
4. 更新 repository/service 与 migration/medium tests；涉及 API shape 时，再执行完整 OpenAPI/SDK 流程。
5. 如需本地撤销最近一次 migration，运行 `pnpm --dir server run migrations:revert`；不要把可本地回滚等同于支持生产环境跨未知 migration downgrade。

### Mobile Drift、Pigeon 与其他 codegen

Mobile generated files 由 [`mobile/mise.toml`](../mobile/mise.toml) 管理。默认运行 `mise //mobile:codegen`，只有在缩小反馈循环且确认依赖已满足时才使用子 task。

**Drift**

1. 修改 table/DAO/database version 与 migration strategy。
2. 运行 `mise //mobile:drift:migration` 生成 migration artifacts。
3. 运行 `mise //mobile:codegen`，更新 Dart code 与 [`mobile/drift_schemas/main/`](../mobile/drift_schemas/main/) 对应的 schema test code。
4. 更新 [`mobile/test/drift/main/migration_test.dart`](../mobile/test/drift/main/migration_test.dart)，覆盖现存用户从旧 schema 升级；同步检查 local/remote ID、sync mapping 与 conflict behavior。

**Pigeon**

1. 先修改 [`mobile/pigeon/`](../mobile/pigeon/) 中的 cross-platform interface。
2. 运行 `mise //mobile:codegen:pigeon`；生成 Dart、Swift、Kotlin interfaces 后审查 signature 与 nullability diff。
3. 更新 Android/iOS implementations、registration 与 Dart caller，最后运行相关 unit/integration tests。只改某一平台实现会留下编译时或运行时断链。

**Freezed、AutoRoute 与其他 Dart inputs**

修改 annotated model、route 或其他 build runner input 后运行完整 `mise //mobile:codegen`。Generated files 用于 review，不应成为手工实现入口。

### i18n 与 generated resources

i18n 的依赖方向是：

`i18n/en.json` → `catalog formatting` → `Web typed consumption + Mobile generation`

1. 新 key 或英文 source text 先进入 [`i18n/en.json`](../i18n/en.json)，再运行 `mise //:i18n:format-fix`；不要从 generated Dart 文件反推 source。
2. Web 通过 [`web/src/app.d.ts`](../web/src/app.d.ts) 从英文 catalog 推导 typed translations，并由 [`web/src/lib/utils/i18n.ts`](../web/src/lib/utils/i18n.ts) lazy-load catalogs。检查 key、placeholder、fallback 与 locale loading。
3. 运行 `mise //mobile:codegen:translation`，更新 `mobile/lib/generated/codegen_loader.g.dart` 和 `mobile/lib/generated/translations.g.dart`。不要手工修改这些 outputs。
4. 同一 key 被 Web 和 Mobile 使用时，两端必须在同一变更中通过 type/static analysis；删除或重命名 key 前先搜索全部 consumers。

## 组合变更的推荐排序

| 组合场景                     | 推荐顺序                                                                                                             |
| ---------------------------- | -------------------------------------------------------------------------------------------------------------------- |
| Database + API + clients     | schema → migration → repository/service → controller/DTO → OpenAPI → both SDKs → Web/Mobile/E2E → tests/docs         |
| API only                     | controller/DTO → Server tests → OpenAPI → both SDKs → affected consumers → tests/docs                                |
| Mobile local database + sync | Drift schema/migration → saved schema/codegen → migration tests → sync mapping → UI/state consumer                   |
| Mobile native feature        | Pigeon source → generated interfaces → Android/iOS implementations → registration → Dart consumer → integration test |
| Shared translation           | English catalog → catalog format → Mobile translation generation → Web/Mobile consumer checks                        |

Contract、migration 或 generated artifact 失败时，回到最左侧的 authoritative input 修复，再顺序重跑；不要在下游 consumer 叠加 workaround。

## Worktree 与 scope 纪律

- 一个 worktree/branch 保持一个可说明的 topic；开始和结束都运行 `git status --short`，并用 `git diff -- <scoped-paths>` 区分本次变更与已有工作。
- 生成前记录预期 outputs。生成器改动大量文件时，只保留由本次 input 可解释的 diff；不要借机做 repository-wide format 或依赖升级。
- 跨模块不等于扩大需求。只更新 contract 的直接 consumers、必要 tests 与 docs；新 feature、兼容策略或 destructive migration 需要单独确认。
- 不提交 local secrets、signing overrides、database data、build cache 或 IDE artifacts。目录归属不明确时先查[目录说明](../docs/docs/developer/directories.md)。

## 完成检查

1. 用 `git status --short` 和 scoped diff 确认文件集合与变更前声明的 scope 一致，没有覆盖其他 worktree 内容。
2. 对所有 changed files 运行所属模块 formatter；随后运行 `git diff --check`。
3. 涉及 OpenAPI、Drift、Pigeon 或 translations 时，再运行一次对应 generator，确认产物稳定且 generated diff 已纳入。
4. 先运行最接近变更的 unit/type/migration tests，再按[内部测试指南](testing-guide.md)和 [PR checklist](../docs/docs/developer/pr-checklist.md)补齐 affected module checks。
5. 检查 migration upgrade path、API backward compatibility、Mobile 双平台实现、i18n placeholder/fallback 与 relative links；未验证的风险在交接或 PR 中明确写出。
