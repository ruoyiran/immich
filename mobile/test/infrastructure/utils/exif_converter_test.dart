import 'package:flutter_test/flutter_test.dart';
import 'package:immich_mobile/infrastructure/utils/exif.converter.dart';
import 'package:openapi/api.dart';

void main() {
  group('ExifDtoConverter.fromDto', () {
    test('maps rating into the domain EXIF info', () {
      final exif = ExifDtoConverter.fromDto(ExifResponseDto(rating: const Optional.present(5)));

      expect(exif.rating, 5);
    });
  });
}
