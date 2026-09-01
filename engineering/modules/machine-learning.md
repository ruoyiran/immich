# Machine Learning 模块

`machine-learning/` 是可独立运行的 Python/FastAPI inference service，包含 model loading、cache、pre/post-processing 和多种 ONNX Runtime provider。

## 当前状态

该模块被保留用于独立开发与兼容，但当前 `photo-classifier` runtime 使用其配置的外部 CLIP、Face 和 Text model services，不依赖本目录。不能把这里的 endpoint 或环境变量描述为当前系统生产路径。

## 变更规则

- request/response schema 在 Python model 中维护；
- provider 是 optional capability，必须保留 CPU fallback；
- unit tests 不下载 production-size models；
- cache/revision 变化要验证 offline startup 和 failed-download recovery；
- 若未来由 `photo-classifier` 接入，需单独更新该仓库 integration 和跨仓库测试。

## 验证

```bash
mise //machine-learning:test
mise //machine-learning:lint
mise //machine-learning:check
mise //machine-learning:checklist
```
