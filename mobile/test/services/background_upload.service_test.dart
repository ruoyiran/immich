import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:immich_mobile/domain/models/asset/base_asset.model.dart';
import 'package:immich_mobile/domain/models/store.model.dart';
import 'package:immich_mobile/domain/services/store.service.dart';
import 'package:immich_mobile/entities/store.entity.dart';
import 'package:immich_mobile/infrastructure/repositories/db.repository.dart';
import 'package:immich_mobile/infrastructure/repositories/storage.repository.dart';
import 'package:immich_mobile/infrastructure/repositories/store.repository.dart';
import 'package:immich_mobile/repositories/upload.repository.dart';
import 'package:immich_mobile/services/background_upload.service.dart';
import 'package:mocktail/mocktail.dart';

import '../fixtures/asset.stub.dart';
import '../infrastructure/repository.mock.dart';
import '../mocks/asset_entity.mock.dart';
import '../repository.mocks.dart';

void main() {
  late MockUploadRepository uploadRepository;
  late MockStorageRepository storageRepository;
  late MockDriftBackupRepository backupRepository;
  late MockAssetMediaRepository assetMediaRepository;
  late BackgroundUploadService sut;
  late Drift db;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    db = Drift(DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true));
    await StoreService.init(storeRepository: DriftStoreRepository(db));
    await Store.put(StoreKey.deviceId, 'device-id');
    registerFallbackValue(File('file'));
    registerFallbackValue(<String, String>{});
    registerFallbackValue(DateTime.utc(2000));
  });

  setUp(() {
    uploadRepository = MockUploadRepository();
    storageRepository = MockStorageRepository();
    backupRepository = MockDriftBackupRepository();
    assetMediaRepository = MockAssetMediaRepository();
    sut = BackgroundUploadService(uploadRepository, storageRepository, backupRepository, assetMediaRepository);
    when(
      () => uploadRepository.preflightLocalAssetIdentity(
        assetId: any(named: 'assetId'),
        localAssetId: any(named: 'localAssetId'),
        deviceId: any(named: 'deviceId'),
        size: any(named: 'size'),
        modifiedAt: any(named: 'modifiedAt'),
        originalFileName: any(named: 'originalFileName'),
        fields: any(named: 'fields'),
      ),
    ).thenAnswer((_) async => null);
    when(
      () => uploadRepository.ensureAssetChecksum(
        any(),
        any(),
        contentMd5: any(named: 'contentMd5'),
        contentSize: any(named: 'contentSize'),
        hashAlgorithm: any(named: 'hashAlgorithm'),
        hashedModifiedAt: any(named: 'hashedModifiedAt'),
        modifiedAt: any(named: 'modifiedAt'),
      ),
    ).thenAnswer((_) async => 'logical-checksum');
    when(
      () => uploadRepository.preflightResumableTerminal(
        checksum: any(named: 'checksum'),
        uploadId: any(named: 'uploadId'),
      ),
    ).thenAnswer((_) async => null);
  });

  tearDown(() => sut.dispose());

  test('Live Photo background upload sends motion before the still', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final asset = LocalAssetStub.image1;
    final entity = MockAssetEntity();
    final still = File('/tmp/still.heic');
    final motion = File('/tmp/motion.mov');
    when(() => entity.isLivePhoto).thenReturn(true);
    when(() => storageRepository.getAssetEntityForAsset(asset)).thenAnswer((_) async => entity);
    when(() => storageRepository.getFileForAsset(asset.id)).thenAnswer((_) async => still);
    when(() => storageRepository.getMotionFileForAsset(asset)).thenAnswer((_) async => motion);
    when(() => assetMediaRepository.getOriginalFilename(asset.id)).thenAnswer((_) async => 'IMG_0001.HEIC');
    when(() => uploadRepository.hashShareIntentFile(motion)).thenAnswer((_) async => 'motion-md5');
    final files = <File>[];
    final names = <String>[];
    final fields = <Map<String, String>>[];
    when(
      () => uploadRepository.uploadFile(
        file: any(named: 'file'),
        originalFileName: any(named: 'originalFileName'),
        fields: any(named: 'fields'),
        cancelToken: any(named: 'cancelToken'),
        onProgress: any(named: 'onProgress'),
        logContext: any(named: 'logContext'),
        checksum: any(named: 'checksum'),
        uploadId: any(named: 'uploadId'),
      ),
    ).thenAnswer((invocation) async {
      files.add(invocation.namedArguments[#file] as File);
      names.add(invocation.namedArguments[#originalFileName] as String);
      fields.add(Map.of(invocation.namedArguments[#fields] as Map<String, String>));
      return UploadResult.success(remoteAssetId: 'remote-${files.length}', assetStatus: 'created');
    });

    final result = await sut.uploadSingleAsset(asset);

    expect(result?.remoteAssetId, 'remote-2');
    verify(
      () => uploadRepository.uploadFile(
        file: any(named: 'file'),
        originalFileName: any(named: 'originalFileName'),
        fields: any(named: 'fields'),
        cancelToken: any(named: 'cancelToken'),
        onProgress: any(named: 'onProgress'),
        logContext: any(named: 'logContext'),
        checksum: any(named: 'checksum'),
        uploadId: any(named: 'uploadId'),
      ),
    ).called(2);
    expect(files, [motion, still]);
    expect(names, ['IMG_0001.mov', 'IMG_0001.heic']);
    expect(fields.first['visibility'], 'hidden');
    expect(fields.first['livePhotoRole'], 'motion');
    expect(fields.last['livePhotoVideoId'], 'remote-1');
    verifyNever(
      () => uploadRepository.createPMLiveBundle(
        assetId: any(named: 'assetId'),
        checksum: any(named: 'checksum'),
        stillFile: any(named: 'stillFile'),
        motionFile: any(named: 'motionFile'),
        stillOriginalName: any(named: 'stillOriginalName'),
        motionOriginalName: any(named: 'motionOriginalName'),
        createdAt: any(named: 'createdAt'),
        modifiedAt: any(named: 'modifiedAt'),
      ),
    );
  });

  test('Android Motion Photo uses verified extracted still and motion files', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final asset = LocalAssetStub.image1.copyWith(playbackStyle: AssetPlaybackStyle.livePhoto);
    final entity = MockAssetEntity();
    final still = File('/tmp/extracted-still.jpg');
    final motion = File('/tmp/extracted-motion.mp4');
    when(() => entity.isLivePhoto).thenReturn(true);
    when(() => storageRepository.getAssetEntityForAsset(asset)).thenAnswer((_) async => entity);
    when(
      () => storageRepository.getLivePhotoFilesForAsset(asset),
    ).thenAnswer((_) async => LivePhotoFiles(still: still, motion: motion, temporary: false));
    when(() => assetMediaRepository.getOriginalFilename(asset.id)).thenAnswer((_) async => 'motion.jpg');
    when(
      () => uploadRepository.ensureAssetFileChecksum(
        asset.id,
        still,
        checksum: asset.checksum,
        contentMd5: asset.contentMd5,
        contentSize: asset.contentSize,
        hashAlgorithm: asset.hashAlgorithm,
        hashedModifiedAt: asset.hashedModifiedAt,
        modifiedAt: asset.updatedAt,
      ),
    ).thenAnswer((_) async => 'still-md5');
    when(() => uploadRepository.hashShareIntentFile(motion)).thenAnswer((_) async => 'motion-md5');
    final files = <File>[];
    when(
      () => uploadRepository.uploadFile(
        file: any(named: 'file'),
        originalFileName: any(named: 'originalFileName'),
        fields: any(named: 'fields'),
        cancelToken: any(named: 'cancelToken'),
        onProgress: any(named: 'onProgress'),
        logContext: any(named: 'logContext'),
        checksum: any(named: 'checksum'),
        uploadId: any(named: 'uploadId'),
      ),
    ).thenAnswer((invocation) async {
      files.add(invocation.namedArguments[#file] as File);
      return UploadResult.success(remoteAssetId: 'remote-${files.length}', assetStatus: 'created');
    });

    final result = await sut.uploadSingleAsset(asset);

    expect(result?.remoteAssetId, 'remote-2');
    expect(files, [motion, still]);
    verifyNever(
      () => uploadRepository.ensureAssetChecksum(
        any(),
        any(),
        contentMd5: any(named: 'contentMd5'),
        contentSize: any(named: 'contentSize'),
        hashAlgorithm: any(named: 'hashAlgorithm'),
        hashedModifiedAt: any(named: 'hashedModifiedAt'),
        modifiedAt: any(named: 'modifiedAt'),
      ),
    );
  });

  test('normal background upload uses the same resumable repository once', () async {
    final asset = LocalAssetStub.image1;
    final entity = MockAssetEntity();
    final file = File('/tmp/photo.jpg');
    when(() => entity.isLivePhoto).thenReturn(false);
    when(() => storageRepository.getAssetEntityForAsset(asset)).thenAnswer((_) async => entity);
    when(() => storageRepository.getFileForAsset(asset.id)).thenAnswer((_) async => file);
    when(() => assetMediaRepository.getOriginalFilename(asset.id)).thenAnswer((_) async => 'photo.jpg');
    when(
      () => uploadRepository.uploadFile(
        file: any(named: 'file'),
        originalFileName: any(named: 'originalFileName'),
        fields: any(named: 'fields'),
        cancelToken: any(named: 'cancelToken'),
        onProgress: any(named: 'onProgress'),
        logContext: any(named: 'logContext'),
        checksum: any(named: 'checksum'),
        uploadId: any(named: 'uploadId'),
      ),
    ).thenAnswer((_) async => UploadResult.success(remoteAssetId: 'remote-id', assetStatus: 'duplicate'));

    final result = await sut.uploadSingleAsset(asset);

    expect(result?.assetStatus, 'duplicate');
    verify(
      () => uploadRepository.uploadFile(
        file: file,
        originalFileName: 'photo.jpg',
        fields: any(named: 'fields'),
        cancelToken: any(named: 'cancelToken'),
        onProgress: any(named: 'onProgress'),
        logContext: any(named: 'logContext'),
        checksum: 'logical-checksum',
        uploadId: asset.id,
      ),
    ).called(1);
    verifyNever(
      () => uploadRepository.createPMLiveBundle(
        assetId: any(named: 'assetId'),
        checksum: any(named: 'checksum'),
        stillFile: any(named: 'stillFile'),
        motionFile: any(named: 'motionFile'),
        stillOriginalName: any(named: 'stillOriginalName'),
        motionOriginalName: any(named: 'motionOriginalName'),
        createdAt: any(named: 'createdAt'),
        modifiedAt: any(named: 'modifiedAt'),
      ),
    );
  });

  test('normal iOS background retry reacquires a fresh temp with the same resumable identity', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final root = await Directory.systemTemp.createTemp('background-normal-restart-');
    addTearDown(() => root.delete(recursive: true));
    final asset = LocalAssetStub.image1;
    final entity = MockAssetEntity();
    final first = File('${root.path}/first-temp.jpg')..writeAsBytesSync(const [1, 2, 3]);
    final rebound = File('${root.path}/rebound-temp.jpg')..writeAsBytesSync(const [1, 2, 3]);
    var sourceCall = 0;
    final uploads = <File>[];
    when(() => entity.isLivePhoto).thenReturn(false);
    when(() => storageRepository.getAssetEntityForAsset(asset)).thenAnswer((_) async => entity);
    when(
      () => storageRepository.getFileForAsset(asset.id),
    ).thenAnswer((_) async => sourceCall++ == 0 ? first : rebound);
    when(() => assetMediaRepository.getOriginalFilename(asset.id)).thenAnswer((_) async => 'photo.jpg');
    when(
      () => uploadRepository.uploadFile(
        file: any(named: 'file'),
        originalFileName: any(named: 'originalFileName'),
        fields: any(named: 'fields'),
        cancelToken: any(named: 'cancelToken'),
        onProgress: any(named: 'onProgress'),
        logContext: any(named: 'logContext'),
        checksum: any(named: 'checksum'),
        uploadId: any(named: 'uploadId'),
      ),
    ).thenAnswer((invocation) async {
      uploads.add(invocation.namedArguments[#file] as File);
      return uploads.length == 1
          ? UploadResult.error(statusCode: 500, errorMessage: 'response lost')
          : UploadResult.success(remoteAssetId: 'remote-id', assetStatus: 'created');
    });

    await sut.uploadSingleAsset(asset);
    expect(first.existsSync(), isFalse);
    await sut.uploadSingleAsset(asset);

    expect(uploads.map((file) => file.path), [first.path, rebound.path]);
    verify(
      () => uploadRepository.uploadFile(
        file: any(named: 'file'),
        originalFileName: 'photo.jpg',
        fields: any(named: 'fields'),
        cancelToken: any(named: 'cancelToken'),
        onProgress: any(named: 'onProgress'),
        logContext: any(named: 'logContext'),
        checksum: 'logical-checksum',
        uploadId: asset.id,
      ),
    ).called(2);
  });

  test('terminal persisted attempt returns before background resolves local media', () async {
    final root = await Directory.systemTemp.createTemp('background-terminal-preflight-');
    addTearDown(() => root.delete(recursive: true));
    const endpoint = 'https://server.example/api';
    const checksum = 'AQIDBAUGBwgJCgsMDQ4PEA==';
    final asset = LocalAssetStub.image1.copyWith(
      checksum: checksum,
      contentMd5: '0102030405060708090a0b0c0d0e0f10',
      contentSize: 4,
      hashAlgorithm: 'md5',
      hashedModifiedAt: LocalAssetStub.image1.updatedAt,
    );
    final uploadId = await _writePersistedAttempt(root, endpoint, asset.id, checksum);
    final repository = UploadRepository(
      client: MockClient(
        (request) async => Response(
          jsonEncode(
            request.url.path.endsWith('/server/config')
                ? {'checksumAlgorithm': 'md5-size'}
                : request.url.path.endsWith('/assets/bulk-device-check')
                ? {
                    'results': [
                      {'id': asset.id, 'action': 'accept'},
                    ],
                  }
                : {
                    'upload_id': uploadId,
                    'generation': 'gen-a',
                    'offset': 4,
                    'size': 4,
                    'complete': true,
                    'asset_id': '22222222-2222-4222-8222-222222222222',
                    'asset_status': 'created',
                  },
          ),
          200,
        ),
      ),
      stateDirectory: root,
      endpoint: endpoint,
      headers: const {},
      registerDownloaderCallbacks: false,
    );
    final terminalService = BackgroundUploadService(
      repository,
      storageRepository,
      backupRepository,
      assetMediaRepository,
    );
    addTearDown(terminalService.dispose);

    final result = await terminalService.uploadSingleAsset(asset);

    expect(result?.remoteAssetId, '22222222-2222-4222-8222-222222222222');
    verifyNever(() => storageRepository.getAssetEntityForAsset(asset));
    verifyNever(() => storageRepository.getFileForAsset(asset.id));
    verifyNever(() => storageRepository.getMotionFileForAsset(asset));
  });

  test(
    'terminal duplicate removes the background pmlive bundle',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final root = await Directory.systemTemp.createTemp('background-pmlive-terminal-');
      addTearDown(() => root.delete(recursive: true));
      final asset = LocalAssetStub.image1;
      final entity = MockAssetEntity();
      // A prior cache cleanup may already have removed a source temp; that must
      // not prevent terminal cleanup of the canonical bundle.
      final still = File('${root.path}/missing-still.heic');
      final motion = File('${root.path}/missing-motion.mov');
      final bundle = File('${root.path}/live.pmlive')..writeAsBytesSync(const [3]);
      when(() => entity.isLivePhoto).thenReturn(true);
      when(() => storageRepository.getAssetEntityForAsset(asset)).thenAnswer((_) async => entity);
      when(() => storageRepository.getFileForAsset(asset.id)).thenAnswer((_) async => still);
      when(() => storageRepository.getMotionFileForAsset(asset)).thenAnswer((_) async => motion);
      when(() => assetMediaRepository.getOriginalFilename(asset.id)).thenAnswer((_) async => 'IMG_0001.HEIC');
      when(
        () => uploadRepository.createPMLiveBundle(
          assetId: any(named: 'assetId'),
          checksum: any(named: 'checksum'),
          stillFile: any(named: 'stillFile'),
          motionFile: any(named: 'motionFile'),
          stillOriginalName: any(named: 'stillOriginalName'),
          motionOriginalName: any(named: 'motionOriginalName'),
          createdAt: any(named: 'createdAt'),
          modifiedAt: any(named: 'modifiedAt'),
        ),
      ).thenAnswer((_) async => bundle);
      when(
        () => uploadRepository.uploadFile(
          file: any(named: 'file'),
          originalFileName: any(named: 'originalFileName'),
          fields: any(named: 'fields'),
          cancelToken: any(named: 'cancelToken'),
          onProgress: any(named: 'onProgress'),
          logContext: any(named: 'logContext'),
          checksum: any(named: 'checksum'),
          uploadId: any(named: 'uploadId'),
        ),
      ).thenAnswer((_) async => UploadResult.success(remoteAssetId: 'remote-id', assetStatus: 'duplicate'));

      await sut.uploadSingleAsset(asset);

      expect(bundle.existsSync(), isFalse);
    },
    skip: 'PMLive generation was removed; retained only as a historical cleanup regression',
  );

  test(
    'retryable background result keeps the pmlive bundle for restart',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final root = await Directory.systemTemp.createTemp('background-pmlive-retry-');
      addTearDown(() => root.delete(recursive: true));
      final asset = LocalAssetStub.image1;
      final entity = MockAssetEntity();
      final still = File('${root.path}/still.heic')..writeAsBytesSync(const [1]);
      final motion = File('${root.path}/motion.mov')..writeAsBytesSync(const [2]);
      final bundle = File('${root.path}/live.pmlive')..writeAsBytesSync(const [3]);
      when(() => entity.isLivePhoto).thenReturn(true);
      when(() => storageRepository.getAssetEntityForAsset(asset)).thenAnswer((_) async => entity);
      when(() => storageRepository.getFileForAsset(asset.id)).thenAnswer((_) async => still);
      when(() => storageRepository.getMotionFileForAsset(asset)).thenAnswer((_) async => motion);
      when(() => assetMediaRepository.getOriginalFilename(asset.id)).thenAnswer((_) async => 'IMG_0001.HEIC');
      when(
        () => uploadRepository.createPMLiveBundle(
          assetId: any(named: 'assetId'),
          checksum: any(named: 'checksum'),
          stillFile: any(named: 'stillFile'),
          motionFile: any(named: 'motionFile'),
          stillOriginalName: any(named: 'stillOriginalName'),
          motionOriginalName: any(named: 'motionOriginalName'),
          createdAt: any(named: 'createdAt'),
          modifiedAt: any(named: 'modifiedAt'),
        ),
      ).thenAnswer((_) async => bundle);
      when(
        () => uploadRepository.uploadFile(
          file: any(named: 'file'),
          originalFileName: any(named: 'originalFileName'),
          fields: any(named: 'fields'),
          cancelToken: any(named: 'cancelToken'),
          onProgress: any(named: 'onProgress'),
          logContext: any(named: 'logContext'),
          checksum: any(named: 'checksum'),
          uploadId: any(named: 'uploadId'),
        ),
      ).thenAnswer((_) async => UploadResult.error(statusCode: 409, errorMessage: 'write lease busy'));

      await sut.uploadSingleAsset(asset);

      expect(bundle.existsSync(), isTrue);
    },
    skip: 'PMLive generation was removed; retained only as a historical cleanup regression',
  );
}

Future<String> _writePersistedAttempt(Directory root, String endpoint, String localAssetId, String checksum) async {
  final serverIdentity = Uri.parse(endpoint).replace(query: null, fragment: null).toString();
  final uploadId = 'pc-${sha256.convert(utf8.encode('$serverIdentity\u0000$localAssetId\u0000$checksum'))}';
  final directory = Directory('${root.path}/resumable-uploads')..createSync(recursive: true);
  final state = File('${directory.path}/${sha256.convert(utf8.encode(uploadId))}.json');
  await state.writeAsString(
    jsonEncode({
      'version': 1,
      'upload_id': uploadId,
      'source_path': '${root.path}/missing-ios-temp.jpg',
      'original_name': 'canonical.jpg',
      'checksum': checksum,
      'size': 4,
      'metadata': {
        'original_created_unix_nano': 1735689600000000000,
        'original_modified_unix_nano': 1738368000000000000,
      },
      'is_favorite': false,
      'visibility': 'timeline',
      'generation': 'gen-a',
      'offset': 4,
    }),
  );
  return uploadId;
}
