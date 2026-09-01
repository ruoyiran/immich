# External Server Removal Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将本仓库收口为可独立检出的 Immich 客户端与客户端契约仓库，并删除已由同级 `photo-classifier` 接管的原 NestJS Server 及其专用基础设施。

**Architecture:** `photo-classifier` 独立拥有 API 行为、认证、MySQL、上传、后台任务和部署；本仓库保留 Web、Mobile、OpenAPI snapshot、生成 SDK 与客户端测试。两个仓库通过运行时 HTTP 契约协作，不通过相对目录参与彼此的构建。

**Tech Stack:** SvelteKit、Flutter、pnpm workspace、mise、OpenAPI Generator、Playwright、GitHub Actions；外部后端为 Go/Gin + MySQL，但不纳入本仓库 task graph。

**Spec:** `engineering/decisions/0001-external-photo-classifier-server.md`

## Global Constraints

- 不修改或回退现有两个 Mobile iOS `Package.resolved` 用户改动。
- 不创建 commit。
- 不手工编辑生成的 `packages/sdk/src/fetch-client.ts` 或 `mobile/generated/openapi/`。
- 不把 `../photo-classifier` 写入构建、CI 或 package dependency；它只出现在工程说明中。
- 保留 `machine-learning/`，但不再把它描述为当前外部后端的运行依赖。
- `docs/superpowers/` 中既有 spec/plan 属于历史 provenance，不因其中提到旧 Server 而改写。

---

### Task 1: 删除原 Server 并收紧 workspace 与生成任务

**Files:**

- Delete: `server/**`
- Modify: `pnpm-workspace.yaml`
- Modify: `mise.toml`
- Regenerate: `pnpm-lock.yaml`

**Interfaces:**

- Consumes: 已提交的 `open-api/immich-openapi-specs.json`。
- Produces: 不含 `server` importer/task 的 workspace；仍可从 snapshot 生成 TypeScript 和 Dart 客户端的 `mise //:open-api`。

- [ ] **Step 1: 记录删除前安全基线**

Run:

```bash
git status --short
shasum -a 256 \
  mobile/ios/Runner.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved \
  mobile/ios/Runner.xcworkspace/xcshareddata/swiftpm/Package.resolved
git status --short --untracked-files=all -- server
git status --short --ignored --untracked-files=all -- server
```

Expected: `server/` 内没有未跟踪的用户文件；仅允许受版本控制文件和可重建的 `.DS_Store`/`node_modules`。

- [ ] **Step 2: 删除受版本控制的原 Server**

Run:

```bash
git rm -r -- server
```

Expected: 680 个原 Server 文件进入删除状态。

- [ ] **Step 3: 删除已确认可重建的 Server 本地产物**

在执行前再次解析绝对路径并确认目标精确等于仓库根下的 `server`，然后删除残留的 `server/.DS_Store`、`server/node_modules` 和空目录。

Expected: `test ! -e server` 成功。

- [ ] **Step 4: 从 pnpm 与 mise 拓扑移除 Server**

在 `pnpm-workspace.yaml` 删除：

```yaml
- server
```

在 `mise.toml`：

- 从 `monorepo.config_roots` 删除 `server`；
- 将 `tasks.open-api` 改为只运行 plugins、`:open-api-typescript` 和 `:open-api-dart`；
- 删除 `tasks.sql`；
- 删除依赖旧 Docker/Server 的 `dev*`、`prod*` 和根级 Compose `e2e*` tasks；
- 从 `tasks.clean` 删除对已移除 `*-down` tasks 的调用。

- [ ] **Step 5: 重新生成 pnpm lockfile**

Run:

```bash
pnpm install --lockfile-only
```

Expected: `pnpm-lock.yaml` 不再包含 `server:` importer，保留的 workspace importer 均可解析。

- [ ] **Step 6: 验证 task 与 workspace 边界**

Run:

```bash
test ! -e server
test -z "$(git ls-files server)"
! rg -n '^  server:$' pnpm-lock.yaml
! rg -n '//server:|dir = "server"|"server",' mise.toml pnpm-workspace.yaml
mise tasks ls --all --name-only
mise tasks info //:open-api
```

