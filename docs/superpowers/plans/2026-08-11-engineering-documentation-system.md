# Immich Layered Engineering Documentation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create a Chinese-first, source-backed engineering handbook and layered `AGENTS.md` instructions for the Immich monorepo without changing application behavior or publishing internal documentation through Docusaurus.

**Architecture:** Keep long-lived engineering knowledge in the root `engineering/` directory, keep root and scoped `AGENTS.md` files short and executable, and retain `docs/docs/developer/` as the canonical public English setup/how-to documentation. Shared facts have one owner: architecture, module map, technology stack, workflow guides, module internals, and scoped instructions link to one another instead of duplicating content.

**Tech Stack:** Markdown, Mermaid, repository-local `mise` tasks, pnpm/Prettier, Node.js link validation, Git diff checks.

**Design spec:** `docs/superpowers/specs/2026-08-11-engineering-documentation-design.md`

**Commit policy:** The commit steps below are suggested review checkpoints. In the current shared workspace, do not create commits unless the user explicitly requests them; otherwise inspect the equivalent scoped diff at each checkpoint.

---

## File Map

### Instruction files

- Create `AGENTS.md`: repository-wide routing, source-of-truth rules, generated-file constraints, verification policy, documentation maintenance, and upstream AI contribution boundaries.
- Create `server/AGENTS.md`: Server-specific layering, schema/migration, OpenAPI, job handler, authentication, and verification rules.
- Create `web/AGENTS.md`: SvelteKit CSR, generated SDK, state patterns, shared-link authentication, and Web verification rules.
- Create `mobile/AGENTS.md`: Flutter/Riverpod/Drift/Pigeon boundaries, generated code, schema migration, native/background work, and Mobile verification rules.
- Create `machine-learning/AGENTS.md`: Python/FastAPI/ONNX boundaries, model/runtime changes, Server integration, and ML verification rules.
- Create `docs/AGENTS.md`: public English docs scope, Docusaurus commands, internal engineering-doc separation, and upstream contribution rules.

### Central engineering handbook

- Create `engineering/README.md`: handbook entry point, global verification baseline, reading routes, and document ownership map.
- Create `engineering/architecture.md`: runtime topology and cross-module data flows.
- Create `engineering/technology-stack.md`: versioned toolchain and framework inventory with canonical sources.
- Create `engineering/module-map.md`: repository directory responsibilities, dependency directions, and change-impact map.
- Create `engineering/development-guide.md`: change-type workflow selection, generated-code flows, and cross-module development sequence.
- Create `engineering/testing-guide.md`: test taxonomy and change-to-verification matrix.
- Create `engineering/maintenance-guide.md`: metadata contract, documentation debt, ownership, and update triggers.
- Create `engineering/upstream-collaboration.md`: local-vs-upstream boundaries and exact generative-AI contribution policy.
- Create `engineering/modules/server.md`: Server internals, flows, risks, and source anchors.
- Create `engineering/modules/web.md`: Web internals, flows, risks, and source anchors.
- Create `engineering/modules/mobile.md`: Mobile internals, flows, migration state, risks, and source anchors.
- Create `engineering/modules/machine-learning.md`: ML service internals, flows, risks, and source anchors.
- Create `engineering/modules/contracts-and-packages.md`: OpenAPI, generated SDKs, CLI, plugins, shared UI/design resources, and i18n boundaries.
- Create `engineering/modules/infrastructure-and-tooling.md`: Docker/Compose, `mise`, CI, E2E, build, and deployment tooling.
- Create `engineering/decisions/README.md`: lightweight ADR policy and complete template.

## Shared Document Contract

Every file under `engineering/`, except the global index where noted, starts with this concrete metadata shape:

```markdown
> 用途：说明本文负责回答的问题。  
> 权威来源：列出当前仓库中的源码、配置或公开文档路径。  
> 更新触发：列出必须重新核对本文的代码或配置变化。
```

Only `engineering/README.md` records the global baseline:

```markdown
> 全局核对基线：`11fe6db14e06a258020cf4ac3c34f35243429d96`
```

The implementation must use these information owners consistently:

- `architecture.md`: cross-module runtime topology and end-to-end flows.
- `module-map.md`: top-level directory roles, dependency direction, and change impact.
- `technology-stack.md`: explicit versions and framework/tool inventory.
- `development-guide.md` and `testing-guide.md`: change-type selection matrices and minimum entry commands.
- `modules/*.md`: module-specific internals, risks, migration state, and source anchors.
- nearest `AGENTS.md`: directly executable rules only.
- `docs/docs/developer/`: full public English setup/how-to.

