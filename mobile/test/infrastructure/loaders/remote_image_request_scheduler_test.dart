import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:immich_mobile/infrastructure/loaders/remote_image_request_scheduler.dart';

void main() {
  test('limits active work and starts the newest visible request first', () async {
    final scheduler = RemoteImageRequestScheduler(maxConcurrent: 2, maxPending: 4);
    final started = <int>[];
    final completions = <int, Completer<int>>{};

    Future<int> operation(int id) {
      started.add(id);
      final completion = Completer<int>();
      completions[id] = completion;
      return completion.future;
    }

    final first = scheduler.schedule(priority: RemoteImageRequestPriority.visible, operation: () => operation(1));
    final second = scheduler.schedule(priority: RemoteImageRequestPriority.visible, operation: () => operation(2));
    final olderPending = scheduler.schedule(
      priority: RemoteImageRequestPriority.visible,
      operation: () => operation(3),
    );
    final newestPending = scheduler.schedule(
      priority: RemoteImageRequestPriority.visible,
      operation: () => operation(4),
    );

    expect(started, [1, 2]);

    completions[1]!.complete(1);
    await first.value;
    await pumpEventQueue();
    expect(started, [1, 2, 4]);

    completions[2]!.complete(2);
    await second.value;
    await pumpEventQueue();
    expect(started, [1, 2, 4, 3]);

    completions[3]!.complete(3);
    completions[4]!.complete(4);
    await Future.wait([olderPending.value, newestPending.value]);
  });

  test('removes a cancelled pending request before it reaches the network', () async {
    final scheduler = RemoteImageRequestScheduler(maxConcurrent: 1, maxPending: 4);
    final started = <int>[];
    final firstCompletion = Completer<int>();

    final first = scheduler.schedule(
      priority: RemoteImageRequestPriority.visible,
      operation: () {
        started.add(1);
        return firstCompletion.future;
      },
    );
    final cancelled = scheduler.schedule(
      priority: RemoteImageRequestPriority.visible,
      operation: () async {
        started.add(2);
        return 2;
      },
    );
    final newest = scheduler.schedule(
      priority: RemoteImageRequestPriority.visible,
      operation: () async {
        started.add(3);
        return 3;
      },
    );

    cancelled.cancel();
    expect(await cancelled.value, isNull);

    firstCompletion.complete(1);
    await first.value;
    await pumpEventQueue();

    expect(started, [1, 3]);
    expect(await newest.value, 3);
  });

  test('bounds pending work and defers the oldest visible request', () async {
    final scheduler = RemoteImageRequestScheduler(maxConcurrent: 1, maxPending: 2);
    final firstCompletion = Completer<int>();
    final thirdCompletion = Completer<int>();
    final fourthCompletion = Completer<int>();
    final started = <int>[];

    final first = scheduler.schedule(
      priority: RemoteImageRequestPriority.visible,
      operation: () {
        started.add(1);
        return firstCompletion.future;
      },
    );
    final oldestPending = scheduler.schedule(
      priority: RemoteImageRequestPriority.visible,
      operation: () async {
        started.add(2);
        return 2;
      },
    );
    scheduler.schedule(
      priority: RemoteImageRequestPriority.visible,
      operation: () {
        started.add(3);
        return thirdCompletion.future;
      },
    );
    final newestPending = scheduler.schedule(
      priority: RemoteImageRequestPriority.visible,
      operation: () {
        started.add(4);
        return fourthCompletion.future;
      },
    );

    await expectLater(oldestPending.value, throwsA(isA<RemoteImageRequestDeferredException>()));

    firstCompletion.complete(1);
    await first.value;
    await pumpEventQueue();
    expect(started, [1, 4]);

    fourthCompletion.complete(4);
    expect(await newestPending.value, 4);
    await pumpEventQueue();
    thirdCompletion.complete(3);
  });

  test('promotes an older request after the starvation threshold', () async {
    final firstQueuedAt = DateTime(2026, 9, 4);
    var now = firstQueuedAt;
    final scheduler = RemoteImageRequestScheduler(
      maxConcurrent: 1,
      maxPending: 4,
      starvationThreshold: const Duration(seconds: 2),
      now: () => now,
    );
    final firstCompletion = Completer<int>();
    final olderCompletion = Completer<int>();
    final newerCompletion = Completer<int>();
    final started = <int>[];

    final first = scheduler.schedule(
      priority: RemoteImageRequestPriority.visible,
      operation: () {
        started.add(1);
        return firstCompletion.future;
      },
    );
    now = firstQueuedAt.add(const Duration(seconds: 3));
    final older = scheduler.schedule(
      priority: RemoteImageRequestPriority.retry,
      enqueuedAt: firstQueuedAt,
      operation: () {
        started.add(2);
        return olderCompletion.future;
      },
    );
    final newer = scheduler.schedule(
      priority: RemoteImageRequestPriority.visible,
      operation: () {
        started.add(3);
        return newerCompletion.future;
      },
    );

    firstCompletion.complete(1);
    await first.value;
    await pumpEventQueue();

    expect(started, [1, 2]);
    olderCompletion.complete(2);
    expect(await older.value, 2);
    await pumpEventQueue();
    newerCompletion.complete(3);
    expect(await newer.value, 3);
  });

  test('queue deferrals do not consume the network retry budget', () {
    final budget = RemoteImageRetryBudget([const Duration(milliseconds: 500), const Duration(seconds: 1)]);

    for (var i = 0; i < 100; i++) {
      expect(budget.deferralDelay, const Duration(milliseconds: 100));
      expect(budget.priority, RemoteImageRequestPriority.visible);
    }

    expect(budget.nextFailureDelay(retryable: true), const Duration(milliseconds: 500));
    expect(budget.priority, RemoteImageRequestPriority.retry);
    expect(budget.deferralDelay, const Duration(milliseconds: 100));
    expect(budget.nextFailureDelay(retryable: true), const Duration(seconds: 1));
    expect(budget.nextFailureDelay(retryable: true), isNull);
  });

  test('visible work stays ahead of retry work', () async {
    final scheduler = RemoteImageRequestScheduler(maxConcurrent: 1, maxPending: 4);
    final firstCompletion = Completer<int>();
    final retryCompletion = Completer<int>();
    final visibleCompletion = Completer<int>();
    final started = <int>[];

    final first = scheduler.schedule(
      priority: RemoteImageRequestPriority.visible,
      operation: () {
        started.add(1);
        return firstCompletion.future;
      },
    );
    final retry = scheduler.schedule(
      priority: RemoteImageRequestPriority.retry,
      operation: () {
        started.add(2);
        return retryCompletion.future;
      },
    );
    final visible = scheduler.schedule(
      priority: RemoteImageRequestPriority.visible,
      operation: () {
        started.add(3);
        return visibleCompletion.future;
      },
    );

    firstCompletion.complete(1);
    await first.value;
    await pumpEventQueue();
    expect(started, [1, 3]);
    visibleCompletion.complete(3);
    expect(await visible.value, 3);
    await pumpEventQueue();
    retryCompletion.complete(2);
    expect(await retry.value, 2);
  });
}
