import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:immich_mobile/platform/native_sync_api.g.dart';
import 'package:immich_mobile/repositories/upload.repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('resumable upload adopts conflict generation and never resends acknowledged bytes', () async {
    final root = await Directory.systemTemp.createTemp('resumable-upload-test-');
    addTearDown(() => root.delete(recursive: true));
    final source = File('${root.path}/asset.jpg');
    await source.writeAsBytes(utf8.encode('abcde'));
    final checksum = base64Encode(md5.convert(utf8.encode('abcde')).bytes);
    final ranges = <String>[];
    var puts = 0;
    final client = _RecordingClient((request, body) async {
      if (request.method == 'POST') {
        final start = jsonDecode(utf8.decode(body)) as Map<String, dynamic>;
        expect(start['generation_capability'], 'required-v1');
        expect(start['md5'], md5.convert(utf8.encode('abcde')).toString());
        expect(start.containsKey('checksum'), isFalse);
        return _json(200, {'upload_id': 'asset-1', 'generation': 'gen-a', 'offset': 0, 'size': 5, 'complete': false});
      }
      puts++;
      expect(request.headers['content-md5'], base64Encode(md5.convert(body).bytes));
      ranges.add(request.headers['content-range']!);
      if (puts == 1) {
        expect(body, utf8.encode('abcde'));
        return _json(409, {'error': 'generation mismatch', 'generation': 'gen-b', 'offset': 2});
      }
      expect(request.headers['x-upload-generation'], 'gen-b');
      expect(body, utf8.encode('cde'));
      return _json(200, {
        'upload_id': 'asset-1',
        'generation': 'gen-b',
        'offset': 5,
        'size': 5,
        'complete': true,
        'asset_id': '11111111-1111-4111-8111-111111111111',
        'asset_status': 'created',
      });
    });
    final repository = UploadRepository(
      client: client,
      stateDirectory: root,
      endpoint: 'http://server/api',
      headers: const {},
      registerDownloaderCallbacks: false,
    );

    final result = await repository.uploadFile(
      file: source,
      originalFileName: 'asset.jpg',
      fields: const {
        'fileCreatedAt': '2026-08-12T01:02:03Z',
        'fileModifiedAt': '2026-08-12T01:02:03Z',
        'isFavorite': 'false',
      },
      cancelToken: null,
      logContext: 'test',
      checksum: checksum,
      uploadId: 'asset-1',
    );

    expect(result.remoteAssetId, '11111111-1111-4111-8111-111111111111');
    expect(result.assetStatus, 'created');
    expect(ranges, ['bytes 0-4/5', 'bytes 2-4/5']);
    final states = Directory('${root.path}/resumable-uploads');
    expect(states.listSync(), isEmpty);
  });

  test('bulk MD5+size duplicate skips bytes and retains Live Photo association metadata', () async {
    final root = await Directory.systemTemp.createTemp('md5-duplicate-test-');
    addTearDown(() => root.delete(recursive: true));
    final source = File('${root.path}/duplicate.jpg');
    await source.writeAsBytes(utf8.encode('duplicate'));
    final checksum = base64Encode(md5.convert(utf8.encode('duplicate')).bytes);
    var resumableRequests = 0;
    var metadataRequests = 0;
    final client = _RecordingClient((request, body) async {
      if (request.url.path.endsWith('/assets/bulk-upload-check')) {
        final payload = jsonDecode(utf8.decode(body)) as Map<String, dynamic>;
        expect(payload['algorithm'], 'md5');
        expect(payload['assets'], [
          {'id': 'local-duplicate', 'md5': md5.convert(utf8.encode('duplicate')).toString(), 'size': 9},
        ]);
        return _json(200, {
          'results': [
            {
              'id': 'local-duplicate',
              'action': 'reject',
              'reason': 'duplicate',
              'assetId': '22222222-2222-4222-8222-222222222222',
            },
          ],
        });
      }
      if (request.url.path.endsWith('/assets/bulk-metadata')) {
        metadataRequests++;
        final payload = jsonDecode(utf8.decode(body)) as Map<String, dynamic>;
        final assets = payload['assets'] as List<dynamic>;
        expect((assets.single as Map<String, dynamic>)['assetId'], '22222222-2222-4222-8222-222222222222');
        final metadata = (assets.single as Map<String, dynamic>)['metadata'] as Map<String, dynamic>;
        expect(metadata, contains('source_metadata'));
        expect(metadata['live_photo_video_id'], '33333333-3333-4333-8333-333333333333');
        return _json(200, {'updated': 1});
      }
      resumableRequests++;
      return _json(500, {'error': 'unexpected resumable request'});
    }, interceptBulkUploadCheck: false);
    final repository = UploadRepository(
      client: client,
      stateDirectory: root,
      endpoint: 'http://server/api',
      headers: const {},
      registerDownloaderCallbacks: false,
    );

    final result = await repository.uploadFile(
      file: source,
      originalFileName: 'duplicate.jpg',
      fields: const {
        'fileCreatedAt': '2026-08-12T01:02:03Z',
        'fileModifiedAt': '2026-08-12T01:02:03Z',
        'livePhotoVideoId': '33333333-3333-4333-8333-333333333333',
      },
      cancelToken: null,
      logContext: 'test',
      checksum: checksum,
      uploadId: 'local-duplicate',
    );

    expect(result.isSuccess, isTrue);
    expect(result.assetStatus, 'duplicate');
    expect(result.remoteAssetId, '22222222-2222-4222-8222-222222222222');
    expect(metadataRequests, 1);
    expect(resumableRequests, 0);
    expect(Directory('${root.path}/resumable-uploads').listSync(), isEmpty);
  });

  test('device tuple match links before hashing or opening media bytes', () async {
    var metadataRequests = 0;
    final checksum = _md5Checksum('existing');
    final modifiedAt = DateTime.utc(2026, 8, 17, 1, 2, 3, 456);
    final client = _RecordingClient((request, body) async {
      if (request.url.path.endsWith('/assets/bulk-device-check')) {
        final payload = jsonDecode(utf8.decode(body)) as Map<String, dynamic>;
        expect(payload['assets'], [
          {
            'id': 'local-asset',
            'deviceId': 'device-1',
            'localAssetId': 'platform-asset',
            'size': 8,
            'modifiedTime': modifiedAt.microsecondsSinceEpoch * 1000,
          },
        ]);
        return _json(200, {
          'results': [
            {
              'id': 'local-asset',
              'action': 'reject',
              'assetId': '44444444-4444-4444-8444-444444444444',
              'checksum': checksum,
              'isTrashed': false,
            },
          ],
        });
      }
      if (request.url.path.endsWith('/assets/bulk-metadata')) {
        metadataRequests++;
        return _json(200, {'updated': 1});
      }
      return _json(500, {'error': 'unexpected request'});
    });
    final repository = UploadRepository(
      client: client,
      endpoint: 'http://server/api',
      headers: const {},
      registerDownloaderCallbacks: false,
    );

    final result = await repository.preflightLocalAssetIdentity(
      assetId: 'local-asset',
      localAssetId: 'platform-asset',
      deviceId: 'device-1',
      size: 8,
      modifiedAt: modifiedAt,
      originalFileName: 'existing.jpg',
      fields: {
        'deviceAssetId': 'local-asset',
        'deviceId': 'device-1',
        'fileCreatedAt': '2026-08-17T01:02:02Z',
        'fileModifiedAt': modifiedAt.toIso8601String(),
      },
    );

    expect(result?.remoteAssetId, '44444444-4444-4444-8444-444444444444');
    expect(result?.assetStatus, 'duplicate');
    expect(metadataRequests, 1);
  });

  test('lease busy keeps resumable state for a later retry', () async {
    final root = await Directory.systemTemp.createTemp('resumable-busy-test-');
    addTearDown(() => root.delete(recursive: true));
    final source = File('${root.path}/asset.jpg');
    await source.writeAsBytes(utf8.encode('abc'));
    final checksum = _md5Checksum('abc');
    final client = _RecordingClient((request, _) async {
      if (request.method == 'POST') {
        return _json(200, {'upload_id': 'asset-2', 'generation': 'gen-a', 'offset': 0, 'size': 3, 'complete': false});
      }
      return _json(409, {'error': 'write lease busy'});
    });
    final repository = UploadRepository(
      client: client,
      stateDirectory: root,
      endpoint: 'http://server/api',
      headers: const {},
      registerDownloaderCallbacks: false,
    );

    final result = await repository.uploadFile(
      file: source,
      originalFileName: 'asset.jpg',
      fields: const {'fileCreatedAt': '2026-08-12T01:02:03Z', 'fileModifiedAt': '2026-08-12T01:02:03Z'},
      cancelToken: null,
      logContext: 'test',
      checksum: checksum,
      uploadId: 'asset-2',
    );

    expect(result.statusCode, 409);
    expect(Directory('${root.path}/resumable-uploads').listSync(), hasLength(1));
  });

  test('cancellation sends no future chunks and preserves resumable metadata', () async {
    final root = await Directory.systemTemp.createTemp('resumable-cancel-test-');
    addTearDown(() => root.delete(recursive: true));
    final source = File('${root.path}/asset.jpg');
    await source.writeAsBytes(utf8.encode('abc'));
    final checksum = _md5Checksum('abc');
    var puts = 0;
    final client = _RecordingClient((request, _) async {
      if (request.method == 'POST') {
        return _json(200, {'upload_id': 'asset-3', 'generation': 'gen-a', 'offset': 1, 'size': 3, 'complete': false});
      }
      puts++;
      return _json(500, {'error': 'unexpected'});
    });
    final repository = UploadRepository(
      client: client,
      stateDirectory: root,
      endpoint: 'http://server/api',
      headers: const {},
      registerDownloaderCallbacks: false,
    );
    final cancel = Completer<void>()..complete();

    final result = await repository.uploadFile(
      file: source,
      originalFileName: 'asset.jpg',
      fields: const {'fileCreatedAt': '2026-08-12T01:02:03Z', 'fileModifiedAt': '2026-08-12T01:02:03Z'},
      cancelToken: cancel,
      logContext: 'test',
      checksum: checksum,
      uploadId: 'asset-3',
    );

    expect(result.isCancelled, isTrue);
    expect(puts, 0);
    expect(Directory('${root.path}/resumable-uploads').listSync(), hasLength(1));
  });

  test('a fresh repository resumes from server offset after an exact PMLive rebuild', () async {
    final root = await Directory.systemTemp.createTemp('resumable-restart-test-');
    addTearDown(() => root.delete(recursive: true));
    final original = File('${root.path}/first.pmlive')..writeAsBytesSync(utf8.encode('abcde'));
    final rebuilt = File('${root.path}/rebuilt.pmlive')..writeAsBytesSync(utf8.encode('abcde'));
    String? stableUploadId;

    final firstClient = _RecordingClient((request, body) async {
      final start = jsonDecode(utf8.decode(body)) as Map<String, dynamic>;
      stableUploadId = start['upload_id'] as String;
      return _json(200, {
        'upload_id': stableUploadId!,
        'generation': 'gen-a',
        'offset': 2,
        'size': 5,
        'complete': false,
      });
    });
    final firstRepository = UploadRepository(
      client: firstClient,
      stateDirectory: root,
      endpoint: 'http://server/api',
      headers: const {},
      registerDownloaderCallbacks: false,
    );
    final cancelled = await firstRepository.uploadFile(
      file: original,
      originalFileName: 'asset.pmlive',
      fields: const {
        'fileCreatedAt': '2026-08-12T01:02:03Z',
        'fileModifiedAt': '2026-08-12T01:02:04Z',
        'isFavorite': 'false',
        'visibility': 'timeline',
      },
      cancelToken: (Completer<void>()..complete()),
      logContext: 'first process',
      checksum: _md5Checksum('logical-still'),
      uploadId: 'UUID/L0/001',
    );
    expect(cancelled.isCancelled, isTrue);
    expect(Directory('${root.path}/resumable-uploads').listSync(), hasLength(1));
    original.deleteSync();

    var puts = 0;
    final restartedClient = _RecordingClient((request, body) async {
      if (request.method == 'POST') {
        final start = jsonDecode(utf8.decode(body)) as Map<String, dynamic>;
        expect(start['upload_id'], stableUploadId);
        expect(start['original_name'], 'asset.pmlive');
        expect(start['is_favorite'], isFalse);
        expect(start['visibility'], 'timeline');
        final metadata = start['metadata'] as Map<String, dynamic>;
        expect(
          metadata['original_created_unix_nano'],
          DateTime.parse('2026-08-12T01:02:03Z').microsecondsSinceEpoch * 1000,
        );
        expect(
          metadata['original_modified_unix_nano'],
          DateTime.parse('2026-08-12T01:02:04Z').microsecondsSinceEpoch * 1000,
        );
        expect(metadata['original_accessed_unix_nano'], isA<int>());
        expect(metadata['source_metadata'], {
          'schema_version': 1,
          'source': 'mobile',
          'uploaded_original_name': 'asset.pmlive',
        });
        expect(metadata['is_live'], isTrue);
        expect(metadata['container'], 'pmlive-v1');
        return _json(200, {
          'upload_id': stableUploadId!,
          'generation': 'gen-b',
          'offset': 2,
          'size': 5,
          'complete': false,
        });
      }
      puts++;
      expect(request.headers['content-range'], 'bytes 2-4/5');
      expect(request.headers['x-upload-generation'], 'gen-b');
      expect(body, utf8.encode('cde'));
      return _json(200, {
        'upload_id': stableUploadId!,
        'generation': 'gen-b',
        'offset': 5,
        'size': 5,
        'complete': true,
        'asset_id': '11111111-1111-4111-8111-111111111111',
        'asset_status': 'created',
      });
    });
    final restartedRepository = UploadRepository(
      client: restartedClient,
      stateDirectory: root,
      endpoint: 'http://server/api',
      headers: const {},
      registerDownloaderCallbacks: false,
    );
    final result = await restartedRepository.uploadFile(
      file: rebuilt,
      originalFileName: 'changed-name.pmlive',
      fields: const {
        'fileCreatedAt': '2030-01-01T00:00:00Z',
        'fileModifiedAt': '2030-01-02T00:00:00Z',
        'isFavorite': 'true',
        'visibility': 'hidden',
      },
      cancelToken: null,
      logContext: 'restarted process',
      checksum: _md5Checksum('logical-still'),
      uploadId: 'UUID/L0/001',
    );

    expect(result.isSuccess, isTrue);
    expect(puts, 1);
    expect(Directory('${root.path}/resumable-uploads').listSync(), isEmpty);
  });

  test('cancelled PMLive rebuilt with same-size changed bytes starts a new server attempt', () async {
    final root = await Directory.systemTemp.createTemp('resumable-pmlive-changed-rebuild-test-');
    addTearDown(() => root.delete(recursive: true));
    final native = _FakeNativeSyncApi();
    final still = File('${root.path}/still.heic')..writeAsBytesSync(const [1]);
    final motion = File('${root.path}/motion.mov')..writeAsBytesSync(const [2]);
    String? oldUploadId;
    final firstRepository = UploadRepository(
      nativeSyncApi: native,
      client: _RecordingClient((request, body) async {
        final start = jsonDecode(utf8.decode(body)) as Map<String, dynamic>;
        oldUploadId = start['upload_id'] as String;
        return _json(200, {
          'upload_id': oldUploadId!,
          'generation': 'gen-old',
          'offset': 1,
          'size': 2,
          'complete': false,
        });
      }),
      stateDirectory: root,
      endpoint: 'https://server.example/api',
      headers: const {},
      registerDownloaderCallbacks: false,
    );
    final firstBundle = await firstRepository.createPMLiveBundle(
      assetId: 'UUID/L0/changed',
      checksum: _md5Checksum('logical-still'),
      stillFile: still,
      motionFile: motion,
      stillOriginalName: 'still.heic',
      motionOriginalName: 'motion.mov',
      createdAt: DateTime.utc(2026, 8, 12),
      modifiedAt: DateTime.utc(2026, 8, 12, 1),
    );
    final cancelled = await firstRepository.uploadFile(
      file: firstBundle,
      originalFileName: 'asset.pmlive',
      fields: const {'fileCreatedAt': '2026-08-12T00:00:00Z', 'fileModifiedAt': '2026-08-12T01:00:00Z'},
      cancelToken: Completer<void>()..complete(),
      logContext: 'first changed PMLive attempt',
      checksum: _md5Checksum('logical-still'),
      uploadId: 'UUID/L0/changed',
    );
    expect(cancelled.isCancelled, isTrue);
    expect(firstBundle.existsSync(), isFalse);

    motion.writeAsBytesSync(const [9]);
    final rebuilt = await firstRepository.createPMLiveBundle(
      assetId: 'UUID/L0/changed',
      checksum: _md5Checksum('logical-still'),
      stillFile: still,
      motionFile: motion,
      stillOriginalName: 'still.heic',
      motionOriginalName: 'motion.mov',
      createdAt: DateTime.utc(2026, 8, 12),
      modifiedAt: DateTime.utc(2026, 8, 12, 1),
    );
    expect(rebuilt.readAsBytesSync(), const [1, 9]);

    String? newUploadId;
    var puts = 0;
    final restartedRepository = UploadRepository(
      client: _RecordingClient((request, body) async {
        if (request.method == 'POST') {
          final start = jsonDecode(utf8.decode(body)) as Map<String, dynamic>;
          newUploadId = start['upload_id'] as String;
          expect(newUploadId, isNot(oldUploadId));
          expect(rebuilt.path.split('/').last, '$newUploadId.pmlive');
          return _json(200, {
            'upload_id': newUploadId!,
            'generation': 'gen-new',
            'offset': 0,
            'size': 2,
            'complete': false,
          });
        }
        puts++;
        expect(request.headers['content-range'], 'bytes 0-1/2');
        expect(request.headers['x-upload-generation'], 'gen-new');
        expect(body, const [1, 9]);
        final state =
            jsonDecode((Directory('${root.path}/resumable-uploads').listSync().single as File).readAsStringSync())
                as Map<String, dynamic>;
        expect(state['version'], 2);
        expect(state['pmlive_container_sha256'], sha256.convert(const [1, 9]).toString());
        return _json(200, {
          'upload_id': newUploadId!,
          'generation': 'gen-new',
          'offset': 2,
          'size': 2,
          'complete': true,
          'asset_id': '44444444-4444-4444-8444-444444444444',
          'asset_status': 'created',
        });
      }),
      stateDirectory: root,
      endpoint: 'https://server.example/api',
      headers: const {},
      registerDownloaderCallbacks: false,
    );
    final result = await restartedRepository.uploadFile(
      file: rebuilt,
      originalFileName: 'asset.pmlive',
      fields: const {'fileCreatedAt': '2026-08-12T00:00:00Z', 'fileModifiedAt': '2026-08-12T01:00:00Z'},
      cancelToken: null,
      logContext: 'changed PMLive retry',
      checksum: _md5Checksum('logical-still'),
      uploadId: 'UUID/L0/changed',
    );

    expect(result.isSuccess, isTrue);
    expect(puts, 1);
    expect(Directory('${root.path}/resumable-uploads').listSync(), isEmpty);
  });

  test('legacy PMLive state without a container digest never reuses its acknowledged offset', () async {
    final root = await Directory.systemTemp.createTemp('resumable-pmlive-v1-migration-test-');
    addTearDown(() => root.delete(recursive: true));
    const endpoint = 'https://server.example/api';
    const assetId = 'UUID/L0/legacy-live';
    final checksum = _md5Checksum('logical-still');
    final logicalUploadId = _logicalUploadId(endpoint, assetId, checksum);
    final oldSource = File('${root.path}/old.pmlive')..writeAsBytesSync(const [1, 2]);
    await _writeLegacyState(
      root,
      logicalUploadId,
      sourcePath: oldSource.path,
      originalName: 'asset.pmlive',
      checksum: checksum,
      size: 2,
      metadata: const {'is_live': true, 'container': 'pmlive-v1'},
      generation: 'gen-old',
      offset: 1,
    );
    final rebuilt = File('${root.path}/rebuilt.pmlive')..writeAsBytesSync(const [1, 9]);
    String? newUploadId;
    var puts = 0;
    final repository = UploadRepository(
      client: _RecordingClient((request, body) async {
        if (request.method == 'POST') {
          final start = jsonDecode(utf8.decode(body)) as Map<String, dynamic>;
          newUploadId = start['upload_id'] as String;
          expect(newUploadId, isNot(logicalUploadId));
          return _json(200, {
            'upload_id': newUploadId!,
            'generation': 'gen-new',
            'offset': 0,
            'size': 2,
            'complete': false,
          });
        }
        puts++;
        expect(request.headers['content-range'], 'bytes 0-1/2');
        expect(body, const [1, 9]);
        final state =
            jsonDecode((Directory('${root.path}/resumable-uploads').listSync().single as File).readAsStringSync())
                as Map<String, dynamic>;
        expect(state['version'], 2);
        expect(state['logical_upload_id'], logicalUploadId);
        expect(state['pmlive_container_sha256'], sha256.convert(const [1, 9]).toString());
        return _json(200, {
          'upload_id': newUploadId!,
          'generation': 'gen-new',
          'offset': 2,
          'size': 2,
          'complete': true,
          'asset_id': '55555555-5555-4555-8555-555555555555',
          'asset_status': 'created',
        });
      }),
      stateDirectory: root,
      endpoint: endpoint,
      headers: const {},
      registerDownloaderCallbacks: false,
    );

    final result = await repository.uploadFile(
      file: rebuilt,
      originalFileName: 'asset.pmlive',
      fields: const {'fileCreatedAt': '2026-08-12T00:00:00Z', 'fileModifiedAt': '2026-08-12T01:00:00Z'},
      cancelToken: null,
      logContext: 'legacy PMLive migration',
      checksum: checksum,
      uploadId: assetId,
    );

    expect(result.isSuccess, isTrue);
    expect(puts, 1);
    expect(Directory('${root.path}/resumable-uploads').listSync(), isEmpty);
  });

  test('legacy PMLive state still supports response-loss terminal preflight', () async {
    final root = await Directory.systemTemp.createTemp('resumable-pmlive-v1-terminal-test-');
    addTearDown(() => root.delete(recursive: true));
    const endpoint = 'https://server.example/api';
    const assetId = 'UUID/L0/legacy-terminal';
    final checksum = _md5Checksum('logical-still');
    final logicalUploadId = _logicalUploadId(endpoint, assetId, checksum);
    final attempts = Directory('${root.path}/pmlive-upload-attempts')..createSync(recursive: true);
    final artifact = File('${attempts.path}/$logicalUploadId.pmlive')..writeAsBytesSync(const [1, 2]);
    await _writeLegacyState(
      root,
      logicalUploadId,
      sourcePath: artifact.path,
      originalName: 'asset.pmlive',
      checksum: checksum,
      size: 2,
      metadata: const {'is_live': true, 'container': 'pmlive-v1'},
      generation: 'gen-old',
      offset: 2,
    );
    final repository = UploadRepository(
      client: _RecordingClient((request, body) async {
        expect(request.method, 'POST');
        final start = jsonDecode(utf8.decode(body)) as Map<String, dynamic>;
        expect(start['upload_id'], logicalUploadId);
        return _json(200, {
          'upload_id': logicalUploadId,
          'generation': 'gen-old',
          'offset': 2,
          'size': 2,
          'complete': true,
          'asset_id': '66666666-6666-4666-8666-666666666666',
          'asset_status': 'duplicate',
        });
      }),
      stateDirectory: root,
      endpoint: endpoint,
      headers: const {},
      registerDownloaderCallbacks: false,
    );

    final result = await repository.preflightResumableTerminal(checksum: checksum, uploadId: assetId);

    expect(result?.isSuccess, isTrue);
    expect(result?.assetStatus, 'duplicate');
    expect(artifact.existsSync(), isFalse);
    expect(Directory('${root.path}/resumable-uploads').listSync(), isEmpty);
  });

  test('legacy normal upload state migrates to v2 without changing its upload identity', () async {
    final root = await Directory.systemTemp.createTemp('resumable-normal-v1-migration-test-');
    addTearDown(() => root.delete(recursive: true));
    const endpoint = 'https://server.example/api';
    const assetId = 'legacy-normal';
    final source = File('${root.path}/asset.jpg')..writeAsBytesSync(utf8.encode('abcde'));
    final checksum = _md5Checksum('abcde');
    final logicalUploadId = _logicalUploadId(endpoint, assetId, checksum);
    await _writeLegacyState(
      root,
      logicalUploadId,
      sourcePath: source.path,
      originalName: 'asset.jpg',
      checksum: checksum,
      size: 5,
      metadata: const {},
      generation: 'gen-old',
      offset: 2,
    );
    final repository = UploadRepository(
      client: _RecordingClient((request, body) async {
        if (request.method == 'POST') {
          final start = jsonDecode(utf8.decode(body)) as Map<String, dynamic>;
          expect(start['upload_id'], logicalUploadId);
          return _json(200, {
            'upload_id': logicalUploadId,
            'generation': 'gen-new',
            'offset': 2,
            'size': 5,
            'complete': false,
          });
        }
        expect(request.headers['content-range'], 'bytes 2-4/5');
        expect(body, utf8.encode('cde'));
        final state =
            jsonDecode((Directory('${root.path}/resumable-uploads').listSync().single as File).readAsStringSync())
                as Map<String, dynamic>;
        expect(state['version'], 2);
        expect(state['logical_upload_id'], logicalUploadId);
        expect(state.containsKey('pmlive_container_sha256'), isFalse);
        return _json(200, {
          'upload_id': logicalUploadId,
          'generation': 'gen-new',
          'offset': 5,
          'size': 5,
          'complete': true,
          'asset_id': '77777777-7777-4777-8777-777777777777',
          'asset_status': 'created',
        });
      }),
      stateDirectory: root,
      endpoint: endpoint,
      headers: const {},
      registerDownloaderCallbacks: false,
    );

    final result = await repository.uploadFile(
      file: source,
      originalFileName: 'asset.jpg',
      fields: const {'fileCreatedAt': '2026-08-12T00:00:00Z', 'fileModifiedAt': '2026-08-12T01:00:00Z'},
      cancelToken: null,
      logContext: 'legacy normal migration',
      checksum: checksum,
      uploadId: assetId,
    );

    expect(result.isSuccess, isTrue);
  });

  test('PMLive source is fully rehashed after querying a nonzero server offset', () async {
    final root = await Directory.systemTemp.createTemp('resumable-pmlive-post-query-rehash-test-');
    addTearDown(() => root.delete(recursive: true));
    final source = File('${root.path}/asset.pmlive')..writeAsBytesSync(utf8.encode('abcde'));
    var puts = 0;
    final repository = UploadRepository(
      client: _RecordingClient((request, body) async {
        if (request.method == 'POST') {
          source.writeAsBytesSync(utf8.encode('vwxyz'));
          return _json(200, {
            'upload_id': (jsonDecode(utf8.decode(body)) as Map<String, dynamic>)['upload_id'],
            'generation': 'gen-a',
            'offset': 2,
            'size': 5,
            'complete': false,
          });
        }
        puts++;
        return _json(500, {'error': 'changed bytes must not be uploaded'});
      }),
      stateDirectory: root,
      endpoint: 'https://server.example/api',
      headers: const {},
      registerDownloaderCallbacks: false,
    );

    final result = await repository.uploadFile(
      file: source,
      originalFileName: 'asset.pmlive',
      fields: const {'fileCreatedAt': '2026-08-12T00:00:00Z', 'fileModifiedAt': '2026-08-12T01:00:00Z'},
      cancelToken: null,
      logContext: 'post query mutation',
      checksum: _md5Checksum('logical-still'),
      uploadId: 'UUID/L0/post-query',
    );

    expect(result.isSuccess, isFalse);
    expect(result.errorMessage, contains('changed'));
    expect(puts, 0);
  });

  test('normal restart queries server before rebinding a missing iOS temp from verified content', () async {
    final root = await Directory.systemTemp.createTemp('resumable-normal-rebind-test-');
    addTearDown(() => root.delete(recursive: true));
    final original = File('${root.path}/ios-temp-first.jpg')..writeAsBytesSync(utf8.encode('abcde'));
    final checksum = _md5Checksum('abcde');
    String? stableUploadId;
    final first = UploadRepository(
      client: _RecordingClient((request, body) async {
        final start = jsonDecode(utf8.decode(body)) as Map<String, dynamic>;
        stableUploadId = start['upload_id'] as String;
        return _json(200, {
          'upload_id': stableUploadId!,
          'generation': 'gen-a',
          'offset': 2,
          'size': 5,
          'complete': false,
        });
      }),
      stateDirectory: root,
      endpoint: 'http://server/api',
      headers: const {},
      registerDownloaderCallbacks: false,
    );
    final cancelled = await first.uploadFile(
      file: original,
      originalFileName: 'canonical.jpg',
      fields: const {
        'fileCreatedAt': '2026-08-12T01:02:03Z',
        'fileModifiedAt': '2026-08-12T01:02:04Z',
        'isFavorite': 'false',
        'visibility': 'timeline',
      },
      cancelToken: Completer<void>()..complete(),
      logContext: 'first iOS process',
      checksum: checksum,
      uploadId: 'UUID/L0/001',
    );
    expect(cancelled.isCancelled, isTrue);
    original.deleteSync();
    final rebound = File('${root.path}/ios-temp-recreated.jpg')..writeAsBytesSync(utf8.encode('abcde'));
    var postObservedBeforeSourceValidation = false;
    final restarted = UploadRepository(
      client: _RecordingClient((request, body) async {
        if (request.method == 'POST') {
          postObservedBeforeSourceValidation = true;
          final start = jsonDecode(utf8.decode(body)) as Map<String, dynamic>;
          expect(start['upload_id'], stableUploadId);
          expect(start['original_name'], 'canonical.jpg');
          expect(start['is_favorite'], isFalse);
          expect(start['visibility'], 'timeline');
          return _json(200, {
            'upload_id': stableUploadId!,
            'generation': 'gen-b',
            'offset': 2,
            'size': 5,
            'complete': false,
          });
        }
        expect(postObservedBeforeSourceValidation, isTrue);
        expect(body, utf8.encode('cde'));
        final state =
            jsonDecode((Directory('${root.path}/resumable-uploads').listSync().single as File).readAsStringSync())
                as Map<String, dynamic>;
        expect(state['source_path'], rebound.path);
        expect(state['original_name'], 'canonical.jpg');
        return _json(200, {
          'upload_id': stableUploadId!,
          'generation': 'gen-b',
          'offset': 5,
          'size': 5,
          'complete': true,
          'asset_id': '11111111-1111-4111-8111-111111111111',
          'asset_status': 'created',
        });
      }),
      stateDirectory: root,
      endpoint: 'http://server/api',
      headers: const {},
      registerDownloaderCallbacks: false,
    );
    final result = await restarted.uploadFile(
      file: rebound,
      originalFileName: 'changed.jpg',
      fields: const {
        'fileCreatedAt': '2030-01-01T00:00:00Z',
        'fileModifiedAt': '2030-01-02T00:00:00Z',
        'isFavorite': 'true',
        'visibility': 'hidden',
      },
      cancelToken: null,
      logContext: 'restarted iOS process',
      checksum: checksum,
      uploadId: 'UUID/L0/001',
    );
    expect(result.isSuccess, isTrue);
  });

  test('server terminal result succeeds after restart even when the old normal temp is gone', () async {
    final root = await Directory.systemTemp.createTemp('resumable-normal-terminal-test-');
    addTearDown(() => root.delete(recursive: true));
    final original = File('${root.path}/first.jpg')..writeAsBytesSync(utf8.encode('abc'));
    final checksum = _md5Checksum('abc');
    final first = UploadRepository(
      client: _RecordingClient(
        (request, body) async => _json(200, {
          'upload_id': (jsonDecode(utf8.decode(body)) as Map<String, dynamic>)['upload_id'],
          'generation': 'gen-a',
          'offset': 1,
          'size': 3,
          'complete': false,
        }),
      ),
      stateDirectory: root,
      endpoint: 'http://server/api',
      headers: const {},
      registerDownloaderCallbacks: false,
    );
    await first.uploadFile(
      file: original,
      originalFileName: 'asset.jpg',
      fields: const {'fileCreatedAt': '2026-08-12T01:02:03Z', 'fileModifiedAt': '2026-08-12T01:02:03Z'},
      cancelToken: Completer<void>()..complete(),
      logContext: 'first',
      checksum: checksum,
      uploadId: 'asset-terminal',
    );
    original.deleteSync();
    final missingCandidate = File('${root.path}/also-missing.jpg');
    final restarted = UploadRepository(
      client: _RecordingClient(
        (request, body) async => _json(200, {
          'upload_id': (jsonDecode(utf8.decode(body)) as Map<String, dynamic>)['upload_id'],
          'generation': 'gen-a',
          'offset': 3,
          'size': 3,
          'complete': true,
          'asset_id': '22222222-2222-4222-8222-222222222222',
          'asset_status': 'duplicate',
        }),
      ),
      stateDirectory: root,
      endpoint: 'http://server/api',
      headers: const {},
      registerDownloaderCallbacks: false,
    );
    final result = await restarted.uploadFile(
      file: missingCandidate,
      originalFileName: 'changed.jpg',
      fields: const {'fileCreatedAt': '2030-01-01T00:00:00Z', 'fileModifiedAt': '2030-01-01T00:00:00Z'},
      cancelToken: null,
      logContext: 'restart',
      checksum: checksum,
      uploadId: 'asset-terminal',
    );
    expect(result.isSuccess, isTrue);
  });

  test('normal restart rejects same-size changed content and preserves the canonical source binding', () async {
    final root = await Directory.systemTemp.createTemp('resumable-normal-rebind-reject-test-');
    addTearDown(() => root.delete(recursive: true));
    final original = File('${root.path}/first.jpg')..writeAsBytesSync(utf8.encode('abcde'));
    final checksum = _md5Checksum('abcde');
    final first = UploadRepository(
      client: _RecordingClient(
        (request, body) async => _json(200, {
          'upload_id': (jsonDecode(utf8.decode(body)) as Map<String, dynamic>)['upload_id'],
          'generation': 'gen-a',
          'offset': 2,
          'size': 5,
          'complete': false,
        }),
      ),
      stateDirectory: root,
      endpoint: 'http://server/api',
      headers: const {},
      registerDownloaderCallbacks: false,
    );
    await first.uploadFile(
      file: original,
      originalFileName: 'canonical.jpg',
      fields: const {'fileCreatedAt': '2026-08-12T01:02:03Z', 'fileModifiedAt': '2026-08-12T01:02:03Z'},
      cancelToken: Completer<void>()..complete(),
      logContext: 'first',
      checksum: checksum,
      uploadId: 'asset-reject',
    );
    final originalPath = original.path;
    original.deleteSync();
    final changed = File('${root.path}/changed.jpg')..writeAsBytesSync(utf8.encode('vwxyz'));
    var posts = 0;
    var puts = 0;
    final restarted = UploadRepository(
      client: _RecordingClient((request, body) async {
        if (request.method == 'POST') {
          posts++;
          return _json(200, {
            'upload_id': (jsonDecode(utf8.decode(body)) as Map<String, dynamic>)['upload_id'],
            'generation': 'gen-b',
            'offset': 2,
            'size': 5,
            'complete': false,
          });
        }
        puts++;
        return _json(500, {'error': 'must not upload changed bytes'});
      }),
      stateDirectory: root,
      endpoint: 'http://server/api',
      headers: const {},
      registerDownloaderCallbacks: false,
    );
    final result = await restarted.uploadFile(
      file: changed,
      originalFileName: 'changed.jpg',
      fields: const {'fileCreatedAt': '2030-01-01T00:00:00Z', 'fileModifiedAt': '2030-01-01T00:00:00Z'},
      cancelToken: null,
      logContext: 'restart',
      checksum: checksum,
      uploadId: 'asset-reject',
    );
    expect(result.isSuccess, isFalse);
    expect(posts, 1);
    expect(puts, 0);
    final state =
        jsonDecode((Directory('${root.path}/resumable-uploads').listSync().single as File).readAsStringSync())
            as Map<String, dynamic>;
    expect(state['source_path'], originalPath);
    expect(state['original_name'], 'canonical.jpg');
  });

  test('persisted same-path normal source is fully rehashed before another PUT', () async {
    final root = await Directory.systemTemp.createTemp('resumable-same-path-rehash-test-');
    addTearDown(() => root.delete(recursive: true));
    final original = File('${root.path}/same-path.jpg')..writeAsBytesSync(const [1, 2, 3, 4]);
    final checksum = base64Encode(md5.convert(const [1, 2, 3, 4]).bytes);
    var posts = 0;
    var puts = 0;
    final client = _RecordingClient((request, body) async {
      if (request.method == 'POST') {
        posts++;
        return _json(200, {
          'upload_id': (jsonDecode(utf8.decode(body)) as Map<String, dynamic>)['upload_id'],
          'generation': 'gen-a',
          'offset': 0,
          'size': 4,
          'complete': false,
        });
      }
      puts++;
      return _json(500, {'message': 'response lost'});
    });
    final repository = UploadRepository(
      client: client,
      stateDirectory: root,
      endpoint: 'https://server.example/api',
      headers: const {},
      registerDownloaderCallbacks: false,
    );
    final first = await repository.uploadFile(
      file: original,
      originalFileName: 'same-path.jpg',
      fields: const {'fileCreatedAt': '2026-08-12T01:02:03Z', 'fileModifiedAt': '2026-08-12T01:02:03Z'},
      cancelToken: null,
      logContext: 'first same path',
      checksum: checksum,
      uploadId: 'same-path-asset',
    );
    expect(first.isSuccess, isFalse);
    expect(posts, 1);
    expect(puts, 1);

    original.writeAsBytesSync(const [4, 3, 2, 1]);
    final second = await repository.uploadFile(
      file: original,
      originalFileName: 'same-path.jpg',
      fields: const {'fileCreatedAt': '2030-01-01T00:00:00Z', 'fileModifiedAt': '2030-01-01T00:00:00Z'},
      cancelToken: null,
      logContext: 'second same path',
      checksum: checksum,
      uploadId: 'same-path-asset',
    );
    expect(second.isSuccess, isFalse);
    expect(second.errorMessage, contains('checksum'));
    expect(posts, 2);
    expect(puts, 1);
  });

  test('cancelled PMLive removes only the exact owned regular bundle and retains resumable state', () async {
    final root = await Directory.systemTemp.createTemp('resumable-pmlive-cancel-cleanup-test-');
    addTearDown(() => root.delete(recursive: true));
    final native = _FakeNativeSyncApi();
    final repository = UploadRepository(
      nativeSyncApi: native,
      client: _RecordingClient(
        (request, body) async => _json(200, {
          'upload_id': (jsonDecode(utf8.decode(body)) as Map<String, dynamic>)['upload_id'],
          'generation': 'gen-a',
          'offset': 1,
          'size': 2,
          'complete': false,
        }),
      ),
      stateDirectory: root,
      endpoint: 'https://server.example/api',
      headers: const {},
      registerDownloaderCallbacks: false,
    );
    final still = File('${root.path}/still.heic')..writeAsBytesSync(const [1]);
    final motion = File('${root.path}/motion.mov')..writeAsBytesSync(const [2]);
    final bundle = await repository.createPMLiveBundle(
      assetId: 'UUID/L0/001',
      checksum: _md5Checksum('logical'),
      stillFile: still,
      motionFile: motion,
      stillOriginalName: 'still.heic',
      motionOriginalName: 'motion.mov',
      createdAt: DateTime.utc(2026, 8, 12),
      modifiedAt: DateTime.utc(2026, 8, 12, 1),
    );
    final outside = File('${root.path}/outside.pmlive')..writeAsBytesSync(const [9]);
    final result = await repository.uploadFile(
      file: bundle,
      originalFileName: 'asset.pmlive',
      fields: const {'fileCreatedAt': '2026-08-12T01:02:03Z', 'fileModifiedAt': '2026-08-12T01:02:03Z'},
      cancelToken: Completer<void>()..complete(),
      logContext: 'cancel pmlive',
      checksum: _md5Checksum('logical'),
      uploadId: 'UUID/L0/001',
    );
    expect(result.isCancelled, isTrue);
    expect(bundle.existsSync(), isFalse);
    expect(outside.existsSync(), isTrue);
    expect(Directory('${root.path}/resumable-uploads').listSync(), hasLength(1));

    final rebuilt = await repository.createPMLiveBundle(
      assetId: 'UUID/L0/001',
      checksum: _md5Checksum('logical'),
      stillFile: still,
      motionFile: motion,
      stillOriginalName: 'changed.heic',
      motionOriginalName: 'changed.mov',
      createdAt: DateTime.utc(2030),
      modifiedAt: DateTime.utc(2031),
    );
    expect(rebuilt.path, bundle.path);
    expect(rebuilt.existsSync(), isTrue);
    final restarted = UploadRepository(
      client: _RecordingClient(
        (request, body) async => _json(200, {
          'upload_id': (jsonDecode(utf8.decode(body)) as Map<String, dynamic>)['upload_id'],
          'generation': 'gen-a',
          'offset': 2,
          'size': 2,
          'complete': true,
          'asset_id': '33333333-3333-4333-8333-333333333333',
          'asset_status': 'created',
        }),
      ),
      stateDirectory: root,
      endpoint: 'https://server.example/api',
      headers: const {},
      registerDownloaderCallbacks: false,
    );
    final terminal = await restarted.uploadFile(
      file: rebuilt,
      originalFileName: 'changed.pmlive',
      fields: const {
        'fileCreatedAt': '2030-01-01T00:00:00Z',
        'fileModifiedAt': '2031-01-01T00:00:00Z',
        'isFavorite': 'true',
        'visibility': 'hidden',
      },
      cancelToken: null,
      logContext: 'restart pmlive',
      checksum: _md5Checksum('logical'),
      uploadId: 'UUID/L0/001',
    );
    expect(terminal.isSuccess, isTrue);
    expect(rebuilt.existsSync(), isFalse);
    expect(Directory('${root.path}/resumable-uploads').listSync(), isEmpty);
  });

  test('PMLive upload rejects an owned-name symlink without touching its outside target', () async {
    final root = await Directory.systemTemp.createTemp('resumable-pmlive-cancel-symlink-test-');
    addTearDown(() => root.delete(recursive: true));
    final native = _FakeNativeSyncApi();
    final repository = UploadRepository(
      nativeSyncApi: native,
      client: _RecordingClient(
        (request, body) async => _json(200, {
          'upload_id': (jsonDecode(utf8.decode(body)) as Map<String, dynamic>)['upload_id'],
          'generation': 'gen-a',
          'offset': 1,
          'size': 2,
          'complete': false,
        }),
      ),
      stateDirectory: root,
      endpoint: 'https://server.example/api',
      headers: const {},
      registerDownloaderCallbacks: false,
    );
    final still = File('${root.path}/still.heic')..writeAsBytesSync(const [1]);
    final motion = File('${root.path}/motion.mov')..writeAsBytesSync(const [2]);
    final ownedPath = await repository.createPMLiveBundle(
      assetId: 'UUID/L0/002',
      checksum: _md5Checksum('logical'),
      stillFile: still,
      motionFile: motion,
      stillOriginalName: 'still.heic',
      motionOriginalName: 'motion.mov',
      createdAt: DateTime.utc(2026, 8, 12),
      modifiedAt: DateTime.utc(2026, 8, 12, 1),
    );
    final outside = File('${root.path}/outside-target.pmlive')..writeAsBytesSync(const [1, 2]);
    ownedPath.deleteSync();
    final link = Link(ownedPath.path)..createSync(outside.path);
    final result = await repository.uploadFile(
      file: File(link.path),
      originalFileName: 'asset.pmlive',
      fields: const {'fileCreatedAt': '2026-08-12T01:02:03Z', 'fileModifiedAt': '2026-08-12T01:02:03Z'},
      cancelToken: Completer<void>()..complete(),
      logContext: 'cancel symlink pmlive',
      checksum: _md5Checksum('logical'),
      uploadId: 'UUID/L0/002',
    );
    expect(result.isSuccess, isFalse);
    expect(result.errorMessage, contains('unavailable or changed'));
    expect(Link(link.path).existsSync(), isTrue);
    expect(outside.readAsBytesSync(), const [1, 2]);
  });

  test('corrupt PMLive state cannot delete a different valid upload-id sibling', () async {
    final root = await Directory.systemTemp.createTemp('resumable-pmlive-cross-reference-test-');
    addTearDown(() => root.delete(recursive: true));
    final native = _FakeNativeSyncApi();
    final repository = UploadRepository(
      nativeSyncApi: native,
      client: _RecordingClient(
        (request, body) async => _json(200, {
          'upload_id': (jsonDecode(utf8.decode(body)) as Map<String, dynamic>)['upload_id'],
          'generation': 'gen-a',
          'offset': 0,
          'size': 2,
          'complete': false,
        }),
      ),
      stateDirectory: root,
      endpoint: 'https://server.example/api',
      headers: const {},
      registerDownloaderCallbacks: false,
    );
    final still = File('${root.path}/still.heic')..writeAsBytesSync(const [1]);
    final motion = File('${root.path}/motion.mov')..writeAsBytesSync(const [2]);
    final bundleA = await repository.createPMLiveBundle(
      assetId: 'asset-a',
      checksum: _md5Checksum('logical-a'),
      stillFile: still,
      motionFile: motion,
      stillOriginalName: 'a.heic',
      motionOriginalName: 'a.mov',
      createdAt: DateTime.utc(2026, 8, 12),
      modifiedAt: DateTime.utc(2026, 8, 12, 1),
    );
    final bundleB = await repository.createPMLiveBundle(
      assetId: 'asset-b',
      checksum: _md5Checksum('logical-b'),
      stillFile: still,
      motionFile: motion,
      stillOriginalName: 'b.heic',
      motionOriginalName: 'b.mov',
      createdAt: DateTime.utc(2026, 8, 12),
      modifiedAt: DateTime.utc(2026, 8, 12, 1),
    );
    final first = await repository.uploadFile(
      file: bundleA,
      originalFileName: 'a.pmlive',
      fields: const {'fileCreatedAt': '2026-08-12T01:02:03Z', 'fileModifiedAt': '2026-08-12T01:02:03Z'},
      cancelToken: Completer<void>()..complete(),
      logContext: 'cancel a',
      checksum: _md5Checksum('logical-a'),
      uploadId: 'asset-a',
    );
    expect(first.isCancelled, isTrue);
    expect(bundleB.existsSync(), isTrue);

    final stateFile = Directory('${root.path}/resumable-uploads').listSync().single as File;
    final state = jsonDecode(stateFile.readAsStringSync()) as Map<String, dynamic>;
    state['source_path'] = bundleB.path;
    stateFile.writeAsStringSync(jsonEncode(state));
    final second = await repository.uploadFile(
      file: bundleA,
      originalFileName: 'a.pmlive',
      fields: const {'fileCreatedAt': '2030-01-01T00:00:00Z', 'fileModifiedAt': '2030-01-01T00:00:00Z'},
      cancelToken: Completer<void>()..complete(),
      logContext: 'cancel corrupt a',
      checksum: _md5Checksum('logical-a'),
      uploadId: 'asset-a',
    );
    expect(second.isCancelled, isTrue);
    expect(bundleB.existsSync(), isTrue);
  });

  test('PMLive rebuild never reuses a content-equal sibling owned by another upload id', () async {
    final root = await Directory.systemTemp.createTemp('resumable-pmlive-rebuild-cross-reference-test-');
    addTearDown(() => root.delete(recursive: true));
    final native = _FakeNativeSyncApi();
    final repository = UploadRepository(
      nativeSyncApi: native,
      client: _RecordingClient(
        (request, body) async => _json(200, {
          'upload_id': (jsonDecode(utf8.decode(body)) as Map<String, dynamic>)['upload_id'],
          'generation': 'gen-a',
          'offset': 0,
          'size': 2,
          'complete': false,
        }),
      ),
      stateDirectory: root,
      endpoint: 'https://server.example/api',
      headers: const {},
      registerDownloaderCallbacks: false,
    );
    final still = File('${root.path}/still.heic')..writeAsBytesSync(const [1]);
    final motion = File('${root.path}/motion.mov')..writeAsBytesSync(const [2]);
    final bundleA = await repository.createPMLiveBundle(
      assetId: 'asset-a',
      checksum: _md5Checksum('logical-a'),
      stillFile: still,
      motionFile: motion,
      stillOriginalName: 'a.heic',
      motionOriginalName: 'a.mov',
      createdAt: DateTime.utc(2026, 8, 12),
      modifiedAt: DateTime.utc(2026, 8, 12, 1),
    );
    final bundleB = await repository.createPMLiveBundle(
      assetId: 'asset-b',
      checksum: _md5Checksum('logical-b'),
      stillFile: still,
      motionFile: motion,
      stillOriginalName: 'b.heic',
      motionOriginalName: 'b.mov',
      createdAt: DateTime.utc(2026, 8, 12),
      modifiedAt: DateTime.utc(2026, 8, 12, 1),
    );
    await repository.uploadFile(
      file: bundleA,
      originalFileName: 'a.pmlive',
      fields: const {'fileCreatedAt': '2026-08-12T01:02:03Z', 'fileModifiedAt': '2026-08-12T01:02:03Z'},
      cancelToken: Completer<void>()..complete(),
      logContext: 'cancel a',
      checksum: _md5Checksum('logical-a'),
      uploadId: 'asset-a',
    );
    final stateFile = Directory('${root.path}/resumable-uploads').listSync().single as File;
    final state = jsonDecode(stateFile.readAsStringSync()) as Map<String, dynamic>;
    state['source_path'] = bundleB.path;
    stateFile.writeAsStringSync(jsonEncode(state));

    final rebuilt = await repository.createPMLiveBundle(
      assetId: 'asset-a',
      checksum: _md5Checksum('logical-a'),
      stillFile: still,
      motionFile: motion,
      stillOriginalName: 'a.heic',
      motionOriginalName: 'a.mov',
      createdAt: DateTime.utc(2026, 8, 12),
      modifiedAt: DateTime.utc(2026, 8, 12, 1),
    );

    expect(rebuilt.path, isNot(bundleB.path));
    expect(bundleB.existsSync(), isTrue);
    expect(rebuilt.path.split('/').last, '${state['upload_id']}.pmlive');
  });

  test('upload id is a stable safe derivation of server, local asset, and checksum', () async {
    final root = await Directory.systemTemp.createTemp('resumable-id-test-');
    addTearDown(() => root.delete(recursive: true));
    final first = File('${root.path}/first.pmlive')..writeAsBytesSync(const [1]);
    final rebuilt = File('${root.path}/rebuilt.pmlive')..writeAsBytesSync(const [1]);
    final captured = <String>[];

    Future<String> upload({required String endpoint, required File file, required String checksum}) async {
      final client = _RecordingClient((request, body) async {
        final start = jsonDecode(utf8.decode(body)) as Map<String, dynamic>;
        final uploadId = start['upload_id'] as String;
        captured.add(uploadId);
        return _json(200, {
          'upload_id': uploadId,
          'generation': 'gen-a',
          'offset': 1,
          'size': 1,
          'complete': true,
          'asset_id': '11111111-1111-4111-8111-111111111111',
          'asset_status': 'duplicate',
        });
      });
      final repository = UploadRepository(
        client: client,
        stateDirectory: root,
        endpoint: endpoint,
        headers: const {},
        registerDownloaderCallbacks: false,
      );
      final result = await repository.uploadFile(
        file: file,
        originalFileName: 'asset.pmlive',
        fields: const {'fileCreatedAt': '2026-08-12T01:02:03Z', 'fileModifiedAt': '2026-08-12T01:02:03Z'},
        cancelToken: null,
        logContext: 'test',
        checksum: checksum,
        uploadId: 'UUID/L0/001',
      );
      expect(result.isSuccess, isTrue);
      return captured.last;
    }

    final firstId = await upload(endpoint: 'https://one.example/api', file: first, checksum: _md5Checksum('one'));
    final rebuiltId = await upload(endpoint: 'https://one.example/api', file: rebuilt, checksum: _md5Checksum('one'));
    final otherServerId = await upload(
      endpoint: 'https://two.example/api',
      file: rebuilt,
      checksum: _md5Checksum('one'),
    );
    final otherContentId = await upload(
      endpoint: 'https://one.example/api',
      file: rebuilt,
      checksum: _md5Checksum('two'),
    );

    expect(firstId, rebuiltId);
    expect(firstId, matches(RegExp(r'^[A-Za-z0-9_.-]{1,128}$')));
    expect(firstId, isNot(contains('/')));
    expect(otherServerId, isNot(firstId));
    expect(otherContentId, isNot(firstId));
  });

  test('only a cached raw MD5 checksum is reused for a local asset', () async {
    final native = _FakeNativeSyncApi();
    final repository = UploadRepository(nativeSyncApi: native, registerDownloaderCallbacks: false);
    final cachedMD5 = base64Encode(md5.convert(utf8.encode('cached')).bytes);
    final cachedSHA1 = base64Encode(sha1.convert(utf8.encode('legacy')).bytes);

    final modifiedAt = DateTime.utc(2026, 8, 17);
    expect(
      await repository.ensureAssetChecksum(
        'UUID/L0/001',
        cachedMD5,
        contentMd5: md5.convert(utf8.encode('cached')).toString(),
        contentSize: 6,
        hashAlgorithm: 'md5',
        hashedModifiedAt: modifiedAt,
        modifiedAt: modifiedAt,
      ),
      cachedMD5,
    );
    expect(native.assetIds, isEmpty);

    expect(
      await repository.ensureAssetChecksum('UUID/L0/001', cachedSHA1, modifiedAt: modifiedAt),
      _FakeNativeSyncApi.nativeMD5,
    );
    expect(native.assetIds, ['UUID/L0/001']);

    expect(
      await repository.ensureAssetChecksum('UUID/L0/002', null, modifiedAt: modifiedAt),
      _FakeNativeSyncApi.nativeMD5,
    );
    expect(native.assetIds, ['UUID/L0/001', 'UUID/L0/002']);
  });

  test('extracted Motion Photo still reuses cache only when its size matches', () async {
    final root = await Directory.systemTemp.createTemp('motion-still-md5-test-');
    addTearDown(() => root.delete(recursive: true));
    final still = File('${root.path}/still.jpg')..writeAsBytesSync(utf8.encode('still'));
    final repository = UploadRepository(registerDownloaderCallbacks: false);
    final modifiedAt = DateTime.utc(2026, 8, 17);
    final cached = _md5Checksum('still');

    expect(
      await repository.ensureAssetFileChecksum(
        'asset-1',
        still,
        checksum: cached,
        contentMd5: md5.convert(utf8.encode('still')).toString(),
        contentSize: 5,
        hashAlgorithm: 'md5',
        hashedModifiedAt: modifiedAt,
        modifiedAt: modifiedAt,
      ),
      cached,
    );
    expect(
      await repository.ensureAssetFileChecksum(
        'asset-1',
        still,
        checksum: _md5Checksum('combined-motion-photo'),
        contentMd5: md5.convert(utf8.encode('combined-motion-photo')).toString(),
        contentSize: 21,
        hashAlgorithm: 'md5',
        hashedModifiedAt: modifiedAt,
        modifiedAt: modifiedAt,
      ),
      cached,
    );
  });

  test('PMLive artifacts use container-specific safe names before resumable state exists', () async {
    final root = await Directory.systemTemp.createTemp('pmlive-attempt-test-');
    addTearDown(() => root.delete(recursive: true));
    final native = _FakeNativeSyncApi();
    final repository = UploadRepository(
      nativeSyncApi: native,
      stateDirectory: root,
      endpoint: 'https://server.example/api',
      registerDownloaderCallbacks: false,
    );
    final firstStill = File('${root.path}/first.heic')..writeAsBytesSync(const [1]);
    final firstMotion = File('${root.path}/first.mov')..writeAsBytesSync(const [2]);
    final changedStill = File('${root.path}/changed.heic')..writeAsBytesSync(const [8]);
    final changedMotion = File('${root.path}/changed.mov')..writeAsBytesSync(const [9]);

    final first = await repository.createPMLiveBundle(
      assetId: 'UUID/L0/001',
      checksum: _md5Checksum('logical-checksum'),
      stillFile: firstStill,
      motionFile: firstMotion,
      stillOriginalName: 'first.heic',
      motionOriginalName: 'first.mov',
      createdAt: DateTime.utc(2026, 8, 12),
      modifiedAt: DateTime.utc(2026, 8, 12, 1),
    );
    final second = await repository.createPMLiveBundle(
      assetId: 'UUID/L0/001',
      checksum: _md5Checksum('logical-checksum'),
      stillFile: changedStill,
      motionFile: changedMotion,
      stillOriginalName: 'changed.heic',
      motionOriginalName: 'changed.mov',
      createdAt: DateTime.utc(2030),
      modifiedAt: DateTime.utc(2031),
    );

    expect(second.path, isNot(first.path));
    expect(first.path.split('/').last, matches(RegExp(r'^pc-[0-9a-f]{64}\.pmlive$')));
    expect(second.path.split('/').last, matches(RegExp(r'^pc-[0-9a-f]{64}\.pmlive$')));
    expect(first.readAsBytesSync(), const [1, 2]);
    expect(second.readAsBytesSync(), const [8, 9]);
    expect(native.pmliveWrites, 2);
  });

  test('PMLive publish never replaces a final-name symlink or touches its outside target', () async {
    final root = await Directory.systemTemp.createTemp('pmlive-final-symlink-test-');
    addTearDown(() => root.delete(recursive: true));
    final native = _FakeNativeSyncApi();
    final repository = UploadRepository(
      nativeSyncApi: native,
      stateDirectory: root,
      endpoint: 'https://server.example/api',
      registerDownloaderCallbacks: false,
    );
    final still = File('${root.path}/still.heic')..writeAsBytesSync(const [1]);
    final motion = File('${root.path}/motion.mov')..writeAsBytesSync(const [2]);
    final first = await repository.createPMLiveBundle(
      assetId: 'UUID/L0/final-link',
      checksum: _md5Checksum('logical-checksum'),
      stillFile: still,
      motionFile: motion,
      stillOriginalName: 'still.heic',
      motionOriginalName: 'motion.mov',
      createdAt: DateTime.utc(2026, 8, 12),
      modifiedAt: DateTime.utc(2026, 8, 12, 1),
    );
    final outside = File('${root.path}/outside-target.pmlive')..writeAsBytesSync(const [9, 9]);
    first.deleteSync();
    final link = Link(first.path)..createSync(outside.path);

    await expectLater(
      repository.createPMLiveBundle(
        assetId: 'UUID/L0/final-link',
        checksum: _md5Checksum('logical-checksum'),
        stillFile: still,
        motionFile: motion,
        stillOriginalName: 'still.heic',
        motionOriginalName: 'motion.mov',
        createdAt: DateTime.utc(2026, 8, 12),
        modifiedAt: DateTime.utc(2026, 8, 12, 1),
      ),
      throwsA(isA<StateError>()),
    );

    expect(Link(link.path).existsSync(), isTrue);
    expect(outside.readAsBytesSync(), const [9, 9]);
  });

  test('stale cleanup ignores final and provisional symlinks with owned-looking names', () async {
    final root = await Directory.systemTemp.createTemp('pmlive-cleanup-symlink-test-');
    addTearDown(() => root.delete(recursive: true));
    final repository = UploadRepository(
      stateDirectory: root,
      endpoint: 'https://server.example/api',
      registerDownloaderCallbacks: false,
    );
    final attempts = Directory('${root.path}/pmlive-upload-attempts')..createSync(recursive: true);
    final outside = File('${root.path}/outside-target.pmlive')..writeAsBytesSync(const [7, 7]);
    final digestName = List.filled(64, 'a').join();
    final finalLink = Link('${attempts.path}/pc-$digestName.pmlive')..createSync(outside.path);
    final provisionalLink = Link('${attempts.path}/.pc-$digestName.pmlive.123e4567-e89b-12d3-a456-426614174000.part')
      ..createSync(outside.path);

    await repository.cleanupStalePMLiveArtifacts(now: DateTime.utc(2030), maxAge: Duration.zero);

    expect(Link(finalLink.path).existsSync(), isTrue);
    expect(Link(provisionalLink.path).existsSync(), isTrue);
    expect(outside.readAsBytesSync(), const [7, 7]);
  });

  test(
    'startup PMLive cleanup preserves referenced and fresh artifacts and removes only expired owned files',
    () async {
      final root = await Directory.systemTemp.createTemp('pmlive-cleanup-test-');
      addTearDown(() => root.delete(recursive: true));
      final repository = UploadRepository(
        stateDirectory: root,
        endpoint: 'https://server.example/api',
        registerDownloaderCallbacks: false,
      );
      final attempts = Directory('${root.path}/pmlive-upload-attempts')..createSync(recursive: true);
      final states = Directory('${root.path}/resumable-uploads')..createSync(recursive: true);
      final a = List.filled(64, 'a').join();
      final b = List.filled(64, 'b').join();
      final c = List.filled(64, 'c').join();
      final d = List.filled(64, 'd').join();
      final referenced = File('${attempts.path}/pc-$a.pmlive')..writeAsBytesSync(const [1]);
      final expired = File('${attempts.path}/pc-$b.pmlive')..writeAsBytesSync(const [2]);
      final fresh = File('${attempts.path}/pc-$c.pmlive')..writeAsBytesSync(const [3]);
      final expiredPart = File('${attempts.path}/.pc-$d.pmlive.123E4567-E89B-12D3-A456-426614174000.part')
        ..writeAsBytesSync(const [4]);
      final unrelated = File('${attempts.path}/keep-me.txt')..writeAsBytesSync(const [5]);
      final now = DateTime.utc(2026, 8, 12, 12);
      final old = now.subtract(const Duration(days: 2));
      for (final file in [referenced, expired, expiredPart]) {
        file.setLastModifiedSync(old);
      }
      fresh.setLastModifiedSync(now.subtract(const Duration(minutes: 5)));
      File('${states.path}/referenced.json').writeAsStringSync(
        jsonEncode({
          'version': 1,
          'upload_id': 'pc-$a',
          'source_path': referenced.path,
          'original_name': 'live.pmlive',
          'checksum': 'logical',
          'size': 1,
          'metadata': <String, Object>{},
          'is_favorite': false,
          'visibility': 'timeline',
        }),
      );

      await repository.cleanupStalePMLiveArtifacts(now: now, maxAge: const Duration(days: 1));

      expect(referenced.existsSync(), isTrue);
      expect(fresh.existsSync(), isTrue);
      expect(unrelated.existsSync(), isTrue);
      expect(expired.existsSync(), isFalse);
      expect(expiredPart.existsSync(), isFalse);
    },
  );
}

