import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/domain/models/asset/base_asset.model.dart';
import 'package:immich_mobile/domain/models/exif.model.dart';
import 'package:immich_mobile/domain/models/original_media.model.dart';
import 'package:immich_mobile/domain/services/asset.service.dart';
import 'package:immich_mobile/providers/infrastructure/asset.provider.dart';
import 'package:immich_mobile/providers/infrastructure/asset_viewer/asset.provider.dart';
import 'package:mocktail/mocktail.dart';

import '../../../unit/factories/remote_asset_factory.dart';

class MockAssetService extends Mock implements AssetService {}

void main() {
  test('reads the motion component size for original motion-video playback', () async {
    final service = MockAssetService();
    final still = RemoteAssetFactory.create().copyWith(livePhotoVideoId: 'motion-video');
    final motion = RemoteAssetFactory.create(id: 'motion-video', type: AssetType.video);
    when(() => service.getRemoteAsset('motion-video')).thenAnswer((_) async => motion);
    when(() => service.getExif(motion)).thenAnswer((_) async => const ExifInfo(fileSize: 42 * 1024 * 1024));
    final container = ProviderContainer(overrides: [assetServiceProvider.overrideWithValue(service)]);
    addTearDown(container.dispose);

    final size = await container.read(
      originalMediaFileSizeProvider((asset: still, type: OriginalMediaType.video)).future,
    );

    expect(size, 42 * 1024 * 1024);
  });
}
