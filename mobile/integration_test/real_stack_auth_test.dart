import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:background_downloader/background_downloader.dart';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:immich_mobile/constants/constants.dart';
import 'package:immich_mobile/constants/enums.dart';
import 'package:immich_mobile/domain/models/album/album.model.dart';
import 'package:immich_mobile/domain/models/album/local_album.model.dart';
import 'package:immich_mobile/domain/models/asset/base_asset.model.dart';
import 'package:immich_mobile/domain/models/events.model.dart';
import 'package:immich_mobile/domain/models/exif.model.dart';
import 'package:immich_mobile/domain/models/person.model.dart';
import 'package:immich_mobile/domain/models/settings_key.dart';
import 'package:immich_mobile/domain/models/store.model.dart';
import 'package:immich_mobile/domain/models/sync_event.model.dart';
import 'package:immich_mobile/domain/models/timeline.model.dart';
import 'package:immich_mobile/domain/models/user.model.dart';
import 'package:immich_mobile/domain/services/asset.service.dart';
import 'package:immich_mobile/domain/services/background_worker.service.dart';
import 'package:immich_mobile/domain/services/people.service.dart';
import 'package:immich_mobile/domain/services/search.service.dart';
import 'package:immich_mobile/domain/services/timeline.service.dart';
import 'package:immich_mobile/domain/utils/event_stream.dart';
import 'package:immich_mobile/entities/store.entity.dart';
import 'package:immich_mobile/infrastructure/repositories/db.repository.dart';
import 'package:immich_mobile/infrastructure/repositories/local_album.repository.dart';
import 'package:immich_mobile/infrastructure/repositories/settings.repository.dart';
import 'package:immich_mobile/infrastructure/repositories/storage.repository.dart';
import 'package:immich_mobile/main.dart' as app;
import 'package:immich_mobile/models/search/search_filter.model.dart';
import 'package:immich_mobile/pages/backup/drift_backup.page.dart';
import 'package:immich_mobile/pages/backup/drift_backup_album_selection.page.dart';
import 'package:immich_mobile/pages/backup/drift_backup_asset_detail.page.dart';
import 'package:immich_mobile/pages/backup/drift_backup_options.page.dart';
import 'package:immich_mobile/pages/backup/drift_upload_detail.page.dart';
import 'package:immich_mobile/pages/library/locked/pin_auth.page.dart';
import 'package:immich_mobile/pages/login/login.page.dart';
import 'package:immich_mobile/presentation/pages/dev/main_timeline.page.dart';
import 'package:immich_mobile/presentation/pages/drift_album.page.dart';
import 'package:immich_mobile/presentation/pages/drift_archive.page.dart';
import 'package:immich_mobile/presentation/pages/drift_asset_selection_timeline.page.dart';
import 'package:immich_mobile/presentation/pages/drift_favorite.page.dart';
import 'package:immich_mobile/presentation/pages/drift_library.page.dart';
import 'package:immich_mobile/presentation/pages/drift_locked_folder.page.dart';
import 'package:immich_mobile/presentation/pages/drift_remote_album.page.dart';
import 'package:immich_mobile/presentation/pages/search/drift_search.page.dart';
import 'package:immich_mobile/presentation/widgets/album/album_selector.widget.dart';
import 'package:immich_mobile/presentation/widgets/asset_viewer/asset_viewer.page.dart';
import 'package:immich_mobile/presentation/widgets/asset_viewer/video_viewer.widget.dart';
import 'package:immich_mobile/presentation/widgets/backup/backup_toggle_button.widget.dart';
import 'package:immich_mobile/presentation/widgets/bottom_sheet/archive_bottom_sheet.widget.dart';
import 'package:immich_mobile/presentation/widgets/bottom_sheet/favorite_bottom_sheet.widget.dart';
import 'package:immich_mobile/presentation/widgets/bottom_sheet/general_bottom_sheet.widget.dart';
import 'package:immich_mobile/presentation/widgets/bottom_sheet/remote_album_bottom_sheet.widget.dart';
import 'package:immich_mobile/presentation/widgets/images/thumbnail_tile.widget.dart';
import 'package:immich_mobile/presentation/widgets/timeline/header.widget.dart';
import 'package:immich_mobile/presentation/widgets/timeline/timeline.widget.dart';
import 'package:immich_mobile/providers/api.provider.dart';
import 'package:immich_mobile/providers/asset_viewer/asset_viewer.provider.dart';
import 'package:immich_mobile/providers/asset_viewer/video_player_provider.dart';
import 'package:immich_mobile/providers/background_sync.provider.dart';
import 'package:immich_mobile/providers/backup/backup_album.provider.dart';
import 'package:immich_mobile/providers/backup/drift_backup.provider.dart';
import 'package:immich_mobile/providers/gallery_permission.provider.dart';
import 'package:immich_mobile/providers/infrastructure/album.provider.dart';
import 'package:immich_mobile/providers/infrastructure/asset.provider.dart';
import 'package:immich_mobile/providers/infrastructure/cancel.provider.dart';
import 'package:immich_mobile/providers/infrastructure/db.provider.dart';
import 'package:immich_mobile/providers/infrastructure/people.provider.dart';
import 'package:immich_mobile/providers/infrastructure/platform.provider.dart';
import 'package:immich_mobile/providers/infrastructure/search.provider.dart';
import 'package:immich_mobile/providers/infrastructure/sync.provider.dart';
import 'package:immich_mobile/providers/infrastructure/timeline.provider.dart';
import 'package:immich_mobile/providers/tab.provider.dart';
import 'package:immich_mobile/providers/timeline/multiselect.provider.dart';
import 'package:immich_mobile/providers/websocket.provider.dart';
import 'package:immich_mobile/repositories/asset_api.repository.dart';
import 'package:immich_mobile/repositories/asset_media.repository.dart';
import 'package:immich_mobile/repositories/auth_api.repository.dart';
import 'package:immich_mobile/repositories/download.repository.dart';
import 'package:immich_mobile/repositories/file_media.repository.dart';
import 'package:immich_mobile/routing/router.dart';
import 'package:immich_mobile/services/api.service.dart';
import 'package:immich_mobile/services/background_upload.service.dart';
import 'package:immich_mobile/services/download.service.dart';
import 'package:immich_mobile/services/foreground_upload.service.dart';
import 'package:immich_mobile/utils/bootstrap.dart';
import 'package:immich_mobile/utils/option.dart';
import 'package:immich_mobile/utils/semver.dart';
import 'package:immich_mobile/widgets/asset_viewer/video_controls.dart';
import 'package:immich_mobile/widgets/backup/drift_album_info_list_tile.dart';
import 'package:immich_mobile/widgets/common/selection_sliver_app_bar.dart';
import 'package:immich_mobile/widgets/photo_view/photo_view.dart';
import 'package:immich_mobile/widgets/settings/setting_list_tile.dart';
import 'package:openapi/api.dart' as api;
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart' hide AssetType;

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
const _backgroundBackupAssetName = String.fromEnvironment(
  'IMMICH_E2E_BACKGROUND_BACKUP_ASSET_NAME',
  defaultValue: 'immich-e2e-background-031.jpg',
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
const _serverRestartReadyMarker = 'MOB-REAL-030:READY_FOR_SERVER_RESTART';
const _backgroundWorkerTriggerMarker = 'MOB-REAL-031-A:TRIGGER_ANDROID_BACKGROUND_WORKER';
const _upgradeStage = String.fromEnvironment('IMMICH_E2E_UPGRADE_STAGE', defaultValue: 'single');
const _upgradeSnapshotFilename = 'mob-real-032-upgrade-snapshot.json';
const _upgradeExpectedBackupSettings = <String, Object>{
  'backupEnabled': true,
  'backupUseCellularForPhotos': true,
  'backupUseCellularForVideos': true,
  'backupRequireCharging': true,
  'backupTriggerDelay': 17,
};
const _backupAlbumSelectionCameraAlbum = 'Camera';
const _backupAlbumSelectionScreenshotsAlbum = 'Screenshots';
const _backupAlbumSelectionDownloadAlbum = 'Download';
const _backupAlbumSelectionDuplicateAlbum = 'ImmichE2ESameName035';
const _backupSettingsAlbumName = String.fromEnvironment(
  'IMMICH_E2E_BACKUP_SETTINGS_ALBUM_NAME',
  defaultValue: 'ImmichE2EBackupSettings036',
);
const _backupSettingsAssetName = String.fromEnvironment(
  'IMMICH_E2E_BACKUP_SETTINGS_ASSET_NAME',
  defaultValue: 'immich-e2e-backup-settings-036.jpg',
);
const _uploadQueueAlbumName = String.fromEnvironment(
  'IMMICH_E2E_UPLOAD_QUEUE_ALBUM_NAME',
  defaultValue: 'ImmichE2EUploadQueue037',
);
const _uploadQueueSuccessAssetName = String.fromEnvironment(
  'IMMICH_E2E_UPLOAD_QUEUE_SUCCESS_ASSET_NAME',
  defaultValue: 'immich-e2e-upload-queue-037-success.jpg',
);
const _uploadQueueRetryAssetName = String.fromEnvironment(
  'IMMICH_E2E_UPLOAD_QUEUE_RETRY_ASSET_NAME',
  defaultValue: 'immich-e2e-upload-queue-037-retry.jpg',
);
const _multiSelectMinimumAssetCount = int.fromEnvironment('IMMICH_E2E_MULTISELECT_MIN_ASSET_COUNT', defaultValue: 60);
const _multiSelectRemoteSeedPrefix = String.fromEnvironment(
  'IMMICH_E2E_MULTISELECT_REMOTE_SEED_PREFIX',
  defaultValue: 'immich-e2e-multiselect-038-remote-',
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

    _realStackSessionTest(
      'MOB-REAL-024-$_caseSuffix',
      'keeps album membership cover and sync idempotent across clients',
      (tester) async {
        await _loadAuthenticatedApp(tester, overrideCancellation: true);
        final container = _containerOfApp(tester);
        final drift = container.read(driftProvider);
        final apiService = container.read(apiServiceProvider);
        final albumsApi = apiService.albumsApi;
        final assetsApi = apiService.assetsApi;
        final uploadedRemoteIds = <String>[];
        String? albumId;

        addTearDown(() async {
          final id = albumId;
          if (id != null) {
            await _deleteAlbumBestEffort(albumsApi, id);
          }
          for (final assetId in uploadedRemoteIds) {
            await _deleteTestAssetBestEffort(assetsApi, assetId);
          }
        });

        await container.read(syncApiRepositoryProvider).deleteSyncAck(_allReplayableSyncAckTypes);
        await Store.delete(StoreKey.syncMigrationStatus);
        await container.read(syncStreamRepositoryProvider).reset();
        final baselineSyncSuccess = await container.read(syncStreamServiceProvider).sync();
        expect(baselineSyncSuccess, isTrue);

        final baseCreatedAt = DateTime.now().toUtc();
        final assetIds = <String>[];
        for (var index = 0; index < 3; index++) {
          final createdAt = baseCreatedAt.subtract(Duration(seconds: 3 - index));
          final assetId = await _uploadGeneratedJpegAsSecondClient(
            'immich-e2e-album-024-$index-${createdAt.microsecondsSinceEpoch}.jpg',
            createdAt,
          );
          uploadedRemoteIds.add(assetId);
          assetIds.add(assetId);
        }

        final uploadSyncSuccess = await container.read(syncStreamServiceProvider).sync();
        expect(uploadSyncSuccess, isTrue);
        for (final assetId in assetIds) {
          await _waitForRemoteAssetState(
            tester,
            container,
            assetId,
            (asset) => asset.visibility == AssetVisibility.timeline && !asset.isTrashed,
            reason: 'Expected uploaded album candidate $assetId to sync locally',
          );
          expect(await _remoteAssetRowCountById(drift, assetId), 1);
        }

        final albumName = 'immich-e2e-album-024-${baseCreatedAt.microsecondsSinceEpoch}';
        final createdAlbum = await albumsApi.createAlbum(
          api.CreateAlbumDto(albumName: albumName, assetIds: api.Optional.present(assetIds.take(2).toList())),
        );
        expect(createdAlbum, isNotNull);
        albumId = createdAlbum!.id;

        await _waitForAlbumInfoState(
          tester,
          albumsApi,
          albumId,
          (album) => album.albumName == albumName && album.assetCount == 2,
          reason: 'Expected created album to contain the first two assets on the server',
        );

        final duplicateAdd = await albumsApi.addAssetsToAlbum(albumId, api.BulkIdsDto(ids: assetIds.take(2).toList()));
        _expectBulkResultsAcceptedOrDuplicate(
          duplicateAdd,
          assetIds.take(2).toSet(),
          reason: 'Repeated album add should be idempotent for existing assets',
        );
        await _waitForAlbumInfoState(
          tester,
          albumsApi,
          albumId,
          (album) => album.assetCount == 2,
          reason: 'Repeated album add should not duplicate membership on the server',
        );

        final addThird = await albumsApi.addAssetsToAlbum(albumId, api.BulkIdsDto(ids: [assetIds[2]]));
        _expectBulkSuccess(addThird, {assetIds[2]}, reason: 'Expected third asset to be added to album');

        await _waitForAlbumInfoState(
          tester,
          albumsApi,
          albumId,
          (album) => album.assetCount == 3,
          reason: 'Expected album to contain three assets after adding the third asset',
        );

        final coverUpdate = await albumsApi.updateAlbumInfo(
          albumId,
          api.UpdateAlbumDto(albumThumbnailAssetId: api.Optional.present(assetIds[2])),
        );
        expect(coverUpdate, isNotNull);
        expect(coverUpdate!.albumThumbnailAssetId, assetIds[2]);

        final removeSecond = await albumsApi.removeAssetFromAlbum(albumId, api.BulkIdsDto(ids: [assetIds[1]]));
        _expectBulkSuccess(removeSecond, {assetIds[1]}, reason: 'Expected second asset to be removed from album');

        await _waitForAlbumInfoState(
          tester,
          albumsApi,
          albumId,
          (album) => album.assetCount == 2 && album.albumThumbnailAssetId == assetIds[2],
          reason: 'Expected removed asset to leave album count at two while preserving cover',
        );
        final removedAssetInfo = await assetsApi.getAssetInfo(assetIds[1]);
        expect(removedAssetInfo, isNotNull);
        expect(removedAssetInfo!.isTrashed, isFalse, reason: 'Removing from album must not trash the source asset');

        final albumSyncSuccess = await container.read(syncStreamServiceProvider).sync();
        expect(albumSyncSuccess, isTrue);

        await _waitForRemoteAlbumState(
          tester,
          container,
          albumId,
          (album) => album.name == albumName && album.assetCount == 2 && album.thumbnailAssetId == assetIds[2],
          reason: 'Expected local album to converge after cross-client album changes',
        );
        await _waitForRemoteAlbumAssetIds(
          tester,
          container,
          albumId,
          includes: {assetIds[0], assetIds[2]},
          excludes: {assetIds[1]},
          reason: 'Expected local album membership to include first and third assets only',
        );
        expect(await _remoteAlbumRowCountById(drift, albumId), 1);
        expect(await _remoteAlbumAssetRowCountByAlbumId(drift, albumId), 2);
        expect(await _remoteAssetRowCountById(drift, assetIds[1]), 1);

        final rowsAfterAlbumSync = await _remoteSyncRowCounts(drift);
        final secondSyncSuccess = await container.read(syncStreamServiceProvider).sync();
        expect(secondSyncSuccess, isTrue);
        expect(
          await _remoteSyncRowCounts(drift),
          rowsAfterAlbumSync,
          reason: 'Second sync after album changes should not duplicate local rows',
        );
      },
    );

    _realStackSessionTest('MOB-REAL-025-$_caseSuffix', 'matches server search results across text and filters', (
      tester,
    ) async {
      await _loadAuthenticatedApp(tester, overrideCancellation: true);
      final container = _containerOfApp(tester);
      final apiService = container.read(apiServiceProvider);
      final assetsApi = apiService.assetsApi;
      final searchApi = apiService.searchApi;
      final searchService = container.read(searchServiceProvider);
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

      final runToken = DateTime.now().toUtc().microsecondsSinceEpoch.toString();
      final sharedNeedle = 'search-025-$runToken';
      const cameraMake = 'ImmichE2E';
      const cameraModel = 'Search025';
      final baseCreatedAt = DateTime.utc(2026, 1, 25, 12);
      final timelineFavoriteCreatedAt = baseCreatedAt;
      final timelinePlainCreatedAt = baseCreatedAt.subtract(const Duration(days: 10));
      final archiveFavoriteCreatedAt = baseCreatedAt.add(const Duration(minutes: 1));
      final hiddenCreatedAt = baseCreatedAt.add(const Duration(minutes: 2));

      final timelineFavoriteName = 'immich-e2e-$sharedNeedle-snow-東京-favorite.jpg';
      final timelineFavoriteId = await _uploadGeneratedJpegAsSecondClient(
        timelineFavoriteName,
        timelineFavoriteCreatedAt,
        isFavorite: true,
        sourceMetadata: {'device_make': cameraMake, 'device_model': cameraModel, 'width': 64, 'height': 64},
      );
      uploadedRemoteIds.add(timelineFavoriteId);

      final timelinePlainId = await _uploadGeneratedJpegAsSecondClient(
        'immich-e2e-$sharedNeedle-canyon-plain.jpg',
        timelinePlainCreatedAt,
        sourceMetadata: {'device_make': cameraMake, 'device_model': 'Search025Plain', 'width': 64, 'height': 64},
      );
      uploadedRemoteIds.add(timelinePlainId);

      final archiveFavoriteId = await _uploadGeneratedJpegAsSecondClient(
        'immich-e2e-$sharedNeedle-snow-archive.jpg',
        archiveFavoriteCreatedAt,
        isFavorite: true,
        visibility: api.AssetVisibility.archive,
        sourceMetadata: {'device_make': cameraMake, 'device_model': cameraModel, 'width': 64, 'height': 64},
      );
      uploadedRemoteIds.add(archiveFavoriteId);

      final hiddenId = await _uploadGeneratedJpegAsSecondClient(
        'immich-e2e-$sharedNeedle-snow-hidden.jpg',
        hiddenCreatedAt,
        visibility: api.AssetVisibility.hidden,
        sourceMetadata: {'device_make': cameraMake, 'device_model': cameraModel, 'width': 64, 'height': 64},
      );
      uploadedRemoteIds.add(hiddenId);

      final uploadSyncSuccess = await container.read(syncStreamServiceProvider).sync();
      expect(uploadSyncSuccess, isTrue);

      await _waitForRemoteAssetState(
        tester,
        container,
        timelineFavoriteId,
        (asset) => asset.visibility == AssetVisibility.timeline && asset.isFavorite && !asset.isTrashed,
        reason: 'Expected searchable favorite asset to sync locally',
      );
      await _waitForRemoteAssetState(
        tester,
        container,
        timelinePlainId,
        (asset) => asset.visibility == AssetVisibility.timeline && !asset.isFavorite && !asset.isTrashed,
        reason: 'Expected searchable plain asset to sync locally',
      );
      await _waitForRemoteAssetState(
        tester,
        container,
        archiveFavoriteId,
        (asset) => asset.visibility == AssetVisibility.archive && asset.isFavorite && !asset.isTrashed,
        reason: 'Expected searchable archive asset to sync locally',
      );
      await _waitForRemoteAssetState(
        tester,
        container,
        hiddenId,
        (asset) => asset.visibility == AssetVisibility.hidden && !asset.isTrashed,
        reason: 'Expected searchable hidden asset to sync locally',
      );

      final exactFilter = _searchFilter(filename: timelineFavoriteName, mediaType: AssetType.image);
      final exactServer = await _waitForServerSearchResponse(
        tester,
        searchApi,
        _metadataSearchDto(
          filename: timelineFavoriteName,
          type: api.AssetTypeEnum.IMAGE,
          visibility: api.AssetVisibility.timeline,
        ),
        (response) => _serverSearchAssetIds(response).contains(timelineFavoriteId),
        reason: 'Expected exact filename search to find the timeline favorite asset',
      );
      final exactAppIds = await _waitForSearchServiceAssetIds(
        tester,
        searchService,
        exactFilter,
        (ids) => ids.contains(timelineFavoriteId),
        reason: 'Expected app exact filename search to find the same asset',
      );
      expect(exactAppIds, _serverSearchAssetIds(exactServer));
      expect(exactAppIds, {timelineFavoriteId});

      final partialFilter = _searchFilter(filename: sharedNeedle, mediaType: AssetType.image);
      final partialServer = await _waitForServerSearchResponse(
        tester,
        searchApi,
        _metadataSearchDto(
          filename: sharedNeedle,
          type: api.AssetTypeEnum.IMAGE,
          visibility: api.AssetVisibility.timeline,
        ),
        (response) {
          final ids = _serverSearchAssetIds(response);
          return ids.containsAll({timelineFavoriteId, timelinePlainId}) &&
              !ids.contains(archiveFavoriteId) &&
              !ids.contains(hiddenId);
        },
        reason: 'Expected partial filename search to include timeline assets and exclude archive/hidden assets',
      );
      final partialAppIds = await _waitForSearchServiceAssetIds(
        tester,
        searchService,
        partialFilter,
        (ids) =>
            ids.containsAll({timelineFavoriteId, timelinePlainId}) &&
            !ids.contains(archiveFavoriteId) &&
            !ids.contains(hiddenId),
        reason: 'Expected app partial search to mirror server timeline visibility',
      );
      expect(partialAppIds, _serverSearchAssetIds(partialServer));

      final unicodeNeedle = '$sharedNeedle-snow-東京';
      final unicodeFilter = _searchFilter(filename: unicodeNeedle, mediaType: AssetType.image);
      final unicodeServer = await _waitForServerSearchResponse(
        tester,
        searchApi,
        _metadataSearchDto(
          filename: unicodeNeedle,
          type: api.AssetTypeEnum.IMAGE,
          visibility: api.AssetVisibility.timeline,
        ),
        (response) => _serverSearchAssetIds(response).contains(timelineFavoriteId),
        reason: 'Expected Unicode filename search to find the seeded asset',
      );
      final unicodeAppIds = await _waitForSearchServiceAssetIds(
        tester,
        searchService,
        unicodeFilter,
        (ids) => ids.contains(timelineFavoriteId),
        reason: 'Expected app Unicode search to mirror server results',
      );
      expect(unicodeAppIds, _serverSearchAssetIds(unicodeServer));
      expect(unicodeAppIds, contains(timelineFavoriteId));

      final takenAfter = baseCreatedAt.subtract(const Duration(minutes: 1));
      final takenBefore = baseCreatedAt.add(const Duration(minutes: 3));
      final timelineComboFilter = _searchFilter(
        filename: sharedNeedle,
        takenAfter: takenAfter,
        takenBefore: takenBefore,
        isFavorite: true,
        mediaType: AssetType.image,
        make: cameraMake,
        model: cameraModel,
      );
      final timelineComboServer = await _waitForServerSearchResponse(
        tester,
        searchApi,
        _metadataSearchDto(
          filename: sharedNeedle,
          takenAfter: takenAfter,
          takenBefore: takenBefore,
          isFavorite: true,
          type: api.AssetTypeEnum.IMAGE,
          visibility: api.AssetVisibility.timeline,
          make: cameraMake,
          model: cameraModel,
        ),
        (response) => _serverSearchAssetIds(response).contains(timelineFavoriteId),
        reason: 'Expected combined timeline filters to find only the matching favorite image',
      );
      final timelineComboAppIds = await _waitForSearchServiceAssetIds(
        tester,
        searchService,
        timelineComboFilter,
        (ids) => ids.contains(timelineFavoriteId),
        reason: 'Expected app combined timeline search to mirror server results',
      );
      expect(timelineComboAppIds, _serverSearchAssetIds(timelineComboServer));
      expect(timelineComboAppIds, {timelineFavoriteId});

      final archiveComboFilter = _searchFilter(
        filename: sharedNeedle,
        takenAfter: takenAfter,
        takenBefore: takenBefore,
        isFavorite: true,
        isArchive: true,
        mediaType: AssetType.image,
        make: cameraMake,
        model: cameraModel,
      );
      final archiveComboServer = await _waitForServerSearchResponse(
        tester,
        searchApi,
        _metadataSearchDto(
          filename: sharedNeedle,
          takenAfter: takenAfter,
          takenBefore: takenBefore,
          isFavorite: true,
          type: api.AssetTypeEnum.IMAGE,
          visibility: api.AssetVisibility.archive,
          make: cameraMake,
          model: cameraModel,
        ),
        (response) => _serverSearchAssetIds(response).contains(archiveFavoriteId),
        reason: 'Expected combined archive filters to find the archived favorite image',
      );
      final archiveComboAppIds = await _waitForSearchServiceAssetIds(
        tester,
        searchService,
        archiveComboFilter,
        (ids) => ids.contains(archiveFavoriteId),
        reason: 'Expected app archive-filtered search to mirror server results',
      );
      expect(archiveComboAppIds, _serverSearchAssetIds(archiveComboServer));
      expect(archiveComboAppIds, {archiveFavoriteId});

      final hiddenServer = await _waitForServerSearchResponse(
        tester,
        searchApi,
        _metadataSearchDto(
          filename: sharedNeedle,
          type: api.AssetTypeEnum.IMAGE,
          visibility: api.AssetVisibility.hidden,
        ),
        (response) => _serverSearchAssetIds(response).contains(hiddenId),
        reason: 'Expected explicit hidden search to prove the hidden asset exists',
      );
      expect(_serverSearchAssetIds(hiddenServer), contains(hiddenId));
      expect(partialAppIds, isNot(contains(hiddenId)), reason: 'Timeline search must not leak hidden assets');

      final emptyFilter = _searchFilter(filename: 'immich-e2e-$sharedNeedle-no-result', mediaType: AssetType.image);
      final emptyServer = await _waitForServerSearchResponse(
        tester,
        searchApi,
        _metadataSearchDto(
          filename: 'immich-e2e-$sharedNeedle-no-result',
          type: api.AssetTypeEnum.IMAGE,
          visibility: api.AssetVisibility.timeline,
        ),
        (response) => response.assets.total == 0 && response.assets.items.isEmpty,
        reason: 'Expected no-result search to return an empty server page',
      );
      expect(_serverSearchAssetIds(emptyServer), isEmpty);
      final emptyAppIds = await _waitForSearchServiceAssetIds(
        tester,
        searchService,
        emptyFilter,
        (ids) => ids.isEmpty,
        reason: 'Expected app no-result search to return no assets',
      );
      expect(emptyAppIds, isEmpty);

      final pageOne = await _waitForServerSearchResponse(
        tester,
        searchApi,
        _metadataSearchDto(
          filename: sharedNeedle,
          page: 1,
          size: 1,
          type: api.AssetTypeEnum.IMAGE,
          visibility: api.AssetVisibility.timeline,
        ),
        (response) => response.assets.total >= 2 && response.assets.items.length == 1,
        reason: 'Expected first server search page to contain one timeline asset',
      );
      final pageTwo = await _waitForServerSearchResponse(
        tester,
        searchApi,
        _metadataSearchDto(
          filename: sharedNeedle,
          page: 2,
          size: 1,
          type: api.AssetTypeEnum.IMAGE,
          visibility: api.AssetVisibility.timeline,
        ),
        (response) => response.assets.total == pageOne.assets.total && response.assets.items.length == 1,
        reason: 'Expected second server search page to be stable',
      );
      expect(pageOne.assets.nextPage, '2');
      expect(_serverSearchAssetIds(pageOne).intersection(_serverSearchAssetIds(pageTwo)), isEmpty);
      expect(_serverSearchAssetIds(pageOne).union(_serverSearchAssetIds(pageTwo)), {
        timelineFavoriteId,
        timelinePlainId,
      });
    });

    _realStackSessionTest('MOB-REAL-026-$_caseSuffix', 'shows synced people and places for processed assets', (
      tester,
    ) async {
      await _loadAuthenticatedApp(tester, overrideCancellation: true);
      final container = _containerOfApp(tester);
      final drift = container.read(driftProvider);
      final apiService = container.read(apiServiceProvider);
      final assetsApi = apiService.assetsApi;
      final peopleApi = apiService.peopleApi;
      final peopleService = container.read(driftPeopleServiceProvider);
      final assetService = container.read(assetServiceProvider);
      final uploadedRemoteIds = <String>[];
      String? personId;

      addTearDown(() async {
        final id = personId;
        if (id != null) {
          await _deletePersonBestEffort(peopleApi, id);
        }
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

      final runToken = DateTime.now().toUtc().microsecondsSinceEpoch.toString();
      final personName = 'Immich E2E Person 026 $runToken';
      final city = 'Immich E2E City 026 $runToken';
      const state = 'Immich E2E State';
      const country = 'Immich E2E Country';
      final baseCreatedAt = DateTime.utc(2026, 1, 26, 12);

      for (var index = 0; index < 3; index++) {
        final createdAt = baseCreatedAt.add(Duration(minutes: index));
        final assetId = await _uploadGeneratedJpegAsSecondClient(
          'immich-e2e-people-places-026-$runToken-$index.jpg',
          createdAt,
          sourceMetadata: {
            'device_make': 'ImmichE2E',
            'device_model': 'PeoplePlaces026',
            'width': 64,
            'height': 64,
            'latitude': 31.143680555555555 + index / 1000,
            'longitude': 121.65776944444445 + index / 1000,
            'country': country,
            'state': state,
            'city': city,
          },
        );
        uploadedRemoteIds.add(assetId);
      }

      final createdPerson = await peopleApi.createPerson(
        api.PersonCreateDto(
          name: api.Optional.present(personName),
          isHidden: const api.Optional.present(false),
          isFavorite: const api.Optional.present(false),
          birthDate: const api.Optional.present(null),
          color: const api.Optional.present(null),
        ),
      );
      expect(createdPerson, isNotNull);
      personId = createdPerson!.id;

      for (var index = 0; index < uploadedRemoteIds.length; index++) {
        await _createFaceAsSecondClient(
          assetId: uploadedRemoteIds[index],
          personId: personId,
          x: 6 + index,
          y: 7 + index,
          width: 24,
          height: 28,
          imageWidth: 64,
          imageHeight: 64,
        );
      }

      final serverFaces = await _waitForServerFaces(
        tester,
        uploadedRemoteIds.first,
        (faces) => faces.any(
          (face) =>
              face['person'] is Map &&
              (face['person'] as Map)['id'] == personId &&
              face['boundingBoxX1'] == 6 &&
              face['boundingBoxY1'] == 7 &&
              face['sourceType'] == 'manual',
        ),
        reason: 'Expected server faces endpoint to link the test person and first asset',
      );
      expect(serverFaces, isNotEmpty);

      final serverPlaceAssets = await _waitForServerPlaces(
        tester,
        (assets) => assets.any(
          (asset) => uploadedRemoteIds.contains(asset.id) && asset.exifInfo.orElse(null)?.city.orElse(null) == city,
        ),
        reason: 'Expected server places endpoint to include the uploaded city asset',
      );
      expect(serverPlaceAssets.map((asset) => asset.exifInfo.orElse(null)?.city.orElse(null)), contains(city));

      final syncSuccess = await container.read(syncStreamServiceProvider).sync();
      expect(syncSuccess, isTrue);

      final localAsset = await _waitForRemoteAssetState(
        tester,
        container,
        uploadedRemoteIds.first,
        (asset) => asset.visibility == AssetVisibility.timeline && !asset.isTrashed,
        reason: 'Expected people/places asset to sync locally',
      );
      final localExif = await _waitForRemoteExifState(
        tester,
        assetService,
        localAsset,
        (exif) => exif.city == city && exif.state == state && exif.country == country && exif.hasCoordinates,
        reason: 'Expected uploaded GPS metadata to sync into local EXIF',
      );
      expect(localExif.city, city);

      final localPeople = await _waitForLocalPeopleState(
        tester,
        peopleService,
        (people) => people.any((person) => person.id == personId && person.name == personName),
        reason: 'Expected synced people list to include the created person',
      );
      expect(localPeople.map((person) => person.id), contains(personId));

      for (final assetId in uploadedRemoteIds) {
        final assetPeople = await _waitForAssetPeopleState(
          tester,
          peopleService,
          assetId,
          (people) => people.any((person) => person.id == personId),
          reason: 'Expected synced face membership for asset $assetId',
        );
        expect(assetPeople.map((person) => person.name), contains(personName));
        expect(await _remoteAssetFaceRowCount(drift, assetId, personId), 1);
      }

      final localPlaces = await _waitForLocalPlacesState(
        tester,
        assetService,
        user!.id,
        (places) => places.any((place) => place.$1 == city && uploadedRemoteIds.contains(place.$2)),
        reason: 'Expected synced places list to include the uploaded city',
      );
      expect(localPlaces.map((place) => place.$1), contains(city));
    });

    _realStackSessionTest('MOB-REAL-027-$_caseSuffix', 'preserves assets and relations through trash restore', (
      tester,
    ) async {
      await _loadAuthenticatedApp(tester, overrideCancellation: true);
      final container = _containerOfApp(tester);
      final drift = container.read(driftProvider);
      final apiService = container.read(apiServiceProvider);
      final assetsApi = apiService.assetsApi;
      final albumsApi = apiService.albumsApi;
      final assetService = container.read(assetServiceProvider);
      final uploadedRemoteIds = <String>[];
      String? albumId;

      addTearDown(() async {
        final id = albumId;
        if (id != null) {
          await _deleteAlbumBestEffort(albumsApi, id);
        }
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

      final runToken = DateTime.now().toUtc().microsecondsSinceEpoch.toString();
      final baseCreatedAt = DateTime.utc(2026, 1, 27, 12);
      final normalId = await _uploadGeneratedJpegAsSecondClient(
        'immich-e2e-trash-restore-027-normal-$runToken.jpg',
        baseCreatedAt,
      );
      uploadedRemoteIds.add(normalId);
      final favoriteId = await _uploadGeneratedJpegAsSecondClient(
        'immich-e2e-trash-restore-027-favorite-$runToken.jpg',
        baseCreatedAt.add(const Duration(minutes: 1)),
        isFavorite: true,
      );
      uploadedRemoteIds.add(favoriteId);
      final albumAssetId = await _uploadGeneratedJpegAsSecondClient(
        'immich-e2e-trash-restore-027-album-$runToken.jpg',
        baseCreatedAt.add(const Duration(minutes: 2)),
      );
      uploadedRemoteIds.add(albumAssetId);

      final initialSyncSuccess = await container.read(syncStreamServiceProvider).sync();
      expect(initialSyncSuccess, isTrue);

      for (final assetId in uploadedRemoteIds) {
        await _waitForRemoteAssetState(
          tester,
          container,
          assetId,
          (asset) => asset.visibility == AssetVisibility.timeline && !asset.isTrashed,
          reason: 'Expected uploaded trash/restore candidate $assetId to sync locally',
        );
        expect(await _remoteAssetRowCountById(drift, assetId), 1);
      }

      final albumName = 'immich-e2e-trash-restore-027-$runToken';
      final createdAlbum = await albumsApi.createAlbum(
        api.CreateAlbumDto(albumName: albumName, assetIds: api.Optional.present([albumAssetId])),
      );
      expect(createdAlbum, isNotNull);
      albumId = createdAlbum!.id;
      await _waitForAlbumInfoState(
        tester,
        albumsApi,
        albumId,
        (album) => album.albumName == albumName && album.assetCount == 1,
        reason: 'Expected server album to contain the album-scoped test asset before trash',
      );

      final albumSyncSuccess = await container.read(syncStreamServiceProvider).sync();
      expect(albumSyncSuccess, isTrue);
      await _waitForRemoteAlbumAssetIds(
        tester,
        container,
        albumId,
        includes: {albumAssetId},
        excludes: const {},
        reason: 'Expected local album membership before trash',
      );
      expect(await _remoteAlbumAssetRowCountByAlbumId(drift, albumId), 1);

      final beforeInfos = <String, api.AssetResponseDto>{};
      final beforeDownloads = <String, String>{};
      for (final assetId in uploadedRemoteIds) {
        final info = await _waitForAssetInfoState(
          tester,
          assetsApi,
          assetId,
          (asset) => !asset.isTrashed && asset.originalPath.isNotEmpty,
          reason: 'Expected server asset $assetId to be active before trash',
        );
        beforeInfos[assetId] = info;
        final download = await _waitForSuccessfulResponse(
          tester,
          () => container.read(assetApiRepositoryProvider).downloadAsset(assetId, edited: false),
        );
        beforeDownloads[assetId] = base64Encode(md5.convert(download.bodyBytes).bytes);
        expect(beforeDownloads[assetId], info.checksum);
      }

      final timelineFactory = container.read(timelineFactoryProvider);
      final mainTimeline = timelineFactory.main([user!.id]);
      final favoriteTimeline = timelineFactory.favorite(user.id);
      final trashTimeline = timelineFactory.trash(user.id);
      addTearDown(mainTimeline.dispose);
      addTearDown(favoriteTimeline.dispose);
      addTearDown(trashTimeline.dispose);

      await _expectTimelineAssetSet(
        tester,
        mainTimeline,
        includes: {normalId, favoriteId, albumAssetId},
        excludes: const {},
        reason: 'Initial main timeline should include all trash/restore candidates',
      );
      await _expectTimelineAssetSet(
        tester,
        favoriteTimeline,
        includes: {favoriteId},
        excludes: {normalId, albumAssetId},
        reason: 'Initial favorite timeline should contain only the favorited candidate',
      );
      await _expectTimelineAssetSet(
        tester,
        trashTimeline,
        includes: const {},
        excludes: {normalId, favoriteId, albumAssetId},
        reason: 'Initial trash timeline should not contain active candidates',
      );

      await assetService.trash(uploadedRemoteIds);
      for (final assetId in uploadedRemoteIds) {
        await _waitForAssetInfoState(
          tester,
          assetsApi,
          assetId,
          (asset) => asset.isTrashed,
          reason: 'Expected server asset $assetId to be logically trashed',
        );
        await _waitForRemoteAssetState(
          tester,
          container,
          assetId,
          (asset) => asset.isTrashed,
          reason: 'Expected App-side trash action to mark local asset $assetId as trashed',
        );
      }

      await _expectTimelineAssetSet(
        tester,
        mainTimeline,
        includes: const {},
        excludes: {normalId, favoriteId, albumAssetId},
        reason: 'Main timeline should hide logically trashed assets',
      );
      await _expectTimelineAssetSet(
        tester,
        favoriteTimeline,
        includes: const {},
        excludes: {normalId, favoriteId, albumAssetId},
        reason: 'Favorite timeline should hide logically trashed assets',
      );
      await _expectTimelineAssetSet(
        tester,
        trashTimeline,
        includes: {normalId, favoriteId, albumAssetId},
        excludes: const {},
        reason: 'Trash timeline should expose logically trashed assets',
      );

      final trashSyncSuccess = await container.read(syncStreamServiceProvider).sync();
      expect(trashSyncSuccess, isTrue);
      expect(await _remoteAlbumAssetRowCountByAlbumId(drift, albumId), 1);

      await assetService.restoreTrash(uploadedRemoteIds);
      for (final assetId in uploadedRemoteIds) {
        final restoredInfo = await _waitForAssetInfoState(
          tester,
          assetsApi,
          assetId,
          (asset) => !asset.isTrashed,
          reason: 'Expected server asset $assetId to be restored',
        );
        _expectAssetInfoPreserved(restoredInfo, beforeInfos[assetId]!);
      }

      final restoreSyncSuccess = await container.read(syncStreamServiceProvider).sync();
      expect(restoreSyncSuccess, isTrue);
      for (final assetId in uploadedRemoteIds) {
        final restoredAsset = await _waitForRemoteAssetState(
          tester,
          container,
          assetId,
          (asset) => !asset.isTrashed && asset.visibility == AssetVisibility.timeline,
          reason: 'Expected restored asset $assetId to sync back into the local active set',
        );
        expect(restoredAsset.isFavorite, beforeInfos[assetId]!.isFavorite);
        expect(await _remoteAssetRowCountById(drift, assetId), 1);

        final download = await _waitForSuccessfulResponse(
          tester,
          () => container.read(assetApiRepositoryProvider).downloadAsset(assetId, edited: false),
        );
        expect(base64Encode(md5.convert(download.bodyBytes).bytes), beforeDownloads[assetId]);
      }

      await _expectTimelineAssetSet(
        tester,
        mainTimeline,
        includes: {normalId, favoriteId, albumAssetId},
        excludes: const {},
        reason: 'Restored assets should return to the main timeline',
      );
      await _expectTimelineAssetSet(
        tester,
        favoriteTimeline,
        includes: {favoriteId},
        excludes: {normalId, albumAssetId},
        reason: 'Restored favorite asset should keep favorite membership',
      );
      await _expectTimelineAssetSet(
        tester,
        trashTimeline,
        includes: const {},
        excludes: {normalId, favoriteId, albumAssetId},
        reason: 'Trash timeline should be empty for restored candidates',
      );

      await _waitForAlbumInfoState(
        tester,
        albumsApi,
        albumId,
        (album) => album.assetCount == 1 && album.albumThumbnailAssetId == albumAssetId,
        reason: 'Expected restored album asset to keep server album membership and cover',
      );
      await _waitForRemoteAlbumAssetIds(
        tester,
        container,
        albumId,
        includes: {albumAssetId},
        excludes: {normalId, favoriteId},
        reason: 'Expected restored album asset to keep local album membership',
      );
      expect(await _remoteAlbumAssetRowCountByAlbumId(drift, albumId), 1);

      final rowsAfterRestore = await _remoteSyncRowCounts(drift);
      final secondSyncSuccess = await container.read(syncStreamServiceProvider).sync();
      expect(secondSyncSuccess, isTrue);
      expect(
        await _remoteSyncRowCounts(drift),
        rowsAfterRestore,
        reason: 'Second sync after trash restore should not duplicate local rows',
      );
    });

    _realStackSessionTest('MOB-REAL-028-$_caseSuffix', 'converges permanent delete across server and local state', (
      tester,
    ) async {
      await _loadAuthenticatedApp(tester, overrideCancellation: true);
      final container = _containerOfApp(tester);
      final drift = container.read(driftProvider);
      final assetsApi = container.read(apiServiceProvider).assetsApi;
      final assetService = container.read(assetServiceProvider);
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

      final runToken = DateTime.now().toUtc().microsecondsSinceEpoch.toString();
      final baseCreatedAt = DateTime.utc(2026, 1, 28, 12);
      final deleteId = await _uploadGeneratedJpegAsSecondClient(
        'immich-e2e-permanent-delete-028-delete-$runToken.jpg',
        baseCreatedAt,
      );
      uploadedRemoteIds.add(deleteId);
      final controlId = await _uploadGeneratedJpegAsSecondClient(
        'immich-e2e-permanent-delete-028-control-$runToken.jpg',
        baseCreatedAt.add(const Duration(minutes: 1)),
        isFavorite: true,
      );
      uploadedRemoteIds.add(controlId);

      final initialSyncSuccess = await container.read(syncStreamServiceProvider).sync();
      expect(initialSyncSuccess, isTrue);

      for (final assetId in [deleteId, controlId]) {
        await _waitForRemoteAssetState(
          tester,
          container,
          assetId,
          (asset) => asset.visibility == AssetVisibility.timeline && !asset.isTrashed,
          reason: 'Expected uploaded permanent-delete candidate $assetId to sync locally',
        );
        expect(await _remoteAssetRowCountById(drift, assetId), 1);
      }

      final deleteInfo = await _waitForAssetInfoState(
        tester,
        assetsApi,
        deleteId,
        (asset) => !asset.isTrashed && asset.originalPath.isNotEmpty,
        reason: 'Expected delete target to expose active server metadata before permanent delete',
      );
      final controlInfo = await _waitForAssetInfoState(
        tester,
        assetsApi,
        controlId,
        (asset) => asset.isFavorite && !asset.isTrashed && asset.originalPath.isNotEmpty,
        reason: 'Expected control asset to expose active server metadata before permanent delete',
      );
      final deleteOriginal = await _waitForSuccessfulResponse(
        tester,
        () => container.read(assetApiRepositoryProvider).downloadAsset(deleteId, edited: false),
      );
      expect(base64Encode(md5.convert(deleteOriginal.bodyBytes).bytes), deleteInfo.checksum);
      await _waitForSuccessfulResponse(
        tester,
        () => assetsApi.viewAssetWithHttpInfo(deleteId, size: api.AssetMediaSize.thumbnail),
      );
      final controlOriginal = await _waitForSuccessfulResponse(
        tester,
        () => container.read(assetApiRepositoryProvider).downloadAsset(controlId, edited: false),
      );
      final controlChecksum = base64Encode(md5.convert(controlOriginal.bodyBytes).bytes);
      expect(controlChecksum, controlInfo.checksum);

      final timelineFactory = container.read(timelineFactoryProvider);
      final mainTimeline = timelineFactory.main([user!.id]);
      final favoriteTimeline = timelineFactory.favorite(user.id);
      final trashTimeline = timelineFactory.trash(user.id);
      addTearDown(mainTimeline.dispose);
      addTearDown(favoriteTimeline.dispose);
      addTearDown(trashTimeline.dispose);

      await _expectTimelineAssetSet(
        tester,
        mainTimeline,
        includes: {deleteId, controlId},
        excludes: const {},
        reason: 'Initial main timeline should include delete target and control asset',
      );
      await _expectTimelineAssetSet(
        tester,
        favoriteTimeline,
        includes: {controlId},
        excludes: {deleteId},
        reason: 'Initial favorite timeline should include only the favorite control asset',
      );
      await _expectTimelineAssetSet(
        tester,
        trashTimeline,
        includes: const {},
        excludes: {deleteId, controlId},
        reason: 'Initial trash timeline should not include active permanent-delete assets',
      );

      await assetService.trash([deleteId]);
      await _waitForAssetInfoState(
        tester,
        assetsApi,
        deleteId,
        (asset) => asset.isTrashed,
        reason: 'Expected delete target to be logically trashed before permanent delete',
      );
      await _waitForRemoteAssetState(
        tester,
        container,
        deleteId,
        (asset) => asset.isTrashed,
        reason: 'Expected mobile trash action to move delete target into local trash',
      );
      await _expectTimelineAssetSet(
        tester,
        mainTimeline,
        includes: {controlId},
        excludes: {deleteId},
        reason: 'Main timeline should hide the logically trashed delete target',
      );
      await _expectTimelineAssetSet(
        tester,
        trashTimeline,
        includes: {deleteId},
        excludes: {controlId},
        reason: 'Trash timeline should contain the logically trashed delete target',
      );

      await assetService.delete([deleteId]);
      await _waitForAssetInfoUnavailable(
        tester,
        assetsApi,
        deleteId,
        reason: 'Expected hard-deleted asset info endpoint to become unavailable',
      );
      await _waitForRemoteAssetDeleted(
        tester,
        container,
        deleteId,
        reason: 'Expected mobile permanent delete to remove the local remote asset row',
      );
      expect(await _remoteAssetRowCountById(drift, deleteId), 0);

      await _waitForRejectedResponse(
        tester,
        () => _authenticatedApiGet('/assets/$deleteId/original?edited=false'),
        reason: 'Expected old original download URL to be unreadable after permanent delete',
      );
      await _waitForRejectedResponse(
        tester,
        () => _authenticatedApiGet('/assets/$deleteId/thumbnail?size=thumbnail&edited=false'),
        reason: 'Expected old thumbnail URL to be unreadable after permanent delete',
      );

      await _expectTimelineAssetSet(
        tester,
        mainTimeline,
        includes: {controlId},
        excludes: {deleteId},
        reason: 'Main timeline should keep only the unaffected control asset after permanent delete',
      );
      await _expectTimelineAssetSet(
        tester,
        favoriteTimeline,
        includes: {controlId},
        excludes: {deleteId},
        reason: 'Favorite timeline should keep the unaffected control asset after permanent delete',
      );
      await _expectTimelineAssetSet(
        tester,
        trashTimeline,
        includes: const {},
        excludes: {deleteId, controlId},
        reason: 'Trash timeline should no longer list the permanently deleted asset',
      );

      final deleteSyncSuccess = await container.read(syncStreamServiceProvider).sync();
      expect(deleteSyncSuccess, isTrue);
      expect(await _remoteAssetRowCountById(drift, deleteId), 0);
      expect(await _remoteAssetRowCountById(drift, controlId), 1);

      final controlAfterDelete = await _waitForAssetInfoState(
        tester,
        assetsApi,
        controlId,
        (asset) => asset.isFavorite && !asset.isTrashed,
        reason: 'Expected permanent delete to leave the control asset untouched',
      );
      _expectAssetInfoPreserved(controlAfterDelete, controlInfo);
      final controlDownloadAfterDelete = await _waitForSuccessfulResponse(
        tester,
        () => container.read(assetApiRepositoryProvider).downloadAsset(controlId, edited: false),
      );
      expect(base64Encode(md5.convert(controlDownloadAfterDelete.bodyBytes).bytes), controlChecksum);

      final rowsAfterDelete = await _remoteSyncRowCounts(drift);
      final secondSyncSuccess = await container.read(syncStreamServiceProvider).sync();
      expect(secondSyncSuccess, isTrue);
      expect(
        await _remoteSyncRowCounts(drift),
        rowsAfterDelete,
        reason: 'Second sync after permanent delete should not reinsert deleted local rows',
      );
    });

    _realStackSessionTest(
      'MOB-REAL-029-$_caseSuffix',
      'browses cached assets across offline cold start and reconnect',
      (tester) async {
        await _loadAuthenticatedApp(tester, overrideCancellation: true, closeDriftOnDispose: false);
        var container = _containerOfApp(tester);
        var drift = container.read(driftProvider);
        final realEndpoint = _apiEndpoint(_serverUrl);
        final offlineEndpoint = _apiEndpoint(_badServerUrl);
        final uploadedRemoteIds = <String>[];
        final user = Store.tryGet(StoreKey.currentUser);
        expect(user, isNotNull);

        addTearDown(() async {
          await Store.put(StoreKey.serverEndpoint, realEndpoint);
          await Store.put(StoreKey.serverUrl, realEndpoint);
          final apiService = ApiService()..setEndpoint(realEndpoint);
          await apiService.updateHeaders();
          for (final assetId in uploadedRemoteIds) {
            await _deleteTestAssetBestEffort(apiService.assetsApi, assetId);
          }
        });

        await container.read(syncApiRepositoryProvider).deleteSyncAck(_allReplayableSyncAckTypes);
        await Store.delete(StoreKey.syncMigrationStatus);
        await container.read(syncStreamRepositoryProvider).reset();
        final baselineSyncSuccess = await container.read(syncStreamServiceProvider).sync();
        expect(baselineSyncSuccess, isTrue);
        if (Store.tryGet(StoreKey.currentUser) == null) {
          await Store.put(StoreKey.currentUser, user!);
        }

        final runToken = DateTime.now().toUtc().microsecondsSinceEpoch.toString();
        final createdAt = DateTime.utc(
          2026,
          1,
          29,
          12,
        ).add(Duration(microseconds: int.parse(runToken) % Duration.microsecondsPerDay));
        final cachedAssetId = await _uploadGeneratedJpegAsSecondClient(
          'immich-e2e-offline-recovery-029-cached-$runToken.jpg',
          createdAt,
        );
        uploadedRemoteIds.add(cachedAssetId);

        final uploadSyncSuccess = await container.read(syncStreamServiceProvider).sync();
        expect(uploadSyncSuccess, isTrue);
        final cachedBeforeOffline = await _waitForRemoteAssetState(
          tester,
          container,
          cachedAssetId,
          (asset) => asset.visibility == AssetVisibility.timeline && !asset.isTrashed && !asset.isFavorite,
          reason: 'Expected uploaded offline-recovery asset to sync locally before disconnect',
        );

        final assetsApi = container.read(apiServiceProvider).assetsApi;
        final infoBeforeOffline = await _waitForAssetInfoState(
          tester,
          assetsApi,
          cachedAssetId,
          (asset) => !asset.isTrashed && asset.originalPath.isNotEmpty,
          reason: 'Expected server metadata before offline cold start',
        );
        final originalBeforeOffline = await _waitForSuccessfulResponse(
          tester,
          () => container.read(assetApiRepositoryProvider).downloadAsset(cachedAssetId, edited: false),
        );
        expect(base64Encode(md5.convert(originalBeforeOffline.bodyBytes).bytes), infoBeforeOffline.checksum);
        await _waitForSuccessfulResponse(
          tester,
          () => assetsApi.viewAssetWithHttpInfo(cachedAssetId, size: api.AssetMediaSize.thumbnail),
        );

        final onlineTimeline = container.read(timelineFactoryProvider).main([user!.id]);
        await _expectTimelineAssetSet(
          tester,
          onlineTimeline,
          includes: {cachedAssetId},
          excludes: const {},
          reason: 'Expected online timeline to include the cached offline-recovery asset',
        );
        await onlineTimeline.dispose();
        final rowsBeforeOffline = await _remoteSyncRowCounts(drift);

        await Store.put(StoreKey.serverEndpoint, offlineEndpoint);
        await Store.put(StoreKey.serverUrl, offlineEndpoint);
        final onlineApiService = container.read(apiServiceProvider);
        onlineApiService.setEndpoint(offlineEndpoint);
        await onlineApiService.updateHeaders();
        container.read(websocketProvider.notifier).disconnect();
        await tester.pumpWidget(const SizedBox.shrink());
        await _pumpFor(tester, const Duration(milliseconds: 500));

        await _loadAppPreservingStore(tester, overrideCancellation: true, closeDriftOnDispose: false);
        await _waitForAccessToken(tester);
        await _waitForCurrentUser(_email, tester);
        container = _containerOfApp(tester);
        drift = container.read(driftProvider);

        final cachedAfterColdStart = await _waitForRemoteAssetState(
          tester,
          container,
          cachedAssetId,
          (asset) =>
              !asset.isTrashed && !asset.isFavorite && asset.createdAt.toUtc() == cachedBeforeOffline.createdAt.toUtc(),
          reason: 'Expected offline cold start to keep the cached remote asset readable from Drift',
        );
        expect(cachedAfterColdStart.checksum, cachedBeforeOffline.checksum);

        final offlineTimeline = container.read(timelineFactoryProvider).main([user.id]);
        await _expectTimelineAssetSet(
          tester,
          offlineTimeline,
          includes: {cachedAssetId},
          excludes: const {},
          reason: 'Expected offline timeline browsing to use cached remote rows',
        );
        await offlineTimeline.dispose();
        expect(await _remoteSyncRowCounts(drift), rowsBeforeOffline);

        final offlineWriteError = await _captureError(
          () => container.read(assetServiceProvider).update([cachedAssetId], isFavorite: const Option.some(true)),
        );
        expect(offlineWriteError, isNotNull, reason: 'Expected offline favorite write to fail explicitly');
        expect(offlineWriteError.toString(), isNotEmpty);
        final assetAfterOfflineWrite = await container.read(remoteAssetRepositoryProvider).get(cachedAssetId);
        expect(assetAfterOfflineWrite, isNotNull);
        expect(assetAfterOfflineWrite!.isFavorite, isFalse, reason: 'Failed offline write must not mutate local state');

        await Store.put(StoreKey.serverEndpoint, realEndpoint);
        await Store.put(StoreKey.serverUrl, realEndpoint);
        final recoveredApiService = container.read(apiServiceProvider);
        recoveredApiService.setEndpoint(realEndpoint);
        await recoveredApiService.updateHeaders();

        final reconnectSyncSuccess = await container.read(syncStreamServiceProvider).sync();
        expect(reconnectSyncSuccess, isTrue);
        await _waitForRemoteAssetState(
          tester,
          container,
          cachedAssetId,
          (asset) => !asset.isTrashed && !asset.isFavorite,
          reason: 'Expected reconnect sync to preserve the server truth after rejected offline write',
        );
        expect(await _remoteAssetRowCountById(drift, cachedAssetId), 1);
        expect(
          await _remoteSyncRowCounts(drift),
          rowsBeforeOffline,
          reason: 'Reconnect sync after offline cold start should not duplicate cached rows',
        );

        final infoAfterReconnect = await _waitForAssetInfoState(
          tester,
          recoveredApiService.assetsApi,
          cachedAssetId,
          (asset) => !asset.isTrashed && !asset.isFavorite,
          reason: 'Expected restored network access to read server metadata again',
        );
        _expectAssetInfoPreserved(infoAfterReconnect, infoBeforeOffline);

        final secondSyncSuccess = await container.read(syncStreamServiceProvider).sync();
        expect(secondSyncSuccess, isTrue);
        expect(
          await _remoteSyncRowCounts(drift),
          rowsBeforeOffline,
          reason: 'Second sync after offline recovery should not duplicate cached rows',
        );
      },
    );

    _realStackSessionTest('MOB-REAL-030-$_caseSuffix', 'recovers session upload and sync after a real server restart', (
      tester,
    ) async {
      await _loadAuthenticatedApp(tester, overrideCancellation: true, closeDriftOnDispose: false);
      var container = _containerOfApp(tester);
      var drift = container.read(driftProvider);
      final realEndpoint = _apiEndpoint(_serverUrl);
      final user = Store.tryGet(StoreKey.currentUser);
      expect(user, isNotNull);

      String? uploadedRemoteId;
      addTearDown(() async {
        await Store.put(StoreKey.serverEndpoint, realEndpoint);
        await Store.put(StoreKey.serverUrl, realEndpoint);
        final apiService = ApiService()..setEndpoint(realEndpoint);
        await apiService.updateHeaders();
        final assetId = uploadedRemoteId;
        if (assetId != null) {
          await _deleteTestAssetBestEffort(apiService.assetsApi, assetId);
        }
      });

      await container.read(syncApiRepositoryProvider).deleteSyncAck(_allReplayableSyncAckTypes);
      await Store.delete(StoreKey.syncMigrationStatus);
      await container.read(syncStreamRepositoryProvider).reset();
      final baselineSyncSuccess = await container.read(syncStreamServiceProvider).sync();
      expect(baselineSyncSuccess, isTrue);
      if (Store.tryGet(StoreKey.currentUser) == null) {
        await Store.put(StoreKey.currentUser, user!);
      }
      final baselineRows = await _remoteSyncRowCounts(drift);

      final asset = await _waitForLocalAssetByName(container, _resumableAssetName, tester);
      final contentSize = asset.contentSize;
      if (contentSize == null) {
        fail('Server-restart upload asset $_resumableAssetName has no known content size');
      }
      expect(contentSize, greaterThan(_resumableCancelAfterBytes));
      await _clearResumableStateFiles();

      final firstProgress = <int>[];
      String? firstUploadError;
      var restartMarkerPrinted = false;
      final firstUpload = container
          .read(foregroundUploadServiceProvider)
          .uploadSingleAsset(
            asset,
            null,
            callbacks: UploadCallbacks(
              onProgress: (_, _, bytes, totalBytes) {
                firstProgress.add(bytes);
                if (!restartMarkerPrinted && bytes > 0) {
                  restartMarkerPrinted = true;
                  debugPrint(_serverRestartReadyMarker);
                }
              },
              onSuccess: (_, remoteId) => uploadedRemoteId = remoteId,
              onError: (_, errorMessage) => firstUploadError = errorMessage,
            ),
          );

      await _pumpUntil(
        tester,
        () => restartMarkerPrinted || uploadedRemoteId != null || firstUploadError != null,
        timeout: const Duration(seconds: 90),
      );
      expect(
        restartMarkerPrinted,
        isTrue,
        reason: 'Expected upload progress before asking the host harness to restart the server',
      );

      await _waitForServerReachability(tester, realEndpoint, reachable: false, timeout: const Duration(seconds: 30));
      await _waitForServerReachability(tester, realEndpoint, reachable: true, timeout: const Duration(seconds: 90));

      await firstUpload.timeout(
        const Duration(seconds: 120),
        onTimeout: () => fail('Timed out waiting for the in-flight upload to settle after server restart'),
      );

      if (uploadedRemoteId == null) {
        expect(firstUploadError, isNotNull, reason: 'Expected the interrupted upload to report a recoverable error');
        expect(await _resumableStateFiles(), isNotEmpty, reason: 'Interrupted upload should persist resumable state');

        final retryProgress = <int>[];
        String? retryError;
        await container
            .read(foregroundUploadServiceProvider)
            .uploadSingleAsset(
              asset,
              null,
              callbacks: UploadCallbacks(
                onProgress: (_, _, bytes, totalBytes) => retryProgress.add(bytes),
                onSuccess: (_, remoteId) => uploadedRemoteId = remoteId,
                onError: (_, errorMessage) => retryError = errorMessage,
              ),
            )
            .timeout(const Duration(seconds: 120));
        expect(retryError, isNull);
        expect(retryProgress, isNotEmpty);
        expect(retryProgress.last, contentSize);
      }

      expect(uploadedRemoteId, isNotNull);
      final uploadId = uploadedRemoteId!;
      expect(firstProgress, isNotEmpty);

      final postRestartSyncSuccess = await container.read(syncStreamServiceProvider).sync();
      expect(postRestartSyncSuccess, isTrue);
      await _waitForRemoteAssetState(
        tester,
        container,
        uploadId,
        (asset) => asset.visibility == AssetVisibility.timeline && !asset.isTrashed,
        reason: 'Expected uploaded asset to sync locally after backend restart',
      );
      expect(await _remoteAssetRowCountById(drift, uploadId), 1);

      await tester.pumpWidget(const SizedBox.shrink());
      await _pumpFor(tester, const Duration(milliseconds: 500));
      await _loadAppPreservingStore(tester, overrideCancellation: true, closeDriftOnDispose: false);
      await _waitForAccessToken(tester);
      await _waitForCurrentUser(_email, tester);
      container = _containerOfApp(tester);
      drift = container.read(driftProvider);

      final resumedSyncSuccess = await container.read(syncStreamServiceProvider).sync();
      expect(resumedSyncSuccess, isTrue);
      final localAsset = await _waitForRemoteAssetState(
        tester,
        container,
        uploadId,
        (asset) => asset.visibility == AssetVisibility.timeline && !asset.isTrashed,
        reason: 'Expected relaunched client to preserve the uploaded asset after server recovery',
      );
      expect(localAsset.ownerId, user!.id);
      expect(await _remoteAssetRowCountById(drift, uploadId), 1);
      final resumedRows = await _remoteSyncRowCounts(drift);
      expect(resumedRows['remote_asset_entity'], greaterThanOrEqualTo(baselineRows['remote_asset_entity']! + 1));

      final infoAfterRestart = await _waitForAssetInfoState(
        tester,
        container.read(apiServiceProvider).assetsApi,
        uploadId,
        (asset) => !asset.isTrashed && asset.originalPath.isNotEmpty,
        reason: 'Expected session token to remain valid after backend restart',
      );
      expect(infoAfterRestart.originalFileName, _resumableAssetName);

      final downloaded = await _waitForSuccessfulResponse(
        tester,
        () => container.read(assetApiRepositoryProvider).downloadAsset(uploadId, edited: false),
      );
      expect(downloaded.bodyBytes.length, contentSize);

      final secondSyncSuccess = await container.read(syncStreamServiceProvider).sync();
      expect(secondSyncSuccess, isTrue);
      expect(
        await _remoteSyncRowCounts(drift),
        resumedRows,
        reason: 'Second sync after server restart recovery should not duplicate local rows',
      );
    });

    _realStackSessionTest('MOB-REAL-031-$_caseSuffix', 'runs scheduled background backup and tears down cleanly', (
      tester,
    ) async {
      final (container, drift) = await _loadAuthenticatedSyncContainer();
      final backgroundWorker = container.read(backgroundWorkerFgServiceProvider);
      final backgroundWorkerLock = container.read(backgroundWorkerLockServiceProvider);
      final apiService = container.read(apiServiceProvider);
      final user = Store.tryGet(StoreKey.currentUser);
      expect(user, isNotNull);

      final uploadedRemoteIds = <String>{};
      addTearDown(() async {
        await _restoreRealStackApi(apiService);
        try {
          await backgroundWorker.disable();
          await backgroundWorkerLock.lock();
        } catch (_) {
          // Best-effort cleanup for native WorkManager state used by this test.
        }
        for (final remoteId in uploadedRemoteIds) {
          await _deleteTestAssetBestEffort(apiService.assetsApi, remoteId);
        }
        container.dispose();
      });

      await container.read(backgroundSyncProvider).syncLocal(full: true);
      final asset = await _waitForLocalAssetByName(container, _backgroundBackupAssetName, tester);
      await _selectOnlyBackupAlbumForAsset(container, asset);
      await SettingsRepository.instance.write(SettingsKey.backupEnabled, true);
      await SettingsRepository.instance.write(SettingsKey.backupUseCellularForPhotos, true);
      await SettingsRepository.instance.write(SettingsKey.backupUseCellularForVideos, true);
      await SettingsRepository.instance.write(SettingsKey.backupRequireCharging, false);
      await SettingsRepository.instance.write(SettingsKey.backupTriggerDelay, 1);

      final beforeServerIds = await _serverAssetIdsByOriginalFilename(apiService.searchApi, _backgroundBackupAssetName);
      expect(beforeServerIds, isEmpty, reason: 'Background backup fixture name must be unique for this run');
      final beforeRows = await _remoteSyncRowCounts(drift);

      final initialCounts = await _waitForBackupCounts(
        tester,
        container,
        user!.id,
        (counts) => counts.total == 1 && counts.remainder == 1,
        reason: 'Expected selected album to expose exactly one background backup candidate',
      );

      await container.read(backgroundWorkerLockServiceProvider).unlock();
      await container.read(backgroundWorkerFgServiceProvider).disable();
      await container.read(backgroundWorkerFgServiceProvider).configure(minimumDelaySeconds: 1, requireCharging: false);
      await container.read(backgroundWorkerFgServiceProvider).enable();
      debugPrint('$_backgroundWorkerTriggerMarker first');
      await _runAndroidBackgroundUploadOnce();
      await _restoreRealStackApi(apiService);

      final firstServerIds = await _waitForServerAssetIdsByOriginalFilename(
        tester,
        apiService.searchApi,
        _backgroundBackupAssetName,
        (ids) => ids.length == beforeServerIds.length + 1,
        reason: 'Expected forced Android background worker to upload the selected local asset',
        timeout: const Duration(minutes: 3),
      );
      final uploadedId = firstServerIds.difference(beforeServerIds).single;
      uploadedRemoteIds.add(uploadedId);

      final firstSyncSuccess = await container.read(syncStreamServiceProvider).sync();
      expect(firstSyncSuccess, isTrue);
      await _waitForRemoteAssetState(
        tester,
        container,
        uploadedId,
        (asset) => asset.visibility == AssetVisibility.timeline && !asset.isTrashed,
        reason: 'Expected background-uploaded asset to sync into the local remote timeline',
      );
      expect(await _remoteAssetRowCountById(drift, uploadedId), 1);
      final afterFirstRows = await _remoteSyncRowCounts(drift);
      expect(
        afterFirstRows['remote_asset_entity'],
        greaterThanOrEqualTo(beforeRows['remote_asset_entity']! + 1),
        reason: 'Background worker remote sync should converge after upload',
      );

      final afterFirstCounts = await _waitForBackupCounts(
        tester,
        container,
        user.id,
        (counts) => counts.remainder == initialCounts.remainder - 1,
        reason: 'Uploaded background asset should no longer be a backup candidate',
      );
      expect(afterFirstCounts.processing, 0);
      expect(await container.read(backgroundUploadServiceProvider).getActiveTasks(kBackupGroup), isEmpty);

      debugPrint('$_backgroundWorkerTriggerMarker second');
      await _runAndroidBackgroundUploadOnce();
      await _restoreRealStackApi(apiService);
      await _pumpFor(tester, const Duration(seconds: 2));

      final secondServerIds = await _serverAssetIdsByOriginalFilename(apiService.searchApi, _backgroundBackupAssetName);
      expect(
        secondServerIds,
        firstServerIds,
        reason: 'A repeated background schedule must not upload the same selected asset twice',
      );
      final secondSyncSuccess = await container.read(syncStreamServiceProvider).sync();
      expect(secondSyncSuccess, isTrue);
      expect(await _remoteAssetRowCountById(drift, uploadedId), 1);
      expect(await _remoteSyncRowCounts(drift), afterFirstRows);
      expect(await container.read(backgroundUploadServiceProvider).getActiveTasks(kBackupGroup), isEmpty);
      await drift.customSelect('SELECT 1').getSingle();
    });

    _realStackSessionTest('MOB-REAL-032-$_caseSuffix', 'preserves login and local library across app upgrade', (
      tester,
    ) async {
      switch (_upgradeStage) {
        case 'seed':
          await _seedUpgradeState(tester);
          return;
        case 'verify':
          await _verifyUpgradeState(tester);
          return;
        case 'single':
          await _seedUpgradeState(tester);
          await tester.pumpWidget(const SizedBox.shrink());
          await _pumpFor(tester, const Duration(milliseconds: 500));
          await _verifyUpgradeState(tester);
          return;
        default:
          fail('Unknown IMMICH_E2E_UPGRADE_STAGE=$_upgradeStage; expected seed, verify, or single');
      }
    });

    _realStackSessionTest('MOB-UI-033-$_caseSuffix', 'keeps primary navigation state across tabs and rotation', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(430, 932);
      addTearDown(tester.view.reset);

      await _loadAuthenticatedApp(tester, overrideCancellation: true);
      final container = _containerOfApp(tester);
      final user = Store.tryGet(StoreKey.currentUser);
      expect(user, isNotNull);

      await container.read(backgroundSyncProvider).syncLocal(full: true);
      final syncSuccess = await container.read(syncStreamServiceProvider).sync();
      expect(syncSuccess, isTrue);

      final timeline = container.read(timelineFactoryProvider).main([user!.id]);
      addTearDown(timeline.dispose);
      await _waitForTimelineBuckets(tester, timeline, minAssets: _timelineMinimumAssetCount);

      await _expectPrimaryNavigationState(
        tester,
        container,
        tab: TabEnum.home,
        selectedIndex: kPhotoTabIndex,
        pageType: MainTimelinePage,
        expectedNavigationType: NavigationBar,
      );
      await _expectPhotoRetapScrollsToTop(tester);

      await _selectPrimaryNavigationTab(tester, kSearchTabIndex);
      await _expectPrimaryNavigationState(
        tester,
        container,
        tab: TabEnum.search,
        selectedIndex: kSearchTabIndex,
        pageType: DriftSearchPage,
        expectedNavigationType: NavigationBar,
      );

      await _selectPrimaryNavigationTab(tester, kAlbumTabIndex);
      await _expectPrimaryNavigationState(
        tester,
        container,
        tab: TabEnum.albums,
        selectedIndex: kAlbumTabIndex,
        pageType: DriftAlbumsPage,
        expectedNavigationType: NavigationBar,
      );

      await _selectPrimaryNavigationTab(tester, kLibraryTabIndex);
      await _expectPrimaryNavigationState(
        tester,
        container,
        tab: TabEnum.library,
        selectedIndex: kLibraryTabIndex,
        pageType: DriftLibraryPage,
        expectedNavigationType: NavigationBar,
      );
      await _openFavoritePageAndReturn(tester, container, expectedNavigationType: NavigationBar);

      await _setTestViewport(tester, const Size(1000, 520));
      await _expectPrimaryNavigationState(
        tester,
        container,
        tab: TabEnum.library,
        selectedIndex: kLibraryTabIndex,
        pageType: DriftLibraryPage,
        expectedNavigationType: NavigationRail,
      );

      await _selectPrimaryNavigationTab(tester, kSearchTabIndex);
      await _expectPrimaryNavigationState(
        tester,
        container,
        tab: TabEnum.search,
        selectedIndex: kSearchTabIndex,
        pageType: DriftSearchPage,
        expectedNavigationType: NavigationRail,
      );

      await _setTestViewport(tester, const Size(430, 932));
      await _expectPrimaryNavigationState(
        tester,
        container,
        tab: TabEnum.search,
        selectedIndex: kSearchTabIndex,
        pageType: DriftSearchPage,
        expectedNavigationType: NavigationBar,
      );

      await _selectPrimaryNavigationTab(tester, kPhotoTabIndex);
      await _expectPrimaryNavigationState(
        tester,
        container,
        tab: TabEnum.home,
        selectedIndex: kPhotoTabIndex,
        pageType: MainTimelinePage,
        expectedNavigationType: NavigationBar,
      );
    });

    _realStackSessionTest(
      'MOB-UI-034-$_caseSuffix',
      'returns guarded deep links after login and avoids bad route stacks',
      (tester) async {
        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = const Size(430, 932);
        addTearDown(tester.view.reset);

        await _loadUnauthenticatedApp(tester, overrideCancellation: true);
        var container = _containerOfApp(tester);
        var router = container.read(appRouterProvider);

        unawaited(router.push(const TabShellRoute(children: [DriftLibraryRoute()])));
        await _pumpUntil(
          tester,
          () => find.byType(LoginPage).evaluate().isNotEmpty,
          timeout: const Duration(seconds: 30),
        );
        expect(Store.tryGet(StoreKey.accessToken), isNull);

        await _login(tester, serverUrl: _serverUrl, email: _email, password: _password);
        await _waitForAccessToken(tester);
        await _waitForCurrentUser(_email, tester);
        await _expectPrimaryNavigationState(
          tester,
          container,
          tab: TabEnum.library,
          selectedIndex: kLibraryTabIndex,
          pageType: DriftLibraryPage,
          expectedNavigationType: NavigationBar,
        );
        _expectRouteCount(router, DriftLibraryRoute.name, 1);

        unawaited(router.push(const DriftFavoriteRoute()));
        await _pumpUntil(
          tester,
          () => find.byType(DriftFavoritePage).evaluate().isNotEmpty,
          timeout: const Duration(seconds: 30),
        );
        final favoriteRouteCount = _currentRouteCount(router, DriftFavoriteRoute.name);
        expect(favoriteRouteCount, 1);

        unawaited(router.push(const DriftFavoriteRoute()));
        await _pumpFor(tester, const Duration(milliseconds: 800));
        expect(find.byType(DriftFavoritePage), findsOneWidget);
        expect(_currentRouteCount(router, DriftFavoriteRoute.name), favoriteRouteCount);

        await tester.binding.handlePopRoute();
        await _pumpFor(tester, const Duration(milliseconds: 800));
        await _expectPrimaryNavigationState(
          tester,
          container,
          tab: TabEnum.library,
          selectedIndex: kLibraryTabIndex,
          pageType: DriftLibraryPage,
          expectedNavigationType: NavigationBar,
        );

        unawaited(router.push(const DriftLockedFolderRoute()));
        await _pumpUntil(
          tester,
          () => find.byType(PinAuthPage).evaluate().isNotEmpty,
          timeout: const Duration(seconds: 30),
        );
        expect(find.byType(DriftLockedFolderPage), findsNothing);
        expect(_currentRouteCount(router, PinAuthRoute.name), 1);
        expect(
          find.text('setup_pin_code'.tr()).evaluate().isNotEmpty ||
              find.text('enter_your_pin_code_subtitle'.tr()).evaluate().isNotEmpty,
          isTrue,
        );

        await router.replaceAll([
          const TabShellRoute(children: [MainTimelineRoute()]),
        ]);
        await _pumpFor(tester, const Duration(milliseconds: 800));
        await _expectPrimaryNavigationState(
          tester,
          container,
          tab: TabEnum.home,
          selectedIndex: kPhotoTabIndex,
          pageType: MainTimelinePage,
          expectedNavigationType: NavigationBar,
        );

        await router.navigatePath('/missing-mobile-route-034');
        await _pumpFor(tester, const Duration(seconds: 1));
        await _expectPrimaryNavigationState(
          tester,
          container,
          tab: TabEnum.home,
          selectedIndex: kPhotoTabIndex,
          pageType: MainTimelinePage,
          expectedNavigationType: NavigationBar,
        );
        expect(find.byType(LoginPage), findsNothing);
        expect(_currentRouteCount(router, MainTimelineRoute.name), 1);

        await tester.binding.handlePopRoute();
        await _pumpFor(tester, const Duration(milliseconds: 800));
        container = _containerOfApp(tester);
        router = container.read(appRouterProvider);
        expect(Store.tryGet(StoreKey.accessToken), isNotNull);
        await _expectPrimaryNavigationState(
          tester,
          container,
          tab: TabEnum.home,
          selectedIndex: kPhotoTabIndex,
          pageType: MainTimelinePage,
          expectedNavigationType: NavigationBar,
        );
        expect(_currentRouteCount(router, MainTimelineRoute.name), 1);
      },
    );

    _realStackSessionTest(
      'MOB-UI-035-$_caseSuffix',
      'persists backup album search, selection, exclusions, and upload scope',
      (tester) async {
        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = const Size(430, 932);
        addTearDown(tester.view.reset);

        await _loadAuthenticatedApp(tester, overrideCancellation: true, closeDriftOnDispose: false);
        final container = _containerOfApp(tester);
        final drift = container.read(driftProvider);
        final albumRepository = container.read(localAlbumRepository);
        final router = container.read(appRouterProvider);
        final user = Store.tryGet(StoreKey.currentUser);
        expect(user, isNotNull);

        final originalSelections = await _albumBackupSelections(container);
        final originalBackupEnabled = SettingsRepository.instance.appConfig.backup.enabled;
        final originalSyncAlbums = SettingsRepository.instance.appConfig.backup.syncAlbums;
        addTearDown(() async {
          await _restoreAlbumBackupSelections(albumRepository, originalSelections);
          await SettingsRepository.instance.write(SettingsKey.backupEnabled, originalBackupEnabled);
          await SettingsRepository.instance.write(SettingsKey.backupSyncAlbums, originalSyncAlbums);
          await drift.close();
        });

        await SettingsRepository.instance.write(SettingsKey.backupEnabled, false);
        await SettingsRepository.instance.write(SettingsKey.backupSyncAlbums, false);
        await _clearAlbumBackupSelections(container);

        final albums = await _waitForBackupAlbumFixtures(
          tester,
          container,
          requiredNames: {
            _backupAlbumSelectionCameraAlbum,
            _backupAlbumSelectionScreenshotsAlbum,
            _backupAlbumSelectionDownloadAlbum,
          },
          duplicatedName: _backupAlbumSelectionDuplicateAlbum,
        );
        final cameraAlbum = _singleAlbumNamed(albums, _backupAlbumSelectionCameraAlbum);
        final screenshotsAlbum = _singleAlbumNamed(albums, _backupAlbumSelectionScreenshotsAlbum);
        final downloadAlbum = _singleAlbumNamed(albums, _backupAlbumSelectionDownloadAlbum);
        final duplicateAlbums = _albumsNamed(albums, _backupAlbumSelectionDuplicateAlbum);
        expect(duplicateAlbums, hasLength(2), reason: 'Expected two same-name fixture albums for duplicate handling');

        unawaited(router.push(const DriftBackupAlbumSelectionRoute()));
        await _pumpUntil(
          tester,
          () => find.byType(DriftBackupAlbumSelectionPage).evaluate().isNotEmpty,
          timeout: const Duration(seconds: 30),
        );

        await _searchBackupAlbums(tester, _backupAlbumSelectionCameraAlbum);
        await _waitForVisibleBackupAlbumTile(tester, _backupAlbumSelectionCameraAlbum);
        final cameraSearchResults = _visibleBackupAlbumNames(tester);
        expect(cameraSearchResults, contains(_backupAlbumSelectionCameraAlbum));
        expect(cameraSearchResults, isNot(contains(_backupAlbumSelectionScreenshotsAlbum)));

        await _tapBackupAlbumTile(tester, _backupAlbumSelectionCameraAlbum);
        await _waitForAlbumSelection(container, cameraAlbum.id, BackupSelection.selected, tester);
        await _clearBackupAlbumSearch(tester);
        await _waitForAlbumSelection(container, cameraAlbum.id, BackupSelection.selected, tester);

        await _tapBackupAlbumTile(tester, _backupAlbumSelectionCameraAlbum);
        await _waitForAlbumSelection(container, cameraAlbum.id, BackupSelection.none, tester);

        await _searchBackupAlbums(tester, _backupAlbumSelectionDuplicateAlbum);
        await _waitForVisibleBackupAlbumTile(tester, _backupAlbumSelectionDuplicateAlbum);
        expect(
          _visibleBackupAlbumNames(tester).where((name) => name == _backupAlbumSelectionDuplicateAlbum),
          hasLength(2),
        );
        await tester.tap(find.widgetWithText(ElevatedButton, 'select_all'.tr()));
        await _pumpFor(tester, const Duration(milliseconds: 800));
        for (final album in duplicateAlbums) {
          await _waitForAlbumSelection(container, album.id, BackupSelection.selected, tester);
        }
        await _clearBackupAlbumSearch(tester);

        await _searchBackupAlbums(tester, _backupAlbumSelectionScreenshotsAlbum);
        await _waitForVisibleBackupAlbumTile(tester, _backupAlbumSelectionScreenshotsAlbum);
        await _tapBackupAlbumTile(tester, _backupAlbumSelectionScreenshotsAlbum);
        await _waitForAlbumSelection(container, screenshotsAlbum.id, BackupSelection.selected, tester);
        await _clearBackupAlbumSearch(tester);

        await _searchBackupAlbums(tester, _backupAlbumSelectionDownloadAlbum);
        await _waitForVisibleBackupAlbumTile(tester, _backupAlbumSelectionDownloadAlbum);
        await _doubleTapBackupAlbumTile(tester, _backupAlbumSelectionDownloadAlbum);
        await _waitForAlbumSelection(container, downloadAlbum.id, BackupSelection.excluded, tester);
        expect(
          await _albumSelection(container, downloadAlbum.id),
          isNot(BackupSelection.selected),
          reason: 'An excluded album must be mutually exclusive with selected backup albums',
        );

        await _popBackupAlbumSelectionPage(tester);

        final selectedAlbumIds = {screenshotsAlbum.id, ...duplicateAlbums.map((album) => album.id)};
        final excludedAlbumIds = {downloadAlbum.id};
        await _expectAlbumSelections(container, {
          cameraAlbum.id: BackupSelection.none,
          screenshotsAlbum.id: BackupSelection.selected,
          for (final album in duplicateAlbums) album.id: BackupSelection.selected,
          downloadAlbum.id: BackupSelection.excluded,
        });
        final expectedTotal = await _expectedBackupAssetTotal(container, selectedAlbumIds, excludedAlbumIds);
        final counts = await container.read(foregroundUploadServiceProvider).getBackupCounts(user!.id);
        expect(counts.total, expectedTotal);

        unawaited(router.push(const DriftBackupAlbumSelectionRoute()));
        await _pumpUntil(
          tester,
          () => find.byType(DriftBackupAlbumSelectionPage).evaluate().isNotEmpty,
          timeout: const Duration(seconds: 30),
        );
        await container.read(backupAlbumProvider.notifier).getAll();
        await _expectAlbumSelections(container, {
          screenshotsAlbum.id: BackupSelection.selected,
          for (final album in duplicateAlbums) album.id: BackupSelection.selected,
          downloadAlbum.id: BackupSelection.excluded,
        });
        await _popBackupAlbumSelectionPage(tester);
      },
    );

    _realStackSessionTest(
      'MOB-UI-036-$_caseSuffix',
      'preserves backup toggles, network, charging, and background options',
      (tester) async {
        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = const Size(430, 932);
        addTearDown(tester.view.reset);

        await _loadAuthenticatedApp(tester, overrideCancellation: true, closeDriftOnDispose: false);
        final container = _containerOfApp(tester);
        final drift = container.read(driftProvider);
        final albumRepository = container.read(localAlbumRepository);
        final router = container.read(appRouterProvider);
        final apiService = container.read(apiServiceProvider);
        final user = Store.tryGet(StoreKey.currentUser);
        expect(user, isNotNull);

        final originalSelections = await _albumBackupSelections(container);
        final originalBackupEnabled = SettingsRepository.instance.appConfig.backup.enabled;
        final originalCellularPhotos = SettingsRepository.instance.appConfig.backup.useCellularForPhotos;
        final originalCellularVideos = SettingsRepository.instance.appConfig.backup.useCellularForVideos;
        final originalRequireCharging = SettingsRepository.instance.appConfig.backup.requireCharging;
        final originalTriggerDelay = SettingsRepository.instance.appConfig.backup.triggerDelay;
        final originalSyncAlbums = SettingsRepository.instance.appConfig.backup.syncAlbums;
        final beforeServerIds = await _serverAssetIdsByOriginalFilename(
          apiService.searchApi,
          _backupSettingsAssetName,
        ).timeout(const Duration(seconds: 30));
        final beforeServerAlbumIds = await _serverAlbumIdsByName(
          apiService.albumsApi,
          _backupSettingsAlbumName,
        ).timeout(const Duration(seconds: 30));

        addTearDown(() async {
          try {
            container.read(driftBackupProvider.notifier).stopForegroundBackup(reason: 'MOB-UI-036 cleanup');
          } catch (_) {
            // The ProviderScope may already have disposed the notifier.
          }
          await SettingsRepository.instance.write(SettingsKey.backupEnabled, originalBackupEnabled);
          await SettingsRepository.instance.write(SettingsKey.backupUseCellularForPhotos, originalCellularPhotos);
          await SettingsRepository.instance.write(SettingsKey.backupUseCellularForVideos, originalCellularVideos);
          await SettingsRepository.instance.write(SettingsKey.backupRequireCharging, originalRequireCharging);
          await SettingsRepository.instance.write(SettingsKey.backupTriggerDelay, originalTriggerDelay);
          await SettingsRepository.instance.write(SettingsKey.backupSyncAlbums, originalSyncAlbums);
          await _restoreAlbumBackupSelections(albumRepository, originalSelections);

          final afterServerIds = await _serverAssetIdsByOriginalFilename(
            apiService.searchApi,
            _backupSettingsAssetName,
          );
          for (final remoteId in afterServerIds.difference(beforeServerIds)) {
            await _deleteTestAssetBestEffort(apiService.assetsApi, remoteId);
          }
          final afterServerAlbumIds = await _serverAlbumIdsByName(apiService.albumsApi, _backupSettingsAlbumName);
          for (final albumId in afterServerAlbumIds.difference(beforeServerAlbumIds)) {
            await _deleteAlbumBestEffort(apiService.albumsApi, albumId);
          }
          await drift.close();
        });

        await SettingsRepository.instance.write(SettingsKey.backupEnabled, false);
        await SettingsRepository.instance.write(SettingsKey.backupUseCellularForPhotos, false);
        await SettingsRepository.instance.write(SettingsKey.backupUseCellularForVideos, false);
        await SettingsRepository.instance.write(SettingsKey.backupRequireCharging, false);
        await SettingsRepository.instance.write(SettingsKey.backupTriggerDelay, 5);
        await SettingsRepository.instance.write(SettingsKey.backupSyncAlbums, false);
        await _clearAlbumBackupSelections(container);

        final albums = await _waitForBackupAlbumFixtures(tester, container, requiredNames: {_backupSettingsAlbumName});
        final settingsAlbum = _singleAlbumNamed(albums, _backupSettingsAlbumName);
        await albumRepository.upsert(settingsAlbum.copyWith(backupSelection: BackupSelection.selected));
        await container.read(backupAlbumProvider.notifier).getAll();

        final initialCounts = await container.read(foregroundUploadServiceProvider).getBackupCounts(user!.id);
        expect(
          initialCounts.total,
          greaterThanOrEqualTo(1),
          reason: 'Expected the settings fixture album to be in scope',
        );
        expect(await container.read(backgroundUploadServiceProvider).getActiveTasks(kBackupGroup), isEmpty);

        unawaited(router.push(const DriftBackupRoute()));
        await _pumpUntil(
          tester,
          () => find.byType(DriftBackupPage).evaluate().isNotEmpty,
          timeout: const Duration(seconds: 30),
        );
        await pumpUntilFound(tester, find.byType(BackupToggleButton), timeout: const Duration(seconds: 30));
        expect(find.textContaining(_backupSettingsAlbumName), findsWidgets);
        _expectBackupPageSwitchValue(tester, false);

        await _setBackupPageSwitch(tester, true);
        await _waitForBackupSetting(tester, SettingsKey.backupEnabled, true);
        _expectBackupPageSwitchValue(tester, true);

        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await _pumpFor(tester, const Duration(milliseconds: 500));
        expect(SettingsRepository.instance.appConfig.backup.enabled, isTrue);
        await _setBackupPageSwitch(tester, false);
        await _waitForBackupSetting(tester, SettingsKey.backupEnabled, false);
        expect(container.read(driftBackupProvider).uploadItems, isEmpty);

        await _openDriftBackupOptionsPage(tester);
        await _expectBackupOptionSwitch(tester, titleKey: 'videos', expected: false);
        await _expectBackupOptionSwitch(tester, titleKey: 'photos', expected: false);
        await _expectBackupOptionSwitch(tester, titleKey: 'charging', expected: false);
        await _expectBackupOptionSwitch(tester, titleKey: 'sync_albums', expected: false);
        expect(find.text('network_requirement_videos_upload'.tr()), findsWidgets);
        expect(find.text('network_requirement_photos_upload'.tr()), findsWidgets);
        expect(find.text('charging_requirement_mobile_backup'.tr()), findsWidgets);

        await _setBackupOptionSwitch(
          tester,
          titleKey: 'videos',
          settingKey: SettingsKey.backupUseCellularForVideos,
          expected: true,
        );
        await _setBackupOptionSwitch(
          tester,
          titleKey: 'photos',
          settingKey: SettingsKey.backupUseCellularForPhotos,
          expected: true,
        );
        await _setBackupOptionSwitch(
          tester,
          titleKey: 'charging',
          settingKey: SettingsKey.backupRequireCharging,
          expected: true,
        );
        await _setBackupDelaySlider(tester, 2);
        await _waitForBackupSetting(tester, SettingsKey.backupTriggerDelay, 120);

        await _setBackupOptionSwitch(
          tester,
          titleKey: 'sync_albums',
          settingKey: SettingsKey.backupSyncAlbums,
          expected: true,
        );
        await _ensureBackupOptionTextVisible(tester, 'organize_into_albums');
        expect(find.text('organize_into_albums'.tr()), findsWidgets);
        await _setBackupOptionSwitch(
          tester,
          titleKey: 'sync_albums',
          settingKey: SettingsKey.backupSyncAlbums,
          expected: false,
        );
        await _pumpUntil(
          tester,
          () => find.text('organize_into_albums'.tr()).evaluate().isEmpty,
          timeout: const Duration(seconds: 10),
        );
        await _setBackupOptionSwitch(
          tester,
          titleKey: 'sync_albums',
          settingKey: SettingsKey.backupSyncAlbums,
          expected: true,
        );

        await router.maybePop();
        await _pumpUntil(
          tester,
          () => find.byType(DriftBackupOptionsPage).evaluate().isEmpty,
          timeout: const Duration(seconds: 30),
        );
        await _openDriftBackupOptionsPage(tester);
        await _expectBackupOptionSwitch(tester, titleKey: 'videos', expected: true);
        await _expectBackupOptionSwitch(tester, titleKey: 'photos', expected: true);
        await _expectBackupOptionSwitch(tester, titleKey: 'charging', expected: true);
        await _expectBackupOptionSwitch(tester, titleKey: 'sync_albums', expected: true);
        expect(SettingsRepository.instance.appConfig.backup.triggerDelay, 120);

        await router.maybePop();
        await _pumpUntil(
          tester,
          () => find.byType(DriftBackupOptionsPage).evaluate().isEmpty,
          timeout: const Duration(seconds: 30),
        );
        await _setBackupPageSwitch(tester, true);
        await _waitForBackupSetting(tester, SettingsKey.backupEnabled, true);
        expect(SettingsRepository.instance.appConfig.backup.useCellularForPhotos, isTrue);
        expect(SettingsRepository.instance.appConfig.backup.useCellularForVideos, isTrue);
        expect(SettingsRepository.instance.appConfig.backup.requireCharging, isTrue);
        expect(SettingsRepository.instance.appConfig.backup.syncAlbums, isTrue);
        expect(SettingsRepository.instance.appConfig.backup.triggerDelay, 120);
        await _setBackupPageSwitch(tester, false);
        await _waitForBackupSetting(tester, SettingsKey.backupEnabled, false);
      },
    );

    _realStackSessionTest(
      'MOB-UI-037-$_caseSuffix',
      'shows upload queue progress, details, failure, retry, and cancellation',
      (tester) async {
        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = const Size(430, 932);
        addTearDown(tester.view.reset);

        await _loadAuthenticatedApp(tester, overrideCancellation: true, closeDriftOnDispose: false);
        final container = _containerOfApp(tester);
        final drift = container.read(driftProvider);
        final albumRepository = container.read(localAlbumRepository);
        final router = container.read(appRouterProvider);
        final apiService = container.read(apiServiceProvider);
        final user = Store.tryGet(StoreKey.currentUser);
        expect(user, isNotNull);

        final originalEndpoint = Store.get(StoreKey.serverEndpoint);
        final originalServerUrl = Store.get(StoreKey.serverUrl);
        final originalSelections = await _albumBackupSelections(container);
        final originalBackupEnabled = SettingsRepository.instance.appConfig.backup.enabled;
        final originalCellularPhotos = SettingsRepository.instance.appConfig.backup.useCellularForPhotos;
        final originalCellularVideos = SettingsRepository.instance.appConfig.backup.useCellularForVideos;
        final originalRequireCharging = SettingsRepository.instance.appConfig.backup.requireCharging;
        final originalSyncAlbums = SettingsRepository.instance.appConfig.backup.syncAlbums;
        final beforeSuccessIds = await _serverAssetIdsByOriginalFilename(
          apiService.searchApi,
          _uploadQueueSuccessAssetName,
        ).timeout(const Duration(seconds: 30));
        final beforeRetryIds = await _serverAssetIdsByOriginalFilename(
          apiService.searchApi,
          _uploadQueueRetryAssetName,
        ).timeout(const Duration(seconds: 30));

        addTearDown(() async {
          try {
            container.read(driftBackupProvider.notifier).stopForegroundBackup(reason: 'MOB-UI-037 cleanup');
          } catch (_) {
            // The ProviderScope may already have disposed the notifier.
          }
          await Store.put(StoreKey.serverEndpoint, originalEndpoint);
          await Store.put(StoreKey.serverUrl, originalServerUrl);
          apiService.setEndpoint(originalEndpoint);
          await apiService.updateHeaders();
          await SettingsRepository.instance.write(SettingsKey.backupEnabled, originalBackupEnabled);
          await SettingsRepository.instance.write(SettingsKey.backupUseCellularForPhotos, originalCellularPhotos);
          await SettingsRepository.instance.write(SettingsKey.backupUseCellularForVideos, originalCellularVideos);
          await SettingsRepository.instance.write(SettingsKey.backupRequireCharging, originalRequireCharging);
          await SettingsRepository.instance.write(SettingsKey.backupSyncAlbums, originalSyncAlbums);
          await _restoreAlbumBackupSelections(albumRepository, originalSelections);

          final afterSuccessIds = await _serverAssetIdsByOriginalFilename(
            apiService.searchApi,
            _uploadQueueSuccessAssetName,
          );
          for (final remoteId in afterSuccessIds.difference(beforeSuccessIds)) {
            await _deleteTestAssetBestEffort(apiService.assetsApi, remoteId);
          }
          final afterRetryIds = await _serverAssetIdsByOriginalFilename(
            apiService.searchApi,
            _uploadQueueRetryAssetName,
          );
          for (final remoteId in afterRetryIds.difference(beforeRetryIds)) {
            await _deleteTestAssetBestEffort(apiService.assetsApi, remoteId);
          }
          await drift.close();
        });

        await SettingsRepository.instance.write(SettingsKey.backupEnabled, false);
        await SettingsRepository.instance.write(SettingsKey.backupUseCellularForPhotos, true);
        await SettingsRepository.instance.write(SettingsKey.backupUseCellularForVideos, true);
        await SettingsRepository.instance.write(SettingsKey.backupRequireCharging, false);
        await SettingsRepository.instance.write(SettingsKey.backupSyncAlbums, false);
        await _clearAlbumBackupSelections(container);

        final albums = await _waitForBackupAlbumFixtures(tester, container, requiredNames: {_uploadQueueAlbumName});
        final uploadQueueAlbum = _singleAlbumNamed(albums, _uploadQueueAlbumName);
        await albumRepository.upsert(uploadQueueAlbum.copyWith(backupSelection: BackupSelection.selected));
        await container.read(backupAlbumProvider.notifier).getAll();

        final successAsset = await _waitForLocalAssetByName(container, _uploadQueueSuccessAssetName, tester);
        final retryAsset = await _waitForLocalAssetByName(container, _uploadQueueRetryAssetName, tester);
        expect(successAsset.localId, isNotNull);
        expect(retryAsset.localId, isNotNull);
        final targetLocalIds = {successAsset.localId!, retryAsset.localId!};

        final counts = await container.read(foregroundUploadServiceProvider).getBackupCounts(user!.id);
        expect(counts.remainder, greaterThanOrEqualTo(2));

        unawaited(router.push(const DriftBackupAssetDetailRoute()));
        await _pumpUntil(
          tester,
          () => find.byType(DriftBackupAssetDetailPage).evaluate().isNotEmpty,
          timeout: const Duration(seconds: 30),
        );
        await _ensureUploadQueueTextVisible(tester, _uploadQueueSuccessAssetName, pageType: DriftBackupAssetDetailPage);
        await _ensureUploadQueueTextVisible(tester, _uploadQueueRetryAssetName, pageType: DriftBackupAssetDetailPage);
        await _ensureUploadQueueTextVisible(tester, _uploadQueueAlbumName, pageType: DriftBackupAssetDetailPage);
        await router.maybePop();
        await _pumpUntil(
          tester,
          () => find.byType(DriftBackupAssetDetailPage).evaluate().isEmpty,
          timeout: const Duration(seconds: 30),
        );

        unawaited(router.push(const DriftUploadDetailRoute()));
        await _pumpUntil(
          tester,
          () => find.byType(DriftUploadDetailPage).evaluate().isNotEmpty,
          timeout: const Duration(seconds: 30),
        );
        expect(find.text('upload_details'.tr()), findsWidgets);

        final realUpload = container.read(driftBackupProvider.notifier).startForegroundBackup(user.id);
        final progressItems = await _waitForUploadItems(
          tester,
          container,
          (items) {
            final item = items[retryAsset.localId!];
            return item != null && item.isFailed != true && item.progress < 1.0;
          },
          reason: 'Expected the large retry asset to appear as an active upload item before cancellation',
          timeout: const Duration(seconds: 60),
        );
        final activeRetry = progressItems[retryAsset.localId!]!;
        expect(activeRetry.filename, _uploadQueueRetryAssetName);
        expect(activeRetry.fileSize, greaterThan(1024 * 1024));
        expect(activeRetry.progress, inInclusiveRange(0.0, 1.0));
        await _ensureUploadQueueTextVisible(tester, _uploadQueueRetryAssetName);
        await tester.tap(find.textContaining(_uploadQueueRetryAssetName).first);
        await pumpUntilFound(tester, find.byType(FileDetailDialog), timeout: const Duration(seconds: 30));
        await pumpUntilFound(
          tester,
          find.textContaining(_uploadQueueRetryAssetName),
          timeout: const Duration(seconds: 30),
        );
        expect(find.textContaining(retryAsset.localId!), findsWidgets);
        expect(find.textContaining('file_size'.tr()), findsWidgets);
        await tester.tap(find.text('close'.tr()).last);
        await _pumpUntil(
          tester,
          () => find.byType(FileDetailDialog).evaluate().isEmpty,
          timeout: const Duration(seconds: 30),
        );

        container.read(driftBackupProvider.notifier).stopForegroundBackup(reason: 'MOB-UI-037 cancel progress probe');
        await _waitForUploadItems(
          tester,
          container,
          (items) => items.isEmpty,
          reason: 'Expected cancelling the foreground upload to clear upload detail items',
        );
        await realUpload.timeout(const Duration(minutes: 2));

        await Store.put(StoreKey.serverEndpoint, _apiEndpoint(_badServerUrl));
        await Store.put(StoreKey.serverUrl, _apiEndpoint(_badServerUrl));
        final failingUpload = container.read(driftBackupProvider.notifier).startForegroundBackup(user.id);
        final failedItems = await _waitForUploadItems(
          tester,
          container,
          (items) => targetLocalIds.any((id) => items[id]?.isFailed == true),
          reason: 'Expected an upload failure when the server endpoint is unreachable',
          timeout: const Duration(seconds: 60),
        );
        final failedStatus = targetLocalIds
            .map((id) => failedItems[id])
            .whereType<DriftUploadStatus>()
            .firstWhere((item) => item.isFailed == true);
        expect(failedStatus.error, isNotNull);
        final failureNeedle = failedStatus.error!.length > 24
            ? failedStatus.error!.substring(0, 24)
            : failedStatus.error!;
        await _ensureUploadQueueTextVisible(tester, failureNeedle);
        expect(find.byIcon(Icons.error_rounded), findsWidgets);
        await failingUpload.timeout(const Duration(minutes: 2));

        container.read(driftBackupProvider.notifier).stopForegroundBackup(reason: 'MOB-UI-037 retry after failure');
        await Store.put(StoreKey.serverEndpoint, originalEndpoint);
        await Store.put(StoreKey.serverUrl, originalServerUrl);
        apiService.setEndpoint(originalEndpoint);
        await apiService.updateHeaders();

        await container
            .read(driftBackupProvider.notifier)
            .startForegroundBackup(user.id)
            .timeout(const Duration(minutes: 5));
        final successIds = await _waitForServerAssetIdsByOriginalFilename(
          tester,
          apiService.searchApi,
          _uploadQueueSuccessAssetName,
          (ids) => ids.difference(beforeSuccessIds).length == 1,
          reason: 'Expected the success upload asset to be created exactly once',
          timeout: const Duration(seconds: 90),
        );
        final retryIds = await _waitForServerAssetIdsByOriginalFilename(
          tester,
          apiService.searchApi,
          _uploadQueueRetryAssetName,
          (ids) => ids.difference(beforeRetryIds).length == 1,
          reason: 'Expected the retry upload asset to be created exactly once',
          timeout: const Duration(seconds: 90),
        );

        final duplicateRemoteId = await _uploadSingleAssetToServer(container, retryAsset);
        expect(retryIds.difference(beforeRetryIds), contains(duplicateRemoteId));
        expect(await _serverAssetIdsByOriginalFilename(apiService.searchApi, _uploadQueueRetryAssetName), retryIds);
        expect(successIds.difference(beforeSuccessIds), hasLength(1));
      },
    );

    _realStackSessionTest(
      'MOB-UI-038-$_caseSuffix',
      'keeps multiselect state across taps, bucket selection, scrolling, and exit',
      (tester) async {
        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = const Size(430, 932);
        addTearDown(tester.view.reset);

        await _loadAuthenticatedApp(tester, overrideCancellation: true);
        final container = _containerOfApp(tester);
        final router = container.read(appRouterProvider);
        final apiService = container.read(apiServiceProvider);
        final createdRemoteAssetIds = <String>{};
        final user = Store.tryGet(StoreKey.currentUser);
        expect(user, isNotNull);

        addTearDown(() async {
          try {
            container.read(multiSelectProvider.notifier).reset();
          } catch (_) {
            // ProviderScope may already be disposed when earlier expectations fail.
          }
          for (final assetId in createdRemoteAssetIds) {
            await _deleteTestAssetBestEffort(apiService.assetsApi, assetId);
          }
        });

        await container.read(backgroundSyncProvider).syncLocal(full: true);
        await container.read(backgroundSyncProvider).syncRemote();
        await _pumpFor(tester, const Duration(seconds: 2));
        await pumpUntilFound(tester, find.byType(Timeline), timeout: const Duration(seconds: 60));

        final mainTimeline = container.read(timelineServiceProvider);
        final buckets = await _ensureMultiSelectTimelineAssets(tester, container, mainTimeline, createdRemoteAssetIds);
        expect(buckets.length, greaterThanOrEqualTo(2));
        expect(mainTimeline.totalAssets, greaterThanOrEqualTo(_multiSelectMinimumAssetCount));

        await _waitForVisibleTimelineAssetTiles(tester, minCount: 3);
        expect(find.byType(NavigationBar), findsWidgets);
        final firstTile = _timelineAssetTiles().first;
        final firstAsset = _assetFromTimelineTile(tester, firstTile);

        await tester.longPress(firstTile);
        await _waitForMultiSelectCount(tester, container, 1);
        expect(container.read(multiSelectProvider).selectedAssets, contains(firstAsset));
        await _pumpUntil(
          tester,
          () => find.byType(NavigationBar).evaluate().isEmpty,
          timeout: const Duration(seconds: 10),
        );
        expect(find.widgetWithText(ElevatedButton, '1'), findsOneWidget);

        await tester.tap(_timelineAssetTiles().at(1));
        await _waitForMultiSelectCount(tester, container, 2);
        final secondAsset = _assetFromTimelineTile(tester, _timelineAssetTiles().at(1));
        expect(container.read(multiSelectProvider).selectedAssets, contains(secondAsset));
        await tester.tap(_timelineAssetTileForAsset(secondAsset));
        await _waitForMultiSelectCount(tester, container, 1);
        expect(container.read(multiSelectProvider).selectedAssets, isNot(contains(secondAsset)));

        final mainScrollable = find.descendant(of: find.byType(Timeline), matching: find.byType(Scrollable)).first;
        await tester.fling(mainScrollable, const Offset(0, -1400), 1600);
        await _pumpFor(tester, const Duration(seconds: 1));
        expect(container.read(multiSelectProvider).selectedAssets, contains(firstAsset));
        await _waitForVisibleTimelineAssetTiles(tester, minCount: 1);
        final scrolledAsset = _firstVisibleTimelineAssetWhere(
          tester,
          (asset) => !container.read(multiSelectProvider).selectedAssets.contains(asset),
          minCenterY: 240,
          bottomPadding: 120,
        );
        await tester.tap(_timelineAssetTileForAsset(scrolledAsset));
        await _waitForMultiSelectCount(tester, container, 2);
        expect(container.read(multiSelectProvider).selectedAssets, containsAll([firstAsset, scrolledAsset]));

        await tester.binding.handlePopRoute();
        await _waitForMultiSelectCount(tester, container, 0);
        await _pumpUntil(
          tester,
          () => find.byType(NavigationBar).evaluate().isNotEmpty,
          timeout: const Duration(seconds: 10),
        );
        expect(container.read(multiSelectProvider).isEnabled, isFalse);

        unawaited(router.push(DriftAssetSelectionTimelineRoute()));
        await _pumpUntil(
          tester,
          () => find.byType(DriftAssetSelectionTimelinePage).evaluate().isNotEmpty,
          timeout: const Duration(seconds: 30),
        );
        await pumpUntilFound(tester, find.byType(SelectionSliverAppBar), timeout: const Duration(seconds: 30));
        final selectionContainer = ProviderScope.containerOf(tester.element(find.byType(Timeline).last), listen: false);
        expect(selectionContainer.read(multiSelectProvider).forceEnable, isTrue);
        await _waitForVisibleTimelineAssetTiles(tester, minCount: 3);
        expect(find.byType(NavigationBar), findsNothing);

        final routeFirstAsset = _assetFromTimelineTile(tester, _timelineAssetTiles().first);
        await tester.tap(_timelineAssetTiles().first);
        await _waitForMultiSelectCount(tester, selectionContainer, 1);
        expect(selectionContainer.read(multiSelectProvider).selectedAssets, contains(routeFirstAsset));
        expect(find.textContaining('1'), findsWidgets);

        final bucketSelectButton = find.descendant(of: find.byType(TimelineHeader), matching: find.byType(IconButton));
        await pumpUntilFound(tester, bucketSelectButton, timeout: const Duration(seconds: 30));
        final beforeBucketCount = selectionContainer.read(multiSelectProvider).selectedAssets.length;
        await tester.tap(bucketSelectButton.first);
        await _pumpUntil(
          tester,
          () => selectionContainer.read(multiSelectProvider).selectedAssets.length > beforeBucketCount,
          timeout: const Duration(seconds: 30),
        );
        final afterBucketCount = selectionContainer.read(multiSelectProvider).selectedAssets.length;
        expect(afterBucketCount, greaterThan(beforeBucketCount));

        final selectionScrollable = find
            .descendant(of: find.byType(Timeline).last, matching: find.byType(Scrollable))
            .first;
        await tester.fling(selectionScrollable, const Offset(0, -1800), 1800);
        await _pumpFor(tester, const Duration(seconds: 1));
        expect(selectionContainer.read(multiSelectProvider).selectedAssets.length, afterBucketCount);
        await _waitForVisibleTimelineAssetTiles(tester, minCount: 1);
        final routeScrolledAsset = _firstVisibleTimelineAssetWhere(
          tester,
          (asset) => !selectionContainer.read(multiSelectProvider).selectedAssets.contains(asset),
          minCenterY: 240,
          bottomPadding: 120,
        );
        await tester.tap(_timelineAssetTileForAsset(routeScrolledAsset));
        await _waitForMultiSelectCount(tester, selectionContainer, afterBucketCount + 1);

        await tester.tap(
          find.descendant(of: find.byType(SelectionSliverAppBar), matching: find.byIcon(Icons.close_rounded)),
        );
        await _pumpUntil(
          tester,
          () => find.byType(DriftAssetSelectionTimelinePage).evaluate().isEmpty,
          timeout: const Duration(seconds: 30),
        );

        unawaited(router.push(DriftAssetSelectionTimelineRoute()));
        await _pumpUntil(
          tester,
          () => find.byType(DriftAssetSelectionTimelinePage).evaluate().isNotEmpty,
          timeout: const Duration(seconds: 30),
        );
        final reenteredContainer = ProviderScope.containerOf(tester.element(find.byType(Timeline).last), listen: false);
        await _waitForMultiSelectCount(tester, reenteredContainer, 0);
        await tester.tap(_timelineAssetTiles().first);
        await _waitForMultiSelectCount(tester, reenteredContainer, 1);
        await tester.tap(
          find.descendant(of: find.byType(SelectionSliverAppBar), matching: find.byIcon(Icons.close_rounded)),
        );
      },
    );

    _realStackSessionTest('MOB-UI-039-$_caseSuffix', 'supports bulk favorite, unfavorite, archive, and archive undo', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(430, 932);
      addTearDown(tester.view.reset);

      await _loadAuthenticatedApp(tester, overrideCancellation: true);
      final container = _containerOfApp(tester);
      final router = container.read(appRouterProvider);
      final apiService = container.read(apiServiceProvider);
      final assetsApi = apiService.assetsApi;
      final createdRemoteAssetIds = <String>{};
      final user = Store.tryGet(StoreKey.currentUser);
      expect(user, isNotNull);

      addTearDown(() async {
        try {
          container.read(multiSelectProvider.notifier).reset();
        } catch (_) {
          // ProviderScope may already be disposed when an earlier expectation fails.
        }
        for (final assetId in createdRemoteAssetIds) {
          await _deleteTestAssetBestEffort(assetsApi, assetId);
        }
      });

      await container.read(syncApiRepositoryProvider).deleteSyncAck(_allReplayableSyncAckTypes);
      await Store.delete(StoreKey.syncMigrationStatus);
      await container.read(syncStreamRepositoryProvider).reset();
      final baselineSyncSuccess = await container.read(syncStreamServiceProvider).sync();
      expect(baselineSyncSuccess, isTrue);

      final runToken = DateTime.now().toUtc().microsecondsSinceEpoch.toString();
      final baseCreatedAt = DateTime.now().toUtc();
      final favoriteTargetId = await _uploadGeneratedJpegAsSecondClient(
        'immich-e2e-bulk-action-039-favorite-target-$runToken.jpg',
        baseCreatedAt.subtract(const Duration(seconds: 1)),
      );
      createdRemoteAssetIds.add(favoriteTargetId);
      final alreadyFavoriteId = await _uploadGeneratedJpegAsSecondClient(
        'immich-e2e-bulk-action-039-already-favorite-$runToken.jpg',
        baseCreatedAt.subtract(const Duration(seconds: 2)),
        isFavorite: true,
      );
      createdRemoteAssetIds.add(alreadyFavoriteId);
      final archiveTargetId = await _uploadGeneratedJpegAsSecondClient(
        'immich-e2e-bulk-action-039-archive-target-$runToken.jpg',
        baseCreatedAt.subtract(const Duration(seconds: 3)),
      );
      createdRemoteAssetIds.add(archiveTargetId);
      final alreadyArchivedId = await _uploadGeneratedJpegAsSecondClient(
        'immich-e2e-bulk-action-039-already-archived-$runToken.jpg',
        baseCreatedAt.subtract(const Duration(seconds: 4)),
        visibility: api.AssetVisibility.archive,
      );
      createdRemoteAssetIds.add(alreadyArchivedId);

      for (final assetId in createdRemoteAssetIds) {
        await _waitForSuccessfulResponse(
          tester,
          () => assetsApi.viewAssetWithHttpInfo(assetId, size: api.AssetMediaSize.thumbnail),
        );
      }

      final initialSyncSuccess = await container.read(syncStreamServiceProvider).sync();
      expect(initialSyncSuccess, isTrue);
      await _pumpFor(tester, const Duration(seconds: 2));
      await pumpUntilFound(tester, find.byType(Timeline), timeout: const Duration(seconds: 60));

      await _waitForRemoteAssetState(
        tester,
        container,
        favoriteTargetId,
        (asset) => asset.visibility == AssetVisibility.timeline && !asset.isFavorite,
        reason: 'Expected favorite target to sync as an unfavorited timeline asset',
      );
      await _waitForRemoteAssetState(
        tester,
        container,
        alreadyFavoriteId,
        (asset) => asset.visibility == AssetVisibility.timeline && asset.isFavorite,
        reason: 'Expected favorite control to sync as an already favorited timeline asset',
      );
      await _waitForRemoteAssetState(
        tester,
        container,
        archiveTargetId,
        (asset) => asset.visibility == AssetVisibility.timeline && !asset.isFavorite,
        reason: 'Expected archive target to sync as a plain timeline asset',
      );
      await _waitForRemoteAssetState(
        tester,
        container,
        alreadyArchivedId,
        (asset) => asset.visibility == AssetVisibility.archive,
        reason: 'Expected archived control to sync as an archived asset',
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
        includes: {favoriteTargetId, alreadyFavoriteId, archiveTargetId},
        excludes: {alreadyArchivedId},
        reason: 'Initial main timeline should include only unarchived bulk-action assets',
      );
      await _expectTimelineAssetSet(
        tester,
        favoriteTimeline,
        includes: {alreadyFavoriteId},
        excludes: {favoriteTargetId, archiveTargetId, alreadyArchivedId},
        reason: 'Initial favorite timeline should include only the pre-favorited asset',
      );
      await _expectTimelineAssetSet(
        tester,
        archiveTimeline,
        includes: {alreadyArchivedId},
        excludes: {favoriteTargetId, alreadyFavoriteId, archiveTargetId},
        reason: 'Initial archive timeline should include only the pre-archived asset',
      );

      await _selectTimelineAssetsById(tester, container, [favoriteTargetId, alreadyFavoriteId]);
      expect(_bottomSheetIcon(GeneralBottomSheet, Icons.favorite_border_rounded), findsOneWidget);
      expect(_bottomSheetIcon(GeneralBottomSheet, Icons.favorite_rounded), findsNothing);
      await _tapBottomSheetAction(tester, GeneralBottomSheet, Icons.favorite_border_rounded);
      await _waitForMultiSelectCount(tester, container, 0);
      await _waitForAssetInfoState(
        tester,
        assetsApi,
        favoriteTargetId,
        (asset) => asset.isFavorite && asset.visibility == api.AssetVisibility.timeline,
        reason: 'Expected selected unfavorited asset to become favorite on the server',
      );
      await _waitForAssetInfoState(
        tester,
        assetsApi,
        alreadyFavoriteId,
        (asset) => asset.isFavorite && asset.visibility == api.AssetVisibility.timeline,
        reason: 'Expected selected already-favorited asset to remain favorite on the server',
      );
      await _expectTimelineAssetSet(
        tester,
        favoriteTimeline,
        includes: {favoriteTargetId, alreadyFavoriteId},
        excludes: {archiveTargetId, alreadyArchivedId},
        reason: 'Favorite timeline should immediately include both selected favorites',
      );

      unawaited(router.push(const DriftFavoriteRoute()));
      await pumpUntilFound(tester, find.byType(DriftFavoritePage), timeout: const Duration(seconds: 30));
      final favoriteContainer = ProviderScope.containerOf(tester.element(find.byType(Timeline).last), listen: false);
      await _selectTimelineAssetsById(tester, favoriteContainer, [favoriteTargetId, alreadyFavoriteId]);
      expect(_bottomSheetIcon(FavoriteBottomSheet, Icons.favorite_rounded), findsOneWidget);
      await _tapBottomSheetAction(tester, FavoriteBottomSheet, Icons.favorite_rounded);
      await _waitForMultiSelectCount(tester, favoriteContainer, 0);
      for (final assetId in [favoriteTargetId, alreadyFavoriteId]) {
        await _waitForAssetInfoState(
          tester,
          assetsApi,
          assetId,
          (asset) => !asset.isFavorite && asset.visibility == api.AssetVisibility.timeline,
          reason: 'Expected selected favorite asset $assetId to be removed from favorites',
        );
      }
      await _expectTimelineAssetSet(
        tester,
        favoriteTimeline,
        includes: const {},
        excludes: {favoriteTargetId, alreadyFavoriteId, archiveTargetId, alreadyArchivedId},
        reason: 'Favorite timeline should drop the bulk-unfavorited assets immediately',
      );

      await router.maybePop();
      await _pumpUntil(
        tester,
        () => find.byType(DriftFavoritePage).evaluate().isEmpty,
        timeout: const Duration(seconds: 30),
      );
      await pumpUntilFound(tester, find.byType(MainTimelinePage), timeout: const Duration(seconds: 30));

      await _selectTimelineAssetsById(tester, container, [favoriteTargetId, archiveTargetId]);
      expect(_bottomSheetIcon(GeneralBottomSheet, Icons.archive_outlined), findsOneWidget);
      await _tapBottomSheetAction(tester, GeneralBottomSheet, Icons.archive_outlined);
      await _waitForMultiSelectCount(tester, container, 0);
      await _waitForRemoteAssetState(
        tester,
        container,
        favoriteTargetId,
        (asset) => asset.visibility == AssetVisibility.archive,
        reason: 'Expected bulk-archived favorite target to update locally before undo',
      );
      await _waitForRemoteAssetState(
        tester,
        container,
        archiveTargetId,
        (asset) => asset.visibility == AssetVisibility.archive,
        reason: 'Expected bulk-archived archive target to update locally before undo',
      );
      await _expectTimelineAssetSet(
        tester,
        archiveTimeline,
        includes: {alreadyArchivedId, favoriteTargetId, archiveTargetId},
        excludes: {alreadyFavoriteId},
        reason: 'Archive timeline should include newly archived assets before undo',
      );

      await _tapSnackbarAction(tester);
      for (final assetId in [favoriteTargetId, archiveTargetId]) {
        await _waitForAssetInfoState(
          tester,
          assetsApi,
          assetId,
          (asset) => !asset.isFavorite && asset.visibility == api.AssetVisibility.timeline,
          reason: 'Expected archive undo to restore asset $assetId to the server timeline',
        );
        await _waitForRemoteAssetState(
          tester,
          container,
          assetId,
          (asset) => !asset.isFavorite && asset.visibility == AssetVisibility.timeline,
          reason: 'Expected archive undo to restore local asset $assetId to the timeline',
        );
      }

      unawaited(router.push(const DriftArchiveRoute()));
      await pumpUntilFound(tester, find.byType(DriftArchivePage), timeout: const Duration(seconds: 30));
      await _expectTimelineAssetSet(
        tester,
        archiveTimeline,
        includes: {alreadyArchivedId},
        excludes: {favoriteTargetId, alreadyFavoriteId, archiveTargetId},
        reason: 'Archive page should retain only the pre-archived control asset after undo',
      );

      final archiveContainer = ProviderScope.containerOf(tester.element(find.byType(Timeline).last), listen: false);
      await _selectTimelineAssetsById(tester, archiveContainer, [alreadyArchivedId]);
      expect(_bottomSheetIcon(ArchiveBottomSheet, Icons.unarchive_outlined), findsOneWidget);
      await _tapBottomSheetAction(tester, ArchiveBottomSheet, Icons.unarchive_outlined);
      await _waitForMultiSelectCount(tester, archiveContainer, 0);
      await _waitForAssetInfoState(
        tester,
        assetsApi,
        alreadyArchivedId,
        (asset) => asset.visibility == api.AssetVisibility.timeline,
        reason: 'Expected unarchive action to restore the archived control to the server timeline',
      );
      final refreshSyncSuccess = await container.read(syncStreamServiceProvider).sync();
      expect(refreshSyncSuccess, isTrue);
      await _expectTimelineAssetSet(
        tester,
        mainTimeline,
        includes: {favoriteTargetId, alreadyFavoriteId, archiveTargetId, alreadyArchivedId},
        excludes: const {},
        reason: 'Bulk-action state should stay stable after a server refresh',
      );
      await _expectTimelineAssetSet(
        tester,
        archiveTimeline,
        includes: const {},
        excludes: {favoriteTargetId, alreadyFavoriteId, archiveTargetId, alreadyArchivedId},
        reason: 'Archive timeline should remain empty for 039 assets after undo and unarchive',
      );
    });

    _realStackSessionTest('MOB-UI-040-$_caseSuffix', 'supports bulk album add, create, and remove flows', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(430, 932);
      addTearDown(tester.view.reset);

      await _loadAuthenticatedApp(tester, overrideCancellation: true);
      final container = _containerOfApp(tester);
      final drift = container.read(driftProvider);
      final router = container.read(appRouterProvider);
      final apiService = container.read(apiServiceProvider);
      final albumsApi = apiService.albumsApi;
      final assetsApi = apiService.assetsApi;
      final createdRemoteAssetIds = <String>[];
      String? existingAlbumId;
      String? newAlbumId;
      final user = Store.tryGet(StoreKey.currentUser);
      expect(user, isNotNull);
      final originalAlbumIsGrid = SettingsRepository.instance.appConfig.album.isGrid;

      addTearDown(() async {
        try {
          await SettingsRepository.instance.write(SettingsKey.albumIsGrid, originalAlbumIsGrid);
          container.read(multiSelectProvider.notifier).reset();
        } catch (_) {
          // ProviderScope may already be disposed when an earlier expectation fails.
        }
        for (final albumId in [newAlbumId, existingAlbumId]) {
          if (albumId != null) {
            await _deleteAlbumBestEffort(albumsApi, albumId);
          }
        }
        for (final assetId in createdRemoteAssetIds) {
          await _deleteTestAssetBestEffort(assetsApi, assetId);
        }
      });

      await container.read(syncApiRepositoryProvider).deleteSyncAck(_allReplayableSyncAckTypes);
      await Store.delete(StoreKey.syncMigrationStatus);
      await container.read(syncStreamRepositoryProvider).reset();
      final baselineSyncSuccess = await container.read(syncStreamServiceProvider).sync();
      expect(baselineSyncSuccess, isTrue);

      final runToken = DateTime.now().toUtc().microsecondsSinceEpoch.toString();
      final baseCreatedAt = DateTime.now().toUtc();
      final assetIds = <String>[];
      for (var index = 0; index < 6; index++) {
        final assetId = await _uploadGeneratedJpegAsSecondClient(
          'immich-e2e-album-actions-040-$index-$runToken.jpg',
          baseCreatedAt.subtract(Duration(seconds: 6 - index)),
        );
        createdRemoteAssetIds.add(assetId);
        assetIds.add(assetId);
      }

      for (final assetId in assetIds) {
        await _waitForSuccessfulResponse(
          tester,
          () => _authenticatedApiGet('/assets/$assetId/thumbnail?size=thumbnail&edited=false&c=$runToken'),
          timeout: const Duration(minutes: 3),
        );
      }

      final existingAlbumName = 'immich-e2e-album-actions-040-existing-$runToken';
      final existingAlbum = await albumsApi.createAlbum(
        api.CreateAlbumDto(albumName: existingAlbumName, assetIds: api.Optional.present([assetIds[0]])),
      );
      expect(existingAlbum, isNotNull);
      existingAlbumId = existingAlbum!.id;

      await _waitForAlbumInfoState(
        tester,
        albumsApi,
        existingAlbumId,
        (album) => album.albumName == existingAlbumName && album.assetCount == 1,
        reason: 'Expected existing 040 album to start with one member',
      );

      final initialSyncSuccess = await container.read(syncStreamServiceProvider).sync();
      expect(initialSyncSuccess, isTrue);
      await _pumpFor(tester, const Duration(seconds: 2));
      await pumpUntilFound(tester, find.byType(Timeline), timeout: const Duration(seconds: 60));

      for (final assetId in assetIds) {
        await _waitForRemoteAssetState(
          tester,
          container,
          assetId,
          (asset) => asset.visibility == AssetVisibility.timeline && !asset.isTrashed,
          reason: 'Expected 040 asset $assetId to sync locally before album actions',
        );
      }
      await _waitForRemoteAlbumAssetIds(
        tester,
        container,
        existingAlbumId,
        includes: {assetIds[0]},
        excludes: {assetIds[1], assetIds[2], assetIds[3], assetIds[4], assetIds[5]},
        reason: 'Expected existing 040 album local membership before UI add',
      );

      await SettingsRepository.instance.write(SettingsKey.albumIsGrid, false);
      await _selectTimelineAssetsById(tester, container, [assetIds[0], assetIds[1]]);
      await _tapAlbumInSelector(tester, GeneralBottomSheet, existingAlbumName);
      await _waitForMultiSelectCount(tester, container, 0, timeout: const Duration(seconds: 30));
      await _waitForAlbumInfoState(
        tester,
        albumsApi,
        existingAlbumId,
        (album) => album.assetCount == 2,
        reason: 'Expected UI add to existing album to add only the missing asset',
      );
      await _waitForRemoteAlbumAssetIds(
        tester,
        container,
        existingAlbumId,
        includes: {assetIds[0], assetIds[1]},
        excludes: {assetIds[2], assetIds[3], assetIds[4], assetIds[5]},
        reason: 'Expected local existing album to contain first two assets after UI add',
      );

      await _selectTimelineAssetsById(tester, container, [assetIds[0], assetIds[1]]);
      await _tapAlbumInSelector(tester, GeneralBottomSheet, existingAlbumName);
      await _waitForMultiSelectCount(tester, container, 0, timeout: const Duration(seconds: 30));
      await _waitForAlbumInfoState(
        tester,
        albumsApi,
        existingAlbumId,
        (album) => album.assetCount == 2,
        reason: 'Expected repeated UI add to existing album to avoid duplicate members',
      );
      expect(await _remoteAlbumAssetRowCountByAlbumId(drift, existingAlbumId), 2);

      final newAlbumName = 'immich-e2e-album-actions-040-new-$runToken';
      await _selectTimelineAssetsById(tester, container, [assetIds[2], assetIds[3], assetIds[4]]);
      await _createAlbumFromBottomSheet(tester, newAlbumName);
      await pumpUntilFound(tester, find.byType(RemoteAlbumPage), timeout: const Duration(seconds: 30));

      final newAlbumIds = await _waitForServerAlbumIdsByName(
        tester,
        albumsApi,
        newAlbumName,
        (ids) => ids.length == 1,
        reason: 'Expected bottom-sheet album creation to create one server album named $newAlbumName',
      );
      newAlbumId = newAlbumIds.single;
      await _waitForAlbumInfoState(
        tester,
        albumsApi,
        newAlbumId,
        (album) => album.assetCount == 3,
        reason: 'Expected newly created album to contain the selected assets',
      );
      await _waitForRemoteAlbumAssetIds(
        tester,
        container,
        newAlbumId,
        includes: {assetIds[2], assetIds[3], assetIds[4]},
        excludes: {assetIds[0], assetIds[1], assetIds[5]},
        reason: 'Expected local new album membership after create flow',
      );

      final albumContainer = ProviderScope.containerOf(tester.element(find.byType(Timeline).last), listen: false);
      await _selectTimelineAssetsById(tester, albumContainer, [assetIds[2], assetIds[3]]);
      expect(_bottomSheetIcon(RemoteAlbumBottomSheet, Icons.remove_circle_outline), findsOneWidget);
      await _tapBottomSheetAction(tester, RemoteAlbumBottomSheet, Icons.remove_circle_outline);
      await _waitForMultiSelectCount(tester, albumContainer, 0, timeout: const Duration(seconds: 30));
      await _waitForAlbumInfoState(
        tester,
        albumsApi,
        newAlbumId,
        (album) => album.assetCount == 1,
        reason: 'Expected removing selected assets from new album to leave one member',
      );
      await _waitForRemoteAlbumAssetIds(
        tester,
        container,
        newAlbumId,
        includes: {assetIds[4]},
        excludes: {assetIds[0], assetIds[1], assetIds[2], assetIds[3], assetIds[5]},
        reason: 'Expected local new album membership to retain only the unselected asset',
      );

      for (final assetId in [assetIds[2], assetIds[3]]) {
        final assetInfo = await assetsApi.getAssetInfo(assetId);
        expect(assetInfo, isNotNull);
        expect(assetInfo!.isTrashed, isFalse, reason: 'Removing $assetId from an album must not delete the asset');
      }

      await router.maybePop();
      await _pumpUntil(
        tester,
        () => find.byType(RemoteAlbumPage).evaluate().isEmpty,
        timeout: const Duration(seconds: 30),
      );
      await pumpUntilFound(tester, find.byType(MainTimelinePage), timeout: const Duration(seconds: 30));
      final refreshSyncSuccess = await container.read(syncStreamServiceProvider).sync();
      expect(refreshSyncSuccess, isTrue);

      final mainTimeline = container.read(timelineFactoryProvider).main([user!.id]);
      addTearDown(mainTimeline.dispose);
      await _expectTimelineAssetSet(
        tester,
        mainTimeline,
        includes: assetIds.toSet(),
        excludes: const {},
        reason: 'Album add/remove actions should not remove assets from the main timeline',
      );
      expect(await _remoteAlbumRowCountById(drift, existingAlbumId), 1);
      expect(await _remoteAlbumRowCountById(drift, newAlbumId), 1);
      expect(await _remoteAlbumAssetRowCountByAlbumId(drift, existingAlbumId), 2);
      expect(await _remoteAlbumAssetRowCountByAlbumId(drift, newAlbumId), 1);
    });

    _realStackSessionTest('MOB-UI-041-$_caseSuffix', 'supports viewer share, download, and browser actions', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(430, 932);
      addTearDown(tester.view.reset);

      await _loadAuthenticatedApp(tester, overrideCancellation: true);
      final container = _containerOfApp(tester);
      final apiService = container.read(apiServiceProvider);
      final assetsApi = apiService.assetsApi;
      final shareInvocations = <_ShareInvocation>[];
      final launchedBrowserUrls = <String>[];
      final downloadUpdates = <TaskStatusUpdate>[];
      final createdRemoteAssetIds = <String>[];
      final user = Store.tryGet(StoreKey.currentUser);
      expect(user, isNotNull);

      _recordSharePlusInvocations(shareInvocations);
      _recordUrlLauncherInvocations(launchedBrowserUrls);
      final downloadService = container.read(downloadServiceProvider);
      final downloadRepository = container.read(downloadRepositoryProvider);
      downloadService.onImageDownloadStatus = downloadUpdates.add;
      downloadService.onVideoDownloadStatus = downloadUpdates.add;

      addTearDown(() async {
        _clearSharePlusInvocationRecorder();
        _clearUrlLauncherInvocationRecorder();
        downloadService.onImageDownloadStatus = null;
        downloadService.onVideoDownloadStatus = null;
        await downloadRepository.deleteRecordsWithIds(createdRemoteAssetIds);
        for (final assetId in createdRemoteAssetIds) {
          await _deleteTestAssetBestEffort(assetsApi, assetId);
        }
      });

      final runToken = DateTime.now().toUtc().microsecondsSinceEpoch.toString();
      final imageName = 'immich-e2e-share-download-browser-041-image-$runToken.jpg';
      final localOnlyName = 'immich-e2e-share-download-browser-041-local-$runToken.jpg';
      final imageId = await _uploadGeneratedJpegAsSecondClient(imageName, DateTime.now().toUtc());
      createdRemoteAssetIds.add(imageId);

      await _waitForSuccessfulResponse(
        tester,
        () => _authenticatedApiGet('/assets/$imageId/thumbnail?size=thumbnail&edited=false&c=$runToken'),
        timeout: const Duration(minutes: 3),
      );

      final createdLocalOnly = await container
          .read(fileMediaRepositoryProvider)
          .saveLocalAsset(
            _generatedJpegBytes(runToken.hashCode),
            title: localOnlyName,
            relativePath: 'Pictures/ImmichE2E041',
          );
      expect(createdLocalOnly, isNotNull);

      await container.read(backgroundSyncProvider).syncLocal(full: true);
      final remoteSyncSuccess = await container.read(syncStreamServiceProvider).sync();
      expect(remoteSyncSuccess, isTrue);
      await _pumpFor(tester, const Duration(seconds: 2));
      await pumpUntilFound(tester, find.byType(Timeline), timeout: const Duration(seconds: 60));

      final remoteImage = await _waitForRemoteAssetState(
        tester,
        container,
        imageId,
        (asset) => asset.isRemoteOnly,
        reason: 'Expected the 041 image to sync as a remote-only asset before download',
      );
      final localOnly = await _waitForLocalAssetByName(container, localOnlyName, tester);
      expect(localOnly.isLocalOnly, isTrue);
      expect(
        await _serverAssetIdsByOriginalFilename(apiService.searchApi, localOnlyName),
        isEmpty,
        reason: 'Local-only 041 fixture must not already exist on the server',
      );

      final timeline = container.read(timelineFactoryProvider).main([user!.id]);
      addTearDown(timeline.dispose);
      final timelineAssets = await _expectTimelineAssetSet(
        tester,
        timeline,
        includes: {imageId},
        excludes: const {},
        reason: 'Expected the 041 remote image in the main timeline before viewer actions',
      );
      final remoteVideo = _firstRemoteVideo(timelineAssets);
      expect(remoteVideo, isNotNull, reason: 'Expected at least one remote video in the real timeline for sharing');

      final mixedShareCount = await container.read(assetMediaRepositoryProvider).shareAssets([
        remoteImage,
        remoteVideo!,
        localOnly,
      ], tester.element(find.byType(MainTimelinePage)));
      expect(mixedShareCount, 3);
      await _waitForShareInvocationCount(tester, shareInvocations, 1);
      _expectSharedDisplayNames(shareInvocations.single, {remoteImage.name, remoteVideo.name, localOnlyName});

      await _openTimelineAsset(tester, remoteImage);
      await _showViewerControls(tester, container);

      await _tapViewerActionIcon(tester, Icons.share_rounded);
      await _waitForShareInvocationCount(tester, shareInvocations, 2);
      _expectSharedDisplayNames(shareInvocations.last, {remoteImage.name});

      await container.read(downloadRepositoryProvider).deleteRecordsWithIds([remoteImage.id]);
      await _tapViewerMenuAction(tester, Icons.download);
      final firstDownloadRecord = await _waitForDownloadRecordStatus(
        tester,
        remoteImage.id,
        TaskStatus.complete,
        reason: 'Expected viewer download to complete for the 041 remote image',
      );
      expect(firstDownloadRecord.group, kDownloadGroupImage);
      expect(firstDownloadRecord.task.filename, remoteImage.name);
      final downloadedLocal = await _waitForLocalAssetByName(container, remoteImage.name, tester);
      expect(downloadedLocal.hasLocal, isTrue);

      final completedDownloadUpdates = downloadUpdates
          .where((update) => update.task.taskId == remoteImage.id && update.status == TaskStatus.complete)
          .length;
      final repeatedDownload = await container.read(downloadRepositoryProvider).downloadAllAssets([remoteImage]);
      expect(repeatedDownload, equals([true]), reason: 'A repeated download should be explicitly accepted for re-save');
      await _waitForDownloadUpdateCount(
        tester,
        downloadUpdates,
        remoteImage.id,
        TaskStatus.complete,
        completedDownloadUpdates + 1,
        reason: 'Expected repeated download to run to completion instead of being silently ignored',
      );

      await _tapViewerMenuAction(tester, Icons.open_in_browser);
      await _pumpUntil(tester, () => launchedBrowserUrls.isNotEmpty, timeout: const Duration(seconds: 10));
      final expectedBrowserUrl =
          '${Store.get(StoreKey.serverEndpoint).replaceFirst('/api', '')}/photos/${remoteImage.id}';
      expect(launchedBrowserUrls.single, expectedBrowserUrl);
      final browserAssetResponse = await _waitForSuccessfulResponse(
        tester,
        () => _authenticatedApiGet('/assets/${remoteImage.id}/thumbnail?size=thumbnail&edited=false'),
      );
      expect(browserAssetResponse.bodyBytes, isNotEmpty);
    });

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

Future<void> _loadAppPreservingStore(
  WidgetTester tester, {
  bool overrideCancellation = false,
  bool closeDriftOnDispose = true,
}) async {
  await EasyLocalization.ensureInitialized();
  final (drift, _) = await Bootstrap.initDomain();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        driftProvider.overrideWith(_driftOverrideForTest(drift, closeOnDispose: closeDriftOnDispose)),
        if (overrideCancellation) cancellationProvider.overrideWithValue(Completer()),
      ],
      child: const app.MainWidget(),
    ),
  );
  await EasyLocalization.ensureInitialized();
}

