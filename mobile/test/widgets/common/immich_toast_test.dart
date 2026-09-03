import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:immich_mobile/widgets/common/immich_toast.dart';

void main() {
  tearDown(() {
    FToast().removeQueuedCustomToasts();
  });

  testWidgets('queued toasts keep using the root overlay after the source context is disposed', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () {
                unawaited(
                  showModalBottomSheet<void>(
                    context: context,
                    builder: (sheetContext) => TextButton(
                      onPressed: () {
                        ImmichToast.show(context: sheetContext, msg: 'First queued toast', durationInSecond: 1);
                        ImmichToast.show(context: sheetContext, msg: 'Second queued toast', durationInSecond: 1);
                        Navigator.of(sheetContext).pop();
                      },
                      child: const Text('show toasts'),
                    ),
                  ),
                );
              },
              child: const Text('open sheet'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open sheet'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('show toasts'));
    await tester.pumpAndSettle();

    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 500));

    expect(tester.takeException(), isNull);
  });
}
