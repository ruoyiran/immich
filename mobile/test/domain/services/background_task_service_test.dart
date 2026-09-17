import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:immich_mobile/domain/services/background_task.service.dart';
import 'package:worker_manager/worker_manager.dart';

import '../../mocks/background_task_host.mock.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeBackgroundTaskHost host;
  late BackgroundTaskService service;

  setUp(() {
    host = FakeBackgroundTaskHost();
    service = BackgroundTaskService(host);
  });
  tearDown(() => service.dispose());

  test('waits for native protection before starting network work', () async {
    host.startResult = Completer<bool>();
    var started = false;
    final work = service.run(
      title: 'Sync',
      description: 'Photos',
      action: (task) async {
        started = true;
        return 42;
      },
    );
    await Future<void>.delayed(Duration.zero);
    expect(started, isFalse);
    host.startResult!.complete(true);
    expect(await work, 42);
    expect(host.active, isEmpty);
    expect(host.finished, hasLength(1));
  });

  test('finishing sync does not release a concurrent upload', () async {
    final sync = Completer<void>();
    final upload = Completer<void>();
    final syncWork = service.run(title: 'Sync', description: '', action: (_) => sync.future);
    final uploadWork = service.run(title: 'Upload', description: '', action: (_) => upload.future);
    await Future<void>.delayed(Duration.zero);
    expect(host.active, hasLength(2));
    sync.complete();
    await syncWork;
    expect(host.active, hasLength(1));
    upload.complete();
    await uploadWork;
    expect(host.active, isEmpty);
  });

  test('protected work survives background and foreground without restarting', () async {
    final done = Completer<int>();
    var attempts = 0;
    final work = service.run(
      title: 'Sync',
      description: '',
      action: (task) => task.run((_) {
        attempts++;
        return done.future;
      }),
    );
    await Future<void>.delayed(Duration.zero);
    await service.onBackground();
    await service.onForeground();
    expect(attempts, 1);
    done.complete(7);
    expect(await work, 7);
  });

  test('expiration interrupts work and retries only after foreground resume', () async {
    final started = Completer<void>();
    var attempts = 0;
    final work = service.run(
      title: 'Sync',
      description: '',
      action: (task) => task.run((cancel) async {
        attempts++;
        if (attempts == 1) {
          started.complete();
          await cancel.future;
          throw CanceledError();
        }
        return 9;
      }),
    );
    await started.future;
    await service.onBackground();
    final id = host.active.single;
    host.active.remove(id);
    await service.onExpired(id);
    await Future<void>.delayed(Duration.zero);
    expect(attempts, 1);
    await service.onForeground();
    expect(await work, 9);
    expect(attempts, 2);
    expect(host.active, isEmpty);
  });

  test('resume detects lost native protection even if expiration callback was missed', () async {
    var attempts = 0;
    final work = service.run(
      title: 'Sync',
      description: '',
      action: (task) => task.run((cancel) async {
        attempts++;
        if (attempts == 1) {
          await cancel.future;
        }
        return attempts;
      }),
    );
    await Future<void>.delayed(Duration.zero);
    await service.onBackground();
    host.active.clear();
    await service.onForeground();
    expect(await work, 2);
  });

  test('user cancellation while suspended releases task without waiting for resume', () async {
    final userCancel = Completer<void>();
    var attempts = 0;
    final work = service.run(
      title: 'Upload',
      description: '',
      cancelToken: userCancel,
      action: (task) => task.run((cancel) async {
        attempts++;
        await cancel.future;
      }),
    );
    final result = expectLater(work, throwsA(isA<CanceledError>()));
    await Future<void>.delayed(Duration.zero);
    await service.onBackground();
    final id = host.active.single;
    host.active.clear();
    await service.onExpired(id);
    userCancel.complete();
    await result;
    expect(attempts, 1);
    expect(host.active, isEmpty);
  });

  test('denied protection permits foreground work but pauses it in background', () async {
    host.grant = false;
    var attempts = 0;
    final work = service.run(
      title: 'Upload',
      description: '',
      action: (task) => task.run((cancel) async {
        attempts++;
        if (attempts == 1) {
          await cancel.future;
        }
        return attempts;
      }),
    );
    await Future<void>.delayed(Duration.zero);
    await service.onBackground();
    await Future<void>.delayed(Duration.zero);
    expect(attempts, 1);
    await service.onForeground();
    expect(await work, 2);
  });

  test('operation failure releases the native task', () async {
    await expectLater(
      service.run<void>(
        title: 'Sync',
        description: '',
        action: (_) async {
          throw StateError('network failed');
        },
      ),
      throwsStateError,
    );
    expect(host.active, isEmpty);
    expect(host.finished, hasLength(1));
  });

  test('cancelable work cancels its worker before releasing protection', () async {
    var cancelled = false;
    final started = Completer<void>();
    final result = Completer<int?>();
    final work = service.execute<int>(
      title: 'Sync',
      description: '',
      factory: (_) {
        started.complete();
        return Cancelable<int?>(
          completer: result,
          onCancel: () {
            cancelled = true;
            result.completeError(CanceledError());
          },
        );
      },
    );
    final assertion = expectLater(work.future, throwsA(isA<CanceledError>()));
    await started.future;
    work.cancel();
    await assertion;
    expect(cancelled, isTrue);
    expect(host.active, isEmpty);
  });

  test('backgrounding during native startup still runs once protection is granted', () async {
    host.startResult = Completer<bool>();
    final work = service.run(title: 'Sync', description: '', action: (_) async => 1);
    await Future<void>.delayed(Duration.zero);
    await service.onBackground();
    host.startResult!.complete(true);
    expect(await work.timeout(const Duration(seconds: 1)), 1);
  });

  test('expiration while foregrounded retries without waiting for another resume', () async {
    var attempts = 0;
    final work = service.run(
      title: 'Sync',
      description: '',
      action: (task) => task.run((cancel) async {
        attempts++;
        if (attempts == 1) {
          await cancel.future;
        }
        return attempts;
      }),
    );
    await Future<void>.delayed(Duration.zero);
    final id = host.active.single;
    host.active.clear();
    await service.onExpired(id);
    expect(await work.timeout(const Duration(seconds: 1)), 2);
  });

  test('late expiration does not interrupt a renewed native lease', () async {
    final done = Completer<void>();
    var attempts = 0;
    final work = service.run(
      title: 'Sync',
      description: '',
      action: (task) => task.run((cancel) async {
        attempts++;
        await done.future;
        expect(cancel.isCompleted, isFalse);
      }),
    );
    await Future<void>.delayed(Duration.zero);
    await service.onExpired(host.active.single);
    done.complete();
    await work;
    expect(attempts, 1);
  });

  test('pause during native resume check cannot release suspended work', () async {
    var attempts = 0;
    final work = service.run(
      title: 'Sync',
      description: '',
      action: (task) => task.run((cancel) async {
        attempts++;
        if (attempts == 1) {
          await cancel.future;
        }
        return attempts;
      }),
    );
    await Future<void>.delayed(Duration.zero);
    await service.onBackground();
    final id = host.active.single;
    host.active.clear();
    await service.onExpired(id);
    host.activityResult = Completer<bool>();
    final resume = service.onForeground();
    await Future<void>.delayed(Duration.zero);
    await service.onBackground();
    host.activityResult!.complete(false);
    await resume;
    expect(attempts, 1);
    host.activityResult = null;
    await service.onForeground();
    expect(await work, 2);
  });
}