Future<void> _loadAuthenticatedApp(
  WidgetTester tester, {
  bool overrideCancellation = false,
  bool closeDriftOnDispose = true,
}) async {
  await EasyLocalization.ensureInitialized();
  final (drift, _) = await Bootstrap.initDomain();
  await Store.clear();

  await _seedAuthenticatedStore();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        driftProvider.overrideWith(_driftOverrideForTest(drift, closeOnDispose: closeDriftOnDispose)),
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

Future<void> _loadUnauthenticatedApp(
  WidgetTester tester, {
  bool overrideCancellation = false,
  bool closeDriftOnDispose = true,
}) async {
  await EasyLocalization.ensureInitialized();
  final (drift, _) = await Bootstrap.initDomain();
  await Store.clear();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        driftProvider.overrideWith(_driftOverrideForTest(drift, closeOnDispose: closeDriftOnDispose)),
        if (overrideCancellation) cancellationProvider.overrideWithValue(Completer()),
      ],
      child: const app.MainWidget(),
    ),
  );
  await EasyLocalization.ensureInitialized();
  await _pumpFor(tester, const Duration(milliseconds: 500));
}

Drift Function(Ref ref) _driftOverrideForTest(Drift drift, {required bool closeOnDispose}) => (ref) {
  if (closeOnDispose) {
    ref.onDispose(() => unawaited(drift.close()));
  }
  ref.keepAlive();
  return drift;
};

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

