import 'dart:async';

import 'package:immich_mobile/platform/background_task_api.g.dart';
import 'package:logging/logging.dart';
import 'package:uuid/uuid.dart';
import 'package:worker_manager/worker_manager.dart';

/// Keeps user-started work alive while backgrounded. If the OS withdraws runtime,
/// attempts stop at their existing checkpoints and wait for the next resume.
class BackgroundTaskService extends BackgroundTaskFlutterApi {
  final BackgroundTaskHostApi _host;
  final _tasks = <String, BackgroundTask>{};
  final _log = Logger('BackgroundTaskService');
  bool _foreground = true;
  bool _disposed = false;
  int _lifecycleRevision = 0;

  BackgroundTaskService(this._host) {
    BackgroundTaskFlutterApi.setUp(this);
  }

  Cancelable<T?> execute<T>({
    required String title,
    required String description,
    required Cancelable<T?> Function(String taskId) factory,
    BackgroundTaskMode mode = BackgroundTaskMode.limited,
    void Function(BackgroundTask task)? onTaskCreated,
  }) {
    final cancellation = Completer<void>();
    final result = Completer<T?>();
    result.complete(
      run<T?>(
        title: title,
        description: description,
        mode: mode,
        cancelToken: cancellation,
        action: (task) {
          onTaskCreated?.call(task);
          return task.run((interruption) async {
            final worker = factory(task.id);
            var finished = false;
            unawaited(
              interruption.future.then((_) {
                if (!finished) {
                  worker.cancel();
                }
              }),
            );
            try {
              return await worker.future;
            } finally {
              finished = true;
            }
          });
        },
      ),
    );
    return Cancelable(completer: result, onCancel: () => cancellation.complete());
  }

  Future<T> run<T>({
    required String title,
    required String description,
    required Future<T> Function(BackgroundTask task) action,
    BackgroundTaskMode mode = BackgroundTaskMode.limited,
    Completer<void>? cancelToken,
  }) async {
    if (_disposed) {
      throw CanceledError();
    }
    final task = BackgroundTask._(this, const Uuid().v4(), title, description, mode);
    _tasks[task.id] = task;
    if (cancelToken != null) {
      if (cancelToken.isCompleted) {
        task._cancel();
      }
      unawaited(cancelToken.future.then((_) => task._cancel()));
    }
    try {
      await task._waitUntilReady();
      return await action(task);
    } finally {
      await task._finish();
      _tasks.remove(task.id);
    }
  }

  Future<void> onBackground() async {
    _lifecycleRevision++;
    _foreground = false;
    for (final task in _tasks.values.toList()) {
      if (!task._protected && task._starting == null) {
        task._interrupt();
      }
    }
  }

  Future<void> onForeground() async {
    final revision = ++_lifecycleRevision;
    // Reconcile native state before releasing suspended work: an expiration
    // callback may not have reached Dart before the process was suspended.
    for (final task in _tasks.values.toList()) {
      await task._starting;
      if (revision != _lifecycleRevision || _disposed) {
        return;
      }
      if (task._closed) {
        continue;
      }
      var active = false;
      try {
        active = await _host.isActive(task.id);
      } catch (error, stack) {
        _log.warning('Cannot check background task protection', error, stack);
      }
      if (revision != _lifecycleRevision || _disposed) {
        return;
      }
      if (!active) {
        task._interrupt();
      }
    }
    if (revision != _lifecycleRevision || _disposed) {
      return;
    }
    _foreground = true;
    for (final task in _tasks.values.toList()) {
      task._resume();
    }
  }

  @override
  Future<void> onExpired(String taskId) async {
    final task = _tasks[taskId];
    if (task == null) {
      return;
    }
    try {
      // Ignore a delayed callback for an earlier native attempt of this task.
      if (await _host.isActive(taskId)) {
        return;
      }
    } catch (_) {}
    _log.info('Background runtime expired for $taskId; waiting for foreground');
    task._interrupt();
    if (_foreground) {
      task._resume();
    }
  }

