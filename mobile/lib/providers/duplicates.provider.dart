import 'dart:async';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/domain/models/duplicate_group.model.dart';
import 'package:immich_mobile/repositories/duplicate_api.repository.dart';

class DuplicatesState {
  const DuplicatesState({
    required this.groups,
    required this.currentIndex,
    required this.trashSelections,
    this.minimumSimilarity = 0.9,
  });

  final List<DuplicateGroup> groups;
  final int currentIndex;
  final Map<String, Set<String>> trashSelections;
  final double minimumSimilarity;

  DuplicateGroup? get currentGroup => groups.isEmpty ? null : groups[currentIndex];

  List<DuplicateGroup> get visibleGroups =>
      groups.where((group) => group.maxSimilarity + 0.0000001 >= minimumSimilarity).toList(growable: false);

  int get selectedAssetCount =>
      visibleGroups.fold(0, (count, group) => count + (trashSelections[group.id]?.length ?? 0));

  Set<String> trashIdsFor(String groupId) => Set.unmodifiable(trashSelections[groupId] ?? const <String>{});

  DuplicatesState copyWith({
    List<DuplicateGroup>? groups,
    int? currentIndex,
    Map<String, Set<String>>? trashSelections,
    double? minimumSimilarity,
  }) => DuplicatesState(
    groups: groups ?? this.groups,
    currentIndex: currentIndex ?? this.currentIndex,
    trashSelections: trashSelections ?? this.trashSelections,
    minimumSimilarity: minimumSimilarity ?? this.minimumSimilarity,
  );
}

final duplicatesProvider = StateNotifierProvider.autoDispose<DuplicatesNotifier, AsyncValue<DuplicatesState>>((ref) {
  final notifier = DuplicatesNotifier(ref.watch(duplicateApiRepositoryProvider));
  unawaited(notifier.load());
  return notifier;
}, dependencies: [duplicateApiRepositoryProvider]);

class DuplicatesNotifier extends StateNotifier<AsyncValue<DuplicatesState>> {
  DuplicatesNotifier(this._repository) : super(const AsyncLoading());

  final DuplicateRepository _repository;

