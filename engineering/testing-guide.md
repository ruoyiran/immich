# 测试与验证选择指南

> 用途：按变更风险选择最小、可解释的验证集，并定义何时升级到跨层或完整检查。  
> 权威来源：各子系统的 `mise.toml`、[CI workflows](../.github/workflows/)、[公开测试指南](../docs/docs/developer/testing.md) 与 [PR checklist](../.github/pull_request_template.md)。  
> 更新触发：测试分层、任务名、生成流程、CI 门禁或模块边界发生变化时。

本文不重复公开测试指南中的环境搭建和逐项操作。这里回答两个问题：一次变更最低需要验证什么，以及什么信号要求扩大验证范围。命令以仓库任务定义为准；CI 是否执行某项检查，仍以 workflow 为准。

## 选择原则

1. 先运行能直接覆盖变更行为的最窄测试，再补静态检查和跨边界验证。
2. 变更触及持久化、队列、进程间协议、生成契约或平台桥接时，不把单元测试视为充分证据。
3. `checklist` 是子系统交付前的聚合检查，不是所有小改动的第一步；高风险或大范围改动应运行它。
4. 只报告实际运行过的命令。未运行的昂贵、需服务或需平台环境的检查，要记录原因和剩余风险。
5. 生成文件必须由权威源重新生成，不直接修改生成结果来让测试通过。

## 变更到最小验证矩阵

| 变更范围                                        | 最小验证集                                                                                         | 需要升级的信号                                                                                                                                          |
| ----------------------------------------------- | -------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Server 纯函数、service 或 controller 的局部行为 | `mise //server:test --run`                                                                         | 涉及数据库、队列、外部服务适配或共享 fixture 时，加 `mise //server:test-medium --run`；跨多个模块或准备交付时运行 `mise //server:checklist`             |
| Web 工具函数、store 或组件行为                  | `mise //web:test --run`                                                                            | 修改 TypeScript/Svelte 类型、路由或 API 消费时加 `mise //web:check`；大范围 UI 变更运行 `mise //web:checklist`；关键用户流程再加 Web E2E                |
| Mobile Dart service、provider、widget 或导航    | `mise //mobile:test`                                                                               | 修改平台桥接、代码生成输入、复杂 provider 图或广泛 UI 状态时加 `mise //mobile:analyze`；大范围改动运行 `mise //mobile:checklist`                        |
| Mobile Drift 表、实体或 schema                  | `mise //mobile:drift:migration`，然后 `mise //mobile:codegen:drift:schema` 与 `mise //mobile:test` | 迁移跨多个 schema 版本、影响同步数据或生成结果较大时，升级到 `mise //mobile:checklist` 并检查生成 diff                                                  |
| Machine Learning 局部 Python 行为               | `mise //machine-learning:test`                                                                     | 类型边界变化加 `mise //machine-learning:check`；代码风格或导入变化加 `mise //machine-learning:lint`；跨模块变更运行 `mise //machine-learning:checklist` |
| Server/API 的跨进程或公开契约                   | 相关 Server 测试加 `mise //e2e:test`                                                               | 影响浏览器可见流程、鉴权、上传或回归路径时，再运行 `mise //e2e:test-web`                                                                                |
| Web 关键浏览器流程                              | `mise //web:test --run` 加 `mise //e2e:test-web`                                                   | 同时改变公开 API 或 Server 行为时，加 `mise //e2e:test` 与对应 Server 测试                                                                              |
| 公开 docs 的 Markdown/MDX 文案                  | `mise //docs:format`                                                                               | 修改导航、Docusaurus 配置、代码示例构建输入或生成 API 内容时，加 `mise //docs:build`                                                                    |
| 内部 `engineering/*.md`                         | `pnpm exec prettier --config .prettierrc --check engineering/<file>.md`                            | 同时修改公开 docs 或链接到其构建输入时，按上一行补 docs 检查                                                                                            |
| OpenAPI、SDK 或其他生成输入                     | 运行对应生成任务并审查生成 diff，再验证受影响消费者                                                | 契约跨 Server、Web、Mobile 时，运行完整 `mise //:open-api`，并补各消费者的类型检查、分析或 E2E                                                          |

矩阵给出默认下限，不替代对实际调用链的判断。若一项改动同时命中多行，验证集取并集。

## 子系统命令速查

### Server

任务定义见 [`server/mise.toml`](../server/mise.toml)。

