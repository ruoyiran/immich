# 上游协作与 AI 使用边界

> 用途：说明内部工程知识与 Immich 上游贡献流程的关系，并准确保留 generative AI 政策。  
> 权威来源：[CONTRIBUTING.md](../CONTRIBUTING.md)、PR templates、公开开发者文档。  
> 更新触发：贡献政策、feature freeze、PR template 或内部/公开文档边界变化。

## 本地工程文档与上游文档

`engineering/` 服务于本地理解、开发和 AI 协作；`docs/docs/` 是公开英文 Docusaurus 内容。两者可以互相链接，但职责不同：

- 内部手册记录跨模块关系、当前实现、风险和选择路径。
- 公开文档提供面向贡献者与用户的稳定 how-to。
- 内部发现不自动等于可接受的上游变更。
- 公开文档偏差应以独立、聚焦的修正提交处理。

## 提交前的责任边界

准备上游工作前必须：

1. 阅读 [CONTRIBUTING.md](../CONTRIBUTING.md) 和当前 PR template。
2. 检查相关区域是否处于 feature freeze。
3. 理解变更的行为、兼容性、生成物和测试影响。
4. 运行与风险相称的验证，并能解释结果。
5. 保持 PR 聚焦，不把内部文档初始化或无关重构混入功能修复。

本手册不能代替维护者判断，也不能保证某项工作会被上游接受。

## Generative AI 政策

仓库当前政策的关键边界是：

- 不要提交由 LLM 生成的 PR。维护者要求贡献者能够证明自己理解变更的全部影响。
- 可以使用 LLM 翻译简洁的 PR 标题或描述，但必须遵循 PR template。
- 禁止使用 LLM 修复带 `good-first-issue` 标签的 issue；这类 PR 会被自动关闭。
- 隐瞒 LLM 使用、自动化低质量贡献或反复触发自动关闭规则，可能导致维护者阻止贡献者。

政策原文以 [Use of generative AI](../CONTRIBUTING.md#use-of-generative-ai) 为准。政策变化时，本页和根 `AGENTS.md` 必须同步复核。

## 将本地发现整理为上游修复

发现文档或代码问题后：

1. 用源码、测试和配置复核事实。
2. 将“当前行为”“文档偏差”“建议修改”分开记录。
3. 确认没有 feature freeze、重复 PR 或已有维护者决策。
4. 将修正缩小到单一主题，并使用公开文档的语言和结构。
5. 由贡献者逐行审阅、验证并承担最终责任。

不要把 Graphify、自动总结或聊天结论直接作为上游证据；链接实际源码、配置、测试或可复现行为。

## Feature freeze 与范围确认

Feature freeze 会随上游状态变化，因此不在本手册复制具体名单。准备功能工作时直接检查 [CONTRIBUTING.md](../CONTRIBUTING.md#feature-freezes) 和相关 issue/discussion。

如果修复需要显著扩展范围、改变公开行为或触及冻结区域，应先与维护者确认方向，而不是先完成大型实现。
