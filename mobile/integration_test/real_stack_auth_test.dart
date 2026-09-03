import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:immich_mobile/constants/constants.dart';
import 'package:immich_mobile/constants/enums.dart';
import 'package:immich_mobile/domain/models/asset/base_asset.model.dart';
import 'package:immich_mobile/domain/models/events.model.dart';
import 'package:immich_mobile/domain/models/store.model.dart';
import 'package:immich_mobile/domain/models/sync_event.model.dart';
import 'package:immich_mobile/domain/models/timeline.model.dart';
import 'package:immich_mobile/domain/models/user.model.dart';
import 'package:immich_mobile/domain/services/timeline.service.dart';
import 'package:immich_mobile/domain/utils/event_stream.dart';
import 'package:immich_mobile/entities/store.entity.dart';
import 'package:immich_mobile/infrastructure/repositories/db.repository.dart';
import 'package:immich_mobile/infrastructure/repositories/storage.repository.dart';
import 'package:immich_mobile/main.dart' as app;
import 'package:immich_mobile/presentation/widgets/asset_viewer/asset_viewer.page.dart';
import 'package:immich_mobile/presentation/widgets/asset_viewer/video_viewer.widget.dart';
import 'package:immich_mobile/presentation/widgets/images/thumbnail_tile.widget.dart';
import 'package:immich_mobile/presentation/widgets/timeline/timeline.widget.dart';
import 'package:immich_mobile/providers/api.provider.dart';
import 'package:immich_mobile/providers/asset_viewer/asset_viewer.provider.dart';
import 'package:immich_mobile/providers/asset_viewer/video_player_provider.dart';
import 'package:immich_mobile/providers/background_sync.provider.dart';
import 'package:immich_mobile/providers/gallery_permission.provider.dart';
import 'package:immich_mobile/providers/infrastructure/album.provider.dart';
import 'package:immich_mobile/providers/infrastructure/asset.provider.dart';
import 'package:immich_mobile/providers/infrastructure/cancel.provider.dart';
import 'package:immich_mobile/providers/infrastructure/db.provider.dart';
import 'package:immich_mobile/providers/infrastructure/sync.provider.dart';
import 'package:immich_mobile/providers/infrastructure/timeline.provider.dart';
import 'package:immich_mobile/providers/websocket.provider.dart';
import 'package:immich_mobile/repositories/asset_api.repository.dart';
import 'package:immich_mobile/repositories/auth_api.repository.dart';
import 'package:immich_mobile/repositories/download.repository.dart';
import 'package:immich_mobile/services/api.service.dart';
import 'package:immich_mobile/services/foreground_upload.service.dart';
import 'package:immich_mobile/utils/bootstrap.dart';
import 'package:immich_mobile/utils/semver.dart';
import 'package:immich_mobile/widgets/asset_viewer/video_controls.dart';
import 'package:immich_mobile/widgets/photo_view/photo_view.dart';
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
const _motionPhotoAssetName = String.fromEnvironment(
  'IMMICH_E2E_MOTION_PHOTO_ASSET_NAME',
  defaultValue: 'immich-e2e-motion-014.heic',
);
const _metadataExifAssetName = String.fromEnvironment(
  'IMMICH_E2E_METADATA_EXIF_ASSET_NAME',
  defaultValue: 'immich-e2e-metadata-015-exif.jpg',
);
const _metadataNoExifAssetName = String.fromEnvironment(
  'IMMICH_E2E_METADATA_NO_EXIF_ASSET_NAME',
  defaultValue: 'immich-e2e-metadata-015-no-exif.jpg',
);
const _timelineMinimumAssetCount = int.fromEnvironment('IMMICH_E2E_TIMELINE_MIN_ASSET_COUNT', defaultValue: 24);
const _timelinePageSize = int.fromEnvironment('IMMICH_E2E_TIMELINE_PAGE_SIZE', defaultValue: 8);
const _assetViewerImageCount = int.fromEnvironment('IMMICH_E2E_VIEWER_IMAGE_COUNT', defaultValue: 3);

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

    _realStackSessionTest('MOB-REAL-014-$_caseSuffix', 'uploads and replays Android Motion HEIC originals', (
      tester,
    ) async {
      await _loadAuthenticatedApp(tester);

      final container = _containerOfApp(tester);
      final asset = await _waitForLocalAssetByName(container, _motionPhotoAssetName, tester);
      expect(asset.isImage, isTrue);
      expect(asset.isMotionPhoto, isTrue);

      final files = await StorageRepository().getLivePhotoFilesForAsset(asset);
      expect(files, isNotNull);
      expect(files!.still.existsSync(), isTrue);
      expect(files.motion.existsSync(), isTrue);
      expect(files.still.lengthSync(), greaterThan(32));
      expect(files.motion.lengthSync(), greaterThan(32));

      final remoteAssetId = await _uploadSingleAssetToServer(container, asset);
      final assetsApi = container.read(apiServiceProvider).assetsApi;
      final info = await assetsApi.getAssetInfo(remoteAssetId);
      expect(info, isNotNull);
      expect(info!.type, api.AssetTypeEnum.IMAGE);
      final livePhotoVideoId = info.livePhotoVideoId.orElse(null);
      expect(livePhotoVideoId, isNotNull);
      expect(livePhotoVideoId, isNot(remoteAssetId));

      final original = await _waitForSuccessfulResponse(
        tester,
        () => http.get(
          Uri.parse('${Store.get(StoreKey.serverEndpoint)}/assets/$remoteAssetId/original'),
          headers: {
            ...ApiService.getRequestHeaders(),
            'Authorization': 'Bearer ${Store.get(StoreKey.accessToken)}',
            DownloadRepository.livePhotoFormatHeader: DownloadRepository.androidMotionHeicFormat,
          },
        ),
      );
      _expectAndroidMotionHeic(original.bodyBytes);

      final motionPlayback = await _waitForSuccessfulResponse(
        tester,
        () => assetsApi.playAssetVideoWithHttpInfo(livePhotoVideoId!),
        acceptedStatusCodes: const {200, 206},
      );
      expect(motionPlayback.bodyBytes, isNotEmpty);

      final duplicateRemoteId = await _uploadSingleAssetToServer(container, asset);
      expect(duplicateRemoteId, remoteAssetId);
    });

    _realStackSessionTest('MOB-REAL-015-$_caseSuffix', 'preserves image metadata through upload', (tester) async {
      await _loadAuthenticatedApp(tester);

      final container = _containerOfApp(tester);
      final exifAsset = await _waitForLocalAssetByName(container, _metadataExifAssetName, tester);
      final noExifAsset = await _waitForLocalAssetByName(container, _metadataNoExifAssetName, tester);

      expect(exifAsset.isImage, isTrue);
      expect(exifAsset.orientation, 90);
      expect(exifAsset.width, 90);
      expect(exifAsset.height, 160);

      final exifRemoteId = await _uploadSingleAssetToServer(container, exifAsset);
      final noExifRemoteId = await _uploadSingleAssetToServer(container, noExifAsset);
      expect(noExifRemoteId, isNot(exifRemoteId));

      final assetsApi = container.read(apiServiceProvider).assetsApi;
      final exifInfo = await _waitForAssetInfo(tester, assetsApi, exifRemoteId);
      expect(exifInfo.type, api.AssetTypeEnum.IMAGE);
      expect(exifInfo.originalFileName.toLowerCase(), endsWith('.jpg'));
      expect(exifInfo.width, 90);
      expect(exifInfo.height, 160);
      _expectUtcDateTimeParts(exifInfo.fileCreatedAt, 2024, 12, 31, 23, 30);

      final exif = exifInfo.exifInfo.orElse(null);
      expect(exif, isNotNull);
      expect(exif!.dateTimeOriginal.orElse(null), isNotNull);
      _expectUtcDateTimeParts(exif.dateTimeOriginal.orElse(null)!, 2024, 12, 31, 23, 30);
      expect(exif.exifImageWidth.orElse(null), 90);
      expect(exif.exifImageHeight.orElse(null), 160);
      expect(exif.make.orElse(null), 'ImmichE2E');
      expect(exif.model.orElse(null), 'Metadata015');
      expect(exif.latitude.orElse(null), closeTo(27.717245, 0.0001));
      expect(exif.longitude.orElse(null), closeTo(85.323959, 0.0001));

      final noExifInfo = await _waitForAssetInfo(tester, assetsApi, noExifRemoteId);
      expect(noExifInfo.type, api.AssetTypeEnum.IMAGE);
      expect(noExifInfo.originalFileName.toLowerCase(), endsWith('.jpg'));
      expect(noExifInfo.width, 120);
      expect(noExifInfo.height, 80);
      _expectDateTimesClose(noExifInfo.fileCreatedAt, noExifAsset.createdAt, const Duration(minutes: 2));
      final noExif = noExifInfo.exifInfo.orElse(null);
      expect(noExif, isNotNull);
      expect(noExif!.make.orElse(null), isNull);
      expect(noExif.model.orElse(null), isNull);
      expect(noExif.latitude.orElse(null), isNull);
      expect(noExif.longitude.orElse(null), isNull);
    });

    _realStackSessionTest('MOB-REAL-016-$_caseSuffix', 'loads timeline first page, pagination, and date buckets', (
      tester,
    ) async {
      await _loadAuthenticatedApp(tester);

      final container = _containerOfApp(tester);
      final syncSuccess = await container.read(backgroundSyncProvider).syncRemote();
      expect(syncSuccess, isTrue);

      final user = Store.tryGet(StoreKey.currentUser);
      expect(user, isNotNull);

      final timeline = container.read(timelineFactoryProvider).main([user!.id]);
      addTearDown(timeline.dispose);

      final buckets = await _waitForTimelineBuckets(tester, timeline, minAssets: _timelineMinimumAssetCount);
      expect(timeline.totalAssets, greaterThanOrEqualTo(_timelineMinimumAssetCount));
      expect(buckets.length, greaterThanOrEqualTo(2), reason: 'Expected cross-month seed data in the real timeline');

      final totalFromBuckets = buckets.fold<int>(0, (total, bucket) => total + bucket.assetCount);
      expect(totalFromBuckets, timeline.totalAssets);
      _expectTimelineBucketsDescending(buckets);
      expect(_spansMultipleMonths(buckets), isTrue);

      await _exerciseTimelineUiPagination(tester);

      final firstPageCount = _timelineCountForPage(timeline.totalAssets, 0);
      final firstPage = await timeline.loadAssets(0, firstPageCount);
      expect(firstPage.length, firstPageCount);

      final assets = <BaseAsset>[];
      for (var offset = 0; offset < timeline.totalAssets; offset += _timelinePageSize) {
        final count = _timelineCountForPage(timeline.totalAssets, offset);
        final page = await timeline.loadAssets(offset, count);
        expect(page.length, count);
        assets.addAll(page);
      }

      expect(assets.length, timeline.totalAssets);
      expect(_timelineAssetIds(assets).length, assets.length);
      _expectTimelineAssetsDescending(assets);
      expect(_hasSharedTimestamp(assets), isTrue, reason: 'Expected same-timestamp assets in the real timeline');

      final firstPageAgain = await timeline.loadAssets(0, firstPageCount);
      expect(_timelineAssetIds(firstPageAgain), _timelineAssetIds(firstPage));
    });

    _realStackSessionTest('MOB-REAL-017-$_caseSuffix', 'opens remote image viewer and switches adjacent images', (
      tester,
    ) async {
      await _loadAuthenticatedApp(tester);

      final container = _containerOfApp(tester);
      final syncSuccess = await container.read(backgroundSyncProvider).syncRemote();
      expect(syncSuccess, isTrue);

      final user = Store.tryGet(StoreKey.currentUser);
      expect(user, isNotNull);

      final timeline = container.read(timelineFactoryProvider).main([user!.id]);
      addTearDown(timeline.dispose);

      await _waitForTimelineBuckets(tester, timeline, minAssets: _timelineMinimumAssetCount);
      final assets = await _loadAllTimelineAssets(timeline);
      final startIndex = _findRemoteImageWindow(assets, _assetViewerImageCount);
      expect(startIndex, greaterThanOrEqualTo(0), reason: 'Expected remote images in the real timeline');

      final imageAssets = _remoteImagesFrom(assets, startIndex, _assetViewerImageCount);
      await _expectRemoteImageMedia(container, tester, imageAssets.first);

      await _openTimelineAsset(tester, imageAssets.first);
      await pumpUntilFound(tester, find.byType(AssetViewer), timeout: const Duration(seconds: 60));
      expect(container.read(assetViewerProvider).currentAsset?.remoteId, imageAssets[0].id);

      final secondImage = await _swipeViewerToNextRemoteImage(tester, container, const Offset(-700, 0));
      expect(secondImage.remoteId, isNot(imageAssets[0].id));
      await _expectRemoteImageMedia(container, tester, secondImage);
      final thirdImage = await _swipeViewerToNextRemoteImage(tester, container, const Offset(-700, 0));
      expect(thirdImage.remoteId, isNot(anyOf(imageAssets[0].id, secondImage.remoteId)));
      await _expectRemoteImageMedia(container, tester, thirdImage);

      final previousImage = await _swipeViewerToNextRemoteImage(tester, container, const Offset(700, 0));
      expect(previousImage.remoteId, secondImage.remoteId);

      await _zoomViewerImage(tester, container);

      EventStream.shared.emit(const ViewerShowDetailsEvent());
      await _pumpFor(tester, const Duration(seconds: 1));
      expect(container.read(assetViewerProvider).showingDetails, isTrue);

      await tester.tap(find.byIcon(Icons.arrow_back_rounded).first);
      await _pumpFor(tester, const Duration(seconds: 1));
      expect(find.byType(Timeline), findsWidgets);

      final firstPageAgain = await timeline.loadAssets(0, _timelineCountForPage(timeline.totalAssets, 0));
      expect(firstPageAgain.any((asset) => asset.refersToSameAsset(imageAssets.first)), isTrue);
    });

    _realStackSessionTest('MOB-REAL-018-$_caseSuffix', 'plays, pauses, seeks, and resumes a remote video viewer', (
      tester,
    ) async {
      await _loadAuthenticatedApp(tester);

      final container = _containerOfApp(tester);
      final syncSuccess = await container.read(backgroundSyncProvider).syncRemote();
      expect(syncSuccess, isTrue);

      final user = Store.tryGet(StoreKey.currentUser);
      expect(user, isNotNull);

      final timeline = container.read(timelineFactoryProvider).main([user!.id]);
      addTearDown(timeline.dispose);

      await _waitForTimelineBuckets(tester, timeline, minAssets: _timelineMinimumAssetCount);
      final assets = await _loadAllTimelineAssets(timeline);
      final video = _firstRemoteVideo(assets);
      expect(video, isNotNull, reason: 'Expected at least one remote video in the real timeline');

      await _expectRemoteVideoMedia(container, tester, video!);
      await _openTimelineAsset(tester, video);
      await pumpUntilFound(tester, find.byType(AssetViewer), timeout: const Duration(seconds: 60));
      expect(container.read(assetViewerProvider).currentAsset?.remoteId, video.id);
      await pumpUntilFound(tester, find.byType(NativeVideoViewer), timeout: const Duration(seconds: 60));

      final loaded = await _waitForVideoState(
        tester,
        container,
        video.id,
        (state) => state.duration > Duration.zero,
        timeout: const Duration(seconds: 90),
      );
      expect(loaded.duration, greaterThan(const Duration(seconds: 2)));

      await _playVideoFromControls(tester, container, video.id);
      final firstPlayingPosition = await _waitForVideoPositionAfter(tester, container, video.id, Duration.zero);
      expect(firstPlayingPosition, greaterThan(Duration.zero));

      await _pauseVideoFromControls(tester, container, video.id);
      final pausedPosition = container.read(videoPlayerProvider(video.id)).position;
      await _pumpFor(tester, const Duration(seconds: 2));
      final pausedAfterWait = container.read(videoPlayerProvider(video.id)).position;
      expect(pausedAfterWait, lessThanOrEqualTo(pausedPosition + const Duration(seconds: 1)));

      final middleTarget = await _seekVideoWithSlider(tester, container, video.id, 0.50);
      final middlePosition = container.read(videoPlayerProvider(video.id)).position;
      expect(middlePosition, greaterThanOrEqualTo(middleTarget - const Duration(seconds: 1)));

      await _playVideoFromControls(tester, container, video.id);
      await _waitForVideoPositionAfter(tester, container, video.id, middlePosition);

      await _backgroundApp(tester);
      await _waitForVideoState(
        tester,
        container,
        video.id,
        (state) => state.status == VideoPlaybackStatus.paused,
        timeout: const Duration(seconds: 10),
      );
      final lifecyclePausePosition = container.read(videoPlayerProvider(video.id)).position;

      await _foregroundApp(tester);
      await _waitForVideoState(
        tester,
        container,
        video.id,
        (state) => state.status == VideoPlaybackStatus.playing || state.status == VideoPlaybackStatus.buffering,
        timeout: const Duration(seconds: 20),
      );
      final lifecycleResumePosition = container.read(videoPlayerProvider(video.id)).position;
      expect(lifecycleResumePosition, greaterThanOrEqualTo(lifecyclePausePosition - const Duration(seconds: 1)));

      await _pauseVideoFromControls(tester, container, video.id);
      final tailTarget = await _seekVideoWithSlider(tester, container, video.id, 0.85);
      final tailPosition = container.read(videoPlayerProvider(video.id)).position;
      expect(tailPosition, greaterThan(middlePosition));
      expect(tailPosition, greaterThanOrEqualTo(tailTarget - const Duration(seconds: 1)));

      await _playVideoFromControls(tester, container, video.id);
      await _waitForVideoPositionAfter(tester, container, video.id, tailPosition);
    });

    _realStackSessionTest('MOB-REAL-019-$_caseSuffix', 'applies full sync stream and persists acknowledgements', (
      tester,
    ) async {
      final (container, drift) = await _loadAuthenticatedSyncContainer();
      addTearDown(container.dispose);

      await container.read(syncApiRepositoryProvider).deleteSyncAck(_allReplayableSyncAckTypes);
      await Store.delete(StoreKey.syncMigrationStatus);
      await container.read(syncStreamRepositoryProvider).reset();

      final emptyCounts = await _remoteSyncRowCounts(drift);
      expect(
        emptyCounts.values.every((count) => count == 0),
        isTrue,
        reason: 'Expected a fresh local remote-sync database, got $emptyCounts',
      );

      final expectedEvents = await _collectSyncStreamEvents(container);
      expect(expectedEvents, isNotEmpty, reason: 'Expected the real sync stream to return backfill events');
      _expectRealSyncCoverage(expectedEvents);

      final expectedRows = _expectedRemoteSyncRowCounts(expectedEvents);
      expect(expectedRows['remote_asset_entity'], greaterThanOrEqualTo(_timelineMinimumAssetCount));
      expect(expectedRows['remote_exif_entity'], greaterThan(0));

      final syncSuccess = await container.read(syncStreamServiceProvider).sync();
      expect(syncSuccess, isTrue);

      final firstRows = await _remoteSyncRowCounts(drift);
      _expectRemoteSyncRows(firstRows, expectedRows, label: 'first sync');

      final firstAckSet = await _syncAckSet(container);
      _expectAckCoverage(firstAckSet, expectedEvents);

      final secondSyncSuccess = await container.read(syncStreamServiceProvider).sync();
      expect(secondSyncSuccess, isTrue);

      final secondRows = await _remoteSyncRowCounts(drift);
      expect(secondRows, firstRows, reason: 'Second sync should not duplicate Drift rows');

      final secondAckSet = await _syncAckSet(container);
      expect(secondAckSet, containsAll(firstAckSet), reason: 'ACKs from the first sync should remain persisted');
    });

    _realStackSessionTest('MOB-REAL-020-$_caseSuffix', 'resumes safely after an interrupted sync stream', (
      tester,
    ) async {
      final (container, drift) = await _loadAuthenticatedSyncContainer();
      addTearDown(container.dispose);

      await container.read(syncApiRepositoryProvider).deleteSyncAck(_allReplayableSyncAckTypes);
      await Store.delete(StoreKey.syncMigrationStatus);
      await container.read(syncStreamRepositoryProvider).reset();

      final expectedEvents = await _collectSyncStreamEvents(container);
      expect(expectedEvents, isNotEmpty, reason: 'Expected the real sync stream to return backfill events');
      _expectRealSyncCoverage(expectedEvents);
      final expectedRows = _expectedRemoteSyncRowCounts(expectedEvents);

      final interruptedEvents = await _interruptSyncAfterFirstSafeEvent(container);
      expect(interruptedEvents, hasLength(1));
      expect(interruptedEvents.single.type, api.SyncEntityType.authUserV1);

      final interruptedRows = await _remoteSyncRowCounts(drift);
      _expectRemoteSyncRows(
        interruptedRows,
        _expectedRemoteSyncRowCounts(interruptedEvents),
        label: 'interrupted sync',
      );

      final interruptedAckSet = await _syncAckSet(container);
      final interruptedAckTypes = _syncAckTypes(interruptedAckSet);
      expect(interruptedAckTypes, contains(api.SyncEntityType.authUserV1));
      expect(interruptedAckTypes, isNot(contains(api.SyncEntityType.syncCompleteV1)));

      final resumedSyncSuccess = await container.read(syncStreamServiceProvider).sync();
      expect(resumedSyncSuccess, isTrue);

      final resumedRows = await _remoteSyncRowCounts(drift);
      _expectRemoteSyncRows(resumedRows, expectedRows, label: 'resumed sync');

      final resumedAckSet = await _syncAckSet(container);
      expect(resumedAckSet.length, greaterThan(interruptedAckSet.length));
      _expectAckCoverage(resumedAckSet, expectedEvents);

      final secondSyncSuccess = await container.read(syncStreamServiceProvider).sync();
      expect(secondSyncSuccess, isTrue);

      final secondRows = await _remoteSyncRowCounts(drift);
      expect(secondRows, resumedRows, reason: 'Second sync after recovery should not duplicate Drift rows');

      final secondAckSet = await _syncAckSet(container);
      expect(secondAckSet, containsAll(resumedAckSet), reason: 'Recovered ACKs should remain persisted');
    });

    _realStackSessionTest(
      'MOB-REAL-021-$_caseSuffix',
      'converges realtime and incremental changes from another client',
      (tester) async {
        await _loadAuthenticatedApp(tester, overrideCancellation: true);
        final container = _containerOfApp(tester);
        final drift = container.read(driftProvider);
        final assetsApi = container.read(apiServiceProvider).assetsApi;
        final websocket = container.read(websocketProvider.notifier);
        String? uploadedRemoteId;

        addTearDown(() async {
          try {
            websocket.disconnect();
          } catch (_) {
            // The ProviderScope may already have disposed the notifier.
          }
          final assetId = uploadedRemoteId;
          if (assetId != null) {
            await _deleteTestAssetBestEffort(assetsApi, assetId);
          }
        });

        await container.read(syncApiRepositoryProvider).deleteSyncAck(_allReplayableSyncAckTypes);
        await Store.delete(StoreKey.syncMigrationStatus);
        await container.read(syncStreamRepositoryProvider).reset();
        final baselineSyncSuccess = await container.read(syncStreamServiceProvider).sync();
        expect(baselineSyncSuccess, isTrue);
        final baselineRows = await _remoteSyncRowCounts(drift);

        await _connectAndWaitForWebsocket(tester, container);

        final createdAt = DateTime.now().toUtc();
        final fileName = 'immich-e2e-realtime-021-${createdAt.microsecondsSinceEpoch}.jpg';
        final uploadedId = await _uploadGeneratedJpegAsSecondClient(fileName, createdAt);
        uploadedRemoteId = uploadedId;
        final uploadSyncSuccess = await container.read(syncStreamServiceProvider).sync();
        expect(uploadSyncSuccess, isTrue);

        final uploadedAsset = await _waitForRemoteAssetState(
          tester,
          container,
          uploadedId,
          (asset) => !asset.isFavorite && !asset.isTrashed,
          reason: 'Expected realtime remote-change handling to create a local remote asset row',
        );
        expect(uploadedAsset.isImage, isTrue);

        await assetsApi.updateAssets(
          api.AssetBulkUpdateDto(ids: [uploadedId], isFavorite: const api.Optional.present(true)),
        );
        final updateSyncSuccess = await container.read(syncStreamServiceProvider).sync();
        expect(updateSyncSuccess, isTrue);

        await _waitForRemoteAssetState(
          tester,
          container,
          uploadedId,
          (asset) => asset.isFavorite && !asset.isTrashed,
          reason: 'Expected websocket-driven incremental sync to apply favorite update',
        );

        container.read(websocketProvider.notifier).disconnect();
        await _pumpUntil(
          tester,
          () => !container.read(websocketProvider).isConnected,
          timeout: const Duration(seconds: 10),
        );

        await assetsApi.updateAssets(
          api.AssetBulkUpdateDto(ids: [uploadedId], isFavorite: const api.Optional.present(false)),
        );
        await assetsApi.deleteAssets(
          api.AssetBulkDeleteDto(ids: [uploadedId], force: const api.Optional.present(false)),
        );
        await _pumpFor(tester, const Duration(seconds: 3));

        final staleAsset = await container.read(remoteAssetRepositoryProvider).get(uploadedId);
        expect(staleAsset, isNotNull);
        expect(staleAsset!.isFavorite, isTrue, reason: 'Disconnected websocket should not apply remote changes inline');
        expect(staleAsset.isTrashed, isFalse);

        await _connectAndWaitForWebsocket(tester, container);
        final recoveredSyncSuccess = await container.read(syncStreamServiceProvider).sync();
        expect(recoveredSyncSuccess, isTrue);

        await _waitForRemoteAssetGoneOrTrashed(
          tester,
          container,
          uploadedId,
          reason: 'Expected reconnect sync to backfill offline favorite and trash changes',
        );
        expect(await _remoteAssetRowCountById(drift, uploadedId), lessThanOrEqualTo(1));

        final recoveredRows = await _remoteSyncRowCounts(drift);
        expect(recoveredRows['remote_asset_entity'], greaterThanOrEqualTo(baselineRows['remote_asset_entity']!));
        final secondSyncSuccess = await container.read(syncStreamServiceProvider).sync();
        expect(secondSyncSuccess, isTrue);
        expect(
          await _remoteSyncRowCounts(drift),
          recoveredRows,
          reason: 'Second sync after realtime recovery should not duplicate rows',
        );
      },
    );

    _realStackSessionTest(
      'MOB-REAL-022-$_caseSuffix',
      'keeps repeated favorite changes idempotent and cross-client consistent',
      (tester) async {
        await _loadAuthenticatedApp(tester, overrideCancellation: true);
        final container = _containerOfApp(tester);
        final drift = container.read(driftProvider);
        final assetsApi = container.read(apiServiceProvider).assetsApi;
        String? uploadedRemoteId;

        addTearDown(() async {
          final assetId = uploadedRemoteId;
          if (assetId != null) {
            await _deleteTestAssetBestEffort(assetsApi, assetId);
          }
        });

        await container.read(syncApiRepositoryProvider).deleteSyncAck(_allReplayableSyncAckTypes);
        await Store.delete(StoreKey.syncMigrationStatus);
        await container.read(syncStreamRepositoryProvider).reset();
        final baselineSyncSuccess = await container.read(syncStreamServiceProvider).sync();
        expect(baselineSyncSuccess, isTrue);

        final createdAt = DateTime.now().toUtc();
        final fileName = 'immich-e2e-favorite-022-${createdAt.microsecondsSinceEpoch}.jpg';
        final uploadedId = await _uploadGeneratedJpegAsSecondClient(fileName, createdAt);
        uploadedRemoteId = uploadedId;

        final initialSyncSuccess = await container.read(syncStreamServiceProvider).sync();
        expect(initialSyncSuccess, isTrue);

        await _waitForRemoteAssetState(
          tester,
          container,
          uploadedId,
          (asset) => !asset.isFavorite && !asset.isTrashed,
          reason: 'Expected uploaded asset to sync locally before favorite toggles',
        );
        expect(await _remoteAssetRowCountById(drift, uploadedId), 1);

        await assetsApi.updateAssets(
          api.AssetBulkUpdateDto(ids: [uploadedId], isFavorite: const api.Optional.present(true)),
        );
        await assetsApi.updateAssets(
          api.AssetBulkUpdateDto(ids: [uploadedId], isFavorite: const api.Optional.present(true)),
        );

        await _waitForAssetInfoState(
          tester,
          assetsApi,
          uploadedId,
          (info) => info.isFavorite && !info.isTrashed,
          reason: 'Expected repeated favorite requests to converge on server favorite=true',
        );
        final favoriteSyncSuccess = await container.read(syncStreamServiceProvider).sync();
        expect(favoriteSyncSuccess, isTrue);

        await _waitForRemoteAssetState(
          tester,
          container,
          uploadedId,
          (asset) => asset.isFavorite && !asset.isTrashed,
          reason: 'Expected synced client to observe favorite=true from another client',
        );
        expect(await _remoteAssetRowCountById(drift, uploadedId), 1);

        await assetsApi.updateAssets(
          api.AssetBulkUpdateDto(ids: [uploadedId], isFavorite: const api.Optional.present(false)),
        );
        await assetsApi.updateAssets(
          api.AssetBulkUpdateDto(ids: [uploadedId], isFavorite: const api.Optional.present(false)),
        );

        await _waitForAssetInfoState(
          tester,
          assetsApi,
          uploadedId,
          (info) => !info.isFavorite && !info.isTrashed,
          reason: 'Expected repeated unfavorite requests to converge on server favorite=false',
        );
        final unfavoriteSyncSuccess = await container.read(syncStreamServiceProvider).sync();
        expect(unfavoriteSyncSuccess, isTrue);

        await _waitForRemoteAssetState(
          tester,
          container,
          uploadedId,
          (asset) => !asset.isFavorite && !asset.isTrashed,
          reason: 'Expected original client to observe favorite=false after cross-client sync',
        );
        final rowsAfterUnfavorite = await _remoteSyncRowCounts(drift);
        expect(await _remoteAssetRowCountById(drift, uploadedId), 1);

        final secondSyncSuccess = await container.read(syncStreamServiceProvider).sync();
        expect(secondSyncSuccess, isTrue);
        expect(
          await _remoteSyncRowCounts(drift),
          rowsAfterUnfavorite,
          reason: 'Second sync after idempotent favorite toggles should not duplicate rows',
        );
      },
    );

    _realStackSessionTest(
      'MOB-REAL-023-$_caseSuffix',
      'keeps archive and hidden assets isolated from the main timeline',
      (tester) async {
        await _loadAuthenticatedApp(tester, overrideCancellation: true);
        final container = _containerOfApp(tester);
        final drift = container.read(driftProvider);
        final assetsApi = container.read(apiServiceProvider).assetsApi;
        final uploadedRemoteIds = <String>[];

        addTearDown(() async {
          for (final assetId in uploadedRemoteIds) {
            await _deleteTestAssetBestEffort(assetsApi, assetId);
          }
        });

        await container.read(syncApiRepositoryProvider).deleteSyncAck(_allReplayableSyncAckTypes);
        await Store.delete(StoreKey.syncMigrationStatus);
        await container.read(syncStreamRepositoryProvider).reset();
        final baselineSyncSuccess = await container.read(syncStreamServiceProvider).sync();
        expect(baselineSyncSuccess, isTrue);

        final user = Store.tryGet(StoreKey.currentUser);
        expect(user, isNotNull);

        final baseCreatedAt = DateTime.now().toUtc();
        final normalCreatedAt = baseCreatedAt.subtract(const Duration(seconds: 2));
        final favoriteCreatedAt = baseCreatedAt.subtract(const Duration(seconds: 1));
        final hiddenCreatedAt = baseCreatedAt;

        final normalId = await _uploadGeneratedJpegAsSecondClient(
          'immich-e2e-archive-023-normal-${normalCreatedAt.microsecondsSinceEpoch}.jpg',
          normalCreatedAt,
        );
        uploadedRemoteIds.add(normalId);
        final favoriteId = await _uploadGeneratedJpegAsSecondClient(
          'immich-e2e-archive-023-favorite-${favoriteCreatedAt.microsecondsSinceEpoch}.jpg',
          favoriteCreatedAt,
          isFavorite: true,
        );
        uploadedRemoteIds.add(favoriteId);
        final hiddenId = await _uploadGeneratedJpegAsSecondClient(
          'immich-e2e-archive-023-hidden-${hiddenCreatedAt.microsecondsSinceEpoch}.jpg',
          hiddenCreatedAt,
          visibility: api.AssetVisibility.hidden,
        );
        uploadedRemoteIds.add(hiddenId);

        final uploadSyncSuccess = await container.read(syncStreamServiceProvider).sync();
        expect(uploadSyncSuccess, isTrue);

        await _waitForRemoteAssetState(
          tester,
          container,
          normalId,
          (asset) => asset.visibility == AssetVisibility.timeline && !asset.isFavorite && !asset.isTrashed,
          reason: 'Expected normal uploaded asset to sync as a timeline asset',
        );
        await _waitForRemoteAssetState(
          tester,
          container,
          favoriteId,
          (asset) => asset.visibility == AssetVisibility.timeline && asset.isFavorite && !asset.isTrashed,
          reason: 'Expected favorite uploaded asset to sync as a favorite timeline asset',
        );
        await _waitForRemoteAssetState(
          tester,
          container,
          hiddenId,
          (asset) => asset.visibility == AssetVisibility.hidden && !asset.isTrashed,
          reason: 'Expected hidden uploaded asset to sync as hidden',
        );

        final timelineFactory = container.read(timelineFactoryProvider);
        final mainTimeline = timelineFactory.main([user!.id]);
        final favoriteTimeline = timelineFactory.favorite(user.id);
        final archiveTimeline = timelineFactory.archive(user.id);
        addTearDown(mainTimeline.dispose);
        addTearDown(favoriteTimeline.dispose);
        addTearDown(archiveTimeline.dispose);

        await _expectTimelineAssetSet(
          tester,
          mainTimeline,
          includes: {normalId, favoriteId},
          excludes: {hiddenId},
          reason: 'Initial main timeline should include timeline assets and exclude hidden assets',
        );
        await _expectTimelineAssetSet(
          tester,
          favoriteTimeline,
          includes: {favoriteId},
          excludes: {normalId, hiddenId},
          reason: 'Initial favorite timeline should include only the favorited visible asset',
        );
        await _expectTimelineAssetSet(
          tester,
          archiveTimeline,
          includes: const {},
          excludes: {normalId, favoriteId, hiddenId},
          reason: 'Initial archive timeline should not include timeline or hidden assets',
        );

        await assetsApi.updateAssets(
          api.AssetBulkUpdateDto(
            ids: [favoriteId],
            visibility: const api.Optional.present(api.AssetVisibility.archive),
          ),
        );
        await _waitForAssetInfoState(
          tester,
          assetsApi,
          favoriteId,
          (info) => info.visibility == api.AssetVisibility.archive && info.isFavorite && !info.isTrashed,
          reason: 'Expected archived favorite asset to keep favorite relation on the server',
        );
        final archiveSyncSuccess = await container.read(syncStreamServiceProvider).sync();
        expect(archiveSyncSuccess, isTrue);

        await _waitForRemoteAssetState(
          tester,
          container,
          favoriteId,
          (asset) => asset.visibility == AssetVisibility.archive && asset.isFavorite && !asset.isTrashed,
          reason: 'Expected archived favorite asset to sync locally',
        );
        expect(await _remoteAssetRowCountById(drift, favoriteId), 1);

        await _expectTimelineAssetSet(
          tester,
          mainTimeline,
          includes: {normalId},
          excludes: {favoriteId, hiddenId},
          reason: 'Main timeline should not leak archived or hidden assets',
        );
        await _expectTimelineAssetSet(
          tester,
          archiveTimeline,
          includes: {favoriteId},
          excludes: {normalId, hiddenId},
          reason: 'Archive timeline should contain the archived asset and exclude hidden assets',
        );
        await _expectTimelineAssetSet(
          tester,
          favoriteTimeline,
          includes: {favoriteId},
          excludes: {normalId, hiddenId},
          reason: 'Favorite timeline should retain archived favorite assets without leaking hidden assets',
        );

        await assetsApi.updateAssets(
          api.AssetBulkUpdateDto(
            ids: [favoriteId],
            visibility: const api.Optional.present(api.AssetVisibility.timeline),
          ),
        );
        await _waitForAssetInfoState(
          tester,
          assetsApi,
          favoriteId,
          (info) => info.visibility == api.AssetVisibility.timeline && info.isFavorite && !info.isTrashed,
          reason: 'Expected unarchived favorite asset to return to timeline visibility on the server',
        );
        final restoreSyncSuccess = await container.read(syncStreamServiceProvider).sync();
        expect(restoreSyncSuccess, isTrue);

        final restoredAssets = await _expectTimelineAssetSet(
          tester,
          mainTimeline,
          includes: {normalId, favoriteId},
          excludes: {hiddenId},
          reason: 'Restored favorite asset should return to the main timeline while hidden stays isolated',
        );
        final restoredFavoriteIndex = restoredAssets.indexWhere((asset) => _timelineAssetId(asset) == favoriteId);
        final normalIndex = restoredAssets.indexWhere((asset) => _timelineAssetId(asset) == normalId);
        expect(restoredFavoriteIndex, greaterThanOrEqualTo(0));
        expect(normalIndex, greaterThanOrEqualTo(0));
        expect(
          restoredFavoriteIndex,
          lessThan(normalIndex),
          reason: 'Restored asset should return to the main timeline at its created-at position',
        );

        await _expectTimelineAssetSet(
          tester,
          archiveTimeline,
          includes: const {},
          excludes: {normalId, favoriteId, hiddenId},
          reason: 'Archive timeline should be empty for restored and hidden test assets',
        );
        await _expectTimelineAssetSet(
          tester,
          favoriteTimeline,
          includes: {favoriteId},
          excludes: {normalId, hiddenId},
          reason: 'Favorite timeline should still expose the restored favorite without hidden leakage',
        );

        final rowsAfterRestore = await _remoteSyncRowCounts(drift);
        final secondSyncSuccess = await container.read(syncStreamServiceProvider).sync();
        expect(secondSyncSuccess, isTrue);
        expect(
          await _remoteSyncRowCounts(drift),
          rowsAfterRestore,
          reason: 'Second sync after archive lifecycle should not duplicate local rows',
        );
      },
    );

    if (_selectedCaseId.isNotEmpty && !_registeredSelectedCase) {
      test(_selectedCaseId, () => fail('No real stack auth test registered for $_selectedCaseId'));
    }
  });
}

