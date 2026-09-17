import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:immich_mobile/domain/utils/background_sync.dart';
import 'package:worker_manager/worker_manager.dart';

void main() {
  group('foreground resume', () {
    late BackgroundSyncManager manager;
    late List<Completer<bool?>> attempts;
    late List<String> events;
    var foreground = true;

    setUp(() {
      attempts = [];
      events = [];
      foreground = true;
      manager = BackgroundSyncManager(
        remoteSyncTaskFactory: () {
          final completion = Completer<bool?>();
          attempts.add(completion);
          return Cancelable(
            completer: completion,
            onCancel: () {
              if (!completion.isCompleted) {
                completion.completeError(CanceledError());
              }
            },
          );
        },
        onRemoteSyncStart: () => events.add('start'),
        onRemoteSyncComplete: (success) => events.add('complete:$success'),
        onRemoteSyncCancel: () => events.add('cancel'),
        onRemoteSyncError: (_) => events.add('error'),
      );
    });
    tearDown(() => manager.cancel());

    Future<bool> resume() => manager.resumeRemoteSync(shouldContinue: () => foreground);

    test('retries a failed existing sync and all callers await the replacement', () async {
      final first = manager.syncRemote();
      final resumed = resume();
      final duplicateResume = resume();
      attempts.first.complete(null);
      await Future<void>.delayed(Duration.zero);

      expect(attempts, hasLength(2));
      expect(events, ['start', 'start']);
      attempts.last.complete(true);
      expect(await first, isTrue);
      expect(await resumed, isTrue);
      expect(await duplicateResume, isTrue);
      expect(events, ['start', 'start', 'complete:true']);
    });

    test('preserves a healthy existing sync', () async {
      final first = manager.syncRemote();
      final resumed = resume();
      attempts.single.complete(true);
      expect(await first, isTrue);
      expect(await resumed, isTrue);
      expect(attempts, hasLength(1));
      expect(events, ['start', 'complete:true']);
    });

    test('retries an exception only once and reports the final failure', () async {
      final first = manager.syncRemote();
      final resumed = resume();
      attempts.first.completeError(StateError('stale connection'));
      await Future<void>.delayed(Duration.zero);
      expect(attempts, hasLength(2));
      attempts.last.completeError(StateError('still offline'));

      expect(await first, isFalse);
      expect(await resumed, isFalse);
      expect(attempts, hasLength(2));
      expect(events, ['start', 'start', 'error']);
    });

    test('does not restart after the app leaves the foreground again', () async {
      final first = manager.syncRemote();
      final resumed = resume();
      foreground = false;
      attempts.single.complete(false);
      expect(await first, isFalse);
      expect(await resumed, isFalse);
      expect(attempts, hasLength(1));
    });

    test('does not restart after logout cancels the manager', () async {
      final first = manager.syncRemote();
      final resumed = resume();
      await manager.cancel();
      expect(await first, isFalse);
      expect(await resumed, isFalse);
      expect(attempts, hasLength(1));
      expect(events, ['start']);
    });

    test('does not restart an explicitly cancelled task', () async {
      final first = manager.syncRemote();
      final resumed = resume();
      attempts.single.completeError(CanceledError());
      expect(await first, isFalse);
      expect(await resumed, isFalse);
      expect(attempts, hasLength(1));
      expect(events, ['start', 'cancel']);
    });

    test('does not retry an ordinary failure without a resume request', () async {
      final sync = manager.syncRemote();
      attempts.single.complete(false);
      expect(await sync, isFalse);
      expect(attempts, hasLength(1));
      expect(events, ['start', 'complete:false']);
    });

    test('does not treat a newly started sync as a stale task', () async {
      final resumed = resume();
      attempts.single.complete(false);
      expect(await resumed, isFalse);
      expect(attempts, hasLength(1));
    });

    test('does not start a resume sync after logout or another pause', () async {
      foreground = false;
      expect(await resume(), isFalse);
      expect(attempts, isEmpty);
      expect(events, isEmpty);
    });
  });

  test('cancelled stale remote task cannot clear the status of its replacement', () async {
    final first = Completer<bool?>();
    final second = Completer<bool?>();
    var invocation = 0;
    final events = <String>[];
    final manager = BackgroundSyncManager(
      remoteSyncTaskFactory: () {
        invocation++;
        final completer = invocation == 1 ? first : second;
        return Cancelable(
          completer: completer,
          onCancel: () => scheduleMicrotask(() => completer.completeError(CanceledError())),
        );
      },
      onRemoteSyncStart: () => events.add('start'),
      onRemoteSyncComplete: (_) => events.add('complete'),
      onRemoteSyncCancel: () => events.add('cancel'),
    );

    unawaited(manager.syncRemote());
    unawaited(manager.cancelResumeSyncs());
    unawaited(manager.syncRemote());
    await Future<void>.delayed(Duration.zero);

    expect(events, ['start', 'start']);

    second.complete(true);
    await Future<void>.delayed(Duration.zero);
    expect(events, ['start', 'start', 'complete']);
  });
}
