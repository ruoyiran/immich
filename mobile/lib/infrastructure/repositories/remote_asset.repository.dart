import 'package:drift/drift.dart';
import 'package:immich_mobile/domain/models/asset/base_asset.model.dart';
import 'package:immich_mobile/domain/models/asset_edit.model.dart';
import 'package:immich_mobile/domain/models/exif.model.dart';
import 'package:immich_mobile/domain/models/place.model.dart';
import 'package:immich_mobile/domain/models/stack.model.dart';
import 'package:immich_mobile/infrastructure/entities/asset_edit.entity.dart';
import 'package:immich_mobile/infrastructure/entities/exif.entity.dart';
import 'package:immich_mobile/infrastructure/entities/exif.entity.drift.dart';
import 'package:immich_mobile/infrastructure/entities/remote_asset.entity.dart';
import 'package:immich_mobile/infrastructure/entities/remote_asset.entity.drift.dart';
import 'package:immich_mobile/infrastructure/entities/stack.entity.drift.dart';
import 'package:immich_mobile/infrastructure/repositories/db.repository.dart';
import 'package:immich_mobile/utils/option.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

class RemoteAssetRepository extends DriftDatabaseRepository {
  final Drift _db;

  const RemoteAssetRepository(this._db) : super(_db);

  /// For testing purposes
  Future<List<RemoteAsset>> getSome(String userId) {
    final query = _db.remoteAssetEntity.select()
      ..where(
        (row) =>
            _db.remoteAssetEntity.ownerId.equals(userId) &
            _db.remoteAssetEntity.deletedAt.isNull() &
            _db.remoteAssetEntity.visibility.equalsValue(AssetVisibility.timeline),
      )
      ..orderBy([(row) => OrderingTerm.desc(row.createdAt)])
      ..limit(10);

    return query.map((row) => row.toDto()).get();
  }

  SingleOrNullSelectable<RemoteAsset?> _assetSelectable(String id) {
    final query =
        _db.remoteAssetEntity.select().addColumns([_db.localAssetEntity.id]).join([
            leftOuterJoin(
              _db.localAssetEntity,
              _db.remoteAssetEntity.checksum.equalsExp(_db.localAssetEntity.checksum),
              useColumns: false,
            ),
          ])
          ..where(_db.remoteAssetEntity.id.equals(id))
          ..limit(1);

    return query.map((row) {
      final asset = row.readTable(_db.remoteAssetEntity).toDto();
      return asset.copyWith(localId: row.read(_db.localAssetEntity.id));
    });
  }

  Stream<RemoteAsset?> watch(String id) {
    return _assetSelectable(id).watchSingleOrNull();
  }

  Future<RemoteAsset?> get(String id) {
    return _assetSelectable(id).getSingleOrNull();
  }

  Future<Map<String, RemoteAsset>> getByIds(Iterable<String> ids) async {
    final uniqueIds = ids.toSet();
    if (uniqueIds.isEmpty) {
      return const {};
    }

    final query = _db.remoteAssetEntity.select().addColumns([_db.localAssetEntity.id]).join([
      leftOuterJoin(
        _db.localAssetEntity,
        _db.remoteAssetEntity.checksum.equalsExp(_db.localAssetEntity.checksum),
        useColumns: false,
      ),
    ])..where(_db.remoteAssetEntity.id.isIn(uniqueIds));

    final rows = await query.get();
    return {
      for (final row in rows)
        row.readTable(_db.remoteAssetEntity).id: row
            .readTable(_db.remoteAssetEntity)
            .toDto(localId: row.read(_db.localAssetEntity.id)),
    };
  }

  Future<List<RemoteAsset>> getAllDebugForChecksum(String checksum) {
    final query = _db.remoteAssetEntity.select()..where((row) => row.checksum.equals(checksum));

    return query.map((row) => row.toDto()).get();
  }

  Future<List<RemoteAsset>> getStackChildren(RemoteAsset asset) {
    final stackId = asset.stackId;
    if (stackId == null) {
      return Future.value(const []);
    }

    final query = _db.remoteAssetEntity.select()
      ..where((row) => row.stackId.equals(stackId) & row.id.equals(asset.id).not())
      ..orderBy([(row) => OrderingTerm.desc(row.createdAt)]);

    return query.map((row) => row.toDto()).get();
  }

