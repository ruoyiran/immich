# Server Agent 指南

## 适用范围

本文件适用于 `server/**`，并继承仓库根目录 [`../AGENTS.md`](../AGENTS.md) 的全局规则。

## 开始前阅读

- [Server 模块说明](../engineering/modules/server.md)
- [系统架构](../engineering/architecture.md)
- [数据库迁移](../docs/docs/developer/database-migrations.md)
- [公开测试指南](../docs/docs/developer/testing.md)

## 架构规则

- 将 HTTP、auth 和 DTO 相关职责放在 `src/controllers/`。
- 将领域编排以及 job/event 生产放在 `src/services/`。
- 将 database、queue、storage、WebSocket、ML 和外部 adapter 放在 `src/repositories/`。
- 将 `src/schema/` 视为数据库 schema 的权威来源。
- 使用 `src/*` 和 `test/*` import alias；Server lint 禁止相对 import。
- 每个 endpoint 都必须用 `@Authenticated()` 明确声明预期 policy。
- 每个 queue 必须且只能有一个 `@OnJob` handler。

## 生成物与联动变更

- 不要手工修改生成的 OpenAPI 输出或 SDK client。
- Controller、DTO 或 API 变化需运行 `mise //server:sync-open-api` 或根级 `mise //:open-api`，再检查受影响的 SDK、Web、Mobile 和 E2E。
- Schema、function 或 trigger 变化需通过 `pnpm --dir server run migrations:generate <name>` 生成 migration；审查 SQL，并运行 migration/medium tests。
- Queue contract 变化必须同步更新 producer、唯一 handler、retry/idempotency 行为和 worker deployment 假设。
- ML request/response 变化必须同时验证 `machine-learning/` 和调用它的 job/service。
- Storage layout 变化需要检查 mount integrity、upgrade 和 backup。

## 验证

先选择最小相关命令：

- Unit tests：`mise //server:test`
- PostgreSQL medium tests：`mise //server:test-medium`
- Build/type checks：`mise //server:check`
- 完整模块检查：`mise //server:checklist`

涉及 API、schema、queue、auth、storage 或 worker 的跨域变更时运行完整 checklist。Medium tests 需要可用的 container runtime。

## 高风险检查

- Authorization 同时测试允许与拒绝路径。
- 确认 migration 支持目标 upgrade path；不要假定能够从未知 migration downgrade。
- 确认 job handler 在启动时仍然唯一且可发现。
- 确认拆分 worker 共享兼容的 PostgreSQL、Valkey、media storage 和 config。
- Remote Machine Learning 没有内建认证，只能放在可信网络中。
- 在相关测试和生成 contract 检查通过前，不要宣称完成。