String _logicalUploadId(String endpoint, String localAssetId, String checksum) {
  final uri = Uri.parse(endpoint);
  final path = uri.path.replaceFirst(RegExp(r'/+$'), '');
  final serverIdentity = uri.replace(path: path, query: null, fragment: null).toString();
  return 'pc-${sha256.convert(utf8.encode('$serverIdentity\u0000$localAssetId\u0000$checksum'))}';
}

Future<void> _writeLegacyState(
  Directory root,
  String logicalUploadId, {
  required String sourcePath,
  required String originalName,
  required String checksum,
  required int size,
  required Map<String, Object> metadata,
  required String generation,
  required int offset,
}) async {
  final directory = Directory('${root.path}/resumable-uploads')..createSync(recursive: true);
  final state = File('${directory.path}/${sha256.convert(utf8.encode(logicalUploadId))}.json');
  await state.writeAsString(
    jsonEncode({
      'version': 1,
      'upload_id': logicalUploadId,
      'source_path': sourcePath,
      'original_name': originalName,
      'checksum': checksum,
      'size': size,
      'metadata': metadata,
      'is_favorite': false,
      'visibility': 'timeline',
      'generation': generation,
      'offset': offset,
    }),
    flush: true,
  );
}

typedef _Handler = Future<StreamedResponse> Function(BaseRequest request, List<int> body);

