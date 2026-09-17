import 'dart:async';

import 'package:immich_mobile/domain/services/background_task.service.dart';
import 'package:immich_mobile/domain/utils/migrate_cloud_ids.dart' as m;
import 'package:immich_mobile/extensions/translate_extensions.dart';
import 'package:immich_mobile/platform/background_task_api.g.dart';
import 'package:immich_mobile/providers/infrastructure/sync.provider.dart';
import 'package:immich_mobile/utils/isolate.dart';
import 'package:logging/logging.dart';
import 'package:worker_manager/worker_manager.dart';

typedef SyncCallback = void Function();
typedef SyncCallbackWithResult<T> = void Function(T result);
typedef SyncErrorCallback = void Function(String error);

class BackgroundSyncManager {
  final _log = Logger('BackgroundSyncManager');
  final BackgroundTaskService? backgroundTaskService;
  final Cancelable<bool?> Function()? remoteSyncTaskFactory;
  final SyncCallback? onRemoteSyncStart;
  final SyncCallbackWithResult<bool?>? onRemoteSyncComplete;
  final SyncErrorCallback? onRemoteSyncError;
  // Fired when an in-flight remote sync is cancelled (CanceledError). A cancel
  // is neither success nor failure, but the status notifier must still leave
  // "syncing" — see syncRemote's catchError.
  final SyncCallback? onRemoteSyncCancel;

  final SyncCallback? onLocalSyncStart;
  final SyncCallback? onLocalSyncComplete;
  final SyncErrorCallback? onLocalSyncError;

  final SyncCallback? onCloudIdSyncStart;
  final SyncCallback? onCloudIdSyncComplete;
  final SyncErrorCallback? onCloudIdSyncError;

  Cancelable<bool?>? _syncTask;
  Future<bool>? _syncFuture;
  BackgroundTask? _remoteBackgroundTask;
  bool _remoteSyncUserInitiated = false;
  bool Function()? _resumeRetry;
  bool _syncQueued = false;
  Cancelable<void>? _syncWebsocketTask;
  Cancelable<void>? _cloudIdSyncTask;
  Cancelable<void>? _deviceAlbumSyncTask;

  BackgroundSyncManager({
    this.backgroundTaskService,
    this.remoteSyncTaskFactory,
    this.onRemoteSyncStart,
    this.onRemoteSyncComplete,
    this.onRemoteSyncError,
    this.onRemoteSyncCancel,
    this.onLocalSyncStart,
    this.onLocalSyncComplete,
    this.onLocalSyncError,
    this.onCloudIdSyncStart,
    this.onCloudIdSyncComplete,
    this.onCloudIdSyncError,
  });

  // The tasks the app-resume path re-runs. One in-flight when the app was suspended
  // stays referenced but frozen, so on resume the dedupe guards would hand back the
  // stale task instead of syncing (#28082). Websocket and cloud-id are excluded - the
  // resume path never restarts them. [_allTasks] builds on this so the lists can't drift.
  List<Cancelable?> get _resumeSyncTasks => [_syncTask, _deviceAlbumSyncTask];

  List<Cancelable?> get _allTasks => [_syncWebsocketTask, _cloudIdSyncTask, ..._resumeSyncTasks];

  Future<void> cancel() async {
    _remoteBackgroundTask = null;
    _remoteSyncUserInitiated = false;
    _syncQueued = false;
    _resumeRetry = null;
    _syncFuture = null;
    final tasks = _allTasks;
    _syncTask = null;
    _syncWebsocketTask = null;
    _cloudIdSyncTask = null;
    _deviceAlbumSyncTask = null;
    await _cancelAll(tasks);
  }

  Future<void> cancelResumeSyncs() async {
    _remoteBackgroundTask = null;
    _remoteSyncUserInitiated = false;
    _syncQueued = false;
    _resumeRetry = null;
    _syncFuture = null;
    final tasks = _resumeSyncTasks;
    _syncTask = null;
    _deviceAlbumSyncTask = null;
    await _cancelAll(tasks);
  }

  Future<void> cancelLocalSync() async {
    final task = _deviceAlbumSyncTask;
    _deviceAlbumSyncTask = null;
    await _cancelAll([task]);
  }

