import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/domain/models/asset/base_asset.model.dart';
import 'package:immich_mobile/platform/native_sync_api.g.dart';
import 'package:photo_manager/photo_manager.dart' hide AssetType;

final fileMediaRepositoryProvider = Provider((ref) => FileMediaRepository());

class FileMediaRepository {
  final NativeSyncApi _nativeSyncApi;

  FileMediaRepository({NativeSyncApi? nativeSyncApi}) : _nativeSyncApi = nativeSyncApi ?? NativeSyncApi();

  Future<LocalAsset?> saveLocalAsset(Uint8List data, {required String title, String? relativePath}) async {
    final entity = await PhotoManager.editor.saveImage(data, filename: title, title: title, relativePath: relativePath);

    return LocalAsset(
      id: entity.id,
      name: title,
      type: AssetType.image,
      createdAt: entity.createDateTime,
      updatedAt: entity.modifiedDateTime,
      playbackStyle: AssetPlaybackStyle.image,
      isEdited: false,
    );
  }

  Future<AssetEntity?> saveImageWithFile(String filePath, {String? title, String? relativePath}) async {
    final entity = await PhotoManager.editor.saveImageWithPath(filePath, title: title, relativePath: relativePath);
    return entity;
  }

  Future<AssetEntity?> saveLivePhoto({required File image, required File video, required String title}) async {
    if (Platform.isIOS) {
      final localIdentifier = await _nativeSyncApi.saveAppleLivePhoto(image.path, video.path, title);
      return AssetEntity.fromId(localIdentifier);
    }
    final entity = await PhotoManager.editor.darwin.saveLivePhoto(imageFile: image, videoFile: video, title: title);
    return entity;
  }

  Future<AssetEntity?> saveVideo(File file, {required String title, String? relativePath}) async {
    final entity = await PhotoManager.editor.saveVideo(file, title: title, relativePath: relativePath);
    return entity;
  }
}
