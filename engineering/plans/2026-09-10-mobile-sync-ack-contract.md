# 同步协议契约：会话 ack 持久化与 syncResetV1 纪律

- 日期：2026-09-10（2026-09-11 更新：服务端修复已落地，见文末）
- 适用仓库：`photo-classifier`（服务端，权威实现方）；本文从 mobile 客户端行为推导契约
- 关联问题：mobile 冷启动后时间线整库清空重填（全量重拉）

## 背景

Mobile 客户端（本仓库 `mobile/`）的远端同步协议是「断点全在服务端、按会话隔离」：

- 客户端**不保存任何本地游标**。每次同步 POST `/sync/stream`（body 只含 `types`，从不设置 `reset` 布尔值）。
- 服务端按 `(sessionId, entityType)` 记录该会话已确认的最新 ack（断点）。客户端每处理完一个同类型批次就 POST `/sync/ack` 推进断点（单次上限 1000 条，且客户端会压缩为每类型一条最新值）。
- 收到 `syncResetV1` 事件时，客户端清空全部远端数据表（约 17 张：remote asset/exif/album、face、person、memory、stack、user 等），随后依赖**同一条流**内的完整 backfill 重新填充，结束后再发起第二次 stream（`mobile/lib/domain/services/sync_stream.service.dart` `sync()` 的 `shouldReset` 路径）。

## 问题

photo-classifier 当前行为：客户端每次冷启动的 `/sync/stream` 都触发 `syncResetV1`（或等效的整库重发）。结果：

1. 客户端时间线清空 → 全量 backfill 重填 → 用户看到「每次打开 app 都在重新全量同步」；
2. websocket 远端变更事件（`on_asset_update` 等 7 类）每次都触发一轮完整 stream 往返，把上述代价成倍放大。

客户端侧已确认**不是**以下原因（均已排查排除）：冷启动重建会话（token 复用、无轮换端点、无 401 静默重登）、同步中断丢断点（完成的子批次即时 ack）、客户端迁移任务反复删 ack（每安装一次）。

## 契约要求

以下 (a)-(g) 是 mobile 客户端（按上游 immich 协议实现）对服务端的期望。**服务端是权威实现方，任何偏离都应在 photo-classifier 修复。**

### (a) ack 持久化

`POST /sync/ack` 必须把 `(sessionId, entityType) → 最新 ack` 持久化到数据库（MySQL），**进程重启、重新部署后不丢**。内存 map 不合格。按 type **upsert**（保留最新一条），不是 append——客户端会重复提交并压缩。

### (b) 增量 vs backfill 的判定

对 `/sync/stream` 请求中的每个 type：

- 该 `(session, type)` 存在最新 ack → 只发送 ack 之后的事件；
- 不存在 ack → 发送该类型的**全量 backfill**，但**绝不因此发送 `syncResetV1`**。

「无 ack」是**正常情况**：首次同步、客户端新请求的 type、或客户端主动 DELETE `/sync/ack`（客户端升级迁移会这么做）。它不表示客户端本地状态失效。

### (c) syncResetV1 纪律

`syncResetV1` 仅用于真正的客户端状态失效场景：

- ack/事件格式不兼容（服务端破坏性变更）；
- 管理员强制全端重同步；
- 服务端数据重建导致增量连续性断裂。

约束：

- 每个 stream 至多一次，且位于 stream 开头；
- 发送后**必须在同一条流内跟上所有请求类型的完整 backfill**；
- 注意客户端限制：reset 后的第二次 stream（客户端自动发起）不携带 reset 处理器，若其中再次出现 `syncResetV1`，客户端只会清库而不会再触发补拉——时间线将停留为空直到下一次手动同步。

### (d) 会话生命周期

会话跨客户端冷启动稳定（当前已满足：客户端复用同一 access token，会话 id 不变）。会话创建或复用**不得**清空或重新键控该会话已存在的 ack。

### (e) `isPendingSyncReset`

仅由管理员操作或检测到的不兼容**显式**设置。不得作为会话创建、服务重启、或读到空 ack 集合的副作用。应是 stream 时求值的持久标志，而非会话创建时烘焙。

