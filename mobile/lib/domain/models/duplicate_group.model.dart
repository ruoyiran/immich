import 'package:immich_mobile/domain/models/asset/base_asset.model.dart';

class DuplicateGroup {
  const DuplicateGroup({
    required this.id,
    required this.captureDay,
    required this.assets,
    required this.suggestedKeepIds,
  });

  final String id;
  final DateTime captureDay;
  final List<RemoteAssetExif> assets;
  final Set<String> suggestedKeepIds;
}

class DuplicateResolution {
  const DuplicateResolution({required this.groupId, required this.keepAssetIds, required this.trashAssetIds});

  final String groupId;
  final Set<String> keepAssetIds;
  final Set<String> trashAssetIds;
}
