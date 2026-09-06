import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:immich_mobile/domain/models/asset/base_asset.model.dart';
import 'package:immich_mobile/domain/models/timeline.model.dart';
import 'package:immich_mobile/domain/services/timeline.service.dart';

import '../../fixtures/asset.stub.dart';

void main() {
  test('watchBuckets shares the single upstream bucket subscription', () async {
    final bucketController = StreamController<List<Bucket>>.broadcast(sync: true);
    int sourceCallCount = 0;
    final service = TimelineService((
      assetSource: (_, __) async => <BaseAsset>[],
      bucketSource: () {
        sourceCallCount++;
        return bucketController.stream;
      },
      origin: TimelineOrigin.main,
    ));
    addTearDown(bucketController.close);
    addTearDown(service.dispose);

    final firstBuckets = service.watchBuckets().first;
    final secondBuckets = service.watchBuckets().first;

    expect(sourceCallCount, 1);

    const buckets = [Bucket(assetCount: 0)];
    bucketController.add(buckets);
    await expectLater(Future.wait([firstBuckets, secondBuckets]), completion([buckets, buckets]));
  });

  test('watchBuckets replays the latest buckets to a late subscriber', () async {
    final bucketController = StreamController<List<Bucket>>.broadcast(sync: true);
    final service = TimelineService((
      assetSource: (_, __) async => <BaseAsset>[],
      bucketSource: () => bucketController.stream,
      origin: TimelineOrigin.main,
    ));
    addTearDown(bucketController.close);
    addTearDown(service.dispose);

    const buckets = [Bucket(assetCount: 0)];
    bucketController.add(buckets);
    await Future<void>.delayed(Duration.zero);

    await expectLater(service.watchBuckets().first.timeout(const Duration(milliseconds: 100)), completion(buckets));
  });

  test('unchanged buckets refresh assets without rebuilding public bucket consumers', () async {
    final bucketController = StreamController<List<Bucket>>.broadcast(sync: true);
    final assetLoads = [Completer<void>(), Completer<void>()];
    int assetLoadCount = 0;
    final service = TimelineService((
      assetSource: (_, __) async {
        assetLoads[assetLoadCount].complete();
        assetLoadCount++;
        return [LocalAssetStub.image1];
      },
      bucketSource: () => bucketController.stream,
      origin: TimelineOrigin.main,
    ));
    addTearDown(bucketController.close);
    addTearDown(service.dispose);

    final receivedBuckets = <List<Bucket>>[];
    final subscription = service.watchBuckets().listen(receivedBuckets.add);
    addTearDown(subscription.cancel);

    const buckets = [Bucket(assetCount: 1)];
    bucketController.add(buckets);
    await assetLoads.first.future;
    bucketController.add(buckets);
    await assetLoads.last.future;

    expect(assetLoadCount, 2);
    expect(receivedBuckets, [buckets]);
  });

  test('coalesces bucket refreshes that arrive while an asset load is in flight', () async {
    final bucketController = StreamController<List<Bucket>>.broadcast(sync: true);
    final firstLoad = Completer<void>();
    var assetLoadCount = 0;
    final service = TimelineService((
      assetSource: (_, __) async {
        assetLoadCount++;
        if (assetLoadCount == 1) {
          await firstLoad.future;
        }
        return [LocalAssetStub.image1];
      },
      bucketSource: () => bucketController.stream,
      origin: TimelineOrigin.main,
    ));
    addTearDown(bucketController.close);
    addTearDown(service.dispose);

    bucketController.add(const [Bucket(assetCount: 1)]);
    await Future<void>.delayed(Duration.zero);
    expect(assetLoadCount, 1);

    for (var count = 2; count <= 10; count++) {
      bucketController.add([Bucket(assetCount: count)]);
    }
    await Future<void>.delayed(Duration.zero);
    expect(assetLoadCount, 1);

    firstLoad.complete();
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(assetLoadCount, 2);
    expect(service.totalAssets, 10);
  });

  test('reload refreshes the buffered assets without a bucket change', () async {
    final bucketController = StreamController<List<Bucket>>.broadcast(sync: true);
    var currentAsset = LocalAssetStub.image1;
    final service = TimelineService((
      assetSource: (_, __) async => [currentAsset],
      bucketSource: () => bucketController.stream,
      origin: TimelineOrigin.localAlbum,
    ));
    addTearDown(bucketController.close);
    addTearDown(service.dispose);

    bucketController.add(const [Bucket(assetCount: 1)]);
    await Future<void>.delayed(Duration.zero);
    expect(service.getAsset(0).id, LocalAssetStub.image1.id);

    currentAsset = LocalAssetStub.image2;
    await service.reload();

    expect(service.getAsset(0).id, LocalAssetStub.image2.id);
  });

  test('markUploaded immediately links a buffered local asset', () async {
    final bucketController = StreamController<List<Bucket>>.broadcast(sync: true);
    final service = TimelineService((
      assetSource: (_, __) async => [LocalAssetStub.image1],
      bucketSource: () => bucketController.stream,
      origin: TimelineOrigin.localAlbum,
    ));
    addTearDown(bucketController.close);
    addTearDown(service.dispose);

    bucketController.add(const [Bucket(assetCount: 1)]);
    await Future<void>.delayed(Duration.zero);

    expect(service.markUploaded(LocalAssetStub.image1.id, 'remote-id'), isTrue);
    expect(service.getAsset(0).remoteId, 'remote-id');
    expect(service.markUploaded(LocalAssetStub.image1.id, 'remote-id'), isFalse);
  });

  test('loadAssets returns a short page when bucket counts are stale', () async {
    final bucketController = StreamController<List<Bucket>>.broadcast(sync: true);
    var assets = [LocalAssetStub.image1];
    final assetLoads = [Completer<void>(), Completer<void>()];
    var assetLoadCount = 0;
    final service = TimelineService((
      assetSource: (offset, count) async {
        if (assetLoadCount < assetLoads.length) {
          assetLoads[assetLoadCount].complete();
        }
        assetLoadCount++;
        return assets.skip(offset).take(count).toList(growable: false);
      },
      bucketSource: () => bucketController.stream,
      origin: TimelineOrigin.remoteAlbum,
    ));
    addTearDown(bucketController.close);
    addTearDown(service.dispose);

    bucketController.add(const [Bucket(assetCount: 1)]);
    await assetLoads.first.future;

    assets = const [];
    bucketController.add(const [Bucket(assetCount: 1)]);
    await assetLoads.last.future;

    await expectLater(service.loadAssets(0, 1), completion(isEmpty));
  });

  test('dispose prevents an in-flight bucket refresh from repopulating the timeline', () async {
    final bucketController = StreamController<List<Bucket>>.broadcast(sync: true);
    final assetLoadStarted = Completer<void>();
    final assetLoadResult = Completer<List<BaseAsset>>();
    final service = TimelineService((
      assetSource: (_, __) {
        assetLoadStarted.complete();
        return assetLoadResult.future;
      },
      bucketSource: () => bucketController.stream,
      origin: TimelineOrigin.main,
    ));
    addTearDown(bucketController.close);

    bucketController.add(const [Bucket(assetCount: 1)]);
    await assetLoadStarted.future;
    await service.dispose();
    assetLoadResult.complete([LocalAssetStub.image1]);
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(service.totalAssets, 0);
  });
}
