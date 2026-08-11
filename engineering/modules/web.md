# Web 模块

> 用途：说明 Web client 的运行方式、目录边界、状态/API 数据流和高风险修改。  
> 权威来源：`web/src/`、`web/svelte.config.js`、`web/vite.config.ts`、`web/mise.toml` 与 `packages/sdk/`。  
> 更新触发：SSR/CSR 模式、route/layout、state ownership、SDK、WebSocket、i18n、service worker 或 Web test 配置变化。

## 职责与运行方式

Web 是 SvelteKit 应用，但当前运行模式是纯 CSR SPA：

- [`web/src/routes/+layout.ts`](../../web/src/routes/+layout.ts) 设置 `ssr = false`；
- [`web/svelte.config.js`](../../web/svelte.config.js) 使用 static adapter 和 `index.html` fallback；
- Vite 开发服务器在本地提供页面并代理 API；
- production build 复制到 Server image，由 Nest/sirv 托管静态资源；
- 浏览器通过生成的 TypeScript SDK 调用 `/api`。

因此不要把 Server 中名为 fallback/SSR 的 handler 误解为 Svelte server-side rendering。

## 路由与初始化

根初始化在页面进入业务 route 前完成关键依赖装配：

1. SvelteKit `fetch` 注入 SDK。
2. 加载语言和 locale。
3. 读取 server config、feature flags 和当前用户。
4. 建立长生命周期 manager/store。
5. route loader 调用 SDK 返回 typed `PageData`。

[`web/src/lib/utils/server.ts`](../../web/src/lib/utils/server.ts) 对初始化结果做 memoization。部分 manager getter 假设根初始化已完成；在 module load 或过早生命周期读取可能直接抛错。

路由 URL 由 [`web/src/lib/route.ts`](../../web/src/lib/route.ts) 集中构造。`continue` URL 需要同源校验，动态 UUID 使用 route matcher。修改 optional asset-viewer routes 时要同时检查 browser history、deep link 和 modal/page behavior。

## UI 与状态分层

主要目录职责：

| 路径                           | 职责                                                              |
| ------------------------------ | ----------------------------------------------------------------- |
| `src/routes/`                  | SvelteKit route、layout、page loader 与 route-level orchestration |
| `src/lib/components/`          | album、asset-viewer、timeline、faces、settings 等领域 UI          |
| `src/lib/elements/`            | 小型通用控件                                                      |
| `src/lib/managers/*.svelte.ts` | 基于 Svelte runes 的长生命周期领域状态/控制器                     |
| `src/lib/stores/`              | writable、legacy store、localStorage/persisted preferences        |
| `src/lib/services/`            | API mutation、confirmation、toast、error handling、domain event   |
| `src/lib/modals/`              | modal composition 与 lifecycle                                    |
| `src/lib/actions/`             | Svelte actions                                                    |
| `src/lib/utils/`               | 无 UI 工具、route/server/i18n helpers                             |
| `src/service-worker/`          | 媒体请求协调与取消                                                |
| `src/test-data/`、`tests/`     | factories、mocks 与 render helpers                                |

状态体系是混合式：Svelte 5 runes manager、writable store、persisted store 和自定义 cache 并存。新增状态应遵循相邻领域的现有 owner；不要为局部修改引入第二套全局状态模型。

Svelte global runes 没有全局开启，`state_referenced_locally` warning 也有显式配置。修改 reactive capture 时必须通过行为测试确认，而不是只依赖类型检查。

## API SDK 与数据流

典型数据流：

```text
root init
  → generated SDK fetch
  → route load
  → typed PageData
  → component
  → service/manager mutation
  → event manager / WebSocket
  → manager/store refresh
```

[`packages/sdk/src/fetch-client.ts`](../../packages/sdk/src/fetch-client.ts) 由 OpenAPI 生成，禁止手改。[`packages/sdk/src/index.ts`](../../packages/sdk/src/index.ts) 添加 base URL、header/API key 和 media URL helpers。

API/DTO 变化应从 Server contract 出发，运行 OpenAPI/SDK generation，再修改 consumer。只修补 Web 类型以绕过生成 contract 会造成下一次 codegen 覆盖。

shared-link 页面需要传播 [`authManager.params`](../../web/src/lib/managers/auth-manager.svelte.ts) 中的 key/slug context。新增或重构 API 调用时遗漏这些 params 会让普通登录场景通过、共享链接场景失败。

## WebSocket 与事件更新

[`web/src/lib/stores/websocket.ts`](../../web/src/lib/stores/websocket.ts) 连接 `/api/socket.io`，将 Server events 转发到 store/event manager。领域写操作也会发出 typed events，供 timeline、album 等 manager 更新。

