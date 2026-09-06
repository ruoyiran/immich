# 按拍摄日处理的相似照片清理设计

> 状态：方案已确认，尚未实施  
> 日期：2026-09-06  
> 涉及仓库：`immich`、同级 `../photo-classifier`

## 1. 背景

用户需要服务端识别高度相似的照片，并在 Mobile 提供“相似照片清理”入口。识别范围按照片拍摄地的自然日划分；用户确认保留项后，其余照片进入回收站，不允许后台自动删除或直接永久删除。

当前代码已经具备部分基础：

- `../photo-classifier/pipeline-rs/src/stages/duplicates.rs` 实现 v3 相似度扫描，使用 `0.85 × CLIP + 0.15 × pHash`，综合分严格大于 `0.90` 时保留候选。
- v3 只在相同主分类中进行全库 pair 比较，没有按拍摄日分桶，也不生成当前可消费的保守分组。
- `../photo-classifier/server/internal/store/similarity.go` 和数据库中保留 pair、group、fingerprint、ignore 等基础结构。
- 当前 Immich compatibility router 未注册 `/api/duplicates`，但 `/api/server/features` 已声明 `duplicateDetection=true`，能力声明与实际路由不一致。
- 本仓库 OpenAPI、TypeScript SDK 和 Dart SDK 已包含官方 `/duplicates`、`/duplicates/resolve`、`/duplicates/{id}` 契约，因此不需要新增客户端协议或手改生成代码。
- Mobile 当前只有单张资产的“查看相似照片”智能搜索动作，没有重复照片审阅页面。

## 2. 已确认的产品决策

1. “一天”定义为照片拍摄地的自然日，使用数据库 `taken_at` 所表达的拍摄地 wall-clock 日期进行分桶。
2. 不做滚动 24 小时窗口；跨午夜照片属于不同日期，不互相比较。
3. 服务端只给出建议，不自动回收媒体。
4. Mobile 默认选中服务端建议删除项，用户确认后才将其移动到回收站。
5. 相似照片页面不提供直接永久删除；永久删除仍由现有回收站流程处理。
6. 分组采用保守策略，不能因为 A≈B、B≈C 就自动认定 A≈C。

## 3. 目标

- 将相似照片扫描升级为按拍摄日独立处理的 v4 算法。
- 新增和变更照片只重算受影响的自然日，不重新扫描整库。
- 对相似 pair 生成不重叠、可安全审阅的保守分组。
- 实现 Immich 官方 duplicate API，使现有 SDK 和 Web/Mobile 数据模型可直接消费。
- 在 Mobile 图库页提供受能力开关控制的相似照片清理入口。
- 保持逻辑回收、同步、实时通知和永久删除安全边界不变。

## 4. 非目标

- 不在客户端计算 embedding 或图片相似度。
- 不修改当前 CLIP 模型、向量格式或远端模型服务契约。
- 不识别跨自然日的连续拍摄或滚动 24 小时重复项。
- 不自动合并人物、人脸或所有 EXIF 字段。
- 不在本次实现中加入视频相似清理。
- 不新增自定义 OpenAPI endpoint；优先实现已有官方 `/duplicates` 契约。

## 5. 总体架构

```mermaid
flowchart LR
  Import[上传或扫描入库]
  Derived[缩略图与 CLIP embedding]
  Scan[v4 按 capture_day 增量扫描]
  Groups[active duplicate groups]
  API[/api/duplicates]
  Mobile[Mobile 相似照片清理]
  Trash[现有逻辑回收]

  Import --> Derived --> Scan --> Groups --> API --> Mobile --> Trash
```

运行边界保持不变：Rust pipeline 是相似度派生数据的唯一写者；Go server 提供读取、忽略、resolve 和逻辑回收 API；Mobile 只消费服务端结果。

## 6. 日期语义

`capture_day` 使用 `DATE(taken_at)` 的 wall-clock 日期。现有入库链已经按 EXIF、文件名、客户端创建时间、客户端修改时间、mtime 和上传完成时间填充 `taken_at`，因此扫描不再自行推导时区。

关键规则：

- 同一 `capture_day` 的活动静态照片可以参与比较。
- 跨日期照片即使内容完全相同也不进入同一组。
- `taken_at` 修改时，旧日期和新日期都必须失效并重算。
- 回收、恢复、文件内容变化、缩略图变化、embedding 变化都会使所属日期失效。
- Live Photo 以 still 照片的 `taken_at` 参与照片相似度扫描，motion 文件不单独参与。

## 7. v4 相似度算法

### 7.1 候选范围

- 只选择 `missing=0`、未回收、未永久删除、缩略图和 embedding 完整的照片。
- 以 `capture_day` 分桶，不再要求主分类相同。按日限制已经降低计算量，取消分类限制可避免裁剪、曝光变化或分类波动造成漏检。
- 每个日期内部按 photo ID 稳定排序，结果必须与线程调度和数据库返回顺序无关。

