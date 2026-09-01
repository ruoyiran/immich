# Mobile 模块

`mobile/` 是 Flutter client，负责 UI、本机媒体、后台上传、Drift local database、sync state 和 Android/iOS integration。Runtime backend 是同级 `photo-classifier`。

## 边界

- Remote API types 来自 `mobile/generated/openapi/`。
- Local state 和 migration 位于 Drift 层，不由服务器 database schema 直接生成。
- Pigeon 定义 Dart 与 native platform 的接口。
- Server endpoint 由用户配置；客户端必须保持 URL、auth、upload 和 sync compatibility。

## 生成代码

不要手改 OpenAPI、Drift、Pigeon、translation、icon 或 splash 生成输出。使用：

```bash
mise //mobile:codegen
mise //mobile:drift:migration
mise //mobile:codegen:pigeon
```

## 验证

```bash
mise //mobile:test
mise //mobile:analyze
mise //mobile:checklist
```

API/sync 变化需要同时验证 full-sync fallback、reset/reconnect、large-library batching、Live Photo upload ordering 和 retry/idempotency。
