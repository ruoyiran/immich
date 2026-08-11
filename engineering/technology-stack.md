# 技术栈

> 用途：集中记录仓库工具链、主要框架和数据基础设施的当前版本及其来源。  
> 权威来源：[`mise.toml`](../mise.toml)、package manifests、[`pnpm-lock.yaml`](../pnpm-lock.yaml)、Mobile/ML manifests 与 Compose。  
> 更新触发：工具链、主要框架、platform target、database/queue image 或生成器版本变化。

## 版本读取原则

本文区分三类版本：

- **Pinned tool**：`mise.toml` 或平台配置中的固定版本，开发环境应使用该值。
- **Declared range**：manifest 允许的版本范围，用于表达兼容范围。
- **Resolved version**：lockfile 或已安装 workspace 中当前实际解析的版本。

版本来源冲突时，先判断它们是否属于不同类别。不要把 manifest range 当成当前解析版本，也不要把本机临时版本写成仓库要求。

本文只维护影响架构、生成、兼容性或开发入口的依赖，不复制完整 dependency tree。

## Repository toolchain

| 工具                | 版本        | 类型             | 来源                                                                     |
| ------------------- | ----------- | ---------------- | ------------------------------------------------------------------------ |
| Node.js             | 24.15.0     | Pinned tool      | [`mise.toml`](../mise.toml)                                              |
| pnpm                | 11.17.0     | Pinned tool      | [`mise.toml`](../mise.toml)、[`package.json`](../package.json)           |
| Java                | 21.0.2      | Pinned tool      | [`mise.toml`](../mise.toml)                                              |
| OpenAPI CLI wrapper | 2.40.1      | Pinned tool      | [`mise.toml`](../mise.toml)                                              |
| OpenAPI Generator   | 7.24.0      | Pinned generator | [`open-api/openapitools.json`](../open-api/openapitools.json)            |
| oazapfts            | 7.5.0       | Pinned tool      | [`mise.toml`](../mise.toml)                                              |
| OpenTofu            | 1.12.5      | Pinned tool      | [`mise.toml`](../mise.toml)                                              |
| Terragrunt          | 1.1.1       | Pinned tool      | [`mise.toml`](../mise.toml)                                              |
| Jellyfin FFmpeg     | 7.1.3-6     | Pinned tool      | [`mise.toml`](../mise.toml)                                              |
| Extism CLI          | 1.6.3       | Pinned tool      | [`mise.toml`](../mise.toml)                                              |
| Extism JS PDK       | 1.6.0       | Pinned tool      | [`mise.toml`](../mise.toml)                                              |
| Binaryen            | version_124 | Pinned tool      | [`mise.toml`](../mise.toml)                                              |
| Prettier            | 3.9.6       | Resolved version | [`package.json`](../package.json)、[`pnpm-lock.yaml`](../pnpm-lock.yaml) |

根 `mise.toml` 同时定义 workspace project roots 和 OpenAPI、Docker、SDK、release 等跨模块 task。

## Server

| 组件               | 版本                | 类型              | 来源                                                                                   |
| ------------------ | ------------------- | ----------------- | -------------------------------------------------------------------------------------- |
| TypeScript         | 6.0.2 alias package | Resolved version  | [`server/package.json`](../server/package.json)、[`pnpm-lock.yaml`](../pnpm-lock.yaml) |
| NestJS core/common | 11.1.28             | Resolved version  | [`server/package.json`](../server/package.json)、[`pnpm-lock.yaml`](../pnpm-lock.yaml) |
| Express            | 5.2.1               | Resolved version  | [`server/package.json`](../server/package.json)、[`pnpm-lock.yaml`](../pnpm-lock.yaml) |
| Zod                | 4.3.6               | Pinned dependency | [`server/package.json`](../server/package.json)                                        |
| Kysely             | 0.28.17             | Pinned dependency | [`server/package.json`](../server/package.json)                                        |
| postgres.js        | 3.4.9               | Pinned dependency | [`server/package.json`](../server/package.json)                                        |
| BullMQ             | 5.81.2              | Resolved version  | [`server/package.json`](../server/package.json)、[`pnpm-lock.yaml`](../pnpm-lock.yaml) |
| ioredis            | 5.11.1              | Resolved version  | [`server/package.json`](../server/package.json)、[`pnpm-lock.yaml`](../pnpm-lock.yaml) |
| Socket.IO          | 4.x                 | Declared major    | [`server/package.json`](../server/package.json)                                        |
| Vitest             | 3.x                 | Declared major    | [`server/package.json`](../server/package.json)                                        |