### Task 1: Create the Handbook Foundation and Root Instructions

**Files:**

- Create: `AGENTS.md`
- Create: `engineering/README.md`
- Create: `engineering/maintenance-guide.md`
- Create: `engineering/upstream-collaboration.md`
- Create: `engineering/decisions/README.md`

- [ ] **Step 1: Verify the pre-change baseline**

Run:

```bash
git rev-parse HEAD
git status --short
test ! -e AGENTS.md
test ! -e engineering
```

Expected:

- HEAD is `11fe6db14e06a258020cf4ac3c34f35243429d96` unless the user has advanced it during this task.
- Existing untracked paths include `graphify-out/`, `.superpowers/`, and `docs/superpowers/`.
- The two `test` commands exit successfully.

- [ ] **Step 2: Create `engineering/README.md`**

Write the global baseline block, then these exact sections:

```markdown
# Immich 工程手册

## 文档定位

## 推荐阅读路线

## 工程文档地图

## 信息唯一归属

## 权威来源分类

## 全局核对基线

## 已知文档偏差

## 维护入口
```

Content requirements:

- State that `engineering/` is internal Chinese-first engineering knowledge and is not Docusaurus content.
- Route new contributors to public `docs/docs/developer/setup.md` and `CONTRIBUTING.md` first.
- Provide scenario links for system overview, Server, Web, Mobile, ML, API/contracts, infrastructure, development, testing, and ADRs.
- Record the baseline commit exactly once.
- List known verified documentation debt: Mobile Isar references versus current Drift/SQLite, stale TS SDK path references, and stale Mobile module-template descriptions.

- [ ] **Step 3: Create `engineering/maintenance-guide.md`**

Use the shared metadata contract and these sections:

```markdown
# 工程文档维护指南

## 信息权威来源

## 信息唯一归属

## 文档元数据

## 更新触发条件

## Documentation debt

## 新增 scoped AGENTS.md 的门槛

## 删除与归档规则

## 审查清单
```

Specify the categorized source-of-truth table from the design spec, prohibit copying full setup/how-to into `engineering/`, and require a new scoped `AGENTS.md` only when a subtree has stable recurring rules not adequately covered by its parent.

- [ ] **Step 4: Create `engineering/upstream-collaboration.md`**

Use the shared metadata contract and these sections:

```markdown
# 上游协作与 AI 使用边界

## 本地工程文档与上游文档

## 提交前的责任边界

## Generative AI 政策

## 将本地发现整理为上游修复

## Feature freeze 与范围确认
```

Directly link `../CONTRIBUTING.md` and accurately preserve these repository policies:

- Do not open PRs generated with an LLM.
- LLM translation of a concise PR title or description is allowed when the PR template is followed.
- Using an LLM to fix `good-first-issue` issues is forbidden and such PRs are automatically closed.
- Misrepresenting LLM use or contribution farming may lead to blocking.
- Check current feature freezes before proposing feature work.

- [ ] **Step 5: Create `engineering/decisions/README.md`**

Use the shared metadata contract, explain when an ADR is warranted, and include this complete reusable template:

```markdown
# ADR-NNNN：决策标题

- 状态：Proposed | Accepted | Superseded
- 日期：YYYY-MM-DD
- 决策者：相关维护者或团队
- 替代：无，或被替代 ADR 的相对链接

## 背景

说明问题、约束和必须做出决策的原因。

## 决策

说明选定方案及其适用范围。

## 备选方案

列出实际评估过的方案及未采用原因。

## 影响

记录正面影响、成本、迁移要求和后续维护责任。

## 验证

列出证明决策有效的测试、指标或人工检查。
```

- [ ] **Step 6: Create root `AGENTS.md`**

Keep it at or below 180 lines and use these sections:

```markdown
# Repository Agent Guide

## Scope and precedence

## Read first

## Repository map

## Source-of-truth rules

## Working rules

## Generated files and coupled changes

## Verification

## Documentation maintenance

## Upstream contribution policy
```

Required rules:

- Preserve user changes and inspect `git status` before editing.
- Prefer `mise` tasks and package scripts already defined by the repository.
- Do not hand-edit generated OpenAPI clients/spec outputs or generated Pigeon/Drift artifacts.
- Schema, API contract, translations, and generated-client changes require their documented generation and verification flows.
- Run the nearest relevant checklist rather than unrelated full-suite tests.
- Route Server/Web/Mobile/ML/docs work to the nearest scoped `AGENTS.md`.
- Link the engineering handbook instead of duplicating architecture prose.
- Link `CONTRIBUTING.md` and state the two exact LLM boundaries from the design spec.

