// ignore_for_file: avoid_slow_async_io, close_sinks

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:immich_mobile/domain/models/original_media.model.dart';
import 'package:immich_mobile/repositories/original_media_cache.repository.dart';

import '../unit/factories/remote_asset_factory.dart';

class _ControlledClient extends http.BaseClient {
  final started = Completer<void>();
  final response = StreamController<List<int>>();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    started.complete();
    return http.StreamedResponse(response.stream, 200);
  }
}

class _AbortAwareClient extends http.BaseClient {
  final started = Completer<void>();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final abortable = request as http.AbortableRequest;
    started.complete();
    await abortable.abortTrigger;
    throw http.RequestAbortedException(request.url);
  }
}

class _ChunkedClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return http.StreamedResponse(
      Stream.fromIterable([
        [1, 2],
        [3, 4],
      ]),
      200,
      contentLength: 4,
    );
  }
}

class _ControlledChunkClient extends http.BaseClient {
  final started = Completer<void>();
  final chunks = StreamController<List<int>>();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    started.complete();
    return http.StreamedResponse(chunks.stream, 200, contentLength: 4);
  }
}

class _RangeSizeClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    expect(request.method, 'GET');
    expect(request.headers['range'], 'bytes=0-0');
    return http.StreamedResponse(
      Stream.value([0]),
      206,
      contentLength: 1,
      headers: {'content-range': 'bytes 0-0/7340032'},
    );
  }
}