Server runtime 还使用 OpenTelemetry、Extism plugin runtime、FFmpeg/ExifTool 与 PostgreSQL extensions。完整依赖以 manifest/lockfile 为准。

## Web

| 组件                       | 版本                | 类型                      | 来源                                                                             |
| -------------------------- | ------------------- | ------------------------- | -------------------------------------------------------------------------------- |
| Svelte                     | 5.56.8              | Resolved version          | [`web/package.json`](../web/package.json)、[`pnpm-lock.yaml`](../pnpm-lock.yaml) |
| SvelteKit                  | 2.70.1              | Resolved version          | [`web/package.json`](../web/package.json)、[`pnpm-lock.yaml`](../pnpm-lock.yaml) |
| Vite                       | 8.1.5               | Resolved version          | [`web/package.json`](../web/package.json)、[`pnpm-lock.yaml`](../pnpm-lock.yaml) |
| Tailwind CSS               | 4.3.3               | Resolved version          | [`web/package.json`](../web/package.json)、[`pnpm-lock.yaml`](../pnpm-lock.yaml) |
| TypeScript                 | 6.0.2 alias package | Resolved version          | [`web/package.json`](../web/package.json)、[`pnpm-lock.yaml`](../pnpm-lock.yaml) |
| Vitest                     | 4.1.10              | Resolved version          | [`web/package.json`](../web/package.json)、[`pnpm-lock.yaml`](../pnpm-lock.yaml) |
| happy-dom                  | 20.11.1             | Resolved version          | [`web/package.json`](../web/package.json)、[`pnpm-lock.yaml`](../pnpm-lock.yaml) |
| Testing Library for Svelte | 5.4.2               | Resolved version          | [`web/package.json`](../web/package.json)、[`pnpm-lock.yaml`](../pnpm-lock.yaml) |
| Socket.IO client           | 4.8.3               | Resolved version          | [`web/package.json`](../web/package.json)、[`pnpm-lock.yaml`](../pnpm-lock.yaml) |
| svelte-i18n                | 4.0.1               | Resolved version          | [`web/package.json`](../web/package.json)、[`pnpm-lock.yaml`](../pnpm-lock.yaml) |
| `@immich/ui`               | 0.83.0              | Resolved external package | [`web/package.json`](../web/package.json)、[`pnpm-lock.yaml`](../pnpm-lock.yaml) |

Web 使用 static adapter 和 CSR 配置，运行模式见 [`web/svelte.config.js`](../web/svelte.config.js) 与 [`web/src/routes/+layout.ts`](../web/src/routes/+layout.ts)。

## Mobile

### Dart/Flutter

| 组件                    | 版本            | 类型                                    | 来源                                                                                       |
| ----------------------- | --------------- | --------------------------------------- | ------------------------------------------------------------------------------------------ |
| Flutter                 | 3.44.9          | Pinned tool                             | [`mobile/mise.toml`](../mobile/mise.toml)、[`mobile/pubspec.yaml`](../mobile/pubspec.yaml) |
| Dart SDK                | >=3.12.0 <4.0.0 | Declared range                          | [`mobile/pubspec.yaml`](../mobile/pubspec.yaml)                                            |
| Riverpod/hooks_riverpod | 2.6.1           | Declared range floor/current constraint | [`mobile/pubspec.yaml`](../mobile/pubspec.yaml)                                            |
| AutoRoute               | 11.1.0          | Declared range floor/current constraint | [`mobile/pubspec.yaml`](../mobile/pubspec.yaml)                                            |
| Drift/drift_dev         | 2.34.0          | Declared range floor/current constraint | [`mobile/pubspec.yaml`](../mobile/pubspec.yaml)                                            |
| Pigeon                  | 26.3.4          | Declared range floor/current constraint | [`mobile/pubspec.yaml`](../mobile/pubspec.yaml)                                            |
| Freezed                 | 3.2.5           | Declared range floor/current constraint | [`mobile/pubspec.yaml`](../mobile/pubspec.yaml)                                            |
| worker_manager          | 7.2.9           | Declared range floor/current constraint | [`mobile/pubspec.yaml`](../mobile/pubspec.yaml)                                            |
| photo_manager           | 3.9.0           | Pinned dependency                       | [`mobile/pubspec.yaml`](../mobile/pubspec.yaml)                                            |