Future<void> _exerciseTimelineUiPagination(WidgetTester tester) async {
  await pumpUntilFound(tester, find.byType(Timeline), timeout: const Duration(seconds: 60));
  await _dismissFeatureMessageIfVisible(tester);
  final scrollable = find.descendant(of: find.byType(Timeline), matching: find.byType(Scrollable));
  expect(scrollable, findsWidgets);

  for (var i = 0; i < 4; i++) {
    await tester.fling(scrollable.first, const Offset(0, -1200), 1500);
    await _pumpFor(tester, const Duration(milliseconds: 700));
  }

  for (var i = 0; i < 4; i++) {
    await tester.fling(scrollable.first, const Offset(0, 1200), 1500);
    await _pumpFor(tester, const Duration(milliseconds: 700));
  }
}

final _allReplayableSyncAckTypes = api.SyncEntityType.values.toList(growable: false);

const _remoteSyncTableNames = [
  'auth_user_entity',
  'user_entity',
  'partner_entity',
  'remote_asset_entity',
  'remote_exif_entity',
  'remote_asset_cloud_id_entity',
  'asset_edit_entity',
  'remote_album_entity',
  'remote_album_user_entity',
  'remote_album_asset_entity',
  'memory_entity',
  'memory_asset_entity',
  'stack_entity',
  'user_metadata_entity',
  'person_entity',
  'asset_face_entity',
  'asset_ocr_entity',
];

