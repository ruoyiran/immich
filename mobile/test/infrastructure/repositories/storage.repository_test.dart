import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:immich_mobile/infrastructure/repositories/storage.repository.dart';

void main() {
  test('parses legacy Motion Photo offset as a tail byte range', () {
    final prefix = Uint8List.fromList('<rdf:Description GCamera:MicroVideoOffset="128"/>'.codeUnits);
    final ranges = parseMotionPhotoRanges(prefix, 1024);
    expect(ranges?.stillLength, 896);
    expect(ranges?.motionOffset, 896);
    expect(ranges?.motionLength, 128);
  });

  test('parses Container MotionPhoto item length independent of attribute order', () {
    final prefix = Uint8List.fromList(
      '<Container:Item Item:Length="256" Item:Semantic="MotionPhoto" Item:Mime="video/mp4"/>'.codeUnits,
    );
    final ranges = parseMotionPhotoRanges(prefix, 4096);
    expect(ranges?.motionOffset, 3840);
    expect(ranges?.motionLength, 256);
  });

  test('rejects missing and out-of-bounds Motion Photo ranges', () {
    expect(parseMotionPhotoRanges(Uint8List.fromList('no xmp'.codeUnits), 1024), isNull);
    expect(parseMotionPhotoRanges(Uint8List.fromList('MicroVideoOffset="1024"'.codeUnits), 1024), isNull);
  });
}
