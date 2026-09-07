import 'package:flutter/foundation.dart';
import 'package:immich_mobile/widgets/map/map_launch_uri.dart';

enum MapBackend { mapLibre, amap }

class MapBackendConfig {
  static const environment = MapBackendConfig(
    requestedBackend: String.fromEnvironment('IMMICH_MAP_BACKEND', defaultValue: 'amap'),
    amapWebKey: String.fromEnvironment('IMMICH_AMAP_WEB_KEY'),
  );

  final String requestedBackend;
  final String amapWebKey;

  const MapBackendConfig({required this.requestedBackend, required this.amapWebKey});

  MapBackend resolve({required TargetPlatform platform, bool isWeb = false}) {
    if (isWeb) {
      return MapBackend.mapLibre;
    }

    final requested = requestedBackend.trim().toLowerCase();
    final hasAmapKey = amapWebKey.trim().isNotEmpty;
    final isMobile = platform == TargetPlatform.android || platform == TargetPlatform.iOS;
    if (isMobile && hasAmapKey && requested != 'maplibre') {
      return MapBackend.amap;
    }

    return MapBackend.mapLibre;
  }
}

abstract interface class MapThumbnailController {
  Future<void> moveTo(double latitude, double longitude);
}

typedef MapThumbnailControllerCallback = void Function(MapThumbnailController controller);

Uri buildAmapStaticMapUri({
  required String key,
  required double latitude,
  required double longitude,
  required double zoom,
  required double width,
  required double height,
  required bool showMarker,
}) {
  final converted = wgs84ToGcj02(latitude, longitude);
  final params = <String, String>{
    'key': key.trim(),
    'location': '${converted.longitude},${converted.latitude}',
    'zoom': '${zoom.round().clamp(1, 17)}',
    'size': '${width.round().clamp(32, 1024)}*${height.round().clamp(32, 1024)}',
    'scale': '2',
  };
  if (showMarker) {
    params['markers'] = 'mid,0xE53935,A:${converted.longitude},${converted.latitude}';
  }

  return Uri.https('restapi.amap.com', '/v3/staticmap', params);
}