Future<void> _selectOnlyBackupAlbumForAsset(ProviderContainer container, LocalAsset asset) async {
  final albumRepository = container.read(localAlbumRepository);
  final albums = await albumRepository.getAll();
  for (final album in albums) {
    if (album.backupSelection != BackupSelection.none) {
      await albumRepository.upsert(album.copyWith(backupSelection: BackupSelection.none));
    }
  }

  final sourceAlbums = await container.read(localAssetRepository).getSourceAlbums(asset.id);
  expect(sourceAlbums, isNotEmpty, reason: 'Expected ${asset.name} to belong to at least one local album');
  await albumRepository.upsert(sourceAlbums.first.copyWith(backupSelection: BackupSelection.selected));
}

Future<Map<String, BackupSelection>> _albumBackupSelections(ProviderContainer container) async {
  final albums = await container.read(localAlbumServiceProvider).getAll();
  return {for (final album in albums) album.id: album.backupSelection};
}

Future<void> _restoreAlbumBackupSelections(
  DriftLocalAlbumRepository albumRepository,
  Map<String, BackupSelection> selectionsById,
) async {
  final albums = await albumRepository.getAll();
  for (final album in albums) {
    final originalSelection = selectionsById[album.id] ?? BackupSelection.none;
    if (album.backupSelection != originalSelection) {
      await albumRepository.upsert(album.copyWith(backupSelection: originalSelection));
    }
  }
}

