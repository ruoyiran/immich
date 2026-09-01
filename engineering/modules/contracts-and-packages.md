# Contracts 与 Packages

## OpenAPI snapshot

`open-api/immich-openapi-specs.json` 是本仓库生成客户端的提交输入。服务器实现位于 `../photo-classifier`，因此 snapshot 不再由本地 controller/DTO 自动生成。

生成链：

```text
photo-classifier API semantics
  -> open-api/immich-openapi-specs.json
  -> packages/sdk/src/fetch-client.ts
  -> mobile/generated/openapi/
  -> Web / Mobile / CLI consumers
```

运行 `mise //:open-api` 生成 TypeScript 和 Dart clients。生成输出不得手工编辑。

## Packages

- `packages/sdk/`：生成 TypeScript client 与 runtime helper；
- `packages/cli/`：服务器 API client，保留；
- `packages/plugin-core/`、`packages/plugin-sdk/`：plugin contract 与 SDK；
- `packages/scripts/`：repository automation。

旧的 `packages/e2e-auth-server/` 已随真实服务器 E2E harness 删除。

## 验证

```bash
mise //:sdk:build
mise //packages/cli:checklist
mise //packages/plugin-core:build
```

生成变更还需确认 `packages/sdk/` 与 `mobile/generated/openapi/` 的 diff 都来自同一 snapshot。
