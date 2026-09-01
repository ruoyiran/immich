# Immich 客户端工程手册

> 用途：说明当前仓库的客户端架构、契约边界、开发入口和验证要求。
> 服务器实现：同级独立仓库 [`../../photo-classifier`](../../photo-classifier)。
> 架构决策：[ADR-0001](decisions/0001-external-photo-classifier-server.md)。

## 当前定位

本仓库维护 Immich Web、Mobile、生成 SDK、提交的 OpenAPI snapshot、mocked-API browser E2E，以及一个保留但不被当前服务器运行时使用的 Machine Learning 服务。原 NestJS Server、数据库迁移、Docker Compose、服务器 E2E 和发布镜像已移除。

`photo-classifier` 负责 Go/Gin API、MySQL persistence、媒体上传、任务编排、Rust pipeline 和部署。服务器行为、配置、数据库与生产验证以该仓库的源码、测试和 README 为准。

## 阅读路线

| 场景                     | 文档                                                                |
| ------------------------ | ------------------------------------------------------------------- |
| 理解运行边界             | [系统架构](architecture.md) → [模块地图](module-map.md)             |
| 修改 Web                 | [Web 模块](modules/web.md) → [开发指南](development-guide.md)       |
| 修改 Mobile              | [Mobile 模块](modules/mobile.md) → [开发指南](development-guide.md) |
| 修改 API contract 或 SDK | [Contracts 与 Packages](modules/contracts-and-packages.md)          |
| 修改 ML                  | [Machine Learning 模块](modules/machine-learning.md)                |
| 修改 CI、E2E 或工具链    | [Infrastructure 与 Tooling](modules/infrastructure-and-tooling.md)  |
| 选择测试                 | [测试指南](testing-guide.md)                                        |

## 权威来源

- 客户端行为：本仓库源码和测试。
- 服务器行为与数据库：`../photo-classifier` 源码和测试。
- 跨仓库 API 边界：服务器实现与本仓库 `open-api/immich-openapi-specs.json`；两者不一致时必须显式记录并修复。
- 生成任务与工具版本：`mise.toml`、各模块 manifest 和 lockfile。
- CI：`.github/workflows/`。

## 维护原则

1. 服务器语义先在 `photo-classifier` 实施和验证。
2. 再更新本仓库 OpenAPI snapshot，并运行 `mise //:open-api` 生成客户端。
3. 对 Web、Mobile 和 mocked browser E2E 做消费方验证。
4. 不在本仓库恢复服务器源码、数据库 migration 或服务器容器编排。
