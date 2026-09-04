import 'package:async/async.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:immich_mobile/domain/models/asset/base_asset.model.dart';
import 'package:immich_mobile/infrastructure/repositories/db.repository.dart';
import 'package:immich_mobile/infrastructure/repositories/local_album.repository.dart';

import '../../test_utils/medium_factory.dart';

void main() {
  late Drift db;
  late MediumFactory mediumFactory;

  setUp(() {
    db = Drift(DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true));
    mediumFactory = MediumFactory(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('getAll', () {
    test('watchers refresh album count and thumbnail after a local asset is deleted', () async {
      final localAlbumRepo = mediumFactory.getRepository<DriftLocalAlbumRepository>();
      final older = _localAsset('older', createdAt: DateTime(2024, 1, 1));
      final newer = _localAsset('newer', createdAt: DateTime(2024, 1, 2));
      await localAlbumRepo.upsert(mediumFactory.localAlbum(id: 'album'), toUpsert: [older, newer]);

      final albums = StreamQueue(localAlbumRepo.watchAll());
      final thumbnails = StreamQueue(localAlbumRepo.watchThumbnail('album'));
      addTearDown(albums.cancel);
      addTearDown(thumbnails.cancel);

      expect((await albums.next).single.assetCount, 2);
      expect((await thumbnails.next)?.id, newer.id);

      await db.localAssetEntity.deleteWhere((asset) => asset.id.equals(newer.id));

      expect((await albums.next).single.assetCount, 1);
      expect((await thumbnails.next)?.id, older.id);
    });
  });

  group('processDelta', () {
    // Regression for #22844: an asset moved (not copied) into another album on
    // Android was dropped. The delta reports only the asset's new album, and the
    // stale link to its old album made the per-album delete sweep wipe the asset.
    test('keeps an asset moved to another album that still holds other assets', () async {
      final localAlbumRepo = mediumFactory.getRepository<DriftLocalAlbumRepository>();

      final moved = _localAsset('moved');
      final other = _localAsset('other');
      await localAlbumRepo.upsert(mediumFactory.localAlbum(id: 'src'), toUpsert: [moved, other]);
      final anchor = _localAsset('anchor');
      await localAlbumRepo.upsert(mediumFactory.localAlbum(id: 'dst'), toUpsert: [anchor]);

      // Delta reports the moved asset now living only in the destination album.
      await localAlbumRepo.processDelta(
        updates: [moved],
        deletes: [],
        assetAlbums: {
          'moved': ['dst'],
        },
      );

      // Per-album delete sweep, as sync() runs on Android. src now physically
      // holds only `other`; dst holds `anchor` and the moved asset.
      await localAlbumRepo.syncDeletes('src', ['other']);
      await localAlbumRepo.syncDeletes('dst', ['anchor', 'moved']);

      final dstIds = (await localAlbumRepo.getAssets('dst')).map((a) => a.id).toSet();
      final srcIds = await localAlbumRepo.getAssetIds('src');

      expect(dstIds, contains('moved')); // survived and linked to the destination album
      expect(srcIds, isNot(contains('moved'))); // stale source link cleared
      expect(srcIds, contains('other')); // untouched asset stays put
    });

    test('replaces album membership with exactly what the delta reports', () async {
      final localAlbumRepo = mediumFactory.getRepository<DriftLocalAlbumRepository>();

      final moved = _localAsset('moved');
      await localAlbumRepo.upsert(mediumFactory.localAlbum(id: 'src'), toUpsert: [moved]);
      await localAlbumRepo.upsert(mediumFactory.localAlbum(id: 'dst'));

      await localAlbumRepo.processDelta(
        updates: [moved],
        deletes: [],
        assetAlbums: {
          'moved': ['dst'],
        },
      );

      expect(await localAlbumRepo.getAssetIds('src'), isEmpty);
      expect(await localAlbumRepo.getAssetIds('dst'), ['moved']);
    });
  });
}

LocalAsset _localAsset(String id, {DateTime? createdAt}) => LocalAsset(
  id: id,
  name: '$id.jpg',
  type: AssetType.image,
  createdAt: createdAt ?? DateTime(2024),
  updatedAt: DateTime(2024),
  playbackStyle: AssetPlaybackStyle.image,
  isEdited: false,
);
