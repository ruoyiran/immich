# Web Agent 指南

## 适用范围

适用于 `web/**`，并继承 [`../AGENTS.md`](../AGENTS.md) 中的仓库级规则。

## 开始前阅读

- [Web 模块指南](../engineering/modules/web.md)
- [系统架构](../engineering/architecture.md)
- [公开开发环境配置](../docs/docs/developer/setup.md)
- [公开测试指南](../docs/docs/developer/testing.md)

## 架构规则

- 将 Web 视为 SvelteKit CSR SPA；`ssr=false` 是有意设计。
- Route loading/orchestration 放在 `src/routes/`，domain UI 放在 `src/lib/components/`，long-lived state 放在现有 managers/stores，mutations 放在 services。
- 遵循相邻 domain 的 state ownership 模式。局部变更不要引入新的 global state abstraction。
- 在 root initialization 保证 manager state 就绪前，不要读取该 state。
- 保持 same-origin redirect validation 和可选 asset-viewer route 的行为。

## 生成文件与联动变更

- 绝不手工编辑 `../packages/sdk/src/fetch-client.ts`。
- 修改 Web consumer 前，API type 变更必须通过根级 `mise //:open-api` generation path 传递。
- Shared-link API 调用必须传递 `authManager.params` 的 key/slug context。
- WebSocket/event 变更必须确保 Server producer、typed event、manager consumer 与 reconnect recovery 保持一致。
- Translation key 变更必须更新根 `i18n/` sources 以及生成或 typed consumers。
- 将 service worker 视为 media request coordination，不要将其视为 offline media cache。

## 验证

优先选择最窄的相关命令：

- 单次 unit/component tests：`mise //web:test --run`
- Svelte 与 TypeScript checks：`mise //web:check`
- Build：`mise //web:build`
- 完整模块 gate：`mise //web:checklist`
- 需要时运行 coverage：`pnpm --dir web test:cov`

当面向用户的 route、shared-link、auth、modal、asset-viewer 或 maintenance flow 发生变化时，在 `e2e/` 中增加 Playwright coverage。

## 高风险检查

- Shared-link 行为应与普通 authenticated 行为分开测试。
- Route 变更后检查 deep links、browser history 与 same-origin redirect handling。
- Manager/store 变更后检查 reactive capture 与 persisted defaults。
- 确保 Web 仍能基于重新生成的 SDK output 完成 build。
- 不要根据 service-worker request coalescing 宣称支持 offline。
