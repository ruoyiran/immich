import 'dart:async';
import 'dart:io';

import 'package:background_downloader/background_downloader.dart';
import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/constants/constants.dart';
import 'package:immich_mobile/domain/models/asset/base_asset.model.dart';
import 'package:immich_mobile/extensions/platform_extensions.dart';
import 'package:immich_mobile/infrastructure/repositories/backup.repository.dart';
import 'package:immich_mobile/infrastructure/repositories/storage.repository.dart';
import 'package:immich_mobile/providers/infrastructure/storage.provider.dart';
import 'package:immich_mobile/repositories/asset_media.repository.dart';
import 'package:immich_mobile/repositories/upload.repository.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

final backgroundUploadServiceProvider = Provider((ref) {
  final service = BackgroundUploadService(
    ref.watch(uploadRepositoryProvider),
    ref.watch(storageRepositoryProvider),
    ref.watch(backupRepositoryProvider),
    ref.watch(assetMediaRepositoryProvider),
  );

  ref.onDispose(service.dispose);
  return service;
});

/// Background backup uses the same persisted resumable state machine as the
/// foreground service. Each request is one bounded chunk; if iOS suspends the
/// process, the next backup pass restarts with the same stable upload id and
/// adopts the server generation/offset before sending more bytes.
class BackgroundUploadService {
  BackgroundUploadService(
    this._uploadRepository,
    this._storageRepository,
    this._backupRepository,
    this._assetMediaRepository,
  ) {
    _uploadRepository.onUploadStatus = _onUploadCallback;
    _uploadRepository.onTaskProgress = _onTaskProgressCallback;
  }

  final UploadRepository _uploadRepository;
  final StorageRepository _storageRepository;
  final DriftBackupRepository _backupRepository;
  final AssetMediaRepository _assetMediaRepository;
  final Logger _logger = Logger('BackgroundUploadService');

  final StreamController<TaskStatusUpdate> _taskStatusController = StreamController<TaskStatusUpdate>.broadcast();
  final StreamController<TaskProgressUpdate> _taskProgressController = StreamController<TaskProgressUpdate>.broadcast();

  Stream<TaskStatusUpdate> get taskStatusStream => _taskStatusController.stream;
  Stream<TaskProgressUpdate> get taskProgressStream => _taskProgressController.stream;

  bool shouldAbortQueuingTasks = false;
  Completer<void>? _cancelToken;

  void _onTaskProgressCallback(TaskProgressUpdate update) {
    if (!_taskProgressController.isClosed) {
      _taskProgressController.add(update);
    }
  }

  void _onUploadCallback(TaskStatusUpdate update) {
    if (!_taskStatusController.isClosed) {
      _taskStatusController.add(update);
    }
    if (update.status == TaskStatus.complete && CurrentPlatform.isIOS) {
      unawaited(_deleteLegacyTaskFile(update));
    }
  }

  Future<void> _deleteLegacyTaskFile(TaskStatusUpdate update) async {
    try {
      final path = await update.task.filePath();
      final file = File(path);
      if (file.existsSync()) {
        file.deleteSync();
      }
    } catch (error) {
      _logger.warning('Failed to clean legacy background task file: $error');
    }
  }

  void dispose() {
    if (!(_cancelToken?.isCompleted ?? true)) {
      _cancelToken?.complete();
    }
    unawaited(_taskStatusController.close());
    unawaited(_taskProgressController.close());
  }

  Future<List<bool>> enqueueTasks(List<UploadTask> tasks) => _uploadRepository.enqueueBackgroundAll(tasks);

  Future<List<Task>> getActiveTasks(String group) => _uploadRepository.getActiveTasks(group);

  Future<void> uploadBackupCandidates(String userId) async {
    await _storageRepository.clearCache();
    shouldAbortQueuingTasks = false;
    _cancelToken = Completer<void>();

    final candidates = await _backupRepository.getCandidates(userId);
    if (candidates.isEmpty) {
      _logger.info('No new backup candidates found, finishing background upload');
      return;
    }

    for (final asset in candidates.take(100)) {
      if (shouldAbortQueuingTasks || (_cancelToken?.isCompleted ?? false)) {
        break;
      }
      await uploadSingleAsset(asset, cancelToken: _cancelToken);
    }
  }