### Android/iOS

| 平台项                      | 版本/目标 | 来源                                                                                                                                           |
| --------------------------- | --------- | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| Android Gradle Plugin       | 8.11.2    | [`mobile/android/gradle/libs.versions.toml`](../mobile/android/gradle/libs.versions.toml)                                                      |
| Kotlin                      | 2.2.20    | [`mobile/android/gradle/libs.versions.toml`](../mobile/android/gradle/libs.versions.toml)                                                      |
| Java/Kotlin bytecode target | 17        | [`mobile/android/app/build.gradle`](../mobile/android/app/build.gradle)                                                                        |
| Android minSdk              | 26        | [`mobile/android/app/build.gradle`](../mobile/android/app/build.gradle)                                                                        |
| Main iOS app minimum        | 15.0      | [`mobile/ios/Podfile`](../mobile/ios/Podfile)、[`mobile/ios/Runner.xcodeproj/project.pbxproj`](../mobile/ios/Runner.xcodeproj/project.pbxproj) |
| Share Extension minimum     | 16.0      | [`mobile/ios/Runner.xcodeproj/project.pbxproj`](../mobile/ios/Runner.xcodeproj/project.pbxproj)                                                |
| Widget minimum              | 17.0      | [`mobile/ios/Runner.xcodeproj/project.pbxproj`](../mobile/ios/Runner.xcodeproj/project.pbxproj)                                                |

Android `compileSdk` 跟随 Flutter toolchain，而不是在 app build file 中固定数字。

## Machine Learning

| 组件                 | 版本                        | 类型           | 来源                                                                    |
| -------------------- | --------------------------- | -------------- | ----------------------------------------------------------------------- |
| Python               | 3.11                        | Pinned tool    | [`machine-learning/mise.toml`](../machine-learning/mise.toml)           |
| Python compatibility | >=3.11 <4.0                 | Declared range | [`machine-learning/pyproject.toml`](../machine-learning/pyproject.toml) |
| uv                   | 0.8.15                      | Pinned tool    | [`machine-learning/mise.toml`](../machine-learning/mise.toml)           |
| FastAPI              | >=0.95.2 <1.0               | Declared range | [`machine-learning/pyproject.toml`](../machine-learning/pyproject.toml) |
| Gunicorn             | >=21.1.0                    | Declared range | [`machine-learning/pyproject.toml`](../machine-learning/pyproject.toml) |
| Uvicorn              | >=0.22.0 <1.0               | Declared range | [`machine-learning/pyproject.toml`](../machine-learning/pyproject.toml) |
| ONNX                 | >=1.22.0                    | Declared range | [`machine-learning/pyproject.toml`](../machine-learning/pyproject.toml) |
| ONNX Runtime family  | >=1.23.2; OpenVINO >=1.24.1 | Declared range | [`machine-learning/pyproject.toml`](../machine-learning/pyproject.toml) |
| pytest               | >=7.3.1                     | Declared range | [`machine-learning/pyproject.toml`](../machine-learning/pyproject.toml) |
| mypy                 | >=1.3.0                     | Declared range | [`machine-learning/pyproject.toml`](../machine-learning/pyproject.toml) |
| Ruff                 | >=0.0.272                   | Declared range | [`machine-learning/pyproject.toml`](../machine-learning/pyproject.toml) |

CPU、CUDA、OpenVINO、Arm NN、RKNN 和 ROCm 通过 optional dependency/image variant 选择；不要假定所有 provider 同时可用。

## Data and infrastructure

