import 'dart:async';
import 'dart:collection';

enum RemoteImageRequestPriority { visible, retry }

final class RemoteImageRequestDeferredException implements Exception {
  const RemoteImageRequestDeferredException();

  @override
  String toString() => 'Remote image request was deferred by the bounded queue';
}

final class RemoteImageRetryBudget {
  RemoteImageRetryBudget(this.delays, {this.deferralDelay = const Duration(milliseconds: 100)});

  final List<Duration> delays;
  final Duration deferralDelay;
  var _failedRequests = 0;

  RemoteImageRequestPriority get priority =>
      _failedRequests == 0 ? RemoteImageRequestPriority.visible : RemoteImageRequestPriority.retry;

  Duration? nextFailureDelay({required bool retryable}) {
    if (!retryable || _failedRequests >= delays.length) {
      return null;
    }
    return delays[_failedRequests++];
  }
}

final class ScheduledRemoteImageRequest<T> {
  ScheduledRemoteImageRequest._(this._task);

  final _RemoteImageTask<T> _task;

  Future<T?> get value => _task.completer.future;

  void cancel() => _task.scheduler._cancel(_task);
}

final class RemoteImageRequestScheduler {
  static const defaultMaxConcurrent = 8;
  static const defaultMaxPending = 64;
  static const defaultStarvationThreshold = Duration(seconds: 2);

  RemoteImageRequestScheduler({
    this.maxConcurrent = defaultMaxConcurrent,
    this.maxPending = defaultMaxPending,
    this.starvationThreshold = defaultStarvationThreshold,
    DateTime Function()? now,
  }) : assert(maxConcurrent > 0),
       assert(maxPending > 0),
       _now = now ?? DateTime.now;

  final int maxConcurrent;
  final int maxPending;
  final Duration starvationThreshold;
  final DateTime Function() _now;

  final ListQueue<_RemoteImageTask<dynamic>> _visible = ListQueue();
  final ListQueue<_RemoteImageTask<dynamic>> _retries = ListQueue();
  var _active = 0;

  ScheduledRemoteImageRequest<T> schedule<T>({
    required RemoteImageRequestPriority priority,
    required Future<T> Function() operation,
    DateTime? enqueuedAt,
  }) {
    final task = _RemoteImageTask<T>(this, enqueuedAt ?? _now(), operation);
    if (_active < maxConcurrent && _pendingCount == 0) {
      _start(task);
      return ScheduledRemoteImageRequest<T>._(task);
    }

    if (_pendingCount >= maxPending) {
      if (priority == RemoteImageRequestPriority.retry) {
        task.completeDeferred();
        return ScheduledRemoteImageRequest<T>._(task);
      }
      final evicted = _retries.isNotEmpty ? _retries.removeFirst() : _visible.removeLast();
      evicted.completeDeferred();
    }

    // New viewport work is LIFO so a fast scroll does not wait behind stale rows.
    // Retries stay FIFO and lower priority so they cannot block newly visible images.
    switch (priority) {
      case RemoteImageRequestPriority.visible:
        _visible.addFirst(task);
      case RemoteImageRequestPriority.retry:
        _retries.addLast(task);
    }
    _drain();
    return ScheduledRemoteImageRequest<T>._(task);
  }

  int get _pendingCount => _visible.length + _retries.length;

  void _cancel(_RemoteImageTask<dynamic> task) {
    if (task.started || task.completer.isCompleted) {
      return;
    }
    if (_visible.remove(task) || _retries.remove(task)) {
      task.completer.complete(null);
    }
  }

  void _drain() {
    while (_active < maxConcurrent && _pendingCount > 0) {
      _start(_takeNext());
    }
  }

  _RemoteImageTask<dynamic> _takeNext() {
    final now = _now();
    _RemoteImageTask<dynamic>? oldestStarved;
    // Promote any request that has waited long enough, regardless of its queue,
    // so continuously arriving viewport work cannot starve an older live tile.
    for (final task in [..._visible, ..._retries]) {
      if (now.difference(task.enqueuedAt) < starvationThreshold) {
        continue;
      }
      if (oldestStarved == null || task.enqueuedAt.isBefore(oldestStarved.enqueuedAt)) {
        oldestStarved = task;
      }
    }
    if (oldestStarved != null) {
      _visible.remove(oldestStarved);
      _retries.remove(oldestStarved);
      return oldestStarved;
    }
    if (_visible.isNotEmpty) {
      return _visible.removeFirst();
    }
    return _retries.removeFirst();
  }

  void _start(_RemoteImageTask<dynamic> task) {
    task.started = true;
    _active++;
    unawaited(_run(task));
  }

  Future<void> _run(_RemoteImageTask<dynamic> task) async {
    try {
      final value = await task.operation();
      if (!task.completer.isCompleted) {
        task.completer.complete(value);
      }
    } catch (error, stackTrace) {
      if (!task.completer.isCompleted) {
        task.completer.completeError(error, stackTrace);
      }
    } finally {
      _active--;
      _drain();
    }
  }
}

final class _RemoteImageTask<T> {
  _RemoteImageTask(this.scheduler, this.enqueuedAt, this.operation);

  final RemoteImageRequestScheduler scheduler;
  final DateTime enqueuedAt;
  final Future<T> Function() operation;
  final Completer<T?> completer = Completer<T?>();
  var started = false;

  void completeDeferred() {
    if (!completer.isCompleted) {
      completer.completeError(const RemoteImageRequestDeferredException());
    }
  }
}
