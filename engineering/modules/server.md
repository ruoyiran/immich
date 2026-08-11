# Server 模块

> 用途：说明 Server 的进程模型、内部层次、持久化、queue、实时通信与高风险变更。  
> 权威来源：`server/src/`、`server/test/`、`server/mise.toml`、`server/package.json` 与数据库迁移文档。  
> 更新触发：worker 模式、controller/service/repository 边界、schema、queue、WebSocket、ML 或 OpenAPI 流程变化。

## 职责

Server 是 Immich 的业务与持久化中心，负责：

- `/api` HTTP、authentication、authorization 与 request/response validation；
- Web 静态资源和共享链接 metadata 注入；
- 用户、资产、相册、共享、搜索、审计、workflow 等领域逻辑；
- PostgreSQL schema、migration、query 与 transaction；
- 媒体文件写入、读取、派生文件与挂载完整性；
- BullMQ job 生产/消费、scheduled work 和 event dispatch；
- WebSocket 实时通知与多实例 pub/sub；
- 调用 Machine Learning 服务并持久化结果；
- 生成 OpenAPI contract 供 SDK、clients、tests 和 docs 使用。

跨模块拓扑见 [系统架构](../architecture.md)。

## 运行入口与进程模型

[`server/src/main.ts`](../../server/src/main.ts) 是 supervisor。默认启动：

- API child process：入口 [`server/src/workers/api.ts`](../../server/src/workers/api.ts)，创建 `ApiModule`；
- microservices worker thread：入口 [`server/src/workers/microservices.ts`](../../server/src/workers/microservices.ts)，创建 `MicroservicesModule`；

进入 maintenance mode 时，上述常规 workers 不会启动；supervisor 只启动 [`server/src/workers/maintenance.ts`](../../server/src/workers/maintenance.ts) 执行维护任务。

公共 repository/service/event/queue/telemetry 装配位于 [`server/src/app.module.ts`](../../server/src/app.module.ts)。HTTP 通用设置位于 [`server/src/app.common.ts`](../../server/src/app.common.ts)，包括 `/api` prefix、Zod validation/serialization、auth guard、exception/logging interceptors 和 Web fallback。

worker 可通过 `IMMICH_WORKERS_INCLUDE`/`IMMICH_WORKERS_EXCLUDE` 拆分部署。拆分只改变职责分配，不改变共享 PostgreSQL、Valkey 和媒体存储的要求。

## Controller-Service-Repository 分层

### Controllers

`server/src/controllers/` 负责 transport boundary：

- route、request parsing、upload interceptor；
- authentication/permission metadata；
- DTO 与 OpenAPI metadata；
- 调用 service 并返回 response。

每个 endpoint 必须显式声明 `@Authenticated()`；auth guard 会检查缺失 metadata，不能把“默认受保护”当成隐式行为。

### Services

`server/src/services/` 负责领域流程、transaction orchestration、event/job producer 与跨 repository 组合。多数 service 继承 [`BaseService`](../../server/src/services/base.service.ts) 以复用核心 repository 和 storage 依赖。

Service 不应把 HTTP transport 细节泄漏给 repository，也不应绕过 schema/migration 直接制造持久化差异。

### Repositories

`server/src/repositories/` 封装：

- PostgreSQL/Kysely；
- BullMQ/Valkey；
- filesystem/storage；
- WebSocket/pub-sub；
- Machine Learning HTTP；
- external services 与 system integration。

新增 import 使用 `src/*`、`test/*` alias；Server ESLint 禁止相对 import。

## Schema 与持久化

[`server/src/schema/`](../../server/src/schema/) 是 database model、function、trigger 和 migration input 的实现权威。它覆盖 asset、user、album、face、search、OCR、audit、workflow、plugin 等数据。

修改 schema 时：

1. 修改 schema source。
2. 使用 `pnpm --dir server run migrations:generate <name>` 生成 migration。
3. 审查 SQL、index、lock 和 data migration 影响。
4. 运行 migration/medium tests。
5. 检查 upgrade 与 backup assumptions。

Server 启动会验证 PostgreSQL/extensions、执行 migration、检查 schema drift 并准备 vector indexes。数据库含有未知 migration 时不支持简单降级。

原始媒体不存进 PostgreSQL。默认容器内 media root 是 `/data`，Server 启动会执行挂载读写完整性检查。数据库备份不能替代媒体文件备份。

公开流程见 [数据库迁移文档](../../docs/docs/developer/database-migrations.md)。当前 `mise //server:migrations` task 指向仓库中不存在的 `dist/bin/migrations.js`；在 task 修复前，以 `server/package.json` 中的 `migrations:*` scripts 为可执行入口。

## Queue、event 与 worker

BullMQ job 的关键角色：

- Service 产生 job；
- queue repository 创建 worker 和注册处理器；
- microservices process 消费；
- system config 控制 concurrency；
- event/job decorators 由 discovery 机制收集。