- [ ] **Step 7: Validate Task 1**

Run:

```bash
test "$(wc -l < AGENTS.md)" -le 180
pnpm exec prettier --config .prettierrc --check \
  AGENTS.md \
  engineering/README.md \
  engineering/maintenance-guide.md \
  engineering/upstream-collaboration.md \
  engineering/decisions/README.md
git diff --check
```

Expected: line budget succeeds, Prettier reports all matched files formatted, and `git diff --check` is silent.

- [ ] **Step 8: Review checkpoint**

Inspect:

```bash
git status --short
sed -n '1,240p' AGENTS.md
sed -n '1,240p' engineering/README.md
sed -n '1,280p' engineering/maintenance-guide.md
sed -n '1,240p' engineering/upstream-collaboration.md
sed -n '1,240p' engineering/decisions/README.md
```

Suggested commit if explicitly authorized:

```bash
git add AGENTS.md engineering/README.md engineering/maintenance-guide.md engineering/upstream-collaboration.md engineering/decisions/README.md
git commit -m "docs: add engineering handbook foundation"
```

### Task 2: Document System Architecture and Repository Modules

**Files:**

- Create: `engineering/architecture.md`
- Create: `engineering/module-map.md`

- [ ] **Step 1: Create `engineering/architecture.md`**

Use the shared metadata contract and these sections:

```markdown
# 系统架构

## 系统上下文

## 部署与运行拓扑

## Server 进程模型

## 资产上传与异步处理流

## Web 请求与实时更新流

## Mobile 本地与远端同步流

## Machine Learning 调用流

## 持久化与共享基础设施

## 扩展与故障边界

## 源码导航
```

Include Mermaid diagrams for:

1. Web/Mobile → API → PostgreSQL/Valkey/media storage/ML.
2. `server/src/main.ts` supervisor → API child process and microservices worker in normal mode, or the mutually exclusive maintenance worker in maintenance mode.
3. Upload → asset persistence → BullMQ jobs → metadata/thumbnail/search/facial/OCR/transcode stages.

Source anchors must include:

- `server/src/main.ts`
- `server/src/workers/api.ts`
- `server/src/workers/microservices.ts`
- `server/src/app.module.ts`
- `server/src/services/job.service.ts`
- `server/src/repositories/job.repository.ts`
- `server/src/repositories/websocket.repository.ts`
- `server/src/repositories/machine-learning.repository.ts`
- `web/src/routes/+layout.ts`
- `mobile/lib/domain/services/sync_stream.service.dart`
- `mobile/lib/domain/services/local_sync.service.dart`
- `docker/docker-compose.yml`

State explicitly that Web is a CSR SPA whose static build is served by the Nest Server, and that ML is an HTTP service rather than an in-process library.

- [ ] **Step 2: Create `engineering/module-map.md`**

Use the shared metadata contract and these sections:

```markdown
# 模块地图

## 一级目录概览

## 运行时模块

## 契约与生成代码

## 共享 packages

## 测试与质量工具

## 文档与本地化

## 基础设施与发布

## 依赖方向

## 变更影响矩阵
```

Cover at least `server/`, `web/`, `mobile/`, `machine-learning/`, `packages/`, `packages/cli/`, `open-api/`, `e2e/`, `i18n/`, `design/`, `mobile/packages/ui/`, `docs/`, `docker/`, and `.github/workflows/`. The impact matrix must map API/DTO, database schema, translations, Web UI, Mobile DB/native API, ML endpoint/model, and docs changes to coupled modules.

- [ ] **Step 3: Validate Task 2**

Run:

```bash
pnpm exec prettier --config .prettierrc --check engineering/architecture.md engineering/module-map.md
rg -n "server/src/main.ts|docker/docker-compose.yml|CSR|Drift|BullMQ" engineering/architecture.md
rg -n "open-api/|packages/cli/|e2e/|mobile/packages/ui/|design/|变更影响矩阵" engineering/module-map.md
git diff --check
```

Expected: formatting passes; each `rg` prints all required concepts; whitespace check is silent.

- [ ] **Step 4: Review checkpoint**

Suggested commit if explicitly authorized:

```bash
git add engineering/architecture.md engineering/module-map.md
git commit -m "docs: map system architecture and modules"
```

### Task 3: Document the Technology Stack

**Files:**

- Create: `engineering/technology-stack.md`

- [ ] **Step 1: Create the stack inventory**

Use the shared metadata contract and these sections:

```markdown
# 技术栈

## 版本读取原则

## Repository toolchain

## Server

## Web

## Mobile

## Machine Learning

## Data and infrastructure

## Testing and quality

## Generated contracts and SDKs

## Version update checklist
```

