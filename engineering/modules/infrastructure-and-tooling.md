# Infrastructure 与 Tooling

> 用途：说明 repository task system、containers、共享基础设施、CI、E2E、build/release 与 deployment 工具边界。  
> 权威来源：根/模块 `mise.toml`、`docker/`、`e2e/`、`.github/workflows/`、`server/Dockerfile` 与 `deployment/`。  
> 更新触发：workspace task、Compose service、storage/database/queue、CI job、E2E environment、image build 或 deployment 配置变化。

## Root mise 与 pnpm workspace

根 [`mise.toml`](../../mise.toml) 定义：

- pinned toolchain；
- monorepo project roots；
- OpenAPI/SDK/plugin generation；
- Docker dev/prod/e2e orchestration；
- release 与 cross-project tasks。

模块 `mise.toml` 将 package scripts、Flutter、uv 或 deployment commands 暴露为统一 task namespace。查看真实 task 使用：

```bash
mise tasks ls --all --name-only
mise tasks info //server:checklist
```

根 [`pnpm-workspace.yaml`](../../pnpm-workspace.yaml) 和 [`package.json`](../../package.json) 管理 Node workspace。pnpm lockfile 是 resolved dependency 权威来源。

task 是开发入口，不代表每个 task 都是 CI mandatory。CI 门禁以 workflow 实际调用为准。

## Docker 与 Compose

主要文件：

- [`docker/docker-compose.yml`](../../docker/docker-compose.yml)：release installation topology；
- [`docker/docker-compose.dev.yml`](../../docker/docker-compose.dev.yml)：本地开发；
- [`docker/docker-compose.prod.yml`](../../docker/docker-compose.prod.yml)：repository production build；
- [`docker/docker-compose.rootless.yml`](../../docker/docker-compose.rootless.yml)：rootless installation variant；
- [`server/Dockerfile`](../../server/Dockerfile)：Server/Web production image build。

常用入口：

- `mise //:dev`
- `mise //:dev-down`
- `mise //:dev-update`
- `mise //:dev-scale`
- `mise //:prod`
- `mise //:prod-down`

`docker-compose.yml` 主分支文件可能面向下一版本，不保证与 latest release 完全兼容。用户安装应使用公开安装指南指定的 release Compose。

## 共享基础设施

### PostgreSQL

PostgreSQL 保存业务 metadata、schema state、vector/search、faces 和 OCR 结果。Compose image 包含 vector extensions。database volume 与 media storage 是不同备份对象。

Database 变化需检查：

- migration 与 extension compatibility；
- index/build time；
- backup/restore；
- data checksums/storage class；
- rolling upgrade/downgrade assumptions。

### Valkey

Valkey 提供 Redis-compatible queue/pub-sub：

- BullMQ job data；
- API/microservices coordination；
- multi-instance WebSocket adapter；
- selected temporary/distributed state。

更换/升级时需要验证 BullMQ 和 Socket.IO adapter compatibility，而不是只验证 `PING`。

### Media storage

Server container 将 host `UPLOAD_LOCATION` 挂载到 `/data`。不要把 container-internal `IMMICH_MEDIA_LOCATION` 误当作 host path setting。

所有 API/worker 实例必须看到同一 media tree。改变 layout、mount 或 permissions 时运行 storage integrity checks，并更新 backup/upgrade documentation。

### Machine Learning cache

ML container 使用独立 `/cache` volume 保存 models。它不是业务 media/database backup 的一部分，但丢失会造成重新下载和 cold start。

## CI workflows

`.github/workflows/` 是 enforced CI behavior 的权威来源。主要类别：

- static analysis/format/lint；
- Server/Web/Mobile/ML unit tests；
- Server medium tests；
- OpenAPI generation/compatibility；
- API/browser E2E；
- image/platform build；
- release/deploy automation。

workflow 常调用 `mise` task，但也可能传入 CI-specific args、matrix、service/container 或 artifact。内部文档只能把 workflow 实际执行的步骤称为 CI gate。

任务/CI 变化应同步检查 [测试指南](../testing-guide.md) 和相关 scoped `AGENTS.md`。

## E2E

