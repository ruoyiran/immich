import 'dart:convert';

import 'package:immich_mobile/domain/models/asset/base_asset.model.dart';
import 'package:immich_mobile/extensions/platform_extensions.dart';
import 'package:path/path.dart' as p;

String buildUploadSourceMetadata(BaseAsset asset, {required String originalName, String? deviceId}) {
  final local = asset is LocalAsset ? asset : null;
  final platformAsset = <String, Object?>{'id': asset.localId, if (local?.cloudId != null) 'cloud_id': local!.cloudId};
  return jsonEncode({
    'schema_version': 1,
    'source': 'mobile',
    'platform': CurrentPlatform.isIOS ? 'ios' : 'android',
    if (deviceId != null && deviceId.isNotEmpty) 'device_id': deviceId,
    'original_name': originalName,
    'asset_type': asset.type.name,
    'playback_style': asset.playbackStyle.name,
    'created_at': asset.createdAt.toIso8601String(),
    'modified_at': asset.updatedAt.toIso8601String(),
    'timezone_offset_minutes': asset.createdAt.toLocal().timeZoneOffset.inMinutes,
    'mime_type': _mimeTypeForName(originalName, asset.type),
    if (asset.width != null) 'width': asset.width,
    if (asset.height != null) 'height': asset.height,
    if (asset.durationMs != null) 'duration_ms': asset.durationMs,
    if (local != null) 'orientation': local.orientation,
    if (local?.latitude != null) 'latitude': local!.latitude,
    if (local?.longitude != null) 'longitude': local!.longitude,
    if (CurrentPlatform.isIOS) 'photo_kit': platformAsset,
    if (CurrentPlatform.isAndroid) 'media_store': platformAsset,
  });
}

String _mimeTypeForName(String name, AssetType type) => switch (p.extension(name).toLowerCase()) {
  '.heic' || '.heif' => 'image/heic',
  '.jpg' || '.jpeg' => 'image/jpeg',
  '.png' => 'image/png',
  '.gif' => 'image/gif',
  '.webp' => 'image/webp',
  '.mov' => 'video/quicktime',
  '.mp4' || '.m4v' => 'video/mp4',
  _ => type == AssetType.video ? 'video/*' : 'image/*',
};