Record only versions verified from repository sources. Include:

- Node 24.15.0, pnpm 11.17.0, Java 21.0.2 from root `mise.toml`.
- NestJS 11, Express 5, Zod 4, Kysely, PostgreSQL, BullMQ/ioredis from `server/package.json` and Compose.
- Svelte 5.56.8, SvelteKit 2.70.1, Vite 8.1.5, Tailwind 4.3.3, TypeScript 6, Vitest 4 from `pnpm-lock.yaml`, `web/package.json`, and `web/vite.config.ts`.
- Flutter 3.44.9, Dart >=3.12, Riverpod 2.6.1, AutoRoute 11.1, Drift 2.34, Pigeon 26.3.4, Android/iOS minimums from `mobile/mise.toml`, `mobile/pubspec.yaml`, Gradle, Podfile, and Xcode project settings.
- Python 3.11, FastAPI, ONNX runtime, uv/pytest/mypy/ruff from `machine-learning/pyproject.toml` and `machine-learning/mise.toml`.
- PostgreSQL 14, VectorChord/pgvectors, Valkey, Docker/Compose from `docker/docker-compose.yml`.

For each explicit version, include a source link or source-path column. Distinguish pinned toolchain versions from lockfile-resolved versions.

- [ ] **Step 2: Validate Task 3**

Run:

```bash
pnpm exec prettier --config .prettierrc --check engineering/technology-stack.md
rg -n "24\.15\.0|11\.17\.0|3\.44\.9|2\.34|3\.11|VectorChord" engineering/technology-stack.md
rg -n "mise\.toml|package\.json|pnpm-lock\.yaml|pubspec\.yaml|docker-compose\.yml" engineering/technology-stack.md
git diff --check
```

Expected: formatting passes and every listed version/source family is present.

- [ ] **Step 3: Review checkpoint**

Suggested commit if explicitly authorized:

```bash
git add engineering/technology-stack.md
git commit -m "docs: record verified technology stack"
```

### Task 4: Document and Scope the Server Module

**Files:**

- Create: `engineering/modules/server.md`
- Create: `server/AGENTS.md`

- [ ] **Step 1: Create `engineering/modules/server.md`**

Use the shared metadata contract and these sections:

```markdown
# Server 模块

## 职责

## 运行入口与进程模型

## Controller-Service-Repository 分层

## Schema 与持久化

## Queue、event 与 worker

## WebSocket 与横向扩展

## Machine Learning 集成

## 最小开发与测试入口

## 生成物与高风险变更

## 已知约束

## 源码导航
```

Capture these verified constraints:

- `/api` Nest/Express API, API child process, and microservices worker threads.
- `controllers/`, `services/`, `repositories/`, `schema/`, and worker responsibilities.
- Every endpoint requires `@Authenticated()`.
- Every queue has exactly one `@OnJob` handler.
- Schema changes require migrations and downgrade from unknown migrations is unsupported.
- OpenAPI outputs are generated, not manually edited.
- Remote ML has no built-in authentication and belongs on a trusted network.
- Minimum verification entry is `mise //server:checklist`, with focused unit/medium tests selected first.

- [ ] **Step 2: Create `server/AGENTS.md`**

Keep it at or below 120 lines. Use sections `Scope`, `Read first`, `Architecture rules`, `Generated and coupled changes`, `Verification`, and `High-risk checks`. Link the module document and public database migration/testing docs. Include direct executable rules for authentication decorators, import aliases, schema migrations, OpenAPI regeneration, and queue handlers.

- [ ] **Step 3: Validate Task 4**

Run:

```bash
test "$(wc -l < server/AGENTS.md)" -le 120
pnpm exec prettier --config .prettierrc --check engineering/modules/server.md server/AGENTS.md
rg -n "@Authenticated|@OnJob|mise //server:checklist|migration|OpenAPI" engineering/modules/server.md server/AGENTS.md
git diff --check
```

Expected: line budget and formatting pass; all critical Server rules are present.

- [ ] **Step 4: Review checkpoint**

Suggested commit if explicitly authorized:

```bash
git add engineering/modules/server.md server/AGENTS.md
git commit -m "docs: add server engineering guidance"
```

### Task 5: Document and Scope the Web Module

**Files:**

- Create: `engineering/modules/web.md`
- Create: `web/AGENTS.md`

- [ ] **Step 1: Create `engineering/modules/web.md`**

Use the shared metadata contract and these sections:

```markdown
# Web 模块

## 职责与运行方式

## 路由与初始化

## UI 与状态分层

## API SDK 与数据流

## WebSocket 与事件更新

## i18n 与路由安全

## 最小开发与测试入口

## 生成物与高风险变更

## 已知约束

## 源码导航
```

Document Web as a SvelteKit CSR SPA with `ssr=false`, static adapter output embedded in Server, generated SDK at `packages/sdk/src/fetch-client.ts`, mixed runes/store state, shared-link auth parameter propagation, and a service worker used for media request coordination rather than offline media caching. Include `mise //web:start`, focused Vitest execution, and `mise //web:checklist` as entry points.

- [ ] **Step 2: Create `web/AGENTS.md`**

Keep it at or below 120 lines. Link the Web module document. Require generated SDK regeneration rather than editing `fetch-client.ts`, preserve shared-link auth params, account for root initialization assumptions, choose manager/store patterns consistent with surrounding code, and run focused tests plus the Web checklist when appropriate.

- [ ] **Step 3: Validate Task 5**

Run:

```bash
test "$(wc -l < web/AGENTS.md)" -le 120
pnpm exec prettier --config .prettierrc --check engineering/modules/web.md web/AGENTS.md
rg -n "ssr=false|fetch-client\.ts|shared-link|mise //web:checklist|service worker" engineering/modules/web.md web/AGENTS.md
git diff --check
```

Expected: line budget and formatting pass; Web-specific risks are present.

- [ ] **Step 4: Review checkpoint**

Suggested commit if explicitly authorized:

```bash
git add engineering/modules/web.md web/AGENTS.md
git commit -m "docs: add web engineering guidance"
```

### Task 6: Document and Scope the Mobile Module

**Files:**

- Create: `engineering/modules/mobile.md`
- Create: `mobile/AGENTS.md`

- [ ] **Step 1: Create `engineering/modules/mobile.md`**

Use the shared metadata contract and these sections:

```markdown
# Mobile 模块

## 职责与启动流程

## 当前分层与迁移态

## Drift 本地数据层

## 远端同步与 WebSocket

## 本机媒体同步

## Pigeon 与原生平台

## 前后台任务与上传

## 最小开发与测试入口

## 生成物与高风险变更

## 已知文档偏差

## 源码导航
```

Document the target Page/Widget → Riverpod Provider → Service → Repository flow, the coexistence of newer domain/infrastructure/presentation layers with legacy directories, Drift/SQLite schema version 31, `/sync/stream` JSONL, native MediaStore/PhotoKit deltas, Pigeon-generated APIs, multiple FlutterEngine/background lifecycle risks, and the separate `mobile/packages/ui` package. Explicitly state that Isar and `module_template` descriptions in older docs are stale.

- [ ] **Step 2: Create `mobile/AGENTS.md`**

Keep it at or below 120 lines. Link the Mobile module document. Require `mise //mobile:codegen` for generated artifacts, Drift migration tests for schema changes, Pigeon regeneration for native API changes, preservation of enum/protocol ordering, focused tests before `mise //mobile:checklist`, and separate verification for `mobile/packages/ui` when touched.

- [ ] **Step 3: Validate Task 6**

Run:

```bash
test "$(wc -l < mobile/AGENTS.md)" -le 120
pnpm exec prettier --config .prettierrc --check engineering/modules/mobile.md mobile/AGENTS.md
rg -n "Drift|schema version 31|sync/stream|Pigeon|mise //mobile:checklist|Isar" engineering/modules/mobile.md mobile/AGENTS.md
git diff --check
```

Expected: line budget and formatting pass; current Mobile architecture and stale-doc warnings are present.

- [ ] **Step 4: Review checkpoint**

Suggested commit if explicitly authorized:

```bash
git add engineering/modules/mobile.md mobile/AGENTS.md
git commit -m "docs: add mobile engineering guidance"
```

### Task 7: Document and Scope the Machine Learning Module

**Files:**

- Create: `engineering/modules/machine-learning.md`
- Create: `machine-learning/AGENTS.md`

- [ ] **Step 1: Create `engineering/modules/machine-learning.md`**

Use the shared metadata contract and these sections:

```markdown
# Machine Learning 模块

## 职责与服务边界

## FastAPI 入口与请求流

## 模型加载与缓存

## ONNX 推理与设备选择

## Server 集成

## 测试与质量工具

## 最小开发与测试入口

## 高风险变更

## 安全与部署约束

## 源码导航
```

Document Python 3.11, FastAPI/Gunicorn/Uvicorn, ONNX inference, Server HTTP `/predict` integration, fallback across configured ML URLs, model/cache behavior, pytest/mypy/ruff checks, and the lack of built-in authentication for remote ML.