const _assetUpsertSyncTypes = {
  api.SyncEntityType.assetV1,
  api.SyncEntityType.assetV2,
  api.SyncEntityType.partnerAssetV1,
  api.SyncEntityType.partnerAssetV2,
  api.SyncEntityType.partnerAssetBackfillV1,
  api.SyncEntityType.partnerAssetBackfillV2,
  api.SyncEntityType.albumAssetCreateV1,
  api.SyncEntityType.albumAssetCreateV2,
  api.SyncEntityType.albumAssetUpdateV1,
  api.SyncEntityType.albumAssetUpdateV2,
  api.SyncEntityType.albumAssetBackfillV1,
  api.SyncEntityType.albumAssetBackfillV2,
};

const _assetDeleteSyncTypes = {api.SyncEntityType.assetDeleteV1, api.SyncEntityType.partnerAssetDeleteV1};

const _exifUpsertSyncTypes = {
  api.SyncEntityType.assetExifV1,
  api.SyncEntityType.partnerAssetExifV1,
  api.SyncEntityType.partnerAssetExifBackfillV1,
  api.SyncEntityType.albumAssetExifCreateV1,
  api.SyncEntityType.albumAssetExifUpdateV1,
  api.SyncEntityType.albumAssetExifBackfillV1,
};

const _albumUpsertSyncTypes = {api.SyncEntityType.albumV1, api.SyncEntityType.albumV2};

