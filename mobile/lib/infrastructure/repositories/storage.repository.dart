// ignore_for_file: avoid_slow_async_io

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:immich_mobile/domain/models/asset/base_asset.model.dart';
import 'package:immich_mobile/extensions/platform_extensions.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';

class LivePhotoFiles {
  final File still;
  final File motion;
  final bool temporary;

  const LivePhotoFiles({required this.still, required this.motion, required this.temporary});
}

class MotionPhotoRanges {
  final int stillLength;
  final int motionOffset;
  final int motionLength;

  const MotionPhotoRanges({required this.stillLength, required this.motionOffset, required this.motionLength});
}

MotionPhotoRanges? parseMotionPhotoRanges(Uint8List prefix, int totalSize) {
  if (totalSize <= 0 || prefix.isEmpty) {
    return null;
  }
  final xmp = latin1.decode(prefix, allowInvalid: true);
  int? motionLength;
  final offset = RegExp(
    r'(?:MicroVideoOffset|MotionPhotoOffset)\s*=\s*["\x27](\d+)["\x27]',
    caseSensitive: false,
  ).firstMatch(xmp);
  if (offset != null) {
    motionLength = int.tryParse(offset.group(1)!);
  }
  if (motionLength == null) {
    for (final tag in RegExp(r'<[^>]+>', dotAll: true).allMatches(xmp)) {
      final value = tag.group(0)!;
      if (!RegExp(r'(?:Semantic)\s*=\s*["\x27]MotionPhoto["\x27]', caseSensitive: false).hasMatch(value)) {
        continue;
      }
      final length = RegExp(r'(?:Length)\s*=\s*["\x27](\d+)["\x27]', caseSensitive: false).firstMatch(value);
      if (length != null) {
        motionLength = int.tryParse(length.group(1)!);
        break;
      }
    }
  }
  if (motionLength == null || motionLength <= 16 || motionLength >= totalSize) {
    return null;
  }
  final motionOffset = totalSize - motionLength;
  if (motionOffset <= 16) {
    return null;
  }
  return MotionPhotoRanges(stillLength: motionOffset, motionOffset: motionOffset, motionLength: motionLength);
}

class StorageRepository {
  final log = Logger('StorageRepository');

  StorageRepository();

  Future<File?> getFileForAsset(String assetId) async {
    File? file;
    final log = Logger('StorageRepository');

    try {
      final entity = await AssetEntity.fromId(assetId);
      file = await entity?.originFile;
      if (file == null) {
        log.warning("Cannot get file for asset $assetId");
        return null;
      }

      final exists = await file.exists();
      if (!exists) {
        log.warning("File for asset $assetId does not exist");
        return null;
      }
    } catch (error, stackTrace) {
      log.warning("Error getting file for asset $assetId", error, stackTrace);
    }
    return file;
  }

  // TODO(agg23): Unify these methods
  Future<File?> getMotionFileForAsset(LocalAsset asset) async {
    File? file;
    final log = Logger('StorageRepository');

    try {
      final entity = await AssetEntity.fromId(asset.id);
      file = await entity?.originFileWithSubtype;
      if (file == null) {
        log.warning(
          "Cannot get motion file for asset ${asset.id}, name: ${asset.name}, created on: ${asset.createdAt}",
        );
        return null;
      }

      final exists = await file.exists();
      if (!exists) {
        log.warning("Motion file for asset ${asset.id} does not exist");
        return null;
      }
    } catch (error, stackTrace) {
      log.warning(
        "Error getting motion file for asset ${asset.id}, name: ${asset.name}, created on: ${asset.createdAt}",
        error,
        stackTrace,
      );
    }
    return file;
  }

  Future<LivePhotoFiles?> getLivePhotoFilesForAsset(LocalAsset asset) async {
    try {
      final entity = await AssetEntity.fromId(asset.id);
      if (entity == null) {
        return null;
      }
      if (CurrentPlatform.isIOS) {
        final still = await entity.originFile;
        final motion = await entity.originFileWithSubtype;
        if (still == null || motion == null || !await still.exists() || !await motion.exists()) {
          return null;
        }
        return LivePhotoFiles(still: still, motion: motion, temporary: true);
      }
      final source = await entity.originFile;
      if (source == null || !await source.exists()) {
        return null;
      }
      return await _extractAndroidMotionPhoto(source, asset.name);
    } catch (error, stackTrace) {
      log.warning('Unable to extract Live/Motion Photo ${asset.id}', error, stackTrace);
      return null;
    }
  }