Expected: 没有 `//server:*` task，`//:open-api` 只依赖客户端生成链路。

---

### Task 2: 删除原 Server 的 Docker、devcontainer 与发布自动化

**Files:**

- Delete: `docker/**`
- Delete: `.devcontainer/**`
- Modify: `.dockerignore`
- Modify: `.github/labeler.yml`
- Modify: `.github/workflows/docker.yml`
- Modify: `.github/workflows/prepare-release.yml`
- Modify: `CODEOWNERS`

**Interfaces:**

- Consumes: 独立的 `machine-learning/Dockerfile`。
- Produces: 仅构建仍由本仓库拥有的镜像/模块的 CI；不再发布 `immich-server` 镜像或打包旧 Compose 文件。

- [ ] **Step 1: 删除旧运行栈文件**

删除 `docker/` 和 `.devcontainer/`。核查发现 Mobile devcontainer 同样继承 `server/Dockerfile.dev` 和旧 Compose 服务，无法在 Server 删除后独立保留。

- [ ] **Step 2: 清理仓库元数据**

- `.dockerignore` 删除 `server/upload/`、`server/src/queries`、`server/www/`；
- `.github/labeler.yml` 删除 Server path label；
- `CODEOWNERS` 删除 `/server/` owner。

- [ ] **Step 3: 将 Docker workflow 收口到 Machine Learning**

在 `.github/workflows/docker.yml` 删除：

- `server` path filter；
- `retag_server` job；
- `server` image build job；
- `success-check-server` job。

保留 `machine-learning`、`retag_ml` 和 `success-check-ml`，并确保 `pre-job` 输出只访问存在的 filter key。

- [ ] **Step 4: 清理 release 资产列表**

在 `.github/workflows/prepare-release.yml` 删除对 `docker/docker-compose.yml`、`docker/docker-compose.rootless.yml`、`docker/example.env`、hardware acceleration fragments 和 Prometheus 配置的复制/发布步骤。

- [ ] **Step 5: 验证配置不引用已删除路径**

Run:

```bash
test ! -e docker
test ! -e .devcontainer
! rg -n 'server/Dockerfile|server/Dockerfile.dev|docker/docker-compose|/server/' \
  .dockerignore CODEOWNERS .github/labeler.yml .github/workflows/docker.yml .github/workflows/prepare-release.yml
```

Expected: Server image、Compose 和 devcontainer 引用全部消失，ML workflow 仍保留。

---

### Task 3: 将 E2E 收口为不依赖后端的 UI mock 测试

**Files:**

- Delete: `e2e/docker-compose.yml`
- Delete: `e2e/docker-compose.dev.yml`
- Delete: `e2e/vitest.config.ts`
- Delete: `e2e/vitest.maintenance.config.ts`
- Delete: `e2e/src/docker-compose.ts`
- Delete: `e2e/src/api/**`
- Delete: `e2e/src/specs/**`
- Delete: `e2e/src/generators.ts`
- Delete: `e2e/src/responses.ts`
- Delete: `e2e/src/utils.ts`
- Delete: `e2e/test-assets/**`
- Create: `e2e/src/ui/fixtures.ts`
- Create: `e2e/src/ui/sdk.ts`
- Modify: `e2e/src/ui/generators/timeline/rest-response.ts`
- Modify: `e2e/src/ui/specs/asset-viewer/asset-viewer.e2e-spec.ts`
- Modify: `e2e/src/ui/specs/asset-viewer/utils.ts`
- Modify: `e2e/src/ui/specs/timeline/timeline.e2e-spec.ts`
- Modify: `e2e/playwright.config.ts`
- Modify: `e2e/package.json`
- Modify: `e2e/mise.toml`
- Modify: `e2e/tsconfig.json`
- Regenerate: `pnpm-lock.yaml`

**Interfaces:**

- Consumes: `@immich/sdk` types and the Web Vite development server.
- Produces: 仅通过 Playwright request interception 验证 Web UI 的测试 harness，不连接数据库、旧 NestJS Server、CLI 或 maintenance runtime。