Future<void> _clearAlbumBackupSelections(ProviderContainer container) async {
  final albumRepository = container.read(localAlbumRepository);
  final albums = await albumRepository.getAll();
  for (final album in albums) {
    if (album.backupSelection != BackupSelection.none) {
      await albumRepository.upsert(album.copyWith(backupSelection: BackupSelection.none));
    }
  }
  await container.read(backupAlbumProvider.notifier).getAll();
}

Future<List<LocalAlbum>> _waitForBackupAlbumFixtures(
  WidgetTester tester,
  ProviderContainer container, {
  required Set<String> requiredNames,
  String? duplicatedName,
}) async {
  var albums = <LocalAlbum>[];
  for (var attempt = 0; attempt < 12; attempt++) {
    await container.read(backgroundSyncProvider).syncLocal(full: true);
    await container.read(backupAlbumProvider.notifier).getAll();
    albums = await container.read(localAlbumServiceProvider).getAll();
    final names = albums.map((album) => album.name).toSet();
    final hasRequired = requiredNames.every(names.contains);
    final hasDuplicatedName =
        duplicatedName == null || albums.where((album) => album.name == duplicatedName).length >= 2;
    if (hasRequired && hasDuplicatedName) {
      return albums;
    }
    await _pumpFor(tester, const Duration(seconds: 2));
  }

  final seenNames = albums.map((album) => album.name).toSet().toList()..sort();
  final duplicateExpectation = duplicatedName == null ? '' : ' and two "$duplicatedName" albums';
  fail('Expected backup album fixtures $requiredNames$duplicateExpectation; saw ${seenNames.join(', ')}');
}