  Future<void> load() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final groups = await _repository.getGroups();
      return DuplicatesState(groups: groups, currentIndex: 0, trashSelections: _initialSelections(groups));
    });
  }

  void toggleTrash(String groupId, String assetId) {
    final current = state.valueOrNull;
    if (current == null) {
      return;
    }
    DuplicateGroup? group;
    for (final candidate in current.groups) {
      if (candidate.id == groupId) {
        group = candidate;
        break;
      }
    }
    if (group == null || !group.assets.any((asset) => asset.id == assetId)) {
      return;
    }
    final selections = _copySelections(current.trashSelections);
    final selected = selections.putIfAbsent(groupId, () => <String>{});
    selected.contains(assetId) ? selected.remove(assetId) : selected.add(assetId);
    if (selected.length == group.assets.length) {
      selected.remove(assetId);
      return;
    }
    state = AsyncData(current.copyWith(trashSelections: selections));
  }

  void setTrashIdsForGroup(String groupId, Set<String> trashIds) {
    final current = state.valueOrNull;
    if (current == null) {
      return;
    }

    state = AsyncData(current.copyWith(trashSelections: {...current.trashSelections, groupId: trashIds}));
  }

  void setMinimumSimilarity(double value) {
    final current = state.valueOrNull;
    if (current == null) {
      return;
    }
    final percentage = (value.clamp(0.9, 1.0) * 100).round();
    state = AsyncData(current.copyWith(minimumSimilarity: percentage / 100, currentIndex: 0));
  }

  Future<int> resolveAllSelected() async {
    final current = state.valueOrNull;
    if (current == null) {
      return 0;
    }

    final selectedCounts = <String, int>{};
    final resolutions = <DuplicateResolution>[];
    for (final group in current.visibleGroups) {
      final trash = current.trashIdsFor(group.id);
      if (trash.isEmpty) {
        continue;
      }
      selectedCounts[group.id] = trash.length;
      resolutions.add(
        DuplicateResolution(
          groupId: group.id,
          keepAssetIds: group.assets.map((asset) => asset.id).where((id) => !trash.contains(id)).toSet(),
          trashAssetIds: trash,
        ),
      );
    }
    if (resolutions.isEmpty) {
      return 0;
    }

    final response = await _repository.resolve(resolutions);
    final responseById = {for (final result in response) result.id: result};
    final successfulIds = resolutions
        .where((resolution) => responseById[resolution.groupId]?.success == true)
        .map((resolution) => resolution.groupId)
        .toSet();
    if (successfulIds.isNotEmpty) {
      _removeGroups(state.valueOrNull ?? current, successfulIds);
    }

    final failed = resolutions.where((resolution) => !successfulIds.contains(resolution.groupId)).toList();
    if (failed.isNotEmpty) {
      final message = responseById[failed.first.groupId]?.errorMessage.orElse(null);
      throw StateError(message ?? 'Failed to resolve selected duplicate groups');
    }
    return successfulIds.fold<int>(0, (count, id) => count + selectedCounts[id]!);
  }

  Future<void> resolveGroup(String groupId) async {
    final current = state.valueOrNull;
    if (current == null) {
      return;
    }

    final index = current.groups.indexWhere((group) => group.id == groupId);
    if (index < 0) {
      return;
    }

    state = AsyncData(current.copyWith(currentIndex: index));
    await resolveCurrent();
  }

  Future<void> dismissGroup(String groupId) async {
    final current = state.valueOrNull;
    if (current == null) {
      return;
    }

    final index = current.groups.indexWhere((group) => group.id == groupId);
    if (index < 0) {
      return;
    }

    state = AsyncData(current.copyWith(currentIndex: index));
    await dismissCurrent();
  }

  Future<void> resolveCurrent() async {
    final current = state.valueOrNull;
    final group = current?.currentGroup;
    if (current == null || group == null) {
      return;
    }
    final trash = current.trashIdsFor(group.id);
    final keep = group.assets.map((asset) => asset.id).where((id) => !trash.contains(id)).toSet();
    final response = await _repository.resolve([
      DuplicateResolution(groupId: group.id, keepAssetIds: keep, trashAssetIds: trash),
    ]);
    if (response.length != 1 || !response.single.success) {
      final message = response.isEmpty ? null : response.first.errorMessage.orElse(null);
      throw StateError(message ?? 'Failed to resolve duplicate group');
    }
    _removeGroups(current, {group.id});
  }

  Future<void> dismissCurrent() async {
    final current = state.valueOrNull;
    final group = current?.currentGroup;
    if (current == null || group == null) {
      return;
    }
    await _repository.dismissGroups([group.id]);
    _removeGroups(current, {group.id});
  }

  void previous() {
    final current = state.valueOrNull;
    if (current == null || current.currentIndex == 0) {
      return;
    }
    state = AsyncData(current.copyWith(currentIndex: current.currentIndex - 1));
  }

  void next() {
    final current = state.valueOrNull;
    if (current == null || current.currentIndex >= current.groups.length - 1) {
      return;
    }
    state = AsyncData(current.copyWith(currentIndex: current.currentIndex + 1));
  }

  void _removeGroups(DuplicatesState current, Set<String> groupIds) {
    final groups = current.groups.where((group) => !groupIds.contains(group.id)).toList(growable: false);
    final selections = _copySelections(current.trashSelections)
      ..removeWhere((groupId, _) => groupIds.contains(groupId));
    final index = groups.isEmpty || current.currentIndex >= groups.length ? 0 : current.currentIndex;
    state = AsyncData(current.copyWith(groups: groups, currentIndex: index, trashSelections: selections));
  }

  static Map<String, Set<String>> _initialSelections(List<DuplicateGroup> groups) => {
    for (final group in groups)
      group.id: group.assets.map((asset) => asset.id).where((id) => !group.suggestedKeepIds.contains(id)).toSet(),
  };

  static Map<String, Set<String>> _copySelections(Map<String, Set<String>> source) => {
    for (final entry in source.entries) entry.key: {...entry.value},
  };
}
