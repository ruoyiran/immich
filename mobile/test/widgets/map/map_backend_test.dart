import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:immich_mobile/widgets/map/map_backend.dart';

void main() {
  test('uses AMap on mobile when the web key is configured', () {
    const config = MapBackendConfig(requestedBackend: 'amap', amapWebKey: 'web-key');

    expect(config.resolve(platform: TargetPlatform.android), MapBackend.amap);
    expect(config.resolve(platform: TargetPlatform.iOS), MapBackend.amap);
  });

  test('falls back to MapLibre when AMap configuration is incomplete', () {
    const missingKey = MapBackendConfig(requestedBackend: 'amap', amapWebKey: ' ');
    const mapLibre = MapBackendConfig(requestedBackend: 'maplibre', amapWebKey: 'web-key');

    expect(missingKey.resolve(platform: TargetPlatform.android), MapBackend.mapLibre);
    expect(mapLibre.resolve(platform: TargetPlatform.iOS), MapBackend.mapLibre);
    expect(configuredForWeb.resolve(platform: TargetPlatform.android, isWeb: true), MapBackend.mapLibre);
  });

  test('builds an AMap static map URL with converted coordinates', () {
    final uri = buildAmapStaticMapUri(
      key: ' web-key ',
      latitude: 31.2304,
      longitude: 121.4737,
      zoom: 12,
      width: 320,
      height: 180,
      showMarker: true,
    );

    expect(uri.host, 'restapi.amap.com');
    expect(uri.path, '/v3/staticmap');
    expect(uri.queryParameters['key'], 'web-key');
    expect(uri.queryParameters['location'], startsWith('121.478'));
    expect(uri.queryParameters['size'], '320*180');
    expect(uri.queryParameters['markers'], isNotEmpty);
  });
}

const configuredForWeb = MapBackendConfig(requestedBackend: 'amap', amapWebKey: 'web-key');
