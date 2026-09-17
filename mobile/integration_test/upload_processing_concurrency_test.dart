import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:immich_mobile/domain/models/store.model.dart';
import 'package:immich_mobile/domain/services/background_task.service.dart';
import 'package:immich_mobile/domain/services/store.service.dart';
import 'package:immich_mobile/entities/store.entity.dart';
import 'package:immich_mobile/infrastructure/repositories/db.repository.dart';
import 'package:immich_mobile/infrastructure/repositories/network.repository.dart';
import 'package:immich_mobile/infrastructure/repositories/storage.repository.dart';
import 'package:immich_mobile/infrastructure/repositories/store.repository.dart';
import 'package:immich_mobile/platform/background_task_api.g.dart';
import 'package:immich_mobile/platform/native_sync_api.g.dart';
import 'package:immich_mobile/repositories/asset_media.repository.dart';
import 'package:immich_mobile/repositories/upload.repository.dart';
import 'package:immich_mobile/services/foreground_upload.service.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('processing files do not block transfers or appended batches', (tester) async {
    final database = Drift(DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true));
    await StoreService.init(storeRepository: DriftStoreRepository(database));
    await Store.put(StoreKey.deviceId, 'upload-processing-test');
    await NetworkRepository.init();
    final directory = await (await getApplicationSupportDirectory()).createTemp('upload-processing-');
    final files = List.generate(7, (index) {
      final extension = index.isEven ? 'jpg' : 'mp4';
      return File('${directory.path}/asset-$index.$extension')..writeAsBytesSync(List.filled(1024, index));
    });
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final transfersAccepted = Completer<void>();
    final processingFinished = Completer<void>();
    final firstTransfers = Completer<void>();
    final allTransferred = Completer<void>();
    final allProcessing = Completer<void>();
    final polledProcessing = <String>{};
    final sizes = <String, int>{};
    final offsets = <String, int>{};
    final received = <String>{};
    final requestErrors = <Object>[];
    var activeTransfers = 0;
    var peakTransfers = 0;
    var statusRequests = 0;

    Future<void> route(HttpRequest request) async {
      final body = await request.fold<List<int>>([], (bytes, chunk) => bytes..addAll(chunk));
      Object response;
      if (request.uri.path.endsWith('/server/config')) {
        response = {'checksumAlgorithm': 'md5-size'};
      } else if (request.uri.path.endsWith('/assets/bulk-upload-check')) {
        final payload = jsonDecode(utf8.decode(body)) as Map<String, dynamic>;
        response = {
          'results': [
            {'id': payload['assets'][0]['id'], 'action': 'accept'},
          ],
        };
      } else {
        expect(request.headers.value('X-Upload-Finalization'), 'queued-v1');
        late String uploadId;
        if (request.method == 'POST') {
          final payload = jsonDecode(utf8.decode(body)) as Map<String, dynamic>;
          uploadId = payload['upload_id'] as String;
          sizes[uploadId] = payload['size'] as int;
          offsets[uploadId] = 0;
        } else {
          uploadId = request.uri.pathSegments.last;
        }
        if (request.method == 'PUT') {
          activeTransfers++;
          if (activeTransfers > peakTransfers) {
            peakTransfers = activeTransfers;
          }
          received.add(uploadId);
          if (received.length == 3 && !firstTransfers.isCompleted) {
            firstTransfers.complete();
          }
          await transfersAccepted.future;
          offsets[uploadId] = body.length;
          activeTransfers--;
          if (received.length == 7 && !allTransferred.isCompleted) {
            allTransferred.complete();
          }
        }
        if (request.method == 'GET') {
          statusRequests++;
          if (!processingFinished.isCompleted) {
            polledProcessing.add(uploadId);
            if (polledProcessing.length == 7 && !allProcessing.isCompleted) {
              allProcessing.complete();
            }
          }
        }
        final complete = offsets[uploadId] == sizes[uploadId];
        final terminal = complete && processingFinished.isCompleted;
        response = {
          'generation': 'processing-test',
          'upload_id': uploadId,
          'offset': offsets[uploadId],
          'size': sizes[uploadId],
          'complete': complete,
          if (complete && !terminal) 'processing': true,
          if (terminal) 'asset_id': uploadId,
          if (terminal) 'asset_status': 'created',
        };
      }
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(response));
      await request.response.close();
    }

    server.listen((request) => unawaited(route(request).catchError((Object error) => requestErrors.add(error))));
    final background = BackgroundTaskService(BackgroundTaskHostApi());
    final storage = StorageRepository();
    final uploads = ForegroundUploadService(
      UploadRepository(
        stateDirectory: directory,
        endpoint: 'http://127.0.0.1:${server.port}/api',
        headers: const {},
        registerDownloaderCallbacks: false,
      ),
      storage,
      AssetMediaRepository(NativeSyncApi(), storage),
      backgroundTaskService: background,
    );
    final successes = <String>[];
    final errors = <String>[];
    final batches = <Future<void>>[];
    try {
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Text('Upload processing concurrency'))));
      await tester.pumpAndSettle();
      batches.add(
        uploads.uploadShareIntent(
          files.take(5).toList(),
          onSuccess: (_, id) => successes.add(id),
          onError: (_, error) => errors.add(error),
        ),
      );
      await firstTransfers.future.timeout(const Duration(seconds: 20));
      batches.add(
        uploads.uploadShareIntent(
          files.skip(5).toList(),
          onSuccess: (_, id) => successes.add(id),
          onError: (_, error) => errors.add(error),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(received, hasLength(3));
      transfersAccepted.complete();
      await allTransferred.future.timeout(const Duration(seconds: 20));
      await allProcessing.future.timeout(const Duration(seconds: 20));
      expect(successes, isEmpty);
      expect(peakTransfers, lessThanOrEqualTo(3));
      processingFinished.complete();
      await Future.wait(batches).timeout(
        const Duration(seconds: 20),
        onTimeout: () {
          throw StateError(
            'Transferred: ${received.length}, completed: ${successes.length}, status requests: $statusRequests, errors: $errors, server errors: $requestErrors',
          );
        },
      );
      expect(successes.toSet(), hasLength(7));
      expect(errors, isEmpty);
      expect(requestErrors, isEmpty);
      debugPrint('UPLOAD_PROCESSING_VERIFIED: 7 files, two batches, maximum 3 transfers');
    } finally {
      if (!transfersAccepted.isCompleted) {
        transfersAccepted.complete();
      }
      if (!processingFinished.isCompleted) {
        processingFinished.complete();
      }
      await uploads.cancelAndDrain();
      await Future.wait(batches);
      background.dispose();
      await server.close(force: true);
      await directory.delete(recursive: true);
      await database.close();
    }
  });
}