const _albumAssetUpsertSyncTypes = {api.SyncEntityType.albumToAssetV1, api.SyncEntityType.albumToAssetBackfillV1};

const _stackUpsertSyncTypes = {
  api.SyncEntityType.stackV1,
  api.SyncEntityType.partnerStackV1,
  api.SyncEntityType.partnerStackBackfillV1,
};

const _stackDeleteSyncTypes = {api.SyncEntityType.stackDeleteV1, api.SyncEntityType.partnerStackDeleteV1};

const _assetFaceUpsertSyncTypes = {api.SyncEntityType.assetFaceV1, api.SyncEntityType.assetFaceV2};

Future<List<SyncEvent>> _collectSyncStreamEvents(ProviderContainer container) async {
  final apiService = container.read(apiServiceProvider);
  final serverVersion = await apiService.serverInfoApi.getServerVersion();
  expect(serverVersion, isNotNull);

  final events = <SyncEvent>[];
  await container
      .read(syncApiRepositoryProvider)
      .streamChanges(
        (batch, _, _) async {
          events.addAll(batch);
        },
        serverVersion: SemVer(major: serverVersion!.major, minor: serverVersion.minor, patch: serverVersion.patch_),
        initialBatchSize: 25,
        batchSize: 50,
      );
  return events;
}

