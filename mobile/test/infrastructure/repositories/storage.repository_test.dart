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

  test('parses Google Motion HEIC directory item elements and excludes mpvd header from still range', () {
    const xmp = '''
<GContainer:Item rdf:parseType='Resource'>
  <GItem:Length>0</GItem:Length>
  <GItem:Semantic>Primary</GItem:Semantic>
</GContainer:Item>
<GContainer:Item rdf:parseType='Resource'>
  <GItem:Length>320</GItem:Length>
  <GItem:Mime>video/mp4</GItem:Mime>
  <GItem:Semantic>MotionPhoto</GItem:Semantic>
</GContainer:Item>
''';
    final prefix = Uint8List(512)..setAll(0, xmp.codeUnits);
    prefix.setAll(440, [0, 0, 1, 72, 0x6d, 0x70, 0x76, 0x64]);

    final ranges = parseMotionPhotoRanges(prefix, 768);
    expect(ranges?.stillLength, 440);
    expect(ranges?.motionOffset, 448);
    expect(ranges?.motionLength, 320);
  });

  test('rejects missing and out-of-bounds Motion Photo ranges', () {
    expect(parseMotionPhotoRanges(Uint8List.fromList('no xmp'.codeUnits), 1024), isNull);
    expect(parseMotionPhotoRanges(Uint8List.fromList('MicroVideoOffset="1024"'.codeUnits), 1024), isNull);
  });
}
