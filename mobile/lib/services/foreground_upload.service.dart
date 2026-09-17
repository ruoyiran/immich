import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/domain/models/asset/asset_metadata.model.dart';
import 'package:immich_mobile/domain/models/asset/base_asset.model.dart' hide AssetVisibility;
import 'package:immich_mobile/domain/models/store.model.dart';
import 'package:immich_mobile/domain/services/background_task.service.dart';
import 'package:immich_mobile/entities/store.entity.dart';
import 'package:immich_mobile/extensions/platform_extensions.dart';
import 'package:immich_mobile/extensions/translate_extensions.dart';
import 'package:immich_mobile/infrastructure/repositories/storage.repository.dart';
import 'package:immich_mobile/platform/background_task_api.g.dart';
import 'package:immich_mobile/providers/background_task.provider.dart';
import 'package:immich_mobile/providers/infrastructure/storage.provider.dart';
import 'package:immich_mobile/repositories/asset_media.repository.dart';
import 'package:immich_mobile/repositories/upload.repository.dart';
import 'package:immich_mobile/utils/upload_source_metadata.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:photo_manager/photo_manager.dart' show PMProgressHandler;
import 'package:worker_manager/worker_manager.dart' show CanceledError;

/// Callbacks for upload progress and status updates
class UploadCallbacks {
  final void Function(String id, String filename, int bytes, int totalBytes)? onProgress;
  final void Function(String localId)? onProcessing;
  final void Function(String localId, String remoteId)? onSuccess;
  final void Function(String id, String errorMessage)? onError;
  final void Function(String id, double progress)? onICloudProgress;

  const UploadCallbacks({this.onProgress, this.onProcessing, this.onSuccess, this.onError, this.onICloudProgress});
}

final foregroundUploadServiceProvider = Provider((ref) {
  // ignore: dispose-provided-instances
  return ForegroundUploadService(
    ref.watch(uploadRepositoryProvider),
    ref.watch(storageRepositoryProvider),
    ref.watch(assetMediaRepositoryProvider),
    backgroundTaskService: ref.watch(backgroundTaskServiceProvider),
  );
});

/// Service for handling user-started HTTP uploads, including background continuation.
///
/// This service handles synchronous uploads using HTTP client with
/// concurrent worker pools. Used for manual and share intent uploads.
class ForegroundUploadService {
  ForegroundUploadService(
    this._uploadRepository,
    this._storageRepository,
    this._assetMediaRepository, {
    this.backgroundTaskService,
  });

  final UploadRepository _uploadRepository;
  final StorageRepository _storageRepository;
  final AssetMediaRepository _assetMediaRepository;
  final BackgroundTaskService? backgroundTaskService;
  final _activePools = <Completer<void>>{};
  final _poolDrains = <Completer<void>>{};
  final _waitingTransfers = Queue<Completer<void>>();
  int _activeTransfers = 0;
  Future<void> _cacheClear = Future.value();
  final Logger _logger = Logger('ForegroundUploadService');

  bool shouldAbortUpload = false;

  /// Manually upload picked local assets
  Future<void> uploadManual(
    List<LocalAsset> localAssets, {
    Completer<void>? cancelToken,
    UploadCallbacks callbacks = const UploadCallbacks(),
  }) async {
    if (localAssets.isEmpty) {
      return;
    }

    await _executeWithWorkerPool<LocalAsset>(
      items: localAssets,
      cancelToken: cancelToken,
      processItem: (asset, token, reportProgress, transfer) => uploadSingleAsset(
        asset,
        token,
        callbacks: _callbacksForAttempt(callbacks, token, reportProgress, transfer.release),
        acquireTransferSlot: transfer.acquire,
      ),
    );
  }

