import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:immich_mobile/platform/remote_image_api.g.dart';
import 'package:immich_mobile/presentation/widgets/images/remote_image_provider.dart';
import 'package:immich_mobile/presentation/widgets/images/thumbnail.widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const requestChannel = BasicMessageChannel<Object?>(
    'dev.flutter.pigeon.immich_mobile.RemoteImageApi.requestImage',
    RemoteImageApi.pigeonChannelCodec,
  );

  const cancelChannel = BasicMessageChannel<Object?>(
    'dev.flutter.pigeon.immich_mobile.RemoteImageApi.cancelRequest',
    RemoteImageApi.pigeonChannelCodec,
  );

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockDecodedMessageHandler(
      requestChannel,
      null,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockDecodedMessageHandler(cancelChannel, null);
  });

  testWidgets('retries remote thumbnail after a transient load error', (tester) async {
    var requests = 0;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockDecodedMessageHandler(cancelChannel, (
      _,
    ) async {
      return <Object?>[null];
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockDecodedMessageHandler(requestChannel, (
      _,
    ) async {
      requests++;
      if (requests == 1) {
        return <Object?>['404', 'HTTP 404: Not Found', null];
      }
      return <Object?>[null];
    });

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox.square(
          dimension: 32,
          child: Thumbnail(
            imageProvider: RemoteImageProvider(url: 'https://example.test/thumbnail', retryNotFound: true),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(requests, 1);

    await tester.pump(const Duration(milliseconds: 499));
    expect(requests, 1);

    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();

    expect(requests, 2);
  });

  testWidgets('keeps retrying transient thumbnails across delayed server processing', (tester) async {
    var requests = 0;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockDecodedMessageHandler(cancelChannel, (
      _,
    ) async {
      return <Object?>[null];
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockDecodedMessageHandler(requestChannel, (
      _,
    ) async {
      requests++;
      if (requests < 8) {
        return <Object?>['404', 'HTTP 404: Not Found', null];
      }
      return <Object?>[null];
    });

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox.square(
          dimension: 32,
          child: Thumbnail(
            imageProvider: RemoteImageProvider(url: 'https://example.test/thumbnail-delayed', retryNotFound: true),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(requests, 1);
    for (final delay in const <Duration>[
      Duration(milliseconds: 500),
      Duration(seconds: 1),
      Duration(seconds: 2),
      Duration(seconds: 4),
      Duration(seconds: 8),
      Duration(seconds: 16),
      Duration(seconds: 32),
    ]) {
      await tester.pump(delay);
      await tester.pump();
    }

    expect(requests, 8);
  });

  testWidgets('does not retry not found errors for generic remote images', (tester) async {
    var requests = 0;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockDecodedMessageHandler(cancelChannel, (
      _,
    ) async {
      return <Object?>[null];
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockDecodedMessageHandler(requestChannel, (
      _,
    ) async {
      requests++;
      return <Object?>['404', 'HTTP 404: Not Found', null];
    });

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox.square(
          dimension: 32,
          child: Thumbnail(imageProvider: RemoteImageProvider(url: 'https://example.test/profile-image')),
        ),
      ),
    );
    await tester.pump();

    expect(requests, 1);

    await tester.pump(const Duration(seconds: 2));

    expect(requests, 1);
  });

  testWidgets('does not retry non-transient remote image errors', (tester) async {
    var requests = 0;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockDecodedMessageHandler(cancelChannel, (
      _,
    ) async {
      return <Object?>[null];
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockDecodedMessageHandler(requestChannel, (
      _,
    ) async {
      requests++;
      return <Object?>['401', 'HTTP 401: Unauthorized', null];
    });

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox.square(
          dimension: 32,
          child: Thumbnail(imageProvider: RemoteImageProvider(url: 'https://example.test/thumbnail')),
        ),
      ),
    );
    await tester.pump();

    expect(requests, 1);

    await tester.pump(const Duration(seconds: 2));

    expect(requests, 1);
  });
}
