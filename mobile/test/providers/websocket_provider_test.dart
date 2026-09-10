import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/domain/utils/background_sync.dart';
import 'package:immich_mobile/providers/background_sync.provider.dart';
import 'package:immich_mobile/providers/websocket.provider.dart';
import 'package:mocktail/mocktail.dart';

class MockBackgroundSyncManager extends Mock implements BackgroundSyncManager {}

void main() {
  late MockBackgroundSyncManager mockBackgroundSync;
  late int syncRemoteCalls;
  late ProviderContainer container;
  late WebsocketNotifier notifier;

  setUp(() {
    mockBackgroundSync = MockBackgroundSyncManager();
    syncRemoteCalls = 0;
    when(() => mockBackgroundSync.syncRemote(enqueue: any(named: 'enqueue'))).thenAnswer((_) {
      syncRemoteCalls++;
      return Future.value(true);
    });

    container = ProviderContainer(overrides: [backgroundSyncProvider.overrideWithValue(mockBackgroundSync)]);
    addTearDown(container.dispose);
    notifier = container.read(websocketProvider.notifier);
  });

  group('WebsocketNotifier - requestRemoteSync', () {
    test('a single change triggers the sync immediately', () {
      fakeAsync((async) {
        notifier.requestRemoteSync();

        expect(syncRemoteCalls, 1, reason: 'the first event must fire immediately');
        async.elapse(const Duration(seconds: 6));
        expect(syncRemoteCalls, 1, reason: 'no trailing sync expected after a single event');
      });
    });

    test('a burst of changes coalesces into one immediate and one trailing sync', () {
      fakeAsync((async) {
        for (var i = 0; i < 5; i++) {
          notifier.requestRemoteSync();
        }

        // The first call fires immediately; the trailing window collapses the rest.
        expect(syncRemoteCalls, 1);

        async.elapse(const Duration(seconds: 6));
        expect(syncRemoteCalls, 2);

        // Staying quiet afterwards must not fire anything more.
        async.elapse(const Duration(seconds: 30));
        expect(syncRemoteCalls, 2);
      });
    });

    test('dispose drops a pending trailing sync', () {
      fakeAsync((async) {
        // A dedicated container so the manual dispose below is the only one.
        final localContainer = ProviderContainer(
          overrides: [backgroundSyncProvider.overrideWithValue(mockBackgroundSync)],
        );
        final localNotifier = localContainer.read(websocketProvider.notifier);

        localNotifier.requestRemoteSync();
        localNotifier.requestRemoteSync();

        // First fired immediately, second is still pending on the timer.
        expect(syncRemoteCalls, 1);

        localNotifier.dispose();
        async.elapse(const Duration(seconds: 30));
        expect(syncRemoteCalls, 1, reason: 'dispose must drop the pending trailing sync');
      });
    });
  });
}