- [ ] **Step 1: 添加最小 UI fixtures 与 SDK 初始化**

`e2e/src/ui/fixtures.ts` 只导出 mock UI 使用的 owner 信息：

```ts
export const owner = {
  email: "admin@immich.cloud",
  name: "Immich Admin",
};
```

`e2e/src/ui/sdk.ts` 将生成 SDK 指向 Playwright base URL：

```ts
import { setBaseUrl } from "@immich/sdk";
import { playwriteBaseUrl } from "../../playwright.config";

export const initializeSdk = () => setBaseUrl(`${playwriteBaseUrl}/api`);
```

更新四个 consumer，移除对旧 `src/fixtures` 和 `src/utils` 的引用。

- [ ] **Step 2: 删除真实 Server/API 测试与 Compose harness**

删除上述 server、CLI、maintenance、真实 Web integration specs 与 Docker setup 文件；只保留 `e2e/src/ui/**`。

- [ ] **Step 3: 改造 Playwright 启动方式**

`e2e/playwright.config.ts`：

- `testDir` 指向 `./src/ui/specs`；
- 只保留 `ui` project；
- 删除 database host 和 backend project；
- `webServer.command` 使用 `pnpm --dir ../web exec vite dev --host 127.0.0.1 --port 2285`；
- 保留 `PLAYWRIGHT_DISABLE_WEBSERVER` 供 CI/本地复用已启动的 Web。

- [ ] **Step 4: 清理 E2E scripts 与 dependencies**

`e2e/package.json` 删除 Vitest、Server、CLI、PostgreSQL、supertest、Socket.IO client、ExifTool 和不再使用的 scripts/dependencies。保留 Playwright UI、SDK、mock 数据生成和 lint/typecheck 所需依赖。

`e2e/mise.toml`：

- 删除 Docker `build` task；
- `test`/`test-web` 直接运行 `playwright test --project=ui`；
- `ci-setup` 只安装/构建 SDK 并安装 E2E dependencies；
- 保留 format、lint、check 和 browser install tasks。

`e2e/tsconfig.json` 删除对已删除 Vitest config 的包含要求。

- [ ] **Step 5: 更新 CI 的 E2E 边界**

在 `.github/workflows/test.yml`：

- 删除 `server` filter、`server-unit-tests`、`server-medium-tests`、`e2e-tests-server-cli` 和 `sql-schema-up-to-date`；
- 将 `e2e-tests-web` 收口为 UI mock Playwright job，不再启动 Docker Compose；
- 将 `success-check-e2e` 只依赖该 UI job；
- 保留 `generated-api-up-to-date`，但删除 Server install，并让它从已提交 spec 运行 `mise //:open-api`；校验 TypeScript 与 Dart generated outputs。

- [ ] **Step 6: 重新生成 lockfile 并验证 UI harness**

Run:

```bash
pnpm install --lockfile-only
mise //e2e:ci-unit
pnpm --dir e2e exec playwright test --project=ui --list
```

Expected: E2E package 不再安装 Server-only dependencies，Playwright 能发现全部 UI mock specs，lint 和 typecheck 通过。

---

### Task 4: 更新项目说明和跨仓库开发规则

**Files:**

- Modify: `README.md`
- Modify: `AGENTS.md`
- Modify: `web/AGENTS.md`
- Modify: `mobile/AGENTS.md`
- Modify: `machine-learning/AGENTS.md`
- Modify: `docs/AGENTS.md`
- Modify: `engineering/README.md`
- Modify: `engineering/architecture.md`
- Modify: `engineering/module-map.md`
- Modify: `engineering/technology-stack.md`
- Modify: `engineering/development-guide.md`
- Modify: `engineering/testing-guide.md`
- Delete: `engineering/modules/server.md`
- Create: `engineering/modules/external-server.md`
- Modify: `engineering/modules/web.md`
- Modify: `engineering/modules/mobile.md`
- Modify: `engineering/modules/machine-learning.md`
- Modify: `engineering/modules/contracts-and-packages.md`
- Modify: `engineering/modules/infrastructure-and-tooling.md`
- Modify: `docs/docs/developer/architecture.mdx`
- Modify: `docs/docs/developer/database-migrations.md`
- Modify: `docs/docs/developer/devcontainers.md`
- Modify: `docs/docs/developer/directories.md`
- Modify: `docs/docs/developer/pr-checklist.md`
- Modify: `docs/docs/developer/setup.md`
- Modify: `docs/docs/developer/testing.md`

