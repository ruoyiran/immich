import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/constants/constants.dart';
import 'package:immich_mobile/providers/auth.provider.dart';
import 'package:immich_mobile/providers/background_sync.provider.dart';
import 'package:immich_mobile/repositories/original_media_cache.repository.dart';
import 'package:immich_mobile/services/foreground_upload.service.dart';
import 'package:mocktail/mocktail.dart';

import '../service.mocks.dart';

class _MockOriginalMediaCacheRepository extends Mock implements OriginalMediaCacheRepository {}

class _SignedInAuthNotifier extends AuthNotifier {
  _SignedInAuthNotifier(
    Ref ref,
    MockAuthService authService,
    MockSecureStorageService secureStorageService,
    MockWidgetService widgetService,
  ) : super(authService, MockApiService(), MockUserService(), secureStorageService, widgetService, ref) {
    state = state.copyWith(isAuthenticated: true, userId: 'user-1');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockAuthService authService;
  late MockSecureStorageService secureStorageService;
  late MockWidgetService widgetService;
  late MockBackgroundSyncManager syncManager;
  late MockForegroundUploadService uploadService;
  late _MockOriginalMediaCacheRepository cacheRepository;
  late ProviderContainer container;
  late AuthNotifier notifier;
  late List<String> events;

  setUp(() {
    authService = MockAuthService();
    secureStorageService = MockSecureStorageService();
    widgetService = MockWidgetService();
    syncManager = MockBackgroundSyncManager();
    uploadService = MockForegroundUploadService();
    cacheRepository = _MockOriginalMediaCacheRepository();
    events = [];

    when(() => syncManager.cancel()).thenAnswer((_) async => events.add('cancel sync'));
    when(() => uploadService.cancelAndDrain()).thenAnswer((_) async => events.add('cancel uploads'));
    when(() => secureStorageService.delete(kSecuredPinCode)).thenAnswer((_) async => events.add('clear PIN'));
    when(() => widgetService.clearCredentials()).thenAnswer((_) async => events.add('clear widget credentials'));
    when(() => cacheRepository.clear()).thenAnswer((_) async {
      events.add('clear media cache');
      return 0;
    });
    when(() => authService.logout()).thenAnswer((_) async => events.add('server logout and local cleanup'));

    container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(
          (ref) => _SignedInAuthNotifier(ref, authService, secureStorageService, widgetService),
        ),
        backgroundSyncProvider.overrideWithValue(syncManager),
        foregroundUploadServiceProvider.overrideWithValue(uploadService),
        originalMediaCacheRepositoryProvider.overrideWithValue(cacheRepository),
      ],
    );
    notifier = container.read(authProvider.notifier);
  });

  tearDown(() => container.dispose());

  test('logout cancels both transfers and drains them before clearing credentials or contacting the server', () async {
    final syncDrained = Completer<void>();
    final uploadsDrained = Completer<void>();
    when(() => syncManager.cancel()).thenAnswer((_) {
      events.add('cancel sync');
      return syncDrained.future;
    });
    when(() => uploadService.cancelAndDrain()).thenAnswer((_) {
      events.add('cancel uploads');
      return uploadsDrained.future;
    });

    final logout = notifier.logout();
    await Future<void>.delayed(Duration.zero);

    expect(events, ['cancel sync', 'cancel uploads']);
    expect(container.read(authProvider).isAuthenticated, isTrue);

    syncDrained.complete();
    await Future<void>.delayed(Duration.zero);

    expect(events, ['cancel sync', 'cancel uploads']);
    expect(container.read(authProvider).isAuthenticated, isTrue);

    uploadsDrained.complete();
    await logout;

    expect(events, [
      'cancel sync',
      'cancel uploads',
      'clear PIN',
      'clear widget credentials',
      'clear media cache',
      'server logout and local cleanup',
    ]);
    expect(container.read(authProvider).isAuthenticated, isFalse);
    expect(container.read(authProvider).userId, isEmpty);
  });

  test('a failed sync drain still waits for uploads and completes logout', () async {
    final syncDrained = Completer<void>();
    final uploadsDrained = Completer<void>();
    when(() => syncManager.cancel()).thenAnswer((_) {
      events.add('cancel sync');
      return syncDrained.future;
    });
    when(() => uploadService.cancelAndDrain()).thenAnswer((_) {
      events.add('cancel uploads');
      return uploadsDrained.future;
    });

    final logout = notifier.logout();
    await Future<void>.delayed(Duration.zero);
    expect(events, ['cancel sync', 'cancel uploads']);

    syncDrained.completeError(StateError('Sync task failed while unwinding'));
    await Future<void>.delayed(Duration.zero);

    expect(events, ['cancel sync', 'cancel uploads']);
    expect(container.read(authProvider).isAuthenticated, isTrue);

    uploadsDrained.complete();
    await logout;

    expect(events.last, 'server logout and local cleanup');
    expect(container.read(authProvider).isAuthenticated, isFalse);
  });

  test('media cache cleanup failure still logs out after transfers drain', () async {
    when(() => cacheRepository.clear()).thenAnswer((_) async {
      events.add('clear media cache');
      throw StateError('Cache is unavailable');
    });

    await notifier.logout();

    expect(events.take(2), ['cancel sync', 'cancel uploads']);
    expect(events.last, 'server logout and local cleanup');
    expect(container.read(authProvider).isAuthenticated, isFalse);
  });

  test('credential cleanup failure resets authentication after transfers drain', () async {
    final failure = StateError('Secure storage is unavailable');
    when(() => secureStorageService.delete(kSecuredPinCode)).thenAnswer((_) async {
      events.add('clear PIN');
      throw failure;
    });

    await expectLater(notifier.logout(), throwsA(same(failure)));

    expect(events, ['cancel sync', 'cancel uploads', 'clear PIN']);
    expect(container.read(authProvider).isAuthenticated, isFalse);
    expect(container.read(authProvider).userId, isEmpty);
  });
}