LocalAlbum _singleAlbumNamed(List<LocalAlbum> albums, String name) {
  final matches = _albumsNamed(albums, name);
  expect(matches, hasLength(1), reason: 'Expected exactly one local album named $name');
  return matches.single;
}

List<LocalAlbum> _albumsNamed(List<LocalAlbum> albums, String name) {
  return albums.where((album) => album.name == name).toList();
}

Future<void> _searchBackupAlbums(WidgetTester tester, String query) async {
  final page = find.byType(DriftBackupAlbumSelectionPage);
  final searchButton = find.descendant(of: page, matching: find.byIcon(Icons.search));
  if (searchButton.evaluate().isNotEmpty) {
    await tester.tap(searchButton.last);
    await _pumpFor(tester, const Duration(milliseconds: 300));
  }
  await tester.enterText(find.descendant(of: page, matching: find.byType(TextField)).last, query);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  FocusManager.instance.primaryFocus?.unfocus();
  await _pumpFor(tester, const Duration(milliseconds: 500));
}

Future<void> _clearBackupAlbumSearch(WidgetTester tester) async {
  final page = find.byType(DriftBackupAlbumSelectionPage);
  await tester.tap(find.descendant(of: page, matching: find.byIcon(Icons.close)).last);
  await _pumpFor(tester, const Duration(milliseconds: 500));
}

