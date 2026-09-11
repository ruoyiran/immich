// ignore_for_file: avoid_slow_async_io

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:immich_mobile/domain/models/asset/base_asset.model.dart';
import 'package:immich_mobile/domain/models/original_media.model.dart';
import 'package:immich_mobile/repositories/download.repository.dart';
import 'package:immich_mobile/repositories/file_media.repository.dart';
import 'package:immich_mobile/repositories/original_media_cache.repository.dart';
import 'package:immich_mobile/services/download.service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:photo_manager/photo_manager.dart' show AssetEntity;

import '../unit/factories/remote_asset_factory.dart';

class MockDownloadRepository extends Mock implements DownloadRepository {}

class MockFileMediaRepository extends Mock implements FileMediaRepository {}

class MockOriginalMediaCacheRepository extends Mock implements OriginalMediaCacheRepository {}

class MockAssetEntity extends Mock implements AssetEntity {}

void main() {
  late DownloadRepository downloads;
  late FileMediaRepository files;
  late OriginalMediaCacheRepository cache;
  late Directory temporaryDirectory;

  setUpAll(() {
    registerFallbackValue(RemoteAssetFactory.create());
    registerFallbackValue(OriginalMediaType.image);
  });

  setUp(() async {
    downloads = MockDownloadRepository();
    files = MockFileMediaRepository();
    cache = MockOriginalMediaCacheRepository();
    temporaryDirectory = await Directory.systemTemp.createTemp('immich-download-service-test-');
    when(() => downloads.getLiveVideoTasks()).thenAnswer((_) async => []);
  });

  tearDown(() async {
    if (await temporaryDirectory.exists()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  test('saves a cached original image without enqueueing another download', () async {
    final asset = RemoteAssetFactory.create(id: '77777777-7777-4777-8777-777777777777', name: 'cached.jpg');
    final cached = File('${temporaryDirectory.path}/cached.jpg')..writeAsBytesSync([1, 2, 3]);
    when(() => cache.get(asset, OriginalMediaType.image)).thenAnswer((_) async => cached);
    when(
      () => files.saveImageWithFile(
        cached.path,
        title: asset.name,
        relativePath: any(named: 'relativePath'),
      ),
    ).thenAnswer((_) async => MockAssetEntity());
    when(() => downloads.downloadAllAssets(any())).thenAnswer((_) async => [false]);
    final service = DownloadService(files, downloads, cache);

    final result = await service.downloadAllAssets([asset]);

    expect(result, [true]);
    verifyNever(() => downloads.downloadAllAssets(any()));
  });

  test('saves a cached original video without enqueueing another download', () async {
    final asset = RemoteAssetFactory.create(
      id: '88888888-8888-4888-8888-888888888888',
      name: 'cached.mp4',
      type: AssetType.video,
    );
    final cached = File('${temporaryDirectory.path}/cached.mp4')..writeAsBytesSync([4, 5, 6]);
    when(() => cache.get(asset, OriginalMediaType.video)).thenAnswer((_) async => cached);
    when(
      () => files.saveVideo(
        cached,
        title: asset.name,
        relativePath: any(named: 'relativePath'),
      ),
    ).thenAnswer((_) async => MockAssetEntity());
    when(() => downloads.downloadAllAssets(any())).thenAnswer((_) async => [false]);
    final service = DownloadService(files, downloads, cache);

    final result = await service.downloadAllAssets([asset]);

    expect(result, [true]);
    verifyNever(() => downloads.downloadAllAssets(any()));
  });

  test('falls back to the existing downloader when no reusable original is cached', () async {
    final asset = RemoteAssetFactory.create(id: '99999999-9999-4999-8999-999999999999');
    when(() => cache.get(asset, OriginalMediaType.image)).thenAnswer((_) async => null);
    when(() => downloads.downloadAllAssets([asset])).thenAnswer((_) async => [true]);
    final service = DownloadService(files, downloads, cache);

    expect(await service.downloadAllAssets([asset]), [true]);
  });

  test('falls back to the existing downloader when saving a cached original fails', () async {
    final asset = RemoteAssetFactory.create(id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', name: 'cached.jpg');
    final cached = File('${temporaryDirectory.path}/cached.jpg')..writeAsBytesSync([1, 2, 3]);
    when(() => cache.get(asset, OriginalMediaType.image)).thenAnswer((_) async => cached);
    when(
      () => files.saveImageWithFile(
        cached.path,
        title: asset.name,
        relativePath: any(named: 'relativePath'),
      ),
    ).thenAnswer((_) async => null);
    when(() => downloads.downloadAllAssets([asset])).thenAnswer((_) async => [true]);
    final service = DownloadService(files, downloads, cache);

    expect(await service.downloadAllAssets([asset]), [true]);
  });

  test('falls back to the existing downloader when the cached file disappears during lookup', () async {
    final asset = RemoteAssetFactory.create(id: 'ffffffff-ffff-4fff-8fff-ffffffffffff');
    when(() => cache.get(asset, OriginalMediaType.image)).thenThrow(const FileSystemException('gone'));
    when(() => downloads.downloadAllAssets([asset])).thenAnswer((_) async => [true]);
    final service = DownloadService(files, downloads, cache);

    expect(await service.downloadAllAssets([asset]), [true]);
  });
}