  /// Upload files from shared intent
  Future<void> uploadShareIntent(
    List<File> files, {
    Completer<void>? cancelToken,
    void Function(String fileId, int bytes, int totalBytes)? onProgress,
    void Function(String fileId, String remoteAssetId)? onSuccess,
    void Function(String fileId, String errorMessage)? onError,
  }) async {
    if (files.isEmpty) {
      return;
    }
    await _executeWithWorkerPool<File>(
      items: files,
      cancelToken: cancelToken,
      processItem: (file, token, reportProgress, transfer) async {
        final fileId = p.hash(file.path).toString();

        final result = await _uploadSingleFile(
          file,
          deviceAssetId: fileId,
          cancelToken: token,
          onProgress: (bytes, totalBytes) {
            if (token.isCompleted) {
              return;
            }
            reportProgress(bytes, totalBytes);
            onProgress?.call(fileId, bytes, totalBytes);
          },
          onProcessing: transfer.release,
        );

        if (token.isCompleted) {
          return;
        }
        if (result.isSuccess) {
          onSuccess?.call(fileId, result.remoteAssetId!);
        } else if (!result.isCancelled && result.errorMessage != null) {
          onError?.call(fileId, result.errorMessage!);
        }
      },
    );
  }

  void cancel() {
    shouldAbortUpload = true;
    for (final token in _activePools) {
      if (!token.isCompleted) {
        token.complete();
      }
    }
  }

  Future<void> cancelAndDrain() async {
    final drains = _poolDrains.map((drain) => drain.future).toList();
    cancel();
    await Future.wait(drains);
  }

  UploadCallbacks _callbacksForAttempt(
    UploadCallbacks callbacks,
    Completer<void> token,
    void Function(int bytes, int total) reportProgress,
    void Function() releaseTransferSlot,
  ) => UploadCallbacks(
    onProgress: (id, filename, bytes, total) {
      if (token.isCompleted) {
        return;
      }
      reportProgress(bytes, total);
      callbacks.onProgress?.call(id, filename, bytes, total);
    },
    onProcessing: (id) {
      releaseTransferSlot();
      if (!token.isCompleted) {
        callbacks.onProcessing?.call(id);
      }
    },
    onSuccess: (id, remoteId) {
      if (!token.isCompleted) {
        callbacks.onSuccess?.call(id, remoteId);
      }
    },
    onError: (id, error) {
      if (!token.isCompleted) {
        callbacks.onError?.call(id, error);
      }
    },
    onICloudProgress: (id, progress) {
      if (!token.isCompleted) {
        callbacks.onICloudProgress?.call(id, progress);
      }
    },
  );

  Future<void> _executeWithWorkerPool<T>({
    required List<T> items,
    required Completer<void>? cancelToken,
    required Future<void> Function(
      T item,
      Completer<void> token,
      void Function(int, int) reportProgress,
      _UploadTransferLease transfer,
    )
    processItem,
  }) async {
    if (cancelToken?.isCompleted ?? false) {
      return;
    }
    final cancellation = Completer<void>();
    if (_activePools.isEmpty) {
      _cacheClear = _storageRepository.clearCache();
    }
    _activePools.add(cancellation);
    final drained = Completer<void>();
    _poolDrains.add(drained);
    if (cancelToken != null) {
      unawaited(
        cancelToken.future.then((_) {
          if (_activePools.contains(cancellation) && !cancellation.isCompleted) {
            cancellation.complete();
          }
        }),
      );
    }
    shouldAbortUpload = false;
    Future<void> runPool(BackgroundTask? task) async {
      await _cacheClear;
      final progress = <int, int>{};
      Future<void> worker(int index) async {
        if (!shouldAbortUpload && !cancellation.isCompleted) {
          void reportProgress(int bytes, int total) {
            if (total <= 0) {
              return;
            }
            // Reserve the last unit until server processing has completed. A
            // Live Photo's motion and still parts remain one logical item.
            final value = (bytes * 1000 ~/ total).clamp(0, 999);
            if (value > (progress[index] ?? 0)) {
              progress[index] = value;
            }
            task?.progress(progress.values.fold(0, (a, b) => a + b), items.length * 1000);
          }

          Future<void> upload(Completer<void> token) async {
            final transfer = _UploadTransferLease(() => _acquireTransferSlot(token));
            try {
              await transfer.acquire();
              if (!shouldAbortUpload && !token.isCompleted) {
                await processItem(items[index], token, reportProgress, transfer);
              }
            } finally {
              transfer.release();
            }
          }

          if (task == null) {
            await upload(cancellation);
          } else {
            await task.run(upload);
          }
          if (cancellation.isCompleted) {
            return;
          }
          progress[index] = 1000;
          task?.progress(progress.values.fold(0, (a, b) => a + b), items.length * 1000);
        }
      }

      await Future.wait(List.generate(items.length, worker));
    }

    try {
      final background = backgroundTaskService;
      if (background == null) {
        await runPool(null);
      } else {
        await background.run(
          mode: BackgroundTaskMode.continued,
          title: 'uploading_media'.t(),
          description: 'backup_background_service_in_progress_notification'.t(),
          cancelToken: cancellation,
          action: runPool,
        );
      }
    } on CanceledError {
      // User cancellation stops the pool; OS expiry is retried inside task.run.
    } finally {
      _activePools.remove(cancellation);
      _poolDrains.remove(drained);
      drained.complete();
    }
  }

