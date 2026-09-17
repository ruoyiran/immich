import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:immich_mobile/domain/services/background_task.service.dart';
import 'package:immich_mobile/domain/utils/background_sync.dart';
import 'package:immich_mobile/platform/background_task_api.g.dart';
import 'package:worker_manager/worker_manager.dart';

import '../../mocks/background_task_host.mock.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeBackgroundTaskHost host;
  late BackgroundTaskService service;
  late BackgroundSyncManager manager;
  late List<Completer<bool?>> attempts;

  setUp(() {
    host = FakeBackgroundTaskHost();
    service = BackgroundTaskService(host);
    attempts = [];
    manager = BackgroundSyncManager(
      backgroundTaskService: service,
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
    );
  });
  tearDown(() async {
    await manager.cancel();
    service.dispose();
  });

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('automatic sync only requests limited background runtime', () async {
    final syncing = manager.syncRemote();
    await settle();
    expect(host.modes, [BackgroundTaskMode.limited]);
    attempts.single.complete(true);
    expect(await syncing, isTrue);
  });

  test('manual sync requests continued processing', () async {
    final syncing = manager.syncRemote(userInitiated: true);
    await settle();
    expect(host.modes, [BackgroundTaskMode.continued]);
    attempts.single.complete(true);
    expect(await syncing, isTrue);
  });

  test('manual sync upgrades automatic work without restarting its stream', () async {
    final automatic = manager.syncRemote();
    await settle();
    final manual = manager.syncRemote(userInitiated: true);
    unawaited(manager.syncRemote(userInitiated: true));
    await settle();
    expect(identical(automatic, manual), isTrue);
    expect(attempts, hasLength(1));
    expect(host.modes, [BackgroundTaskMode.limited, BackgroundTaskMode.continued]);
    expect(host.active, hasLength(1));
    attempts.single.complete(true);
    expect(await manual, isTrue);
  });

  test('manual intent survives a pending native start', () async {
    host.startResult = Completer<bool>();
    final automatic = manager.syncRemote();
    final manual = manager.syncRemote(userInitiated: true);
    host.startResult!.complete(true);
    await settle();
    expect(host.modes, [BackgroundTaskMode.limited, BackgroundTaskMode.continued]);
    expect(attempts, hasLength(1));
    attempts.single.complete(true);
    expect(await automatic, isTrue);
    expect(await manual, isTrue);
  });

  test('foreground recovery preserves manual intent across a failed attempt', () async {
    final syncing = manager.syncRemote(userInitiated: true);
    await settle();
    final resumed = manager.resumeRemoteSync(shouldContinue: () => true);
    attempts.first.complete(false);
    await settle();
    expect(attempts, hasLength(2));
    expect(host.modes, [BackgroundTaskMode.continued, BackgroundTaskMode.continued]);
    attempts.last.complete(true);
    expect(await syncing, isTrue);
    expect(await resumed, isTrue);
  });

  test('queued automatic work does not inherit completed manual intent', () async {
    final syncing = manager.syncRemote(userInitiated: true);
    await settle();
    unawaited(manager.syncRemote(enqueue: true));
    attempts.first.complete(true);
    expect(await syncing, isTrue);
    await settle();
    expect(host.modes, [BackgroundTaskMode.continued, BackgroundTaskMode.limited]);
    attempts.last.complete(true);
    await settle();
  });

  test('upgraded intent survives expiration without starting work in the background', () async {
    final syncing = manager.syncRemote();
    await settle();
    unawaited(manager.syncRemote(userInitiated: true));
    await settle();
    await service.onBackground();
    final taskId = host.active.single;
    host.active.clear();
    await service.onExpired(taskId);
    await settle();
    expect(attempts, hasLength(1));
    await service.onForeground();
    await settle();
    expect(host.modes, [BackgroundTaskMode.limited, BackgroundTaskMode.continued, BackgroundTaskMode.continued]);
    expect(attempts, hasLength(2));
    attempts.last.complete(true);
    expect(await syncing, isTrue);
  });

  test('cancelling a pending upgrade cannot create continued work after logout', () async {
    host.startResult = Completer<bool>();
    final syncing = manager.syncRemote();
    unawaited(manager.syncRemote(userInitiated: true));
    final cancellation = manager.cancel();
    host.startResult!.complete(true);
    await cancellation;
    expect(await syncing, isFalse);
    expect(host.modes, [BackgroundTaskMode.limited]);
    expect(host.active, isEmpty);
    expect(attempts, isEmpty);
  });
}
