part of 'base_asset.model.dart';

class LocalAsset extends BaseAsset {
  @override
  final String id;
  final String? remoteAssetId;
  final String? cloudId;
  final int orientation;
  final String? contentMd5;
  final int? contentSize;
  final String? hashAlgorithm;
  final DateTime? hashedModifiedAt;
  @override
  final AssetPlaybackStyle playbackStyle;

  final DateTime? adjustmentTime;
  final double? latitude;
  final double? longitude;

  const LocalAsset({
    required this.id,
    String? remoteId,
    this.cloudId,
    required super.name,
    super.checksum,
    required super.type,
    required super.createdAt,
    required super.updatedAt,
    super.width,
    super.height,
    super.durationMs,
    super.isFavorite = false,
    this.orientation = 0,
    this.contentMd5,
    this.contentSize,
    this.hashAlgorithm,
    this.hashedModifiedAt,
    required this.playbackStyle,
    this.adjustmentTime,
    this.latitude,
    this.longitude,
    required super.isEdited,
  }) : remoteAssetId = remoteId;

  @override
  String? get localId => id;

  @override
  String? get remoteId => remoteAssetId;

  @override
  AssetState get storage => remoteId == null ? AssetState.local : AssetState.merged;

  @override
  String get heroTag => '${id}_${remoteId ?? checksum}';

  bool get hasCoordinates => latitude != null && longitude != null && latitude != 0 && longitude != 0;

  @override
  String toString() {
    return '''LocalAsset {
   id: $id,
   name: $name,
   type: $type,
   createdAt: $createdAt,
   updatedAt: $updatedAt,
   width: ${width ?? "<NA>"},
   height: ${height ?? "<NA>"},
   durationMs: ${durationMs ?? "<NA>"},
   playbackStyle: $playbackStyle,
   remoteId: ${remoteId ?? "<NA>"},
   cloudId: ${cloudId ?? "<NA>"},
   checksum: ${checksum ?? "<NA>"},
   contentMd5: ${contentMd5 ?? "<NA>"},
   contentSize: ${contentSize ?? "<NA>"},
   hashAlgorithm: ${hashAlgorithm ?? "<NA>"},
   hashedModifiedAt: ${hashedModifiedAt ?? "<NA>"},
   isFavorite: $isFavorite,
   orientation: $orientation,
   adjustmentTime: $adjustmentTime,
   latitude: ${latitude ?? "<NA>"},
   longitude: ${longitude ?? "<NA>"},
 }''';
  }

  // Not checking for remoteId here
  @override
  bool operator ==(Object other) {
    if (other is! LocalAsset) {
      return false;
    }
    if (identical(this, other)) {
      return true;
    }
    return super == other &&
        id == other.id &&
        cloudId == other.cloudId &&
        contentMd5 == other.contentMd5 &&
        contentSize == other.contentSize &&
        hashAlgorithm == other.hashAlgorithm &&
        hashedModifiedAt == other.hashedModifiedAt &&
        orientation == other.orientation &&
        playbackStyle == other.playbackStyle &&
        adjustmentTime == other.adjustmentTime &&
        latitude == other.latitude &&
        longitude == other.longitude;
  }

  @override
  int get hashCode =>
      super.hashCode ^
      id.hashCode ^
      remoteId.hashCode ^
      contentMd5.hashCode ^
      contentSize.hashCode ^
      hashAlgorithm.hashCode ^
      hashedModifiedAt.hashCode ^
      orientation.hashCode ^
      playbackStyle.hashCode ^
      adjustmentTime.hashCode ^
      latitude.hashCode ^
      longitude.hashCode;

  LocalAsset copyWith({
    String? id,
    String? remoteId,
    String? cloudId,
    String? name,
    String? checksum,
    AssetType? type,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? width,
    int? height,
    int? durationMs,
    bool? isFavorite,
    int? orientation,
    String? contentMd5,
    int? contentSize,
    String? hashAlgorithm,
    DateTime? hashedModifiedAt,
    AssetPlaybackStyle? playbackStyle,
    DateTime? adjustmentTime,
    double? latitude,
    double? longitude,
    bool? isEdited,
  }) {
    return LocalAsset(
      id: id ?? this.id,
      remoteId: remoteId ?? this.remoteId,
      cloudId: cloudId ?? this.cloudId,
      name: name ?? this.name,
      checksum: checksum ?? this.checksum,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      width: width ?? this.width,
      height: height ?? this.height,
      durationMs: durationMs ?? this.durationMs,
      isFavorite: isFavorite ?? this.isFavorite,
      orientation: orientation ?? this.orientation,
      contentMd5: contentMd5 ?? this.contentMd5,
      contentSize: contentSize ?? this.contentSize,
      hashAlgorithm: hashAlgorithm ?? this.hashAlgorithm,
      hashedModifiedAt: hashedModifiedAt ?? this.hashedModifiedAt,
      playbackStyle: playbackStyle ?? this.playbackStyle,
      adjustmentTime: adjustmentTime ?? this.adjustmentTime,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      isEdited: isEdited ?? this.isEdited,
    );
  }
}