### 7.2 pair 评分

保留 v3 已验证的确定性评分：

```text
combined_similarity = 0.85 × clip_cosine + 0.15 × (1 - phash_distance / 64)
```

- CLIP 候选召回阈值继续由最终阈值反推。
- 综合分必须严格大于 `0.90`。
- embedding 字节完全一致时仍显式按 CLIP `1.0` 处理。
- 阈值和权重与 `algorithm_version=4` 一起持久化；首版不提供用户可调阈值，避免同一版本产生不一致语义。

### 7.3 保守分组

pair 先按综合分降序、photo ID 升序排序。分组采用确定性的 complete-link 贪心策略：

1. 取尚未分组的最高质量照片作为 seed。
2. 候选按与 seed 的相似度降序排列。
3. 只有候选与当前组内每个成员都存在大于阈值的 pair 时才加入。
4. 每张照片最多属于一个 active group。
5. 少于两张照片的结果不持久化。

这种策略牺牲部分召回率，换取清理页面上每个组内部任意两张都高度相似，避免传递相似造成误删。

### 7.4 keeper 建议

复用现有确定性质量排序，并明确顺序：

1. 非明显模糊；
2. 像素数更大；
3. 文件更大；
4. sharpness 更高；
5. Live Photo 优先；
6. photo ID 更小作为最终稳定 tie-breaker。

服务端为每组返回一个 `suggestedKeepAssetIds`。用户可以在 Mobile 修改选择。

## 8. 增量扫描与发布

`photo_similarity_fingerprints` 增加 `capture_day`。增量扫描比较当前照片状态和上一轮 fingerprint：

- 新照片：当前日期为 dirty。
- 删除、缺失或回收照片：旧 fingerprint 日期为 dirty。
- 日期变化：旧、新日期均为 dirty。
- embedding、缩略图、文件身份或算法版本变化：当前日期为 dirty。

生成新 scan 时：

1. 从旧 active scan 复制所有非 dirty 日期的 pair、group 和 member。
2. 按日期重新计算 dirty 日期。
3. 写入新的 inactive scan。
4. 所有日期成功后，在单个事务内切换 active scan 并删除旧 scan。

旧 active scan 在构建期间继续提供读取，Mobile 不会看到部分结果。进程崩溃后可丢弃未发布 scan，再次运行增量扫描即可恢复。

上传后的 `process-new` 在人物处理完成后增加相似度增量阶段；完整 `run-all` 也在照片阶段末尾运行相同扫描。现有手动 `duplicates --incremental` 保留，并新增精确日期诊断参数 `--date YYYY-MM-DD`。

## 9. 数据模型

复用现有表并升级语义：

- `photo_similarity_fingerprints`：增加 `capture_day DATE NOT NULL`。
- `similarity_pairs`：增加 `capture_day DATE NOT NULL`，便于复制和删除指定日期结果。
- `similarity_groups`：增加 `public_id CHAR(36) NOT NULL`、`capture_day DATE NOT NULL`，并以 `(scan_id, public_id)` 唯一；这样新 scan 构建期间可安全复用旧 active scan 的组 UUID。
- `similarity_group_members`：继续保存成员、到 keeper 的分数、质量顺序和推荐保留标记。
- `similarity_scans`：写入 `algorithm_version=4` 和真实 `group_count`。
- `similarity_ignores`：继续使用 pair + 双方缩略图 SHA；忽略整组时写入组内全部 pair。

DDL 的唯一 owner 仍是 Rust `init-db`；Go test schema 必须同步。

## 10. Immich compatibility API

实现现有 OpenAPI 契约：

### `GET /api/duplicates`

- 要求有效 session。
- 只读取 active v4 scan。
- 返回不重叠的 active groups，按 `capture_day DESC`、组内最高相似度 DESC、`public_id` ASC 排序。
- 通过 `immich_public_ids` 批量转换内部 photo ID，并复用现有 `AssetResponseDto` 映射。
- `duplicateId` 使用持久化 UUID；`suggestedKeepAssetIds` 使用 keeper 的公开 UUID。

### `DELETE /api/duplicates/{id}` 与 `DELETE /api/duplicates`

- 表示“全部保留并忽略”，不回收照片。
- 在事务中验证 active group，将组内 pair 写入 ignore，再从当前 active scan 删除 group/pair 并更新计数。
- 重复请求保持幂等；不存在或已过期 ID 按官方接口语义返回 not found 或对应 bulk failure。

### `POST /api/duplicates/resolve`

