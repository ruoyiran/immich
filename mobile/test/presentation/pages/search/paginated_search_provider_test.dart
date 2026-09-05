import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:immich_mobile/domain/models/asset/base_asset.model.dart';
import 'package:immich_mobile/domain/models/search_result.model.dart';
import 'package:immich_mobile/models/search/search_filter.model.dart';
import 'package:immich_mobile/presentation/pages/search/paginated_search.provider.dart';
import 'package:immich_mobile/utils/option.dart';

SearchFilter filter(String filename) => SearchFilter(
  filename: filename,
  people: {},
  location: SearchLocationFilter(),
  camera: SearchCameraFilter(),
  date: SearchDateFilter(),
  display: const SearchDisplayFilters(isNotInAlbum: false, isArchive: false, isFavorite: false),
  rating: SearchRatingFilter(rating: const Option.none()),
  mediaType: AssetType.other,
);

RemoteAsset asset(String id) => RemoteAsset(
  id: id,
  name: '$id.jpg',
  ownerId: 'owner',
  checksum: 'checksum-$id',
  type: AssetType.image,
  createdAt: DateTime.utc(2024),
  updatedAt: DateTime.utc(2024),
  isEdited: false,
);

void main() {
  test('removeRemoteIds immediately removes trashed search results', () async {
    final notifier = PaginatedSearchNotifier((_, _) async => SearchResult(assets: [asset('a'), asset('b')]));

    await notifier.search(filter('first'));
    notifier.removeRemoteIds({'a'});

    expect(notifier.state.assets.map((item) => item.remoteId), ['b']);
  });

  test('a cleared stale request cannot overwrite a newer search', () async {
    final first = Completer<SearchResult?>();
    final second = Completer<SearchResult?>();
    final notifier = PaginatedSearchNotifier((value, _) {
      return value.filename == 'first' ? first.future : second.future;
    });

    final firstSearch = notifier.search(filter('first'));
    notifier.clear();
    final secondSearch = notifier.search(filter('second'));
    second.complete(SearchResult(assets: [asset('new')]));
    await secondSearch;
    first.complete(SearchResult(assets: [asset('stale')]));
    await firstSearch;

    expect(notifier.state.assets.map((item) => item.remoteId), ['new']);
  });
}
