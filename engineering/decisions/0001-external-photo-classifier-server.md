# ADR-0001：将服务器端迁移到外部 photo-classifier 仓库

- 状态：Accepted
- 日期：2026-09-02
- 决策者：仓库维护者
- 替代：无

## 背景

本仓库当前同时包含 Immich Web、Mobile、OpenAPI/SDK、原 NestJS Server、Server 专用 Docker/CI/E2E 和工程说明。实际使用的服务器端已经迁移到本仓库同级目录 `../photo-classifier`：该仓库以 Go 提供 HTTP API，并负责认证、上传、持久化、后台任务和 Immich 客户端兼容接口。

继续保留本仓库的 `server/` 会形成两个服务器端事实源。仅删除源码而保留 workspace、task、Docker、CI 或 E2E 入口，又会留下无法执行的配置。

## 决策

本仓库调整为客户端与客户端契约仓库，服务器端职责由 `photo-classifier` 独立拥有。

- 删除本仓库原有的 `server/` 目录及其本地生成缓存。
- 删除或调整只为原 Server 服务的 pnpm workspace、mise task、Docker、devcontainer、CI、CODEOWNERS、label 和 E2E 配置。
- 保留 `open-api/`、生成的 TypeScript/Dart SDK、Web 和 Mobile，作为客户端编译及兼容契约；本仓库不再从本地 Server 重新生成 OpenAPI spec。
- `photo-classifier` 是 API 行为、认证、数据库、上传、后台任务和服务器部署的权威来源。服务器端变更与验证必须在该仓库完成。
- 本仓库不通过 task 或构建配置硬编码 `../photo-classifier`。Web 使用 `IMMICH_SERVER_URL` 连接外部后端，Mobile 使用运行时配置的服务器地址。
- 保留 `machine-learning/`，但它不属于当前 `photo-classifier` 后端的运行链路；后端实际使用的模型服务和推理契约以 `photo-classifier` 文档为准。
- 保留与客户端自身有关的 unit、static 和 mock-based UI 测试；删除依赖原 NestJS Server 镜像、数据库拓扑或 maintenance runtime 的测试入口。

## 仓库边界

本仓库负责：

- Web 与 Mobile 客户端实现；
- 客户端使用的 OpenAPI snapshot、TypeScript SDK 和 Dart SDK；
- 客户端 package、UI、本地化、构建和发布流程；
- 不依赖原 NestJS runtime 的客户端测试。

`photo-classifier` 负责：

- HTTP API 与 Immich compatibility endpoints；
- 身份认证、session 和 API key；
- MySQL schema、数据迁移与持久化；
- 媒体上传、读取、回收站和后台 pipeline；
- 服务器部署、配置、日志和服务器端测试。

## 备选方案

### 在本仓库任务中直接调用 `../photo-classifier`

未采用。它会让 checkout 布局成为隐藏的构建依赖，使本仓库无法独立安装、检查或在 CI 中运行。

### 只删除 `server/`，保留其余配置

未采用。workspace、mise、Docker、CI、OpenAPI 同步和 E2E 会继续引用不存在的文件或任务。

### 将 photo-classifier 作为 submodule 或 vendor 目录引入

未采用。当前目标是明确仓库职责，不是重新把服务器端纳入本仓库；引入 submodule 还会增加版本锁定和发布协调成本。

## 影响

- 本仓库不再能够构建或启动原 Immich Server 镜像。
- 原 Server unit/medium/API/maintenance E2E 和 SQL schema freshness 检查会被移除。
- OpenAPI spec 成为受版本控制的客户端兼容快照；更新时必须先在 `photo-classifier` 核对实际兼容接口，再在本仓库重新生成客户端。
- Web/Mobile 的后端集成验证需要连接独立运行的 `photo-classifier`，其启动和测试命令不属于本仓库 task graph。
- 原 Immich 公开文档中只适用于 NestJS Server 的开发和部署说明不再代表当前仓库；工程入口需明确指向 `photo-classifier` 的 README 与架构文档。
- 本次修改不得覆盖现有 Mobile iOS `Package.resolved` 用户改动。

## 验证

- `git ls-files server` 不返回文件，工作区中不存在 `server/`。
- `pnpm-workspace.yaml`、`mise.toml`、`.github/workflows/`、`.devcontainer/` 和保留的 E2E 配置不再引用原 Server 路径或 task。
- `mise tasks ls --all --name-only` 不包含 `//server:*`，保留任务均可解析。
- OpenAPI 的 TypeScript/Dart 客户端生成入口不依赖本地 Server。
- 更新后的工程文档相对链接有效，且没有把 `machine-learning/` 描述为当前后端运行依赖。
- 对所有变更运行相应 formatter，并运行 `git diff --check`。
