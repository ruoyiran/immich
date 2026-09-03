import 'package:flutter_test/flutter_test.dart';
import 'package:immich_mobile/domain/services/asset.service.dart';
import 'package:immich_mobile/utils/option.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:mocktail/mocktail.dart';

import '../../infrastructure/repository.mock.dart';
import '../../repository.mocks.dart';
import '../mocks.dart';

void main() {
  late AssetService sut;
  late RepositoryMocks mocks;
  late MockAssetApiRepository apiRepository;
  late MockRemoteAssetRepository remoteRepository;
  late MockRemoteExifRepository exifRepository;

  setUp(() {
    mocks = RepositoryMocks();
    apiRepository = mocks.assetApi.api;
    remoteRepository = mocks.remoteAsset.repo;
    exifRepository = mocks.remoteExif.repo;

    sut = AssetService(
      remoteRepository: remoteRepository,
      exifRepository: exifRepository,
      localRepository: MockDriftLocalAssetRepository(),
      apiRepository: apiRepository,
      mediaRepository: mocks.assetMedia.api,
      trashedLocalRepository: mocks.trashedAsset,
    );
  });

  group('AssetService.updateDateTime', () {
    const ids = ['asset_id_1'];

    test('sends the picked value to the api with its offset intact', () async {
      const picked = '2026-06-10T19:15:00.000+06:00';
      await sut.update(ids, dateTime: const .some(picked));

      verify(
        () => apiRepository.update(ids, dateTimeOriginal: const .some(picked), timeZone: const .some('UTC+06:00')),
      ).called(1);
      verify(
        () => remoteRepository.update(
          ids,
          createdAt: .some(DateTime.parse(picked)),
          localDateTime: .some(DateTime.parse('2026-06-10T19:15:00.000')),
        ),
      ).called(1);
      verify(
        () => exifRepository.update(
          ids,
          dateTimeOriginal: .some(DateTime.parse(picked)),
          timeZone: const .some('UTC+06:00'),
        ),
      ).called(1);
    });

    test('handles negative offsets', () async {
      const picked = '2026-01-05T08:00:00.000-05:30';
      await sut.update(ids, dateTime: const .some(picked));

      verify(
        () => remoteRepository.update(
          ids,
          createdAt: .some(DateTime.parse(picked)),
          localDateTime: .some(DateTime.parse('2026-01-05T08:00:00.000')),
        ),
      ).called(1);
      verify(
        () => exifRepository.update(
          ids,
          dateTimeOriginal: .some(DateTime.parse(picked)),
          timeZone: const .some('UTC-05:30'),
        ),
      ).called(1);
    });

    test('writes no timezone when the value has no offset', () async {
      const picked = '2026-06-10T13:15:00.000Z';
      await sut.update(ids, dateTime: const .some(picked));

      verify(
        () => remoteRepository.update(
          ids,
          createdAt: .some(DateTime.parse(picked)),
          localDateTime: .some(DateTime.parse('2026-06-10T13:15:00.000')),
        ),
      ).called(1);
      verify(
        () => exifRepository.update(ids, dateTimeOriginal: .some(DateTime.parse(picked)), timeZone: const .none()),
      ).called(1);
    });

    test('is a no-op when there are no asset ids', () async {
      await sut.update(const [], dateTime: const .some('2026-06-10T19:15:00.000+06:00'));

      verifyZeroInteractions(apiRepository);
      verifyZeroInteractions(remoteRepository);
    });
  });

  group('AssetService.updateLocation', () {
    const ids = ['asset_id_1'];

    test('updates coordinates through the api and local exif cache', () async {
      const location = LatLng(35.6895, 139.6917);

      await sut.update(ids, location: const .some(location));

      verify(() => apiRepository.update(ids, location: const Option<LatLng?>.some(location))).called(1);
      verify(() => exifRepository.update(ids, location: const Option<LatLng?>.some(location))).called(1);
    });

    test('keeps null location present so coordinates are cleared', () async {
      await sut.update(ids, location: const Option<LatLng?>.some(null));

      final apiLocation =
          verify(() => apiRepository.update(ids, location: captureAny(named: 'location'))).captured.single
              as Option<LatLng?>;
      final exifLocation =
          verify(() => exifRepository.update(ids, location: captureAny(named: 'location'))).captured.single
              as Option<LatLng?>;
      expect(apiLocation, isA<Some<LatLng?>>());
      expect(apiLocation.unwrapOrNull, isNull);
      expect(exifLocation, isA<Some<LatLng?>>());
      expect(exifLocation.unwrapOrNull, isNull);
    });
  });
}