[`e2e/`](../../e2e/) 包含两类验证：

### API E2E

Vitest 通过真实 API 与测试环境验证 auth、asset、album、sharing、sync 等 contract/behavior。setup 会准备 database/services 并生成 OpenAPI/SDK dependencies。

入口：

- `mise //:e2e`
- `mise //e2e:ci-setup`
- `mise //e2e:test`

### Browser E2E

Playwright config 定义 Web、UI、maintenance 等 Desktop Chrome projects，并可启动 Docker test environment。用户可见的 route/auth/shared-link/asset-viewer/maintenance 变化应评估 browser coverage。

入口：

- `mise //e2e:test-web`
- package scripts in [`e2e/package.json`](../../e2e/package.json)

E2E 较慢且依赖 container/browser；先运行模块 focused tests，再用 E2E 覆盖跨服务或用户关键路径。

## Build 与 release images

Server production Dockerfile 的主要阶段：

1. 安装/build plugin/SDK dependencies；
2. build Server；
3. build Web static output；
4. 准备 runtime dependencies 与 system tools；
5. 将 `web/build` 复制到 Server runtime；
6. 生成 release image。

因此 Web build、SDK 和 Server build 不是完全独立的 release artifacts。改变 build path、static output 或 runtime system dependency 时必须检查 Dockerfile stages 和 CI image build。

Mobile release 使用 platform build、Fastlane 和 CI workflows；本手册不复制 signing credentials/process。

## Deployment

[`deployment/`](../../deployment/) 包含 OpenTofu/Terraform/Terragrunt 配置。根 task 提供：

- `mise //deployment:tf:init`
- `mise //deployment:tf`
- `mise //deployment:tf:fmt`
- `mise //deployment:tg:fmt`

Infrastructure mutation 可能影响真实外部资源；除非用户明确授权，不执行 apply/destroy 或 credential-bearing operation。文档和 format/validate 可以只读或局部执行。

## 最小验证入口

| 变更              | 最小入口                                                                 |
| ----------------- | ------------------------------------------------------------------------ |
| Root task/config  | 受影响 task 的 `mise tasks info` 与 `mise run --dry-run <task>`          |
| Dev Compose       | `docker compose config`，再按授权运行 `mise //:dev`                      |
| Server/Web image  | 对应 build + Docker image build workflow                                 |
| API E2E           | `mise //e2e:test`                                                        |
| Browser E2E       | `mise //e2e:test-web`                                                    |
| CI workflow       | workflow syntax/action references + 被调用 local task                    |
| Public docs       | `mise //docs:format`；MDX/config/navigation 高风险时 `mise //docs:build` |
| Deployment format | `mise //deployment:tf:fmt`、`mise //deployment:tg:fmt`                   |

在当前核对基线和 `mise 2026.8.3` 下，`mise tasks validate` 会对 `//:open-api` 的三个可解析 Server task 产生 `missing-task-reference` 基线错误；在 task graph 或工具兼容性修复前，不把该命令零退出作为文档变更的完成条件。

当前环境若 `mise` 因工具安装或网络限制不可用，可以运行 task 中声明的等价 package command 做局部诊断，但最终文档仍以 repository task 为 canonical entry。

## 源码导航

| 主题              | 路径                                                         |
| ----------------- | ------------------------------------------------------------ |
| Root tasks/tools  | [`mise.toml`](../../mise.toml)                               |
| pnpm workspace    | [`pnpm-workspace.yaml`](../../pnpm-workspace.yaml)           |
| Compose           | [`docker/`](../../docker/)                                   |
| Production image  | [`server/Dockerfile`](../../server/Dockerfile)               |
| E2E               | [`e2e/`](../../e2e/)                                         |
| Playwright config | [`e2e/playwright.config.ts`](../../e2e/playwright.config.ts) |
| API E2E config    | [`e2e/vitest.config.ts`](../../e2e/vitest.config.ts)         |
| CI                | [`.github/workflows/`](../../.github/workflows/)             |
| Deployment        | [`deployment/`](../../deployment/)                           |
| Mobile release    | [`fastlane/`](../../fastlane/)、[`mobile/`](../../mobile/)   |