  void dispose() {
    _disposed = true;
    BackgroundTaskFlutterApi.setUp(null);
    for (final task in _tasks.values.toList()) {
      task._cancel();
      unawaited(task._finish());
    }
    _tasks.clear();
  }
}

class BackgroundTask {
  final BackgroundTaskService _service;
  final String id;
  final String _title;
  final String _description;
  BackgroundTaskMode _mode;
  final _attempts = <Completer<void>>{};
  Completer<void>? _resumeGate;
  Future<void>? _starting;
  bool _protected = false;
  bool _requested = false;
  bool _cancelled = false;
  bool _closed = false;
  DateTime? _lastProgress;

  BackgroundTask._(this._service, this.id, this._title, this._description, this._mode);

  Future<void> requestContinuedProcessing() async {
    if (_closed || _cancelled || _mode == BackgroundTaskMode.continued) {
      return;
    }
    _mode = BackgroundTaskMode.continued;
    await _starting;
    if (_closed || _cancelled || (!_service._foreground && !_protected)) {
      return;
    }
    await _start();
  }

  /// Retries only attempts interrupted by the OS. Ordinary failures and user
  /// cancellation retain the caller's existing error/cancellation behavior.
  /// The action must suppress completion callbacks when its token is completed.
  Future<T> run<T>(Future<T> Function(Completer<void> cancelToken) action) async {
    while (true) {
      await _waitUntilReady();
      final interruption = Completer<void>();
      _attempts.add(interruption);
      try {
        final result = await action(interruption);
        if (_cancelled) {
          throw CanceledError();
        }
        if (!interruption.isCompleted) {
          return result;
        }
      } catch (_) {
        if (_cancelled || !interruption.isCompleted) {
          rethrow;
        }
      } finally {
        _attempts.remove(interruption);
      }
    }
  }

  Future<void> _waitUntilReady() async {
    while (true) {
      if (_cancelled || _closed) {
        throw CanceledError();
      }
      if (!_service._foreground && !_protected) {
        _interrupt();
      }
      final gate = _resumeGate;
      if (gate != null) {
        await gate.future;
        continue;
      }
      if (_starting != null) {
        await _starting;
        continue;
      }
      if (!_requested) {
        await (_starting ??= _start()).whenComplete(() => _starting = null);
        continue;
      }
      return;
    }
  }

  Future<void> _start() async {
    _requested = true;
    try {
      _protected = await _service._host.start(id, _title, _description, _mode);
      if (!_protected) {
        _service._log.warning('Background runtime unavailable for $id; foreground only');
      }
    } catch (error, stack) {
      _service._log.warning('Cannot acquire background runtime; foreground only', error, stack);
    }
    if (_closed) {
      await _service._host.finish(id);
    }
  }

  void _interrupt() {
    if (_closed) {
      return;
    }
    _protected = false;
    _requested = false;
    _resumeGate ??= Completer<void>();
    for (final token in _attempts) {
      if (!token.isCompleted) {
        token.complete();
      }
    }
  }

  void _resume() {
    final gate = _resumeGate;
    _resumeGate = null;
    if (gate != null && !gate.isCompleted) {
      gate.complete();
    }
  }

  void _cancel() {
    if (_closed) {
      return;
    }
    _cancelled = true;
    _interrupt();
    _resume();
  }

  void progress(int completed, int total) {
    if (_closed || !_protected) {
      return;
    }
    final now = DateTime.now();
    if (completed != total && _lastProgress != null && now.difference(_lastProgress!) < const Duration(seconds: 1)) {
      return;
    }
    _lastProgress = now;
    unawaited(
      _service._host.updateProgress(id, completed, total).catchError((Object error, StackTrace stack) {
        _service._log.warning('Cannot update background progress', error, stack);
      }),
    );
  }

  Future<void> _finish() async {
    if (_closed) {
      return;
    }
    _closed = true;
    try {
      await _service._host.finish(id);
    } catch (error, stack) {
      _service._log.warning('Cannot release background runtime', error, stack);
    }
  }
}