Future<List<SyncEvent>> _interruptSyncAfterFirstSafeEvent(ProviderContainer container) async {
  final apiService = container.read(apiServiceProvider);
  final serverVersion = await apiService.serverInfoApi.getServerVersion();
  expect(serverVersion, isNotNull);

  final events = <SyncEvent>[];
  await container
      .read(syncApiRepositoryProvider)
      .streamChanges(
        (batch, abort, _) async {
          final event = batch.single;
          events.add(event);
          expect(event.type, api.SyncEntityType.authUserV1);
          await container.read(syncStreamRepositoryProvider).updateAuthUsersV1([event.data as api.SyncAuthUserV1]);
          await container.read(syncApiRepositoryProvider).ack([event.ack]);
          abort();
        },
        serverVersion: SemVer(major: serverVersion!.major, minor: serverVersion.minor, patch: serverVersion.patch_),
        initialBatchSize: 1,
        batchSize: 1,
      );
  return events;
}

Future<void> _connectAndWaitForWebsocket(WidgetTester tester, ProviderContainer container) async {
  container.read(websocketProvider.notifier).connect();
  await _pumpUntil(tester, () => container.read(websocketProvider).isConnected, timeout: const Duration(seconds: 30));
}

void _expectRealSyncCoverage(List<SyncEvent> events) {
  final eventTypes = events.map((event) => event.type).toSet();
  final logicalTypes = _logicalSyncTypes(events);
  expect(logicalTypes, containsAll([api.SyncEntityType.authUserV1, api.SyncEntityType.userV1]));
  expect(eventTypes.intersection(_assetUpsertSyncTypes), isNotEmpty, reason: 'Expected asset sync events');
  expect(eventTypes, contains(api.SyncEntityType.assetExifV1));
  expect(
    logicalTypes.intersection(_albumUpsertSyncTypes),
    isNotEmpty,
    reason: 'Expected album sync events or checkpoints',
  );
  expect(
    logicalTypes.intersection(_assetFaceUpsertSyncTypes),
    isNotEmpty,
    reason: 'Expected face sync events or checkpoints',
  );
  expect(logicalTypes, containsAll([api.SyncEntityType.personV1, api.SyncEntityType.syncCompleteV1]));

  final syncedMediaTypes = events
      .where((event) => _assetUpsertSyncTypes.contains(event.type))
      .map((event) => (event.data as dynamic).type)
      .toSet();
  expect(syncedMediaTypes, containsAll([api.AssetTypeEnum.IMAGE, api.AssetTypeEnum.VIDEO]));
}

Set<api.SyncEntityType> _logicalSyncTypes(List<SyncEvent> events) {
  final types = <api.SyncEntityType>{};
  for (final event in events) {
    if (event.type == api.SyncEntityType.syncAckV1) {
      final ackType = _syncEntityTypeFromAck(event.ack);
      if (ackType != null) {
        types.add(ackType);
      }
    } else {
      types.add(event.type);
    }
  }
  return types;
}

api.SyncEntityType? _syncEntityTypeFromAck(String ack) {
  final separator = ack.indexOf('|');
  final value = separator < 0 ? ack : ack.substring(0, separator);
  return api.SyncEntityType.fromJson(value);
}

Map<String, int> _expectedRemoteSyncRowCounts(List<SyncEvent> events) {
  final authUsers = <String>{};
  final users = <String>{};
  final partners = <String>{};
  final assets = <String>{};
  final exifs = <String>{};
  final cloudIds = <String>{};
  final assetEdits = <String>{};
  final albums = <String>{};
  final albumUsers = <String>{};
  final albumAssets = <String>{};
  final memories = <String>{};
  final memoryAssets = <String>{};
  final stacks = <String>{};
  final userMetadata = <String>{};
  final people = <String>{};
  final faces = <String>{};
  final ocrRows = <String>{};

  for (final event in events) {
    final data = event.data as dynamic;
    switch (event.type) {
      case api.SyncEntityType.authUserV1:
        authUsers.add(data.id as String);
      case api.SyncEntityType.userV1:
        users.add(data.id as String);
      case api.SyncEntityType.userDeleteV1:
        users.remove(data.userId as String);
      case api.SyncEntityType.partnerV1:
        partners.add('${data.sharedById}|${data.sharedWithId}');
      case api.SyncEntityType.partnerDeleteV1:
        partners.remove('${data.sharedById}|${data.sharedWithId}');
      case final type when _assetUpsertSyncTypes.contains(type):
        assets.add(data.id as String);
      case final type when _assetDeleteSyncTypes.contains(type):
        assets.remove(data.assetId as String);
      case final type when _exifUpsertSyncTypes.contains(type):
        exifs.add(data.assetId as String);
      case api.SyncEntityType.assetMetadataV1:
        if (data.key == kMobileMetadataKey) {
          cloudIds.add(data.assetId as String);
        }
      case api.SyncEntityType.assetMetadataDeleteV1:
        if (data.key == kMobileMetadataKey) {
          cloudIds.remove(data.assetId as String);
        }
      case api.SyncEntityType.assetEditV1:
        assetEdits.add(data.id as String);
      case api.SyncEntityType.assetEditDeleteV1:
        assetEdits.remove(data.editId as String);
      case api.SyncEntityType.albumV1:
        albums.add(data.id as String);
        albumUsers.add('${data.id}|${data.ownerId}');
      case api.SyncEntityType.albumV2:
        albums.add(data.id as String);
      case api.SyncEntityType.albumDeleteV1:
        albums.remove(data.albumId as String);
      case api.SyncEntityType.albumUserV1:
      case api.SyncEntityType.albumUserBackfillV1:
        albumUsers.add('${data.albumId}|${data.userId}');
      case api.SyncEntityType.albumUserDeleteV1:
        albumUsers.remove('${data.albumId}|${data.userId}');
      case final type when _albumAssetUpsertSyncTypes.contains(type):
        albumAssets.add('${data.albumId}|${data.assetId}');
      case api.SyncEntityType.albumToAssetDeleteV1:
        albumAssets.remove('${data.albumId}|${data.assetId}');
      case api.SyncEntityType.memoryV1:
        memories.add(data.id as String);
      case api.SyncEntityType.memoryDeleteV1:
        memories.remove(data.memoryId as String);
      case api.SyncEntityType.memoryToAssetV1:
        memoryAssets.add('${data.memoryId}|${data.assetId}');
      case api.SyncEntityType.memoryToAssetDeleteV1:
        memoryAssets.remove('${data.memoryId}|${data.assetId}');
      case final type when _stackUpsertSyncTypes.contains(type):
        stacks.add(data.id as String);
      case final type when _stackDeleteSyncTypes.contains(type):
        stacks.remove(data.stackId as String);
      case api.SyncEntityType.userMetadataV1:
        userMetadata.add('${data.userId}|${data.key}');
      case api.SyncEntityType.userMetadataDeleteV1:
        userMetadata.remove('${data.userId}|${data.key}');
      case api.SyncEntityType.personV1:
        people.add(data.id as String);
      case api.SyncEntityType.personDeleteV1:
        people.remove(data.personId as String);
      case final type when _assetFaceUpsertSyncTypes.contains(type):
        faces.add(data.id as String);
      case api.SyncEntityType.assetFaceDeleteV1:
        faces.remove(data.assetFaceId as String);
      case api.SyncEntityType.assetOcrV1:
        ocrRows.add(data.id as String);
      case api.SyncEntityType.assetOcrDeleteV1:
        ocrRows.remove(data.id as String);
      case api.SyncEntityType.syncAckV1:
      case api.SyncEntityType.syncResetV1:
      case api.SyncEntityType.syncCompleteV1:
      case _:
        break;
    }
  }

  return {
    'auth_user_entity': authUsers.length,
    'user_entity': users.length,
    'partner_entity': partners.length,
    'remote_asset_entity': assets.length,
    'remote_exif_entity': exifs.length,
    'remote_asset_cloud_id_entity': cloudIds.length,
    'asset_edit_entity': assetEdits.length,
    'remote_album_entity': albums.length,
    'remote_album_user_entity': albumUsers.length,
    'remote_album_asset_entity': albumAssets.length,
    'memory_entity': memories.length,
    'memory_asset_entity': memoryAssets.length,
    'stack_entity': stacks.length,
    'user_metadata_entity': userMetadata.length,
    'person_entity': people.length,
    'asset_face_entity': faces.length,
    'asset_ocr_entity': ocrRows.length,
  };
}