```bash
mise //server:test --run
mise //server:test-medium --run
mise //server:checklist
```

`test` 覆盖快速、隔离的 Vitest 层；`test-medium` 面向需要更多基础设施或真实集成面的测试。非交互执行时使用 `--run`，避免进入 watch 模式。

### Web

任务定义见 [`web/mise.toml`](../web/mise.toml)。

```bash
mise //web:test --run
mise //web:check
mise //web:checklist
```

`check` 负责 TypeScript 与 Svelte 静态检查；`checklist` 聚合格式、静态检查、测试及其所需生成依赖。

### Mobile

任务定义见 [`mobile/mise.toml`](../mobile/mise.toml)。

```bash
mise //mobile:test
mise //mobile:analyze
mise //mobile:checklist
```

Drift schema 变更另外运行：

```bash
mise //mobile:drift:migration
mise //mobile:codegen:drift:schema
```

提交前检查迁移和 schema 生成结果是否与模型变更一致。普通 Dart 或 UI 改动不需要无条件生成 Drift migration。

### Machine Learning

任务定义见 [`machine-learning/mise.toml`](../machine-learning/mise.toml)。

```bash
mise //machine-learning:test
mise //machine-learning:check
mise //machine-learning:lint
mise //machine-learning:checklist
```

`check` 是严格类型检查，`lint` 是代码质量检查；二者不能互相替代。

### E2E

任务定义见 [`e2e/mise.toml`](../e2e/mise.toml)。

```bash
mise //e2e:test
mise //e2e:test-web
```

前者验证 API/服务集成，后者运行 Playwright 浏览器流程。它们会准备构建产物和测试环境，适合作为跨边界证据，而不是局部实现改动的唯一反馈环。

### Docs 与内部 Markdown

公开站点任务定义见 [`docs/mise.toml`](../docs/mise.toml)。

```bash
mise //docs:format
mise //docs:build
```

`engineering/` 下的内部 Markdown 使用根目录 [`.prettierrc`](../.prettierrc)，不要用 docs 子项目配置代替：

```bash
pnpm exec prettier --config .prettierrc --write engineering/<file>.md
pnpm exec prettier --config .prettierrc --check engineering/<file>.md
```

### Generated contracts and clients

根任务定义见 [`mise.toml`](../mise.toml)，生成边界详见[契约与包说明](modules/contracts-and-packages.md)。

```bash
mise //:open-api
mise //:open-api-typescript
mise //:open-api-dart
mise //mobile:codegen
```

只改单一消费者时可以使用对应的窄生成任务；改变 OpenAPI 权威源或共享契约时使用完整 `mise //:open-api`。生成后审查 diff，并按消费者补 `mise //web:check`、`mise //mobile:analyze`、相关测试或 E2E。不要手改 SDK、schema 或其他生成输出。

## 失败升级原则

1. **窄测试失败**：先固定到最小可复现用例，确认失败来自行为回归、fixture、环境还是陈旧生成物；不要立即用完整套件掩盖定位信息。
2. **静态检查失败**：修复根因后重跑对应检查和直接相关测试。不要通过放宽类型、lint 规则或断言绕过新问题。
3. **集成或 E2E 失败**：保留失败命令、日志、服务状态和浏览器产物。仅为判断是否可复现而重跑；重复通过不能自动把失败归类为无关波动。
4. **共享状态、并发或平台相关失败**：扩大到相邻模块、medium test、目标平台或 E2E；涉及 Android/iOS 原生桥接时，Flutter 单元测试不足以证明平台行为。
5. **生成差异或 freshness 失败**：回到 schema、注解、翻译或 API 定义等权威输入重新生成，审查所有消费者差异，不直接修补生成文件。
6. **聚合检查出现疑似既有失败**：记录完整命令和首个失败，使用窄测试或基线证据区分本次回归与既有问题；交付说明中明确剩余失败，不静默忽略。
7. **需要凭据、真实外部服务、破坏性数据库重置或当前环境不具备的平台**：停止扩大操作，说明阻塞条件和可由谁、在何处完成的下一项验证。

## 交付时记录

在 PR 或交接说明中至少记录：

- 实际运行的验证命令及结果；
- 因环境、成本或范围未运行的检查及原因；
- 生成任务及生成 diff 是否已审查；
- 已知失败、可复现条件和剩余跨平台或跨服务风险。
