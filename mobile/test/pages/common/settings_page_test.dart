import 'package:flutter_test/flutter_test.dart';
import 'package:immich_mobile/pages/common/settings.page.dart';

void main() {
  test('automatic backup is not exposed as a settings section', () {
    expect(SettingSection.values.map((section) => section.name), isNot(contains('backup')));
  });
}
