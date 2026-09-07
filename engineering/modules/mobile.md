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

## 地图后端

照片详情中的地图缩略图在移动端可使用高德静态地图 Web API，避免中国区 MapLibre 瓦片不可达时出现黑色背景。构建时将部署环境中 `PC_AMAP_KEY` 的值注入为客户端 Dart define：

```bash
--dart-define=IMMICH_AMAP_WEB_KEY="$PC_AMAP_KEY"
```

客户端代码不直接读取部署侧变量。没有配置 `IMMICH_AMAP_WEB_KEY` 时，照片详情地图缩略图回退到 MapLibre。照片 EXIF 的 WGS84 坐标在传给高德静态图和高德 App 前会转换为 GCJ-02。

Android 真机 release 只构建 `arm64-v8a` APK：

```bash
cd mobile
PC_AMAP_KEY=<same-value-as-deployment> scripts/build_android_release_apk.sh
adb install --user 0 -r build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```