  Future<int> cancel() async {
    shouldAbortQueuingTasks = true;
    if (!(_cancelToken?.isCompleted ?? true)) {
      _cancelToken?.complete();
    }
    await _storageRepository.clearCache();
    await _uploadRepository.reset(kBackupGroup);
    await _uploadRepository.deleteDatabaseRecords(kBackupGroup);
    return (await _uploadRepository.getActiveTasks(kBackupGroup)).length;
  }

  Future<void> resume() => _uploadRepository.start();

  @visibleForTesting
  Future<UploadResult?> uploadSingleAsset(LocalAsset asset, {Completer<void>? cancelToken}) async {
    File? stillFile;
    File? motionFile;
    File? pmliveFile;
    var removePMLive = false;
    try {
      final checksum = await _uploadRepository.ensureAssetChecksum(asset.id, asset.checksum);
      final terminal = await _uploadRepository.preflightResumableTerminal(checksum: checksum, uploadId: asset.id);
      if (terminal != null) {
        return terminal;
      }
      final entity = await _storageRepository.getAssetEntityForAsset(asset);
      if (entity == null) {
        _logger.warning('Asset entity not found for ${asset.id} - ${asset.name}');
        return null;
      }
      stillFile = await _storageRepository.getFileForAsset(asset.id);
      if (stillFile == null) {
        _logger.warning('Failed to get file for asset ${asset.id} - ${asset.name}');
        return null;
      }
      final baseName = await _assetMediaRepository.getOriginalFilename(asset.id) ?? asset.name;
      final stillExtension = p.extension(stillFile.path).isNotEmpty
          ? p.extension(stillFile.path)
          : p.extension(asset.name);
      final stillOriginalName = p.setExtension(baseName, stillExtension);
      var uploadFile = stillFile;
      var uploadOriginalName = stillOriginalName;
      if (entity.isLivePhoto) {
        motionFile = await _storageRepository.getMotionFileForAsset(asset);
        if (motionFile == null) {
          _logger.warning('Failed to get Live Photo motion for ${asset.id}');
          return null;
        }
        final motionOriginalName = p.setExtension(baseName, p.extension(motionFile.path));
        pmliveFile = await _uploadRepository.createPMLiveBundle(
          assetId: asset.id,
          checksum: checksum,
          stillFile: stillFile,
          motionFile: motionFile,
          stillOriginalName: stillOriginalName,
          motionOriginalName: motionOriginalName,
          createdAt: asset.createdAt,
          modifiedAt: asset.updatedAt,
        );
        uploadFile = pmliveFile;
        uploadOriginalName = p.setExtension(baseName, '.pmlive');
      }

      final result = await _uploadRepository.uploadFile(
        file: uploadFile,
        originalFileName: uploadOriginalName,
        fields: {
          'fileCreatedAt': asset.createdAt.toUtc().toIso8601String(),
          'fileModifiedAt': asset.updatedAt.toUtc().toIso8601String(),
          'isFavorite': asset.isFavorite.toString(),
          'duration': (asset.durationMs ?? 0).toString(),
        },
        cancelToken: cancelToken,
        onProgress: null,
        logContext: 'backgroundAsset[${asset.id}]',
        checksum: checksum,
        uploadId: asset.id,
      );
      removePMLive = result.isSuccess;
      return result;
    } catch (error, stackTrace) {
      _logger.warning('Background upload failed for ${asset.id}: $error', error, stackTrace);
      return UploadResult.error(errorMessage: error.toString());
    } finally {
      if (CurrentPlatform.isIOS) {
        await _deleteTempFile(stillFile);
        await _deleteTempFile(motionFile);
        if (removePMLive) {
          await _deleteTempFile(pmliveFile);
        }
      }
    }
  }

  Future<void> _deleteTempFile(File? file) async {
    if (file == null || !file.existsSync()) {
      return;
    }
    try {
      await file.delete();
    } catch (error) {
      _logger.warning('Failed to clean background temp ${file.path}: $error');
    }
  }
}
