import 'package:flutter_test/flutter_test.dart';
import 'package:immich_mobile/repositories/duplicate_api.repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openapi/api.dart';

class MockDuplicatesApi extends Mock implements DuplicatesApi {}

AssetResponseDto asset(String id, DateTime localDateTime) => AssetResponseDto(
  checksum: '',
  createdAt: localDateTime,
  duration: null,
  fileCreatedAt: localDateTime,
  fileModifiedAt: localDateTime,
  hasMetadata: true,
  height: 100,
  id: id,
  isArchived: false,
  isEdited: false,
  isFavorite: false,
  isOffline: false,
  isTrashed: false,
  localDateTime: localDateTime,
  originalFileName: '$id.jpg',
  originalPath: '/library/photo/$id/$id.jpg',
  ownerId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  thumbhash: null,
  type: AssetTypeEnum.IMAGE,
  updatedAt: localDateTime,
  visibility: AssetVisibility.timeline,
  width: 100,
);

void main() {
  test('maps and sorts duplicate groups by capture-location natural day', () async {
    final api = MockDuplicatesApi();
    final newer = DateTime(2026, 9, 6, 23, 30);
    final older = DateTime(2026, 9, 5, 8, 0);
    when(() => api.getAssetDuplicates()).thenAnswer(
      (_) async => [
        DuplicateResponseDto(
          duplicateId: '11111111-1111-4111-8111-111111111111',
          assets: [
            asset('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', older),
            asset('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', older),
          ],
          suggestedKeepAssetIds: ['aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'],
        ),
        DuplicateResponseDto(
          duplicateId: '22222222-2222-4222-8222-222222222222',
          assets: [
            asset('cccccccc-cccc-4ccc-8ccc-cccccccccccc', newer),
            asset('dddddddd-dddd-4ddd-8ddd-dddddddddddd', newer),
          ],
          suggestedKeepAssetIds: ['cccccccc-cccc-4ccc-8ccc-cccccccccccc'],
        ),
      ],
    );

    final groups = await DuplicateApiRepository(api).getGroups();

    expect(groups.map((group) => group.id), [
      '22222222-2222-4222-8222-222222222222',
      '11111111-1111-4111-8111-111111111111',
    ]);
    expect(groups.first.captureDay, DateTime(2026, 9, 6));
    expect(groups.first.suggestedKeepIds, {'cccccccc-cccc-4ccc-8ccc-cccccccccccc'});
  });
}
