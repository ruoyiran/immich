import 'package:flutter_test/flutter_test.dart';
import 'package:immich_mobile/domain/models/asset/base_asset.model.dart';
import 'package:immich_mobile/domain/models/duplicate_group.model.dart';
import 'package:immich_mobile/domain/models/exif.model.dart';
import 'package:immich_mobile/providers/duplicates.provider.dart';
import 'package:immich_mobile/repositories/duplicate_api.repository.dart';
import 'package:openapi/api.dart' show BulkIdResponseDto;

class FakeDuplicateRepository implements DuplicateRepository {
  FakeDuplicateRepository(this.groups);

  List<DuplicateGroup> groups;
  final resolved = <DuplicateResolution>[];
  final dismissed = <String>[];

  @override
  Future<void> dismissGroups(List<String> ids) async => dismissed.addAll(ids);

  @override
  Future<List<DuplicateGroup>> getGroups() async => groups;

  @override
  Future<List<BulkIdResponseDto>> resolve(List<DuplicateResolution> groups) async {
    resolved.addAll(groups);
    return groups.map((group) => BulkIdResponseDto(id: group.groupId, success: true)).toList();
  }
}

RemoteAssetExif remote(String id) => RemoteAssetExif(
  id: id,
  name: '$id.jpg',
  checksum: '',
  createdAt: DateTime(2026, 9, 6),
  updatedAt: DateTime(2026, 9, 6),
  uploadedAt: DateTime(2026, 9, 6),
  ownerId: 'owner',
  visibility: AssetVisibility.timeline,
  durationMs: null,
  height: 100,
  width: 100,
  isFavorite: false,
  livePhotoVideoId: null,
  thumbHash: null,
  localId: null,
  type: AssetType.image,
  stackId: null,
  isEdited: false,
  exifInfo: const ExifInfo(),
);

void main() {
  test('loads suggested trash selections and resolves the current group', () async {
    final keeper = remote('keeper');
    final other = remote('other');
    final repository = FakeDuplicateRepository([
      DuplicateGroup(
        id: 'group',
        captureDay: DateTime(2026, 9, 6),
        maxSimilarity: 0.97,
        assets: [keeper, other],
        suggestedKeepIds: {'keeper'},
      ),
    ]);
    final notifier = DuplicatesNotifier(repository);

    await notifier.load();
    expect(notifier.state.value!.trashIdsFor('group'), {'other'});

    await notifier.resolveCurrent();

    expect(repository.resolved.single.keepAssetIds, {'keeper'});
    expect(repository.resolved.single.trashAssetIds, {'other'});
    expect(notifier.state.value!.groups, isEmpty);
  });

  test('filters groups from 90 to 100 percent and bulk resolves visible selections', () async {
    final repository = FakeDuplicateRepository([
      DuplicateGroup(
        id: 'lower',
        captureDay: DateTime(2026, 9, 6),
        maxSimilarity: 0.91,
        assets: [remote('lower-keeper'), remote('lower-other')],
        suggestedKeepIds: {'lower-keeper'},
      ),
      DuplicateGroup(
        id: 'higher',
        captureDay: DateTime(2026, 9, 6),
        maxSimilarity: 0.98,
        assets: [remote('higher-keeper'), remote('higher-other')],
        suggestedKeepIds: {'higher-keeper'},
      ),
    ]);
    final notifier = DuplicatesNotifier(repository);

    await notifier.load();
    expect(notifier.state.value!.visibleGroups.map((group) => group.id), ['lower', 'higher']);
    expect(notifier.state.value!.selectedAssetCount, 2);

    notifier.setMinimumSimilarity(0.95);
    expect(notifier.state.value!.visibleGroups.map((group) => group.id), ['higher']);
    expect(notifier.state.value!.selectedAssetCount, 1);

    expect(await notifier.resolveAllSelected(), 1);
    expect(repository.resolved.map((group) => group.groupId), ['higher']);
    expect(notifier.state.value!.groups.map((group) => group.id), ['lower']);
  });
}