### (f) 行为矩阵（建议转为 photo-classifier 集成测试）

| # | 场景 | 期望 |
|---|------|------|
| 1 | 二次冷启动，ack 齐全，无新事件 | 流内只有 `SyncAckV1`/`SyncCompleteV1` 检查点；零数据事件；客户端时间线不清空 |
| 2 | ack 齐全 + 新事件 | 仅按类型发增量 |
| 3 | 某类型 ack 缺失（新类型或客户端迁移删过） | 仅该类型全量 backfill；其余类型增量；**无** `syncResetV1` |
| 4 | 服务端重启 | GET `/sync/ack` 返回与重启前相同的集合 |
| 5 | 管理员强制 reset | stream 开头恰好一次 `syncResetV1` + 同流内所有请求类型的完整 backfill |

### (g) `SyncStreamDto.reset`

这是客户端主动请求 reset 的字段。本客户端从不设置（已验证）。服务端不得要求它、也不得把它的缺席解读为任何语义。

## 客户端侧配套改动（本仓库，2026-09-10）

在等待/验证服务端修复期间，mobile 已加入诊断与缓解（不改变协议语义）：

1. **诊断日志**：`sync()` 在 stream 前调用 GET `/sync/ack` 并输出 `Remote sync session acks: N (types: ...)`；stream 完成日志按事件类型输出计数（`Remote sync completed ... AssetV2=50000 ...`）；`reset()` 日志升级为 info 级（`SyncResetV1 received`）。
2. **websocket 触发的 syncRemote 防抖**（5s interval / 10s maxWait）：事件风暴从 N 次完整 stream 往返收敛为每安静窗口至多 2 次。
3. 修复本地同步 bug：取消的 fullSync 不再推进 MediaStore/PHPersistentChangeToken 检查点。

## 验收方法（服务端修复后）

连续两次冷启动 mobile 客户端，检查日志：

1. 第二次启动 `Remote sync session acks: N` 非空，且与上一次 stream 的终态一致；
2. 无 `SyncResetV1 received`；
3. `Remote sync completed` 的按类型计数为增量规模（非全库 backfill）；
4. 时间线不再清空重填。

## 服务端修复落地记录（2026-09-11）

根因最终定位在 `photo-classifier` 的 `sync_http.go` stream handler：任一请求类型的 checkpoint 游标低于 history floor（`immich_sync_state` singleton 行，由 `RunHistoryRetention` 每 5 分钟按 100k 变更窗口推进）时，下发单个 `SyncResetV1` 并立即返回 → 客户端清空全部远端表 → ack `SyncResetV1` → 服务端删光该会话全部 checkpoint → 全量 backfill。`photos`/`videos` 表的 AFTER UPDATE 触发器（每次行更新写一条 change）使 pipeline 全库任务轻易冲破 100k 窗口，冷启动高频触发。

修复（已实现，`server/internal/immichcompat/`）：

- `sync_http.go`：checkpoint 低于 floor 时**不再下发 `SyncResetV1`**——服务端只删除该会话中过期类型的 checkpoint，`buildStream` 对这些类型改走全量 backfill（客户端时间线保持已填充，upsert 原地收敛）；未过期的类型照常增量。
- 已知取舍（`docs/backlog.md` 已记录）：prune 掉的历史窗口内发生的服务端删除不再以 delete 事件到达该客户端（本地可能残留 ghost 行）。缓解方向：PruneHistory 保留 delete-action 行并补发，或客户端在 syncCompleteV1 后 prune。
- 测试：`sync_http_test.go` 两个场景（stale-only、stale+fresh 混合）；`mysql_sync_store_integration_test.go` 重写 reset 段为断言 backfill 行为。**集成测试需要 `PC_TEST_DATABASE_URL` 指向 MySQL，本地未跑**，需在有 MySQL 的环境执行 `cd server && go test ./internal/immichcompat/ -run TestMySQLSyncStoreLifecycle`。

本仓库（immich mobile）无需再改：协议消费方行为不变，诊断日志（`Remote sync session acks` / `SyncResetV1 received` / 按类型计数）即验收工具。
