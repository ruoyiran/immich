import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:immich_mobile/domain/models/asset/base_asset.model.dart';
import 'package:immich_mobile/domain/models/duplicate_group.model.dart';
import 'package:immich_mobile/domain/models/exif.model.dart';
import 'package:immich_mobile/presentation/pages/drift_duplicates.page.dart';
import 'package:immich_mobile/repositories/duplicate_api.repository.dart';
import 'package:openapi/api.dart' show BulkIdResponseDto;

import 'presentation_context.dart';

class FakeDuplicateRepository implements DuplicateRepository {
  FakeDuplicateRepository(this.groups);

  final List<DuplicateGroup> groups;
  final resolveCalls = <List<DuplicateResolution>>[];

  @override
  Future<void> dismissGroups(List<String> ids) async {}

  @override
  Future<List<DuplicateGroup>> getGroups() async => groups;

  @override
  Future<List<BulkIdResponseDto>> resolve(List<DuplicateResolution> groups) async {
    resolveCalls.add(groups);
    return groups.map((group) => BulkIdResponseDto(id: group.groupId, success: true)).toList();
  }
}

RemoteAssetExif remote(String id, DateTime date) => RemoteAssetExif(
  id: id,
  name: '$id.jpg',
  checksum: '',
  createdAt: date,
  updatedAt: date,
  uploadedAt: date,
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

DuplicateGroup group(String id, DateTime day, {double maxSimilarity = 0.95}) => DuplicateGroup(
  id: id,
  captureDay: DateTime(day.year, day.month, day.day),
  maxSimilarity: maxSimilarity,
  assets: [remote('$id-a', day), remote('$id-b', day)],
  suggestedKeepIds: {'$id-a'},
);

void main() {
  late PresentationContext context;

  setUp(() async => context = await PresentationContext.create());
  tearDown(() async => context.dispose());

  testWidgets('shows a stable empty state when there are no similar photos', (tester) async {
    await tester.pumpTestWidget(
      context,
      const DriftDuplicatesPage(),
      overrides: [duplicateApiRepositoryProvider.overrideWithValue(FakeDuplicateRepository(const []))],
    );

    expect(find.byKey(const Key('duplicates-empty-state')), findsOneWidget);
  });

  testWidgets('renders multiple duplicate groups in one vertically scrollable list', (tester) async {
    final groups = [group('group-1', DateTime(2026, 9, 6)), group('group-2', DateTime(2026, 9, 5))];
    await tester.pumpTestWidget(
      context,
      const DriftDuplicatesPage(),
      overrides: [duplicateApiRepositoryProvider.overrideWithValue(FakeDuplicateRepository(groups))],
    );

    expect(find.byType(CustomScrollView), findsOneWidget);
    expect(find.byKey(const Key('duplicate-group-group-1')), findsOneWidget);
    final secondGroup = find.byKey(const Key('duplicate-group-group-2'));
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(secondGroup, findsWidgets);
  });

  testWidgets('tapping a thumbnail requests full-screen viewing for that group', (tester) async {
    final value = group('group-1', DateTime(2026, 9, 6));
    String? opened;
    await tester.pumpTestWidget(
      context,
      DuplicateGroupCard(group: value, trashIds: const {'group-1-b'}, onOpenAsset: (asset) => opened = asset.id),
    );

    await tester.tap(find.byKey(const Key('duplicate-asset-group-1-a')));
    expect(opened, 'group-1-a');
  });

  testWidgets('shows group and selected counts and resolves all visible selections in one request', (tester) async {
    final repository = FakeDuplicateRepository([
      group('group-1', DateTime(2026, 9, 6), maxSimilarity: 0.96),
      group('group-2', DateTime(2026, 9, 5), maxSimilarity: 0.98),
    ]);
    await tester.pumpTestWidget(
      context,
      const DriftDuplicatesPage(),
      overrides: [duplicateApiRepositoryProvider.overrideWithValue(repository)],
    );

    expect(find.text('2 组相似照片'), findsOneWidget);
    expect(find.text('已选 2 张'), findsOneWidget);

    await tester.tap(find.byKey(const Key('duplicates-resolve-all')));
    await tester.pumpAndSettle();

    expect(repository.resolveCalls, hasLength(1));
    expect(repository.resolveCalls.single.map((group) => group.groupId), ['group-1', 'group-2']);
    expect(find.byKey(const Key('duplicates-empty-state')), findsOneWidget);
  });
}