void main() {
  late Directory cacheDirectory;

  setUp(() async {
    cacheDirectory = await Directory.systemTemp.createTemp('immich-original-media-cache-test-');
  });

  tearDown(() async {
    if (await cacheDirectory.exists()) {
      await cacheDirectory.delete(recursive: true);
    }
  });

  OriginalMediaCacheRepository buildRepository(http.Client client) => OriginalMediaCacheRepository(
    client: client,
    cacheDirectory: () async => cacheDirectory,
    serverEndpoint: () => 'https://photos.example.test/api',
    requestHeaders: () => const {},
  );

  test('downloads an original once and reuses it from a new repository instance', () async {
    var requestCount = 0;
    final asset = RemoteAssetFactory.create(id: '11111111-1111-4111-8111-111111111111', name: 'photo.jpg');
    final repository = buildRepository(
      MockClient((request) async {
        requestCount++;
        expect(request.url.path, '/api/assets/${asset.id}/original');
        expect(request.headers['cache-control'], 'no-store');
        return http.Response.bytes([1, 2, 3, 4], 200);
      }),
    );

    final downloaded = await repository.getOrDownload(asset, OriginalMediaType.image);
    final persisted = await buildRepository(
      MockClient((_) => throw StateError('cached media must not be downloaded again')),
    ).getOrDownload(asset, OriginalMediaType.image);

    expect(requestCount, 1);
    expect(await downloaded.readAsBytes(), [1, 2, 3, 4]);
    expect(persisted.path, downloaded.path);
  });

  test('invalidates cached media when the remote asset version changes', () async {
    final asset = RemoteAssetFactory.create(id: '22222222-2222-4222-8222-222222222222');
    final repository = buildRepository(MockClient((_) async => http.Response.bytes([1], 200)));
    await repository.getOrDownload(asset, OriginalMediaType.image);

    final updated = asset.copyWith(updatedAt: asset.updatedAt.add(const Duration(seconds: 1)));

    expect(await repository.get(updated, OriginalMediaType.image), isNull);
  });

  test('invalidates an edited original when its thumbnail revision changes', () async {
    final asset = RemoteAssetFactory.create(
      id: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
    ).copyWith(isEdited: true, thumbHash: 'first-edit');
    final repository = buildRepository(MockClient((_) async => http.Response.bytes([1], 200)));
    await repository.getOrDownload(asset, OriginalMediaType.image);

    final reedited = asset.copyWith(thumbHash: 'second-edit');

    expect(await repository.get(reedited, OriginalMediaType.image), isNull);
  });

  test('coalesces concurrent requests for the same original', () async {
    var requestCount = 0;
    final asset = RemoteAssetFactory.create(id: '33333333-3333-4333-8333-333333333333');
    final repository = buildRepository(
      MockClient((_) async {
        requestCount++;
        await Future<void>.delayed(const Duration(milliseconds: 10));
        return http.Response.bytes([5, 6, 7], 200);
      }),
    );

    final files = await Future.wait([
      repository.getOrDownload(asset, OriginalMediaType.image),
      repository.getOrDownload(asset, OriginalMediaType.image),
    ]);

    expect(requestCount, 1);
    expect(files.first.path, files.last.path);
  });

  test('uses the motion component id when caching an original motion video', () async {
    late Uri requestedUrl;
    final asset = RemoteAssetFactory.create(
      id: '44444444-4444-4444-8444-444444444444',
    ).copyWith(livePhotoVideoId: '55555555-5555-4555-8555-555555555555');
    final repository = buildRepository(
      MockClient((request) async {
        requestedUrl = request.url;
        return http.Response.bytes([8, 9], 200);
      }),
    );

    await repository.getOrDownload(asset, OriginalMediaType.video);

    expect(requestedUrl.path, '/api/assets/${asset.livePhotoVideoId}/original');
  });

  test('clear removes cached originals and reports their size', () async {
    final asset = RemoteAssetFactory.create(id: '66666666-6666-4666-8666-666666666666');
    final repository = buildRepository(MockClient((_) async => http.Response.bytes([1, 2, 3], 200)));
    await repository.getOrDownload(asset, OriginalMediaType.image);

    expect(await repository.clear(), 3);
    expect(await repository.get(asset, OriginalMediaType.image), isNull);
  });

  test('does not retain an original larger than the cache limit', () async {
    final asset = RemoteAssetFactory.create(id: 'cccccccc-cccc-4ccc-8ccc-cccccccccccc');
    final repository = OriginalMediaCacheRepository(
      client: MockClient((_) async => http.Response.bytes([1, 2, 3, 4], 200)),
      cacheDirectory: () async => cacheDirectory,
      serverEndpoint: () => 'https://photos.example.test/api',
      requestHeaders: () => const {},
      maxCacheSize: 3,
    );

    await expectLater(
      repository.getOrDownload(asset, OriginalMediaType.image),
      throwsA(isA<OriginalMediaCacheLimitException>()),
    );
    expect(await cacheDirectory.list().toList(), isEmpty);
  });

  test('removes recent abandoned partial downloads before caching another original', () async {
    final partial = File('${cacheDirectory.path}/abandoned.part')..writeAsBytesSync([1, 2]);
    final asset = RemoteAssetFactory.create(id: 'dddddddd-dddd-4ddd-8ddd-dddddddddddd');
    final repository = buildRepository(MockClient((_) async => http.Response.bytes([3], 200)));

    await repository.getOrDownload(asset, OriginalMediaType.image);

    expect(partial.existsSync(), isFalse);
  });

  test('a cache clear prevents an active download from restoring the cleared file', () async {
    final client = _ControlledClient();
    final asset = RemoteAssetFactory.create(id: 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee');
    final repository = buildRepository(client);

    final downloading = repository.getOrDownload(asset, OriginalMediaType.image);
    await client.started.future;
    await Future<void>.delayed(Duration.zero);
    await repository.clear();
    client.response.add([1, 2, 3]);
    unawaited(client.response.close());

    await expectLater(downloading, throwsA(isA<OriginalMediaCacheClearedException>()));
    expect(cacheDirectory.existsSync(), isFalse);
  });

  test('translates a clear-triggered HTTP abort into a cache-clear result', () async {
    final client = _AbortAwareClient();
    final asset = RemoteAssetFactory.create(id: '12121212-1212-4212-8212-121212121212');
    final repository = buildRepository(client);

    final downloading = repository.getOrDownload(asset, OriginalMediaType.video);
    await client.started.future;
    await repository.clear();

    await expectLater(downloading, throwsA(isA<OriginalMediaCacheClearedException>()));
  });

  test('reports byte progress while downloading an original', () async {
    final asset = RemoteAssetFactory.create(id: '13131313-1313-4313-8313-131313131313');
    final repository = buildRepository(_ChunkedClient());
    final updates = <OriginalMediaDownloadProgress>[];

    await repository.getOrDownload(asset, OriginalMediaType.image, onProgress: updates.add);

    expect(updates, [
      (downloadedBytes: 0, totalBytes: 4),
      (downloadedBytes: 2, totalBytes: 4),
      (downloadedBytes: 4, totalBytes: 4),
    ]);
  });

  test('reads the exact remote original size with a range request', () async {
    final asset = RemoteAssetFactory.create(id: '15151515-1515-4515-8515-151515151515').copyWith(isEdited: true);
    final repository = buildRepository(_RangeSizeClient());

    expect(await repository.getRemoteSize(asset, OriginalMediaType.image), 7340032);
  });

  test('replays current progress to a viewer joining an active download', () async {
    final client = _ControlledChunkClient();
    final asset = RemoteAssetFactory.create(id: '14141414-1414-4414-8414-141414141414');
    final repository = buildRepository(client);
    final firstUpdates = <OriginalMediaDownloadProgress>[];
    final secondUpdates = <OriginalMediaDownloadProgress>[];

    final first = repository.getOrDownload(asset, OriginalMediaType.video, onProgress: firstUpdates.add);
    await client.started.future;
    client.chunks.add([1, 2]);
    await pumpEventQueue();

    final second = repository.getOrDownload(asset, OriginalMediaType.video, onProgress: secondUpdates.add);
    await pumpEventQueue();
    client.chunks.add([3, 4]);
    await client.chunks.close();
    await Future.wait([first, second]);

    expect(secondUpdates.first, (downloadedBytes: 2, totalBytes: 4));
    expect(secondUpdates.last, (downloadedBytes: 4, totalBytes: 4));
  });
}
