# External Server 模块

服务器实现位于同级独立仓库 `../photo-classifier`，不属于本仓库 worktree。

## 职责

- Go/Gin HTTP API 与 Immich-compatible endpoints；
- session、API key 与访问控制；
- MySQL schema、migration 和 persistence；
- media upload、原图/缩略图读取、Live Photo、回收站；
- Rust pipeline 调度、分类、人脸、搜索和任务状态；
- deployment、runtime configuration 和生产验证。

## 本仓库接口

- `open-api/immich-openapi-specs.json`：提交的 client contract snapshot；
- `packages/sdk/`：Web/CLI TypeScript client；
- `mobile/generated/openapi/`：Mobile Dart client；
- Web `IMMICH_SERVER_URL`：开发代理目标，默认 `http://127.0.0.1:8080`。

## 变更规则

服务器行为先在 `photo-classifier` 实施。跨仓库 contract 变化随后更新 snapshot 和生成 clients；不要在本仓库重新创建 server adapter、database schema 或容器编排来绕过外部实现。

配置、启动、数据库和部署说明见 `../photo-classifier/README.md` 及其 `docs/`。
