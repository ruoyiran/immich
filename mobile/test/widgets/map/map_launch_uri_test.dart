import 'package:flutter_test/flutter_test.dart';
import 'package:immich_mobile/widgets/map/map_launch_uri.dart';

void main() {
  test('builds Android AMap URI with GCJ-02 coordinates', () {
    final uris = buildMapLaunchUris(
      latitude: 31.2304,
      longitude: 121.4737,
      zoom: 16,
      platform: MapLaunchPlatform.android,
      label: '上海市浦东新区',
    );

    expect(uris.amapUri, isNotNull);
    expect(uris.amapUri!.scheme, 'androidamap');
    expect(uris.amapUri!.host, 'viewmap');
    expect(uris.amapUri!.queryParameters['poiname'], '上海市浦东新区');
    expect(uris.amapUri!.queryParameters['dev'], '0');
    expect(double.parse(uris.amapUri!.queryParameters['lat']!), closeTo(31.22845, 0.0001));
    expect(double.parse(uris.amapUri!.queryParameters['lon']!), closeTo(121.4782, 0.0001));
  });

  test('uses Apple Maps for iOS', () {
    final uris = buildMapLaunchUris(latitude: 31.2304, longitude: 121.4737, zoom: 16, platform: MapLaunchPlatform.ios);

    expect(uris.amapUri, isNull);
    expect(uris.fallbackUri.host, 'maps.apple.com');
  });

  test('keeps non-China coordinates unchanged for AMap URI', () {
    final uris = buildMapLaunchUris(
      latitude: 37.7749,
      longitude: -122.4194,
      zoom: 16,
      platform: MapLaunchPlatform.android,
    );

    expect(uris.amapUri, isNotNull);
    expect(double.parse(uris.amapUri!.queryParameters['lat']!), 37.7749);
    expect(double.parse(uris.amapUri!.queryParameters['lon']!), -122.4194);
  });
}
