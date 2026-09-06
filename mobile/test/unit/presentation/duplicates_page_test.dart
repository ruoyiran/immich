import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:immich_mobile/domain/models/duplicate_group.model.dart';
import 'package:immich_mobile/presentation/pages/drift_duplicates.page.dart';
import 'package:immich_mobile/repositories/duplicate_api.repository.dart';
import 'package:openapi/api.dart';

import 'presentation_context.dart';

class EmptyDuplicateRepository implements DuplicateRepository {
  @override
  Future<void> dismissGroups(List<String> ids) async {}

  @override
  Future<List<DuplicateGroup>> getGroups() async => const [];

  @override
  Future<List<BulkIdResponseDto>> resolve(List<DuplicateResolution> groups) async => const [];
}

void main() {
  late PresentationContext context;

  setUp(() async => context = await PresentationContext.create());
  tearDown(() async => context.dispose());

  testWidgets('shows a stable empty state when there are no similar photos', (tester) async {
    await tester.pumpTestWidget(
      context,
      const DriftDuplicatesPage(),
      overrides: [duplicateApiRepositoryProvider.overrideWithValue(EmptyDuplicateRepository())],
    );

    expect(find.byKey(const Key('duplicates-empty-state')), findsOneWidget);
  });
}
