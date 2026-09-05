import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:immich_mobile/domain/utils/background_sync.dart';
import 'package:worker_manager/worker_manager.dart';

void main() {
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
