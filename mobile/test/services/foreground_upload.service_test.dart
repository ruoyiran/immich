import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:immich_mobile/domain/models/store.model.dart';
import 'package:immich_mobile/domain/services/background_task.service.dart';
import 'package:immich_mobile/domain/services/store.service.dart';
import 'package:immich_mobile/entities/store.entity.dart';
import 'package:immich_mobile/infrastructure/repositories/db.repository.dart';
import 'package:immich_mobile/infrastructure/repositories/settings.repository.dart';
import 'package:immich_mobile/infrastructure/repositories/store.repository.dart';
import 'package:immich_mobile/platform/background_task_api.g.dart';
import 'package:immich_mobile/repositories/upload.repository.dart';
import 'package:immich_mobile/services/foreground_upload.service.dart';
import 'package:mocktail/mocktail.dart';

import '../fixtures/asset.stub.dart';
import '../infrastructure/repository.mock.dart';
import '../mocks/asset_entity.mock.dart';
import '../mocks/background_task_host.mock.dart';
import '../repository.mocks.dart';

void main() {
  late ForegroundUploadService sut;
  late MockUploadRepository mockUploadRepository;
  late MockStorageRepository mockStorageRepository;
  late MockAssetMediaRepository mockAssetMediaRepository;
  late Drift db;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async => 'test',
    );
    db = Drift(DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true));
    await StoreService.init(storeRepository: DriftStoreRepository(db));
    await SettingsRepository.ensureInitialized(db);

    await Store.put(StoreKey.serverEndpoint, 'http://demo.immich.app');
    await Store.put(StoreKey.deviceId, 'device-id');

    registerFallbackValue(File('file'));
    registerFallbackValue(<String, String>{});
    registerFallbackValue(DateTime.utc(2000));
  });

  setUp(() {
    mockUploadRepository = MockUploadRepository();
    mockStorageRepository = MockStorageRepository();
    mockAssetMediaRepository = MockAssetMediaRepository();

    sut = ForegroundUploadService(mockUploadRepository, mockStorageRepository, mockAssetMediaRepository);
    when(
      () => mockUploadRepository.preflightLocalAssetIdentity(
        assetId: any(named: 'assetId'),
        localAssetId: any(named: 'localAssetId'),
        deviceId: any(named: 'deviceId'),
        size: any(named: 'size'),
        modifiedAt: any(named: 'modifiedAt'),
        originalFileName: any(named: 'originalFileName'),
        fields: any(named: 'fields'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer((_) async => null);
    when(
      () => mockUploadRepository.ensureAssetChecksum(
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
      () => mockUploadRepository.preflightResumableTerminal(
        checksum: any(named: 'checksum'),
        uploadId: any(named: 'uploadId'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer((_) async => null);
  });

  List<Map<String, String>> captureFields() {
    final captured = <Map<String, String>>[];
    when(
      () => mockUploadRepository.uploadFile(
        file: any(named: 'file'),
        originalFileName: any(named: 'originalFileName'),
        fields: any(named: 'fields'),
        cancelToken: any(named: 'cancelToken'),
        onProgress: any(named: 'onProgress'),
        onProcessing: any(named: 'onProcessing'),
        logContext: any(named: 'logContext'),
        checksum: any(named: 'checksum'),
        uploadId: any(named: 'uploadId'),
      ),
    ).thenAnswer((invocation) async {
      final fields = invocation.namedArguments[#fields] as Map<String, String>;
      captured.add(Map.of(fields));
      return UploadResult.success(remoteAssetId: 'remote-${captured.length}');
    });
    return captured;
  }

  List<String> captureOriginalFileNames() {
    final captured = <String>[];
    when(
      () => mockUploadRepository.uploadFile(
        file: any(named: 'file'),
        originalFileName: any(named: 'originalFileName'),
        fields: any(named: 'fields'),
        cancelToken: any(named: 'cancelToken'),
        onProgress: any(named: 'onProgress'),
        onProcessing: any(named: 'onProcessing'),
        logContext: any(named: 'logContext'),
        checksum: any(named: 'checksum'),
        uploadId: any(named: 'uploadId'),
      ),
    ).thenAnswer((invocation) async {
      captured.add(invocation.namedArguments[#originalFileName] as String);
      return UploadResult.success(remoteAssetId: 'remote-${captured.length}');
    });
    return captured;
  }

  test('shared upload continues after background expiry without reporting a false failure', () async {
    final host = FakeBackgroundTaskHost();
    final background = BackgroundTaskService(host);
    addTearDown(background.dispose);
    sut = ForegroundUploadService(
      mockUploadRepository,
      mockStorageRepository,
      mockAssetMediaRepository,
      backgroundTaskService: background,
    );
    final root = await Directory.systemTemp.createTemp('background-upload-');
    addTearDown(() => root.delete(recursive: true));
    final file = File('${root.path}/photo.jpg')..writeAsBytesSync([1, 2, 3]);
    when(() => mockStorageRepository.clearCache()).thenAnswer((_) async {});
    when(() => mockUploadRepository.hashShareIntentFile(file)).thenAnswer((_) async => 'checksum');
    final started = Completer<void>();
    var attempts = 0;
    when(
      () => mockUploadRepository.uploadFile(
        file: any(named: 'file'),
        originalFileName: any(named: 'originalFileName'),
        fields: any(named: 'fields'),
        cancelToken: any(named: 'cancelToken'),
        onProgress: any(named: 'onProgress'),
        onProcessing: any(named: 'onProcessing'),
        logContext: any(named: 'logContext'),
        checksum: any(named: 'checksum'),
        uploadId: any(named: 'uploadId'),
      ),
    ).thenAnswer((invocation) async {
      attempts++;
      if (attempts == 1) {
        started.complete();
        await (invocation.namedArguments[#cancelToken] as Completer<void>).future;
        return UploadResult.cancelled();
      }
      return UploadResult.success(remoteAssetId: 'uploaded');
    });
    final successes = <String>[];
    final errors = <String>[];
    final work = sut.uploadShareIntent(
      [file],
      onSuccess: (_, id) => successes.add(id),
      onError: (_, e) => errors.add(e),
    );
    await started.future;
    await background.onBackground();
    final taskId = host.active.single;
    host.active.remove(taskId);
    await background.onExpired(taskId);
    await Future<void>.delayed(Duration.zero);
    expect(successes, isEmpty);
    expect(errors, isEmpty);
    expect(attempts, 1);
    await background.onForeground();
    await work;
    expect(successes, ['uploaded']);
    expect(errors, isEmpty);
    expect(attempts, 2);
    expect(host.active, isEmpty);
    expect(host.modes, [BackgroundTaskMode.continued, BackgroundTaskMode.continued]);
  });

  group('uploadSingleAsset', () {
    test('processing releases transfer slots without reporting success', () async {
      final directory = await Directory.systemTemp.createTemp('upload-processing-');
      addTearDown(() => directory.delete(recursive: true));
      final files = List.generate(5, (index) => File('${directory.path}/photo-$index.jpg')..writeAsBytesSync([index]));
      when(() => mockStorageRepository.clearCache()).thenAnswer((_) async {});
      when(() => mockUploadRepository.hashShareIntentFile(any())).thenAnswer((_) async => 'checksum');
      final processing = <String, void Function()>{};
      final completed = Completer<void>();
      final successes = <String>[];
      when(
        () => mockUploadRepository.uploadFile(
          file: any(named: 'file'),
          originalFileName: any(named: 'originalFileName'),
          fields: any(named: 'fields'),
          cancelToken: any(named: 'cancelToken'),
          onProgress: any(named: 'onProgress'),
          onProcessing: any(named: 'onProcessing'),
          logContext: any(named: 'logContext'),
          checksum: any(named: 'checksum'),
          uploadId: any(named: 'uploadId'),
        ),
      ).thenAnswer((invocation) async {
        final name = invocation.namedArguments[#originalFileName] as String;
        final token = invocation.namedArguments[#cancelToken] as Completer<void>;
        processing[name] = invocation.namedArguments[#onProcessing] as void Function()? ?? () {};
        await Future.any([completed.future, token.future]);
        return token.isCompleted ? UploadResult.cancelled() : UploadResult.success(remoteAssetId: name);
      });
      final work = sut.uploadShareIntent(files, onSuccess: (_, id) => successes.add(id));
      try {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        expect(processing, hasLength(3));
        for (final notify in processing.values.toList()) {
          notify();
          notify();
        }
        await Future<void>.delayed(const Duration(milliseconds: 100));
        expect(processing, hasLength(5));
        expect(successes, isEmpty);
        completed.complete();
        await work;
        expect(successes, hasLength(5));
      } finally {
        sut.cancel();
        await work;
      }
    });

    test('overlapping batches share the transfer limit and cancellation drains queued files', () async {
      final directory = await Directory.systemTemp.createTemp('upload-batches-');
      addTearDown(() => directory.delete(recursive: true));
      final files = List.generate(6, (index) => File('${directory.path}/photo-$index.jpg')..writeAsBytesSync([index]));
      when(() => mockStorageRepository.clearCache()).thenAnswer((_) async {});
      when(() => mockUploadRepository.hashShareIntentFile(any())).thenAnswer((_) async => 'checksum');
      final started = <String>[];
      when(
        () => mockUploadRepository.uploadFile(
          file: any(named: 'file'),
          originalFileName: any(named: 'originalFileName'),
          fields: any(named: 'fields'),
          cancelToken: any(named: 'cancelToken'),
          onProgress: any(named: 'onProgress'),
          onProcessing: any(named: 'onProcessing'),
          logContext: any(named: 'logContext'),
          checksum: any(named: 'checksum'),
          uploadId: any(named: 'uploadId'),
        ),
      ).thenAnswer((invocation) async {
        started.add(invocation.namedArguments[#originalFileName] as String);
        await (invocation.namedArguments[#cancelToken] as Completer<void>).future;
        return UploadResult.cancelled();
      });
      final work = Future.wait([
        sut.uploadShareIntent(files.take(3).toList()),
        sut.uploadShareIntent(files.skip(3).toList()),
      ]);
      try {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        expect(started, hasLength(3));
      } finally {
        await sut.cancelAndDrain();
        await work;
      }
      expect(started, hasLength(3));
    });

    test('device tuple match returns before hashing or opening the asset', () async {
      final asset = LocalAssetStub.image1.copyWith(contentSize: 1234);
      when(
        () => mockUploadRepository.preflightLocalAssetIdentity(
          assetId: asset.id,
          localAssetId: asset.localId!,
          deviceId: 'device-id',
          size: 1234,
          modifiedAt: asset.updatedAt,
          originalFileName: asset.name,
          fields: any(named: 'fields'),
        ),
      ).thenAnswer(
        (_) async =>
            UploadResult.success(remoteAssetId: '44444444-4444-4444-8444-444444444444', assetStatus: 'duplicate'),
      );
      String? linkedRemoteID;

      await sut.uploadSingleAsset(
        asset,
        null,
        callbacks: UploadCallbacks(onSuccess: (_, remoteID) => linkedRemoteID = remoteID),
      );

      expect(linkedRemoteID, '44444444-4444-4444-8444-444444444444');
      verifyNever(
        () => mockUploadRepository.ensureAssetChecksum(
          any(),
          any(),
          contentMd5: any(named: 'contentMd5'),
          contentSize: any(named: 'contentSize'),
          hashAlgorithm: any(named: 'hashAlgorithm'),
          hashedModifiedAt: any(named: 'hashedModifiedAt'),
          modifiedAt: any(named: 'modifiedAt'),
        ),
      );
      verifyNever(() => mockStorageRepository.getAssetEntityForAsset(asset));
    });

    test('uploads Live Photo motion hidden before the still association', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final asset = LocalAssetStub.image1;
      final mockEntity = MockAssetEntity();
      final stillFile = File('/path/to/still.heic');
      final videoFile = File('/path/to/motion.mov');

      when(() => mockEntity.isLivePhoto).thenReturn(true);
      when(() => mockStorageRepository.getAssetEntityForAsset(asset)).thenAnswer((_) async => mockEntity);
      when(() => mockStorageRepository.isAssetAvailableLocally(asset.id)).thenAnswer((_) async => true);
      when(() => mockStorageRepository.getFileForAsset(asset.id)).thenAnswer((_) async => stillFile);
      when(() => mockStorageRepository.getMotionFileForAsset(asset)).thenAnswer((_) async => videoFile);
      when(() => mockAssetMediaRepository.getOriginalFilename(asset.id)).thenAnswer((_) async => 'live.heic');
      when(() => mockUploadRepository.hashShareIntentFile(videoFile)).thenAnswer((_) async => 'motion-md5');

      final captured = captureFields();

      await sut.uploadSingleAsset(asset, null, callbacks: const UploadCallbacks());

      expect(captured, hasLength(2));
      expect(captured[0]['visibility'], 'hidden');
      expect(captured[0]['livePhotoRole'], 'motion');
      expect(captured[1]['livePhotoVideoId'], 'remote-1');
      expect(captured[1].containsKey('visibility'), isFalse);
      verifyNever(
        () => mockUploadRepository.createPMLiveBundle(
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

    test('Live Photo releases its motion slot and reacquires before uploading the still', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final directory = await Directory.systemTemp.createTemp('live-processing-');
      addTearDown(() => directory.delete(recursive: true));
      final still = File('${directory.path}/live.heic')..writeAsBytesSync([1]);
      final motion = File('${directory.path}/motion.mov')..writeAsBytesSync([2]);
      final others = List.generate(3, (index) => File('${directory.path}/other-$index.jpg')..writeAsBytesSync([index]));
      final asset = LocalAssetStub.image1;
      final entity = MockAssetEntity();
      when(() => entity.isLivePhoto).thenReturn(true);
      when(() => mockStorageRepository.clearCache()).thenAnswer((_) async {});
      when(() => mockStorageRepository.getAssetEntityForAsset(asset)).thenAnswer((_) async => entity);
      when(() => mockStorageRepository.isAssetAvailableLocally(asset.id)).thenAnswer((_) async => true);
      when(() => mockStorageRepository.getFileForAsset(asset.id)).thenAnswer((_) async => still);
      when(() => mockStorageRepository.getMotionFileForAsset(asset)).thenAnswer((_) async => motion);
      when(() => mockAssetMediaRepository.getOriginalFilename(asset.id)).thenAnswer((_) async => 'live.heic');
      when(() => mockUploadRepository.hashShareIntentFile(any())).thenAnswer((_) async => 'checksum');
      final processing = <String, void Function()>{};
      final finishes = <String, Completer<void>>{};
      final fields = <String, Map<String, String>>{};
      when(
        () => mockUploadRepository.uploadFile(
          file: any(named: 'file'),
          originalFileName: any(named: 'originalFileName'),
          fields: any(named: 'fields'),
          cancelToken: any(named: 'cancelToken'),
          onProgress: any(named: 'onProgress'),
          onProcessing: any(named: 'onProcessing'),
          logContext: any(named: 'logContext'),
          checksum: any(named: 'checksum'),
          uploadId: any(named: 'uploadId'),
        ),
      ).thenAnswer((invocation) async {
        final name = invocation.namedArguments[#originalFileName] as String;
        final token = invocation.namedArguments[#cancelToken] as Completer<void>;
        processing[name] = invocation.namedArguments[#onProcessing] as void Function();
        fields[name] = invocation.namedArguments[#fields] as Map<String, String>;
        final finish = finishes[name] = Completer<void>();
        await Future.any([finish.future, token.future]);
        return token.isCompleted ? UploadResult.cancelled() : UploadResult.success(remoteAssetId: name);
      });
      final manual = sut.uploadManual([asset]);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      final shared = sut.uploadShareIntent(others);
      try {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        expect(processing, hasLength(3));
        processing['live.mov']!();
        await Future<void>.delayed(const Duration(milliseconds: 100));
        expect(processing, hasLength(4));
        expect(processing.containsKey('live.heic'), isFalse);
        finishes['live.mov']!.complete();
        await Future<void>.delayed(const Duration(milliseconds: 100));
        expect(processing.containsKey('live.heic'), isFalse);
        processing.entries.firstWhere((entry) => entry.key.startsWith('other')).value();
        await Future<void>.delayed(const Duration(milliseconds: 100));
        expect(fields['live.heic']?['livePhotoVideoId'], 'live.mov');
        for (final finish in finishes.values) {
          if (!finish.isCompleted) {
            finish.complete();
          }
        }
        await Future.wait([manual, shared]);
        verify(() => mockStorageRepository.clearCache()).called(1);
      } finally {
        await sut.cancelAndDrain();
        await Future.wait([manual, shared]);
      }
    });

    test(
      'removes the canonical pmlive after a terminal created result',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        final root = await Directory.systemTemp.createTemp('foreground-pmlive-terminal-');
        addTearDown(() => root.delete(recursive: true));
        final asset = LocalAssetStub.image1;
        final mockEntity = MockAssetEntity();
        final stillFile = File('${root.path}/still.heic')..writeAsBytesSync(const [1]);
        final videoFile = File('${root.path}/motion.mov')..writeAsBytesSync(const [2]);
        final bundle = File('${root.path}/asset.pmlive')..writeAsBytesSync(const [3]);

        when(() => mockEntity.isLivePhoto).thenReturn(true);
        when(() => mockStorageRepository.getAssetEntityForAsset(asset)).thenAnswer((_) async => mockEntity);
        when(() => mockStorageRepository.isAssetAvailableLocally(asset.id)).thenAnswer((_) async => true);
        when(() => mockStorageRepository.getFileForAsset(asset.id)).thenAnswer((_) async => stillFile);
        when(() => mockStorageRepository.getMotionFileForAsset(asset)).thenAnswer((_) async => videoFile);
        when(() => mockAssetMediaRepository.getOriginalFilename(asset.id)).thenAnswer((_) async => 'live.heic');
        when(
          () => mockUploadRepository.createPMLiveBundle(
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
          () => mockUploadRepository.uploadFile(
            file: any(named: 'file'),
            originalFileName: any(named: 'originalFileName'),
            fields: any(named: 'fields'),
            cancelToken: any(named: 'cancelToken'),
            onProgress: any(named: 'onProgress'),
            logContext: any(named: 'logContext'),
            checksum: any(named: 'checksum'),
            uploadId: any(named: 'uploadId'),
          ),
        ).thenAnswer((_) async => UploadResult.success(remoteAssetId: 'remote-id', assetStatus: 'created'));

        await sut.uploadSingleAsset(asset, null, callbacks: const UploadCallbacks());

        expect(bundle.existsSync(), isFalse);
      },
      skip: 'PMLive generation was removed; retained only as a historical cleanup regression',
    );

    test(
      'keeps the canonical pmlive after a retryable result',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        final root = await Directory.systemTemp.createTemp('foreground-pmlive-retry-');
        addTearDown(() => root.delete(recursive: true));
        final asset = LocalAssetStub.image1;
        final mockEntity = MockAssetEntity();
        final stillFile = File('${root.path}/still.heic')..writeAsBytesSync(const [1]);
        final videoFile = File('${root.path}/motion.mov')..writeAsBytesSync(const [2]);
        final bundle = File('${root.path}/asset.pmlive')..writeAsBytesSync(const [3]);

        when(() => mockEntity.isLivePhoto).thenReturn(true);
        when(() => mockStorageRepository.getAssetEntityForAsset(asset)).thenAnswer((_) async => mockEntity);
        when(() => mockStorageRepository.isAssetAvailableLocally(asset.id)).thenAnswer((_) async => true);
        when(() => mockStorageRepository.getFileForAsset(asset.id)).thenAnswer((_) async => stillFile);
        when(() => mockStorageRepository.getMotionFileForAsset(asset)).thenAnswer((_) async => videoFile);
        when(() => mockAssetMediaRepository.getOriginalFilename(asset.id)).thenAnswer((_) async => 'live.heic');
        when(
          () => mockUploadRepository.createPMLiveBundle(
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
          () => mockUploadRepository.uploadFile(
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

        await sut.uploadSingleAsset(asset, null, callbacks: const UploadCallbacks());

        expect(bundle.existsSync(), isTrue);
      },
      skip: 'PMLive generation was removed; retained only as a historical cleanup regression',
    );

    test('should not set visibility for a regular photo', () async {
      final asset = LocalAssetStub.image1;
      final mockEntity = MockAssetEntity();
      final stillFile = File('/path/to/photo.jpg');

      when(() => mockEntity.isLivePhoto).thenReturn(false);
      when(() => mockStorageRepository.getAssetEntityForAsset(asset)).thenAnswer((_) async => mockEntity);
      when(() => mockStorageRepository.isAssetAvailableLocally(asset.id)).thenAnswer((_) async => true);
      when(() => mockStorageRepository.getFileForAsset(asset.id)).thenAnswer((_) async => stillFile);
      when(() => mockAssetMediaRepository.getOriginalFilename(asset.id)).thenAnswer((_) async => 'photo.jpg');

      final captured = captureFields();

      await sut.uploadSingleAsset(asset, null, callbacks: const UploadCallbacks());

      expect(captured, hasLength(1));
      expect(captured[0].containsKey('visibility'), isFalse);
    });

    test('normal iOS foreground retry reacquires a fresh temp with the same resumable identity', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final root = await Directory.systemTemp.createTemp('foreground-normal-restart-');
      addTearDown(() => root.delete(recursive: true));
      final asset = LocalAssetStub.image1;
      final mockEntity = MockAssetEntity();
      final first = File('${root.path}/first-temp.jpg')..writeAsBytesSync(const [1, 2, 3]);
      final rebound = File('${root.path}/rebound-temp.jpg')..writeAsBytesSync(const [1, 2, 3]);
      var sourceCall = 0;
      final uploads = <File>[];
      when(() => mockEntity.isLivePhoto).thenReturn(false);
      when(() => mockStorageRepository.getAssetEntityForAsset(asset)).thenAnswer((_) async => mockEntity);
      when(() => mockStorageRepository.isAssetAvailableLocally(asset.id)).thenAnswer((_) async => true);
      when(
        () => mockStorageRepository.getFileForAsset(asset.id),
      ).thenAnswer((_) async => sourceCall++ == 0 ? first : rebound);
      when(() => mockAssetMediaRepository.getOriginalFilename(asset.id)).thenAnswer((_) async => 'photo.jpg');
      when(
        () => mockUploadRepository.uploadFile(
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

      await sut.uploadSingleAsset(asset, null, callbacks: const UploadCallbacks());
      expect(first.existsSync(), isFalse);
      await sut.uploadSingleAsset(asset, null, callbacks: const UploadCallbacks());

      expect(uploads.map((file) => file.path), [first.path, rebound.path]);
      verify(
        () => mockUploadRepository.uploadFile(
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

    test('terminal persisted attempt returns before foreground resolves local media', () async {
      final root = await Directory.systemTemp.createTemp('foreground-terminal-preflight-');
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
                      'asset_id': '11111111-1111-4111-8111-111111111111',
                      'asset_status': 'duplicate',
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
      final terminalService = ForegroundUploadService(repository, mockStorageRepository, mockAssetMediaRepository);
      String? remoteId;

      await terminalService.uploadSingleAsset(
        asset,
        null,
        callbacks: UploadCallbacks(onSuccess: (_, value) => remoteId = value),
      );

      expect(remoteId, '11111111-1111-4111-8111-111111111111');
      verifyNever(() => mockStorageRepository.getAssetEntityForAsset(asset));
      verifyNever(() => mockStorageRepository.getFileForAsset(asset.id));
      verifyNever(() => mockStorageRepository.getMotionFileForAsset(asset));
    });

    test('corrects the extension when iOS returns a rendered file for a .dng asset', () async {
      final asset = LocalAssetStub.image1;
      final mockEntity = MockAssetEntity();
      final stillFile = File('/path/to/IMG_6499.jpg');

      when(() => mockEntity.isLivePhoto).thenReturn(false);
      when(() => mockStorageRepository.getAssetEntityForAsset(asset)).thenAnswer((_) async => mockEntity);
      when(() => mockStorageRepository.isAssetAvailableLocally(asset.id)).thenAnswer((_) async => true);
      when(() => mockStorageRepository.getFileForAsset(asset.id)).thenAnswer((_) async => stillFile);
      when(() => mockAssetMediaRepository.getOriginalFilename(asset.id)).thenAnswer((_) async => 'IMG_6499.dng');

      final names = captureOriginalFileNames();

      await sut.uploadSingleAsset(asset, null, callbacks: const UploadCallbacks());

      expect(names, equals(['IMG_6499.jpg']));
    });

    test('keeps the .dng extension for a genuine RAW original', () async {
      final asset = LocalAssetStub.image1;
      final mockEntity = MockAssetEntity();
      final stillFile = File('/path/to/IMG_5210.dng');

      when(() => mockEntity.isLivePhoto).thenReturn(false);
      when(() => mockStorageRepository.getAssetEntityForAsset(asset)).thenAnswer((_) async => mockEntity);
      when(() => mockStorageRepository.isAssetAvailableLocally(asset.id)).thenAnswer((_) async => true);
      when(() => mockStorageRepository.getFileForAsset(asset.id)).thenAnswer((_) async => stillFile);
      when(() => mockAssetMediaRepository.getOriginalFilename(asset.id)).thenAnswer((_) async => 'IMG_5210.dng');

      final names = captureOriginalFileNames();

      await sut.uploadSingleAsset(asset, null, callbacks: const UploadCallbacks());

      expect(names, equals(['IMG_5210.dng']));
    });

    test('borrows the extension from the asset name for an extensionless name (DJI/Fusion)', () async {
      final asset = LocalAssetStub.image1;
      final mockEntity = MockAssetEntity();
      final stillFile = File('/path/to/DJI_0001');

      when(() => mockEntity.isLivePhoto).thenReturn(false);
      when(() => mockStorageRepository.getAssetEntityForAsset(asset)).thenAnswer((_) async => mockEntity);
      when(() => mockStorageRepository.isAssetAvailableLocally(asset.id)).thenAnswer((_) async => true);
      when(() => mockStorageRepository.getFileForAsset(asset.id)).thenAnswer((_) async => stillFile);
      when(() => mockAssetMediaRepository.getOriginalFilename(asset.id)).thenAnswer((_) async => 'DJI_0001');

      final names = captureOriginalFileNames();

      await sut.uploadSingleAsset(asset, null, callbacks: const UploadCallbacks());

      expect(names, equals(['DJI_0001.jpg']));
    });
  });
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