  Future<LivePhotoFiles> _extractAndroidMotionPhoto(File source, String originalName) async {
    final before = await source.stat();
    if (before.type != FileSystemEntityType.file || before.size <= 32) {
      throw const FormatException('Motion Photo source is not a regular media file');
    }
    final input = await source.open();
    File? still;
    File? motion;
    try {
      final prefix = await input.read(min(before.size, 2 * 1024 * 1024));
      final ranges = parseMotionPhotoRanges(prefix, before.size);
      if (ranges == null) {
        throw const FormatException('Motion Photo XMP does not contain a safe video byte range');
      }
      final sourceIsJpeg = prefix.length >= 2 && prefix[0] == 0xff && prefix[1] == 0xd8;
      final sourceIsHeif = prefix.length >= 12 && ascii.decode(prefix.sublist(4, 8), allowInvalid: true) == 'ftyp';
      if (!sourceIsJpeg && !sourceIsHeif) {
        throw const FormatException('Motion Photo still is neither JPEG nor HEIC/HEIF');
      }
      await input.setPosition(ranges.motionOffset);
      final motionHeader = await input.read(min(32, ranges.motionLength));
      if (motionHeader.length < 12 || ascii.decode(motionHeader.sublist(4, 8), allowInvalid: true) != 'ftyp') {
        throw const FormatException('Motion Photo video range is not an MP4/MOV file');
      }
      if (sourceIsJpeg) {
        final tailStart = max(0, ranges.stillLength - 64 * 1024);
        await input.setPosition(tailStart);
        final tail = await input.read(ranges.stillLength - tailStart);
        var hasEndMarker = false;
        for (var index = 1; index < tail.length; index++) {
          if (tail[index - 1] == 0xff && tail[index] == 0xd9) {
            hasEndMarker = true;
            break;
          }
        }
        if (!hasEndMarker) {
          throw const FormatException('Motion Photo JPEG still range has no end marker');
        }
      }

      final tempRoot = Directory(p.join((await getTemporaryDirectory()).path, 'immich-motion-photo'));
      await tempRoot.create(recursive: true);
      final suffix = List.generate(16, (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0')).join();
      final stillExtension = switch (p.extension(originalName).toLowerCase()) {
        '.heic' || '.heif' => p.extension(originalName).toLowerCase(),
        _ => '.jpg',
      };
      final motionBrand = ascii.decode(motionHeader.sublist(8, 12), allowInvalid: true);
      final motionExtension = motionBrand == 'qt  ' ? '.mov' : '.mp4';
      still = File(p.join(tempRoot.path, '$suffix$stillExtension'));
      motion = File(p.join(tempRoot.path, '$suffix$motionExtension'));
      final stillOutput = await still.open(mode: FileMode.writeOnly);
      final motionOutput = await motion.open(mode: FileMode.writeOnly);
      try {
        await input.setPosition(0);
        await _copyOpenedRange(input, stillOutput, ranges.stillLength);
        await _copyOpenedRange(input, motionOutput, ranges.motionLength);
        await stillOutput.flush();
        await motionOutput.flush();
      } finally {
        await stillOutput.close();
        await motionOutput.close();
      }
      final after = await source.stat();
      if (after.type != FileSystemEntityType.file || after.size != before.size || after.modified != before.modified) {
        throw const FormatException('Motion Photo changed while extracting byte ranges');
      }
      return LivePhotoFiles(still: still, motion: motion, temporary: true);
    } catch (_) {
      if (still != null && await still.exists()) {
        await still.delete();
      }
      if (motion != null && await motion.exists()) {
        await motion.delete();
      }
      rethrow;
    } finally {
      await input.close();
    }
  }

  Future<void> _copyOpenedRange(RandomAccessFile input, RandomAccessFile output, int length) async {
    var remaining = length;
    while (remaining > 0) {
      final chunk = await input.read(min(1024 * 1024, remaining));
      if (chunk.isEmpty) {
        throw const FormatException('Motion Photo byte range ended early');
      }
      await output.writeFrom(chunk);
      remaining -= chunk.length;
    }
  }

  Future<AssetEntity?> getAssetEntityForAsset(LocalAsset asset) async {
    final log = Logger('StorageRepository');

    AssetEntity? entity;

    try {
      entity = await AssetEntity.fromId(asset.id);
      if (entity == null) {
        log.warning(
          "Cannot get AssetEntity for asset ${asset.id}, name: ${asset.name}, created on: ${asset.createdAt}",
        );
      }
    } catch (error, stackTrace) {
      log.warning(
        "Error getting AssetEntity for asset ${asset.id}, name: ${asset.name}, created on: ${asset.createdAt}",
        error,
        stackTrace,
      );
    }
    return entity;
  }

  Future<bool> isAssetAvailableLocally(String assetId) async {
    try {
      final entity = await AssetEntity.fromId(assetId);
      if (entity == null) {
        log.warning("Cannot get AssetEntity for asset $assetId");
        return false;
      }

      return await entity.isLocallyAvailable(isOrigin: true);
    } catch (error, stackTrace) {
      log.warning("Error checking if asset is locally available $assetId", error, stackTrace);
      return false;
    }
  }

  Future<File?> loadFileFromCloud(String assetId, {PMProgressHandler? progressHandler}) async {
    try {
      final entity = await AssetEntity.fromId(assetId);
      if (entity == null) {
        log.warning("Cannot get AssetEntity for asset $assetId");
        return null;
      }

      return await entity.loadFile(progressHandler: progressHandler);
    } catch (error, stackTrace) {
      log.warning("Error loading file from cloud for asset $assetId", error, stackTrace);
      return null;
    }
  }

  Future<File?> loadMotionFileFromCloud(String assetId, {PMProgressHandler? progressHandler}) async {
    try {
      final entity = await AssetEntity.fromId(assetId);
      if (entity == null) {
        log.warning("Cannot get AssetEntity for asset $assetId");
        return null;
      }

      return await entity.loadFile(withSubtype: true, progressHandler: progressHandler);
    } catch (error, stackTrace) {
      log.warning("Error loading motion file from cloud for asset $assetId", error, stackTrace);
      return null;
    }
  }

  Future<void> clearCache() async {
    final log = Logger('StorageRepository');

    try {
      await PhotoManager.clearFileCache();
    } catch (error, stackTrace) {
      log.warning("Error clearing cache", error, stackTrace);
    }

    if (!CurrentPlatform.isIOS) {
      return;
    }

    try {
      if (await Directory.systemTemp.exists()) {
        await Directory.systemTemp.delete(recursive: true);
      }
    } catch (error, stackTrace) {
      log.warning("Error deleting temporary directory", error, stackTrace);
    }
  }
}
