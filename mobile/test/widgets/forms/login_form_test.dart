import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:immich_mobile/widgets/forms/login/login_defaults.dart';

void main() {
  group('initialLoginServerUrl', () {
    test('uses the saved server URL when one exists', () {
      expect(
        initialLoginServerUrl(storedServerUrl: 'https://example.test', platform: TargetPlatform.iOS),
        'https://example.test',
      );
    });

    test('defaults iOS to the local release server URL', () {
      expect(initialLoginServerUrl(storedServerUrl: null, platform: TargetPlatform.iOS), 'http://192.168.1.100:19922');
    });

    test('keeps other platforms empty when there is no saved server URL', () {
      expect(initialLoginServerUrl(storedServerUrl: null, platform: TargetPlatform.android), isNull);
    });
  });
}
