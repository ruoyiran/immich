import 'package:flutter_test/flutter_test.dart';
import 'package:immich_mobile/repositories/download.repository.dart';

void main() {
  test('Android Live Photo download requests a Motion HEIC without mutating base headers', () {
    final base = {'Authorization': 'Bearer token'};

    final headers = DownloadRepository.downloadHeaders(base, isAndroidLivePhoto: true);

    expect(headers, {
      'Authorization': 'Bearer token',
      DownloadRepository.livePhotoFormatHeader: DownloadRepository.androidMotionHeicFormat,
    });
    expect(base, {'Authorization': 'Bearer token'});
    expect(DownloadRepository.downloadFilename('IMG_0001.JPG', isAndroidLivePhoto: true), 'IMG_0001.heic');
  });

  test('ordinary downloads keep their original headers and filename', () {
    final base = {'Authorization': 'Bearer token'};

    expect(DownloadRepository.downloadHeaders(base, isAndroidLivePhoto: false), same(base));
    expect(DownloadRepository.downloadFilename('IMG_0001.JPG', isAndroidLivePhoto: false), 'IMG_0001.JPG');
  });
}
