# Mobile 首次安装缩略图与双平台一致性设计

## 目标

1. 用可重复测量定位并优化首次安装后时间线首屏缩略图加载。
2. 将 Android/iOS 功能一致性要求写入 `mobile/AGENTS.md`。
3. 全量审计 `mobile/**` 中的 Android/iOS 行为差异并形成可追踪矩阵。
4. 分别在 Android 与 iOS 模拟器完成自动化及真实栈验收。
5. 全部验证通过后提交、合并到 `main`，并安全清理工作分支和 worktree。

## 当前基线

- 当前 `main` 工作区干净。
- 代码已经具备远端缩略图并发限制、可见请求优先、失败重试、取消、按显示尺寸解码和本地时间线排序索引；本次先验证这些机制对首次安装场景的实际效果，不重复实现同类机制。
- `mobile/AGENTS.md` 当前只对 Pigeon 变更提出双端同步要求，没有覆盖用户行为、错误、缓存、权限、生命周期和测试的一致性要求。
- 现有 `real_stack_auth_test.dart` 包含 78 个真实栈用例，并支持通过 `IMMICH_E2E_CASE_ID` 和 `IMMICH_E2E_CASE_SUFFIX` 分平台运行。
- iOS 的 `PhotoManagement iPhone 16 Pro` 模拟器已启动；Android 存在 `ImmichTask9_API36` AVD，但当前未启动。
- `.worktrees/thumbnail-cross-platform` 干净，其分支已经合入 `main`，可在实施前快进到最新 `main` 后复用，并在最终合并后清理。

## 范围

### 本轮必须完成

- 首次安装缩略图链路的基线、根因、实现、回归测试和双端实机化模拟器验证。
- Android/iOS 平台一致性规范。
- 全量平台差异审计矩阵。
- 修复所有与缩略图链路有关的差异，以及审计发现的 P0/P1 差异。
- 将其余合理特例或较低优先级问题记录为明确结论，不静默忽略。

### 不默认扩展

- 不修改同级 `../photo-classifier`，除非证据确认瓶颈或一致性缺陷属于服务端；发生这种情况时先报告跨仓库影响。
- 不变更 OpenAPI contract，除非服务端变更不可避免。
- 不创建上游 PR；只按用户要求进行本地提交和合并。
- 不操作实体 iPhone 的应用数据。清除数据仅限可丢弃的模拟器/模拟设备。

## 设计原则

### 端到端测量优先

将首次安装链路分为四段分别计时：

1. 登录完成到远端 sync 建连、首字节和首批事件落库。
2. Drift bucket 查询和首批 asset 查询。
3. 时间线首屏布局和可见 Tile 创建。
4. 缩略图排队、网络读取、原生解码和 Flutter 首帧显示。

Android/iOS 使用相同服务器数据、相同图库规模和相同首屏操作。每个平台至少运行三次冷启动，记录中位数、最慢值、并发峰值、排队峰值、取消数、重试数和重复请求数。

### 共享调度优先

首选在共享 Dart 层解决请求优先级、取消、去重和 Widget 重建问题。只有 trace 证明瓶颈位于原生网络或解码层时，才分别调整 Kotlin/Swift 实现。不得通过无界并发、无界预取或扩大内存缓存掩盖问题。

### 行为一致而非实现一致

Android 与 iOS 可以使用不同系统 API，但以下外部语义必须一致：

- 同一输入产生等价的成功、失败和降级结果。
- HTTP 状态、超时、取消和重试分类一致。
- 缓存命中、缓存失效、编辑版本和 decode size 语义一致。
- 前后台切换、FlutterEngine/isolate 重建后没有泄漏或永久挂起。
- 平台能力不对等时必须有显式说明、稳定降级和对应测试。

## 首次安装优化方案

### 可重复场景

- 在真实测试服务中准备固定的远端图片、视频和已完成/延迟生成缩略图。
- 每轮删除模拟器中的应用数据和图片缓存，保留服务器 fixture，并从真实登录流程开始。
- 打开主时间线，等待首屏可见 Tile，随后快速下滑和回滚，覆盖排队、取消、缓存和重试。
- 使用唯一 case suffix 隔离 Android/iOS 数据，测试结束只删除本轮创建的服务器资产。

### 优化决策顺序

1. 验证 schema 34 的本地时间线查询是否命中 `local_date_time` 索引，并确认同步写入字段完整。
2. 检查初次 sync 的批量写入是否导致 bucket stream 高频发射、TimelineService 重建或相同首屏请求重复创建。
3. 检查 `Thumbnail`、ImageProvider key 和 Flutter ImageCache 是否在 rebuild 后保持复用。
4. 验证现有请求调度器的 8 个 active、64 个 pending 上限，以及可见请求、重试请求和饥饿提升策略。
5. 验证 Android Cronet/OkHttp 和 iOS URLSession 对缓存、非 2xx、取消、重定向和连接切换的行为。
6. 验证 Android ImageDecoder 与 iOS ImageIO/vImage 的目标尺寸、方向、色彩和内存峰值。
7. 只修改确认的瓶颈点，并为每项修复先增加失败测试。

### 性能验收

- 两个平台连续三次冷启动均能完成首次同步并显示首屏所有服务器已就绪的可见缩略图。
- 不出现永久空白 Tile、无限重试、请求饥饿、滚动回退后不再加载或取消后泄漏。
- 远端缩略图 active 请求不超过 8，pending 请求不超过 64；离屏 pending 请求不会进入原生网络层。
- 针对确认的主瓶颈，修复后的中位耗时至少改善 20%，且其他阶段中位耗时不得回退超过 10%。如果基线已低于测量噪声，则以移除重复工作并保持三次运行无回退作为验收依据。
- 内存峰值不因优化引入持续增长，时间线快速滚动后能够回落。