Future<Map<String, int>> _remoteSyncRowCounts(Drift drift) async {
  final counts = <String, int>{};
  for (final table in _remoteSyncTableNames) {
    counts[table] = await _rowCount(drift, table);
  }
  return counts;
}

Future<int> _rowCount(Drift drift, String table) async {
  final row = await drift.customSelect('SELECT COUNT(*) AS count FROM $table').getSingle();
  return row.read<int>('count');
}

void _expectRemoteSyncRows(Map<String, int> actualRows, Map<String, int> expectedRows, {required String label}) {
  for (final entry in expectedRows.entries) {
    expect(
      actualRows[entry.key],
      entry.value,
      reason: '$label row mismatch for ${entry.key}: expected $expectedRows, got $actualRows',
    );
  }
}

Future<Set<String>> _syncAckSet(ProviderContainer container) async {
  final syncAcks = await container.read(apiServiceProvider).syncApi.getSyncAck();
  return {for (final ack in syncAcks ?? <api.SyncAckDto>[]) '${ack.type.toJson()}\t${ack.ack}'};
}

Set<api.SyncEntityType> _syncAckTypes(Set<String> ackSet) {
  return {
    for (final ack in ackSet) api.SyncEntityType.fromJson(ack.split('\t').first),
  }.whereType<api.SyncEntityType>().toSet();
}

void _expectAckCoverage(Set<String> ackSet, List<SyncEvent> expectedEvents) {
  final ackedTypes = _syncAckTypes(ackSet);

  final expectedTypes = _logicalSyncTypes(expectedEvents);
  final requiredTypes = {
    for (final type in expectedTypes)
      if (type != api.SyncEntityType.syncAckV1 && type != api.SyncEntityType.syncResetV1) type,
  };

  for (final type in requiredTypes) {
    expect(ackedTypes, contains(type), reason: 'Expected persisted sync ACK for ${type.toJson()} in $ackSet');
  }
}

Future<List<BaseAsset>> _loadAllTimelineAssets(TimelineService timeline) async {
  final assets = <BaseAsset>[];
  for (var offset = 0; offset < timeline.totalAssets; offset += _timelinePageSize) {
    final count = _timelineCountForPage(timeline.totalAssets, offset);
    assets.addAll(await timeline.loadAssets(offset, count));
  }
  return assets;
}

int _findRemoteImageWindow(List<BaseAsset> assets, int count) {
  for (var start = 0; start < assets.length; start++) {
    if (_remoteImagesFrom(assets, start, count).length == count) {
      return start;
    }
  }
  return -1;
}

List<RemoteAsset> _remoteImagesFrom(List<BaseAsset> assets, int start, int count) =>
    assets.skip(start).whereType<RemoteAsset>().where((asset) => asset.isImage).take(count).toList();

RemoteAsset? _firstRemoteVideo(List<BaseAsset> assets) {
  for (final asset in assets.whereType<RemoteAsset>()) {
    if (asset.isVideo) {
      return asset;
    }
  }
  return null;
}

Future<void> _expectRemoteImageMedia(ProviderContainer container, WidgetTester tester, RemoteAsset asset) async {
  final assetsApi = container.read(apiServiceProvider).assetsApi;
  final info = await _waitForBasicAssetInfo(tester, assetsApi, asset.id);
  expect(info.type, api.AssetTypeEnum.IMAGE);
  expect(info.originalFileName, isNotEmpty);
  expect(info.fileCreatedAt.toUtc(), asset.createdAt.toUtc());

  final thumbnail = await _waitForSuccessfulResponse(
    tester,
    () => assetsApi.viewAssetWithHttpInfo(asset.id, size: api.AssetMediaSize.thumbnail),
  );
  expect(thumbnail.bodyBytes, isNotEmpty);

  final preview = await _waitForSuccessfulResponse(
    tester,
    () => assetsApi.viewAssetWithHttpInfo(asset.id, size: api.AssetMediaSize.preview),
  );
  expect(preview.bodyBytes, isNotEmpty);

  final original = await _waitForSuccessfulResponse(
    tester,
    () => container.read(assetApiRepositoryProvider).downloadAsset(asset.id, edited: false),
  );
  expect(original.bodyBytes, isNotEmpty);
  final checksum = asset.checksum;
  expect(checksum, isNotNull);
  expect(base64Encode(md5.convert(original.bodyBytes).bytes), checksum);
}

Future<void> _expectRemoteVideoMedia(ProviderContainer container, WidgetTester tester, RemoteAsset asset) async {
  final assetsApi = container.read(apiServiceProvider).assetsApi;
  final info = await _waitForBasicAssetInfo(tester, assetsApi, asset.id);
  expect(info.type, api.AssetTypeEnum.VIDEO);
  expect(info.originalFileName, isNotEmpty);
  expect(info.fileCreatedAt.toUtc(), asset.createdAt.toUtc());

  final thumbnail = await _waitForSuccessfulResponse(
    tester,
    () => assetsApi.viewAssetWithHttpInfo(asset.id, size: api.AssetMediaSize.thumbnail),
  );
  expect(thumbnail.bodyBytes, isNotEmpty);

  final playback = await _waitForSuccessfulResponse(
    tester,
    () => assetsApi.playAssetVideoWithHttpInfo(asset.id),
    acceptedStatusCodes: const {200, 206},
  );
  expect(playback.bodyBytes, isNotEmpty);

  final rangedPlayback = await _waitForSuccessfulResponse(
    tester,
    () => http.get(
      Uri.parse('${Store.get(StoreKey.serverEndpoint)}/assets/${asset.id}/video/playback'),
      headers: {
        ...ApiService.getRequestHeaders(),
        'Authorization': 'Bearer ${Store.get(StoreKey.accessToken)}',
        HttpHeaders.rangeHeader: 'bytes=0-2047',
      },
    ),
    acceptedStatusCodes: const {206},
  );
  expect(rangedPlayback.bodyBytes, isNotEmpty);
  expect(rangedPlayback.headers[HttpHeaders.contentRangeHeader], startsWith('bytes 0-'));
}

Future<api.AssetResponseDto> _waitForBasicAssetInfo(
  WidgetTester tester,
  api.AssetsApi assetsApi,
  String remoteAssetId,
) async {
  api.AssetResponseDto? info;
  Object? lastError;
  for (var attempt = 0; attempt < 20; attempt++) {
    try {
      info = await assetsApi.getAssetInfo(remoteAssetId);
      if (info != null) {
        return info;
      }
    } catch (error) {
      lastError = error;
    }
    await _pumpFor(tester, const Duration(seconds: 2));
  }

  fail('Asset $remoteAssetId was unavailable, last error: $lastError');
}

Finder _thumbnailTileForAsset(BaseAsset asset) {
  return find.byWidgetPredicate(
    (widget) => widget is ThumbnailTile && widget.asset != null && widget.asset!.refersToSameAsset(asset),
  );
}

Future<void> _openTimelineAsset(WidgetTester tester, BaseAsset asset) async {
  await pumpUntilFound(tester, find.byType(Timeline), timeout: const Duration(seconds: 60));
  await _dismissFeatureMessageIfVisible(tester);

  final tile = _thumbnailTileForAsset(asset);
  final scrollable = find.descendant(of: find.byType(Timeline), matching: find.byType(Scrollable));
  expect(scrollable, findsWidgets);

  for (var attempt = 0; attempt < 20; attempt++) {
    await _dismissFeatureMessageIfVisible(tester);
    if (tester.any(tile)) {
      await tester.ensureVisible(tile.first);
      await _pumpFor(tester, const Duration(milliseconds: 300));
      await tester.tap(tile.first, warnIfMissed: false);
      await _pumpFor(tester, const Duration(seconds: 2));
      if (tester.any(find.byType(AssetViewer))) {
        return;
      }
    }

    await tester.fling(scrollable.first, const Offset(0, -900), 1500);
    await _pumpFor(tester, const Duration(milliseconds: 700));
  }

  fail('Could not open timeline asset ${asset.id}');
}