  // Cancels every task in [tasks] and waits for them to unwind. Callers null out
  // their own fields first, so the sync guards see a clean slate immediately.
  Future<void> _cancelAll(List<Cancelable?> tasks) async {
    final futures = [
      for (final task in tasks)
        if (task != null) task.future,
    ];
    for (final task in tasks) {
      try {
        task?.cancel();
      } on CanceledError {
        // Ignore cancellation errors
      }
    }
    try {
      await Future.wait(futures);
    } on CanceledError {
      // Ignore cancellation errors
    }
  }

  // No need to cancel the task, as it can also be run when the user logs out
  Future<void> syncLocal({bool full = false}) {
    if (_deviceAlbumSyncTask != null) {
      return _deviceAlbumSyncTask!.future.catchError((_) {}, test: (error) => error is CanceledError);
    }

    onLocalSyncStart?.call();

    // We use a ternary operator to avoid [_deviceAlbumSyncTask] from being
    // captured by the closure passed to [runInIsolateGentle].
    final task = _deviceAlbumSyncTask = full
        ? runInIsolateGentle(
            computation: (ref) => ref.read(localSyncServiceProvider).sync(full: true),
            debugLabel: 'local-sync-full-true',
          )
        : runInIsolateGentle(
            computation: (ref) => ref.read(localSyncServiceProvider).sync(full: false),
            debugLabel: 'local-sync-full-false',
          );

    return task
        .whenComplete(() {
          if (identical(_deviceAlbumSyncTask, task)) {
            _deviceAlbumSyncTask = null;
          }
          onLocalSyncComplete?.call();
        })
        .catchError((error) {
          if (error is! CanceledError) {
            onLocalSyncError?.call(error.toString());
          }
        });
  }

  Future<bool> resumeRemoteSync({required bool Function() shouldContinue}) {
    if (!shouldContinue()) {
      return Future.value(false);
    }
    if (_syncTask != null) {
      _resumeRetry = shouldContinue;
    }
    return syncRemote();
  }

  bool _takeResumeRetry() {
    final shouldContinue = _resumeRetry;
    _resumeRetry = null;
    return shouldContinue?.call() ?? false;
  }

  Future<bool> _restartRemoteSync() {
    _log.info('Retrying failed remote sync after foreground resume');
    _syncTask = null;
    _syncFuture = null;
    _syncQueued = false;
    _remoteBackgroundTask = null;
    return syncRemote(userInitiated: _remoteSyncUserInitiated);
  }

  Future<bool> syncRemote({bool enqueue = false, bool userInitiated = false}) {
    if (_syncTask != null) {
      _syncQueued |= enqueue;
      if (userInitiated && !_remoteSyncUserInitiated) {
        _remoteSyncUserInitiated = true;
        unawaited(_remoteBackgroundTask?.requestContinuedProcessing());
      }
      return _syncFuture!;
    }

    onRemoteSyncStart?.call();
    _remoteSyncUserInitiated = userInitiated;

    final task = _syncTask =
        backgroundTaskService?.execute<bool>(
          title: 'sync'.t(),
          description: 'sync_remote'.t(),
          mode: userInitiated ? BackgroundTaskMode.continued : BackgroundTaskMode.limited,
          onTaskCreated: (task) {
            _remoteBackgroundTask = task;
            if (_remoteSyncUserInitiated) {
              unawaited(task.requestContinuedProcessing());
            }
          },
          factory: (taskId) => remoteSyncTaskFactory?.call() ?? _runRemoteSync(taskId),
        ) ??
        remoteSyncTaskFactory?.call() ??
        _runRemoteSync(null);
    return _syncFuture = task
        .then<bool>((result) {
          final success = result ?? false;
          if (!identical(_syncTask, task)) {
            return success;
          }
          if (!success && _takeResumeRetry()) {
            return _restartRemoteSync();
          }
          onRemoteSyncComplete?.call(success);
          _syncQueued &= success;
          return success;
        })
        .catchError((error) {
          if (!identical(_syncTask, task)) {
            return false;
          }
          if (error is CanceledError) {
            // A cancelled remote sync is neither success nor failure, but it
            // must still transition the status out of "syncing": the notifier
            // only heard onRemoteSyncStart, so without this it stays stuck on
            // "syncing" forever (the "always syncing" symptom).
            onRemoteSyncCancel?.call();
          } else if (_takeResumeRetry()) {
            return _restartRemoteSync();
          } else {
            onRemoteSyncError?.call(error.toString());
          }
          _syncQueued = false;
          return false;
        })
        // A task clears only its own slot: one that was cancelled and superseded by a
        // fresh task (see cancelResumeSyncs) must not null the new task's slot.
        .whenComplete(() {
          if (identical(_syncTask, task)) {
            _syncTask = null;
            _syncFuture = null;
            _remoteBackgroundTask = null;
            _remoteSyncUserInitiated = false;
            _resumeRetry = null;
            if (_syncQueued) {
              _syncQueued = false;
              unawaited(syncRemote());
            }
          }
        });
  }