| 组件                  | 版本/约束                                                | 来源                                                        |
| --------------------- | -------------------------------------------------------- | ----------------------------------------------------------- |
| PostgreSQL image base | 14                                                       | [`docker/docker-compose.yml`](../docker/docker-compose.yml) |
| VectorChord           | 0.4.3                                                    | [`docker/docker-compose.yml`](../docker/docker-compose.yml) |
| pgvectors             | 0.2.0                                                    | [`docker/docker-compose.yml`](../docker/docker-compose.yml) |
| Valkey                | 9                                                        | [`docker/docker-compose.yml`](../docker/docker-compose.yml) |
| Media storage         | shared filesystem mounted at `/data` in Server container | [`docker/docker-compose.yml`](../docker/docker-compose.yml) |
| ML model cache        | Docker named volume mounted at `/cache`                  | [`docker/docker-compose.yml`](../docker/docker-compose.yml) |

Compose 中的 digest 是 release-specific supply-chain pin，不在本手册复制；以 Compose 文件当前值为准。

## Testing and quality

| 范围               | 主要工具                                                  | 来源                                                                                                 |
| ------------------ | --------------------------------------------------------- | ---------------------------------------------------------------------------------------------------- |
| Server unit/medium | Vitest 3.x、Testcontainers/PostgreSQL                     | [`server/package.json`](../server/package.json)、[`server/test/`](../server/test/)                   |
| Web unit/component | Vitest 4.1.10、happy-dom、Testing Library                 | [`web/package.json`](../web/package.json)、[`web/vite.config.ts`](../web/vite.config.ts)             |
| Mobile             | Flutter test、Mocktail、Drift migration/integration tests | [`mobile/pubspec.yaml`](../mobile/pubspec.yaml)、[`mobile/test/`](../mobile/test/)                   |
| Machine Learning   | pytest、mypy、Ruff                                        | [`machine-learning/pyproject.toml`](../machine-learning/pyproject.toml)                              |
| API E2E            | Vitest 4.x                                                | [`e2e/package.json`](../e2e/package.json)                                                            |
| Browser E2E        | Playwright 1.x                                            | [`e2e/package.json`](../e2e/package.json)、[`e2e/playwright.config.ts`](../e2e/playwright.config.ts) |
| Public docs        | Docusaurus 3.10.x、Prettier 3.9.6                         | [`docs/package.json`](../docs/package.json)、[`pnpm-lock.yaml`](../pnpm-lock.yaml)                   |

详细测试选择见 [测试指南](testing-guide.md)。

## Generated contracts and SDKs

| 生成链路                   | 主要工具/输入                                                     | 输出                                 |
| -------------------------- | ----------------------------------------------------------------- | ------------------------------------ |
| Server OpenAPI sync        | Nest/OpenAPI decorators、Server build                             | `open-api/immich-openapi-specs.json` |
| TypeScript SDK             | oazapfts 7.5.0                                                    | `packages/sdk/src/fetch-client.ts`   |
| Dart SDK                   | OpenAPI Generator 7.24.0 + CLI wrapper 2.40.1 + templates/patches | `mobile/generated/openapi/`          |
| Mobile Dart models/routes  | build_runner、Freezed、AutoRoute                                  | generated Dart files                 |
| Drift schema test code     | drift_dev 2.34.0                                                  | `mobile/test/drift/main/generated/`  |
| Native platform interfaces | Pigeon 26.3.4                                                     | Dart/Swift/Kotlin interfaces         |
| Mobile localization        | easy_localization generators                                      | generated loader/keys                |

生成入口见根 [`mise.toml`](../mise.toml) 与 [`mobile/mise.toml`](../mobile/mise.toml)。

## Version update checklist

升级本文记录的组件时：

1. 修改唯一 manifest/tool config，不先改本文。
2. 按 package manager 或平台工具更新 lockfile/generated files。
3. 运行 owning module 的 focused tests 与 checklist。
4. 检查 API、schema、platform target 和 deployment compatibility。
5. 用实际解析结果更新本文，并保持“Pinned/Declared/Resolved”分类。
6. 若升级改变跨模块架构或长期兼容性，创建 ADR。