  /// Inserts a placeholder row for a freshly uploaded local asset so checksum
  /// based local/remote merging updates immediately. The sync stream replaces
  /// its metadata while retaining this device-specific upload checksum.
  Future<void> upsertUploadedAsset({
    required String remoteId,
    required String ownerId,
    required LocalAsset source,
  }) async {
    final checksum = source.checksum ?? remoteId;
    await _db
        .into(_db.remoteAssetEntity)
        .insert(
          RemoteAssetEntityCompanion(
            id: Value(remoteId),
            ownerId: Value(ownerId),
            checksum: Value(checksum),
            name: Value(source.name),
            type: Value(source.type),
            createdAt: Value(source.createdAt),
            updatedAt: Value(source.updatedAt),
            width: Value(source.width),
            height: Value(source.height),
            durationMs: Value(source.durationMs),
            isFavorite: Value(source.isFavorite),
            visibility: const Value(AssetVisibility.timeline),
            isEdited: Value(source.isEdited),
          ),
          onConflict: DoUpdate((_) => RemoteAssetEntityCompanion(checksum: Value(checksum))),
        );
  }

  Future<ExifInfo?> getExif(String id) {
    return _db.managers.remoteExifEntity
        .filter((row) => row.assetId.id.equals(id))
        .map((row) => row.toDto())
        .getSingleOrNull();
  }

  ({String sql, List<Variable> variables, PlaceLevel level}) _placeNodesQuery(String userId, PlacePath parent) {
    final level = parent.nextLevel;
    if (level == null) {
      throw ArgumentError.value(parent, 'parent', 'district is already the deepest place level');
    }
    final target = level.name;
    final child = switch (level) {
      PlaceLevel.country => 'state',
      PlaceLevel.state => 'city',
      PlaceLevel.city => 'district',
      PlaceLevel.district => null,
    };
    final filters = <String>[
      'asset.owner_id = ?',
      'asset.deleted_at IS NULL',
      'asset.visibility = ?',
      'exif.$target IS NOT NULL',
      "TRIM(exif.$target) <> ''",
    ];
    final variables = <Variable>[Variable.withString(userId), Variable.withInt(AssetVisibility.timeline.index)];
    for (final entry in <String, String?>{
      'country': parent.country,
      'state': parent.state,
      'city': parent.city,
      'district': parent.district,
    }.entries) {
      if (entry.value != null) {
        filters.add('exif.${entry.key} = ?');
        variables.add(Variable.withString(entry.value!));
      }
    }
    final childExpression = child == null
        ? '0'
        : "MAX(CASE WHEN exif.$child IS NOT NULL AND TRIM(exif.$child) <> '' THEN 1 ELSE 0 END) "
              'OVER (PARTITION BY exif.$target)';
    return (
      sql:
          '''
WITH ranked AS (
  SELECT exif.$target AS name,
         asset.id AS cover_asset_id,
         COUNT(*) OVER (PARTITION BY exif.$target) AS asset_count,
         $childExpression AS has_children,
         ROW_NUMBER() OVER (
           PARTITION BY exif.$target
           ORDER BY asset.created_at DESC, asset.id DESC
         ) AS cover_rank
  FROM remote_asset_entity asset
  JOIN remote_exif_entity exif ON exif.asset_id = asset.id
  WHERE ${filters.join(' AND ')}
)
SELECT name, cover_asset_id, asset_count, has_children
FROM ranked
WHERE cover_rank = 1
ORDER BY name COLLATE NOCASE
''',
      variables: variables,
      level: level,
    );
  }

  List<PlaceNode> _mapPlaceNodes(List<QueryRow> rows, PlacePath parent, PlaceLevel level) => rows
      .map(
        (row) => PlaceNode(
          name: row.read<String>('name'),
          path: parent.withValue(level, row.read<String>('name')),
          coverAssetId: row.read<String>('cover_asset_id'),
          assetCount: row.read<int>('asset_count'),
          hasChildren: row.read<int>('has_children') != 0,
        ),
      )
      .toList(growable: false);