  Future<void> syncWebsocketBatchV1(List<dynamic> batchData) {
    if (_syncWebsocketTask != null) {
      return _syncWebsocketTask!.future;
    }
    _syncWebsocketTask = _handleWsAssetUploadReadyV1Batch(batchData);
    return _syncWebsocketTask!.whenComplete(() {
      _syncWebsocketTask = null;
    });
  }

  Future<void> syncWebsocketBatchV2(List<dynamic> batchData) {
    if (_syncWebsocketTask != null) {
      return _syncWebsocketTask!.future;
    }
    _syncWebsocketTask = _handleWsAssetUploadReadyV2Batch(batchData);
    return _syncWebsocketTask!.whenComplete(() {
      _syncWebsocketTask = null;
    });
  }

  Future<void> syncWebsocketEditV1(dynamic data) {
    if (_syncWebsocketTask != null) {
      return _syncWebsocketTask!.future;
    }
    _syncWebsocketTask = _handleWsAssetEditReadyV1(data);
    return _syncWebsocketTask!.whenComplete(() {
      _syncWebsocketTask = null;
    });
  }

  Future<void> syncWebsocketEditV2(dynamic data) {
    if (_syncWebsocketTask != null) {
      return _syncWebsocketTask!.future;
    }
    _syncWebsocketTask = _handleWsAssetEditReadyV2(data);
    return _syncWebsocketTask!.whenComplete(() {
      _syncWebsocketTask = null;
    });
  }

  Future<void> syncCloudIds() {
    if (_cloudIdSyncTask != null) {
      return _cloudIdSyncTask!.future;
    }

    onCloudIdSyncStart?.call();

    _cloudIdSyncTask = runInIsolateGentle(computation: m.syncCloudIds);
    return _cloudIdSyncTask!
        .whenComplete(() {
          onCloudIdSyncComplete?.call();
          _cloudIdSyncTask = null;
        })
        .catchError((error) {
          onCloudIdSyncError?.call(error.toString());
          _cloudIdSyncTask = null;
        });
  }
}

Cancelable<bool?> _runRemoteSync(String? taskId) => runInIsolateGentle(
  computation: (ref) {
    var lastProgress = DateTime.fromMillisecondsSinceEpoch(0);
    return ref
        .read(syncStreamServiceProvider)
        .sync(
          onProgress: taskId == null
              ? null
              : (completed) async {
                  final now = DateTime.now();
                  if (now.difference(lastProgress) < const Duration(seconds: 1)) {
                    return;
                  }
                  lastProgress = now;
                  try {
                    await BackgroundTaskHostApi().updateProgress(taskId, completed, -1);
                  } catch (_) {
                    // Progress reporting must not fail a committed sync batch.
                  }
                },
        );
  },
  debugLabel: 'remote-sync',
  waitForCancellation: taskId != null,
);

Cancelable<void> _handleWsAssetUploadReadyV1Batch(List<dynamic> batchData) => runInIsolateGentle(
  computation: (ref) => ref.read(syncStreamServiceProvider).handleWsAssetUploadReadyV1Batch(batchData),
  debugLabel: 'websocket-batch',
);

Cancelable<void> _handleWsAssetUploadReadyV2Batch(List<dynamic> batchData) => runInIsolateGentle(
  computation: (ref) => ref.read(syncStreamServiceProvider).handleWsAssetUploadReadyV2Batch(batchData),
  debugLabel: 'websocket-batch',
);

Cancelable<void> _handleWsAssetEditReadyV1(dynamic data) => runInIsolateGentle(
  computation: (ref) => ref.read(syncStreamServiceProvider).handleWsAssetEditReadyV1(data),
  debugLabel: 'websocket-edit',
);

Cancelable<void> _handleWsAssetEditReadyV2(dynamic data) => runInIsolateGentle(
  computation: (ref) => ref.read(syncStreamServiceProvider).handleWsAssetEditReadyV2(data),
  debugLabel: 'websocket-edit',
);
