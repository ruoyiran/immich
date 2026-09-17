import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/providers/sync_status.provider.dart';

void main() {
  late ProviderContainer container;
  late SyncStatusNotifier notifier;

  setUp(() {
    container = ProviderContainer();
    notifier = container.read(syncStatusProvider.notifier);
  });
  tearDown(() => container.dispose());

  test('an unsuccessful sync must not be shown as success', () {
    notifier.startRemoteSync();
    notifier.completeRemoteSync(success: false);
    expect(container.read(syncStatusProvider).remoteSyncStatus, SyncStatus.error);
  });

  test('retry and success clear a previous remote error', () {
    notifier.errorRemoteSync('offline');
    notifier.startRemoteSync();
    expect(container.read(syncStatusProvider).errorMessage, isNull);
    notifier.completeRemoteSync();
    expect(container.read(syncStatusProvider).remoteSyncStatus, SyncStatus.success);
    expect(container.read(syncStatusProvider).errorMessage, isNull);
  });

  test('cancellation leaves no failed remote status or stale error', () {
    notifier.errorRemoteSync('offline');
    notifier.cancelRemoteSync();
    expect(container.read(syncStatusProvider).remoteSyncStatus, SyncStatus.idle);
    expect(container.read(syncStatusProvider).errorMessage, isNull);
  });
}