  Future<List<PlaceNode>> getPlaceNodes(String userId, PlacePath parent) async {
    if (parent.nextLevel == null) {
      return const [];
    }
    final query = _placeNodesQuery(userId, parent);
    final rows = await _db
        .customSelect(query.sql, variables: query.variables, readsFrom: {_db.remoteAssetEntity, _db.remoteExifEntity})
        .get();
    return _mapPlaceNodes(rows, parent, query.level);
  }

  Stream<List<PlaceNode>> watchPlaceNodes(String userId, PlacePath parent) {
    if (parent.nextLevel == null) {
      return Stream.value(const []);
    }
    final query = _placeNodesQuery(userId, parent);
    return _db
        .customSelect(query.sql, variables: query.variables, readsFrom: {_db.remoteAssetEntity, _db.remoteExifEntity})
        .watch()
        .map((rows) => _mapPlaceNodes(rows, parent, query.level));
  }

  Future<List<(String, String)>> getPlaces(String userId) async {
    final rows = await _db
        .customSelect(
          '''
WITH ranked AS (
  SELECT exif.city AS city,
         asset.id AS cover_asset_id,
         ROW_NUMBER() OVER (
           PARTITION BY exif.city
           ORDER BY asset.created_at DESC, asset.id DESC
         ) AS cover_rank
  FROM remote_asset_entity asset
  JOIN remote_exif_entity exif ON exif.asset_id = asset.id
  WHERE asset.owner_id = ?
    AND asset.deleted_at IS NULL
    AND asset.visibility = ?
    AND exif.city IS NOT NULL
    AND TRIM(exif.city) <> ''
)
SELECT city, cover_asset_id FROM ranked WHERE cover_rank = 1 ORDER BY city COLLATE NOCASE
''',
          variables: [Variable.withString(userId), Variable.withInt(AssetVisibility.timeline.index)],
          readsFrom: {_db.remoteAssetEntity, _db.remoteExifEntity},
        )
        .get();
    return rows.map((row) => (row.read<String>('city'), row.read<String>('cover_asset_id'))).toList(growable: false);
  }

  Future<void> updateVisibility(List<String> ids, AssetVisibility visibility) {
    return _db.batch((batch) async {
      for (final id in ids) {
        batch.update(
          _db.remoteAssetEntity,
          RemoteAssetEntityCompanion(visibility: Value(visibility)),
          where: (e) => e.id.equals(id),
        );
      }
    });
  }

  Future<void> trash(List<String> ids) {
    return _db.batch((batch) async {
      for (final id in ids) {
        batch.update(
          _db.remoteAssetEntity,
          RemoteAssetEntityCompanion(deletedAt: Value(DateTime.now())),
          where: (e) => e.id.equals(id),
        );
      }
    });
  }

  Future<void> restoreTrash(List<String> ids) {
    return _db.batch((batch) async {
      for (final id in ids) {
        batch.update(
          _db.remoteAssetEntity,
          const RemoteAssetEntityCompanion(deletedAt: Value(null)),
          where: (e) => e.id.equals(id),
        );
      }
    });
  }

  Future<void> emptyTrash(String ownerId) async {
    await _db.remoteAssetEntity.deleteWhere((t) => t.deletedAt.isNotNull() & t.ownerId.equals(ownerId));
  }

  Future<void> restoreAllTrash(String ownerId) async {
    await (_db.remoteAssetEntity.update()..where((t) => t.deletedAt.isNotNull() & t.ownerId.equals(ownerId))).write(
      const RemoteAssetEntityCompanion(deletedAt: Value(null)),
    );
  }

  Future<void> delete(List<String> ids) {
    return _db.batch((batch) {
      for (final id in ids) {
        batch.deleteWhere(_db.remoteAssetEntity, (row) => row.id.equals(id));
      }
    });
  }

