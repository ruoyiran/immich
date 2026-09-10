import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:immich_mobile/domain/models/album/local_album.model.dart';
import 'package:immich_mobile/domain/models/asset/base_asset.model.dart';
import 'package:immich_mobile/domain/services/local_sync.service.dart';
import 'package:immich_mobile/platform/native_sync_api.g.dart';
import 'package:mocktail/mocktail.dart';

import '../../infrastructure/repository.mock.dart';
import '../../service.mocks.dart';

void main() {
  final dbAlbum = LocalAlbum(
    id: 'album-1',
    name: 'Camera',
    updatedAt: DateTime.fromMillisecondsSinceEpoch(100 * 1000),
    assetCount: 0,
  );

  final deviceAlbum = PlatformAlbum(
    id: 'album-1',
    name: 'Camera',
    updatedAt: 200,
    isCloud: false,
    assetCount: 1,
  );

  setUpAll(() {
    registerFallbackValue(dbAlbum);
  });

  group('LocalSyncService - PlatformAsset conversion', () {
    test('toLocalAsset uses correct updatedAt timestamp', () {
      final platformAsset = PlatformAsset(
        id: 'test-id',
        name: 'test.jpg',
        type: AssetType.image.index,
        durationMs: 0,
        orientation: 0,
        isFavorite: false,
        createdAt: 1700000000,
        updatedAt: 1732000000,
        playbackStyle: PlatformAssetPlaybackStyle.image,
      );

      final localAsset = platformAsset.toLocalAsset();

      expect(localAsset.createdAt.millisecondsSinceEpoch ~/ 1000, 1700000000);
      expect(localAsset.updatedAt.millisecondsSinceEpoch ~/ 1000, 1732000000);
      expect(localAsset.updatedAt, isNot(localAsset.createdAt));
    });
  });

  group('LocalSyncService - fullSync checkpoint', () {
    late MockLocalAlbumRepository mockAlbumRepo;
    late MockDriftLocalAssetRepository mockAssetRepo;
    late MockNativeSyncApi mockNativeSyncApi;
    late Completer<void> cancellation;

    setUp(() {
      mockAlbumRepo = MockLocalAlbumRepository();
      mockAssetRepo = MockDriftLocalAssetRepository();
      mockNativeSyncApi = MockNativeSyncApi();
      cancellation = Completer<void>();

      when(() => mockNativeSyncApi.cancelSync()).thenAnswer((_) async {});
      when(() => mockAlbumRepo.getAll(sortBy: any(named: 'sortBy'))).thenAnswer((_) async => []);
    });

    LocalSyncService createSut() => LocalSyncService(
      localAlbumRepository: mockAlbumRepo,
      localAssetRepository: mockAssetRepo,
      nativeSyncApi: mockNativeSyncApi,
      cancellation: cancellation,
    );

    test('checkpoints when sync completes without cancellation', () async {
      when(() => mockNativeSyncApi.getAlbums()).thenAnswer((_) async => []);

      await createSut().fullSync();

      verify(() => mockNativeSyncApi.checkpointSync()).called(1);
    });

    test('skips checkpoint when cancelled before the sync', () async {
      when(() => mockNativeSyncApi.getAlbums()).thenAnswer((_) async => []);

      final sut = createSut();
      cancellation.complete();
      await sut.fullSync();

      verifyNever(() => mockNativeSyncApi.checkpointSync());
    });

    test('skips checkpoint when cancelled mid-diff', () async {
      when(() => mockNativeSyncApi.getAlbums()).thenAnswer((_) async => [deviceAlbum]);
      when(() => mockAlbumRepo.getAll(sortBy: any(named: 'sortBy'))).thenAnswer((_) async => [dbAlbum]);
      when(() => mockNativeSyncApi.getAssetsCountSince(any(), any())).thenAnswer((_) {
        cancellation.complete();
        return Future.value(1);
      });
      when(() => mockNativeSyncApi.getAssetsForAlbum(any(), updatedTimeCond: any(named: 'updatedTimeCond')))
          .thenAnswer((_) async => []);
      when(() => mockAlbumRepo.upsert(any(), toUpsert: any(named: 'toUpsert'))).thenAnswer((_) async {});

      await createSut().fullSync();

      verifyNever(() => mockNativeSyncApi.checkpointSync());
    });

    test('skips checkpoint when native throws SYNC_CANCELLED mid-diff', () async {
      when(() => mockNativeSyncApi.getAlbums()).thenAnswer((_) async => [deviceAlbum]);
      when(() => mockAlbumRepo.getAll(sortBy: any(named: 'sortBy'))).thenAnswer((_) async => [dbAlbum]);
      when(() => mockNativeSyncApi.getAssetsCountSince(any(), any())).thenAnswer((_) async => 1);
      when(() => mockNativeSyncApi.getAssetsForAlbum(any(), updatedTimeCond: any(named: 'updatedTimeCond')))
          .thenAnswer((_) {
        cancellation.complete();
        throw PlatformException(code: 'SYNC_CANCELLED', message: 'Sync cancelled');
      });
      // fullDiff re-queries without the time condition; it must also bail out.
      when(() => mockNativeSyncApi.getAssetsForAlbum(any())).thenThrow(
        PlatformException(code: 'SYNC_CANCELLED', message: 'Sync cancelled'),
      );

      await createSut().fullSync();

      verifyNever(() => mockNativeSyncApi.checkpointSync());
    });
  });
}