Future<void> _tapBackupAlbumTile(WidgetTester tester, String albumName) async {
  await _ensureBackupAlbumVisible(tester, albumName);
  await tester.tap(_backupAlbumTileFinder(albumName).first, warnIfMissed: false);
  await _pumpFor(tester, const Duration(milliseconds: 800));
}

Future<void> _doubleTapBackupAlbumTile(WidgetTester tester, String albumName) async {
  await _ensureBackupAlbumVisible(tester, albumName);
  await tester.tap(_backupAlbumTileFinder(albumName).first, warnIfMissed: false);
  await tester.pump(const Duration(milliseconds: 80));
  await tester.tap(_backupAlbumTileFinder(albumName).first, warnIfMissed: false);
  await _pumpFor(tester, const Duration(milliseconds: 800));
}

Future<void> _ensureBackupAlbumVisible(WidgetTester tester, String albumName) async {
  final tile = _backupAlbumTileFinder(albumName);
  if (tile.evaluate().isNotEmpty) {
    await tester.ensureVisible(tile.first);
    return;
  }

  final scrollable = find.descendant(of: find.byType(DriftBackupAlbumSelectionPage), matching: find.byType(Scrollable));
  expect(scrollable, findsWidgets, reason: 'Expected a scrollable backup album list before looking for $albumName');
  await tester.scrollUntilVisible(tile, 600, scrollable: scrollable.first, maxScrolls: 40);
  await _pumpFor(tester, const Duration(milliseconds: 200));
}

Finder _backupAlbumTileFinder(String albumName) {
  return find.byWidgetPredicate((widget) => widget is DriftAlbumInfoListTile && widget.album.name == albumName);
}

List<String> _visibleBackupAlbumNames(WidgetTester tester) {
  return tester
      .widgetList<DriftAlbumInfoListTile>(find.byType(DriftAlbumInfoListTile))
      .map((tile) => tile.album.name)
      .toList();
}

Future<void> _waitForVisibleBackupAlbumTile(WidgetTester tester, String albumName) async {
  var visibleNames = const <String>[];
  for (var attempt = 0; attempt < 30; attempt++) {
    visibleNames = _visibleBackupAlbumNames(tester);
    if (visibleNames.contains(albumName)) {
      return;
    }
    await _pumpFor(tester, const Duration(milliseconds: 200));
  }

  fail('Expected visible backup album "$albumName"; saw visible albums: ${visibleNames.join(', ')}');
}

Future<void> _waitForAlbumSelection(
  ProviderContainer container,
  String albumId,
  BackupSelection selection,
  WidgetTester tester,
) async {
  BackupSelection? lastSelection;
  for (var attempt = 0; attempt < 20; attempt++) {
    await container.read(backupAlbumProvider.notifier).getAll();
    lastSelection = await _albumSelection(container, albumId);
    if (lastSelection == selection) {
      return;
    }
    await _pumpFor(tester, const Duration(milliseconds: 200));
  }

  fail('Expected album $albumId to be $selection but saw $lastSelection');
}

Future<BackupSelection> _albumSelection(ProviderContainer container, String albumId) async {
  final albums = await container.read(localAlbumServiceProvider).getAll();
  return albums.singleWhere((album) => album.id == albumId).backupSelection;
}

Future<void> _expectAlbumSelections(ProviderContainer container, Map<String, BackupSelection> expectedById) async {
  final actual = await _albumBackupSelections(container);
  for (final entry in expectedById.entries) {
    expect(actual[entry.key], entry.value, reason: 'Unexpected backup selection for local album ${entry.key}');
  }
}

Future<int> _expectedBackupAssetTotal(
  ProviderContainer container,
  Set<String> selectedAlbumIds,
  Set<String> excludedAlbumIds,
) async {
  final albumRepository = container.read(localAlbumRepository);
  final selectedAssetIds = <String>{};
  for (final albumId in selectedAlbumIds) {
    selectedAssetIds.addAll((await albumRepository.getAssets(albumId)).map((asset) => asset.id));
  }

  final excludedAssetIds = <String>{};
  for (final albumId in excludedAlbumIds) {
    excludedAssetIds.addAll((await albumRepository.getAssets(albumId)).map((asset) => asset.id));
  }

  return selectedAssetIds.difference(excludedAssetIds).length;
}

Future<void> _popBackupAlbumSelectionPage(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.arrow_back_ios_rounded).first);
  await _pumpFor(tester, const Duration(seconds: 1));
  await _pumpUntil(
    tester,
    () => find.byType(DriftBackupAlbumSelectionPage).evaluate().isEmpty,
    timeout: const Duration(seconds: 30),
  );
}

Finder _backupPageSwitchFinder() {
  return find.descendant(of: find.byType(BackupToggleButton), matching: find.byType(Switch));
}

void _expectBackupPageSwitchValue(WidgetTester tester, bool expected) {
  final switchFinder = _backupPageSwitchFinder();
  expect(switchFinder, findsOneWidget);
  expect(tester.widget<Switch>(switchFinder).value, expected);
}

Future<void> _setBackupPageSwitch(WidgetTester tester, bool expected) async {
  final switchFinder = _backupPageSwitchFinder();
  expect(switchFinder, findsOneWidget);
  if (tester.widget<Switch>(switchFinder).value == expected) {
    return;
  }

  await tester.tap(switchFinder);
  await _pumpFor(tester, const Duration(milliseconds: 500));
  _expectBackupPageSwitchValue(tester, expected);
}

Future<void> _openDriftBackupOptionsPage(WidgetTester tester) async {
  final settingsButton = find.descendant(
    of: find.byType(DriftBackupPage),
    matching: find.byIcon(Icons.settings_outlined),
  );
  await pumpUntilFound(tester, settingsButton, timeout: const Duration(seconds: 30));
  await tester.tap(settingsButton.last);
  await _pumpUntil(
    tester,
    () => find.byType(DriftBackupOptionsPage).evaluate().isNotEmpty,
    timeout: const Duration(seconds: 30),
  );
}

Future<void> _ensureBackupOptionTextVisible(WidgetTester tester, String titleKey) async {
  final text = find.text(titleKey.tr());
  if (text.evaluate().isNotEmpty) {
    await tester.ensureVisible(text.first);
    await _pumpFor(tester, const Duration(milliseconds: 200));
    return;
  }

  final scrollable = find.descendant(of: find.byType(DriftBackupOptionsPage), matching: find.byType(Scrollable));
  expect(scrollable, findsWidgets, reason: 'Expected backup options to be scrollable before looking for $titleKey');
  try {
    await tester.scrollUntilVisible(text, 450, scrollable: scrollable.first, maxScrolls: 20);
  } catch (_) {
    await tester.scrollUntilVisible(text, -450, scrollable: scrollable.first, maxScrolls: 20);
  }
  await _pumpFor(tester, const Duration(milliseconds: 200));
}

Finder _backupOptionSwitchFinder(String titleKey) {
  final tile = find.ancestor(of: find.text(titleKey.tr()), matching: find.byType(SettingListTile));
  return find.descendant(of: tile, matching: find.byType(Switch));
}

Future<void> _expectBackupOptionSwitch(WidgetTester tester, {required String titleKey, required bool expected}) async {
  await _ensureBackupOptionTextVisible(tester, titleKey);
  final switchFinder = _backupOptionSwitchFinder(titleKey);
  expect(switchFinder, findsOneWidget);
  expect(tester.widget<Switch>(switchFinder).value, expected, reason: 'Unexpected value for ${titleKey.tr()}');
}

Future<void> _setBackupOptionSwitch(
  WidgetTester tester, {
  required String titleKey,
  required SettingsKey<bool> settingKey,
  required bool expected,
}) async {
  await _ensureBackupOptionTextVisible(tester, titleKey);
  final switchFinder = _backupOptionSwitchFinder(titleKey);
  expect(switchFinder, findsOneWidget);
  if (tester.widget<Switch>(switchFinder).value != expected) {
    await tester.tap(switchFinder);
    await _waitForBackupSetting(tester, settingKey, expected);
  }
  await _expectBackupOptionSwitch(tester, titleKey: titleKey, expected: expected);
}

Future<void> _setBackupDelaySlider(WidgetTester tester, int expectedSliderValue) async {
  await _ensureBackupOptionTextVisible(tester, 'charging');
  final slider = find.descendant(of: find.byType(DriftBackupOptionsPage), matching: find.byType(Slider));
  expect(slider, findsOneWidget);
  final rect = tester.getRect(slider);
  await tester.tapAt(Offset(rect.left + rect.width * (expectedSliderValue / 3), rect.center.dy));
  await _pumpFor(tester, const Duration(milliseconds: 500));
}

Future<void> _waitForBackupSetting<T>(WidgetTester tester, SettingsKey<T> settingKey, T expected) async {
  await _pumpUntil(
    tester,
    () => SettingsRepository.instance.appConfig.read(settingKey) == expected,
    timeout: const Duration(seconds: 10),
  );
}

Future<void> _ensureUploadQueueTextVisible(
  WidgetTester tester,
  String text, {
  Type pageType = DriftUploadDetailPage,
}) async {
  final textFinder = find.textContaining(text);
  if (textFinder.evaluate().isNotEmpty) {
    await tester.ensureVisible(textFinder.first);
    await _pumpFor(tester, const Duration(milliseconds: 200));
    return;
  }

  final scrollable = find.descendant(of: find.byType(pageType), matching: find.byType(Scrollable));
  expect(scrollable, findsWidgets, reason: 'Expected $pageType to be scrollable before looking for "$text"');
  try {
    await tester.scrollUntilVisible(textFinder, 450, scrollable: scrollable.first, maxScrolls: 20);
  } catch (_) {
    await tester.scrollUntilVisible(textFinder, -450, scrollable: scrollable.first, maxScrolls: 20);
  }
  await _pumpFor(tester, const Duration(milliseconds: 200));
}

Future<Map<String, DriftUploadStatus>> _waitForUploadItems(
  WidgetTester tester,
  ProviderContainer container,
  bool Function(Map<String, DriftUploadStatus> items) matches, {
  required String reason,
  Duration timeout = const Duration(seconds: 30),
}) async {
  var latest = const <String, DriftUploadStatus>{};
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    latest = Map<String, DriftUploadStatus>.from(container.read(driftBackupProvider).uploadItems);
    if (matches(latest)) {
      return latest;
    }
    await _pumpFor(tester, const Duration(milliseconds: 300));
  }

  fail('$reason; latest upload items=${latest.values.toList()}');
}

Finder _timelineAssetTiles() {
  return find.byWidgetPredicate((widget) => widget is ThumbnailTile && widget.asset != null);
}

Finder _timelineAssetTileForAsset(BaseAsset asset) {
  return find.byWidgetPredicate((widget) => widget is ThumbnailTile && widget.asset == asset);
}

Finder _timelineAssetTileForAssetId(String assetId) {
  return find.byWidgetPredicate(
    (widget) => widget is ThumbnailTile && widget.asset != null && _timelineAssetId(widget.asset!) == assetId,
  );
}

BaseAsset _assetFromTimelineTile(WidgetTester tester, Finder tile) {
  final widget = tester.widget<ThumbnailTile>(tile);
  final asset = widget.asset;
  expect(asset, isNotNull);
  return asset!;
}

BaseAsset _firstVisibleTimelineAssetWhere(
  WidgetTester tester,
  bool Function(BaseAsset asset) matches, {
  double minCenterY = 0,
  double bottomPadding = 0,
}) {
  final tiles = _timelineAssetTiles().evaluate();
  final viewSize = tester.view.physicalSize / tester.view.devicePixelRatio;
  for (final element in tiles) {
    final widget = element.widget;
    final renderObject = element.renderObject;
    if (widget is! ThumbnailTile ||
        widget.asset == null ||
        renderObject is! RenderBox ||
        !renderObject.attached ||
        !matches(widget.asset!)) {
      continue;
    }

    final rect = renderObject.localToGlobal(Offset.zero) & renderObject.size;
    final center = rect.center;
    if (center.dx >= 0 &&
        center.dx <= viewSize.width &&
        center.dy >= minCenterY &&
        center.dy <= viewSize.height - bottomPadding) {
      return widget.asset!;
    }
  }
  fail('Expected at least one visible timeline asset matching predicate');
}

Future<void> _waitForVisibleTimelineAssetTiles(WidgetTester tester, {required int minCount}) async {
  await _pumpUntil(
    tester,
    () => _timelineAssetTiles().evaluate().length >= minCount,
    timeout: const Duration(seconds: 60),
  );
}

Future<void> _selectTimelineAssetsById(WidgetTester tester, ProviderContainer container, List<String> assetIds) async {
  expect(assetIds, isNotEmpty);
  await _waitForVisibleTimelineAssetTiles(tester, minCount: assetIds.length);

  final firstTile = _timelineAssetTileForAssetId(assetIds.first);
  await pumpUntilFound(tester, firstTile, timeout: const Duration(seconds: 30));
  await tester.longPress(firstTile);
  await _waitForSelectedTimelineAssetIds(tester, container, {assetIds.first});

  for (var index = 1; index < assetIds.length; index++) {
    final tile = _timelineAssetTileForAssetId(assetIds[index]);
    await pumpUntilFound(tester, tile, timeout: const Duration(seconds: 30));
    await tester.tap(tile);
    await _waitForSelectedTimelineAssetIds(tester, container, assetIds.take(index + 1).toSet());
  }
}

Finder _bottomSheetIcon(Type bottomSheetType, IconData icon) {
  return find.descendant(of: find.byType(bottomSheetType), matching: find.byIcon(icon));
}

