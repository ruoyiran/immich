import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:immich_mobile/domain/models/album/local_album.model.dart';
import 'package:immich_mobile/domain/models/asset/base_asset.model.dart';
import 'package:immich_mobile/domain/models/place.model.dart';
import 'package:immich_mobile/domain/models/timeline.model.dart';
import 'package:immich_mobile/infrastructure/entities/exif.entity.drift.dart';
import 'package:immich_mobile/infrastructure/entities/local_asset.entity.dart';
import 'package:immich_mobile/infrastructure/entities/remote_asset.entity.drift.dart';
import 'package:immich_mobile/infrastructure/repositories/timeline.repository.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../repository_context.dart';

void main() {
  late MediumRepositoryContext ctx;
  late DriftTimelineRepository sut;

  setUpAll(() async {
    await initializeDateFormatting();
  });

  setUp(() {
    ctx = MediumRepositoryContext();
    sut = DriftTimelineRepository(ctx.db);
  });

  tearDown(() async {
    await ctx.dispose();
  });

  group('main assets', () {
    test('only includes assets synced from the server', () async {
      final user = await ctx.newUser();
      final remote = await ctx.newRemoteAsset(ownerId: user.id, checksum: 'remote-checksum');
      final album = await ctx.newLocalAlbum(backupSelection: BackupSelection.selected);
      final local = await ctx.newLocalAsset(checksum: 'local-only-checksum', createdAt: remote.createdAt);
      await ctx.newLocalAlbumAsset(albumId: album.id, assetId: local.id);

      final query = sut.main([user.id], .day);

      final buckets = await query.bucketSource().first;
      expect(buckets.fold<int>(0, (total, bucket) => total + bucket.assetCount), 1);

      final assets = await query.assetSource(0, 10);
      expect(assets, hasLength(1));
      expect(assets.single, isA<RemoteAsset>());
      expect((assets.single as RemoteAsset).id, remote.id);
    });

    test('orders assets by local capture time instead of mixed UTC storage', () async {
      final user = await ctx.newUser();
      final photo = await ctx.newRemoteAsset(
        id: 'photo-at-2103',
        ownerId: user.id,
        createdAt: DateTime.utc(2026, 8, 30, 21, 3),
      );
      final video = await ctx.newRemoteAsset(
        id: 'video-at-2113',
        ownerId: user.id,
        type: AssetType.video,
        createdAt: DateTime.utc(2026, 8, 30, 13, 13),
      );
      await (ctx.db.update(ctx.db.remoteAssetEntity)..where((row) => row.id.equals(photo.id))).write(
        RemoteAssetEntityCompanion(localDateTime: Value(DateTime(2026, 8, 30, 21, 3))),
      );
      await (ctx.db.update(ctx.db.remoteAssetEntity)..where((row) => row.id.equals(video.id))).write(
        RemoteAssetEntityCompanion(localDateTime: Value(DateTime(2026, 8, 30, 21, 13))),
      );

      final assets = await sut.main([user.id], .day).assetSource(0, 10);

      expect(assets.map((asset) => asset.id), [video.id, photo.id]);
    });

    test('uses the local capture-time index for paginated timeline reads', () async {
      final user = await ctx.newUser();

      final plan = await ctx.db
          .customSelect(
            '''
EXPLAIN QUERY PLAN
SELECT rae.id
FROM remote_asset_entity rae
LEFT JOIN stack_entity se ON rae.stack_id = se.id
WHERE rae.deleted_at IS NULL
  AND rae.visibility = 0
  AND rae.owner_id = ?
  AND (rae.stack_id IS NULL OR rae.id = se.primary_asset_id)
ORDER BY rae.local_date_time DESC, rae.id DESC
LIMIT 101 OFFSET 10000
''',
            variables: [Variable.withString(user.id)],
          )
          .get();
      final details = plan.map((row) => row.read<String>('detail')).join('\n');

      expect(details, contains('idx_remote_asset_owner_visibility_deleted_local_date_time'));
      expect(details, isNot(contains('USE TEMP B-TREE FOR ORDER BY')));
    });

    test('groups trimmed unique cities in a deterministic order for each day bucket', () async {
      final user = await ctx.newUser();
      final day = DateTime.utc(2026, 9, 14, 12);
      final berlin = await ctx.newRemoteAsset(ownerId: user.id, createdAt: day);
      final shanghai = await ctx.newRemoteAsset(ownerId: user.id, createdAt: day.add(const Duration(hours: 1)));
      final duplicateShanghai = await ctx.newRemoteAsset(
        ownerId: user.id,
        createdAt: day.add(const Duration(hours: 2)),
      );
      final blank = await ctx.newRemoteAsset(ownerId: user.id, createdAt: day.add(const Duration(hours: 3)));
      final missing = await ctx.newRemoteAsset(ownerId: user.id, createdAt: day.add(const Duration(hours: 4)));
      final commaCity = await ctx.newRemoteAsset(ownerId: user.id, createdAt: day.add(const Duration(hours: 5)));

      await ctx.db.batch((batch) {
        batch.insert(
          ctx.db.remoteExifEntity,
          RemoteExifEntityCompanion(assetId: Value(berlin.id), city: const Value(' Berlin ')),
        );
        batch.insert(
          ctx.db.remoteExifEntity,
          RemoteExifEntityCompanion(assetId: Value(shanghai.id), city: const Value('Shanghai')),
        );
        batch.insert(
          ctx.db.remoteExifEntity,
          RemoteExifEntityCompanion(assetId: Value(duplicateShanghai.id), city: const Value(' shanghai ')),
        );
        batch.insert(
          ctx.db.remoteExifEntity,
          RemoteExifEntityCompanion(assetId: Value(blank.id), city: const Value('   ')),
        );
        batch.insert(ctx.db.remoteExifEntity, RemoteExifEntityCompanion(assetId: Value(missing.id)));
        batch.insert(
          ctx.db.remoteExifEntity,
          RemoteExifEntityCompanion(assetId: Value(commaCity.id), city: const Value('Washington, D.C.')),
        );
      });

      final buckets = await sut.main([user.id], .day).bucketSource().first;

      expect((buckets.single as TimeBucket).cities, ['Berlin', 'Shanghai', 'Washington, D.C.']);
    });

    test('keeps city lists independent between main timeline day buckets', () async {
      final user = await ctx.newUser();
      final newestDay = DateTime.utc(2026, 9, 15, 12);
      final olderDay = DateTime.utc(2026, 9, 14, 12);
      final shanghai = await ctx.newRemoteAsset(ownerId: user.id, createdAt: newestDay);
      final berlin = await ctx.newRemoteAsset(ownerId: user.id, createdAt: olderDay);

      await ctx.db.batch((batch) {
        batch.insert(
          ctx.db.remoteExifEntity,
          RemoteExifEntityCompanion(assetId: Value(shanghai.id), city: const Value('Shanghai')),
        );
        batch.insert(
          ctx.db.remoteExifEntity,
          RemoteExifEntityCompanion(assetId: Value(berlin.id), city: const Value('Berlin')),
        );
      });

      final buckets = await sut.main([user.id], .day).bucketSource().first;

      expect((buckets[0] as TimeBucket).cities, ['Shanghai']);
      expect((buckets[1] as TimeBucket).cities, ['Berlin']);
    });
  });

  group('remoteAlbum assets', () {
    test('no duplicate assets when identical checksum appears in multiple local asset rows', () async {
      // Regression check for #23273: a LEFT OUTER JOIN on checksum would fan out and create duplicates
      // happens when same photo exists in multiple albums on device
      final user = await ctx.newUser();
      const checksum = 'yolo';
      final album = await ctx.newRemoteAlbum(ownerId: user.id);
      final remoteAsset = await ctx.newRemoteAsset(ownerId: user.id, checksum: checksum);
      await ctx.newRemoteAlbumAsset(albumId: album.id, assetId: remoteAsset.id);

      final localAsset1 = await ctx.newLocalAsset(checksum: checksum);
      final localAsset2 = await ctx.newLocalAsset(checksum: checksum);

      final query = sut.remoteAlbum(album.id, .day);

      final buckets = await query.bucketSource().first;
      expect(buckets, hasLength(1));
      expect(buckets.single.assetCount, 1);

      final assets = await query.assetSource(0, 10);
      expect(assets, hasLength(1));
      expect((assets.first as RemoteAsset).id, remoteAsset.id);
      expect([localAsset1.id, localAsset2.id], contains((assets.first as RemoteAsset).localId));
    });

    test('includes cities in remote album day buckets', () async {
      final user = await ctx.newUser();
      final album = await ctx.newRemoteAlbum(ownerId: user.id);
      final asset = await ctx.newRemoteAsset(ownerId: user.id);
      await ctx.newRemoteAlbumAsset(albumId: album.id, assetId: asset.id);
      await ctx.db
          .into(ctx.db.remoteExifEntity)
          .insert(RemoteExifEntityCompanion(assetId: Value(asset.id), city: const Value('Shanghai')));

      final buckets = await sut.remoteAlbum(album.id, .day).bucketSource().first;

      expect((buckets.single as TimeBucket).cities, ['Shanghai']);
    });
  });

  group('person assets', () {
    test('does not duplicate an asset that has multiple face records for the same person', () async {
      // Regression check for #26723: an INNER JOIN between remote_asset_entity and asset_face_entity
      // fanned out one asset into N rows when N face records pointed at the same (asset, person) pair
      final user = await ctx.newUser();
      final asset = await ctx.newRemoteAsset(ownerId: user.id);

      final person = await ctx.newPerson(ownerId: user.id);
      await ctx.newFace(assetId: asset.id, personId: person.id);
      await ctx.newFace(assetId: asset.id, personId: person.id);

      final query = sut.person(user.id, person.id, .day);

      final buckets = await query.bucketSource().first;
      expect(buckets, hasLength(1));
      expect(buckets.single.assetCount, 1);

      final assets = await query.assetSource(0, 10);
      expect(assets, hasLength(1));
      expect((assets.first as RemoteAsset).id, asset.id);
    });

    test('includes cities in person day buckets', () async {
      final user = await ctx.newUser();
      final asset = await ctx.newRemoteAsset(ownerId: user.id);
      final person = await ctx.newPerson(ownerId: user.id);
      await ctx.newFace(assetId: asset.id, personId: person.id);
      await ctx.db
          .into(ctx.db.remoteExifEntity)
          .insert(RemoteExifEntityCompanion(assetId: Value(asset.id), city: const Value('Ningbo')));

      final buckets = await sut.person(user.id, person.id, .day).bucketSource().first;

      expect((buckets.single as TimeBucket).cities, ['Ningbo']);
    });
  });

  group('remote filtered assets', () {
    test('includes cities in favorite day buckets', () async {
      final user = await ctx.newUser();
      final asset = await ctx.newRemoteAsset(ownerId: user.id, isFavorite: true);
      await ctx.db
          .into(ctx.db.remoteExifEntity)
          .insert(RemoteExifEntityCompanion(assetId: Value(asset.id), city: const Value('Hangzhou')));

      final buckets = await sut.favorite(user.id, .day).bucketSource().first;

      expect((buckets.single as TimeBucket).cities, ['Hangzhou']);
    });
  });

  group('place and map assets', () {
    test('includes cities in place day buckets', () async {
      final user = await ctx.newUser();
      final asset = await ctx.newRemoteAsset(ownerId: user.id);
      await ctx.db
          .into(ctx.db.remoteExifEntity)
          .insert(RemoteExifEntityCompanion(assetId: Value(asset.id), city: const Value('Suzhou')));

      final buckets = await sut.place(const PlacePath(city: 'Suzhou'), .day).bucketSource().first;

      expect((buckets.single as TimeBucket).cities, ['Suzhou']);
    });

    test('includes cities in map day buckets', () async {
      final user = await ctx.newUser();
      final asset = await ctx.newRemoteAsset(ownerId: user.id);
      await ctx.db
          .into(ctx.db.remoteExifEntity)
          .insert(
            RemoteExifEntityCompanion(
              assetId: Value(asset.id),
              city: const Value('Wuxi'),
              latitude: const Value(31.5),
              longitude: const Value(120.3),
            ),
          );
      final options = TimelineMapOptions(
        bounds: LatLngBounds(southwest: const LatLng(31, 120), northeast: const LatLng(32, 121)),
      );

      final buckets = await sut.map([user.id], options, .day).bucketSource().first;

      expect((buckets.single as TimeBucket).cities, ['Wuxi']);
    });
  });

  group('live photos', () {
    test('remote-only live photo contains livePhotoVideoId and is marked as a motion photo', () async {
      final user = await ctx.newUser();
      final asset = await ctx.newRemoteAsset(ownerId: user.id, livePhotoVideoId: 'motion-photo-1');

      final assets = await sut.main([user.id], .day).assetSource(0, 10);

      expect(assets, hasLength(1));
      final remote = assets.single as RemoteAsset;
      expect(remote.id, asset.id);
      expect(remote.livePhotoVideoId, 'motion-photo-1');
      expect(remote.isMotionPhoto, isTrue);
      expect(remote.localId, isNull);
    });

    test('merged live photo resolves localId and is marked as a motion photo', () async {
      final user = await ctx.newUser();
      const checksum = 'shared-live-photo-checksum';
      final asset = await ctx.newRemoteAsset(ownerId: user.id, checksum: checksum, livePhotoVideoId: 'motion-photo-2');
      final local = await ctx.newLocalAsset(checksum: checksum);

      final assets = await sut.main([user.id], .day).assetSource(0, 10);

      expect(assets, hasLength(1));
      final remote = assets.single as RemoteAsset;
      expect(remote.id, asset.id);
      expect(remote.livePhotoVideoId, 'motion-photo-2');
      expect(remote.isMotionPhoto, isTrue);
      expect(remote.localId, local.id);
    });

    test('trash timeline shows the still asset without duplicating the hidden motion asset', () async {
      final user = await ctx.newUser();
      final deletedAt = DateTime.now().toUtc();
      final motion = await ctx.newRemoteAsset(
        ownerId: user.id,
        deletedAt: deletedAt,
        type: .video,
        visibility: .hidden,
      );
      final still = await ctx.newRemoteAsset(ownerId: user.id, deletedAt: deletedAt, livePhotoVideoId: motion.id);

      final query = sut.trash(user.id, .day);

      final buckets = await query.bucketSource().first;
      expect(buckets.fold<int>(0, (total, bucket) => total + bucket.assetCount), 1);

      final assets = await query.assetSource(0, 10);
      expect(assets, hasLength(1));
      expect((assets.single as RemoteAsset).id, still.id);
    });
  });

  group('localAlbum assets', () {
    late String userId;
    late String otherUserId;

    setUp(() async {
      final user = await ctx.newUser();
      userId = user.id;
      await ctx.newAuthUser(id: userId);
      final other = await ctx.newUser();
      otherUserId = other.id;
    });

    test('does not duplicate assets when a partner shares the checksum', () async {
      const checksum = 'shared-partner-checksum';
      final album = await ctx.newLocalAlbum();
      final local = await ctx.newLocalAsset(checksum: checksum);
      await ctx.newLocalAlbumAsset(albumId: album.id, assetId: local.id);
      final myRemote = await ctx.newRemoteAsset(ownerId: userId, checksum: checksum);
      await ctx.newRemoteAsset(ownerId: otherUserId, checksum: checksum);

      final assets = await sut.localAlbum(album.id, .day).assetSource(0, 10);

      expect(assets, hasLength(1));
      final asset = assets.single as LocalAsset;
      expect(asset.id, local.id);
      // Must resolve the current user's remote id
      expect(asset.remoteId, myRemote.id);
    });

    test('bucket count ignores a partner sharing the checksum', () async {
      const checksum = 'shared-partner-checksum';
      final album = await ctx.newLocalAlbum();
      final local = await ctx.newLocalAsset(checksum: checksum);
      await ctx.newLocalAlbumAsset(albumId: album.id, assetId: local.id);
      await ctx.newRemoteAsset(ownerId: userId, checksum: checksum);
      await ctx.newRemoteAsset(ownerId: otherUserId, checksum: checksum);

      final buckets = await sut.localAlbum(album.id, .day).bucketSource().first;

      expect(buckets, hasLength(1));
      expect(buckets.single.assetCount, 1);
    });

    test('includes the current user city in local album day buckets', () async {
      const checksum = 'local-album-city-checksum';
      final album = await ctx.newLocalAlbum();
      final local = await ctx.newLocalAsset(checksum: checksum);
      await ctx.newLocalAlbumAsset(albumId: album.id, assetId: local.id);
      final remote = await ctx.newRemoteAsset(ownerId: userId, checksum: checksum);
      await ctx.db
          .into(ctx.db.remoteExifEntity)
          .insert(RemoteExifEntityCompanion(assetId: Value(remote.id), city: const Value('Shaoxing')));

      final buckets = await sut.localAlbum(album.id, .day).bucketSource().first;

      expect((buckets.single as TimeBucket).cities, ['Shaoxing']);
    });
  });

  group('in-memory grouped assets', () {
    test('resolves persisted cities for cleanup-shaped local assets without remote ids', () async {
      final user = await ctx.newUser();
      await ctx.newAuthUser(id: user.id);
      const checksum = 'cleanup-city-checksum';
      final remote = await ctx.newRemoteAsset(ownerId: user.id, checksum: checksum);
      final local = await ctx.newLocalAsset(checksum: checksum);
      await ctx.db
          .into(ctx.db.remoteExifEntity)
          .insert(RemoteExifEntityCompanion(assetId: Value(remote.id), city: const Value('Jiaxing')));
      final cleanupAsset = local.toDto();
      expect(cleanupAsset.remoteId, isNull);

      final buckets = await sut.fromAssetsWithBuckets([cleanupAsset], .search).bucketSource().first;

      expect((buckets.single as TimeBucket).cities, ['Jiaxing']);
    });

    test('resolves cities when cleanup assets exceed the SQLite variable limit', () async {
      final user = await ctx.newUser();
      await ctx.newAuthUser(id: user.id);
      const matchingChecksum = 'cleanup-large-library-0';
      final remote = await ctx.newRemoteAsset(ownerId: user.id, checksum: matchingChecksum);
      await ctx.db
          .into(ctx.db.remoteExifEntity)
          .insert(RemoteExifEntityCompanion(assetId: Value(remote.id), city: const Value('Huzhou')));
      final date = DateTime(2026, 9, 15);
      final assets = List<BaseAsset>.generate(
        32767,
        (index) => LocalAsset(
          id: 'cleanup-local-$index',
          name: 'cleanup-$index.jpg',
          checksum: 'cleanup-large-library-$index',
          type: AssetType.image,
          createdAt: date,
          updatedAt: date,
          playbackStyle: AssetPlaybackStyle.image,
          isEdited: false,
        ),
        growable: false,
      );

      final buckets = await sut.fromAssetsWithBuckets(assets, .search).bucketSource().first;

      expect(buckets.single.assetCount, assets.length);
      expect((buckets.single as TimeBucket).cities, ['Huzhou']);
    });
  });
}