- [ ] **Step 2: Create `machine-learning/AGENTS.md`**

Keep it at or below 120 lines. Link the ML module document. Require matching Python tooling from `machine-learning/mise.toml`/`pyproject.toml`, focused pytest first, full ML checklist when risk warrants it, and Server compatibility checks for request/response contract changes. Warn against exposing remote ML to untrusted networks.

- [ ] **Step 3: Validate Task 7**

Run:

```bash
test "$(wc -l < machine-learning/AGENTS.md)" -le 120
pnpm exec prettier --config .prettierrc --check engineering/modules/machine-learning.md machine-learning/AGENTS.md
rg -n "Python 3\.11|FastAPI|ONNX|/predict|pytest|trusted network" engineering/modules/machine-learning.md machine-learning/AGENTS.md
git diff --check
```

Expected: line budget and formatting pass; ML boundary, validation, and security rules are present.

- [ ] **Step 4: Review checkpoint**

Suggested commit if explicitly authorized:

```bash
git add engineering/modules/machine-learning.md machine-learning/AGENTS.md
git commit -m "docs: add machine learning engineering guidance"
```

### Task 8: Document Contracts, Packages, Infrastructure, and Tooling

**Files:**

- Create: `engineering/modules/contracts-and-packages.md`
- Create: `engineering/modules/infrastructure-and-tooling.md`

- [ ] **Step 1: Create `engineering/modules/contracts-and-packages.md`**

Use the shared metadata contract and sections for OpenAPI ownership, TypeScript/Dart SDK generation, `packages/cli`, plugin core/SDK, Mobile UI package, Web `@immich/ui` dependency, brand design assets, i18n, change coupling, minimum validation entry points, generated files, and source navigation.

Required facts:

- API definitions originate from Server controller/DTO/schema behavior and generate OpenAPI artifacts.
- `packages/sdk/src/fetch-client.ts` and `mobile/generated/openapi/` are generated outputs.
- Root `mise` tasks `//:open-api`, `//:open-api-typescript`, and related generators are the entry points.
- `packages/cli`, plugin packages, `mobile/packages/ui`, Web's external `@immich/ui` dependency, root `design/` assets, and i18n have distinct boundaries; do not imply they form one shared runtime package.
- Translation changes can affect Web and Mobile generated/typed resources.

- [ ] **Step 2: Create `engineering/modules/infrastructure-and-tooling.md`**

Use the shared metadata contract and sections for root `mise`, pnpm workspace, Docker/Compose services, PostgreSQL/Valkey/media mounts, CI workflows, E2E Vitest/Playwright, build/release images, deployment assumptions, minimum validation entry points, and source navigation.

Describe Docker development services, shared persistence requirements, E2E environment setup, browser projects, and the distinction between local task suggestions and CI-enforced gates.

- [ ] **Step 3: Validate Task 8**

Run:

```bash
pnpm exec prettier --config .prettierrc --check \
  engineering/modules/contracts-and-packages.md \
  engineering/modules/infrastructure-and-tooling.md
rg -n "fetch-client\.ts|mobile/generated/openapi|//:open-api|plugin|i18n" engineering/modules/contracts-and-packages.md
rg -n "Docker|PostgreSQL|Valkey|Playwright|CI|deployment" engineering/modules/infrastructure-and-tooling.md
git diff --check
```

Expected: formatting passes and both cross-cutting module boundaries are explicit.

- [ ] **Step 4: Review checkpoint**

Suggested commit if explicitly authorized:

```bash
git add engineering/modules/contracts-and-packages.md engineering/modules/infrastructure-and-tooling.md
git commit -m "docs: describe contracts packages and tooling"
```

### Task 9: Create Development, Testing, and Public Docs Guidance

**Files:**

- Create: `engineering/development-guide.md`
- Create: `engineering/testing-guide.md`
- Create: `docs/AGENTS.md`

- [ ] **Step 1: Create `engineering/development-guide.md`**

Use the shared metadata contract and these sections:

```markdown
# 开发指南

## 使用公开 setup 文档

## 变更前检查

## 选择开发入口

## API 与 SDK 变更

## 数据库 schema 与 migration

## Mobile codegen、Drift 与 Pigeon

## i18n 与生成资源

## 跨模块变更顺序

## 工作树与提交范围

## 完成前检查
```

Provide a change-type matrix rather than copying full setup instructions. Link exact public docs for setup, testing, migrations, directory layout, and PR checklist. Include `mise dev`, module start/checklist entry points, and generation flows only where needed to select the correct workflow.

- [ ] **Step 2: Create `engineering/testing-guide.md`**