## 平台差异审计

审计结果写入 `engineering/mobile-platform-parity-audit.md`，每项包含：功能、共享 Dart 入口、Android 实现、iOS 实现、预期语义、实际差异、证据、严重级别、测试覆盖和处理结论。

覆盖范围：

1. Pigeon contract、生成代码、插件注册和方法实现。
2. 本地及远端图片、视频缩略图、方向、HDR/RAW、色彩和缓存。
3. 全量/增量同步、checkpoint、云端 ID、回收站和相册枚举。
4. 前后台任务、生命周期、取消和多 FlutterEngine/isolate。
5. 上传、断点续传、下载、Live Photo/Motion Photo 和文件命名。
6. 相册、通知、电池优化、媒体位置、有限图库等权限。
7. Cookie、鉴权、mTLS、网络能力和网络切换。
8. 分享、View Intent、深链和外部应用打开。
9. 本地存储、临时文件、升级、数据库迁移和恢复。
10. 平台条件 UI、系统栏、旋转、地图和辅助功能。
11. Manifest、Info.plist、entitlements、Gradle、Xcode/SPM/CocoaPods 配置。
12. Dart、Kotlin、Swift 和双端真实栈测试覆盖。

差异分级：

- P0：数据损坏、安全问题、应用无法启动或核心流程不可用；必须立即修复并阻断合并。
- P1：主要用户流程在单个平台缺失、错误或明显不一致；本轮修复并阻断合并。
- P2：有可靠降级但体验或边缘行为不同；记录证据和后续动作，不阻断当前缩略图交付。
- P3：纯实现差异或平台天然能力差异；记录理由和现有测试。

## AGENTS.md 规则

在 `mobile/AGENTS.md` 增加“Android/iOS 功能一致性”章节：

- Mobile 功能和修复默认同时适用于 Android 与 iOS。
- 修改前检查共享 Dart、Pigeon contract、双端实现、权限、生命周期和构建配置。
- 有意差异必须记录原因、用户可见行为、降级方式和测试。
- 平台敏感变更必须分别在 Android/iOS 模拟器验证。
- 单个平台通过不能代表完成；未测试的平台必须明确标记为未验证。
- 不允许通过静默 no-op 伪装功能一致性。

该规范只在 Mobile scoped instructions 中维护，根 `AGENTS.md` 不重复相同细节。

## 测试设计

### 自动化测试

- 远端请求调度：并发上限、队列上限、LIFO 可见优先、FIFO 重试、饥饿提升和取消。
- RemoteImageProvider：404/408/429/500-504、网络异常、取消和 cache key。
- Thumbnail：thumbhash 占位、成功替换、失败恢复、rebuild 不重复请求。
- Timeline：首批加载、分页、bucket 高频更新时的服务稳定性及查询计划。
- Android/iOS 原生图片路径：非 2xx、目标尺寸、取消、缓存清除、方向和内存所有权。
- Drift schema 变化时执行旧 schema 到新 schema 的 migration 测试。

### 真实栈用例

新增首次安装缩略图用例，覆盖：

- 全新安装登录和首次远端同步。
- 首屏可见缩略图全部渲染。
- 快速滚动时新可见请求优先且旧 pending 请求取消。
- 延迟生成缩略图最终通过重试显示。
- 重启后缓存和本地时间线均可使用。

目标用例通过后，在 Android 与 iOS 上执行与时间线、缩略图、同步、冷启动和平台生命周期直接相关的 real-stack 回归矩阵。完整业务队列包含额外协作者账号、媒体 fixture 和外部服务，仅在对应环境完整可用时运行；不得把未运行项描述为已验证。

### 最终门禁

依次执行存在于仓库 task 列表中的：

```bash
mise //mobile:format
mise //mobile:analyze
mise //mobile:test
mise //mobile:checklist
git diff --check
```

iOS 原生 Swift package 测试另外执行 `swift test`。模拟器测试使用仓库现有 Flutter integration test 入口和真实服务配置，凭据不写入日志、文档或提交。

## Git 与 worktree 流程

1. 复用 `.worktrees/thumbnail-cross-platform` 前确认其仍干净，并将 `codex/thumbnail-cross-platform` fast-forward 到最新 `main`。
2. 所有实现和测试均在该 worktree 完成，主工作区保持干净。
3. 按用户要求，在完整验证通过前不创建 commit。
4. 绿灯后提交聚焦变更；提交前再次检查 diff、生成物和 secrets。
5. 确认 `main` 没有新的冲突变更；如已前进，先同步并重新运行相关门禁。
6. 将工作分支 fast-forward 合并到 `main`，在合并后的树上重新运行 Mobile checklist 和双端首次安装 smoke test。
7. 只有合并后验证仍为绿色，才从主工作区外执行普通 `git worktree remove`、`git worktree prune` 和 `git branch -d`；不得使用强制删除。

## 进度同步

在当前飞书线程同步以下里程碑：

1. worktree 与基线准备完成；
2. 首次安装性能基线和根因确定；
3. 优化实现及窄测试完成；
4. 平台差异审计完成及 P0/P1 结论；
5. Android 完整验证结果；
6. iOS 完整验证结果；
7. 最终门禁、提交、合并和清理结果。

任何测试阻塞、跨仓库需求、数据库修改或无法解释的平台差异都立即同步，不等待整轮结束。
