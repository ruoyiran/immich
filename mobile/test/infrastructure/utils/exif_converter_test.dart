import 'package:flutter_test/flutter_test.dart';
import 'package:immich_mobile/infrastructure/utils/exif.converter.dart';
import 'package:openapi/api.dart';

void main() {
  group('ExifDtoConverter.fromDto', () {
    test('maps rating into the domain EXIF info', () {
      final exif = ExifDtoConverter.fromDto(ExifResponseDto(rating: const Optional.present(5)));

      expect(exif.rating, 5);
    });

    test('maps the detailed place display name', () {
      final exif = ExifDtoConverter.fromDto(
        ExifResponseDto(placeDisplayName: const Optional.present('上海市浦东新区川沙新镇川沙路 100 号')),
      );

      expect(exif.placeDisplayName, '上海市浦东新区川沙新镇川沙路 100 号');
    });
  });
}
