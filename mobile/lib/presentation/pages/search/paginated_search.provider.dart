import 'dart:async';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/domain/models/asset/base_asset.model.dart';
import 'package:immich_mobile/domain/models/search_result.model.dart';
import 'package:immich_mobile/models/search/search_filter.model.dart';
import 'package:immich_mobile/providers/infrastructure/search.provider.dart';

final searchPreFilterProvider = NotifierProvider<SearchFilterProvider, SearchFilter?>(SearchFilterProvider.new);

class SearchFilterProvider extends Notifier<SearchFilter?> {
  @override
  SearchFilter? build() {
    return null;
  }

  void setFilter(SearchFilter? filter) {
    state = filter;
  }

  void clear() {
    state = null;
  }
}

class SearchState {
  final List<BaseAsset> assets;
  final int? nextPage;
  final bool isLoading;

  const SearchState({this.assets = const [], this.nextPage = 1, this.isLoading = false});
}

final paginatedSearchProvider = StateNotifierProvider<PaginatedSearchNotifier, SearchState>(
  (ref) => PaginatedSearchNotifier(ref.watch(searchServiceProvider).search),
);

class PaginatedSearchNotifier extends StateNotifier<SearchState> {
  final Future<SearchResult?> Function(SearchFilter filter, int page) _search;
  final _assetCountController = StreamController<int>.broadcast();
  final Set<String> _removedRemoteIds = {};
  int _generation = 0;

  PaginatedSearchNotifier(this._search) : super(const SearchState());

  Stream<int> get assetCount => _assetCountController.stream;

  Future<void> search(SearchFilter filter) async {
    if (state.nextPage == null || state.isLoading) {
      return;
    }

    final generation = _generation;
    final page = state.nextPage!;
    state = SearchState(assets: state.assets, nextPage: page, isLoading: true);

    final result = await _search(filter, page);

    if (generation != _generation) {
      return;
    }

    if (result == null) {
      state = SearchState(assets: state.assets, nextPage: state.nextPage);
      return;
    }

    final assets = [
      ...state.assets,
      ...result.assets.where((asset) => asset.remoteId == null || !_removedRemoteIds.contains(asset.remoteId)),
    ];
    state = SearchState(assets: assets, nextPage: result.nextPage);

    _assetCountController.add(assets.length);
  }

  void clear() {
    _generation++;
    _removedRemoteIds.clear();
    state = const SearchState();
    _assetCountController.add(0);
  }

  void removeRemoteIds(Set<String> ids) {
    if (ids.isEmpty) {
      return;
    }
    _removedRemoteIds.addAll(ids);
    final assets = state.assets.where((asset) => asset.remoteId == null || !ids.contains(asset.remoteId)).toList();
    if (assets.length == state.assets.length) {
      return;
    }
    state = SearchState(assets: assets, nextPage: state.nextPage, isLoading: state.isLoading);
    _assetCountController.add(assets.length);
  }

  @override
  void dispose() {
    unawaited(_assetCountController.close());
    super.dispose();
  }
}
