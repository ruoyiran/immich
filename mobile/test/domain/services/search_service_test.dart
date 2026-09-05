import 'package:flutter_test/flutter_test.dart';
import 'package:immich_mobile/domain/models/asset/base_asset.model.dart';
import 'package:immich_mobile/domain/services/search.service.dart';

RemoteAsset asset(String id, {String? localId, DateTime? deletedAt, String? thumbHash}) => RemoteAsset(
  id: id,
  localId: localId,
  name: '$id.jpg',
  ownerId: 'owner',
  checksum: 'checksum-$id',
  type: AssetType.image,
  createdAt: DateTime.utc(2024),
  updatedAt: DateTime.utc(2024),
  thumbHash: thumbHash,
  isEdited: false,
  deletedAt: deletedAt,
);

void main() {
  test('reconcileSearchAssets uses the synced local record and removes local tombstones', () {
    final apiA = asset('a', thumbHash: 'stale');
    final apiB = asset('b');
    final apiC = asset('c');
    final syncedA = asset('a', localId: 'device-a', thumbHash: 'current');
    final trashedB = asset('b', deletedAt: DateTime.utc(2024, 2));

    final result = reconcileSearchAssets([apiA, apiB, apiC], {'a': syncedA, 'b': trashedB});

    expect(result.map((item) => item.id), ['a', 'c']);
    expect(result.first.localId, 'device-a');
    expect(result.first.thumbHash, 'current');
  });
}
