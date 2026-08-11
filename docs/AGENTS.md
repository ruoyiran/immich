# 文档 Agent 指南

## 适用范围

本文件适用于 `docs/` subtree。还需遵循仓库级 [Agent 指南](../AGENTS.md)；本文件仅增加文档专用规则。

## 内容边界

- `docs/docs/` 是公开的 Docusaurus 内容目录。这些页面面向 Immich 用户、管理员和上游贡献者，必须使用 English。
- 内部、中文为主的工程知识放在 [`../engineering/`](../engineering/)，不要放入 `docs/docs/`。
- 完整的公开 setup 与 how-to 归[开发者文档](docs/developer/)所有。内部工程页面应链接这些文档，只补充架构、变更影响或维护背景。
- 不要为了让两套文档表面对称，就把内部工程总结复制到公开页面。

## 语言与风格

- 公开文档使用清晰、简洁的 English，包括标题、正文、链接文本和图片 alt text。
- 代码标识、命令、路径、配置键和约定俗成的 technical terms 必须保持原样，并在适合时使用反引号。
- 遵循相邻页面的 frontmatter、MDX imports、Docusaurus admonitions 与标题结构。
- 优先采用 task-oriented 指令和直接链接，避免重复背景说明或长命令表。
- `../engineering/` 以中文为主，同时保留 English technical terms、命令和标识符。

## 写作前核验来源

- 用当前源码和测试核验 runtime 行为。
- 用 `mise.toml`、package manifests、lockfiles 与 generation scripts 核验 task 名称、工具版本和生成文件流程。
- 用 `.github/workflows/` 及其调用的 scripts 核验 CI 要求。
- 不要把推测、过时页面或生成的分析产物写成当前事实。
- 公开页面与仓库不一致时，在对应的工程 owner 文档中记录差异，并把公开修正作为聚焦的独立变更处理。

## 内部工程文档

- 文档工作变更或核实了架构、模块职责、task 名称、版本或跨模块流程时，更新 `../engineering/` 中的唯一 owner。
- 链接 owner 文档，不要把同一事实复制到多个文件。
- 公开修正解决了已记录的 documentation debt 时，更新或删除对应内部记录。
- 除非用户明确要求发布，否则内部文档必须位于 Docusaurus 内容目录之外。

## 公开文档变更

- 移动或删除页面时，按需更新 `static/_redirects`，保持 backward compatibility。
- 除非请求的变更需要 migration，否则保留现有 URL、frontmatter identifiers 与 anchors。
- 修改 Docusaurus 配置、导航、MDX imports/components、redirects 或共享 theme code，属于较高风险的文档变更。

## 验证

- 文档变更运行 `mise //docs:format`。
- 可能影响 Docusaurus 编译、routing、导航或共享渲染的较高风险变更运行 `mise //docs:build`。
- 根据当前 worktree 检查变更后的相对链接和引用路径。
- 完成前，对 tracked diffs 运行 `git diff --check`。

## 上游贡献政策

不要在此复制上游贡献或 AI 使用政策。准备上游工作前，遵循仓库级 [Agent 指南](../AGENTS.md)并阅读 [CONTRIBUTING.md](../CONTRIBUTING.md)。
