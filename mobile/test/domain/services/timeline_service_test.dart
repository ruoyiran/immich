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
