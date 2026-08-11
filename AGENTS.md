# 仓库 Agent 指南

## 适用范围与优先级

本文件适用于整个仓库。更深层的 `AGENTS.md` 会增加 subtree-specific 规则；与本文件冲突时，以更深层文件为准。

按以下顺序遵循指令：

1. 用户与平台指令。
2. 距离目标文件最近且适用的 `AGENTS.md`。
3. 仓库源码、测试、task 定义与 CI 配置。
4. 解释性文档。

不要把本指南当作 CI 或 maintainer review 的替代品。

## 开始前阅读

- 先阅读[工程手册](engineering/README.md)，了解架构与变更路由。
- 准备上游工作前阅读 [CONTRIBUTING.md](CONTRIBUTING.md)。
- 完整 how-to 请查阅公开的[开发环境配置](docs/docs/developer/setup.md)、[测试指南](docs/docs/developer/testing.md)和 [PR checklist](docs/docs/developer/pr-checklist.md)。
- 修改 subtree 时还需阅读：
  - [Server 指南](server/AGENTS.md)
  - [Web 指南](web/AGENTS.md)
  - [Mobile 指南](mobile/AGENTS.md)
  - [Machine Learning 指南](machine-learning/AGENTS.md)
  - [文档指南](docs/AGENTS.md)

## 仓库地图

- `server/`：NestJS API、workers、持久化、queues 与 runtime orchestration。
- `web/`：构建为 CSR SPA 的 SvelteKit client。
- `mobile/`：Flutter 应用及 Android/iOS native integrations。
- `machine-learning/`：通过 HTTP 使用的 Python inference service。
- `packages/`：生成的 SDK、CLI、plugin packages 与共享 scripts。
- `open-api/`：OpenAPI generation 与 compatibility tooling。
- `e2e/`：API 与 browser end-to-end tests。
- `docs/`：公开的 English Docusaurus 文档。
- `engineering/`：内部、中文为主的工程知识。

完整的职责归属与变更影响见[模块地图](engineering/module-map.md)。

## 权威来源规则

- 贡献政策：`CONTRIBUTING.md` 与 PR templates。
- Runtime 行为与架构：当前源码和测试。
- 工具版本与 task 名称：`mise.toml`、package manifests、lockfiles 与 generation scripts。
- CI 要求：`.github/workflows/` 及其调用的 scripts。
- 公开 setup/how-to：`docs/docs/developer/`，并用其调用的 scripts 复核。
- 工程总结：`engineering/`；来源变化时同步更新。

来源不一致时，应记录差异，不要静默选择更方便的描述。

## 工作规则

- 编辑前检查 `git status --short`，保留与任务无关的用户改动。
- 发现文件优先使用 `rg`/`rg --files`，执行任务优先使用仓库定义的 `mise` 或 package scripts。
- 保持变更聚焦，不要把顺手重构混入当前任务。
- 遵循现有模块边界和局部模式；明确记录 migration-state 例外。
- 绝不提交 secrets、本地环境文件、credentials、uploads 或生成的 build output。
- 除非用户明确要求，否则不要创建 commit。

## 生成文件与联动变更

- 不要手工编辑生成的 OpenAPI clients 或 API outputs。
- API/controller/DTO 变更可能需要重新生成 OpenAPI，并验证 SDK、Web、Mobile 与 E2E。
- Database schema 变更需要经过审阅的 migration 和 migration-focused tests。
- Mobile Drift、Pigeon、localization、icon 与 splash artifacts 必须通过对应 generator 修改。
- Translation key 变更可能影响 typed Web resources 与生成的 Mobile resources。
- 修改 contract 或 generator input 前查阅[开发指南](engineering/development-guide.md)。

## 验证

- 先运行最窄的相关测试；风险需要时，再运行归属模块的 checklist。
- 只使用存在于 `mise tasks ls --all --name-only` 或所属 `package.json` scripts 中的 task 名称。
- 不要把可选的本地检查描述为 CI 要求。
- 完成前，为所有变更文件运行格式化和相关测试，并对 tracked diffs 运行 `git diff --check`。
- 仅修改文档时，还需验证相对链接和文档中的 task 名称。

变更类型到验证项的映射见[测试指南](engineering/testing-guide.md)。

## 文档维护

- 更新某项事实的唯一 owner 文档，不要把同一事实复制到多个文件。
- 跨模块流程归 `engineering/architecture.md`；版本归 `engineering/technology-stack.md`；目录职责归 `engineering/module-map.md`。
- 根级指令不超过 180 行，scoped instructions 不超过 120 行。
- 内部中文工程知识放在 `engineering/`，不要放入公开的 `docs/docs/`。
- 架构、tasks、版本或模块边界变化时，遵循[维护指南](engineering/maintenance-guide.md)。

## 上游贡献政策

Immich 要求贡献者不要提交由 LLM 生成的 PR。不得使用 LLM 修复标记为 `good-first-issue` 的 issue；此类 PR 会被自动关闭。遵循 PR template 时，可以使用 LLM 翻译简洁的 PR 标题或描述。

准备上游工作前，阅读仓库的[生成式 AI 政策](CONTRIBUTING.md#use-of-generative-ai)和[工程总结](engineering/upstream-collaboration.md)。
