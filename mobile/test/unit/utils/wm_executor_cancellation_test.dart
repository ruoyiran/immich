import 'dart:async';
import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';
import 'package:immich_mobile/utils/isolate_worker.dart';
import 'package:immich_mobile/wm_executor.dart';
import 'package:worker_manager/worker_manager.dart';

GentleExecution<String> _workWithHeldCleanup(SendPort events) => (cancel) async {
  final release = ReceivePort();
  events.send(release.sendPort);
  try {
    await cancel.future;
  } finally {
    events.send('cleaning');
    await release.first;
    release.close();
    events.send('cleaned');
  }
  return 'done';
};

void main() {
  setUp(() => workerManagerPatch.init(isolatesCount: 1, dynamicSpawning: false));
  tearDown(workerManagerPatch.dispose);

  test('opt-in cancellation waits for the active isolate finally block', () async {
    final events = ReceivePort();
    final messages = StreamIterator<dynamic>(events);
    addTearDown(events.close);
    final task = workerManagerPatch.executeGentle(_workWithHeldCleanup(events.sendPort), waitForCancellation: true);
    final result = task.future.then<Object?>((value) => value, onError: (Object error) => error);
    var settled = false;
    unawaited(result.then((_) => settled = true));
    await messages.moveNext();
    final release = messages.current as SendPort;

    try {
      task.cancel();
      await messages.moveNext();
      expect(messages.current, 'cleaning');
      expect(settled, isFalse, reason: 'the database/native cleanup still owns the worker');
    } finally {
      release.send(null);
      await messages.moveNext();
      expect(messages.current, 'cleaned');
      await result;
    }

    expect(await result, isA<CanceledError>());
  });

  test('queued opt-in task cancels before the occupied worker is released', () async {
    final events = ReceivePort();
    final messages = StreamIterator<dynamic>(events);
    addTearDown(events.close);
    final active = workerManagerPatch.executeGentle(_workWithHeldCleanup(events.sendPort));
    final activeResult = active.future.then<Object?>((value) => value, onError: (Object error) => error);
    await messages.moveNext();
    final release = messages.current as SendPort;
    final queuedEvents = ReceivePort();
    addTearDown(queuedEvents.close);
    final queuedPort = queuedEvents.sendPort;
    var queuedStarted = false;
    queuedEvents.listen((_) => queuedStarted = true);
    final queued = workerManagerPatch.executeGentle((_) {
      queuedPort.send('started');
      return 'unexpected';
    }, waitForCancellation: true);
    final queuedResult = queued.future.then<Object?>((value) => value, onError: (Object error) => error);

    try {
      queued.cancel();
      expect(await queuedResult.timeout(const Duration(seconds: 5)), isA<CanceledError>());
    } finally {
      active.cancel();
      release.send(null);
    }
    await activeResult;
    // Running a follow-up task drains scheduling after the cancelled queue item.
    expect(await workerManagerPatch.executeGentle((_) => 'next'), 'next');
    expect(queuedStarted, isFalse);
  });

  test('late opt-in cancellation preserves a completed result', () async {
    final task = workerManagerPatch.executeGentle((_) => 'done', waitForCancellation: true);
    expect(await task, 'done');

    task.cancel();

    expect(await task, 'done');
    expect(await workerManagerPatch.executeGentle((_) => 'next'), 'next');
  });

  test('existing callers still observe cancellation before active cleanup finishes', () async {
    final events = ReceivePort();
    final messages = StreamIterator<dynamic>(events);
    addTearDown(events.close);
    final task = workerManagerPatch.executeGentle(_workWithHeldCleanup(events.sendPort));
    final result = task.future.then<Object?>((value) => value, onError: (Object error) => error);
    await messages.moveNext();
    final release = messages.current as SendPort;

    try {
      task.cancel();
      expect(await result.timeout(const Duration(seconds: 5)), isA<CanceledError>());
      await messages.moveNext();
      expect(messages.current, 'cleaning');
    } finally {
      release.send(null);
      await messages.moveNext();
      expect(messages.current, 'cleaned');
    }
  });
}
