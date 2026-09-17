import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:immich_mobile/domain/models/store.model.dart';
import 'package:immich_mobile/domain/services/background_task.service.dart';
import 'package:immich_mobile/domain/services/log.service.dart';
import 'package:immich_mobile/domain/utils/background_sync.dart';
import 'package:immich_mobile/entities/store.entity.dart';
import 'package:immich_mobile/main.dart' as app;
import 'package:immich_mobile/platform/background_task_api.g.dart';
import 'package:immich_mobile/services/api.service.dart';
import 'package:immich_mobile/utils/bootstrap.dart';
import 'package:immich_mobile/wm_executor.dart';
import 'package:integration_test/integration_test.dart';
import 'package:openapi/api.dart';
import 'package:path_provider/path_provider.dart';

import 'test_utils/fake_immich_server.dart';
import 'test_utils/recording_background_task_host.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets(
    'long background resume retries a stale connection and preserves committed data',
    (tester) async {
      final errorHandler = FlutterError.onError;
      try {
        await app.initApp();
      } finally {
        FlutterError.onError = errorHandler;
      }
      final (db, logDb) = await Bootstrap.initDomain();
      final backupDirectory = await (await getApplicationSupportDirectory()).createTemp('sync-resume-backup-');
      await db.customStatement('VACUUM INTO ?', ['${backupDirectory.path}/immich-before.sqlite']);
      final previousEndpoint = Store.tryGet(StoreKey.serverEndpoint);
      final previousDevice = Store.tryGet(StoreKey.deviceId);
      final previousMigrations = Store.tryGet(StoreKey.syncMigrationStatus);
      final initialLogId =
          (await logDb.customSelect('SELECT COALESCE(MAX(id), 0) AS last_id FROM logger_messages').getSingle())
              .read<int>('last_id');
      final prefix = 'resume-probe-${DateTime.now().microsecondsSinceEpoch}';
      final remote = await FakeImmichServer.start();
      await ApiService().resolveAndSetEndpoint(remote.endpoint);
      await Store.put(StoreKey.deviceId, prefix);
      await workerManagerPatch.init(dynamicSpawning: true, isolatesCount: 2);
      final host = RecordingBackgroundTaskHost();
      final service = _ObservedBackgroundTasks(host);
      final completions = <bool?>[];
      final errors = <String>[];
      final manager = BackgroundSyncManager(
        backgroundTaskService: service,
        onRemoteSyncComplete: completions.add,
        onRemoteSyncError: errors.add,
      );
      final monitor = _ResumeMonitor(service, manager);
      WidgetsBinding.instance.addObserver(monitor);

      Future<int> recordCount() async =>
          (await db.customSelect("SELECT COUNT(*) AS count FROM user_entity WHERE id LIKE '$prefix-%'").getSingle())
              .read<int>('count');

      void sendUsers(SyncStream stream, int start, int count) {
        for (var index = start; index < start + count; index++) {
          final id = '$prefix-$index';
          stream.send(
            type: SyncEntityType.userV1.toString(),
            data: SyncUserV1(
              id: id,
              name: 'Resume probe $index',
              email: '$id@test.invalid',
              hasProfileImage: false,
              deletedAt: null,
              profileChangedAt: DateTime.utc(2026),
            ).toJson(),
            ack: id,
          );
        }
      }

      Future<void> waitFor(bool Function(int count) predicate) async {
        final deadline = DateTime.now().add(const Duration(seconds: 20));
        while (!predicate(await recordCount())) {
          if (DateTime.now().isAfter(deadline)) {
            fail('Sync did not make progress; streams=${remote.streamOpenCount}, records=${await recordCount()}');
          }
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
      }

      try {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(body: Center(child: Text('Sync resume regression'))),
          ),
        );
        await tester.pumpAndSettle();
        final syncing = manager.syncRemote();
        final first = await remote.streamOpened.timeout(const Duration(seconds: 30));
        sendUsers(first, 0, 256);
        await waitFor((count) => count == 256);
        debugPrint('LONG_SYNC_READY records=256');
        await monitor.paused.future.timeout(const Duration(seconds: 60));
        await monitor.resumed.future.timeout(const Duration(minutes: 3));
        final backgroundDuration = monitor.resumedAt!.difference(monitor.pausedAt!);
        expect(backgroundDuration, greaterThanOrEqualTo(const Duration(seconds: 60)));

        late SyncStream activeStream;
        late int activeIndex;
        while (true) {
          activeIndex = remote.streamOpenCount;
          activeStream = await remote.streamOpenedNth(activeIndex);
          sendUsers(activeStream, 256, 5256);
          await waitFor((count) => count >= 5256 || remote.streamOpenCount > activeIndex);
          if (remote.streamOpenCount == activeIndex && await recordCount() >= 5256) {
            break;
          }
        }
        expect(errors, isEmpty);
        expect(completions, isEmpty);
        debugPrint(
          'LONG_SYNC_DISCONNECT streams=$activeIndex records=${await recordCount()} expirations=${service.expirations}',
        );
        activeStream.disconnect();
        final replacement = await remote.streamOpenedNth(activeIndex + 1).timeout(const Duration(seconds: 30));
        sendUsers(replacement, 256, 5257);
        await replacement.close();
        expect(await syncing.timeout(const Duration(seconds: 30)), isTrue);
        expect(await monitor.resumeSync!.timeout(const Duration(seconds: 5)), isTrue);
        expect(await recordCount(), 5513);
        expect(remote.streamOpenCount, activeIndex + 1);
        expect(host.modes, everyElement(BackgroundTaskMode.limited));
        expect(errors, isEmpty);
        expect(completions, [true]);
        await LogService.I.flush();
        final falseErrors = await logDb
            .customSelect(
              "SELECT COUNT(*) AS count FROM logger_messages WHERE id > $initialLogId AND level >= 6 "
              "AND (details LIKE '%abortTrigger%' OR details LIKE '%CanceledError%')",
            )
            .getSingle();
        expect(falseErrors.read<int>('count'), 0);
        debugPrint(
          'LONG_SYNC_VERIFIED backgroundMs=${backgroundDuration.inMilliseconds} '
          'expirations=${service.expirations} streams=${remote.streamOpenCount} records=5513',
        );
      } finally {
        await manager.cancel();
        service.dispose();
        WidgetsBinding.instance.removeObserver(monitor);
        await remote.close();
        await workerManagerPatch.dispose();
        await db.customStatement("DELETE FROM user_entity WHERE id LIKE '$prefix-%'");
        for (final entry in {
          StoreKey.serverEndpoint: previousEndpoint,
          StoreKey.deviceId: previousDevice,
          StoreKey.syncMigrationStatus: previousMigrations,
        }.entries) {
          if (entry.value == null) {
            await Store.delete(entry.key);
          } else {
            await Store.put(entry.key, entry.value!);
          }
        }
      }
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}