Future<void> _dismissFeatureMessageIfVisible(WidgetTester tester) async {
  final skip = find.text('skip'.tr());
  for (var attempt = 0; attempt < 10; attempt++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (tester.any(skip)) {
      await tester.tap(skip.last, warnIfMissed: false);
      await _pumpFor(tester, const Duration(milliseconds: 500));
      return;
    }
  }
}

Future<RemoteAsset> _swipeViewerToNextRemoteImage(
  WidgetTester tester,
  ProviderContainer container,
  Offset gestureOffset,
) async {
  for (var attempt = 0; attempt < 8; attempt++) {
    final current = await _swipeViewerPage(tester, container, gestureOffset);
    if (current is RemoteAsset && current.isImage) {
      return current;
    }
  }

  final current = container.read(assetViewerProvider).currentAsset;
  fail('Expected viewer to reach a remote image after swipe, got ${current?.remoteId ?? current?.id ?? 'none'}');
}

Future<BaseAsset> _swipeViewerPage(WidgetTester tester, ProviderContainer container, Offset gestureOffset) async {
  final pageView = find.descendant(of: find.byType(AssetViewer), matching: find.byType(PageView));
  await pumpUntilFound(tester, pageView, timeout: const Duration(seconds: 30));
  final before = container.read(assetViewerProvider).currentAsset;
  await tester.timedDrag(pageView.first, gestureOffset, const Duration(milliseconds: 450));
  await _pumpUntil(tester, () {
    final current = container.read(assetViewerProvider).currentAsset;
    return current != null && (before == null || !current.refersToSameAsset(before));
  }, timeout: const Duration(seconds: 20));
  return container.read(assetViewerProvider).currentAsset!;
}

Future<void> _zoomViewerImage(WidgetTester tester, ProviderContainer container) async {
  final photoView = find.byType(PhotoView);
  await pumpUntilFound(tester, photoView, timeout: const Duration(seconds: 30));
  await tester.tap(photoView.first, warnIfMissed: false);
  await tester.pump(const Duration(milliseconds: 80));
  await tester.tap(photoView.first, warnIfMissed: false);
  await _pumpUntil(tester, () => container.read(assetViewerProvider).isZoomed, timeout: const Duration(seconds: 10));
}

Future<void> _backgroundApp(WidgetTester tester) async {
  for (final state in [AppLifecycleState.inactive, AppLifecycleState.hidden, AppLifecycleState.paused]) {
    tester.binding.handleAppLifecycleStateChanged(state);
    if (state != AppLifecycleState.paused) {
      await tester.pump();
    }
  }
}

Future<void> _foregroundApp(WidgetTester tester) async {
  for (final state in [AppLifecycleState.hidden, AppLifecycleState.inactive, AppLifecycleState.resumed]) {
    tester.binding.handleAppLifecycleStateChanged(state);
  }
  await tester.pump();
}

