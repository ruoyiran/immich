# Web 模块

`web/` 是 SvelteKit CSR client，通过生成的 `@immich/sdk` 与外部 `photo-classifier` API 通信。

## 结构

- `src/routes/`：route loading 与页面 orchestration；
- `src/lib/components/`：domain UI；
- managers/stores：long-lived client state；
- services：mutations 与 API coordination；
- `vite-proxy.ts`：开发时代理 `/api`、`/.well-known/immich` 和 `/custom.css`。

默认代理目标为 `http://127.0.0.1:8080`，可用 `IMMICH_SERVER_URL` 覆盖。Web build 产出静态客户端，不再复制进本仓库的 Server image。

## 契约

不要手改 `packages/sdk/src/fetch-client.ts`。API 变化先在外部服务器落地，再更新 OpenAPI snapshot 并运行 `mise //:open-api`。

## 验证

```bash
mise //web:test --run
mise //web:check
mise //web:build
mise //web:checklist
```

用户关键流程可在 `e2e/src/ui/` 增加 mocked-API Playwright coverage。真实 backend integration 在 `photo-classifier` 验证。