Use the shared metadata contract and these sections:

```markdown
# 测试指南

## 测试分层

## 按变更类型选择验证

## Server

## Web

## Mobile

## Machine Learning

## E2E

## 文档与生成物

## 失败处理与升级验证
```

The matrix must cover Server unit/medium, Web Vitest/component, Mobile unit/medium/presentation/migration/integration, ML pytest/type/lint, API E2E, browser Playwright, and docs formatting/link validation. Link the canonical public testing guide and module configs; do not duplicate every command variant.

- [ ] **Step 3: Create `docs/AGENTS.md`**

Keep it at or below 120 lines. Use sections `Scope`, `Public documentation boundary`, `Language and style`, `Source verification`, `Commands`, `Internal engineering docs`, and `Upstream policy`.

Required rules:

- `docs/docs/` is public English Docusaurus content.
- Internal Chinese engineering knowledge belongs in root `engineering/`, not `docs/docs/`.
- Validate public docs with `mise //docs:format` and build when navigation, MDX, config, or generated OpenAPI content changes.
- Link facts to current source/config and avoid preserving stale architecture claims.
- Inherit the root AI contribution policy and link `CONTRIBUTING.md` rather than restating it.

- [ ] **Step 4: Validate Task 9**

Run:

```bash
test "$(wc -l < docs/AGENTS.md)" -le 120
pnpm exec prettier --config .prettierrc --check engineering/development-guide.md engineering/testing-guide.md docs/AGENTS.md
rg -n "docs/docs/developer/setup\.md|database-migrations\.md|pr-checklist\.md" engineering/development-guide.md
rg -n "medium|Vitest|migration|pytest|Playwright|link" engineering/testing-guide.md
rg -n "mise //docs:format|engineering/|CONTRIBUTING\.md" docs/AGENTS.md
git diff --check
```

Expected: line budget and formatting pass; canonical links and test categories are present.

- [ ] **Step 5: Review checkpoint**

Suggested commit if explicitly authorized:

```bash
git add engineering/development-guide.md engineering/testing-guide.md docs/AGENTS.md
git commit -m "docs: add development and testing workflows"
```

### Task 10: Integrate, Cross-Link, and Verify the Entire Documentation System

**Files:**

- Modify: `AGENTS.md`
- Modify: `engineering/README.md`
- Modify: all new `engineering/**/*.md`
- Modify: all five scoped `AGENTS.md`

- [ ] **Step 1: Reconcile cross-links and ownership**

Ensure:

- Every handbook file is linked from `engineering/README.md`.
- Root `AGENTS.md` links all five scoped files and the handbook routes.
- Scoped files link only their module document plus necessary public docs.
- Cross-module topology exists only in `architecture.md`.
- Explicit versions exist only in `technology-stack.md`, except when a version is itself a module-specific risk such as Mobile schema version 31.
- Full setup/how-to remains linked to `docs/docs/developer/` rather than copied.

- [ ] **Step 2: Verify exact target file inventory**

Run:

```bash
for path in \
  AGENTS.md \
  server/AGENTS.md web/AGENTS.md mobile/AGENTS.md \
  machine-learning/AGENTS.md docs/AGENTS.md \
  engineering/README.md \
  engineering/architecture.md \
  engineering/technology-stack.md \
  engineering/module-map.md \
  engineering/development-guide.md \
  engineering/testing-guide.md \
  engineering/maintenance-guide.md \
  engineering/upstream-collaboration.md \
  engineering/modules/server.md \
  engineering/modules/web.md \
  engineering/modules/mobile.md \
  engineering/modules/machine-learning.md \
  engineering/modules/contracts-and-packages.md \
  engineering/modules/infrastructure-and-tooling.md \
  engineering/decisions/README.md; do
  test -f "$path" || exit 1
done
```

Expected: exit code 0.

- [ ] **Step 3: Verify line budgets**

Run:

```bash
test "$(wc -l < AGENTS.md)" -le 180
for path in server/AGENTS.md web/AGENTS.md mobile/AGENTS.md machine-learning/AGENTS.md docs/AGENTS.md; do
  test "$(wc -l < "$path")" -le 120 || exit 1
done
```

Expected: exit code 0.

- [ ] **Step 4: Verify formatting and whitespace**

Run:

```bash
pnpm exec prettier --config .prettierrc --check \
  AGENTS.md \
  server/AGENTS.md web/AGENTS.md mobile/AGENTS.md \
  machine-learning/AGENTS.md docs/AGENTS.md \
  "engineering/**/*.md" \
  docs/superpowers/specs/2026-08-11-engineering-documentation-design.md \
  docs/superpowers/plans/2026-08-11-engineering-documentation-system.md
git diff --check
```