  Future<void Function()> _acquireTransferSlot(Completer<void> token) async {
    if (token.isCompleted) {
      throw CanceledError();
    }
    final ready = Completer<void>();
    if (_activeTransfers < 3) {
      _activeTransfers++;
      ready.complete();
    } else {
      _waitingTransfers.add(ready);
    }
    await Future.any([ready.future, token.future]);
    if (token.isCompleted) {
      if (!_waitingTransfers.remove(ready)) {
        _releaseTransferSlot();
      }
      throw CanceledError();
    }
    return _releaseTransferSlot;
  }

  void _releaseTransferSlot() {
    if (_waitingTransfers.isEmpty) {
      _activeTransfers--;
    } else {
      _waitingTransfers.removeFirst().complete();
    }
  }

  @visibleForTesting
  Future<void> uploadSingleAsset(
    LocalAsset asset,
    Completer<void>? cancelToken, {
    required UploadCallbacks callbacks,
    Future<void> Function()? acquireTransferSlot,
  }) async {
    File? file;
    File? livePhotoFile;
    var temporaryLivePhotoFiles = false;

    try {
      if (cancelToken?.isCompleted ?? false) {
        return;
      }
      final deviceId = Store.get(StoreKey.deviceId);
      if ((!CurrentPlatform.isAndroid || !asset.isMotionPhoto) && asset.contentSize != null) {
        final identityFields = {
          'deviceAssetId': asset.localId!,
          'deviceId': deviceId,
          'fileCreatedAt': asset.createdAt.toUtc().toIso8601String(),
          'fileModifiedAt': asset.updatedAt.toUtc().toIso8601String(),
          'sourceMetadata': buildUploadSourceMetadata(asset, originalName: asset.name, deviceId: deviceId),
        };
        final linked = await _uploadRepository.preflightLocalAssetIdentity(
          assetId: asset.id,
          localAssetId: asset.localId!,
          deviceId: deviceId,
          size: asset.contentSize!,
          modifiedAt: asset.updatedAt,
          originalFileName: asset.name,
          fields: identityFields,
          cancelToken: cancelToken,
        );
        if (linked != null) {
          callbacks.onSuccess?.call(asset.localId!, linked.remoteAssetId!);
          return;
        }
      }
      if (cancelToken?.isCompleted ?? false) {
        return;
      }
      String? checksum;
      if (!CurrentPlatform.isAndroid || !asset.isMotionPhoto) {
        checksum = await _uploadRepository.ensureAssetChecksum(
          asset.id,
          asset.checksum,
          contentMd5: asset.contentMd5,
          contentSize: asset.contentSize,
          hashAlgorithm: asset.hashAlgorithm,
          hashedModifiedAt: asset.hashedModifiedAt,
          modifiedAt: asset.updatedAt,
        );
        final terminal = await _uploadRepository.preflightResumableTerminal(
          checksum: checksum,
          uploadId: asset.id,
          cancelToken: cancelToken,
        );
        if (terminal != null) {
          if (terminal.isSuccess && terminal.remoteAssetId != null) {
            callbacks.onSuccess?.call(asset.localId!, terminal.remoteAssetId!);
          } else if (terminal.errorMessage != null) {
            callbacks.onError?.call(asset.localId!, terminal.errorMessage!);
          }
          return;
        }
      }
      if (cancelToken?.isCompleted ?? false) {
        return;
      }
      final entity = await _storageRepository.getAssetEntityForAsset(asset);
      if (entity == null) {
        callbacks.onError?.call(
          asset.localId!,
          CurrentPlatform.isAndroid ? "asset_not_found_on_device_android".t() : "asset_not_found_on_device_ios".t(),
        );
        return;
      }
      final androidMotionPhotoUsesServerSplit =
          CurrentPlatform.isAndroid && asset.isMotionPhoto && _isHeicFileName(asset.name);
      final shouldUploadAsLivePhoto =
          entity.isLivePhoto ||
          (CurrentPlatform.isAndroid && asset.isMotionPhoto && !androidMotionPhotoUsesServerSplit);

      final isAvailableLocally = await _storageRepository.isAssetAvailableLocally(asset.id);

      if (!isAvailableLocally && CurrentPlatform.isIOS) {
        _logger.info("Loading iCloud asset ${asset.id} - ${asset.name}");

        // Create progress handler for iCloud download
        PMProgressHandler? progressHandler;
        StreamSubscription? progressSubscription;

        progressHandler = PMProgressHandler();
        progressSubscription = progressHandler.stream.listen((event) {
          callbacks.onICloudProgress?.call(asset.localId!, event.progress);
        });

        try {
          file = await _storageRepository.loadFileFromCloud(asset.id, progressHandler: progressHandler);
          if (shouldUploadAsLivePhoto) {
            livePhotoFile = await _storageRepository.loadMotionFileFromCloud(
              asset.id,
              progressHandler: progressHandler,
            );
          }
        } finally {
          await progressSubscription.cancel();
        }
      } else {
        // Get files locally
        if (shouldUploadAsLivePhoto && CurrentPlatform.isAndroid) {
          final liveFiles = await _storageRepository.getLivePhotoFilesForAsset(asset);
          file = liveFiles?.still;
          livePhotoFile = liveFiles?.motion;
          temporaryLivePhotoFiles = liveFiles?.temporary ?? false;
        } else {
          file = await _storageRepository.getFileForAsset(asset.id);
        }
        if (file == null) {
          _logger.warning("Failed to get file ${asset.id} - ${asset.name}");
          callbacks.onError?.call(
            asset.localId!,
            CurrentPlatform.isAndroid ? "asset_not_found_on_device_android".t() : "asset_not_found_on_device_ios".t(),
          );
          return;
        }

        // For live photos, get the motion video file
        if (shouldUploadAsLivePhoto && livePhotoFile == null) {
          livePhotoFile = await _storageRepository.getMotionFileForAsset(asset);
          if (livePhotoFile == null) {
            _logger.warning("Failed to obtain motion part of the livePhoto - ${asset.name}");
            callbacks.onError?.call(
              asset.localId!,
              CurrentPlatform.isAndroid ? "asset_not_found_on_device_android".t() : "asset_not_found_on_device_ios".t(),
            );
          }
        }
      }

      if (file == null) {
        _logger.warning("Failed to obtain file from iCloud for asset ${asset.id} - ${asset.name}");
        callbacks.onError?.call(asset.localId!, "asset_not_found_on_icloud".t());
        return;
      }

      if (cancelToken?.isCompleted ?? false) {
        return;
      }

      final uploadChecksum =
          checksum ??
          await _uploadRepository.ensureAssetFileChecksum(
            asset.id,
            file,
            checksum: asset.checksum,
            contentMd5: asset.contentMd5,
            contentSize: asset.contentSize,
            hashAlgorithm: asset.hashAlgorithm,
            hashedModifiedAt: asset.hashedModifiedAt,
            modifiedAt: asset.updatedAt,
          );
      if (checksum == null) {
        final terminal = await _uploadRepository.preflightResumableTerminal(
          checksum: uploadChecksum,
          uploadId: asset.id,
          cancelToken: cancelToken,
        );
        if (terminal != null) {
          if (terminal.isSuccess && terminal.remoteAssetId != null) {
            callbacks.onSuccess?.call(asset.localId!, terminal.remoteAssetId!);
          } else if (terminal.errorMessage != null) {
            callbacks.onError?.call(asset.localId!, terminal.errorMessage!);
          }
          return;
        }
      }

      if (cancelToken?.isCompleted ?? false) {
        return;
      }

      final fileName = await _assetMediaRepository.getOriginalFilename(asset.id) ?? asset.name;
      // Some apps (e.g. DJI/Fusion) return names without an extension; fall back to the asset name for those.
      final extension = p.extension(file.path).isNotEmpty ? p.extension(file.path) : p.extension(asset.name);
      final originalFileName = p.setExtension(fileName, extension);
      final fields = {
        // deviceAssetId/deviceId required by server v2.7.5 and below (drop in v4.0 per #27818).
        'deviceAssetId': asset.localId!,
        'deviceId': deviceId,
        'fileCreatedAt': asset.createdAt.toUtc().toIso8601String(),
        'fileModifiedAt': asset.updatedAt.toUtc().toIso8601String(),
        'isFavorite': asset.isFavorite.toString(),
        'duration': (asset.durationMs ?? 0).toString(),
        'sourceMetadata': buildUploadSourceMetadata(asset, originalName: originalFileName, deviceId: deviceId),
      };

      if (shouldUploadAsLivePhoto) {
        if (livePhotoFile == null) {
          return;
        }
        final motionName = p.setExtension(fileName, p.extension(livePhotoFile.path));
        final motionChecksum = await _uploadRepository.hashShareIntentFile(livePhotoFile);
        final motionResult = await _uploadRepository.uploadFile(
          file: livePhotoFile,
          originalFileName: motionName,
          fields: {...fields, 'visibility': 'hidden', 'livePhotoRole': 'motion'},
          cancelToken: cancelToken,
          onProgress: callbacks.onProgress != null
              ? (bytes, totalBytes) => callbacks.onProgress!(asset.localId!, motionName, bytes, totalBytes)
              : null,
          onProcessing: callbacks.onProcessing != null ? () => callbacks.onProcessing!(asset.localId!) : null,
          logContext: 'livePhotoMotion[${asset.localId}]',
          checksum: motionChecksum,
          uploadId: '${asset.id}:motion',
        );
        if (motionResult.isCancelled) {
          return;
        }
        if (!motionResult.isSuccess || motionResult.remoteAssetId == null) {
          callbacks.onError?.call(asset.localId!, motionResult.errorMessage ?? 'Failed to upload Live Photo motion');
          return;
        }
        fields['livePhotoVideoId'] = motionResult.remoteAssetId!;
      }

      // Cloud metadata remains attached to the one logical still asset.
      if (CurrentPlatform.isIOS && asset.cloudId != null) {
        fields['metadata'] = jsonEncode([
          RemoteAssetMetadataItem(
            key: RemoteAssetMetadataKey.mobileApp,
            value: RemoteAssetMobileAppMetadata(
              cloudId: asset.cloudId,
              createdAt: asset.createdAt.toIso8601String(),
              adjustmentTime: asset.adjustmentTime?.toIso8601String(),
              latitude: asset.latitude?.toString(),
              longitude: asset.longitude?.toString(),
            ),
          ),
        ]);
      }

      final onProgress = callbacks.onProgress;
      await acquireTransferSlot?.call();
      if (cancelToken?.isCompleted ?? false) {
        return;
      }
      final result = await _uploadRepository.uploadFile(
        file: file,
        originalFileName: originalFileName,
        fields: fields,
        cancelToken: cancelToken,
        onProgress: onProgress != null
            ? (bytes, totalBytes) => onProgress(asset.localId!, originalFileName, bytes, totalBytes)
            : null,
        onProcessing: callbacks.onProcessing != null ? () => callbacks.onProcessing!(asset.localId!) : null,
        logContext: 'asset[${asset.localId}]',
        checksum: uploadChecksum,
        uploadId: asset.id,
      );

      if (result.isSuccess && result.remoteAssetId != null) {
        callbacks.onSuccess?.call(asset.localId!, result.remoteAssetId!);
      } else if (result.isCancelled) {
        return;
      } else if (result.errorMessage != null) {
        _logger.severe(
          () =>
              "Error(${result.statusCode}) uploading ${asset.localId} | $originalFileName | Created on ${asset.createdAt} | ${result.errorMessage}",
        );

        callbacks.onError?.call(asset.localId!, result.errorMessage!);

        if (result.errorMessage == "Quota has been exceeded!") {
          shouldAbortUpload = true;
        }
      }
    } catch (error, stackTrace) {
      _logger.severe(() => "Error backup asset: $error", stackTrace);
      callbacks.onError?.call(asset.localId!, error.toString());
    } finally {
      if (CurrentPlatform.isIOS || temporaryLivePhotoFiles) {
        await _deleteTempFile(file);
        await _deleteTempFile(livePhotoFile);
      }
    }
  }

