import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:immich_mobile/domain/models/asset/base_asset.model.dart';
import 'package:immich_mobile/domain/models/place.model.dart';
import 'package:immich_mobile/infrastructure/entities/exif.entity.drift.dart';
import 'package:immich_mobile/infrastructure/repositories/local_asset.repository.dart';
import 'package:immich_mobile/infrastructure/repositories/remote_asset.repository.dart';

import '../repository_context.dart';

void main() {
  late MediumRepositoryContext ctx;
  late RemoteAssetRepository sut;

  setUp(() {
    ctx = MediumRepositoryContext();
    sut = RemoteAssetRepository(ctx.db);
  });

  tearDown(() async {
    await ctx.dispose();
  });

  group('getByChecksum', () {
    late String userId;

    setUp(() async {
      final user = await ctx.newUser();
      userId = user.id;
      await ctx.newAuthUser(id: userId);
    });

    test('returns all assets when a partner shares the checksum', () async {
      const checksum = 'shared-partner-checksum';
      final mine = await ctx.newRemoteAsset(ownerId: userId, checksum: checksum);
      final partner = await ctx.newUser();
      final theirs = await ctx.newRemoteAsset(ownerId: partner.id, checksum: checksum);

      final result = await sut.getAllDebugForChecksum(checksum);
      final mineResult = result.firstWhere((asset) => asset.id == mine.id);
      final theirResult = result.firstWhere((asset) => asset.id == theirs.id);

      expect(result, isNotEmpty);
      expect(mineResult.id, mine.id);
      expect(mineResult.ownerId, userId);

      expect(theirResult.id, theirs.id);
      expect(theirResult.ownerId, partner.id);
    });

    test('returns partner asset only if there is no matching user asset', () async {
      const checksum = 'partner-only';
      final partner = await ctx.newUser();
      final theirs = await ctx.newRemoteAsset(ownerId: partner.id, checksum: checksum);

      final result = await sut.getAllDebugForChecksum(checksum);

      expect(result.length, 1);
      expect(result[0].id, theirs.id);
    });

    test('returns the current user\'s asset', () async {
      const checksum = 'simple';
      final remote = await ctx.newRemoteAsset(ownerId: userId, checksum: checksum);

      final result = await sut.getAllDebugForChecksum(checksum);

      expect(result.length, 1);
      expect(result[0].id, remote.id);
    });
  });

  test('upsertUploadedAsset immediately links the local asset by checksum', () async {
    const checksum = 'fresh-upload-checksum';
    const remoteId = 'fresh-upload-remote-id';
    final user = await ctx.newUser();
    await ctx.newAuthUser(id: user.id);
    final local = await ctx.newLocalAsset(checksum: checksum);
    final localRepository = DriftLocalAssetRepository(ctx.db);
    final source = await localRepository.getById(local.id);

    await sut.upsertUploadedAsset(remoteId: remoteId, ownerId: user.id, source: source!);

    final linked = await localRepository.get(local.id);
    expect(linked?.remoteId, remoteId);
    expect(linked?.storage, AssetState.merged);
  });

  test('upsertUploadedAsset replaces a synced checksum with the uploaded local checksum', () async {
    const localChecksum = 'motion-heic-container-checksum';
    const serverChecksum = 'split-still-checksum';
    const remoteId = 'motion-photo-remote-id';
    final user = await ctx.newUser();
    await ctx.newAuthUser(id: user.id);
    await ctx.newRemoteAsset(id: remoteId, ownerId: user.id, checksum: serverChecksum);
    final local = await ctx.newLocalAsset(checksum: localChecksum);
    final localRepository = DriftLocalAssetRepository(ctx.db);
    final source = await localRepository.getById(local.id);

    await sut.upsertUploadedAsset(remoteId: remoteId, ownerId: user.id, source: source!);

    final linked = await localRepository.get(local.id);
    expect(linked?.remoteId, remoteId);
    expect(linked?.storage, AssetState.merged);
    final remote = await sut.get(remoteId);
    expect(remote?.checksum, localChecksum);
  });

  test('getByIds returns current rows with their device links and tombstone state', () async {
    final user = await ctx.newUser();
    await ctx.newAuthUser(id: user.id);
    final local = await ctx.newLocalAsset(checksum: 'linked-checksum');
    final active = await ctx.newRemoteAsset(ownerId: user.id, checksum: 'linked-checksum');
    final trashed = await ctx.newRemoteAsset(ownerId: user.id, deletedAt: DateTime.utc(2025, 1, 1));

    final result = await sut.getByIds([active.id, trashed.id, 'missing']);

    expect(result.keys, containsAll([active.id, trashed.id]));
    expect(result[active.id]?.localId, local.id);
    expect(result[trashed.id]?.isTrashed, isTrue);
    expect(result.containsKey('missing'), isFalse);
  });

  test('getPlaceNodes returns deterministic country to district drill-down covers', () async {
    final user = await ctx.newUser();
    await ctx.newAuthUser(id: user.id);
    final oldShanghai = await ctx.newRemoteAsset(ownerId: user.id, createdAt: DateTime.utc(2024, 1));
    final newShanghai = await ctx.newRemoteAsset(ownerId: user.id, createdAt: DateTime.utc(2025, 1));
    final beijing = await ctx.newRemoteAsset(ownerId: user.id, createdAt: DateTime.utc(2024, 6));
    final france = await ctx.newRemoteAsset(ownerId: user.id, createdAt: DateTime.utc(2024, 3));

    Future<void> place(String id, String country, String state, String city, String district) => ctx.db
        .into(ctx.db.remoteExifEntity)
        .insert(
          RemoteExifEntityCompanion(
            assetId: Value(id),
            country: Value(country),
            state: Value(state),
            city: Value(city),
            district: Value(district),
          ),
        );
    await place(oldShanghai.id, 'China', 'Shanghai', 'Shanghai', 'Pudong');
    await place(newShanghai.id, 'China', 'Shanghai', 'Shanghai', 'Pudong');
    await place(beijing.id, 'China', 'Beijing', 'Beijing', 'Chaoyang');
    await place(france.id, 'France', 'Île-de-France', 'Paris', 'Paris');

    final countries = await sut.getPlaceNodes(user.id, const PlacePath());
    expect(countries.map((node) => node.name), ['China', 'France']);
    expect(countries.first.coverAssetId, newShanghai.id);
    expect(countries.first.assetCount, 3);
    expect(countries.first.hasChildren, isTrue);

    final states = await sut.getPlaceNodes(user.id, const PlacePath(country: 'China'));
    expect(states.map((node) => node.name), ['Beijing', 'Shanghai']);

    final districts = await sut.getPlaceNodes(
      user.id,
      const PlacePath(country: 'China', state: 'Shanghai', city: 'Shanghai'),
    );
    expect(districts.single.name, 'Pudong');
    expect(districts.single.coverAssetId, newShanghai.id);
    expect(districts.single.hasChildren, isFalse);
  });

  test('watchPlaceNodes emits when EXIF place rows arrive during first sync', () async {
    final user = await ctx.newUser();
    await ctx.newAuthUser(id: user.id);
    final iterator = StreamIterator(sut.watchPlaceNodes(user.id, const PlacePath()));

    expect(await iterator.moveNext(), isTrue);
    expect(iterator.current, isEmpty);

    final asset = await ctx.newRemoteAsset(ownerId: user.id, createdAt: DateTime.utc(2025));
    await ctx.db
        .into(ctx.db.remoteExifEntity)
        .insert(RemoteExifEntityCompanion(assetId: Value(asset.id), country: const Value('China')));

    expect(await iterator.moveNext(), isTrue);
    expect(iterator.current.single.name, 'China');
    await iterator.cancel();
  });
}
