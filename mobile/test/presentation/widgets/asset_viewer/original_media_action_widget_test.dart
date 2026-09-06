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
}
