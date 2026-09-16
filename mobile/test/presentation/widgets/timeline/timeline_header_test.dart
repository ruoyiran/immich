import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:immich_mobile/domain/models/asset/base_asset.model.dart';
import 'package:immich_mobile/domain/models/timeline.model.dart';
import 'package:immich_mobile/domain/services/timeline.service.dart';
import 'package:immich_mobile/presentation/widgets/timeline/header.widget.dart';
import 'package:immich_mobile/providers/infrastructure/readonly_mode.provider.dart';
import 'package:immich_mobile/providers/infrastructure/timeline.provider.dart';
import 'package:intl/intl.dart';

import '../../../widget_tester_extensions.dart';

class _HeaderTimelineService extends Fake implements TimelineService {
  @override
  List<BaseAsset> getAssets(int offset, int count) => const [];
}

class _ReadOnlyModeNotifier extends ReadOnlyModeNotifier {
  @override
  bool build() => true;
}

class _EditableModeNotifier extends ReadOnlyModeNotifier {
  @override
  bool build() => false;
}

void main() {
  Future<void> pumpHeader(
    WidgetTester tester,
    TimeBucket bucket, {
    HeaderType header = HeaderType.day,
    bool readOnly = true,
  }) {
    return tester.pumpConsumerWidget(
      TimelineHeader(bucket: bucket, header: header, height: 72, assetOffset: 0),
      overrides: [
        timelineServiceProvider.overrideWithValue(_HeaderTimelineService()),
        readonlyModeProvider.overrideWith(readOnly ? _ReadOnlyModeNotifier.new : _EditableModeNotifier.new),
      ],
    );
  }

  testWidgets('renders a current-year day header as localized month and day without a year or weekday', (tester) async {
    final currentYear = DateTime.now().year;
    final date = DateTime(currentYear, 5, 6);

    await pumpHeader(tester, TimeBucket(date: date, assetCount: 1));

    expect(find.text('May 6'), findsOneWidget);
    expect(find.textContaining('$currentYear'), findsNothing);
    expect(find.textContaining(DateFormat.E('en').format(date)), findsNothing);
  });

  testWidgets('renders a prior-year day header as localized year, month, and day without a weekday', (tester) async {
    final priorYear = DateTime.now().year - 1;
    final date = DateTime(priorYear, 5, 6);

    await pumpHeader(tester, TimeBucket(date: date, assetCount: 1));

    expect(find.text('May 6, $priorYear'), findsOneWidget);
    expect(find.textContaining(DateFormat.E('en').format(date)), findsNothing);
  });

  testWidgets('renders city names from a time bucket between the date and select control', (tester) async {
    await pumpHeader(
      tester,
      TimeBucket(date: DateTime(DateTime.now().year, 5, 6), assetCount: 1, cities: const ['上海', '宁波']),
      readOnly: false,
    );

    expect(find.text('上海 & 宁波'), findsOneWidget);
    final cityCenter = tester.getCenter(find.text('上海 & 宁波'));
    final dateCenter = tester.getCenter(find.textContaining('May'));
    final selectCenter = tester.getCenter(find.byIcon(Icons.check_circle_outline_rounded));
    expect(cityCenter.dx, greaterThan(dateCenter.dx));
    expect(cityCenter.dx, lessThan(selectCenter.dx));
  });

  testWidgets('does not render day cities in a month-only header', (tester) async {
    await pumpHeader(
      tester,
      TimeBucket(date: DateTime(DateTime.now().year, 5, 1), assetCount: 1, cities: const ['上海']),
      header: HeaderType.month,
    );

    expect(find.text('上海'), findsNothing);
  });
}
