import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:immich_mobile/presentation/widgets/asset_viewer/original_media_action.widget.dart';

import '../../../widget_tester_extensions.dart';

void main() {
  testWidgets('places the original media action below the photo center', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpConsumerWidget(
      Stack(
        children: [OriginalMediaActionOverlay(kind: OriginalMediaKind.image, showingControls: true, onPressed: () {})],
      ),
    );

    final center = tester.getCenter(find.byKey(const Key('view-original-media-button')));
    expect(center.dy, greaterThan(400));
  });

  testWidgets('shows the original file size to the right of the action label', (tester) async {
    await tester.pumpConsumerWidget(
      Stack(
        children: [
          OriginalMediaActionOverlay(
            kind: OriginalMediaKind.image,
            showingControls: true,
            sizeLabel: '24.6 MiB',
            onPressed: () {},
          ),
        ],
      ),
    );

    expect(find.text('24.6 MiB'), findsOneWidget);
    final labelCenter = tester.getCenter(find.text('View original image'));
    final sizeCenter = tester.getCenter(find.text('24.6 MiB'));
    expect(sizeCenter.dx, greaterThan(labelCenter.dx));
  });

  testWidgets('shows progress and disables repeated taps while the original is caching', (tester) async {
    var presses = 0;
    await tester.pumpConsumerWidget(
      Stack(
        children: [
          OriginalMediaActionOverlay(
            kind: OriginalMediaKind.video,
            showingControls: true,
            loading: true,
            progress: 0.42,
            sizeLabel: '80.0 MiB',
            onPressed: () => presses++,
          ),
        ],
      ),
    );

    expect(find.text('42%'), findsOneWidget);
    expect(find.text('80.0 MiB'), findsOneWidget);
    final progress = tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator));
    expect(progress.value, 0.42);
    await tester.tap(find.byKey(const Key('view-original-media-button')));
    expect(presses, 0);
  });
}
