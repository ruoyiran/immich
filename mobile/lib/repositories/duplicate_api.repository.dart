import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/domain/models/duplicate_group.model.dart';
import 'package:immich_mobile/extensions/asset_extensions.dart';
import 'package:immich_mobile/providers/api.provider.dart';
import 'package:openapi/api.dart';

final duplicateApiRepositoryProvider = Provider<DuplicateRepository>(
  (ref) => DuplicateApiRepository(ref.watch(apiServiceProvider).duplicatesApi),
);

abstract interface class DuplicateRepository {
  Future<List<DuplicateGroup>> getGroups();

  Future<void> dismissGroups(List<String> ids);

  Future<List<BulkIdResponseDto>> resolve(List<DuplicateResolution> groups);
}

class DuplicateApiRepository implements DuplicateRepository {
  const DuplicateApiRepository(this._api);

  final DuplicatesApi _api;

  @override
  Future<List<DuplicateGroup>> getGroups() async {
    final response = await _api.getAssetDuplicates() ?? const <DuplicateResponseDto>[];
    final groups = response.map(_toDomain).toList(growable: false)
      ..sort((left, right) {
        final day = right.captureDay.compareTo(left.captureDay);
        if (day != 0) {
          return day;
        }
        final similarity = right.maxSimilarity.compareTo(left.maxSimilarity);
        return similarity != 0 ? similarity : left.id.compareTo(right.id);
      });
    return groups;
  }

  @override
  Future<void> dismissGroups(List<String> ids) => _api.deleteDuplicates(BulkIdsDto(ids: ids));

  @override
  Future<List<BulkIdResponseDto>> resolve(List<DuplicateResolution> groups) async {
    return await _api.resolveDuplicates(
          DuplicateResolveDto(
            groups: groups
                .map(
                  (group) => DuplicateResolveGroupDto(
                    duplicateId: group.groupId,
                    keepAssetIds: group.keepAssetIds.toList(growable: false),
                    trashAssetIds: group.trashAssetIds.toList(growable: false),
                  ),
                )
                .toList(growable: false),
          ),
        ) ??
        const <BulkIdResponseDto>[];
  }

  DuplicateGroup _toDomain(DuplicateResponseDto dto) {
    if (dto.assets.length < 2) {
      throw const FormatException('Duplicate group must contain at least two assets');
    }
    final firstDay = _dateOnly(dto.assets.first.localDateTime);
    if (dto.assets.any((asset) => _dateOnly(asset.localDateTime) != firstDay)) {
      throw const FormatException('Duplicate group contains assets from different capture days');
    }
    final memberIDs = dto.assets.map((asset) => asset.id).toSet();
    final keepIDs = dto.suggestedKeepAssetIds.toSet();
    if (keepIDs.isEmpty || !memberIDs.containsAll(keepIDs)) {
      throw const FormatException('Duplicate group has invalid suggested keep assets');
    }
    final maxSimilarity = dto.maxSimilarity.toDouble();
    if (!maxSimilarity.isFinite || maxSimilarity < 0.9 || maxSimilarity > 1) {
      throw const FormatException('Duplicate group has invalid similarity');
    }
    return DuplicateGroup(
      id: dto.duplicateId,
      captureDay: firstDay,
      maxSimilarity: maxSimilarity,
      assets: dto.assets.map((asset) => asset.toDtoWithExif()).toList(growable: false),
      suggestedKeepIds: keepIDs,
    );
  }

  DateTime _dateOnly(DateTime value) => DateTime(value.year, value.month, value.day);
}