  Future<void> _deleteTempFile(File? file) async {
    if (file == null || !file.existsSync()) {
      return;
    }
    try {
      await file.delete();
    } catch (error, stackTrace) {
      _logger.severe(() => 'ERROR deleting ${file.path}: $error', stackTrace);
    }
  }

  Future<UploadResult> _uploadSingleFile(
    File file, {
    required String deviceAssetId,
    required Completer<void>? cancelToken,
    void Function(int bytes, int totalBytes)? onProgress,
    void Function()? onProcessing,
  }) async {
    try {
      if (cancelToken?.isCompleted ?? false) {
        return UploadResult.cancelled();
      }
      // ignore: avoid_slow_async_io
      final stats = await file.stat();
      final fileCreatedAt = stats.changed;
      final fileModifiedAt = stats.modified;
      final filename = p.basename(file.path);

      final fields = {
        // deviceAssetId/deviceId required by server v2.7.5 and below (drop in v4.0 per #27818).
        'deviceAssetId': deviceAssetId,
        'deviceId': Store.get(StoreKey.deviceId),
        'fileCreatedAt': fileCreatedAt.toUtc().toIso8601String(),
        'fileModifiedAt': fileModifiedAt.toUtc().toIso8601String(),
        'isFavorite': 'false',
        'duration': '0',
      };
      final checksum = await _uploadRepository.hashShareIntentFile(file);

      if (cancelToken?.isCompleted ?? false) {
        return UploadResult.cancelled();
      }

      return await _uploadRepository.uploadFile(
        file: file,
        originalFileName: filename,
        fields: fields,
        cancelToken: cancelToken,
        onProgress: onProgress,
        logContext: 'shareIntent[$deviceAssetId]',
        onProcessing: onProcessing,
        checksum: checksum,
        uploadId: deviceAssetId,
      );
    } catch (e) {
      return UploadResult.error(errorMessage: e.toString());
    }
  }
}

class _UploadTransferLease {
  final Future<void Function()> Function() _acquire;
  void Function()? _release;

  _UploadTransferLease(this._acquire);

  Future<void> acquire() async {
    _release ??= await _acquire();
  }

  void release() {
    final release = _release;
    _release = null;
    release?.call();
  }
}

bool _isHeicFileName(String filename) {
  final extension = p.extension(filename).toLowerCase();
  return extension == '.heic' || extension == '.heif';
}
