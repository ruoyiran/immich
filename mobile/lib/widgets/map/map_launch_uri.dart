import 'dart:math' show cos, pi, sin, sqrt;

enum MapLaunchPlatform { android, ios, other }

class MapLaunchUriSet {
  final Uri? amapUri;
  final Uri fallbackUri;

  const MapLaunchUriSet({required this.amapUri, required this.fallbackUri});
}

MapLaunchUriSet buildMapLaunchUris({
  required double latitude,
  required double longitude,
  required int zoom,
  required MapLaunchPlatform platform,
  String? label,
}) {
  final name = (label?.trim().isNotEmpty ?? false) ? label!.trim() : 'Location';
  final amapCoordinate = wgs84ToGcj02(latitude, longitude);

  return switch (platform) {
    MapLaunchPlatform.android => MapLaunchUriSet(
      amapUri: Uri(
        scheme: 'androidamap',
        host: 'viewMap',
        queryParameters: {
          'sourceApplication': 'Immich',
          'poiname': name,
          'lat': amapCoordinate.latitude.toString(),
          'lon': amapCoordinate.longitude.toString(),
          'dev': '0',
        },
      ),
      fallbackUri: Uri(scheme: 'geo', host: '0,0', queryParameters: {'z': '$zoom', 'q': '$latitude,$longitude($name)'}),
    ),
    MapLaunchPlatform.ios => MapLaunchUriSet(
      amapUri: null,
      fallbackUri: Uri.https('maps.apple.com', '/', {'ll': '$latitude,$longitude', 'q': name, 'z': '$zoom'}),
    ),
    MapLaunchPlatform.other => MapLaunchUriSet(
      amapUri: null,
      fallbackUri: buildOpenStreetMapUri(latitude: latitude, longitude: longitude, zoom: zoom),
    ),
  };
}

Uri buildOpenStreetMapUri({required double latitude, required double longitude, required int zoom}) {
  return Uri(
    scheme: 'https',
    host: 'openstreetmap.org',
    queryParameters: {'mlat': '$latitude', 'mlon': '$longitude'},
    fragment: 'map=$zoom/$latitude/$longitude',
  );
}

({double latitude, double longitude}) wgs84ToGcj02(double latitude, double longitude) {
  if (_isOutsideChina(latitude, longitude)) {
    return (latitude: latitude, longitude: longitude);
  }

  var deltaLatitude = _transformLatitude(longitude - 105.0, latitude - 35.0);
  var deltaLongitude = _transformLongitude(longitude - 105.0, latitude - 35.0);
  final radLatitude = latitude / 180.0 * pi;
  var magic = sin(radLatitude);
  magic = 1 - _eccentricity * magic * magic;
  final sqrtMagic = sqrt(magic);
  deltaLatitude = (deltaLatitude * 180.0) / ((_earthRadius * (1 - _eccentricity)) / (magic * sqrtMagic) * pi);
  deltaLongitude = (deltaLongitude * 180.0) / (_earthRadius / sqrtMagic * cos(radLatitude) * pi);
  return (latitude: latitude + deltaLatitude, longitude: longitude + deltaLongitude);
}

const _earthRadius = 6378245.0;
const _eccentricity = 0.00669342162296594323;

bool _isOutsideChina(double latitude, double longitude) {
  return longitude < 72.004 || longitude > 137.8347 || latitude < 0.8293 || latitude > 55.8271;
}

double _transformLatitude(double x, double y) {
  var result = -100.0 + 2.0 * x + 3.0 * y + 0.2 * y * y + 0.1 * x * y + 0.2 * sqrt(x.abs());
  result += (20.0 * sin(6.0 * x * pi) + 20.0 * sin(2.0 * x * pi)) * 2.0 / 3.0;
  result += (20.0 * sin(y * pi) + 40.0 * sin(y / 3.0 * pi)) * 2.0 / 3.0;
  result += (160.0 * sin(y / 12.0 * pi) + 320 * sin(y * pi / 30.0)) * 2.0 / 3.0;
  return result;
}

double _transformLongitude(double x, double y) {
  var result = 300.0 + x + 2.0 * y + 0.1 * x * x + 0.1 * x * y + 0.1 * sqrt(x.abs());
  result += (20.0 * sin(6.0 * x * pi) + 20.0 * sin(2.0 * x * pi)) * 2.0 / 3.0;
  result += (20.0 * sin(x * pi) + 40.0 * sin(x / 3.0 * pi)) * 2.0 / 3.0;
  result += (150.0 * sin(x / 12.0 * pi) + 300.0 * sin(x / 30.0 * pi)) * 2.0 / 3.0;
  return result;
}
