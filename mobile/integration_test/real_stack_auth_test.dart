import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/constants/enums.dart';
import 'package:immich_mobile/domain/models/store.model.dart';
import 'package:immich_mobile/entities/store.entity.dart';
import 'package:immich_mobile/main.dart' as app;
import 'package:immich_mobile/providers/background_sync.provider.dart';
import 'package:immich_mobile/providers/gallery_permission.provider.dart';
import 'package:immich_mobile/providers/infrastructure/album.provider.dart';
import 'package:immich_mobile/providers/infrastructure/db.provider.dart';
import 'package:immich_mobile/utils/bootstrap.dart';

import 'test_utils/general_helper.dart';

const _caseSuffix = String.fromEnvironment('IMMICH_E2E_CASE_SUFFIX', defaultValue: 'A');
const _selectedCaseId = String.fromEnvironment('IMMICH_E2E_CASE_ID');
const _serverUrl = String.fromEnvironment('IMMICH_E2E_SERVER_URL');
const _badServerUrl = String.fromEnvironment('IMMICH_E2E_BAD_SERVER_URL', defaultValue: 'http://10.0.2.2:9');
const _email = String.fromEnvironment('IMMICH_E2E_EMAIL');
const _password = String.fromEnvironment('IMMICH_E2E_PASSWORD');

var _registeredSelectedCase = false;

void main() async {
  await ImmichTestHelper.initialize();

  group('real stack auth', () {
    _realStackAuthTest('MOB-REAL-001-$_caseSuffix', 'discovers real server capabilities', (tester, _) async {
      await _waitForLoginScreen(tester);
      await _enterServerUrl(tester, _serverUrl);
      await _tapTranslatedButton(tester, 'next');

      await _waitForCredentialFields(tester);
      expect(Store.tryGet(StoreKey.serverEndpoint), endsWith('/api'));
      expect(Store.tryGet(StoreKey.serverEndpoint), contains(Uri.parse(_serverUrl).host));
      expect(Store.tryGet(StoreKey.accessToken), isNull);
    });

    _realStackAuthTest('MOB-REAL-002-$_caseSuffix', 'logs in with real owner credentials', (tester, _) async {
      await _login(tester, serverUrl: _serverUrl, email: _email, password: _password);
      await _waitForAccessToken(tester);
      await _waitForCurrentUser(_email, tester);

      final user = Store.tryGet(StoreKey.currentUser);
      expect(user!.email, _email);
      expect(Store.tryGet(StoreKey.serverEndpoint), endsWith('/api'));
    });

    _realStackAuthTest('MOB-REAL-003-$_caseSuffix', 'recovers after bad server and bad password', (tester, _) async {
      await _waitForLoginScreen(tester);
      await _enterServerUrl(tester, _badServerUrl);
      await _tapTranslatedButton(tester, 'next');
      await tester.pump(const Duration(seconds: 2));
      expect(Store.tryGet(StoreKey.accessToken), isNull);

      await _enterServerUrl(tester, _serverUrl);
      await _tapTranslatedButton(tester, 'next');
      await _waitForCredentialFields(tester);

      await _enterCredentials(tester, email: _email, password: '${_password}x');
      await _tapTranslatedButton(tester, 'login');
      await pumpUntilFound(tester, find.text('login_form_failed_login'.tr()), timeout: const Duration(seconds: 30));
      expect(Store.tryGet(StoreKey.accessToken), isNull);

      await _enterCredentials(tester, email: _email, password: _password);
      await _tapTranslatedButton(tester, 'login');
      await _waitForAccessToken(tester);
      await _waitForCurrentUser(_email, tester);
    });

    _realStackSessionTest('MOB-REAL-004-$_caseSuffix', 'resumes persisted session after app restart', (tester) async {
      await _loadAppPreservingStore(tester);
      await _waitForAccessToken(tester);
      await _waitForCurrentUser(_email, tester);
      expect(Store.tryGet(StoreKey.serverEndpoint), endsWith('/api'));
      expect(Store.tryGet(StoreKey.serverEndpoint), contains(Uri.parse(_serverUrl).host));
    });

    _realStackSessionTest('MOB-REAL-005-$_caseSuffix', 'sees granted full gallery permission', (tester) async {
      await _loadAppPreservingStore(tester);
      await _waitForAccessToken(tester);
      await _waitForCurrentUser(_email, tester);

      final container = _containerOfApp(tester);
      final status = await container.read(galleryPermissionNotifier.notifier).getGalleryPermissionStatus();
      expect(status, DevicePermissionStatus.granted);
    });

    _realStackSessionTest('MOB-REAL-007-$_caseSuffix', 'syncs local media from the simulator gallery', (tester) async {
      await _loadAppPreservingStore(tester);
      await _waitForAccessToken(tester);
      await _waitForCurrentUser(_email, tester);

      final container = _containerOfApp(tester);
      await container.read(backgroundSyncProvider).syncLocal(full: true);

      final albums = await container.read(localAlbumServiceProvider).getAll();
      expect(albums.where((album) => album.assetCount > 0), isNotEmpty);

      final assetNames = <String>{};
      for (final album in albums) {
        final assets = await container.read(localAlbumRepository).getAssets(album.id);
        assetNames.addAll(assets.map((asset) => asset.name));
      }

      expect(assetNames, containsAll(['immich-e2e-red.jpg', 'immich-e2e-green.jpg', 'immich-e2e-video.mp4']));
      expect(assetNames.length, assetNames.toSet().length);
    });

    if (_selectedCaseId.isNotEmpty && !_registeredSelectedCase) {
      test(_selectedCaseId, () => fail('No real stack auth test registered for $_selectedCaseId'));
    }
  });
}