**Interfaces:**

- Consumes: `../photo-classifier/README.md`、`../photo-classifier/docs/architecture.md`、`../photo-classifier/docs/testing.md` 中的现行后端事实。
- Produces: 清晰的仓库所有权、开发入口、契约更新顺序和测试边界。

- [ ] **Step 1: 更新顶层入口**

在 `README.md` 顶部增加 fork-specific repository notice：本仓库负责客户端，实际后端位于同级 `photo-classifier`，后端启动与配置以其 README 为准。

在 `AGENTS.md`：

- 删除 `server/AGENTS.md` 导航；
- 将仓库地图中的 Server 替换为外部 `photo-classifier`；
- 将 backend runtime/source/test 权威来源指向同级仓库；
- 将 API contract 流程改为“外部后端行为 → 本仓库 OpenAPI snapshot → SDK → Web/Mobile”；
- 保持根文件不超过 180 行。

- [ ] **Step 2: 更新 scoped agent 指南**

- `web/AGENTS.md`：SDK 变化以已核对的外部 backend contract 为输入；浏览器集成测试只保留 mock UI，真实兼容测试在后端仓库执行。
- `mobile/AGENTS.md`：sync/upload/OpenAPI 变化需与 `photo-classifier` 的 compatibility contract 对齐。
- `machine-learning/AGENTS.md`：删除必须同步原 Server repository 的要求，明确该模块当前不在 `photo-classifier` runtime path。
- `docs/AGENTS.md`：公开文档涉及 backend setup 时以 `photo-classifier` 为当前实现来源，并区分保留的上游 Immich 参考内容。

- [ ] **Step 3: 重写工程架构 owners**

- `engineering/architecture.md`：以 Web/Mobile → external Go API → MySQL/media/pipeline 的拓扑替换 Nest/PostgreSQL/Valkey worker 拓扑；将 `machine-learning/` 标为保留但未接入当前 runtime。
- `engineering/module-map.md`：删除 `server/` 一级目录，增加 external backend 边界和 client contract 依赖方向。
- `engineering/technology-stack.md`：移除本仓库 Server 技术栈，将 Go/Gin/MySQL 作为外部实现说明并引用 sibling manifest 文本路径。
- `engineering/development-guide.md`：API/数据库/上传/backend job 变更路由到 `photo-classifier`；本仓库只生成和验证 clients。
- `engineering/testing-guide.md`：删除 Server unit/medium/real E2E 命令，保留 Web/Mobile/ML 及 mock UI Playwright 验证。
- `engineering/README.md`：更新推荐阅读路线、owner 表和已知文档偏差。

- [ ] **Step 4: 更新模块文档**

用 `engineering/modules/external-server.md` 替代 `engineering/modules/server.md`，内容包括：

- checkout 边界与权威来源；
- Go API、MySQL、pipeline、上传和 Immich compatibility 职责；
- Web 的 `IMMICH_SERVER_URL` 与 Mobile runtime URL；
- API snapshot 更新顺序；
- 后端测试在 sibling repo 运行，本仓库不提供代理 task。

同步修正 Web、Mobile、Machine Learning、contracts 和 infrastructure 模块文档中的旧 Server 依赖。

- [ ] **Step 5: 更新公开开发者文档中的可执行入口**

公开文档保持 English：

- 移除不存在的 `server/` path、`//server:*` task、Nest devcontainer 和数据库 migration 操作；
- 指明本 fork 的 backend development/testing/deployment 位于 sibling `photo-classifier` checkout；
- Web setup 使用 `IMMICH_SERVER_URL`；
- E2E 仅记录 mock-based UI project；
- 对仍保留的上游产品说明加清晰 scope note，不把它描述为本仓库可执行代码。

