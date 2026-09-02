import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:immich_mobile/constants/enums.dart';
import 'package:immich_mobile/domain/models/asset/base_asset.model.dart';
import 'package:immich_mobile/domain/models/store.model.dart';
import 'package:immich_mobile/domain/models/user.model.dart';
import 'package:immich_mobile/entities/store.entity.dart';
import 'package:immich_mobile/main.dart' as app;
import 'package:immich_mobile/providers/api.provider.dart';
import 'package:immich_mobile/providers/background_sync.provider.dart';
import 'package:immich_mobile/providers/gallery_permission.provider.dart';
import 'package:immich_mobile/providers/infrastructure/album.provider.dart';
import 'package:immich_mobile/providers/infrastructure/db.provider.dart';
import 'package:immich_mobile/repositories/asset_api.repository.dart';
import 'package:immich_mobile/repositories/auth_api.repository.dart';
import 'package:immich_mobile/services/api.service.dart';
import 'package:immich_mobile/services/foreground_upload.service.dart';
import 'package:immich_mobile/utils/bootstrap.dart';
import 'package:openapi/api.dart' as api;
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';

import 'test_utils/general_helper.dart';

const _caseSuffix = String.fromEnvironment('IMMICH_E2E_CASE_SUFFIX', defaultValue: 'A');
const _selectedCaseId = String.fromEnvironment('IMMICH_E2E_CASE_ID');
const _serverUrl = String.fromEnvironment('IMMICH_E2E_SERVER_URL');
const _badServerUrl = String.fromEnvironment('IMMICH_E2E_BAD_SERVER_URL', defaultValue: 'http://10.0.2.2:9');
const _email = String.fromEnvironment('IMMICH_E2E_EMAIL');
const _password = String.fromEnvironment('IMMICH_E2E_PASSWORD');
const _deviceId = String.fromEnvironment('IMMICH_E2E_DEVICE_ID', defaultValue: 'immich-mobile-e2e-device');
const _uploadAssetName = String.fromEnvironment(
  'IMMICH_E2E_UPLOAD_ASSET_NAME',
  defaultValue: 'immich-e2e-upload-008.jpg',
);
const _batchAssetPrefix = String.fromEnvironment(
  'IMMICH_E2E_BATCH_ASSET_PREFIX',
  defaultValue: 'immich-e2e-batch-009-',
);
const _batchAssetCount = int.fromEnvironment('IMMICH_E2E_BATCH_ASSET_COUNT', defaultValue: 20);
const _videoAssetName = String.fromEnvironment('IMMICH_E2E_VIDEO_ASSET_NAME', defaultValue: 'immich-e2e-video-010.mp4');
const _duplicateAssetPrefix = String.fromEnvironment(
  'IMMICH_E2E_DUPLICATE_ASSET_PREFIX',
  defaultValue: 'immich-e2e-duplicate-011-',
);
const _duplicateAssetCount = int.fromEnvironment('IMMICH_E2E_DUPLICATE_ASSET_COUNT', defaultValue: 2);
const _resumableAssetName = String.fromEnvironment(
  'IMMICH_E2E_RESUMABLE_ASSET_NAME',
  defaultValue: 'immich-e2e-resumable-012.mp4',
);
const _resumableCancelAfterBytes = int.fromEnvironment(
  'IMMICH_E2E_RESUMABLE_CANCEL_AFTER_BYTES',
  defaultValue: 512 * 1024,
);
const _lifecycleAssetName = String.fromEnvironment(
  'IMMICH_E2E_LIFECYCLE_ASSET_NAME',
  defaultValue: 'immich-e2e-lifecycle-013.mp4',
);

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

    _realStackSessionTest('MOB-REAL-006-$_caseSuffix', 'honors limited gallery permission expansion', (tester) async {
      await _loadAuthenticatedApp(tester);
      await PhotoManager.setIgnorePermissionCheck(false);
      addTearDown(() async => PhotoManager.setIgnorePermissionCheck(true));

      final container = _containerOfApp(tester);
      final initialStatus = await container.read(galleryPermissionNotifier.notifier).requestGalleryPermission();
      expect(initialStatus, DevicePermissionStatus.limited);

      await container.read(backgroundSyncProvider).syncLocal(full: true);
      final initialAssetNames = await _localAssetNames(container);
      expect(initialAssetNames, isNot(contains('immich-e2e-limited-extra.mp4')));

      final expandedStatus = await container.read(galleryPermissionNotifier.notifier).requestGalleryPermission();
      expect(expandedStatus.hasAccess, isTrue);

      await container.read(backgroundSyncProvider).syncLocal(full: true);
      final expandedAssetNames = await _localAssetNames(container);
      expect(expandedAssetNames.length, greaterThan(initialAssetNames.length));
      expect(expandedAssetNames, contains('immich-e2e-limited-extra.mp4'));
    });

    _realStackSessionTest('MOB-REAL-007-$_caseSuffix', 'syncs local media from the simulator gallery', (tester) async {
      await _loadAppPreservingStore(tester);
      await _waitForAccessToken(tester);
      await _waitForCurrentUser(_email, tester);

      final container = _containerOfApp(tester);
      await container.read(backgroundSyncProvider).syncLocal(full: true);

      final assetNames = await _localAssetNames(container);

      expect(assetNames, containsAll(['immich-e2e-red.jpg', 'immich-e2e-green.jpg', 'immich-e2e-video.mp4']));
      expect(assetNames.length, assetNames.toSet().length);
    });

    _realStackSessionTest('MOB-REAL-008-$_caseSuffix', 'uploads one JPEG to the real server', (tester) async {
      await _loadAuthenticatedApp(tester);

      final container = _containerOfApp(tester);
      final asset = await _waitForLocalAssetByName(container, _uploadAssetName, tester);
      expect(asset.isImage, isTrue);

      String? remoteAssetId;
      String? uploadError;
      await container
          .read(foregroundUploadServiceProvider)
          .uploadSingleAsset(
            asset,
            Completer<void>(),
            callbacks: UploadCallbacks(
              onSuccess: (_, remoteId) => remoteAssetId = remoteId,
              onError: (_, errorMessage) => uploadError = errorMessage,
            ),
          );

      expect(uploadError, isNull);
      expect(remoteAssetId, isNotNull);
      final downloaded = await container.read(assetApiRepositoryProvider).downloadAsset(remoteAssetId!, edited: false);
      expect(downloaded.statusCode, 200);
      expect(downloaded.bodyBytes, isNotEmpty);
    });

    _realStackSessionTest('MOB-REAL-009-$_caseSuffix', 'uploads a batch of mixed photos with monotonic progress', (
      tester,
    ) async {
      await _loadAuthenticatedApp(tester);

      final container = _containerOfApp(tester);
      final assets = await _waitForLocalAssetsByPrefix(container, _batchAssetPrefix, _batchAssetCount, tester);
      expect(assets.every((asset) => asset.isImage), isTrue);

      final uploaded = <String, String>{};
      final failed = <String, String>{};
      final progressById = <String, List<double>>{};

      await container
          .read(foregroundUploadServiceProvider)
          .uploadManual(
            assets,
            cancelToken: Completer<void>(),
            callbacks: UploadCallbacks(
              onProgress: (id, _, bytes, totalBytes) {
                final progress = totalBytes > 0 ? bytes / totalBytes : 0.0;
                final assetProgress = progressById.putIfAbsent(id, () => []);
                expect(progress, inInclusiveRange(0.0, 1.0));
                if (assetProgress.isNotEmpty) {
                  expect(progress, greaterThanOrEqualTo(assetProgress.last));
                }
                assetProgress.add(progress);
              },
              onSuccess: (id, remoteId) {
                uploaded[id] = remoteId;
                failed.remove(id);
              },
              onError: (id, errorMessage) => failed[id] = errorMessage,
            ),
          );

      expect(failed, isEmpty);
      expect(uploaded.length, _batchAssetCount);
      expect(uploaded.values.toSet().length, _batchAssetCount);
      expect(progressById.keys, containsAll(uploaded.keys));

      for (final remoteId in uploaded.values.take(3)) {
        final downloaded = await container.read(assetApiRepositoryProvider).downloadAsset(remoteId, edited: false);
        expect(downloaded.statusCode, 200);
        expect(downloaded.bodyBytes, isNotEmpty);
      }
    });

    _realStackSessionTest('MOB-REAL-010-$_caseSuffix', 'uploads an MP4 and verifies thumbnail and playback', (
      tester,
    ) async {
      await _loadAuthenticatedApp(tester);

      final container = _containerOfApp(tester);
      final asset = await _waitForLocalAssetByName(container, _videoAssetName, tester);
      expect(asset.isVideo, isTrue);

      String? remoteAssetId;
      String? uploadError;
      await container
          .read(foregroundUploadServiceProvider)
          .uploadSingleAsset(
            asset,
            Completer<void>(),
            callbacks: UploadCallbacks(
              onSuccess: (_, remoteId) => remoteAssetId = remoteId,
              onError: (_, errorMessage) => uploadError = errorMessage,
            ),
          );

      expect(uploadError, isNull);
      expect(remoteAssetId, isNotNull);

      final assetsApi = container.read(apiServiceProvider).assetsApi;
      final info = await assetsApi.getAssetInfo(remoteAssetId!);
      expect(info, isNotNull);
      expect(info!.type, api.AssetTypeEnum.VIDEO);

      final original = await container.read(assetApiRepositoryProvider).downloadAsset(remoteAssetId!, edited: false);
      expect(original.statusCode, 200);
      expect(original.bodyBytes, isNotEmpty);

      final thumbnail = await _waitForSuccessfulResponse(
        tester,
        () => assetsApi.viewAssetWithHttpInfo(remoteAssetId!, size: api.AssetMediaSize.thumbnail),
      );
      expect(thumbnail.bodyBytes, isNotEmpty);

      final playback = await _waitForSuccessfulResponse(
        tester,
        () => assetsApi.playAssetVideoWithHttpInfo(remoteAssetId!),
        acceptedStatusCodes: const {200, 206},
      );
      expect(playback.bodyBytes, isNotEmpty);
    });

    _realStackSessionTest('MOB-REAL-011-$_caseSuffix', 'deduplicates repeated backups by MD5 and size', (tester) async {
      await _loadAuthenticatedApp(tester);

      final container = _containerOfApp(tester);
      final assets = await _waitForLocalAssetsByPrefix(container, _duplicateAssetPrefix, _duplicateAssetCount, tester);
      expect(assets.every((asset) => asset.isImage), isTrue);
      expect(assets.map((asset) => asset.name).toSet().length, _duplicateAssetCount);

      final firstRemoteId = await _uploadSingleAssetToServer(container, assets[0]);
      final secondRemoteId = await _uploadSingleAssetToServer(container, assets[1]);

      expect(secondRemoteId, firstRemoteId);

      final downloaded = await container.read(assetApiRepositoryProvider).downloadAsset(firstRemoteId, edited: false);
      expect(downloaded.statusCode, 200);
      expect(downloaded.bodyBytes, isNotEmpty);
    });

    _realStackSessionTest('MOB-REAL-012-$_caseSuffix', 'resumes interrupted upload from server offset', (tester) async {
      await _loadAuthenticatedApp(tester);

      final container = _containerOfApp(tester);
      final asset = await _waitForLocalAssetByName(container, _resumableAssetName, tester);
      final contentSize = asset.contentSize;
      if (contentSize == null) {
        fail('Resumable upload asset $_resumableAssetName has no known content size');
      }
      expect(contentSize, greaterThan(_resumableCancelAfterBytes));
      await _clearResumableStateFiles();

      final cancel = Completer<void>();
      final firstProgress = <int>[];
      String? interruptedRemoteId;
      String? interruptedError;
      await container
          .read(foregroundUploadServiceProvider)
          .uploadSingleAsset(
            asset,
            cancel,
            callbacks: UploadCallbacks(
              onProgress: (_, _, bytes, totalBytes) {
                firstProgress.add(bytes);
                if (!cancel.isCompleted && bytes >= _resumableCancelAfterBytes) {
                  cancel.complete();
                }
              },
              onSuccess: (_, remoteId) => interruptedRemoteId = remoteId,
              onError: (_, errorMessage) => interruptedError = errorMessage,
            ),
          );

      expect(interruptedRemoteId, isNull);
      expect(interruptedError, isNull);
      expect(firstProgress.every((bytes) => bytes >= 0 && bytes <= contentSize), isTrue);
      expect(firstProgress.any((bytes) => bytes >= _resumableCancelAfterBytes), isTrue);

      final stateAfterCancel = await _readSingleResumableState();
      final cancelledOffset = stateAfterCancel['offset'] as int;
      final cancelledSize = stateAfterCancel['size'] as int;
      expect(cancelledOffset, greaterThan(0));
      expect(cancelledOffset, lessThan(cancelledSize));

      final retryProgress = <int>[];
      String? remoteAssetId;
      String? retryError;
      await container
          .read(foregroundUploadServiceProvider)
          .uploadSingleAsset(
            asset,
            null,
            callbacks: UploadCallbacks(
              onProgress: (_, _, bytes, totalBytes) {
                retryProgress.add(bytes);
              },
              onSuccess: (_, remoteId) => remoteAssetId = remoteId,
              onError: (_, errorMessage) => retryError = errorMessage,
            ),
          );

      expect(retryError, isNull);
      expect(remoteAssetId, isNotNull);
      expect(retryProgress.every((bytes) => bytes >= 0 && bytes <= cancelledSize), isTrue);
      expect(retryProgress.firstWhere((bytes) => bytes > 0), greaterThanOrEqualTo(cancelledOffset));
      expect(retryProgress.last, cancelledSize);
      expect(await _resumableStateFiles(), isEmpty);
    });

    _realStackSessionTest('MOB-REAL-013-$_caseSuffix', 'keeps upload stable across lifecycle changes', (tester) async {
      await _loadAuthenticatedApp(tester);

      final container = _containerOfApp(tester);
      final asset = await _waitForLocalAssetByName(container, _lifecycleAssetName, tester);
      final contentSize = asset.contentSize;
      if (contentSize == null) {
        fail('Lifecycle upload asset $_lifecycleAssetName has no known content size');
      }
      await _clearResumableStateFiles();

      final progress = <int>[];
      String? remoteAssetId;
      String? uploadError;
      final upload = container
          .read(foregroundUploadServiceProvider)
          .uploadSingleAsset(
            asset,
            null,
            callbacks: UploadCallbacks(
              onProgress: (_, _, bytes, totalBytes) {
                progress.add(bytes);
              },
              onSuccess: (_, remoteId) => remoteAssetId = remoteId,
              onError: (_, errorMessage) => uploadError = errorMessage,
            ),
          );

      await _pumpUntil(
        tester,
        () => progress.any((bytes) => bytes > 0) || remoteAssetId != null || uploadError != null,
        timeout: const Duration(seconds: 90),
      );
      expect(uploadError, isNull);
      expect(remoteAssetId, isNull);

      for (var i = 0; i < 2; i++) {
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        await Future<void>.delayed(const Duration(seconds: 2));
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await tester.pump();
        await Future<void>.delayed(const Duration(seconds: 2));
      }

      await upload.timeout(const Duration(minutes: 5));
      expect(uploadError, isNull);
      expect(remoteAssetId, isNotNull);
      expect(progress, isNotEmpty);
      expect(progress.every((bytes) => bytes >= 0 && bytes <= contentSize), isTrue);
      for (var i = 1; i < progress.length; i++) {
        expect(progress[i], greaterThanOrEqualTo(progress[i - 1]));
      }
      expect(await _resumableStateFiles(), isEmpty);

      final info = await container.read(apiServiceProvider).assetsApi.getAssetInfo(remoteAssetId!);
      expect(info, isNotNull);
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

Future<void> _loadAuthenticatedApp(WidgetTester tester) async {
  await EasyLocalization.ensureInitialized();
  final (drift, _) = await Bootstrap.initDomain();
  await Store.clear();

  await _seedAuthenticatedStore();

  await tester.pumpWidget(
    ProviderScope(overrides: [driftProvider.overrideWith(driftOverride(drift))], child: const app.MainWidget()),
  );
  await EasyLocalization.ensureInitialized();
  await _pumpFor(tester, const Duration(milliseconds: 500));
  await _waitForAccessToken(tester);
  await _waitForCurrentUser(_email, tester);
}

Future<void> _seedAuthenticatedStore() async {
  final endpoint = _apiEndpoint(_serverUrl);
  await Store.put(StoreKey.serverEndpoint, endpoint);
  await Store.put(StoreKey.serverUrl, endpoint);
  await _ensureDeviceId();

  final apiService = ApiService()..setEndpoint(endpoint);
  final response = await AuthApiRepository(apiService).login(_email, _password);
  expect(response.userEmail, _email);
  await Store.put(StoreKey.accessToken, response.accessToken);
  await Store.put(
    StoreKey.currentUser,
    UserDto(
      id: response.userId,
      email: response.userEmail,
      name: response.name,
      isAdmin: response.isAdmin,
      hasProfileImage: response.profileImagePath.isNotEmpty,
      profileChangedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    ),
  );
  await apiService.updateHeaders();
}

Future<void> _ensureDeviceId() async {
  if ((Store.tryGet(StoreKey.deviceId) ?? '').isEmpty) {
    await Store.put(StoreKey.deviceId, _deviceId);
  }
}

String _apiEndpoint(String serverUrl) {
  final trimmed = serverUrl.replaceFirst(RegExp(r'/+$'), '');
  return trimmed.endsWith('/api') ? trimmed : '$trimmed/api';
}

ProviderContainer _containerOfApp(WidgetTester tester) {
  return ProviderScope.containerOf(tester.element(find.byType(app.MainWidget)), listen: false);
}

Future<Set<String>> _localAssetNames(ProviderContainer container) async {
  final assets = await _localAssets(container);
  expect(assets, isNotEmpty);
  return assets.map((asset) => asset.name).toSet();
}

Future<List<LocalAsset>> _localAssets(ProviderContainer container) async {
  final albums = await container.read(localAlbumServiceProvider).getAll();

  final assets = <LocalAsset>[];
  for (final album in albums) {
    assets.addAll(await container.read(localAlbumRepository).getAssets(album.id));
  }
  return assets;
}

Future<LocalAsset> _waitForLocalAssetByName(ProviderContainer container, String name, WidgetTester tester) async {
  var lastSeen = const <String>{};
  for (var attempt = 0; attempt < 12; attempt++) {
    await container.read(backgroundSyncProvider).syncLocal(full: true);
    final assets = await _localAssets(container);
    for (final asset in assets) {
      if (asset.name == name) {
        return asset;
      }
    }
    lastSeen = assets.map((asset) => asset.name).toSet();
    await _pumpFor(tester, const Duration(seconds: 2));
  }

  final sorted = lastSeen.toList()..sort();
  fail('Local asset $name was not discovered; saw ${sorted.join(', ')}');
}

Future<List<LocalAsset>> _waitForLocalAssetsByPrefix(
  ProviderContainer container,
  String prefix,
  int count,
  WidgetTester tester,
) async {
  var lastSeen = const <String>{};
  for (var attempt = 0; attempt < 12; attempt++) {
    await container.read(backgroundSyncProvider).syncLocal(full: true);
    final assets = await _localAssets(container);
    final matches = assets.where((asset) => asset.name.startsWith(prefix)).toList();
    if (matches.length >= count) {
      matches.sort((a, b) => a.name.compareTo(b.name));
      return matches.take(count).toList();
    }
    lastSeen = assets.map((asset) => asset.name).toSet();
    await _pumpFor(tester, const Duration(seconds: 2));
  }

  final sorted = lastSeen.toList()..sort();
  fail('Local assets matching $prefix did not reach $count; saw ${sorted.join(', ')}');
}

Future<http.Response> _waitForSuccessfulResponse(
  WidgetTester tester,
  Future<http.Response> Function() request, {
  Set<int> acceptedStatusCodes = const {200},
}) async {
  http.Response? lastResponse;
  Object? lastError;
  for (var attempt = 0; attempt < 20; attempt++) {
    try {
      final response = await request();
      if (acceptedStatusCodes.contains(response.statusCode) && response.bodyBytes.isNotEmpty) {
        return response;
      }
      lastResponse = response;
    } catch (error) {
      lastError = error;
    }
    await _pumpFor(tester, const Duration(seconds: 2));
  }

  if (lastResponse != null) {
    fail('Expected HTTP ${acceptedStatusCodes.join('/')} with body, got ${lastResponse.statusCode}');
  }
  fail('Expected HTTP ${acceptedStatusCodes.join('/')} with body, last error: $lastError');
}

Future<String> _uploadSingleAssetToServer(ProviderContainer container, LocalAsset asset) async {
  String? remoteAssetId;
  String? uploadError;
  await container
      .read(foregroundUploadServiceProvider)
      .uploadSingleAsset(
        asset,
        Completer<void>(),
        callbacks: UploadCallbacks(
          onSuccess: (_, remoteId) => remoteAssetId = remoteId,
          onError: (_, errorMessage) => uploadError = errorMessage,
        ),
      );

  expect(uploadError, isNull);
  expect(remoteAssetId, isNotNull);
  return remoteAssetId!;
}

Future<List<File>> _resumableStateFiles() async {
  final support = await getApplicationSupportDirectory();
  final directory = Directory('${support.path}/resumable-uploads');
  if (!directory.existsSync()) {
    return [];
  }

  final files = directory
      .listSync(followLinks: false)
      .where((entity) => entity is File && entity.path.endsWith('.json'))
      .cast<File>()
      .toList();
  files.sort((a, b) => a.path.compareTo(b.path));
  return files;
}

Future<void> _clearResumableStateFiles() async {
  for (final file in await _resumableStateFiles()) {
    file.deleteSync();
  }
}

Future<Map<String, dynamic>> _readSingleResumableState() async {
  final files = await _resumableStateFiles();
  expect(files, hasLength(1));
  return jsonDecode(files.single.readAsStringSync()) as Map<String, dynamic>;
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