class _ObservedBackgroundTasks extends BackgroundTaskService {
  int expirations = 0;

  _ObservedBackgroundTasks(super.host);

  @override
  Future<void> onExpired(String taskId) async {
    expirations++;
    debugPrint('LONG_SYNC_EXPIRED count=$expirations');
    await super.onExpired(taskId);
  }
}

class _ResumeMonitor with WidgetsBindingObserver {
  final BackgroundTaskService service;
  final BackgroundSyncManager manager;
  final paused = Completer<void>();
  final resumed = Completer<void>();
  DateTime? pausedAt;
  DateTime? resumedAt;
  Future<bool>? resumeSync;
  bool inBackground = false;

  _ResumeMonitor(this.service, this.manager);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint('LONG_SYNC_LIFECYCLE ${DateTime.now().toIso8601String()} $state');
    if (state == AppLifecycleState.paused) {
      inBackground = true;
      pausedAt ??= DateTime.now();
      unawaited(service.onBackground());
      if (!paused.isCompleted) {
        paused.complete();
      }
    } else if (state == AppLifecycleState.resumed && paused.isCompleted) {
      inBackground = false;
      unawaited(_resume());
    }
  }

  Future<void> _resume() async {
    await service.onForeground();
    resumeSync = manager.resumeRemoteSync(shouldContinue: () => !inBackground);
    resumedAt ??= DateTime.now();
    if (!resumed.isCompleted) {
      resumed.complete();
    }
  }
}
