import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'local_album.model.freezed.dart';

enum BackupSelection {
  // Retained for compatibility with existing local databases after automatic backup removal.
  // selected -> none -> excluded
  // Do not change the order of these values
  selected,
  none,
  excluded,
}

@freezed
abstract class LocalAlbum with _$LocalAlbum {
  const factory LocalAlbum({
    required String id,
    required String name,
    required DateTime updatedAt,
    @Default(0) int assetCount,
    @Default(BackupSelection.none) BackupSelection backupSelection,
    @Default(false) bool isIosSharedAlbum,
    String? linkedRemoteAlbumId,
  }) = _LocalAlbum;
}
