import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:immich_mobile/domain/models/asset/base_asset.model.dart';
import 'package:immich_mobile/domain/models/settings_key.dart';
import 'package:immich_mobile/domain/models/store.model.dart';
import 'package:immich_mobile/domain/services/store.service.dart';
import 'package:immich_mobile/infrastructure/repositories/settings.repository.dart';
import 'package:immich_mobile/infrastructure/repositories/store.repository.dart';
import 'package:immich_mobile/presentation/widgets/images/image_provider.dart';
import 'package:immich_mobile/presentation/widgets/images/local_image_provider.dart';
import 'package:immich_mobile/presentation/widgets/images/remote_image_provider.dart';

import '../../../medium/repository_context.dart';
import '../../../unit/factories/local_asset_factory.dart';
import '../../../unit/factories/remote_asset_factory.dart';

class _StubCompleter extends ImageStreamCompleter {}

void main() {
  late ImageCache cache;
  late int loads;

  ImageStreamCompleter load() {
    loads++;
    return _StubCompleter();
  }

  setUp(() {
    cache = ImageCache();
    loads = 0;
  });

  group('LocalFullImageProvider.previewTargetSize', () {
    const box = Size(1179, 2556);
    const cases = <(String, Size, int?, int?, bool, Size)>[
      ('normal', box, 4032, 3024, true, box),
      ('missing dimensions', box, null, null, true, box),
      ('invalid dimensions', box, 1000, 0, true, box),
      ('long final preview', box, 1000, 30000, true, Size(16384 / 30, 16384)),
      ('long first preview', box, 30000, 1000, false, Size(2556, 2556 / 30)),
      ('ultra-thin preview', box, 10, 50000, false, Size(1, 2556)),
      ('small source', box, 50, 2000, true, Size(50, 2000)),
      ('at limit', Size(16384, 100), 1000, 1000, true, Size(16384, 100)),
      ('over limit', Size(16385, 100), 1000, 1000, true, Size(1000, 1000)),
    ];

    for (final (name, box, width, height, previewIsFinal, expected) in cases) {
      test(name, () {
        final actual = LocalFullImageProvider.previewTargetSize(
          box.width,
          box.height,
          width,
          height,
          previewIsFinal: previewIsFinal,
        );
        expect(actual.width, closeTo(expected.width, 1e-6));
        expect(actual.height, closeTo(expected.height, 1e-6));
      });
    }
  });

  group('LocalFullImageProvider equality', () {
    LocalFullImageProvider make({int? width, int? height, bool forceOriginal = false}) => LocalFullImageProvider(
      id: 'a',
      assetType: AssetType.image,
      size: const Size(100, 200),
      isAnimated: false,
      width: width,
      height: height,
      forceOriginal: forceOriginal,
    );

    test('uses dimensions in the cache key', () {
      final a = make(width: 100, height: 200);
      final b = make(width: 100, height: 200);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a == make(width: 200, height: 100), isFalse);
      expect(a == make(width: 100, height: 200, forceOriginal: true), isFalse);
    });
  });

  group('LocalThumbProvider caching', () {
    test('editing on device re-renders the thumbnail', () {
      cache.putIfAbsent(LocalThumbProvider(id: 'asset-1', assetType: AssetType.image, checksum: 'before'), load);
      cache.putIfAbsent(LocalThumbProvider(id: 'asset-1', assetType: AssetType.image, checksum: 'after'), load);

      expect(loads, 2);
    });

    test('an unchanged thumbnail still comes from the cache', () {
      cache.putIfAbsent(LocalThumbProvider(id: 'asset-1', assetType: AssetType.image, checksum: 'same'), load);
      cache.putIfAbsent(LocalThumbProvider(id: 'asset-1', assetType: AssetType.image, checksum: 'same'), load);

      expect(loads, 1);
    });

    // The rehash clears the checksum before writing the new one, so the tile has to
    // follow that step too or it waits for the hash to land before showing the edit.
    test('re-renders while the checksum is still being recomputed', () {
      cache.putIfAbsent(LocalThumbProvider(id: 'asset-1', assetType: AssetType.image, checksum: 'before'), load);
      cache.putIfAbsent(LocalThumbProvider(id: 'asset-1', assetType: AssetType.image), load);

      expect(loads, 2);
    });

    test('stays cached while the checksum is missing', () {
      cache.putIfAbsent(LocalThumbProvider(id: 'asset-1', assetType: AssetType.image), load);
      cache.putIfAbsent(LocalThumbProvider(id: 'asset-1', assetType: AssetType.image), load);

      expect(loads, 1);
    });
  });

  group('factories', () {
    test('thumbnails are keyed by the asset checksum', () {
      final asset = LocalAssetFactory.create().copyWith(checksum: 'abc');

      final provider = getThumbnailImageProvider(asset)! as LocalThumbProvider;

      expect(provider.checksum, 'abc');
    });
  });

  group('thumbnail source selection', () {
    late MediumRepositoryContext ctx;
    late SettingsRepository settings;

    setUp(() async {
      ctx = MediumRepositoryContext();
      await StoreService.init(storeRepository: DriftStoreRepository(ctx.db), listenUpdates: false);
      await StoreService.I.put(StoreKey.serverEndpoint, 'http://localhost:3000');
      settings = await SettingsRepository.ensureInitialized(ctx.db);
      await settings.write(SettingsKey.imagePreferRemote, true);
    });

    tearDown(() async {
      await SettingsRepository.reset();
      await StoreService.I.dispose();
      await ctx.dispose();
    });

    test('uses the local thumbnail for a remote asset with local original available', () {
      final asset = RemoteAssetFactory.create(localId: 'local-asset-1');

      final provider = getThumbnailImageProvider(asset)!;

      expect(provider, isA<LocalThumbProvider>());
      expect((provider as LocalThumbProvider).id, 'local-asset-1');
    });

    test('keeps preferring remote thumbnails when the remote thumbnail is materialized', () {
      final asset = RemoteAssetFactory.create(localId: 'local-asset-1').copyWith(thumbHash: 'thumbhash-ready');

      final provider = getThumbnailImageProvider(asset)!;

      expect(provider, isA<RemoteImageProvider>());
    });
  });

  group('LocalFullImageProvider caching', () {
    test('editing on device re-renders the full image', () {
      cache.putIfAbsent(
        LocalFullImageProvider(
          id: 'asset-1',
          assetType: AssetType.image,
          size: const Size(100, 100),
          isAnimated: false,
          checksum: 'before',
        ),
        load,
      );
      cache.putIfAbsent(
        LocalFullImageProvider(
          id: 'asset-1',
          assetType: AssetType.image,
          size: const Size(100, 100),
          isAnimated: false,
          checksum: 'after',
        ),
        load,
      );

      expect(loads, 2);
    });
  });

  group('full image source selection', () {
    late MediumRepositoryContext ctx;
    late SettingsRepository settings;

    setUp(() async {
      ctx = MediumRepositoryContext();
      settings = await SettingsRepository.ensureInitialized(ctx.db);
      await settings.write(SettingsKey.imagePreferRemote, true);
    });

    tearDown(() async {
      await SettingsRepository.reset();
      await ctx.dispose();
    });

    test('uses the local full image for a remote asset with local original available', () {
      final asset = RemoteAssetFactory.create(localId: 'local-asset-1');

      final provider = getFullImageProvider(asset, size: const Size(100, 100));

      expect(provider, isA<LocalFullImageProvider>());
      expect((provider as LocalFullImageProvider).id, 'local-asset-1');
    });

    test('passes a one-time original request to the selected provider', () {
      final localAsset = RemoteAssetFactory.create(localId: 'local-asset-1');
      final remoteAsset = RemoteAssetFactory.create();

      final localProvider = getFullImageProvider(localAsset, forceOriginal: true) as LocalFullImageProvider;
      final remoteProvider = getFullImageProvider(remoteAsset, forceOriginal: true) as RemoteFullImageProvider;

      expect(localProvider.forceOriginal, isTrue);
      expect(remoteProvider.forceOriginal, isTrue);
    });
  });
}