- [ ] **Step 6: 格式化并验证文档**

Run:

```bash
pnpm exec prettier --config .prettierrc --write \
  README.md AGENTS.md web/AGENTS.md mobile/AGENTS.md machine-learning/AGENTS.md docs/AGENTS.md \
  engineering docs/docs/developer
mise //docs:format
```

Expected: Markdown/MDX 使用各自配置格式化，所有新相对链接存在。

---

### Task 5: 完整验证与工作区审计

**Files:**

- Verify only: all changed files

**Interfaces:**

- Consumes: Tasks 1–4 的最终工作树。
- Produces: 可审阅的删除清单、通过的客户端检查和明确记录的未运行项。

- [ ] **Step 1: 验证无旧 Server 实现或构建入口**

Run:

```bash
test ! -e server
test -z "$(git ls-files server)"
! rg -n '//server:|server/Dockerfile|server/Dockerfile.dev|pnpm --dir server|working-directory: ./server' \
  AGENTS.md README.md pnpm-workspace.yaml mise.toml .github .devcontainer e2e engineering docs/docs/developer
```

Expected: 命令成功；允许 OpenAPI 路由中的 `/server/...`、历史 `docs/superpowers/` provenance 和明确描述“已删除 server/”的 ADR/迁移说明。

- [ ] **Step 2: 验证任务和 lockfile**

Run:

```bash
pnpm install --frozen-lockfile
mise tasks ls --all --name-only
mise tasks info //:open-api
mise tasks info //web:check
mise tasks info //e2e:test
```

Expected: install 与 task discovery 成功，无 missing `//server:*` reference。

- [ ] **Step 3: 验证客户端和 UI 测试基础设施**

Run:

```bash
mise //:sdk:build
mise //web:check
mise //web:test --run
mise //e2e:ci-unit
pnpm --dir e2e exec playwright test --project=ui --list
```

如当前环境已有 Chromium，再运行：

```bash
pnpm --dir e2e exec playwright test --project=ui
```

Expected: SDK build、Web static/type tests、E2E lint/typecheck 和 Playwright discovery 通过；浏览器二进制可用时 UI specs 通过。

- [ ] **Step 4: 验证文档、YAML 与链接**

Run:

```bash
mise //docs:format
pnpm exec prettier --config .prettierrc --check AGENTS.md engineering
```

使用仓库现有 Node/Python 环境解析修改后的 YAML，并扫描 Markdown 相对链接；报告任何指向已删除 `server/`、`docker/` 或 server devcontainer 的活动文档链接。

```bash
ruby -e 'require "yaml"; ARGV.each { |file| YAML.load_file(file, aliases: true) }' \
  .github/labeler.yml .github/workflows/docker.yml .github/workflows/prepare-release.yml .github/workflows/test.yml
python3 - <<'PY'
import pathlib
import re
import sys

roots = [pathlib.Path('README.md'), pathlib.Path('AGENTS.md'), pathlib.Path('engineering'), pathlib.Path('docs/docs/developer')]
files = []
for root in roots:
    files.extend(root.rglob('*.md') if root.is_dir() else [root])
    if root.is_dir():
        files.extend(root.rglob('*.mdx'))

missing = []
for file in files:
    text = file.read_text(encoding='utf-8')
    for target in re.findall(r'\[[^\]]+\]\(([^)]+)\)', text):
        target = target.split('#', 1)[0]
        if not target or '://' in target or target.startswith('/'):
            continue
        resolved = (file.parent / target).resolve()
        if not resolved.exists():
            missing.append(f'{file}: {target}')

if missing:
    print('\n'.join(missing))
    sys.exit(1)
PY
```

- [ ] **Step 5: 确认用户改动未被触碰并检查最终 diff**

Run:

```bash
shasum -a 256 \
  mobile/ios/Runner.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved \
  mobile/ios/Runner.xcworkspace/xcshareddata/swiftpm/Package.resolved
git diff --check
git status --short
git diff --stat
```

Expected: 两个 hash 与 Task 1 基线一致；除这两项既有修改外，其余 diff 全部可由 ADR 范围解释。
