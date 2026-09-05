enum PlaceLevel { country, state, city, district }

class PlacePath {
  final String? country;
  final String? state;
  final String? city;
  final String? district;

  const PlacePath({this.country, this.state, this.city, this.district});

  PlaceLevel? get nextLevel {
    if (country == null) {
      return PlaceLevel.country;
    }
    if (state == null) {
      return PlaceLevel.state;
    }
    if (city == null) {
      return PlaceLevel.city;
    }
    if (district == null) {
      return PlaceLevel.district;
    }
    return null;
  }

  String get label => district ?? city ?? state ?? country ?? '';

  String get breadcrumb => [country, state, city, district].whereType<String>().join(' · ');

  PlacePath withValue(PlaceLevel level, String value) => switch (level) {
    PlaceLevel.country => PlacePath(country: value),
    PlaceLevel.state => PlacePath(country: country, state: value),
    PlaceLevel.city => PlacePath(country: country, state: state, city: value),
    PlaceLevel.district => PlacePath(country: country, state: state, city: city, district: value),
  };

  @override
  bool operator ==(Object other) =>
      other is PlacePath &&
      country == other.country &&
      state == other.state &&
      city == other.city &&
      district == other.district;

  @override
  int get hashCode => Object.hash(country, state, city, district);
}

class PlaceNode {
  final String name;
  final PlacePath path;
  final String coverAssetId;
  final int assetCount;
  final bool hasChildren;

  const PlaceNode({
    required this.name,
    required this.path,
    required this.coverAssetId,
    required this.assetCount,
    required this.hasChildren,
  });
}