Future<VideoPlayerState> _waitForVideoState(
  WidgetTester tester,
  ProviderContainer container,
  String assetId,
  bool Function(VideoPlayerState) condition, {
  required Duration timeout,
}) async {
  final end = DateTime.now().add(timeout);
  while (true) {
    final state = container.read(videoPlayerProvider(assetId));
    if (condition(state)) {
      return state;
    }
    if (DateTime.now().isAfter(end)) {
      throw TimeoutException(
        'Timed out waiting for video state: status=${state.status.name}, '
        'position=${state.position.inMilliseconds}ms, duration=${state.duration.inMilliseconds}ms',
      );
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<Duration> _waitForVideoPositionAfter(
  WidgetTester tester,
  ProviderContainer container,
  String assetId,
  Duration position,
) async {
  final threshold = position + const Duration(milliseconds: 250);
  final state = await _waitForVideoState(
    tester,
    container,
    assetId,
    (state) => state.position >= threshold,
    timeout: const Duration(seconds: 30),
  );
  return state.position;
}

Finder _videoControlsFor(String assetId) =>
    find.byWidgetPredicate((widget) => widget is VideoControls && widget.videoPlayerName == assetId);

Future<void> _showVideoControls(WidgetTester tester, ProviderContainer container, String assetId) async {
  container.read(assetViewerProvider.notifier).setControls(true);
  await tester.pump();
  await pumpUntilFound(tester, _videoControlsFor(assetId), timeout: const Duration(seconds: 30));
}

Future<void> _tapVideoPlayPauseControl(WidgetTester tester, ProviderContainer container, String assetId) async {
  await _showVideoControls(tester, container, assetId);
  final button = find.descendant(of: _videoControlsFor(assetId), matching: find.byType(IconButton));
  await pumpUntilFound(tester, button, timeout: const Duration(seconds: 30));
  final iconButton = tester.widget<IconButton>(button.first);
  expect(iconButton.onPressed, isNotNull);
  iconButton.onPressed!();
  await _pumpFor(tester, const Duration(milliseconds: 500));
}

Future<void> _playVideoFromControls(WidgetTester tester, ProviderContainer container, String assetId) async {
  final state = container.read(videoPlayerProvider(assetId));
  if (state.status == VideoPlaybackStatus.paused || state.status == VideoPlaybackStatus.completed) {
    await _tapVideoPlayPauseControl(tester, container, assetId);
  }

  await _waitForVideoState(
    tester,
    container,
    assetId,
    (state) => state.status == VideoPlaybackStatus.playing || state.status == VideoPlaybackStatus.buffering,
    timeout: const Duration(seconds: 30),
  );
}

Future<void> _pauseVideoFromControls(WidgetTester tester, ProviderContainer container, String assetId) async {
  final state = container.read(videoPlayerProvider(assetId));
  if (state.status != VideoPlaybackStatus.paused) {
    await _tapVideoPlayPauseControl(tester, container, assetId);
  }

  await _waitForVideoState(
    tester,
    container,
    assetId,
    (state) => state.status == VideoPlaybackStatus.paused,
    timeout: const Duration(seconds: 30),
  );
}

Future<Duration> _seekVideoWithSlider(
  WidgetTester tester,
  ProviderContainer container,
  String assetId,
  double fraction,
) async {
  final loaded = await _waitForVideoState(
    tester,
    container,
    assetId,
    (state) => state.duration > Duration.zero,
    timeout: const Duration(seconds: 30),
  );
  final target = Duration(microseconds: (loaded.duration.inMicroseconds * fraction).round());

  await _showVideoControls(tester, container, assetId);
  final slider = find.descendant(of: _videoControlsFor(assetId), matching: find.byType(Slider));
  await pumpUntilFound(tester, slider, timeout: const Duration(seconds: 30));
  final rect = tester.getRect(slider.first);
  await tester.tapAt(Offset(rect.left + rect.width * fraction, rect.center.dy));
  await _waitForVideoState(
    tester,
    container,
    assetId,
    (state) => state.position >= target - const Duration(seconds: 1),
    timeout: const Duration(seconds: 10),
  );
  return target;
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

Future<void> _loadAuthenticatedApp(WidgetTester tester, {bool overrideCancellation = false}) async {
  await EasyLocalization.ensureInitialized();
  final (drift, _) = await Bootstrap.initDomain();
  await Store.clear();

  await _seedAuthenticatedStore();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        driftProvider.overrideWith(driftOverride(drift)),
        if (overrideCancellation) cancellationProvider.overrideWithValue(Completer()),
      ],
      child: const app.MainWidget(),
    ),
  );
  await EasyLocalization.ensureInitialized();
  await _pumpFor(tester, const Duration(milliseconds: 500));
  await _waitForAccessToken(tester);
  await _waitForCurrentUser(_email, tester);
  await _dismissFeatureMessageIfVisible(tester);
}

Future<(ProviderContainer, Drift)> _loadAuthenticatedSyncContainer() async {
  await EasyLocalization.ensureInitialized();
  final (drift, _) = await Bootstrap.initDomain();
  await Store.clear();
  await _seedAuthenticatedStore();
  return (
    ProviderContainer(
      overrides: [
        driftProvider.overrideWith(driftOverride(drift)),
        cancellationProvider.overrideWithValue(Completer()),
      ],
    ),
    drift,
  );
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

Future<String> _uploadGeneratedJpegAsSecondClient(
  String fileName,
  DateTime createdAt, {
  bool isFavorite = false,
  api.AssetVisibility? visibility,
}) async {
  final bytes = _generatedJpegBytes(createdAt.microsecondsSinceEpoch);
  final request = http.MultipartRequest('POST', Uri.parse('${Store.get(StoreKey.serverEndpoint)}/assets'))
    ..headers.addAll({
      ...ApiService.getRequestHeaders(),
      'Authorization': 'Bearer ${Store.get(StoreKey.accessToken)}',
      'x-immich-checksum': base64Encode(md5.convert(bytes).bytes),
    })
    ..fields.addAll({
      'fileCreatedAt': createdAt.toIso8601String(),
      'fileModifiedAt': createdAt.toIso8601String(),
      'filename': fileName,
      'isFavorite': isFavorite.toString(),
      if (visibility != null) 'visibility': visibility.toJson(),
    })
    ..files.add(http.MultipartFile.fromBytes('assetData', bytes, filename: fileName));

  final response = await http.Response.fromStream(await request.send());
  expect(response.statusCode, inInclusiveRange(200, 299), reason: response.body);
  final payload = jsonDecode(response.body) as Map<String, dynamic>;
  expect(payload['status'], 'created', reason: response.body);
  return payload['id'] as String;
}

Future<void> _deleteTestAssetBestEffort(api.AssetsApi assetsApi, String remoteAssetId) async {
  try {
    await assetsApi.deleteAssets(
      api.AssetBulkDeleteDto(ids: [remoteAssetId], force: const api.Optional.present(false)),
    );
  } catch (_) {
    // The asset may already be trashed or deleted by the test body.
  }
  try {
    await assetsApi.deleteAssets(api.AssetBulkDeleteDto(ids: [remoteAssetId], force: const api.Optional.present(true)));
  } catch (_) {
    // Best-effort cleanup for a test-created asset.
  }
}

Uint8List _generatedJpegBytes(int seed) {
  const onePixelJpeg =
      '/9j/2wBDAAgEBAQEBAUFBQUFBQYGBgYGBgYGBgYGBgYHBwcICAgHBwcGBgcHCAgICAkJCQgICAgJCQoKCgwMCwsODg4RERT/xABNAAEBAAAAAAAAAAAAAAAAAAAABwEBAQEAAAAAAAAAAAAAAAAAAAIDEAEAAAAAAAAAAAAAAAAAAAAAEQEAAAAAAAAAAAAAAAAAAAAA/8AAEQgAUAB4AwEiAAIRAAMRAP/aAAwDAQACEQMRAD8AvADRIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD/2Q==';
  final bytes = base64Decode(onePixelJpeg);
  final comment = utf8.encode('immich-e2e-generated-$seed');
  final commentLength = comment.length + 2;
  return Uint8List.fromList([
    bytes[0],
    bytes[1],
    0xff,
    0xfe,
    commentLength >> 8,
    commentLength & 0xff,
    ...comment,
    ...bytes.skip(2),
  ]);
}

Future<RemoteAsset> _waitForRemoteAssetState(
  WidgetTester tester,
  ProviderContainer container,
  String remoteAssetId,
  bool Function(RemoteAsset asset) matches, {
  required String reason,
}) async {
  RemoteAsset? latest;
  final end = DateTime.now().add(const Duration(seconds: 60));
  while (DateTime.now().isBefore(end)) {
    latest = await container.read(remoteAssetRepositoryProvider).get(remoteAssetId);
    if (latest != null && matches(latest)) {
      return latest;
    }
    await _pumpFor(tester, const Duration(milliseconds: 500));
  }

  fail('$reason; latest local asset=$latest');
}

Future<api.AssetResponseDto> _waitForAssetInfoState(
  WidgetTester tester,
  api.AssetsApi assetsApi,
  String remoteAssetId,
  bool Function(api.AssetResponseDto info) matches, {
  required String reason,
}) async {
  api.AssetResponseDto? latest;
  Object? lastError;
  final end = DateTime.now().add(const Duration(seconds: 60));
  while (DateTime.now().isBefore(end)) {
    try {
      latest = await assetsApi.getAssetInfo(remoteAssetId);
      if (latest != null && matches(latest)) {
        return latest;
      }
    } catch (error) {
      lastError = error;
    }
    await _pumpFor(tester, const Duration(milliseconds: 500));
  }

  fail('$reason; latest server asset=$latest; last error=$lastError');
}

Future<List<BaseAsset>> _expectTimelineAssetSet(
  WidgetTester tester,
  TimelineService timeline, {
  required Set<String> includes,
  required Set<String> excludes,
  required String reason,
}) async {
  var latest = const <BaseAsset>[];
  final end = DateTime.now().add(const Duration(seconds: 60));
  while (DateTime.now().isBefore(end)) {
    await _pumpFor(tester, const Duration(milliseconds: 300));
    latest = timeline.totalAssets == 0 ? const <BaseAsset>[] : await _loadAllTimelineAssets(timeline);
    final latestIds = _timelineAssetIds(latest);
    final hasExpected = includes.every(latestIds.contains);
    final hasNoUnexpected = excludes.every((assetId) => !latestIds.contains(assetId));
    if (hasExpected && hasNoUnexpected) {
      return latest;
    }
  }

  final latestIds = _timelineAssetIds(latest).toList()..sort();
  fail('$reason; latest timeline ids=${latestIds.join(', ')}');
}

Future<void> _waitForRemoteAssetGoneOrTrashed(
  WidgetTester tester,
  ProviderContainer container,
  String remoteAssetId, {
  required String reason,
}) async {
  RemoteAsset? latest;
  final end = DateTime.now().add(const Duration(seconds: 60));
  while (DateTime.now().isBefore(end)) {
    latest = await container.read(remoteAssetRepositoryProvider).get(remoteAssetId);
    if (latest == null || latest.isTrashed) {
      return;
    }
    await _pumpFor(tester, const Duration(milliseconds: 500));
  }

  fail('$reason; latest local asset=$latest');
}

Future<int> _remoteAssetRowCountById(Drift drift, String remoteAssetId) async {
  final row = await drift
      .customSelect(
        'SELECT COUNT(*) AS count FROM remote_asset_entity WHERE id = ?',
        variables: [Variable.withString(remoteAssetId)],
      )
      .getSingle();
  return row.read<int>('count');
}

Future<api.AssetResponseDto> _waitForAssetInfo(
  WidgetTester tester,
  api.AssetsApi assetsApi,
  String remoteAssetId,
) async {
  api.AssetResponseDto? info;
  Object? lastError;
  for (var attempt = 0; attempt < 20; attempt++) {
    try {
      info = await assetsApi.getAssetInfo(remoteAssetId);
      if (info != null && info.hasMetadata && info.exifInfo.orElse(null) != null) {
        return info;
      }
    } catch (error) {
      lastError = error;
    }
    await _pumpFor(tester, const Duration(seconds: 2));
  }

  if (info != null) {
    fail('Asset $remoteAssetId did not expose metadata: $info');
  }
  fail('Asset $remoteAssetId metadata was unavailable, last error: $lastError');
}

Future<List<TimeBucket>> _waitForTimelineBuckets(
  WidgetTester tester,
  TimelineService timeline, {
  required int minAssets,
}) async {
  var latest = const <Bucket>[];
  Object? streamError;
  final subscription = timeline.watchBuckets().listen((buckets) {
    latest = buckets;
  }, onError: (error) => streamError = error);

  try {
    final end = DateTime.now().add(const Duration(minutes: 2));
    while (DateTime.now().isBefore(end)) {
      if (streamError != null) {
        fail('Timeline bucket stream failed: $streamError');
      }

      final timeBuckets = latest.whereType<TimeBucket>().toList();
      final totalFromBuckets = latest.fold<int>(0, (total, bucket) => total + bucket.assetCount);
      if (latest.isNotEmpty &&
          timeBuckets.length == latest.length &&
          timeBuckets.length >= 2 &&
          totalFromBuckets >= minAssets &&
          timeline.totalAssets == totalFromBuckets) {
        return timeBuckets;
      }
      await _pumpFor(tester, const Duration(milliseconds: 500));
    }

    final totalFromBuckets = latest.fold<int>(0, (total, bucket) => total + bucket.assetCount);
    fail(
      'Timeline did not reach $minAssets assets and two time buckets; '
      'bucket total=$totalFromBuckets, service total=${timeline.totalAssets}, buckets=${latest.length}',
    );
  } finally {
    await subscription.cancel();
  }
}

int _timelineCountForPage(int totalAssets, int offset) {
  final remaining = totalAssets - offset;
  if (remaining <= 0) {
    return 0;
  }
  return remaining < _timelinePageSize ? remaining : _timelinePageSize;
}

Set<String> _timelineAssetIds(Iterable<BaseAsset> assets) {
  return assets.map(_timelineAssetId).toSet();
}

String _timelineAssetId(BaseAsset asset) {
  return asset.remoteId ??
      asset.localId ??
      '${asset.name}:${asset.createdAt.toUtc().microsecondsSinceEpoch}:${asset.checksum ?? ''}';
}

void _expectTimelineBucketsDescending(List<TimeBucket> buckets) {
  for (var i = 1; i < buckets.length; i++) {
    expect(buckets[i].date.isAfter(buckets[i - 1].date), isFalse);
  }
}

bool _spansMultipleMonths(List<TimeBucket> buckets) {
  return buckets.map((bucket) => '${bucket.date.year}-${bucket.date.month}').toSet().length > 1;
}

void _expectTimelineAssetsDescending(List<BaseAsset> assets) {
  for (var i = 1; i < assets.length; i++) {
    expect(assets[i].createdAt.isAfter(assets[i - 1].createdAt), isFalse);
  }
}

bool _hasSharedTimestamp(List<BaseAsset> assets) {
  final seen = <int>{};
  for (final asset in assets) {
    final timestamp = asset.createdAt.toUtc().microsecondsSinceEpoch;
    if (!seen.add(timestamp)) {
      return true;
    }
  }
  return false;
}

void _expectUtcDateTimeParts(DateTime value, int year, int month, int day, int hour, int minute) {
  final utc = value.toUtc();
  expect(utc.year, year);
  expect(utc.month, month);
  expect(utc.day, day);
  expect(utc.hour, hour);
  expect(utc.minute, minute);
}

void _expectDateTimesClose(DateTime actual, DateTime expected, Duration tolerance) {
  final delta = actual.toUtc().difference(expected.toUtc()).abs();
  expect(delta, lessThanOrEqualTo(tolerance));
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

void _expectAndroidMotionHeic(List<int> bodyBytes) {
  expect(bodyBytes.length, greaterThan(64));
  final prefixLength = bodyBytes.length < 2 * 1024 * 1024 ? bodyBytes.length : 2 * 1024 * 1024;
  final ranges = parseMotionPhotoRanges(Uint8List.fromList(bodyBytes.take(prefixLength).toList()), bodyBytes.length);
  expect(ranges, isNotNull);
  final motionOffset = ranges!.motionOffset;
  expect(motionOffset + 12, lessThanOrEqualTo(bodyBytes.length));
  expect(ascii.decode(bodyBytes.sublist(motionOffset + 4, motionOffset + 8), allowInvalid: true), 'ftyp');
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
