import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/domain/models/asset/base_asset.model.dart';
import 'package:immich_mobile/domain/models/exif.model.dart';
import 'package:immich_mobile/domain/models/original_media.model.dart';
import 'package:immich_mobile/providers/infrastructure/asset.provider.dart';

final assetExifProvider = FutureProvider.autoDispose.family<ExifInfo?, BaseAsset>((ref, asset) {
  return ref.watch(assetServiceProvider).getExif(asset);
});

final originalMediaFileSizeProvider = FutureProvider.autoDispose
    .family<int?, ({RemoteAsset asset, OriginalMediaType type})>((ref, request) async {
      final service = ref.watch(assetServiceProvider);
      final motionId = request.asset.livePhotoVideoId;
      if (request.type == OriginalMediaType.video && motionId != null) {
        final motionAsset = await service.getRemoteAsset(motionId);
        if (motionAsset == null) {
          return null;
        }
        return (await service.getExif(motionAsset))?.fileSize;
      }
      return (await service.getExif(request.asset))?.fileSize;
    });
