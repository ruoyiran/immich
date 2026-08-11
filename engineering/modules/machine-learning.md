# Machine Learning 模块

> 用途：说明独立 ML 服务的 HTTP 边界、模型生命周期、ONNX provider、Server 集成和部署风险。  
> 权威来源：`machine-learning/immich_ml/`、`machine-learning/test_main.py`、`machine-learning/pyproject.toml`、`machine-learning/mise.toml` 与 Server ML repository。  
> 更新触发：ML endpoint/schema、model pipeline/cache、execution provider、Server request/response、image variant 或 remote-ML security 变化。

## 职责与服务边界

Machine Learning 是独立 Python HTTP service，负责：

- CLIP visual/text embeddings；
- facial detection 与 recognition；
- OCR detection/recognition；
- model download、cache、load/unload；
- ONNX/RKNN 等 execution backend 和 hardware provider selection；
- inference metrics、health 和 error reporting。

它不直接拥有 Immich 业务数据库。Server 发送请求、接收结果，并负责将 embedding、face、OCR 等数据持久化到 PostgreSQL。

跨服务数据流见 [系统架构](../architecture.md#machine-learning-调用流)。

## FastAPI 入口与请求流

[`machine-learning/immich_ml/main.py`](../../machine-learning/immich_ml/main.py) 创建 FastAPI app，主要 endpoint：

- `GET /`：service metadata/status；
- `GET /ping`：health check；
- `POST /predict`：统一 inference 入口。

典型请求流：

```text
Server service/job
  → MachineLearningRepository
  → POST /predict
  → request schema + model type/task
  → ModelCache 获取/创建 model
  → preprocess + inference + postprocess
  → typed result
  → Server persistence
```

Request/response schema 位于 [`machine-learning/immich_ml/schemas.py`](../../machine-learning/immich_ml/schemas.py) 和模型特定 schema。改变字段、枚举、错误语义或 media encoding 时，必须同时更新 Server repository/service 与测试。

## 模型加载与缓存

[`ModelCache`](../../machine-learning/immich_ml/models/cache.py) 使用 in-memory async cache：

- 首次请求时构建 model；
- 同一 key 的并发 load 使用 optimistic lock 协调；
- 可根据 TTL 重新验证或卸载不活跃 model；
- load 失败时会清理 model cache，避免保留部分初始化状态；
- model 文件保存在配置的 cache folder，容器默认挂载 `/cache` volume。

模型生命周期变化需要检查：

- 并发首载和重复下载；
- TTL/eviction；
- worker process 间 cache 是否共享；
- cache corruption/recovery；
- model revision 与 offline startup；
- memory pressure 和多个 model/task 并存。

## ONNX 推理与设备选择

[`machine-learning/immich_ml/sessions/ort.py`](../../machine-learning/immich_ml/sessions/ort.py) 负责 ONNX Runtime session 和 provider options。可用 provider 取决于安装的 optional dependency/image variant，包括 CPU、CUDA、OpenVINO、ROCm/MIGraphX、Arm NN、RKNN 等。

provider 顺序表示 preference。设备选择还会使用 config 中的 device id、thread 和 cache settings。新增 provider 时必须同时检查：

- Python optional dependency；
- container image suffix/build；
- available-provider detection；
- provider-specific options；
- fallback behavior；
- CI/test hardware 能否覆盖。

不要在通用代码中假定 GPU provider 存在。

## Server 集成

Server integration 位于 [`server/src/repositories/machine-learning.repository.ts`](../../server/src/repositories/machine-learning.repository.ts)。它负责：

- 构建 inference request；
- 选择配置的 ML URL；
- health/error handling；
- response decoding；
- 在多个 URL 之间按健康状态回退。

多个 ML URL 不是自动负载均衡承诺。改变 retry/fallback 时需要考虑重复请求成本、model cold start 和 job retry。

常见调用方包括 smart search、face、OCR 和 asset processing jobs。ML contract 变化不只验证 `/predict`，还要验证调用 job/service 如何持久化结果。

## 测试与质量工具

主要测试位于 [`machine-learning/test_main.py`](../../machine-learning/test_main.py)，覆盖 app、model mock、request/response 与 provider-related behavior。质量工具由 `pyproject.toml`/`mise.toml` 定义：

- pytest + pytest-asyncio/pytest-mock；
- coverage；
- mypy strict；
- Ruff lint/format；
- optional provider markers。

新增模型或 provider 时，优先使用小型 fake/mocked model 验证 orchestration；不要让普通 unit tests 下载大型模型或依赖真实 GPU。

## 最小开发与测试入口

| 目的                     | 命令                                |
| ------------------------ | ----------------------------------- |
| 安装 locked dependencies | `mise //machine-learning:install`   |
| pytest + coverage        | `mise //machine-learning:test`      |
| Ruff lint                | `mise //machine-learning:lint`      |
| mypy strict              | `mise //machine-learning:check`     |
| 完整 ML checklist        | `mise //machine-learning:checklist` |

contract、provider、model cache 或 concurrency 变化先运行 focused pytest，再运行完整 checklist。若请求/响应变化，还要运行 Server focused tests。

## 高风险变更

| 变更                  | 额外要求                                                                    |
| --------------------- | --------------------------------------------------------------------------- |
| `/predict` schema     | Server repository/service、job consumer、error mapping、compatibility tests |
| Model cache/TTL       | 并发首载、eviction、memory、failed-load recovery                            |
| Pre/post-processing   | golden/fixture behavior、shape/dtype、backward result semantics             |
| Execution provider    | dependency/image、device selection、fallback、hardware-specific tests       |
| Model source/revision | cache migration、offline startup、download integrity                        |
| Multiple ML URLs      | health selection、retry duplication、cold-start behavior                    |
| Remote deployment     | trusted network、media privacy、timeout/resource limits                     |

## 安全与部署约束

Remote Machine Learning 没有内置 authentication，并接收图片 preview 或其他媒体输入。它必须位于可信网络，不应直接暴露到公共 Internet。

部署时还要考虑：

- model cache persistence；
- CPU/GPU image variant；
- memory 与 concurrency；
- Server 到 ML 的 network latency/timeout；
- health check 与 rolling restart；
- media data 的 network boundary。

公开说明见 [Remote Machine Learning](../../docs/docs/guides/remote-machine-learning.md)。

## 源码导航

| 主题                    | 路径                                                                                                                     |
| ----------------------- | ------------------------------------------------------------------------------------------------------------------------ |
| FastAPI app/endpoints   | [`machine-learning/immich_ml/main.py`](../../machine-learning/immich_ml/main.py)                                         |
| Config                  | [`machine-learning/immich_ml/config.py`](../../machine-learning/immich_ml/config.py)                                     |
| Request/response schema | [`machine-learning/immich_ml/schemas.py`](../../machine-learning/immich_ml/schemas.py)                                   |
| Model base/cache        | [`machine-learning/immich_ml/models/`](../../machine-learning/immich_ml/models/)                                         |
| ONNX sessions           | [`machine-learning/immich_ml/sessions/ort.py`](../../machine-learning/immich_ml/sessions/ort.py)                         |
| Tests                   | [`machine-learning/test_main.py`](../../machine-learning/test_main.py)                                                   |
| Tasks                   | [`machine-learning/mise.toml`](../../machine-learning/mise.toml)                                                         |
| Dependencies            | [`machine-learning/pyproject.toml`](../../machine-learning/pyproject.toml)                                               |
| Server client           | [`server/src/repositories/machine-learning.repository.ts`](../../server/src/repositories/machine-learning.repository.ts) |