Future<void> _tapBottomSheetAction(WidgetTester tester, Type bottomSheetType, IconData icon) async {
  await pumpUntilFound(tester, find.byType(bottomSheetType), timeout: const Duration(seconds: 30));
  final actionIcon = _bottomSheetIcon(bottomSheetType, icon);
  await pumpUntilFound(tester, actionIcon, timeout: const Duration(seconds: 30));

  final actionScroll = find.descendant(of: find.byType(bottomSheetType), matching: find.byType(SingleChildScrollView));
  await tester.ensureVisible(actionIcon.last);
  await _pumpFor(tester, const Duration(milliseconds: 200));
  for (var attempt = 0; attempt < 16 && actionIcon.hitTestable().evaluate().isEmpty; attempt++) {
    if (actionScroll.evaluate().isEmpty) {
      break;
    }
    await tester.drag(actionScroll.first, const Offset(-520, 0));
    await _pumpFor(tester, const Duration(milliseconds: 200));
  }

  expect(actionIcon.hitTestable(), findsWidgets, reason: 'Expected action icon $icon to be tappable');
  await tester.tap(actionIcon.hitTestable().first);
  await _pumpFor(tester, const Duration(milliseconds: 500));
}

const _sharePlusChannel = MethodChannel('dev.fluttercommunity.plus/share');
const _legacyUrlLauncherChannel = MethodChannel('plugins.flutter.io/url_launcher');

BasicMessageChannel<Object?> _urlLauncherPigeonChannel(String method) => BasicMessageChannel<Object?>(
  'dev.flutter.pigeon.url_launcher_android.UrlLauncherApi.$method',
  const StandardMessageCodec(),
);

class _ShareInvocation {
  final List<String> paths;
  final List<String> mimeTypes;
  final List<bool> existedWhenShared;

  const _ShareInvocation({required this.paths, required this.mimeTypes, required this.existedWhenShared});
}

void _recordSharePlusInvocations(List<_ShareInvocation> invocations) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_sharePlusChannel, (
    call,
  ) async {
    if (call.method != 'shareFiles') {
      return '';
    }

    final arguments = call.arguments as Map<dynamic, dynamic>;
    final paths = (arguments['paths'] as List<dynamic>).cast<String>();
    final mimeTypes = (arguments['mimeTypes'] as List<dynamic>).cast<String>();
    invocations.add(
      _ShareInvocation(
        paths: paths,
        mimeTypes: mimeTypes,
        existedWhenShared: paths.map((path) => File(path).existsSync()).toList(growable: false),
      ),
    );
    return '';
  });
}

void _clearSharePlusInvocationRecorder() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_sharePlusChannel, null);
}

void _recordUrlLauncherInvocations(List<String> launchedUrls) {
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockDecodedMessageHandler<Object?>(_urlLauncherPigeonChannel('canLaunchUrl'), (_) async {
    return <Object?>[true];
  });
  messenger.setMockDecodedMessageHandler<Object?>(_urlLauncherPigeonChannel('launchUrl'), (message) async {
    final arguments = message! as List<Object?>;
    launchedUrls.add(arguments.first! as String);
    return <Object?>[true];
  });
  messenger.setMockMethodCallHandler(_legacyUrlLauncherChannel, (call) async {
    if (call.method == 'canLaunch') {
      return true;
    }
    if (call.method == 'launch') {
      final arguments = call.arguments as Map<dynamic, dynamic>;
      launchedUrls.add(arguments['url'] as String);
      return true;
    }
    return false;
  });
}

void _clearUrlLauncherInvocationRecorder() {
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockDecodedMessageHandler<Object?>(_urlLauncherPigeonChannel('canLaunchUrl'), null);
  messenger.setMockDecodedMessageHandler<Object?>(_urlLauncherPigeonChannel('launchUrl'), null);
  messenger.setMockMethodCallHandler(_legacyUrlLauncherChannel, null);
}

Future<void> _waitForShareInvocationCount(WidgetTester tester, List<_ShareInvocation> invocations, int count) async {
  await _pumpUntil(tester, () => invocations.length >= count, timeout: const Duration(seconds: 30));
}

void _expectSharedDisplayNames(_ShareInvocation invocation, Set<String> displayNames) {
  expect(invocation.paths, hasLength(displayNames.length));
  expect(invocation.mimeTypes, hasLength(displayNames.length));
  expect(invocation.existedWhenShared, everyElement(isTrue));
  for (final name in displayNames) {
    expect(
      invocation.paths.any((path) => path.endsWith('/$name') || path.endsWith('-$name')),
      isTrue,
      reason: 'Expected a shared file path for $name in ${invocation.paths.join(', ')}',
    );
  }
}

Future<void> _showViewerControls(WidgetTester tester, ProviderContainer container) async {
  await pumpUntilFound(tester, find.byType(AssetViewer), timeout: const Duration(seconds: 30));
  container.read(assetViewerProvider.notifier).setControls(true);
  await _pumpFor(tester, const Duration(milliseconds: 300));
}

Future<void> _tapViewerActionIcon(WidgetTester tester, IconData icon) async {
  final actionIcon = find.descendant(of: find.byType(AssetViewer), matching: find.byIcon(icon));
  await pumpUntilFound(tester, actionIcon, timeout: const Duration(seconds: 30));
  expect(actionIcon.hitTestable(), findsWidgets, reason: 'Expected viewer action icon $icon to be tappable');
  await tester.tap(actionIcon.hitTestable().first, warnIfMissed: false);
  await _pumpFor(tester, const Duration(milliseconds: 500));
}

Future<void> _tapViewerMenuAction(WidgetTester tester, IconData icon) async {
  final menuButton = find.descendant(of: find.byType(AssetViewer), matching: find.byIcon(Icons.more_vert_rounded));
  await pumpUntilFound(tester, menuButton, timeout: const Duration(seconds: 30));
  expect(menuButton.hitTestable(), findsWidgets, reason: 'Expected viewer menu button to be tappable');
  await tester.tap(menuButton.hitTestable().last, warnIfMissed: false);
  await _pumpFor(tester, const Duration(milliseconds: 500));

  final actionIcon = find.byIcon(icon);
  await pumpUntilFound(tester, actionIcon, timeout: const Duration(seconds: 30));
  expect(actionIcon.hitTestable(), findsWidgets, reason: 'Expected viewer menu action icon $icon to be tappable');
  await tester.tap(actionIcon.hitTestable().last, warnIfMissed: false);
  await _pumpFor(tester, const Duration(milliseconds: 500));
}

Future<TaskRecord> _waitForDownloadRecordStatus(
  WidgetTester tester,
  String taskId,
  TaskStatus status, {
  required String reason,
}) async {
  TaskRecord? latest;
  Object? lastError;
  final end = DateTime.now().add(const Duration(seconds: 90));
  while (DateTime.now().isBefore(end)) {
    try {
      latest = await FileDownloader().database.recordForId(taskId);
      if (latest?.status == status) {
        return latest!;
      }
    } catch (error) {
      lastError = error;
    }
    await _pumpFor(tester, const Duration(milliseconds: 500));
  }

  fail('$reason; latest record=$latest; last error=$lastError');
}

Future<void> _waitForDownloadUpdateCount(
  WidgetTester tester,
  List<TaskStatusUpdate> updates,
  String taskId,
  TaskStatus status,
  int count, {
  required String reason,
}) async {
  final end = DateTime.now().add(const Duration(seconds: 90));
  while (DateTime.now().isBefore(end)) {
    final currentCount = updates.where((update) => update.task.taskId == taskId && update.status == status).length;
    if (currentCount >= count) {
      return;
    }
    await _pumpFor(tester, const Duration(milliseconds: 500));
  }

  final seenStatuses = updates
      .where((update) => update.task.taskId == taskId)
      .map((update) => update.status.name)
      .toList(growable: false);
  fail('$reason; saw statuses=$seenStatuses');
}

Future<void> _expandBottomSheet(WidgetTester tester, Type bottomSheetType) async {
  await pumpUntilFound(tester, find.byType(bottomSheetType), timeout: const Duration(seconds: 30));

  final sheet = find.descendant(of: find.byType(bottomSheetType), matching: find.byType(DraggableScrollableSheet));
  final dragTarget = sheet.evaluate().isNotEmpty ? sheet.last : find.byType(bottomSheetType).last;
  await tester.drag(dragTarget, const Offset(0, -520), warnIfMissed: false);
  await _pumpFor(tester, const Duration(milliseconds: 400));
}

Future<void> _tapAlbumInSelector(WidgetTester tester, Type bottomSheetType, String albumName) async {
  await _expandBottomSheet(tester, bottomSheetType);
  await pumpUntilFound(tester, find.byType(AlbumSelector), timeout: const Duration(seconds: 30));

  final selector = find.byType(AlbumSelector);
  final searchField = find.descendant(of: selector, matching: find.byType(TextField));
  await pumpUntilFound(tester, searchField, timeout: const Duration(seconds: 30));
  await tester.tap(searchField.first, warnIfMissed: false);
  await tester.enterText(searchField.first, albumName);
  await _pumpFor(tester, const Duration(milliseconds: 500));
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await _pumpFor(tester, const Duration(milliseconds: 300));

  final albumText = find.descendant(
    of: selector,
    matching: find.byWidgetPredicate((widget) => widget is Text && widget.data == albumName),
  );
  final scrollable = find.descendant(of: find.byType(bottomSheetType), matching: find.byType(Scrollable));

  await _pumpUntil(tester, () => albumText.evaluate().isNotEmpty, timeout: const Duration(seconds: 30));

  for (var attempt = 0; attempt < 8 && albumText.hitTestable().evaluate().isEmpty; attempt++) {
    if (scrollable.evaluate().isEmpty) {
      break;
    }
    await tester.drag(scrollable.last, const Offset(0, -360), warnIfMissed: false);
    await _pumpFor(tester, const Duration(milliseconds: 200));
  }

  expect(albumText.hitTestable(), findsWidgets, reason: 'Expected album "$albumName" to be tappable in selector');
  final inkWell = find.ancestor(of: albumText, matching: find.byType(InkWell)).hitTestable();
  final gestureDetector = find.ancestor(of: albumText, matching: find.byType(GestureDetector)).hitTestable();
  if (inkWell.evaluate().isNotEmpty) {
    await tester.tap(inkWell.first, warnIfMissed: false);
  } else if (gestureDetector.evaluate().isNotEmpty) {
    await tester.tap(gestureDetector.last, warnIfMissed: false);
  } else {
    await tester.tap(albumText.hitTestable().first, warnIfMissed: false);
  }
  await _pumpFor(tester, const Duration(milliseconds: 500));
}

Future<void> _createAlbumFromBottomSheet(WidgetTester tester, String albumName) async {
  await _expandBottomSheet(tester, GeneralBottomSheet);
  await pumpUntilFound(tester, find.byType(AddToAlbumHeader), timeout: const Duration(seconds: 30));

  final createButton = find.descendant(
    of: find.byType(AddToAlbumHeader),
    matching: find.widgetWithText(TextButton, 'common_create_new_album'.tr()),
  );
  await pumpUntilFound(tester, createButton, timeout: const Duration(seconds: 30));
  for (var attempt = 0; attempt < 4 && createButton.hitTestable().evaluate().isEmpty; attempt++) {
    await _expandBottomSheet(tester, GeneralBottomSheet);
  }
  expect(
    createButton.hitTestable(),
    findsWidgets,
    reason: 'Expected the create-new-album button to be tappable in the bottom sheet',
  );
  await tester.tap(createButton.hitTestable().last, warnIfMissed: false);

  await pumpUntilFound(tester, find.byType(AlertDialog), timeout: const Duration(seconds: 30));
  final nameField = find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextFormField));
  await pumpUntilFound(tester, nameField, timeout: const Duration(seconds: 30));
  await tester.enterText(nameField.first, albumName);
  await _pumpFor(tester, const Duration(milliseconds: 200));
  FocusManager.instance.primaryFocus?.unfocus();
  await _pumpFor(tester, const Duration(milliseconds: 300));

  final dialogCreate = find.descendant(
    of: find.byType(AlertDialog),
    matching: find.widgetWithText(TextButton, 'create_album'.tr()),
  );
  await pumpUntilFound(tester, dialogCreate, timeout: const Duration(seconds: 30));
  expect(dialogCreate.hitTestable(), findsWidgets, reason: 'Expected the dialog create-album button to be tappable');
  await tester.tap(dialogCreate.hitTestable().last, warnIfMissed: false);
  await _pumpFor(tester, const Duration(milliseconds: 500));
}

Future<void> _tapSnackbarAction(WidgetTester tester) async {
  await pumpUntilFound(tester, find.byType(SnackBarAction), timeout: const Duration(seconds: 10));
  expect(find.text('undo'.tr()), findsWidgets);
  await tester.tap(find.byType(SnackBarAction).first);
  await _pumpFor(tester, const Duration(milliseconds: 500));
}

Future<void> _waitForMultiSelectCount(
  WidgetTester tester,
  ProviderContainer container,
  int expected, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  var latest = -1;
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    latest = container.read(multiSelectProvider).selectedAssets.length;
    if (latest == expected) {
      return;
    }
    await _pumpFor(tester, const Duration(milliseconds: 200));
  }

  fail('Expected multiselect count $expected but saw $latest');
}

Future<void> _waitForSelectedTimelineAssetIds(
  WidgetTester tester,
  ProviderContainer container,
  Set<String> expected, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  var latest = const <String>{};
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    latest = _timelineAssetIds(container.read(multiSelectProvider).selectedAssets);
    if (latest.length == expected.length && latest.containsAll(expected)) {
      return;
    }
    await _pumpFor(tester, const Duration(milliseconds: 200));
  }

  final sortedExpected = expected.toList()..sort();
  final sortedLatest = latest.toList()..sort();
  fail('Expected selected timeline asset ids $sortedExpected but saw $sortedLatest');
}

Future<List<TimeBucket>> _ensureMultiSelectTimelineAssets(
  WidgetTester tester,
  ProviderContainer container,
  TimelineService timeline,
  Set<String> createdRemoteAssetIds,
) async {
  final currentTotal = timeline.totalAssets;
  if (currentTotal < _multiSelectMinimumAssetCount) {
    final seedCount = _multiSelectMinimumAssetCount - currentTotal;
    final runId = DateTime.now().toUtc().microsecondsSinceEpoch;
    for (var i = 0; i < seedCount; i++) {
      final createdAt = DateTime.utc(2024, 1 + (i % 12), 1 + (i % 24), 12, i % 60, i % 60);
      final fileName = '$_multiSelectRemoteSeedPrefix$runId-${i.toString().padLeft(2, '0')}.jpg';
      final assetId = await _uploadGeneratedJpegAsSecondClient(fileName, createdAt);
      createdRemoteAssetIds.add(assetId);
    }

    final syncSuccess = await container.read(syncStreamServiceProvider).sync();
    expect(syncSuccess, isTrue, reason: 'Expected 038 remote seed assets to sync into the Drift timeline');
    await _pumpFor(tester, const Duration(seconds: 2));
  }

  return _waitForTimelineBuckets(tester, timeline, minAssets: _multiSelectMinimumAssetCount);
}

Future<void> _seedUpgradeState(WidgetTester tester) async {
  final snapshotFile = await _upgradeSnapshotFile();
  if (snapshotFile.existsSync()) {
    snapshotFile.deleteSync();
  }

  await _loadAuthenticatedApp(tester, overrideCancellation: true, closeDriftOnDispose: false);
  final container = _containerOfApp(tester);
  final drift = container.read(driftProvider);

  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await _pumpFor(tester, const Duration(milliseconds: 200));
    await drift.close();
  });

  final user = Store.tryGet(StoreKey.currentUser);
  expect(user, isNotNull);
  expect((Store.tryGet(StoreKey.accessToken) ?? '').isNotEmpty, isTrue);

  await _writeUpgradeBackupSettings();
  await container.read(backgroundSyncProvider).syncLocal(full: true);
  final localAssets = await _localAssets(container);
  expect(localAssets, isNotEmpty, reason: 'Expected the seeded app data to include the simulator media library');

  final syncSuccess = await container.read(syncStreamServiceProvider).sync();
  expect(syncSuccess, isTrue);

  final localRows = await _upgradeLocalRowCounts(drift);
  expect(localRows['local_asset_entity'], greaterThan(0));
  expect(localRows['local_album_entity'], greaterThan(0));
  expect(localRows['store_entity'], greaterThan(0));
  expect(localRows['settings'], greaterThan(0));

  final remoteRows = await _remoteSyncRowCounts(drift);
  expect(remoteRows['remote_asset_entity'], greaterThan(0));

  final localAssetNames = localAssets.map((asset) => asset.name).toSet().toList()..sort();
  final snapshot = {
    'caseId': 'MOB-REAL-032-$_caseSuffix',
    'seededAt': DateTime.now().toUtc().toIso8601String(),
    'userId': user!.id,
    'email': user.email,
    'serverEndpoint': Store.get(StoreKey.serverEndpoint),
    'serverUrl': Store.get(StoreKey.serverUrl),
    'deviceId': Store.tryGet(StoreKey.deviceId),
    'accessTokenPresent': true,
    'backupSettings': _readUpgradeBackupSettings(),
    'databaseUserVersion': await _databaseUserVersion(drift),
    'databaseIntegrity': await _databaseIntegrityCheck(drift),
    'localRows': localRows,
    'remoteRows': remoteRows,
    'localAssetNames': localAssetNames.take(25).toList(),
  };

  expect(snapshot['databaseUserVersion'], drift.schemaVersion);
  expect(snapshot['databaseIntegrity'], 'ok');
  snapshotFile.writeAsStringSync(jsonEncode(snapshot));
}

Future<void> _verifyUpgradeState(WidgetTester tester) async {
  final snapshot = await _readUpgradeSnapshot();

  await _loadAppPreservingStore(tester, overrideCancellation: true, closeDriftOnDispose: false);
  await _pumpFor(tester, const Duration(milliseconds: 500));
  await _waitForAccessToken(tester);
  await _waitForCurrentUser(snapshot['email'] as String, tester);
  await _dismissFeatureMessageIfVisible(tester);

  final container = _containerOfApp(tester);
  final drift = container.read(driftProvider);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await _pumpFor(tester, const Duration(milliseconds: 200));
    await drift.close();
  });

  final user = Store.tryGet(StoreKey.currentUser);
  expect(user, isNotNull);
  expect(user!.id, snapshot['userId']);
  expect(user.email, snapshot['email']);
  expect(Store.tryGet(StoreKey.serverEndpoint), snapshot['serverEndpoint']);
  expect(Store.tryGet(StoreKey.serverUrl), snapshot['serverUrl']);
  expect(Store.tryGet(StoreKey.deviceId), snapshot['deviceId']);
  expect((Store.tryGet(StoreKey.accessToken) ?? '').isNotEmpty, isTrue);
  expect(_readUpgradeBackupSettings(), _upgradeExpectedBackupSettings);

  await container.read(backgroundSyncProvider).syncLocal(full: true);
  final localAssets = await _localAssets(container);
  final localAssetNames = localAssets.map((asset) => asset.name).toSet();
  expect(localAssetNames, isNotEmpty);
  expect(
    localAssetNames.intersection(_jsonStringSet(snapshot['localAssetNames'])).isNotEmpty,
    isTrue,
    reason: 'Expected simulator library assets discovered before upgrade to remain visible after upgrade',
  );

  final beforeLocalRows = _jsonIntMap(snapshot['localRows']);
  final afterLocalRows = await _upgradeLocalRowCounts(drift);
  _expectRowsNotReduced(afterLocalRows, beforeLocalRows, label: 'local library after upgrade');

  final beforeRemoteRows = _jsonIntMap(snapshot['remoteRows']);
  final syncSuccess = await container.read(syncStreamServiceProvider).sync();
  expect(syncSuccess, isTrue);
  final afterRemoteRows = await _remoteSyncRowCounts(drift);
  _expectRowsNotReduced(afterRemoteRows, beforeRemoteRows, label: 'remote sync after upgrade');

  final secondSyncSuccess = await container.read(syncStreamServiceProvider).sync();
  expect(secondSyncSuccess, isTrue);
  expect(
    await _remoteSyncRowCounts(drift),
    afterRemoteRows,
    reason: 'Post-upgrade sync should not duplicate Drift remote rows',
  );

  expect(await _databaseUserVersion(drift), drift.schemaVersion);
  expect(await _databaseIntegrityCheck(drift), 'ok');
}

Future<File> _upgradeSnapshotFile() async {
  final directory = await getApplicationDocumentsDirectory();
  return File('${directory.path}/$_upgradeSnapshotFilename');
}

Future<Map<String, dynamic>> _readUpgradeSnapshot() async {
  final file = await _upgradeSnapshotFile();
  expect(
    file.existsSync(),
    isTrue,
    reason: 'Expected upgrade seed snapshot to survive app reinstall without data wipe',
  );
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

Future<void> _writeUpgradeBackupSettings() async {
  await SettingsRepository.instance.write(SettingsKey.backupEnabled, true);
  await SettingsRepository.instance.write(SettingsKey.backupUseCellularForPhotos, true);
  await SettingsRepository.instance.write(SettingsKey.backupUseCellularForVideos, true);
  await SettingsRepository.instance.write(SettingsKey.backupRequireCharging, true);
  await SettingsRepository.instance.write(SettingsKey.backupTriggerDelay, 17);
}

Map<String, Object> _readUpgradeBackupSettings() {
  final config = SettingsRepository.instance.appConfig;
  return {
    'backupEnabled': config.read(SettingsKey.backupEnabled),
    'backupUseCellularForPhotos': config.read(SettingsKey.backupUseCellularForPhotos),
    'backupUseCellularForVideos': config.read(SettingsKey.backupUseCellularForVideos),
    'backupRequireCharging': config.read(SettingsKey.backupRequireCharging),
    'backupTriggerDelay': config.read(SettingsKey.backupTriggerDelay),
  };
}

Future<Map<String, int>> _upgradeLocalRowCounts(Drift drift) async {
  const tables = ['store_entity', 'settings', 'local_album_entity', 'local_asset_entity', 'local_album_asset_entity'];
  return {for (final table in tables) table: await _rowCount(drift, table)};
}

void _expectRowsNotReduced(Map<String, int> actualRows, Map<String, int> minimumRows, {required String label}) {
  for (final entry in minimumRows.entries) {
    expect(
      actualRows[entry.key],
      greaterThanOrEqualTo(entry.value),
      reason: '$label row count for ${entry.key} should not shrink: before=$minimumRows after=$actualRows',
    );
  }
}

Map<String, int> _jsonIntMap(Object? raw) {
  final map = raw! as Map<String, dynamic>;
  return {for (final entry in map.entries) entry.key: (entry.value as num).toInt()};
}

Set<String> _jsonStringSet(Object? raw) => (raw! as List).cast<String>().toSet();

Future<int> _databaseUserVersion(Drift drift) async {
  final row = await drift.customSelect('PRAGMA user_version').getSingle();
  return row.read<int>('user_version');
}

Future<String> _databaseIntegrityCheck(Drift drift) async {
  final row = await drift.customSelect('PRAGMA integrity_check').getSingle();
  return row.read<String>('integrity_check');
}

Future<void> _expectPrimaryNavigationState(
  WidgetTester tester,
  ProviderContainer container, {
  required TabEnum tab,
  required int selectedIndex,
  required Type pageType,
  required Type expectedNavigationType,
}) async {
  try {
    await _pumpUntil(tester, () => find.byType(pageType).evaluate().isNotEmpty, timeout: const Duration(seconds: 30));
  } on TimeoutException catch (_) {
    fail(
      'Timed out waiting for $pageType. Current route stack: ${_routeStackDescription(container.read(appRouterProvider))}. '
      'visible=$pageType:${find.byType(pageType).evaluate().length}, '
      'offstage=$pageType:${find.byType(pageType, skipOffstage: false).evaluate().length}, '
      'NavigationBar:${find.byType(NavigationBar, skipOffstage: false).evaluate().length}, '
      'NavigationRail:${find.byType(NavigationRail, skipOffstage: false).evaluate().length}',
    );
  }
  expect(container.read(tabProvider), tab);

  if (expectedNavigationType == NavigationRail) {
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(tester.widget<NavigationRail>(find.byType(NavigationRail)).selectedIndex, selectedIndex);
    return;
  }

  expect(find.byType(NavigationBar), findsOneWidget);
  expect(find.byType(NavigationRail), findsNothing);
  expect(tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex, selectedIndex);
}

Future<void> _selectPrimaryNavigationTab(WidgetTester tester, int index) async {
  final navigationBar = find.byType(NavigationBar);
  if (navigationBar.evaluate().isNotEmpty) {
    final widget = tester.widget<NavigationBar>(navigationBar.first);
    widget.onDestinationSelected!(index);
  } else {
    final navigationRail = find.byType(NavigationRail);
    expect(navigationRail, findsOneWidget);
    final widget = tester.widget<NavigationRail>(navigationRail.first);
    widget.onDestinationSelected!(index);
  }
  await _pumpFor(tester, const Duration(milliseconds: 800));
}

Future<void> _expectPhotoRetapScrollsToTop(WidgetTester tester) async {
  await pumpUntilFound(tester, find.byType(Timeline), timeout: const Duration(seconds: 60));
  final scrollable = find.descendant(of: find.byType(Timeline), matching: find.byType(Scrollable));
  await pumpUntilFound(tester, scrollable, timeout: const Duration(seconds: 30));
  final position = tester.state<ScrollableState>(scrollable.first).position;
  await _pumpUntil(tester, () => position.maxScrollExtent > 0, timeout: const Duration(seconds: 60));

  await tester.fling(scrollable.first, const Offset(0, -1500), 1500);
  await _pumpFor(tester, const Duration(milliseconds: 700));
  expect(position.pixels, greaterThan(0));

  await _selectPrimaryNavigationTab(tester, kPhotoTabIndex);
  await _pumpUntil(tester, () => position.pixels <= 1, timeout: const Duration(seconds: 10));
}

Future<void> _openFavoritePageAndReturn(
  WidgetTester tester,
  ProviderContainer container, {
  required Type expectedNavigationType,
}) async {
  final favorites = find.descendant(of: find.byType(DriftLibraryPage), matching: find.text('favorites'.tr()));
  await pumpUntilFound(tester, favorites, timeout: const Duration(seconds: 30));
  await tester.tap(favorites.first);
  await _pumpFor(tester, const Duration(milliseconds: 800));
  await _pumpUntil(
    tester,
    () => find.byType(DriftFavoritePage).evaluate().isNotEmpty,
    timeout: const Duration(seconds: 30),
  );

  await tester.binding.handlePopRoute();
  await _pumpFor(tester, const Duration(milliseconds: 800));
  await _expectPrimaryNavigationState(
    tester,
    container,
    tab: TabEnum.library,
    selectedIndex: kLibraryTabIndex,
    pageType: DriftLibraryPage,
    expectedNavigationType: expectedNavigationType,
  );
}

Future<void> _setTestViewport(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  await tester.pump();
  await _pumpFor(tester, const Duration(milliseconds: 800));
}

int _currentRouteCount(AppRouter router, String routeName) {
  return router.currentSegments.where((route) => route.name == routeName).length;
}

void _expectRouteCount(AppRouter router, String routeName, int count) {
  expect(
    _currentRouteCount(router, routeName),
    count,
    reason: 'Current route stack: ${router.currentSegments.map((route) => route.name).join(' > ')}',
  );
}

String _routeStackDescription(AppRouter router) {
  return router.currentSegments.map((route) => route.name).join(' > ');
}

Future<void> _runAndroidBackgroundUploadOnce() async {
  final (drift, logDB) = await Bootstrap.initDomain(shouldBufferLogs: false, listenStoreUpdates: false);
  await BackgroundWorkerBgService(drift: drift, driftLogger: logDB).onAndroidUpload(2);
}

Future<void> _restoreRealStackApi(ApiService apiService) async {
  await _seedAuthenticatedStore();
  apiService.setEndpoint(_apiEndpoint(_serverUrl));
  await apiService.updateHeaders();
}

Future<({int processing, int remainder, int total})> _waitForBackupCounts(
  WidgetTester tester,
  ProviderContainer container,
  String userId,
  bool Function(({int processing, int remainder, int total}) counts) matches, {
  required String reason,
}) async {
  ({int processing, int remainder, int total})? latest;
  final end = DateTime.now().add(const Duration(seconds: 60));
  while (DateTime.now().isBefore(end)) {
    latest = await container.read(foregroundUploadServiceProvider).getBackupCounts(userId);
    if (matches(latest)) {
      return latest;
    }
    await _pumpFor(tester, const Duration(milliseconds: 500));
  }

  fail('$reason; latest backup counts=$latest');
}

Future<Set<String>> _serverAssetIdsByOriginalFilename(api.SearchApi searchApi, String filename) async {
  final response = await searchApi.searchAssets(_metadataSearchDto(filename: filename, type: api.AssetTypeEnum.IMAGE));
  expect(response, isNotNull, reason: 'Expected search response for $filename');
  return _serverSearchAssetIds(response!);
}

Future<Set<String>> _serverAlbumIdsByName(api.AlbumsApi albumsApi, String albumName) async {
  final albums = await albumsApi.getAllAlbums(name: albumName, isOwned: true);
  expect(albums, isNotNull, reason: 'Expected album search response for $albumName');
  return albums!.where((album) => album.albumName == albumName).map((album) => album.id).toSet();
}

Future<Set<String>> _waitForServerAlbumIdsByName(
  WidgetTester tester,
  api.AlbumsApi albumsApi,
  String albumName,
  bool Function(Set<String> ids) matches, {
  required String reason,
  Duration timeout = const Duration(seconds: 60),
}) async {
  var latest = const <String>{};
  Object? lastError;
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    try {
      latest = await _serverAlbumIdsByName(albumsApi, albumName);
      if (matches(latest)) {
        return latest;
      }
    } catch (error) {
      lastError = error;
    }
    await _pumpFor(tester, const Duration(seconds: 1));
  }

  final sorted = latest.toList()..sort();
  fail('$reason; latest server album ids=${sorted.join(', ')}; last error=$lastError');
}