每个 queue 必须且只能有一个 `@OnJob` handler。缺失或重复 handler 会导致 worker 启动失败。job contract 变化必须同时检查 producer、handler、retry/idempotency 和 deployment worker selection。

主要入口：

- [`server/src/services/job.service.ts`](../../server/src/services/job.service.ts)
- [`server/src/repositories/job.repository.ts`](../../server/src/repositories/job.repository.ts)
- [`server/src/services/queue.service.ts`](../../server/src/services/queue.service.ts)
- [`server/src/decorators.ts`](../../server/src/decorators.ts)

领域 event 使用 `@OnEvent`；workflow execution 还可以通过 Extism 运行受限 WASM plugin。plugin contract 变化需要检查 `packages/plugin-core/` 与 `packages/plugin-sdk/`。

## WebSocket 与横向扩展

Server WebSocket path 与 `/api` 数据共同驱动 Web/Mobile 增量更新。多实例通过 Redis adapter/pub-sub 传播事件。

扩展 API 或 worker 时必须共享：

- PostgreSQL；
- Valkey/Redis-compatible service；
- media storage；
- compatible config 和 migration level。

WebSocket 不是持久化 owner。event 丢失后客户端应能通过 reload/sync 恢复。

相关入口：

- [`server/src/middleware/websocket.adapter.ts`](../../server/src/middleware/websocket.adapter.ts)
- [`server/src/repositories/websocket.repository.ts`](../../server/src/repositories/websocket.repository.ts)

## Machine Learning 集成

[`MachineLearningRepository`](../../server/src/repositories/machine-learning.repository.ts) 将 media preview/request 发送到配置的 ML URLs。多个 URL 按健康状态回退，不等同于自动负载均衡。

ML 返回 embeddings、faces、OCR 等结果后，Server service/repository 写入 PostgreSQL。改变 request/response 时需要同步验证 Python service 和相关 job/service。

部署与认证边界由 [Machine Learning 安全与部署约束](machine-learning.md#安全与部署约束) 统一维护。

## 最小开发与测试入口

完整 setup/how-to 见 [公开开发文档](../../docs/docs/developer/setup.md) 和 [测试指南](../../docs/docs/developer/testing.md)。常用入口：

| 目的                     | 命令                                               |
| ------------------------ | -------------------------------------------------- |
| 安装 Server dependencies | `mise //server:install`                            |
| 单元测试                 | `mise //server:test`                               |
| PostgreSQL medium tests  | `mise //server:test-medium`                        |
| build/type checks        | `mise //server:check`                              |
| 完整 Server checklist    | `mise //server:checklist`                          |
| 生成 migration           | `pnpm --dir server run migrations:generate <name>` |
| 同步 OpenAPI             | `mise //server:sync-open-api`                      |

先运行与改动相邻的 spec/medium test，再根据风险运行 checklist。Testcontainers medium tests 需要可用的 container runtime。

## 生成物与高风险变更

| 变更                    | 额外要求                                                          |
| ----------------------- | ----------------------------------------------------------------- |
| Controller/DTO/API      | OpenAPI sync、TS/Dart SDK generation、consumer/E2E checks         |
| Schema/function/trigger | migration、medium/migration tests、upgrade review                 |
| Queue/job               | producer/handler 唯一性、retry/idempotency、worker selection      |
| Storage path/layout     | mount integrity、migration/upgrade、backup docs                   |
| Auth/permission         | endpoint metadata、negative authorization tests                   |
| WebSocket event         | Server event producer、Web/Mobile consumers、recovery path        |
| ML contract             | Python service、Server repository/service、job behavior、安全边界 |
| Plugin workflow         | plugin packages、Extism/WASM compatibility、execution limits      |

OpenAPI spec 和 clients 是生成物，不手改生成输出。

## 已知约束

- 所有 endpoint 显式 `@Authenticated()`，公开/可选身份也是显式策略。
- 每个 queue 恰好一个 `@OnJob` handler。
- Server source 使用 alias import，不使用相对 import。
- migration 会在启动时执行，未知 migration 阻止安全降级。
- media storage 与 database 需要独立备份。
- remote ML 只适合可信网络。
- 拆分 worker 的所有实例必须使用兼容的 shared infrastructure config。

## 源码导航

| 主题                      | 路径                                                         |
| ------------------------- | ------------------------------------------------------------ |
| Supervisor                | [`server/src/main.ts`](../../server/src/main.ts)             |
| API/microservices modules | [`server/src/workers/`](../../server/src/workers/)           |
| Controllers               | [`server/src/controllers/`](../../server/src/controllers/)   |
| Services                  | [`server/src/services/`](../../server/src/services/)         |
| Repositories              | [`server/src/repositories/`](../../server/src/repositories/) |
| Database schema           | [`server/src/schema/`](../../server/src/schema/)             |
| Tests                     | [`server/test/`](../../server/test/)                         |
| Tasks                     | [`server/mise.toml`](../../server/mise.toml)                 |
| Dependencies              | [`server/package.json`](../../server/package.json)           |