Expected: Prettier reports all matched files formatted and `git diff --check` is silent.

- [ ] **Step 5: Verify all relative Markdown links**

Run from the repository root:

```bash
node --input-type=module <<'NODE'
import { access, readdir, readFile } from 'node:fs/promises';
import path from 'node:path';

const files = [
  'AGENTS.md',
  'server/AGENTS.md',
  'web/AGENTS.md',
  'mobile/AGENTS.md',
  'machine-learning/AGENTS.md',
  'docs/AGENTS.md',
];

async function collectMarkdown(directory) {
  for (const entry of await readdir(directory, { withFileTypes: true })) {
    const entryPath = path.join(directory, entry.name);
    if (entry.isDirectory()) {
      await collectMarkdown(entryPath);
    } else if (entry.isFile() && entry.name.endsWith('.md')) {
      files.push(entryPath);
    }
  }
}

await collectMarkdown('engineering');
const missing = [];
const linkPattern = /!?\[[^\]]*\]\(([^)]+)\)/g;

for (const file of files) {
  const markdown = await readFile(file, 'utf8');
  for (const match of markdown.matchAll(linkPattern)) {
    let target = match[1].trim().replace(/^<|>$/g, '');
    target = target.split(/\s+["']/)[0];
    if (/^(https?:|mailto:|#)/.test(target)) continue;
    target = decodeURIComponent(target.split('#')[0]);
    if (!target) continue;
    const resolved = path.resolve(path.dirname(file), target);
    try {
      await access(resolved);
    } catch {
      missing.push(`${file} -> ${target}`);
    }
  }
}

if (missing.length > 0) {
  console.error(missing.join('\n'));
  process.exit(1);
}

console.log('0 missing relative links');
NODE
```

Expected: `0 missing relative links`.

- [ ] **Step 6: Verify documented task names**

Run:

```bash
rg --no-filename -o '`mise (//[^ `]+|[a-zA-Z0-9:_-]+)' \
  AGENTS.md engineering server/AGENTS.md web/AGENTS.md mobile/AGENTS.md \
  machine-learning/AGENTS.md docs/AGENTS.md \
  | sed 's/^`mise //' \
  | sort -u \
  | while read -r task; do
      case "$task" in
        install|tasks|trust|x) continue ;;
      esac
      mise tasks info "$task" >/dev/null || {
        echo "Missing mise task: $task" >&2
        exit 1
      }
    done
```

Package-script commands must also exist in the corresponding `package.json`. Expected: exit code 0 and no `Missing mise task` output.

- [ ] **Step 7: Verify representative routing scenarios**

Manually trace these five scenarios and record the expected route in the final handoff:

| Scenario                    | Expected route                                                                                      |
| --------------------------- | --------------------------------------------------------------------------------------------------- |
| Server API/DTO change       | Root → `server/AGENTS.md` → Server module → OpenAPI/SDK generation → focused Server tests/checklist |
| Mobile Drift schema change  | Root → `mobile/AGENTS.md` → Mobile module → codegen/migration tests → Mobile checklist              |
| Web UI change               | Root → `web/AGENTS.md` → Web module → focused Vitest/component tests → Web checklist                |
| ML endpoint change          | Root → `machine-learning/AGENTS.md` → ML module → ML tests → Server contract compatibility          |
| Public documentation change | Root → `docs/AGENTS.md` → public developer docs → docs format/build as risk requires                |

- [ ] **Step 8: Inspect final repository scope**

Run:

```bash
git status --short
find engineering -type f -name '*.md' -print | sort
wc -l AGENTS.md server/AGENTS.md web/AGENTS.md mobile/AGENTS.md machine-learning/AGENTS.md docs/AGENTS.md engineering/**/*.md
```

Expected:

- Only documentation/instruction files from this plan are changed by the implementation.
- Pre-existing `graphify-out/` and `.superpowers/` remain untouched.
- No application source, generated output, lockfile, or public `docs/docs/` content is modified.

- [ ] **Step 9: Final review checkpoint**

Suggested commit if explicitly authorized:

```bash
git add \
  AGENTS.md \
  engineering \
  server/AGENTS.md web/AGENTS.md mobile/AGENTS.md \
  machine-learning/AGENTS.md docs/AGENTS.md \
  docs/superpowers/specs/2026-08-11-engineering-documentation-design.md \
  docs/superpowers/plans/2026-08-11-engineering-documentation-system.md
git commit -m "docs: establish layered engineering documentation"
```