Future<Set<String>> _waitForServerAssetIdsByOriginalFilename(
  WidgetTester tester,
  api.SearchApi searchApi,
  String filename,
  bool Function(Set<String> ids) matches, {
  required String reason,
  Duration timeout = const Duration(seconds: 60),
}) async {
  var latest = const <String>{};
  Object? lastError;
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    try {
      latest = await _serverAssetIdsByOriginalFilename(searchApi, filename);
      if (matches(latest)) {
        return latest;
      }
    } catch (error) {
      lastError = error;
    }
    await _pumpFor(tester, const Duration(seconds: 1));
  }

  fail('$reason; latest ids=${latest.toList()..sort()}; last error=$lastError');
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
  Set<int> acceptedEmptyBodyStatusCodes = const {},
  Duration timeout = const Duration(seconds: 40),
}) async {
  http.Response? lastResponse;
  Object? lastError;
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    try {
      final response = await request();
      final acceptsEmptyBody = acceptedEmptyBodyStatusCodes.contains(response.statusCode);
      if (acceptedStatusCodes.contains(response.statusCode) && (response.bodyBytes.isNotEmpty || acceptsEmptyBody)) {
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
  Map<String, Object>? sourceMetadata,
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
  final assetId = payload['id'] as String;
  if (sourceMetadata != null && sourceMetadata.isNotEmpty) {
    await _updateTestAssetSourceMetadata(assetId, fileName, createdAt, sourceMetadata);
  }
  return assetId;
}

Future<void> _updateTestAssetSourceMetadata(
  String remoteAssetId,
  String fileName,
  DateTime createdAt,
  Map<String, Object> sourceMetadata,
) async {
  final utcCreatedAt = createdAt.toUtc();
  final mergedSourceMetadata = <String, Object>{'uploaded_original_name': fileName, ...sourceMetadata};
  final metadata = <String, Object>{
    'original_created_unix_nano': utcCreatedAt.microsecondsSinceEpoch * 1000,
    'original_modified_unix_nano': utcCreatedAt.microsecondsSinceEpoch * 1000,
    'source_metadata': mergedSourceMetadata,
  };
  final request = http.Request('POST', Uri.parse('${Store.get(StoreKey.serverEndpoint)}/assets/bulk-metadata'))
    ..headers.addAll({
      ...ApiService.getRequestHeaders(),
      'Authorization': 'Bearer ${Store.get(StoreKey.accessToken)}',
      HttpHeaders.contentTypeHeader: 'application/json',
    })
    ..body = jsonEncode({
      'assets': [
        {'assetId': remoteAssetId, 'metadata': metadata},
      ],
    });

  final response = await http.Response.fromStream(await request.send());
  expect(response.statusCode, 200, reason: response.body);
}

Future<void> _createFaceAsSecondClient({
  required String assetId,
  required String personId,
  required int x,
  required int y,
  required int width,
  required int height,
  required int imageWidth,
  required int imageHeight,
}) async {
  final request = http.Request('POST', Uri.parse('${Store.get(StoreKey.serverEndpoint)}/faces'))
    ..headers.addAll({
      ...ApiService.getRequestHeaders(),
      'Authorization': 'Bearer ${Store.get(StoreKey.accessToken)}',
      HttpHeaders.contentTypeHeader: 'application/json',
    })
    ..body = jsonEncode({
      'assetId': assetId,
      'personId': personId,
      'x': x,
      'y': y,
      'width': width,
      'height': height,
      'imageWidth': imageWidth,
      'imageHeight': imageHeight,
    });

  final response = await http.Response.fromStream(await request.send());
  expect(response.statusCode, inInclusiveRange(200, 299), reason: response.body);
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

Future<void> _deletePersonBestEffort(api.PeopleApi peopleApi, String personId) async {
  try {
    await peopleApi.deletePerson(personId);
  } catch (_) {
    // Best-effort cleanup for a test-created person.
  }
}

Future<void> _deleteAlbumBestEffort(api.AlbumsApi albumsApi, String albumId) async {
  try {
    await albumsApi.deleteAlbum(albumId);
  } catch (_) {
    // Best-effort cleanup for a test-created album.
  }
}

SearchFilter _searchFilter({
  String? filename,
  DateTime? takenAfter,
  DateTime? takenBefore,
  bool isFavorite = false,
  bool isArchive = false,
  bool isNotInAlbum = false,
  AssetType mediaType = AssetType.other,
  String? make,
  String? model,
}) {
  return SearchFilter(
    filename: filename,
    people: {},
    location: SearchLocationFilter(),
    camera: SearchCameraFilter(make: make, model: model),
    date: SearchDateFilter(takenAfter: takenAfter, takenBefore: takenBefore),
    display: SearchDisplayFilters(isNotInAlbum: isNotInAlbum, isArchive: isArchive, isFavorite: isFavorite),
    rating: SearchRatingFilter(),
    mediaType: mediaType,
  );
}

api.MetadataSearchDto _metadataSearchDto({
  String? filename,
  DateTime? takenAfter,
  DateTime? takenBefore,
  bool? isFavorite,
  int page = 1,
  int size = 1000,
  api.AssetTypeEnum? type,
  api.AssetVisibility? visibility,
  String? make,
  String? model,
}) {
  return api.MetadataSearchDto(
    originalFileName: filename == null ? const api.Optional.absent() : api.Optional.present(filename),
    takenAfter: takenAfter == null ? const api.Optional.absent() : api.Optional.present(takenAfter),
    takenBefore: takenBefore == null ? const api.Optional.absent() : api.Optional.present(takenBefore),
    isFavorite: isFavorite == null ? const api.Optional.absent() : api.Optional.present(isFavorite),
    page: api.Optional.present(page),
    size: api.Optional.present(size),
    type: type == null ? const api.Optional.absent() : api.Optional.present(type),
    visibility: visibility == null ? const api.Optional.absent() : api.Optional.present(visibility),
    make: make == null ? const api.Optional.absent() : api.Optional.present(make),
    model: model == null ? const api.Optional.absent() : api.Optional.present(model),
  );
}

Future<api.SearchResponseDto> _waitForServerSearchResponse(
  WidgetTester tester,
  api.SearchApi searchApi,
  api.MetadataSearchDto dto,
  bool Function(api.SearchResponseDto response) matches, {
  required String reason,
}) async {
  api.SearchResponseDto? latest;
  Object? lastError;
  final end = DateTime.now().add(const Duration(seconds: 60));
  while (DateTime.now().isBefore(end)) {
    try {
      latest = await searchApi.searchAssets(dto);
      if (latest != null && matches(latest)) {
        return latest;
      }
    } catch (error) {
      lastError = error;
    }
    await _pumpFor(tester, const Duration(milliseconds: 500));
  }

  fail('$reason; latest server search=$latest; last error=$lastError');
}

Future<Set<String>> _waitForSearchServiceAssetIds(
  WidgetTester tester,
  SearchService searchService,
  SearchFilter filter,
  bool Function(Set<String> ids) matches, {
  required String reason,
}) async {
  var latest = const <String>{};
  Object? lastError;
  final end = DateTime.now().add(const Duration(seconds: 60));
  while (DateTime.now().isBefore(end)) {
    try {
      final result = await searchService.search(filter, 1);
      latest = {
        for (final asset in result?.assets ?? const <BaseAsset>[])
          if (asset.remoteId != null) asset.remoteId!,
      };
      if (matches(latest)) {
        return latest;
      }
    } catch (error) {
      lastError = error;
    }
    await _pumpFor(tester, const Duration(milliseconds: 500));
  }

  fail('$reason; latest app search ids=${latest.toList()..sort()}; last error=$lastError');
}

Future<List<Map<String, dynamic>>> _waitForServerFaces(
  WidgetTester tester,
  String remoteAssetId,
  bool Function(List<Map<String, dynamic>> faces) matches, {
  required String reason,
}) async {
  var latest = const <Map<String, dynamic>>[];
  http.Response? lastResponse;
  Object? lastError;
  final end = DateTime.now().add(const Duration(seconds: 60));
  while (DateTime.now().isBefore(end)) {
    try {
      final uri = Uri.parse(
        '${Store.get(StoreKey.serverEndpoint)}/faces',
      ).replace(queryParameters: {'id': remoteAssetId});
      final response = await http.get(
        uri,
        headers: {...ApiService.getRequestHeaders(), 'Authorization': 'Bearer ${Store.get(StoreKey.accessToken)}'},
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final payload = jsonDecode(response.body);
        if (payload is List) {
          latest = payload.whereType<Map>().map((face) => face.cast<String, dynamic>()).toList(growable: false);
          if (matches(latest)) {
            return latest;
          }
        }
      }
      lastResponse = response;
    } catch (error) {
      lastError = error;
    }
    await _pumpFor(tester, const Duration(milliseconds: 500));
  }

  fail(
    '$reason; latest server faces=$latest; '
    'last status=${lastResponse?.statusCode}; last body=${lastResponse?.body}; last error=$lastError',
  );
}

Future<List<api.AssetResponseDto>> _waitForServerPlaces(
  WidgetTester tester,
  bool Function(List<api.AssetResponseDto> assets) matches, {
  required String reason,
}) async {
  var latest = const <api.AssetResponseDto>[];
  http.Response? lastResponse;
  Object? lastError;
  final end = DateTime.now().add(const Duration(seconds: 60));
  while (DateTime.now().isBefore(end)) {
    try {
      final response = await http.get(
        Uri.parse('${Store.get(StoreKey.serverEndpoint)}/search/cities'),
        headers: {...ApiService.getRequestHeaders(), 'Authorization': 'Bearer ${Store.get(StoreKey.accessToken)}'},
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final payload = jsonDecode(response.body);
        if (payload is List) {
          latest = [
            for (final item in payload)
              if (api.AssetResponseDto.fromJson(item) != null) api.AssetResponseDto.fromJson(item)!,
          ];
          if (matches(latest)) {
            return latest;
          }
        }
      }
      lastResponse = response;
    } catch (error) {
      lastError = error;
    }
    await _pumpFor(tester, const Duration(milliseconds: 500));
  }

  fail(
    '$reason; latest server city assets=$latest; '
    'last status=${lastResponse?.statusCode}; last body=${lastResponse?.body}; last error=$lastError',
  );
}

Future<ExifInfo> _waitForRemoteExifState(
  WidgetTester tester,
  AssetService assetService,
  BaseAsset asset,
  bool Function(ExifInfo exif) matches, {
  required String reason,
}) async {
  ExifInfo? latest;
  final end = DateTime.now().add(const Duration(seconds: 60));
  while (DateTime.now().isBefore(end)) {
    latest = await assetService.getExif(asset);
    if (latest != null && matches(latest)) {
      return latest;
    }
    await _pumpFor(tester, const Duration(milliseconds: 500));
  }

  fail('$reason; latest local EXIF=$latest');
}

Future<List<DriftPerson>> _waitForLocalPeopleState(
  WidgetTester tester,
  DriftPeopleService peopleService,
  bool Function(List<DriftPerson> people) matches, {
  required String reason,
}) async {
  var latest = const <DriftPerson>[];
  final end = DateTime.now().add(const Duration(seconds: 60));
  while (DateTime.now().isBefore(end)) {
    latest = await peopleService.getAllPeople(minFaces: 1);
    if (matches(latest)) {
      return latest;
    }
    await _pumpFor(tester, const Duration(milliseconds: 500));
  }

  fail('$reason; latest local people=$latest');
}

Future<List<DriftPerson>> _waitForAssetPeopleState(
  WidgetTester tester,
  DriftPeopleService peopleService,
  String remoteAssetId,
  bool Function(List<DriftPerson> people) matches, {
  required String reason,
}) async {
  var latest = const <DriftPerson>[];
  final end = DateTime.now().add(const Duration(seconds: 60));
  while (DateTime.now().isBefore(end)) {
    latest = await peopleService.getAssetPeople(remoteAssetId);
    if (matches(latest)) {
      return latest;
    }
    await _pumpFor(tester, const Duration(milliseconds: 500));
  }

  fail('$reason; latest local asset people=$latest');
}

Future<List<(String, String)>> _waitForLocalPlacesState(
  WidgetTester tester,
  AssetService assetService,
  String userId,
  bool Function(List<(String, String)> places) matches, {
  required String reason,
}) async {
  var latest = const <(String, String)>[];
  final end = DateTime.now().add(const Duration(seconds: 60));
  while (DateTime.now().isBefore(end)) {
    latest = await assetService.getPlaces(userId);
    if (matches(latest)) {
      return latest;
    }
    await _pumpFor(tester, const Duration(milliseconds: 500));
  }

  fail('$reason; latest local places=$latest');
}

Future<int> _remoteAssetFaceRowCount(Drift drift, String remoteAssetId, String personId) async {
  final row = await drift
      .customSelect(
        '''
SELECT COUNT(*) AS count
FROM asset_face_entity
WHERE asset_id = ?
  AND person_id = ?
  AND is_visible = 1
  AND deleted_at IS NULL
''',
        variables: [Variable.withString(remoteAssetId), Variable.withString(personId)],
      )
      .getSingle();
  return row.read<int>('count');
}

Set<String> _serverSearchAssetIds(api.SearchResponseDto response) =>
    response.assets.items.map((asset) => asset.id).toSet();

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

Future<api.AlbumResponseDto> _waitForAlbumInfoState(
  WidgetTester tester,
  api.AlbumsApi albumsApi,
  String albumId,
  bool Function(api.AlbumResponseDto album) matches, {
  required String reason,
}) async {
  api.AlbumResponseDto? latest;
  Object? lastError;
  final end = DateTime.now().add(const Duration(seconds: 60));
  while (DateTime.now().isBefore(end)) {
    try {
      latest = await albumsApi.getAlbumInfo(albumId);
      if (latest != null && matches(latest)) {
        return latest;
      }
    } catch (error) {
      lastError = error;
    }
    await _pumpFor(tester, const Duration(milliseconds: 500));
  }

  fail('$reason; latest server album=$latest; last error=$lastError');
}

Future<RemoteAlbum> _waitForRemoteAlbumState(
  WidgetTester tester,
  ProviderContainer container,
  String albumId,
  bool Function(RemoteAlbum album) matches, {
  required String reason,
}) async {
  RemoteAlbum? latest;
  final end = DateTime.now().add(const Duration(seconds: 60));
  while (DateTime.now().isBefore(end)) {
    latest = await container.read(remoteAlbumServiceProvider).get(albumId);
    if (latest != null && matches(latest)) {
      return latest;
    }
    await _pumpFor(tester, const Duration(milliseconds: 500));
  }

  fail('$reason; latest local album=$latest');
}

Future<Set<String>> _waitForRemoteAlbumAssetIds(
  WidgetTester tester,
  ProviderContainer container,
  String albumId, {
  required Set<String> includes,
  required Set<String> excludes,
  required String reason,
}) async {
  var latestIds = const <String>{};
  final end = DateTime.now().add(const Duration(seconds: 60));
  while (DateTime.now().isBefore(end)) {
    final assets = await container.read(remoteAlbumServiceProvider).getAssets(albumId);
    latestIds = assets.map((asset) => asset.remoteId).whereType<String>().toSet();
    final hasExpected = includes.every(latestIds.contains);
    final hasNoUnexpected = excludes.every((assetId) => !latestIds.contains(assetId));
    if (hasExpected && hasNoUnexpected) {
      return latestIds;
    }
    await _pumpFor(tester, const Duration(milliseconds: 500));
  }

  final sorted = latestIds.toList()..sort();
  fail('$reason; latest album asset ids=${sorted.join(', ')}');
}

void _expectBulkSuccess(List<api.BulkIdResponseDto>? response, Set<String> ids, {required String reason}) {
  expect(response, isNotNull, reason: reason);
  final byId = {for (final result in response!) result.id: result};
  expect(byId.keys, containsAll(ids), reason: reason);
  for (final id in ids) {
    expect(byId[id]!.success, isTrue, reason: '$reason; result=${byId[id]}');
  }
}

void _expectBulkResultsAcceptedOrDuplicate(
  List<api.BulkIdResponseDto>? response,
  Set<String> ids, {
  required String reason,
}) {
  expect(response, isNotNull, reason: reason);
  final byId = {for (final result in response!) result.id: result};
  expect(byId.keys, containsAll(ids), reason: reason);
  for (final id in ids) {
    final result = byId[id]!;
    final isDuplicate = !result.success && result.error.orElse(null) == api.BulkIdErrorReason.duplicate;
    expect(result.success || isDuplicate, isTrue, reason: '$reason; result=$result');
  }
}

void _expectAssetInfoPreserved(api.AssetResponseDto restored, api.AssetResponseDto beforeTrash) {
  expect(restored.id, beforeTrash.id);
  expect(restored.checksum, beforeTrash.checksum, reason: 'Restore must not rewrite asset bytes');
  expect(restored.originalFileName, beforeTrash.originalFileName);
  expect(restored.originalPath, beforeTrash.originalPath, reason: 'Restore must keep the original media path');
  expect(restored.fileCreatedAt.toUtc(), beforeTrash.fileCreatedAt.toUtc());
  expect(restored.fileModifiedAt.toUtc(), beforeTrash.fileModifiedAt.toUtc());
  expect(restored.isFavorite, beforeTrash.isFavorite, reason: 'Restore must preserve favorite state');
  expect(restored.visibility, beforeTrash.visibility, reason: 'Restore must preserve visibility');
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

Future<void> _waitForRemoteAssetDeleted(
  WidgetTester tester,
  ProviderContainer container,
  String remoteAssetId, {
  required String reason,
}) async {
  RemoteAsset? latest;
  final end = DateTime.now().add(const Duration(seconds: 60));
  while (DateTime.now().isBefore(end)) {
    latest = await container.read(remoteAssetRepositoryProvider).get(remoteAssetId);
    if (latest == null) {
      return;
    }
    await _pumpFor(tester, const Duration(milliseconds: 500));
  }

  fail('$reason; latest local asset=$latest');
}

Future<void> _waitForAssetInfoUnavailable(
  WidgetTester tester,
  api.AssetsApi assetsApi,
  String remoteAssetId, {
  required String reason,
}) async {
  api.AssetResponseDto? latest;
  Object? lastError;
  final end = DateTime.now().add(const Duration(seconds: 60));
  while (DateTime.now().isBefore(end)) {
    try {
      latest = await assetsApi.getAssetInfo(remoteAssetId);
    } catch (error) {
      lastError = error;
      if (_isMissingAssetError(error)) {
        return;
      }
    }
    await _pumpFor(tester, const Duration(milliseconds: 500));
  }

  fail('$reason; latest server asset=$latest; last error=$lastError');
}

Future<void> _waitForRejectedResponse(
  WidgetTester tester,
  Future<http.Response> Function() request, {
  required String reason,
  Set<int> acceptedStatusCodes = const {400, 403, 404, 410},
}) async {
  http.Response? latest;
  Object? lastError;
  final end = DateTime.now().add(const Duration(seconds: 60));
  while (DateTime.now().isBefore(end)) {
    try {
      latest = await request();
      if (acceptedStatusCodes.contains(latest.statusCode)) {
        return;
      }
    } catch (error) {
      lastError = error;
      if (_isMissingAssetError(error)) {
        return;
      }
    }
    await _pumpFor(tester, const Duration(milliseconds: 500));
  }

  fail('$reason; latest status=${latest?.statusCode}; last error=$lastError');
}

bool _isMissingAssetError(Object error) => error is api.ApiException && (error.code == 404 || error.code == 410);

Future<Object?> _captureError(Future<void> Function() action) async {
  try {
    await action();
    return null;
  } catch (error) {
    return error;
  }
}

Future<void> _waitForServerReachability(
  WidgetTester tester,
  String apiEndpoint, {
  required bool reachable,
  required Duration timeout,
}) async {
  final pingUri = Uri.parse('$apiEndpoint/server/ping');
  final end = DateTime.now().add(timeout);
  Object? lastError;
  int? lastStatus;

  while (DateTime.now().isBefore(end)) {
    try {
      final response = await http.get(pingUri).timeout(const Duration(seconds: 2));
      lastStatus = response.statusCode;
      if (reachable && response.statusCode == 200) {
        return;
      }
      if (!reachable && response.statusCode != 200) {
        return;
      }
    } catch (error) {
      lastError = error;
      if (!reachable) {
        return;
      }
    }

    await _pumpFor(tester, const Duration(milliseconds: 500));
  }

  fail(
    'Timed out waiting for server reachable=$reachable at $pingUri after $timeout; '
    'lastStatus=$lastStatus lastError=$lastError. '
    'Host harness must restart the server after $_serverRestartReadyMarker.',
  );
}

Future<http.Response> _authenticatedApiGet(String path) {
  final endpoint = Store.get(StoreKey.serverEndpoint);
  final separator = path.startsWith('/') ? '' : '/';
  return http.get(
    Uri.parse('$endpoint$separator$path'),
    headers: {...ApiService.getRequestHeaders(), 'Authorization': 'Bearer ${Store.get(StoreKey.accessToken)}'},
  );
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

Future<int> _remoteAlbumRowCountById(Drift drift, String albumId) async {
  final row = await drift
      .customSelect(
        'SELECT COUNT(*) AS count FROM remote_album_entity WHERE id = ?',
        variables: [Variable.withString(albumId)],
      )
      .getSingle();
  return row.read<int>('count');
}

Future<int> _remoteAlbumAssetRowCountByAlbumId(Drift drift, String albumId) async {
  final row = await drift
      .customSelect(
        'SELECT COUNT(*) AS count FROM remote_album_asset_entity WHERE album_id = ?',
        variables: [Variable.withString(albumId)],
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
    await _pumpAllowingExpectedRemoteImage404s(tester, const Duration(milliseconds: 100));
  }
}

Future<void> _pumpUntil(WidgetTester tester, bool Function() condition, {required Duration timeout}) async {
  final end = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(end)) {
      throw TimeoutException('Timed out waiting for condition');
    }
    await _pumpAllowingExpectedRemoteImage404s(tester, const Duration(milliseconds: 100));
  }
}

Future<void> _pumpAllowingExpectedRemoteImage404s(WidgetTester tester, [Duration? duration]) async {
  try {
    await tester.pump(duration);
  } catch (error) {
    if (!_isExpectedRemoteImage404(error)) {
      rethrow;
    }
  }
  _takeExpectedRemoteImage404s(tester);
}

void _takeExpectedRemoteImage404s(WidgetTester tester) {
  Object? exception;
  while ((exception = tester.takeException()) != null) {
    if (_isExpectedRemoteImage404(exception!)) {
      continue;
    }
    fail('Unexpected Flutter exception: $exception');
  }
}

bool _isExpectedRemoteImage404(Object exception) {
  if (exception is PlatformException) {
    return exception.code == 'IOException' && exception.message?.contains('HTTP 404') == true;
  }

  final text = exception.toString();
  return text.contains('PlatformException(IOException') && text.contains('HTTP 404');
}
