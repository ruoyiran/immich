import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:immich_mobile/constants/locales.dart';
import 'package:immich_mobile/generated/codegen_loader.g.dart';
import 'package:immich_mobile/presentation/widgets/asset_viewer/original_media_action.widget.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shows and activates original image and video actions', (tester) async {
    await EasyLocalization.ensureInitialized();
    var imagePressed = false;
    var videoPressed = false;

    Widget app(OriginalMediaKind kind, VoidCallback onPressed) => EasyLocalization(
      supportedLocales: locales.values.toList(),
      path: translationsPath,
      startLocale: const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
      fallbackLocale: const Locale('en'),
      saveLocale: false,
      assetLoader: const CodegenLoader(),
      child: Builder(
        builder: (context) => MaterialApp(
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          locale: context.locale,
          home: Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: OriginalMediaActionButton(kind: kind, onPressed: onPressed),
            ),
          ),
        ),
      ),
    );

    await tester.pumpWidget(app(OriginalMediaKind.image, () => imagePressed = true));
    await tester.pumpAndSettle();
    expect(find.text('查看原图'), findsOneWidget);
    await tester.tap(find.byKey(const Key('view-original-media-button')));
    expect(imagePressed, isTrue);

    await tester.pumpWidget(app(OriginalMediaKind.video, () => videoPressed = true));
    await tester.pumpAndSettle();
    expect(find.text('查看原视频'), findsOneWidget);
    await tester.tap(find.byKey(const Key('view-original-media-button')));
    expect(videoPressed, isTrue);
  });
}