- 每个请求项必须引用当前 active group。
- `keepAssetIds` 与 `trashAssetIds` 必须互斥，合集必须等于当前组成员，且至少保留一张。
- 逻辑回收前复用现有文件身份 snapshot 和统一写租约。
- 将非冲突的用户元数据合并到 keeper：相簿成员关系和手工标签取并集，favorite 使用 OR；description、rating、visibility、位置、时间和人脸不自动覆盖。
- `trashAssetIds` 进入现有逻辑回收站，不直接永久删除。
- 同一事务删除或忽略已处理组，并通过现有 sync/realtime 链发布资产变化。
- 返回逐组 `BulkIdResponseDto`，一组失败不能被伪装为成功。

能力声明只有在 DuplicateStore 和写入依赖均已装配时才返回 `duplicateDetection=true`。

## 11. Mobile 设计

### 11.1 入口

在“图库”页快捷区域加入“相似照片清理”，由 `ServerFeaturesDto.duplicateDetection` 控制显示。Mobile 的 `ServerFeatures` domain model需要映射该字段。

### 11.2 页面

新增 `DriftDuplicatesPage`：

- 加载态、错误态、空状态和重试。
- 按组逐个审阅，组头展示拍摄自然日和当前位置。
- 响应式缩略图网格；每张展示拍摄时间、分辨率、文件大小和 Live Photo 标记。
- 默认选中非 keeper 照片作为待回收项。
- 支持打开现有 Asset Viewer 检查原图。
- 支持“确认清理”“全部保留”“上一组”“下一组”。
- 批量模式只处理用户明确选中的组；不在首版提供后台自动清理。

### 11.3 客户端分层

- `ApiService` 增加生成的 `DuplicatesApi`。
- 新建 `DuplicateRepository`，将 `DuplicateResponseDto` 转成 domain model。
- Riverpod AsyncNotifier 持有组列表、当前索引和每组选择状态。
- 成功 resolve 后乐观移除组，并刷新同步、时间线和回收站相关 provider；失败时恢复原状态并显示可重试错误。
- Android 和 iOS 完全使用共享 Dart 实现，不新增 Pigeon 或平台权限。

现有 i18n 已包含 `duplicates`、`review_duplicates`、`no_duplicates_found`、`keep_this_delete_others` 等文案；新增文案从根 `i18n/` 修改并生成，不手改生成资源。

## 12. 错误处理与并发

- scan 构建失败时保留旧 active scan。
- 单日候选超过安全上限时记录具体日期并使本轮 scan 失败，不发布截断结果。
- resolve 与 scan 切换均受现有写租约保护。
- Mobile 使用过期 group ID 时显示“结果已更新，请刷新”，不根据客户端旧列表执行删除。
- 网络重试不得重复回收照片；服务端按当前 group 和资产回收状态实现幂等。
- 不完整 embedding 的照片暂不参与该日期扫描，但必须记录 skipped 数量；不得因为单张失败阻止其他日期生成结果。

## 13. 测试策略

### Rust

- 自然日分桶、跨日排除、跨分类召回。
- 阈值边界、精确向量、pHash、keeper 排序。
- complete-link 非传递分组和确定性。
- dirty 日期计算、旧/新日期失效、非 dirty 日期复制。
- scan 事务发布和失败回滚。

### Go

- DDL/迁移与 MySQL contract。
- active v4 group 查询、UUID 映射、批量 hydrate、排序。
- API 鉴权、DTO 形状、resolve 校验、dismiss、幂等和过期 group。
- 写租约冲突、逻辑回收、元数据合并、sync/realtime。

### Mobile

- capability 映射和入口显示/隐藏。
- repository DTO 转换。
- provider 加载、选择、resolve、dismiss、失败回滚。
- 页面 loading/error/empty/data 状态和确认对话框。
- Android/iOS 模拟器执行同一验收流程。

## 14. 发布与回滚

1. 先发布数据库迁移和 v4 pipeline，保留 `duplicateDetection=false`。
2. 完成首轮 v4 scan，并核对抽样准确率、每日照片数量和处理耗时。
3. 发布 API 后开启 capability。
4. 最后发布 Mobile 入口。

回滚时关闭 capability，Mobile 自动隐藏入口；旧 active scan 和照片原数据不受影响。算法结果全部是可重建派生数据，不需要回滚媒体文件。

## 15. 验收标准

- 同一自然日的高度相似照片出现在 Mobile 同一组。
- 跨自然日照片不会被分到同一组。
- 每组内部任意两张都满足固定 v4 阈值。
- 默认建议只保留一张，但用户可修改选择。
- 确认后只进入逻辑回收站，可从现有回收站恢复。
- 上传新照片只重算受影响日期。
- scan 或 API 失败不会产生部分发布、直接删除或错误成功提示。
- Android 与 iOS 用户可见行为一致。
