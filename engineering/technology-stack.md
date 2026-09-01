# 技术栈

> 版本以 manifest、lockfile 和 `mise.toml` 为准；本页只列当前仓库与外部服务器边界。

| 范围            | 技术                                                  | 来源                                                   |
| --------------- | ----------------------------------------------------- | ------------------------------------------------------ |
| Toolchain       | Node 24.15.0、pnpm 11.17.0、Java 21.0.2               | `mise.toml`                                            |
| Web             | Svelte 5、SvelteKit 2、Vite 8、TypeScript、Vitest     | `web/package.json`                                     |
| Mobile          | Flutter 3.44.9、Dart 3.12+、Riverpod、Drift           | `mobile/pubspec.yaml`                                  |
| Browser E2E     | Playwright、mocked API responses                      | `e2e/package.json`                                     |
| API generation  | oazapfts、OpenAPI Generator                           | `mise.toml`、`open-api/`                               |
| Standalone ML   | Python 3.11+、FastAPI、ONNX Runtime providers、pytest | `machine-learning/pyproject.toml`                      |
| External server | Go 1.26.1、Gin、MySQL、Rust pipeline                  | `../photo-classifier/server/go.mod` 与该仓库 manifests |

## 不再属于本仓库的栈

NestJS、Express、Kysely、PostgreSQL、BullMQ、Valkey、Server Docker image 和数据库 migration 已随内置服务器删除。不要从历史 lockfile、文档或上游 README 推断它们仍是当前 runtime。

## 版本更新规则

1. 修改实际 manifest 或 `mise.toml`。
2. 更新 lockfile。
3. 运行所属模块 checklist。
4. 只有主要框架或工具链发生变化时才更新本页。
