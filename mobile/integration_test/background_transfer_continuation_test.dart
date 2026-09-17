import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:immich_mobile/domain/models/store.model.dart';
import 'package:immich_mobile/domain/services/background_task.service.dart';
import 'package:immich_mobile/domain/utils/background_sync.dart';
import 'package:immich_mobile/entities/store.entity.dart';
import 'package:immich_mobile/infrastructure/repositories/storage.repository.dart';
import 'package:immich_mobile/main.dart' as app;
import 'package:immich_mobile/platform/background_task_api.g.dart';
import 'package:immich_mobile/platform/native_sync_api.g.dart';
import 'package:immich_mobile/repositories/asset_media.repository.dart';
import 'package:immich_mobile/repositories/upload.repository.dart';
import 'package:immich_mobile/services/api.service.dart';
import 'package:immich_mobile/services/foreground_upload.service.dart';
import 'package:immich_mobile/utils/bootstrap.dart';
import 'package:immich_mobile/wm_executor.dart';
import 'package:integration_test/integration_test.dart';
import 'package:openapi/api.dart';
import 'package:path_provider/path_provider.dart';

import 'test_utils/fake_immich_server.dart';
import 'test_utils/recording_background_task_host.dart';

// Run alone on a simulator. At BACKGROUND_TRANSFER_READY, open Settings/Home.
// At BACKGROUND_TRANSFER_DONE, reopen this app. The test requires a real OS
// lifecycle transition and verifies both network directions finish while paused.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('metadata sync and manual upload finish while the app is backgrounded', (tester) async {
    final errorHandler = FlutterError.onError;
    try {
      await app.initApp();
    } finally {
      FlutterError.onError = errorHandler;
    }
    final (db, _) = await Bootstrap.initDomain();
    await workerManagerPatch.init(dynamicSpawning: true, isolatesCount: 2);
    final previousEndpoint = Store.tryGet(StoreKey.serverEndpoint);
    final previousDevice = Store.tryGet(StoreKey.deviceId);
    final remote = await FakeImmichServer.start();
    await ApiService().resolveAndSetEndpoint(remote.endpoint);
    await Store.put(StoreKey.deviceId, 'background-transfer-test');

    final host = RecordingBackgroundTaskHost();
    final service = BackgroundTaskService(host);
    final monitor = _LifecycleMonitor(service);
    WidgetsBinding.instance.addObserver(monitor);
    // PhotoManager clears iOS's temporary directory when a pool starts. Keep
    // this synthetic shared source with the app's durable files instead.
    final temp = await (await getApplicationSupportDirectory()).createTemp('background-transfer-');
    const size = 12 * 256 * 1024;
    final source = File('${temp.path}/upload.jpg')..writeAsBytesSync(List.filled(size, 42));
    final uploadServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    var uploaded = 0;
    var backgroundChunks = 0;
    final uploadStarted = Completer<void>();
    final requestErrors = <Object>[];
    Future<void> route(HttpRequest request) async {
      final body = await request.fold<List<int>>([], (bytes, chunk) => bytes..addAll(chunk));
      Object response;
      if (request.uri.path.endsWith('/server/config')) {
        response = {'checksumAlgorithm': 'md5-size', 'resumableUploadChunkBytes': 256 * 1024};
      } else if (request.uri.path.endsWith('/assets/bulk-upload-check')) {
        final payload = jsonDecode(utf8.decode(body)) as Map<String, dynamic>;
        response = {
          'results': [
            {'id': payload['assets'][0]['id'], 'action': 'accept'},
          ],
        };
      } else {
        if (!uploadStarted.isCompleted) {
          uploadStarted.complete();
        }
        if (request.method == 'PUT') {
          await monitor.paused.future;
          uploaded += body.length;
          if (monitor.inBackground) {
            backgroundChunks++;
          }
        }
        response = {
          'generation': 'background-test',
          'offset': uploaded,
          'size': size,
          'complete': uploaded == size,
          if (uploaded == size) 'asset_id': '11111111-1111-4111-8111-111111111111',
          if (uploaded == size) 'asset_status': 'created',
        };
      }
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(response));
      await request.response.close();
    }

    uploadServer.listen((request) => unawaited(route(request).catchError((Object error) => requestErrors.add(error))));

    final storage = StorageRepository();
    final uploads = ForegroundUploadService(
      UploadRepository(
        stateDirectory: temp,
        endpoint: 'http://127.0.0.1:${uploadServer.port}/api',
        headers: const {},
        registerDownloaderCallbacks: false,
      ),
      storage,
      AssetMediaRepository(NativeSyncApi(), storage),
      backgroundTaskService: service,
    );
    final manager = BackgroundSyncManager(backgroundTaskService: service);
    final uploadResults = <String>[];
    final uploadErrors = <String>[];
    var syncFinishedInBackground = false;
    var uploadFinishedInBackground = false;
    final diagnostics = Timer.periodic(const Duration(seconds: 3), (_) {
      debugPrint(
        'BACKGROUND_DIAGNOSTIC ${DateTime.now().toIso8601String()} '
        'paused=${monitor.inBackground} bytes=$uploaded chunks=$backgroundChunks '
        'acks=${remote.ackRequests} sync=$syncFinishedInBackground upload=$uploadFinishedInBackground',
      );
    });
    try {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Center(child: Text('Background transfer test'))),
        ),
      );
      // Let the native Activity/Scene reach resumed before requesting runtime.
      await tester.pumpAndSettle();
      final syncing = manager.syncRemote();
      final sync = syncing.then((success) {
        syncFinishedInBackground = monitor.inBackground;
        return success;
      });
      final stream = await remote.streamOpened.timeout(const Duration(seconds: 30));
      expect(host.modes, [BackgroundTaskMode.limited]);
      expect(identical(syncing, manager.syncRemote(userInitiated: true)), isTrue);
      await host.continuedStarted.future.timeout(const Duration(seconds: 10));
      expect(host.modes, [BackgroundTaskMode.limited, BackgroundTaskMode.continued]);
      final upload = uploads
          .uploadShareIntent(
            [source],
            onSuccess: (_, id) => uploadResults.add(id),
            onError: (_, error) => uploadErrors.add(error),
          )
          .then((_) => uploadFinishedInBackground = monitor.inBackground);
      await uploadStarted.future.timeout(const Duration(seconds: 30));
      expect(host.modes.last, BackgroundTaskMode.continued);
      debugPrint('BACKGROUND_TRANSFER_READY');
      await monitor.paused.future.timeout(const Duration(seconds: 60));
      for (var i = 0; i < 20; i++) {
        stream.send(
          type: SyncEntityType.userV1.toString(),
          data: SyncUserV1(
            id: 'background-transfer-$i',
            name: 'Background $i',
            email: 'background-$i@test.invalid',
            hasProfileImage: false,
            deletedAt: null,
            profileChangedAt: DateTime.utc(2026),
          ).toJson(),
          ack: 'background-transfer-$i',
        );
      }
      await stream.close();
      expect(await sync.timeout(const Duration(seconds: 30)), isTrue);
      await upload.timeout(const Duration(seconds: 30));
      expect(uploadErrors, isEmpty);
      expect(uploadResults, hasLength(1));
      expect(uploaded, size);
      expect(backgroundChunks, 12);
      expect(syncFinishedInBackground, isTrue);
      expect(uploadFinishedInBackground, isTrue);
      expect(remote.streamOpenCount, 1, reason: 'Normal backgrounding must not restart sync');
      expect(remote.ackRequests, greaterThan(0));
      expect(requestErrors, isEmpty);
      final rows = await db
          .customSelect("SELECT COUNT(*) AS count FROM user_entity WHERE id LIKE 'background-transfer-%'")
          .getSingle();
      expect(rows.read<int>('count'), 20);
      debugPrint('BACKGROUND_TRANSFER_DONE');
      await monitor.resumed.future.timeout(const Duration(seconds: 60));
    } finally {
      diagnostics.cancel();
      uploads.cancel();
      await manager.cancel();
      service.dispose();
      WidgetsBinding.instance.removeObserver(monitor);
      await remote.close();
      await uploadServer.close(force: true);
      await workerManagerPatch.dispose();
      await db.customStatement("DELETE FROM user_entity WHERE id LIKE 'background-transfer-%'");
      if (previousEndpoint == null) {
        await Store.delete(StoreKey.serverEndpoint);
      } else {
        await Store.put(StoreKey.serverEndpoint, previousEndpoint);
      }
      if (previousDevice == null) {
        await Store.delete(StoreKey.deviceId);
      } else {
        await Store.put(StoreKey.deviceId, previousDevice);
      }
      if (temp.existsSync()) {
        await temp.delete(recursive: true);
      }
    }
  }, timeout: const Timeout(Duration(minutes: 3)));
}

class _LifecycleMonitor with WidgetsBindingObserver {
  final BackgroundTaskService service;
  final paused = Completer<void>();
  final resumed = Completer<void>();
  bool inBackground = false;
  _LifecycleMonitor(this.service);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint('BACKGROUND_LIFECYCLE ${DateTime.now().toIso8601String()} $state');
    if (state == AppLifecycleState.paused) {
      inBackground = true;
      unawaited(service.onBackground());
      if (!paused.isCompleted) {
        paused.complete();
      }
    } else if (state == AppLifecycleState.resumed) {
      inBackground = false;
      unawaited(service.onForeground());
      if (paused.isCompleted && !resumed.isCompleted) {
        resumed.complete();
      }
    }
  }
}