Timeline 对上传、更新、删除事件进行节流合并，避免每个事件触发完整 reload。修改 event payload/节流策略时检查：

- Server producer；
- event type definition；
- manager consumer；
- optimistic/local state；
- reconnect 后的 recovery/reload。

主要入口：

- [`web/src/lib/managers/event-manager.svelte.ts`](../../web/src/lib/managers/event-manager.svelte.ts)
- [`web/src/lib/managers/timeline-manager/internal/websocket-support.svelte.ts`](../../web/src/lib/managers/timeline-manager/internal/websocket-support.svelte.ts)

## i18n 与路由安全

translation JSON 位于根 [`i18n/`](../../i18n/)，Web 通过 glob/lazy import 加载。英文 catalog 还用于生成 type-safe translation keys。

语言选择和 format locale 是独立持久化偏好。修改 locale normalization、Chinese aliases 或 RTL behavior 时需要覆盖 locale fallback 和 persisted preference。

安全相关 route/helper：

- 同源 `continue` URL 检查；
- shared-link auth context；
- dynamic id matcher；
- asset viewer optional routes；
- auth guard/redirect in page loader。

相关入口：

- [`web/src/lib/utils/i18n.ts`](../../web/src/lib/utils/i18n.ts)
- [`web/src/lib/utils/navigation.ts`](../../web/src/lib/utils/navigation.ts)
- [`web/src/params/id.ts`](../../web/src/params/id.ts)

## 最小开发与测试入口

完整 setup 见 [公开开发文档](../../docs/docs/developer/setup.md)。常用入口：

| 目的                     | 命令                      |
| ------------------------ | ------------------------- |
| 启动 Web + SDK           | `mise //web:start`        |
| 使用 demo backend        | `mise //web:start-demo`   |
| 构建                     | `mise //web:build`        |
| 单次 Vitest              | `mise //web:test --run`   |
| Svelte/TypeScript checks | `mise //web:check`        |
| 完整 Web checklist       | `mise //web:checklist`    |
| coverage                 | `pnpm --dir web test:cov` |

组件/单元测试使用 Vitest、happy-dom 和 Testing Library。浏览器关键流程位于 `e2e/` Playwright projects。

## 生成物与高风险变更

| 变更                   | 额外要求                                                            |
| ---------------------- | ------------------------------------------------------------------- |
| API usage/type         | 从 OpenAPI 重新生成 SDK；禁止手改 `fetch-client.ts`                 |
| Shared-link flow       | 传播 auth params，覆盖匿名/shared-link 测试                         |
| Root init/manager      | 检查初始化顺序、memoization、SSR assumptions                        |
| Route/deep link        | 检查同源 redirect、history、asset viewer optional routes            |
| WebSocket event        | Server producer、event manager、reconnect recovery、Playwright flow |
| Global/persisted state | storage migration/default、runes capture、test isolation            |
| i18n key/locale        | 根 catalogs、typed keys、fallback、RTL、Mobile 联动                 |
| Service worker         | 请求取消/合并、cache assumption、浏览器 behavior                    |

## 已知约束

- Web 是 CSR SPA，不是 Svelte SSR app。
- `fetch-client.ts` 是生成文件。
- manager/store/runes 是迁移态混合架构，没有统一 query cache。
- shared-link API 必须保留 key/slug context。
- manager getter 可能要求 root init 已完成。
- service worker 主要协调同 URL 媒体请求，不是离线媒体 cache。
- 本地联调 `@immich/ui` 需要按公开 setup 文档配置 sibling source/alias；不要默认仓库包含其 Web source。

## 源码导航

| 主题           | 路径                                                                         |
| -------------- | ---------------------------------------------------------------------------- |
| Root layout    | [`web/src/routes/+layout.ts`](../../web/src/routes/+layout.ts)               |
| Routes         | [`web/src/routes/`](../../web/src/routes/)                                   |
| Components     | [`web/src/lib/components/`](../../web/src/lib/components/)                   |
| Managers       | [`web/src/lib/managers/`](../../web/src/lib/managers/)                       |
| Stores         | [`web/src/lib/stores/`](../../web/src/lib/stores/)                           |
| Services       | [`web/src/lib/services/`](../../web/src/lib/services/)                       |
| Service worker | [`web/src/service-worker/`](../../web/src/service-worker/)                   |
| SDK wrapper    | [`packages/sdk/src/index.ts`](../../packages/sdk/src/index.ts)               |
| Generated SDK  | [`packages/sdk/src/fetch-client.ts`](../../packages/sdk/src/fetch-client.ts) |
| Tasks          | [`web/mise.toml`](../../web/mise.toml)                                       |
| Test config    | [`web/vite.config.ts`](../../web/vite.config.ts)                             |
