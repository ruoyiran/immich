# 工程文档维护指南

> 用途：规定工程文档的权威来源、唯一归属、更新时机和审查方式。  
> 权威来源：`CONTRIBUTING.md`、`mise.toml`、package manifests、`.github/workflows/`、源码与测试。  
> 更新触发：文档结构、维护流程、权威来源或 scoped instruction 策略发生变化。

## 信息权威来源

不同信息类型使用各自的权威来源，不能用统一顺序覆盖所有场景。

| 信息类型                       | 首要来源                                  | 冲突处理                                 |
| ------------------------------ | ----------------------------------------- | ---------------------------------------- |
| 贡献政策与上游接受边界         | `CONTRIBUTING.md`、PR templates           | 工程文档必须服从并直接链接政策           |
| 工具版本、task、package script | `mise.toml`、manifest、lockfile、生成脚本 | 以配置为准，登记文档偏差                 |
| CI 门禁                        | `.github/workflows/` 和被调用脚本         | 不把本地建议写成 CI 强制规则             |
| 运行行为、架构、数据流         | 当前源码和测试                            | 以实现为当前事实，单独记录公开文档偏差   |
| 公开 setup/how-to              | `docs/docs/developer/` 与实际脚本         | 公开文档为 owner，内部文档只补充选择路径 |
| 解释性工程总结                 | `engineering/`                            | 必须附来源，不能反向覆盖实现或政策       |

Graphify、搜索结果、聊天记录和一次性分析只能作为线索。

## 信息唯一归属

- 跨模块拓扑和端到端流只在 [系统架构](architecture.md) 展开。
- 一级目录职责和依赖方向只在 [模块地图](module-map.md) 展开。
- 显式版本只在 [技术栈](technology-stack.md) 集中维护；模块特有的 schema/protocol 版本风险除外。
- 变更选择矩阵只在 [开发指南](development-guide.md) 与 [测试指南](testing-guide.md) 维护。
- 模块内部层次、风险和迁移态只在 `modules/*.md` 展开。
- `AGENTS.md` 只保留可执行规则和链接。
- 完整公开 setup/how-to 保留在 `docs/docs/developer/`。

修改前先确认 owner；其他文档应链接对应章节，而不是复制段落。

## 文档元数据

除本目录索引外，每篇 `engineering/` 文档使用以下页首：

```markdown
> 用途：说明本文负责回答的问题。  
> 权威来源：列出当前仓库中的源码、配置或公开文档路径。  
> 更新触发：列出必须重新核对本文的代码或配置变化。
```

全局核对基线只记录在 [README](README.md)。单篇文档只有在独立复核时间与全局基线不同时才记录自己的 commit。

引用源码时使用仓库相对链接。不能验证的事实必须标记为“待确认”，不能转化为强制规则。

## 更新触发条件

以下变化必须检查对应 owner：

- 工具链或主要框架版本变化；
- 新增、删除或重命名一级模块；
- Server worker、queue、database、WebSocket 或 ML 调用边界变化；
- Web 初始化、状态所有权或 SDK 使用方式变化；
- Mobile sync、Drift schema、Pigeon 或 background lifecycle 变化；
- `mise` task、package script、CI job 或测试入口变化；
- OpenAPI、SDK、translation 或其他生成目录变化；
- 公开开发者文档修复了本手册记录的偏差。

## Documentation debt

发现公开文档、README 或工程文档与实现不一致时：

1. 用源码、测试和配置确认当前事实。
2. 在 [README](README.md#已知文档偏差) 或对应模块文档记录偏差及来源。
3. 不在无关功能变更中顺带大规模改写公开文档。
4. 将上游修正拆成独立、可审阅的变更。
5. 修正合入后删除内部偏差记录，避免永久保留双重事实。

## 新增 scoped AGENTS.md 的门槛

只有同时满足以下条件才新增更深层的 `AGENTS.md`：

- subtree 有稳定且反复出现的局部规则；
- 父级规则无法准确表达其生成、验证或风险边界；
- 文件不会机械复制父级内容；
- 能明确指出至少一个必读文档和一个可验证命令；
- 预计维护成本低于每次任务重新发现规则的成本。

首期 scoped 文件仅覆盖 Server、Web、Mobile、Machine Learning 和 public docs。`packages/` 与 `e2e/` 由根规则和中央文档覆盖。

## 删除与归档规则

- 事实过期时直接更新或删除，不无限追加时间线说明。
- 临时设计规格保留在 `docs/superpowers/specs/` 作为变更 provenance，不继续扩展为工程手册。
- 长期跨模块决策使用 [ADR](decisions/README.md)；被替代决策标记 `Superseded` 并链接后继 ADR。
- 删除模块或 task 时，同一变更必须清理所有导航和最低验证入口。

## 审查清单

- [ ] 修改了信息唯一 owner，而不是复制到多个文件。
- [ ] 每个显式版本都链接 manifest、lockfile 或平台配置。
- [ ] 每个 `mise` 命令都能通过 `mise tasks info <task>` 解析。
- [ ] 相对 Markdown 链接存在。
- [ ] `AGENTS.md` 没有重复父级规则，且满足行数预算。
- [ ] 没有把建议性检查描述成 CI 门禁。
- [ ] 没有修改业务代码、生成物或无关公开文档。
- [ ] Prettier 与 whitespace 检查通过。
