# Infrastructure 与 Tooling

## 当前范围

根 `mise.toml` 组合 Web、Mobile、ML、E2E、docs、SDK、CLI、plugins 和 deployment tasks。仓库不再拥有 Server build、database task、Server Docker image、Compose stack 或 devcontainer。

`.github/workflows/` 负责客户端、ML、文档、contract generation 和发布检查。Server image build、Server unit/medium tests、real-server E2E 和 SQL schema checks 已移除。

## E2E

`e2e/` 只运行 Playwright UI project：

- Vite 启动 Web；
- route handlers mock API responses；
- 不启动 database、Redis、Docker Compose 或外部服务器。

```bash
mise //e2e:ci-unit
mise //e2e:test
```

## OpenAPI

```bash
mise //:open-api
mise //:sdk:build
```

该流程从提交的 snapshot 生成 clients，不构建本地服务器。

## 发布与部署边界

`deployment/` 可继续维护独立基础设施代码，但本仓库不提供 `docker-compose.yml`、server environment template 或一键服务器安装脚本。Server deployment 由 `../photo-classifier` 管理。

## 核验

```bash
mise tasks ls --all --name-only
mise //web:check
mise //e2e:ci-unit
mise //docs:format
git diff --check
```
