import 'package:collection/collection.dart';
import 'package:drift/drift.dart';
import 'package:immich_mobile/constants/constants.dart';
import 'package:immich_mobile/domain/models/asset/base_asset.model.dart';
import 'package:immich_mobile/infrastructure/entities/local_asset.entity.drift.dart';
import 'package:immich_mobile/infrastructure/entities/trashed_local_asset.entity.dart';
import 'package:immich_mobile/infrastructure/entities/trashed_local_asset.entity.drift.dart';
import 'package:immich_mobile/infrastructure/repositories/db.repository.dart';

class DriftTrashedLocalAssetRepository extends DriftDatabaseRepository {
  final Drift _db;

  const DriftTrashedLocalAssetRepository(this._db) : super(_db);

  Future<void> updateHashes(Map<String, String> hashes) {
    if (hashes.isEmpty) {
      return Future.value();
    }
    return _db.batch((batch) async {
      for (final entry in hashes.entries) {
        batch.update(
          _db.trashedLocalAssetEntity,
          TrashedLocalAssetEntityCompanion(checksum: Value(entry.value)),
          where: (e) => e.id.equals(entry.key),
        );
      }
    });
  }

  Future<List<LocalAsset>> getAssetsToHash(Iterable<String> albumIds) {
    final query = _db.trashedLocalAssetEntity.select()..where((r) => r.albumId.isIn(albumIds) & r.checksum.isNull());
    return query.map((row) => row.toLocalAsset()).get();
  }

  Stream<int> watchCount() {
    return (_db.selectOnly(_db.trashedLocalAssetEntity)..addColumns([_db.trashedLocalAssetEntity.id.count()]))
        .watchSingle()
        .map((row) => row.read<int>(_db.trashedLocalAssetEntity.id.count()) ?? 0);
  }

  Stream<int> watchHashedCount() {
    return (_db.selectOnly(_db.trashedLocalAssetEntity)
          ..addColumns([_db.trashedLocalAssetEntity.id.count()])
          ..where(_db.trashedLocalAssetEntity.checksum.isNotNull()))
        .watchSingle()
        .map((row) => row.read<int>(_db.trashedLocalAssetEntity.id.count()) ?? 0);
  }

  Future<void> applyTrashedAssets(List<String> idList) async {
    if (idList.isEmpty) {
      return Future.value();
    }

    final trashedAssets = <({LocalAssetEntityData asset, String albumId})>[];

    for (final slice in idList.slices(kDriftMaxChunk)) {
      final rows = await (_db.select(_db.localAlbumAssetEntity).join([
        innerJoin(_db.localAssetEntity, _db.localAlbumAssetEntity.assetId.equalsExp(_db.localAssetEntity.id)),
      ])..where(_db.localAlbumAssetEntity.assetId.isIn(slice))).get();

      final assetsWithAlbum = rows.map(
        (row) =>
            (albumId: row.readTable(_db.localAlbumAssetEntity).albumId, asset: row.readTable(_db.localAssetEntity)),
      );

      trashedAssets.addAll(assetsWithAlbum);
    }

    if (trashedAssets.isEmpty) {
      return;
    }

    final companions = trashedAssets.map((e) {
      return TrashedLocalAssetEntityCompanion.insert(
        id: e.asset.id,
        name: e.asset.name,
        type: e.asset.type,
        createdAt: Value(e.asset.createdAt),
        updatedAt: Value(e.asset.updatedAt),
        width: Value(e.asset.width),
        height: Value(e.asset.height),
        durationMs: Value(e.asset.durationMs),
        checksum: Value(e.asset.checksum),
        isFavorite: Value(e.asset.isFavorite),
        orientation: Value(e.asset.orientation),
        playbackStyle: Value(e.asset.playbackStyle),
        source: TrashOrigin.localUser,
        albumId: e.albumId,
      );
    });

    await _db.transaction(() async {
      for (final companion in companions) {
        await _db.into(_db.trashedLocalAssetEntity).insertOnConflictUpdate(companion);
      }
      for (final slice in idList.slices(kDriftMaxChunk)) {
        await (_db.delete(_db.localAssetEntity)..where((t) => t.id.isIn(slice))).go();
      }
    });
  }
}
