import 'package:collection/collection.dart';

enum GroupAssetsBy { day, month, auto, none }

enum HeaderType { none, month, day, monthAndDay }

enum SortAssetsBy { taken, uploaded }

class Bucket {
  final int assetCount;

  const Bucket({required this.assetCount});

  @override
  bool operator ==(covariant Bucket other) {
    return assetCount == other.assetCount;
  }

  @override
  int get hashCode => assetCount.hashCode;
}

class TimeBucket extends Bucket {
  final DateTime date;
  final List<String> cities;

  const TimeBucket({required this.date, required super.assetCount, this.cities = const []});

  @override
  bool operator ==(covariant TimeBucket other) {
    return super == other && date == other.date && const ListEquality<String>().equals(cities, other.cities);
  }

  @override
  int get hashCode => super.hashCode ^ date.hashCode ^ Object.hashAll(cities);
}
