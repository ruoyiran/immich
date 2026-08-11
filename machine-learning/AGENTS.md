# Machine Learning Agent 指南

## 适用范围

适用于 `machine-learning/**`。继承 [`../AGENTS.md`](../AGENTS.md) 中的仓库级规则。

## 开始前阅读

- [Machine Learning 模块指南](../engineering/modules/machine-learning.md)
- [系统架构](../engineering/architecture.md)
- [Remote ML 安全指南](../docs/docs/guides/remote-machine-learning.md)

## 架构规则

- 保持 ML 为 HTTP inference service；Server 负责 business persistence 和 job orchestration。
- 在 Python schema 中定义 request/response 变更，并在同一变更中更新 Server ML repository。
- 将 model loading/cache 行为与 model-specific preprocessing 和 postprocessing 分离。
- 将 execution provider 视为 optional capability；绝不要假设 GPU hardware 可用。
- 保持普通测试 deterministic 且规模小；不要在 unit test 中下载 production-size model。

## 生成文件与联动变更

- Dependency/provider 变更必须更新 `pyproject.toml`/lock state 和兼容的 container image variant。
- `/predict` contract 变更需要检查 Server request/response、error handling、job behavior 和 persistence。
- Model revision/cache layout 变更需要审查 upgrade、offline-startup 和 failed-download recovery。
- 新 hardware provider 需要 availability detection、provider options、fallback 和 hardware-specific validation。
- 不要公开暴露 remote ML；它没有 built-in authentication，并会接收 media input。

## 验证

优先选择最窄的相关命令：

- 测试与 coverage：`mise //machine-learning:test`
- Ruff lint：`mise //machine-learning:lint`
- mypy strict：`mise //machine-learning:check`
- 完整 module gate：`mise //machine-learning:checklist`

在完整 checklist 前，先针对 endpoint/cache/provider 行为运行 focused pytest。对于 request/response 变更，还要为 `MachineLearningRepository` 及调用方 services/jobs 运行 focused Server tests。

## 高风险检查

- 验证 concurrent cold-start 和 failed-load cache cleanup。
- preprocessing/postprocessing 变更后验证 tensor shape/dtype 和 result semantics。
- 新增或修改 hardware provider 时验证 CPU fallback。
- 验证 timeout/retry 行为不会意外成倍增加昂贵的 inference。
- 保持 trusted-network 指南和 model-cache persistence 假设。