  Future<void> stack(String userId, StackResponse stack) {
    return _db.transaction(() async {
      final stackIds = await _db.managers.stackEntity
          .filter((row) => row.primaryAssetId.isIn(stack.assetIds))
          .map((row) => row.id)
          .get();

      await _db.batch((batch) {
        for (final stackId in stackIds) {
          batch.deleteWhere(_db.stackEntity, (row) => row.id.equals(stackId));
        }
      });

      await _db.batch((batch) {
        final companion = StackEntityCompanion(ownerId: Value(userId), primaryAssetId: Value(stack.primaryAssetId));

        batch.insert(_db.stackEntity, companion.copyWith(id: Value(stack.id)), onConflict: DoUpdate((_) => companion));

        for (final assetId in stack.assetIds) {
          batch.update(
            _db.remoteAssetEntity,
            RemoteAssetEntityCompanion(stackId: Value(stack.id)),
            where: (e) => e.id.equals(assetId),
          );
        }
      });
    });
  }

  Future<void> unStack(List<String> stackIds) {
    return _db.transaction(() async {
      await _db.batch((batch) {
        for (final stackId in stackIds) {
          batch.deleteWhere(_db.stackEntity, (row) => row.id.equals(stackId));
        }
      });

      // TODO: delete this after adding foreign key on stackId
      await _db.batch((batch) {
        for (final stackId in stackIds) {
          batch.update(
            _db.remoteAssetEntity,
            const RemoteAssetEntityCompanion(stackId: Value(null)),
            where: (e) => e.stackId.equals(stackId),
          );
        }
      });
    });
  }

  Future<void> updateDescription(String assetId, String description) async {
    await (_db.remoteExifEntity.update()..where((row) => row.assetId.equals(assetId))).write(
      RemoteExifEntityCompanion(description: Value(description)),
    );
  }

  Future<void> updateRating(String assetId, int? rating) async {
    await (_db.remoteExifEntity.update()..where((row) => row.assetId.equals(assetId))).write(
      RemoteExifEntityCompanion(rating: Value(rating)),
    );
  }

  Future<int> getCount() {
    return _db.managers.remoteAssetEntity.count();
  }

  Future<List<AssetEdit>> getAssetEdits(String assetId) {
    final query = _db.assetEditEntity.select()
      ..where((row) => row.assetId.equals(assetId) & row.action.equals(AssetEditAction.other.index).not())
      ..orderBy([(row) => OrderingTerm.asc(row.sequence)]);
    return query.map((row) => row.toDto()!).get();
  }

  Future<void> update(
    List<String> remoteIds, {
    Option<bool> isFavorite = const .none(),
    Option<AssetVisibility> visibility = const .none(),
    Option<DateTime> createdAt = const .none(),
    Option<DateTime> localDateTime = const .none(),
  }) async {
    if ([isFavorite, visibility, createdAt, localDateTime].every((option) => option.isNone)) {
      return;
    }

    final companion = RemoteAssetEntityCompanion(
      visibility: visibility.toDriftValue(),
      isFavorite: isFavorite.toDriftValue(),
      createdAt: createdAt.toDriftValue(),
      localDateTime: localDateTime.toDriftValue(),
    );
    return _db.batch((batch) {
      for (final remoteId in remoteIds) {
        batch.update(_db.remoteAssetEntity, companion, where: (e) => e.id.equals(remoteId));
      }
    });
  }

  // TODO(shenlong): remove after action migration
  Future<void> updateLocation(List<String> ids, LatLng location) {
    return _db.batch((batch) async {
      for (final id in ids) {
        batch.update(
          _db.remoteExifEntity,
          RemoteExifEntityCompanion(latitude: Value(location.latitude), longitude: Value(location.longitude)),
          where: (e) => e.assetId.equals(id),
        );
      }
    });
  }

  Future<void> updateDateTime(List<String> ids, DateTime dateTime, {String? timeZone}) {
    return _db.batch((batch) async {
      for (final id in ids) {
        batch.update(
          _db.remoteExifEntity,
          RemoteExifEntityCompanion(
            dateTimeOriginal: Value(dateTime),
            timeZone: timeZone == null ? const Value.absent() : Value(timeZone),
          ),
          where: (e) => e.assetId.equals(id),
        );
        batch.update(
          _db.remoteAssetEntity,
          RemoteAssetEntityCompanion(createdAt: Value(dateTime)),
          where: (e) => e.id.equals(id),
        );
      }
    });
  }
}