String _md5Checksum(String value) => base64Encode(md5.convert(utf8.encode(value)).bytes);

class _RecordingClient extends BaseClient {
  final _Handler handler;
  final bool interceptBulkUploadCheck;

  _RecordingClient(this.handler, {this.interceptBulkUploadCheck = true});

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    final body = await request.finalize().toBytes();
    if (request.method == 'GET' && request.url.path.endsWith('/server/config')) {
      return _json(200, {'checksumAlgorithm': 'md5-size'});
    }
    if (interceptBulkUploadCheck &&
        request.method == 'POST' &&
        request.url.path.endsWith('/assets/bulk-upload-check')) {
      final payload = jsonDecode(utf8.decode(body)) as Map<String, dynamic>;
      final assets = payload['assets'] as List<dynamic>;
      return _json(200, {
        'results': [
          for (final asset in assets) {'id': (asset as Map<String, dynamic>)['id'], 'action': 'accept'},
        ],
      });
    }
    return handler(request, body);
  }
}

class _FakeNativeSyncApi extends NativeSyncApi {
  static final String nativeMD5 = base64Encode(md5.convert(utf8.encode('native')).bytes);
  final List<String> assetIds = [];
  int pmliveWrites = 0;

  @override
  Future<List<HashResult>> hashAssets(List<String> requestedAssetIds, {bool allowNetworkAccess = false}) async {
    assetIds.addAll(requestedAssetIds);
    return requestedAssetIds
        .map((assetId) => HashResult(assetId: assetId, hash: nativeMD5, size: 6, algorithm: 'md5'))
        .toList();
  }

  @override
  Future<String> createPMLive(PMLiveInput input) async {
    pmliveWrites++;
    await File(
      input.outputPath,
    ).writeAsBytes([...await File(input.stillPath).readAsBytes(), ...await File(input.motionPath).readAsBytes()]);
    return input.outputPath;
  }
}

StreamedResponse _json(int status, Map<String, Object> body) => StreamedResponse(
  Stream.value(utf8.encode(jsonEncode(body))),
  status,
  headers: {'content-type': 'application/json'},
);