void _realStackSessionTest(String caseId, String description, Future<void> Function(WidgetTester) body) {
  if (_selectedCaseId.isNotEmpty && _selectedCaseId != caseId) {
    return;
  }

  _registeredSelectedCase = true;
  testWidgets('$caseId $description', (tester) async {
    _requireRealStackConfig();
    await body(tester);
    await _pumpFor(tester, const Duration(milliseconds: 500));
  }, semanticsEnabled: false);
}

void _realStackAuthTest(String caseId, String description, Future<void> Function(WidgetTester, ImmichTestHelper) body) {
  if (_selectedCaseId.isNotEmpty && _selectedCaseId != caseId) {
    return;
  }

  _registeredSelectedCase = true;
  immichWidgetTest('$caseId $description', (tester, helper) async {
    _requireRealStackConfig();
    await body(tester, helper);
    await _pumpFor(tester, const Duration(milliseconds: 500));
  });
}

void _requireRealStackConfig() {
  expect(_serverUrl, isNotEmpty, reason: 'Pass --dart-define=IMMICH_E2E_SERVER_URL=...');
  expect(_email, isNotEmpty, reason: 'Pass --dart-define=IMMICH_E2E_EMAIL=...');
  expect(_password, isNotEmpty, reason: 'Pass --dart-define=IMMICH_E2E_PASSWORD=...');
}

Future<void> _login(
  WidgetTester tester, {
  required String serverUrl,
  required String email,
  required String password,
}) async {
  await _waitForLoginScreen(tester);
  await _enterServerUrl(tester, serverUrl);
  await _tapTranslatedButton(tester, 'next');
  await _waitForCredentialFields(tester);
  await _enterCredentials(tester, email: email, password: password);
  await _tapTranslatedButton(tester, 'login');
}

Future<void> _loadAppPreservingStore(WidgetTester tester) async {
  await EasyLocalization.ensureInitialized();
  final (drift, _) = await Bootstrap.initDomain();
  await tester.pumpWidget(
    ProviderScope(overrides: [driftProvider.overrideWith(driftOverride(drift))], child: const app.MainWidget()),
  );
  await EasyLocalization.ensureInitialized();
}

ProviderContainer _containerOfApp(WidgetTester tester) {
  return ProviderScope.containerOf(tester.element(find.byType(app.MainWidget)), listen: false);
}

Future<void> _waitForLoginScreen(WidgetTester tester) async {
  await pumpUntilFound(tester, find.byType(TextFormField), timeout: const Duration(seconds: 60));
  await _pumpFor(tester, const Duration(seconds: 3));
}

Future<void> _waitForCredentialFields(WidgetTester tester) async {
  await _pumpUntil(
    tester,
    () => find.byType(TextFormField).evaluate().length >= 2,
    timeout: const Duration(seconds: 60),
  );
}

Future<void> _waitForAccessToken(WidgetTester tester) async {
  await _pumpUntil(
    tester,
    () => (Store.tryGet(StoreKey.accessToken) ?? '').isNotEmpty,
    timeout: const Duration(seconds: 60),
  );
}

Future<void> _waitForCurrentUser(String email, WidgetTester tester) async {
  await _pumpUntil(
    tester,
    () => Store.tryGet(StoreKey.currentUser)?.email == email,
    timeout: const Duration(seconds: 60),
  );
}

Future<void> _enterServerUrl(WidgetTester tester, String serverUrl) async {
  final fields = find.byType(TextFormField);
  await pumpUntilFound(tester, fields, timeout: const Duration(seconds: 60));
  await tester.enterText(fields.first, serverUrl);
  await tester.pump();
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pump();
}

Future<void> _enterCredentials(WidgetTester tester, {required String email, required String password}) async {
  final fields = find.byType(TextFormField);
  await _waitForCredentialFields(tester);
  await tester.enterText(fields.at(0), email);
  await tester.pump();
  await tester.enterText(fields.at(1), password);
  await tester.pump();
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pump();
}

Future<void> _tapTranslatedButton(WidgetTester tester, String key) async {
  final button = find.textContaining(key.tr());
  await pumpUntilFound(tester, button, timeout: const Duration(seconds: 60));
  await tester.tap(button.last);
  await tester.pump();
}

Future<void> _pumpFor(WidgetTester tester, Duration duration) async {
  final end = DateTime.now().add(duration);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _pumpUntil(WidgetTester tester, bool Function() condition, {required Duration timeout}) async {
  final end = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(end)) {
      throw TimeoutException('Timed out waiting for condition');
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
}
