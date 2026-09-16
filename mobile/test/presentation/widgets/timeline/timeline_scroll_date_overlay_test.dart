import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:immich_mobile/domain/models/asset/base_asset.model.dart';
import 'package:immich_mobile/domain/models/config/app_config.dart';
import 'package:immich_mobile/domain/models/timeline.model.dart';
import 'package:immich_mobile/domain/services/timeline.service.dart';
import 'package:immich_mobile/presentation/widgets/timeline/timeline.widget.dart';
import 'package:immich_mobile/providers/infrastructure/settings.provider.dart';
import 'package:immich_mobile/providers/infrastructure/timeline.provider.dart';

import '../../../fixtures/asset.stub.dart';
import '../../../widget_tester_extensions.dart';

const _overlayKey = ValueKey('timeline-scroll-date-overlay');

Future<void> _pumpTimeline(
  WidgetTester tester, {
  required List<Bucket> buckets,
  GroupAssetsBy groupBy = GroupAssetsBy.day,
  Widget? topSliverWidget,
  double? topSliverWidgetHeight,
}) async {
  tester.view.devicePixelRatio = 3.0;
  tester.view.physicalSize = const Size(1200, 1800);
  addTearDown(tester.view.reset);

  final assetCount = buckets.fold(0, (total, bucket) => total + bucket.assetCount);
  final assets = List<BaseAsset>.generate(assetCount, (index) => LocalAssetStub.image1.copyWith(id: 'asset-$index'));
  final service = TimelineService((
    assetSource: (index, count) async => assets.sublist(index, math.min(index + count, assets.length)),
    bucketSource: () => Stream.value(buckets),
    origin: TimelineOrigin.main,
  ));
  addTearDown(service.dispose);

  await tester.pumpConsumerWidget(
    Timeline(
      appBar: null,
      bottomSheet: null,
      withScrubber: false,
      readOnly: true,
      groupBy: groupBy,
      topSliverWidget: topSliverWidget,
      topSliverWidgetHeight: topSliverWidgetHeight,
    ),
    overrides: [
      timelineServiceProvider.overrideWithValue(service),
      appConfigProvider.overrideWithValue(const AppConfig()),
    ],
  );
  tester.takeException();
}

ScrollPosition _timelinePosition(WidgetTester tester) => tester
    .state<ScrollableState>(find.descendant(of: find.byType(Timeline), matching: find.byType(Scrollable)).first)
    .position;

String _overlayLabel(WidgetTester tester) =>
    tester.widget<Text>(find.descendant(of: find.byKey(_overlayKey), matching: find.byType(Text))).data!;

void main() {
  testWidgets('shows the first visible bucket date while scrolling and hides after scrolling stops', (tester) async {
    const assetsPerDay = 48;
    await _pumpTimeline(
      tester,
      buckets: [
        TimeBucket(date: DateTime(2020, 1, 2), assetCount: assetsPerDay),
        TimeBucket(date: DateTime(2019, 12, 31), assetCount: assetsPerDay),
      ],
    );

    expect(find.byKey(_overlayKey), findsNothing);

    final gesture = await tester.startGesture(tester.getCenter(find.byType(Timeline)));
    for (var step = 0; step < 4; step++) {
      await gesture.moveBy(const Offset(0, -700));
      await tester.pump();
    }

    expect(find.byKey(_overlayKey), findsOneWidget);
    expect(_overlayLabel(tester), 'Dec 31, 2019');

    for (var step = 0; step < 4; step++) {
      await gesture.moveBy(const Offset(0, 700));
      await tester.pump();
    }

    expect(_overlayLabel(tester), 'Jan 2, 2020');

    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(_overlayKey), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byKey(_overlayKey), findsNothing);
  });

  testWidgets('subtracts preceding sliver extent when resolving the visible date', (tester) async {
    const assetsPerDay = 48;
    await _pumpTimeline(
      tester,
      buckets: [
        TimeBucket(date: DateTime(2020, 1, 2), assetCount: assetsPerDay),
        TimeBucket(date: DateTime(2019, 12, 31), assetCount: assetsPerDay),
      ],
      topSliverWidget: const SliverToBoxAdapter(child: SizedBox(height: 2600)),
      topSliverWidgetHeight: 2600,
    );

    final position = _timelinePosition(tester);
    position.jumpTo(2600);
    await tester.pump();
    position.jumpTo(2700);
    await tester.pump();

    expect(find.byKey(_overlayKey), findsOneWidget);
    expect(_overlayLabel(tester), 'Jan 2, 2020');
  });

  testWidgets('does not show a date for an ungrouped timeline', (tester) async {
    await _pumpTimeline(
      tester,
      buckets: [TimeBucket(date: DateTime(2020, 1, 2), assetCount: 48)],
      groupBy: GroupAssetsBy.none,
    );

    final position = _timelinePosition(tester);
    position.jumpTo(position.maxScrollExtent);
    await tester.pump();

    expect(find.byKey(_overlayKey), findsNothing);
  });
}
