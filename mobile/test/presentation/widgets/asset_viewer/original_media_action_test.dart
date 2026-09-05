import 'package:flutter_test/flutter_test.dart';
import 'package:immich_mobile/domain/models/asset/base_asset.model.dart';
import 'package:immich_mobile/domain/models/config/app_config.dart';
import 'package:immich_mobile/domain/models/config/image_config.dart';
import 'package:immich_mobile/domain/models/config/viewer_config.dart';
import 'package:immich_mobile/presentation/widgets/asset_viewer/original_media_action.widget.dart';

import '../../../unit/factories/remote_asset_factory.dart';

void main() {
  group('originalMediaActionFor', () {
    test('offers the original image when image originals are disabled', () {
      final asset = RemoteAssetFactory.create();

      expect(originalMediaActionFor(asset: asset, config: const AppConfig()), OriginalMediaKind.image);
    });

    test('does not offer an image already configured or requested as original', () {
      final asset = RemoteAssetFactory.create();

      expect(
        originalMediaActionFor(
          asset: asset,
          config: const AppConfig(image: ImageConfig(loadOriginal: true)),
        ),
        isNull,
      );
      expect(originalMediaActionFor(asset: asset, config: const AppConfig(), originalRequested: true), isNull);
    });

    test('does not offer an original for animated images or direct files', () {
      final animated = RemoteAssetFactory.create().copyWith(durationMs: 1000);
      final image = RemoteAssetFactory.create();

      expect(originalMediaActionFor(asset: animated, config: const AppConfig()), isNull);
      expect(originalMediaActionFor(asset: image, config: const AppConfig(), hasDirectFile: true), isNull);
    });

    test('offers the original video only for remote playback', () {
      final remote = RemoteAssetFactory.create(type: AssetType.video);
      final merged = RemoteAssetFactory.create(type: AssetType.video, localId: 'local-video');

      expect(originalMediaActionFor(asset: remote, config: const AppConfig()), OriginalMediaKind.video);
      expect(originalMediaActionFor(asset: merged, config: const AppConfig()), isNull);
      expect(
        originalMediaActionFor(
          asset: remote,
          config: const AppConfig(viewer: ViewerConfig(loadOriginalVideo: true)),
        ),
        isNull,
      );
    });

    test('treats remote motion playback as video', () {
      final motion = RemoteAssetFactory.create().copyWith(livePhotoVideoId: 'motion-video');

      expect(
        originalMediaActionFor(asset: motion, config: const AppConfig(), isPlayingMotionVideo: true),
        OriginalMediaKind.video,
      );
    });
  });

  test('selectRemoteVideoEndpoint honors a one-time original request', () {
    expect(selectRemoteVideoEndpoint(loadOriginalVideo: false, forceOriginal: false), 'video/playback');
    expect(selectRemoteVideoEndpoint(loadOriginalVideo: false, forceOriginal: true), 'original');
    expect(selectRemoteVideoEndpoint(loadOriginalVideo: true, forceOriginal: false), 'original');
  });
}
