# Immich 工程手册

> 全局核对基线：`11fe6db14e06a258020cf4ac3c34f35243429d96`  
> 用途：为人类开发者与 coding agent 提供跨模块架构、开发和验证导航。  
> 权威来源：仓库源码、测试、`mise.toml`、package manifests、CI 与公开开发者文档。  
> 更新触发：一级模块、架构边界、主要任务、工具链或公开开发流程发生变化。

## 文档定位

本目录是中文为主、技术术语保留英文的内部工程知识库，回答“系统如何组成”“修改会影响哪里”“应验证什么”等跨模块问题。

它不属于 Docusaurus 内容目录，不会替代以下公开英文文档：

- [贡献规范](../CONTRIBUTING.md)
- [开发环境配置](../docs/docs/developer/setup.md)
- [目录说明](../docs/docs/developer/directories.md)
- [测试指南](../docs/docs/developer/testing.md)
- [PR checklist](../docs/docs/developer/pr-checklist.md)
- [数据库迁移](../docs/docs/developer/database-migrations.md)

公开文档负责完整 setup/how-to；本手册负责当前源码事实、跨模块关系、风险和选择路径。

## 推荐阅读路线

| 场景                     | 阅读顺序                                                                                                          |
| ------------------------ | ----------------------------------------------------------------------------------------------------------------- |
| 第一次理解系统           | [系统架构](architecture.md) → [模块地图](module-map.md) → [技术栈](technology-stack.md)                           |
| 修改 Server API/DTO      | [Server 模块](modules/server.md) → [开发指南](development-guide.md) → [测试指南](testing-guide.md)                |
| 修改 Web                 | [Web 模块](modules/web.md) → [开发指南](development-guide.md) → [测试指南](testing-guide.md)                      |
| 修改 Mobile              | [Mobile 模块](modules/mobile.md) → [开发指南](development-guide.md) → [测试指南](testing-guide.md)                |
| 修改 ML                  | [Machine Learning 模块](modules/machine-learning.md) → [系统架构](architecture.md) → [测试指南](testing-guide.md) |
| 修改 OpenAPI/SDK/package | [Contracts 与 Packages](modules/contracts-and-packages.md) → [开发指南](development-guide.md)                     |
| 修改 Docker/CI/E2E       | [Infrastructure 与 Tooling](modules/infrastructure-and-tooling.md) → [测试指南](testing-guide.md)                 |
| 做长期架构决策           | [ADR 指南](decisions/README.md) → [维护指南](maintenance-guide.md)                                                |
| 准备上游贡献             | [上游协作与 AI 边界](upstream-collaboration.md) → [CONTRIBUTING.md](../CONTRIBUTING.md)                           |

## 工程文档地图

- [系统架构](architecture.md)：运行拓扑、进程模型和端到端数据流。
- [技术栈](technology-stack.md)：工具链、框架和版本来源。
- [模块地图](module-map.md)：一级目录职责、依赖方向和变更影响。
- [开发指南](development-guide.md)：按变更类型选择开发与生成流程。
- [测试指南](testing-guide.md)：测试分层与最低验证矩阵。
- [维护指南](maintenance-guide.md)：权威来源、唯一归属和更新触发。
- [上游协作与 AI 边界](upstream-collaboration.md)：本地知识与上游政策。
- [模块文档](modules/)：模块内部层次、风险、迁移态和源码入口。
- [架构决策](decisions/README.md)：轻量 ADR 规则与模板。

## 信息唯一归属

| 信息                             | 唯一 owner                                                                         |
| -------------------------------- | ---------------------------------------------------------------------------------- |
| 跨模块运行拓扑与端到端流         | [architecture.md](architecture.md)                                                 |
| 一级目录职责、依赖方向、联动范围 | [module-map.md](module-map.md)                                                     |
| 显式版本与技术清单               | [technology-stack.md](technology-stack.md)                                         |
| 变更类型到开发/测试入口          | [development-guide.md](development-guide.md)、[testing-guide.md](testing-guide.md) |
| 模块内部层次、风险和迁移态       | [modules/](modules/)                                                               |
| 可直接执行的 subtree 约束        | 最近的 `AGENTS.md`                                                                 |
| 完整公开 setup/how-to            | `docs/docs/developer/`                                                             |

其他文档只链接 owner，避免复制同一版本、流程或架构描述。

## 权威来源分类

- 贡献政策：`CONTRIBUTING.md` 与 PR templates。
- 工具版本和任务：`mise.toml`、manifest、lockfile、生成脚本。
- CI 门禁：`.github/workflows/` 与被调用脚本。
- 运行行为：当前源码和测试。
- 公开 how-to：`docs/docs/developer/`，并用实际脚本复核。
- 本手册：解释性总结，不能反向覆盖上述来源。

Graphify 和临时分析只用于发现关系，不是长期权威来源。

## 全局核对基线

本手册的初始核对基线是页首 commit。后续维护不要求每篇文件同步更新相同 commit；只有独立复核时间不同的文档才记录自己的基线。

## 已知文档偏差

初始分析确认以下内容需要未来独立修正，不在本次内部文档初始化中改写公开文档：

- 部分 Mobile 架构说明仍引用 Isar，而当前本地数据库实现是 Drift/SQLite。
- 部分 API 文档仍引用旧的 TypeScript SDK 路径；当前生成客户端位于 `packages/sdk/src/fetch-client.ts`。
- `mobile/README.md` 中的 `module_template`/`modules` 描述与当前目录不一致。
- 公开数据库迁移文档使用的 `mise //server:migrations` 当前指向不存在的 build output；可执行入口是 `server/package.json` 中的 `migrations:*` scripts。

处理流程见 [维护指南](maintenance-guide.md#documentation-debt)。

## 维护入口

架构、版本、目录、task、CI、生成流程或公开文档发生变化时：

1. 找到信息唯一 owner。
2. 用源码或配置复核事实。
3. 更新 owner 文档与必要链接。
4. 运行文档格式、相对链接和 task 名称检查。
5. 若变化具有长期跨模块影响，评估是否创建 ADR。
