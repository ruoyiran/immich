# 开发指南

## 按变更类型选择入口

| 变更                             | 实施位置                             | 本仓库动作                                    |
| -------------------------------- | ------------------------------------ | --------------------------------------------- |
| API、鉴权、database、upload、job | `../photo-classifier`                | 同步 OpenAPI snapshot，生成并验证 clients     |
| Web route/component/state        | `web/`                               | Web tests/check；用户流程补 mocked Playwright |
| Mobile UI/sync/local DB/native   | `mobile/`                            | 对应 tests、analysis、codegen/migration       |
| API client types                 | `open-api/immich-openapi-specs.json` | `mise //:open-api`                            |
| CLI/plugin package               | `packages/`                          | 运行 package task                             |
| 独立 ML service                  | `machine-learning/`                  | ML checklist；不默认改外部服务器              |
| CI/E2E/tooling                   | `.github/`、`e2e/`、`mise.toml`      | format、task discovery、相关 checks           |

## API contract 工作流

1. 在 `../photo-classifier` 实现并测试 API 行为。
2. 用实现的 contract 更新 `open-api/immich-openapi-specs.json`。
3. 运行 `mise //:open-api`，不要手改生成 clients。
4. 修复 Web、Mobile、CLI 和 E2E consumers。
5. 运行 SDK build 与受影响模块 checks。

本仓库没有 controller/DTO 到 OpenAPI 的本地同步步骤，也没有 database migration 命令。

## Web 本地开发

先按 `../photo-classifier/README.md` 启动 Go server（默认 `127.0.0.1:8080`），再运行：

```bash
mise //web:start
```

如服务器地址不同，设置 `IMMICH_SERVER_URL`。UI E2E 使用 mocked API，不启动真实服务器。

## Mobile 生成链

- OpenAPI：`mise //:open-api-dart`
- 全部 Mobile codegen：`mise //mobile:codegen`
- Drift migration：`mise //mobile:drift:migration`
- Pigeon：`mise //mobile:codegen:pigeon`

## 变更前后检查

- 用 `mise tasks ls --all --name-only` 确认任务存在。
- 保持改动聚焦，保留用户已有修改。
- 完成前运行格式化、最窄相关测试和 `git diff --check`。
