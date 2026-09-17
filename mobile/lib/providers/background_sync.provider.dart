import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/domain/utils/background_sync.dart';
import 'package:immich_mobile/providers/background_task.provider.dart';
import 'package:immich_mobile/providers/sync_status.provider.dart';

final backgroundSyncProvider = Provider<BackgroundSyncManager>((ref) {
  final syncStatusNotifier = ref.read(syncStatusProvider.notifier);

  final manager = BackgroundSyncManager(
    backgroundTaskService: ref.read(backgroundTaskServiceProvider),
    onRemoteSyncStart: () {
      syncStatusNotifier.startRemoteSync();
    },
    onRemoteSyncComplete: (isSuccess) {
      syncStatusNotifier.completeRemoteSync(success: isSuccess == true);
    },
    onRemoteSyncError: syncStatusNotifier.errorRemoteSync,
    onRemoteSyncCancel: syncStatusNotifier.cancelRemoteSync,
    onLocalSyncStart: syncStatusNotifier.startLocalSync,
    onLocalSyncComplete: syncStatusNotifier.completeLocalSync,
    onLocalSyncError: syncStatusNotifier.errorLocalSync,
    onCloudIdSyncStart: syncStatusNotifier.startCloudIdSync,
    onCloudIdSyncComplete: syncStatusNotifier.completeCloudIdSync,
    onCloudIdSyncError: syncStatusNotifier.errorCloudIdSync,
  );
  ref.onDispose(manager.cancel);
  return manager;
});
