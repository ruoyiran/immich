import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:background_downloader/background_downloader.dart';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:immich_mobile/constants/aspect_ratios.dart';
import 'package:immich_mobile/constants/constants.dart';
import 'package:immich_mobile/constants/enums.dart';
import 'package:immich_mobile/domain/models/album/album.model.dart';
import 'package:immich_mobile/domain/models/album/local_album.model.dart';
import 'package:immich_mobile/domain/models/asset/base_asset.model.dart';
import 'package:immich_mobile/domain/models/asset_edit.model.dart';
import 'package:immich_mobile/domain/models/events.model.dart';
import 'package:immich_mobile/domain/models/exif.model.dart';
import 'package:immich_mobile/domain/models/memory.model.dart';
import 'package:immich_mobile/domain/models/ocr.model.dart';
import 'package:immich_mobile/domain/models/person.model.dart';
import 'package:immich_mobile/domain/models/settings_key.dart';
import 'package:immich_mobile/domain/models/store.model.dart';
import 'package:immich_mobile/domain/models/sync_event.model.dart';
import 'package:immich_mobile/domain/models/time_range.model.dart';
import 'package:immich_mobile/domain/models/timeline.model.dart';
import 'package:immich_mobile/domain/models/user.model.dart';
import 'package:immich_mobile/domain/services/asset.service.dart';
import 'package:immich_mobile/domain/services/people.service.dart';
import 'package:immich_mobile/domain/services/search.service.dart';
import 'package:immich_mobile/domain/services/timeline.service.dart';
import 'package:immich_mobile/domain/utils/event_stream.dart';
import 'package:immich_mobile/entities/store.entity.dart';
import 'package:immich_mobile/infrastructure/repositories/db.repository.dart';
import 'package:immich_mobile/infrastructure/repositories/settings.repository.dart';
import 'package:immich_mobile/infrastructure/repositories/storage.repository.dart';
import 'package:immich_mobile/infrastructure/repositories/sync_api.repository.dart';
import 'package:immich_mobile/infrastructure/repositories/timeline.repository.dart';
import 'package:immich_mobile/main.dart' as app;
import 'package:immich_mobile/models/auth/biometric_status.model.dart';
import 'package:immich_mobile/models/folder/recursive_folder.model.dart';
import 'package:immich_mobile/models/folder/root_folder.model.dart';
import 'package:immich_mobile/models/search/search_filter.model.dart';
import 'package:immich_mobile/models/shared_link/shared_link.model.dart';
import 'package:immich_mobile/models/upload/share_intent_attachment.model.dart';
import 'package:immich_mobile/pages/common/app_log.page.dart';
import 'package:immich_mobile/pages/common/headers_settings.page.dart';
import 'package:immich_mobile/pages/common/settings.page.dart';
import 'package:immich_mobile/pages/library/folder/folder.page.dart';
import 'package:immich_mobile/pages/library/locked/pin_auth.page.dart';
import 'package:immich_mobile/pages/library/partner/partner.page.dart';
import 'package:immich_mobile/pages/library/shared_link/shared_link.page.dart';
import 'package:immich_mobile/pages/library/shared_link/shared_link_edit.page.dart';
import 'package:immich_mobile/pages/login/change_password.page.dart';
import 'package:immich_mobile/pages/login/login.page.dart';
import 'package:immich_mobile/pages/search/map/map_location_picker.page.dart';
import 'package:immich_mobile/pages/settings/sync_status.page.dart';
import 'package:immich_mobile/pages/share_intent/share_intent.page.dart';
import 'package:immich_mobile/presentation/pages/cleanup_preview.page.dart';
import 'package:immich_mobile/presentation/pages/dev/main_timeline.page.dart';
import 'package:immich_mobile/presentation/pages/dev/media_stat.page.dart';
import 'package:immich_mobile/presentation/pages/download_info.page.dart';
import 'package:immich_mobile/presentation/pages/drift_activities.page.dart';
import 'package:immich_mobile/presentation/pages/drift_album.page.dart';
import 'package:immich_mobile/presentation/pages/drift_album_options.page.dart';
import 'package:immich_mobile/presentation/pages/drift_archive.page.dart';
import 'package:immich_mobile/presentation/pages/drift_asset_selection_timeline.page.dart';
import 'package:immich_mobile/presentation/pages/drift_asset_troubleshoot.page.dart';
import 'package:immich_mobile/presentation/pages/drift_favorite.page.dart';
import 'package:immich_mobile/presentation/pages/drift_library.page.dart';
import 'package:immich_mobile/presentation/pages/drift_local_album.page.dart';
import 'package:immich_mobile/presentation/pages/drift_locked_folder.page.dart';
import 'package:immich_mobile/presentation/pages/drift_map.page.dart';
import 'package:immich_mobile/presentation/pages/drift_memory.page.dart';
import 'package:immich_mobile/presentation/pages/drift_partner_detail.page.dart';
import 'package:immich_mobile/presentation/pages/drift_people_collection.page.dart';
import 'package:immich_mobile/presentation/pages/drift_person.page.dart';
import 'package:immich_mobile/presentation/pages/drift_place.page.dart';
import 'package:immich_mobile/presentation/pages/drift_place_detail.page.dart';
import 'package:immich_mobile/presentation/pages/drift_recently_added.page.dart';
import 'package:immich_mobile/presentation/pages/drift_recently_taken.page.dart';
import 'package:immich_mobile/presentation/pages/drift_remote_album.page.dart';
import 'package:immich_mobile/presentation/pages/drift_slideshow.page.dart';
import 'package:immich_mobile/presentation/pages/drift_trash.page.dart';
import 'package:immich_mobile/presentation/pages/drift_video.page.dart';
import 'package:immich_mobile/presentation/pages/edit/drift_edit.page.dart';
import 'package:immich_mobile/presentation/pages/edit/editor.provider.dart';
import 'package:immich_mobile/presentation/pages/feature_message/whats_new.page.dart';
import 'package:immich_mobile/presentation/pages/local_timeline.page.dart';
import 'package:immich_mobile/presentation/pages/profile/profile_picture_crop.page.dart';
import 'package:immich_mobile/presentation/pages/search/drift_search.page.dart';
import 'package:immich_mobile/presentation/pages/search/paginated_search.provider.dart';
import 'package:immich_mobile/presentation/widgets/album/album_selector.widget.dart';
import 'package:immich_mobile/presentation/widgets/asset_viewer/asset_details/date_time_details.widget.dart';
import 'package:immich_mobile/presentation/widgets/asset_viewer/asset_details/location_details.widget.dart';
import 'package:immich_mobile/presentation/widgets/asset_viewer/asset_details/rating_details.widget.dart';
import 'package:immich_mobile/presentation/widgets/asset_viewer/asset_stack.widget.dart';
import 'package:immich_mobile/presentation/widgets/asset_viewer/asset_viewer.page.dart';
import 'package:immich_mobile/presentation/widgets/asset_viewer/ocr_overlay.widget.dart';
import 'package:immich_mobile/presentation/widgets/asset_viewer/video_viewer.widget.dart';
import 'package:immich_mobile/presentation/widgets/bottom_sheet/archive_bottom_sheet.widget.dart';
import 'package:immich_mobile/presentation/widgets/bottom_sheet/favorite_bottom_sheet.widget.dart';
import 'package:immich_mobile/presentation/widgets/bottom_sheet/general_bottom_sheet.widget.dart';
import 'package:immich_mobile/presentation/widgets/bottom_sheet/locked_folder_bottom_sheet.widget.dart';
import 'package:immich_mobile/presentation/widgets/bottom_sheet/remote_album_bottom_sheet.widget.dart';
import 'package:immich_mobile/presentation/widgets/bottom_sheet/trash_bottom_sheet.widget.dart';
import 'package:immich_mobile/presentation/widgets/images/thumbnail_tile.widget.dart';
import 'package:immich_mobile/presentation/widgets/map/map.state.dart';
import 'package:immich_mobile/presentation/widgets/timeline/header.widget.dart';
import 'package:immich_mobile/presentation/widgets/timeline/timeline.widget.dart';
import 'package:immich_mobile/providers/api.provider.dart';
import 'package:immich_mobile/providers/asset_viewer/asset_viewer.provider.dart';
import 'package:immich_mobile/providers/asset_viewer/share_intent_upload.provider.dart';
import 'package:immich_mobile/providers/asset_viewer/video_player_provider.dart';
import 'package:immich_mobile/providers/auth.provider.dart';
import 'package:immich_mobile/providers/background_sync.provider.dart';
import 'package:immich_mobile/providers/folder.provider.dart';
import 'package:immich_mobile/providers/gallery_permission.provider.dart';
import 'package:immich_mobile/providers/infrastructure/action.provider.dart';
import 'package:immich_mobile/providers/infrastructure/album.provider.dart';
import 'package:immich_mobile/providers/infrastructure/asset.provider.dart';
import 'package:immich_mobile/providers/infrastructure/asset_viewer/asset.provider.dart';
import 'package:immich_mobile/providers/infrastructure/cancel.provider.dart';
import 'package:immich_mobile/providers/infrastructure/db.provider.dart';
import 'package:immich_mobile/providers/infrastructure/map.provider.dart';
import 'package:immich_mobile/providers/infrastructure/memory.provider.dart';
import 'package:immich_mobile/providers/infrastructure/ocr.provider.dart';
import 'package:immich_mobile/providers/infrastructure/people.provider.dart';
import 'package:immich_mobile/providers/infrastructure/remote_album.provider.dart';
import 'package:immich_mobile/providers/infrastructure/search.provider.dart';
import 'package:immich_mobile/providers/infrastructure/settings.provider.dart';
import 'package:immich_mobile/providers/infrastructure/storage.provider.dart';
import 'package:immich_mobile/providers/infrastructure/sync.provider.dart';
import 'package:immich_mobile/providers/infrastructure/tag.provider.dart';
import 'package:immich_mobile/providers/infrastructure/timeline.provider.dart';
import 'package:immich_mobile/providers/infrastructure/user.provider.dart';
import 'package:immich_mobile/providers/shared_link.provider.dart';
import 'package:immich_mobile/providers/tab.provider.dart';
import 'package:immich_mobile/providers/timeline/multiselect.provider.dart';
import 'package:immich_mobile/providers/upload_profile_image.provider.dart';
import 'package:immich_mobile/providers/user.provider.dart';
import 'package:immich_mobile/providers/websocket.provider.dart';
import 'package:immich_mobile/repositories/asset_api.repository.dart';
import 'package:immich_mobile/repositories/asset_media.repository.dart';
import 'package:immich_mobile/repositories/auth_api.repository.dart';
import 'package:immich_mobile/repositories/biometric.repository.dart';
import 'package:immich_mobile/repositories/download.repository.dart';
import 'package:immich_mobile/repositories/file_media.repository.dart';
import 'package:immich_mobile/routing/router.dart';
import 'package:immich_mobile/services/api.service.dart';
import 'package:immich_mobile/services/download.service.dart';
import 'package:immich_mobile/services/foreground_upload.service.dart';
import 'package:immich_mobile/services/secure_storage.service.dart';
import 'package:immich_mobile/services/shared_link.service.dart';
import 'package:immich_mobile/utils/bootstrap.dart';
import 'package:immich_mobile/utils/editor.utils.dart';
import 'package:immich_mobile/utils/option.dart';
import 'package:immich_mobile/utils/semver.dart';
import 'package:immich_mobile/utils/url_helper.dart';
import 'package:immich_mobile/widgets/asset_viewer/video_controls.dart';
import 'package:immich_mobile/widgets/common/confirm_dialog.dart';
import 'package:immich_mobile/widgets/common/selection_sliver_app_bar.dart';
import 'package:immich_mobile/widgets/forms/change_password_form.dart';
import 'package:immich_mobile/widgets/photo_view/photo_view.dart';
import 'package:immich_mobile/widgets/settings/asset_viewer_settings/slideshow_settings.dart';
import 'package:immich_mobile/widgets/settings/beta_sync_settings/sync_status_and_actions.dart';
import 'package:local_auth/local_auth.dart'
    show BiometricType, LocalAuthentication;
import 'package:logging/logging.dart' show Logger;
import 'package:maplibre_gl/maplibre_gl.dart' show LatLng, LatLngBounds;
import 'package:openapi/api.dart' as api;
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart' hide AssetType, LatLng;

import 'test_utils/general_helper.dart';

const _caseSuffix = String.fromEnvironment(
  'IMMICH_E2E_CASE_SUFFIX',
  defaultValue: 'A',
);
const _selectedCaseId = String.fromEnvironment('IMMICH_E2E_CASE_ID');
const _serverUrl = String.fromEnvironment('IMMICH_E2E_SERVER_URL');
const _badServerUrl = String.fromEnvironment(
  'IMMICH_E2E_BAD_SERVER_URL',
  defaultValue: 'http://10.0.2.2:9',
);
const _email = String.fromEnvironment('IMMICH_E2E_EMAIL');
const _password = String.fromEnvironment('IMMICH_E2E_PASSWORD');
const _albumSharingCollaboratorId = String.fromEnvironment(
  'IMMICH_E2E_ALBUM_SHARING_COLLABORATOR_ID',
  defaultValue: 'a5400000-0000-4000-8000-000000000001',
);
const _albumSharingViewerId = String.fromEnvironment(
  'IMMICH_E2E_ALBUM_SHARING_VIEWER_ID',
  defaultValue: 'a5400000-0000-4000-8000-000000000002',
);
const _albumSharingCollaboratorEmail = String.fromEnvironment(
  'IMMICH_E2E_ALBUM_SHARING_COLLABORATOR_EMAIL',
  defaultValue: 'immich-e2e-054-collaborator@example.test',
);
const _albumSharingViewerEmail = String.fromEnvironment(
  'IMMICH_E2E_ALBUM_SHARING_VIEWER_EMAIL',
  defaultValue: 'immich-e2e-054-viewer@example.test',
);
const _albumSharingCollaboratorPasswordOverride = String.fromEnvironment(
  'IMMICH_E2E_ALBUM_SHARING_COLLABORATOR_PASSWORD',
);
const _albumSharingViewerPasswordOverride = String.fromEnvironment(
  'IMMICH_E2E_ALBUM_SHARING_VIEWER_PASSWORD',
);
const _partnerSharingId = String.fromEnvironment(
  'IMMICH_E2E_PARTNER_SHARING_ID',
  defaultValue: 'd5700000-0000-4000-8000-000000000057',
);
const _partnerSharingEmail = String.fromEnvironment(
  'IMMICH_E2E_PARTNER_SHARING_EMAIL',
  defaultValue: 'immich-e2e-057-partner@example.test',
);
const _partnerSharingPasswordOverride = String.fromEnvironment(
  'IMMICH_E2E_PARTNER_SHARING_PASSWORD',
);
const _deviceId = String.fromEnvironment(
  'IMMICH_E2E_DEVICE_ID',
  defaultValue: 'immich-mobile-e2e-device',
);
const _uploadAssetName = String.fromEnvironment(
  'IMMICH_E2E_UPLOAD_ASSET_NAME',
  defaultValue: 'immich-e2e-upload-008.jpg',
);
const _batchAssetPrefix = String.fromEnvironment(
  'IMMICH_E2E_BATCH_ASSET_PREFIX',
  defaultValue: 'immich-e2e-batch-009-',
);
const _batchAssetCount = int.fromEnvironment(
  'IMMICH_E2E_BATCH_ASSET_COUNT',
  defaultValue: 20,
);
const _videoAssetName = String.fromEnvironment(
  'IMMICH_E2E_VIDEO_ASSET_NAME',
  defaultValue: 'immich-e2e-video-010.mp4',
);
const _duplicateAssetPrefix = String.fromEnvironment(
  'IMMICH_E2E_DUPLICATE_ASSET_PREFIX',
  defaultValue: 'immich-e2e-duplicate-011-',
);
const _duplicateAssetCount = int.fromEnvironment(
  'IMMICH_E2E_DUPLICATE_ASSET_COUNT',
  defaultValue: 2,
);
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
const _timelineMinimumAssetCount = int.fromEnvironment(
  'IMMICH_E2E_TIMELINE_MIN_ASSET_COUNT',
  defaultValue: 24,
);
const _timelinePageSize = int.fromEnvironment(
  'IMMICH_E2E_TIMELINE_PAGE_SIZE',
  defaultValue: 8,
);
const _assetViewerImageCount = int.fromEnvironment(
  'IMMICH_E2E_VIEWER_IMAGE_COUNT',
  defaultValue: 3,
);
const _serverRestartReadyMarker = 'MOB-REAL-030:READY_FOR_SERVER_RESTART';
const _upgradeStage = String.fromEnvironment(
  'IMMICH_E2E_UPGRADE_STAGE',
  defaultValue: 'single',
);
const _upgradeSnapshotFilename = 'mob-real-032-upgrade-snapshot.json';
const _upgradeExpectedBackupSettings = <String, Object>{
  'backupEnabled': true,
  'backupUseCellularForPhotos': true,
  'backupUseCellularForVideos': true,
  'backupRequireCharging': true,
  'backupTriggerDelay': 17,
};
const _multiSelectMinimumAssetCount = int.fromEnvironment(
  'IMMICH_E2E_MULTISELECT_MIN_ASSET_COUNT',
  defaultValue: 60,
);
const _multiSelectRemoteSeedPrefix = String.fromEnvironment(
  'IMMICH_E2E_MULTISELECT_REMOTE_SEED_PREFIX',
  defaultValue: 'immich-e2e-multiselect-038-remote-',
);
const _similarTargetAssetId = String.fromEnvironment(
  'IMMICH_E2E_SIMILAR_TARGET_ASSET_ID',
);
const _similarCandidateAssetId = String.fromEnvironment(
  'IMMICH_E2E_SIMILAR_CANDIDATE_ASSET_ID',
);
const _similarControlAssetId = String.fromEnvironment(
  'IMMICH_E2E_SIMILAR_CONTROL_ASSET_ID',
);

String get _albumSharingCollaboratorPassword =>
    _albumSharingCollaboratorPasswordOverride.isEmpty
    ? _password
    : _albumSharingCollaboratorPasswordOverride;

String get _albumSharingViewerPassword =>
    _albumSharingViewerPasswordOverride.isEmpty
    ? _password
    : _albumSharingViewerPasswordOverride;
const _lockedFolderPin = '123456';
const _lockedFolderWrongPin = '000000';

var _registeredSelectedCase = false;

class _ScriptedBiometricRepository extends BiometricRepository {
  final List<bool> _results;
  int _index = 0;

  _ScriptedBiometricRepository(this._results) : super(LocalAuthentication());

  @override
  Future<BiometricStatus> getStatus() async {
    return const BiometricStatus(
      availableBiometrics: [BiometricType.fingerprint],
      canAuthenticate: true,
    );
  }

  @override
  Future<bool> authenticate(String? message) async {
    if (_results.isEmpty) {
      return true;
    }
    final index = _index < _results.length ? _index : _results.length - 1;
    final value = _results[index];
    _index++;
    return value;
  }
}

void main() async {
  await ImmichTestHelper.initialize();

  group('real stack auth', () {
    _realStackAuthTest(
      'MOB-REAL-001-$_caseSuffix',
      'discovers real server capabilities',
      (tester, _) async {
        await _waitForLoginScreen(tester);
        await _enterServerUrl(tester, _serverUrl);
        await _tapTranslatedButton(tester, 'next');

        await _waitForCredentialFields(tester);
        expect(Store.tryGet(StoreKey.serverEndpoint), endsWith('/api'));
        expect(
          Store.tryGet(StoreKey.serverEndpoint),
          contains(Uri.parse(_serverUrl).host),
        );
        expect(Store.tryGet(StoreKey.accessToken), isNull);
      },
    );

    _realStackAuthTest(
      'MOB-REAL-002-$_caseSuffix',
      'logs in with real owner credentials',
      (tester, _) async {
        await _login(
          tester,
          serverUrl: _serverUrl,
          email: _email,
          password: _password,
        );
        await _waitForAccessToken(tester);
        await _waitForCurrentUser(_email, tester);

        final user = Store.tryGet(StoreKey.currentUser);
        expect(user!.email, _email);
        expect(Store.tryGet(StoreKey.serverEndpoint), endsWith('/api'));
      },
    );

    _realStackAuthTest(
      'MOB-REAL-003-$_caseSuffix',
      'recovers after bad server and bad password',
      (tester, _) async {
        await _waitForLoginScreen(tester);
        await _enterServerUrl(tester, _badServerUrl);
        await _tapTranslatedButton(tester, 'next');
        await tester.pump(const Duration(seconds: 2));
        expect(Store.tryGet(StoreKey.accessToken), isNull);

        await _enterServerUrl(tester, _serverUrl);
        await _tapTranslatedButton(tester, 'next');
        await _waitForCredentialFields(tester);

        await _enterCredentials(
          tester,
          email: _email,
          password: '${_password}x',
        );
        await _tapTranslatedButton(tester, 'login');
        await pumpUntilFound(
          tester,
          find.text('login_form_failed_login'.tr()),
          timeout: const Duration(seconds: 30),
        );
        expect(Store.tryGet(StoreKey.accessToken), isNull);

        await _enterCredentials(tester, email: _email, password: _password);
        await _tapTranslatedButton(tester, 'login');
        await _waitForAccessToken(tester);
        await _waitForCurrentUser(_email, tester);
      },
    );

    _realStackSessionTest(
      'MOB-REAL-004-$_caseSuffix',
      'resumes persisted session after app restart',
      (tester) async {
        await _loadAppPreservingStore(tester);
        await _waitForAccessToken(tester);
        await _waitForCurrentUser(_email, tester);
        expect(Store.tryGet(StoreKey.serverEndpoint), endsWith('/api'));
        expect(
          Store.tryGet(StoreKey.serverEndpoint),
          contains(Uri.parse(_serverUrl).host),
        );
      },
    );

    _realStackSessionTest(
      'MOB-REAL-005-$_caseSuffix',
      'sees granted full gallery permission',
      (tester) async {
        await _loadAppPreservingStore(tester);
        await _waitForAccessToken(tester);
        await _waitForCurrentUser(_email, tester);

        final container = _containerOfApp(tester);
        final status = await container
            .read(galleryPermissionNotifier.notifier)
            .getGalleryPermissionStatus();
        expect(status, DevicePermissionStatus.granted);
      },
    );

    _realStackSessionTest(
      'MOB-REAL-006-$_caseSuffix',
      'honors limited gallery permission expansion',
      (tester) async {
        await _loadAuthenticatedApp(tester);
        await PhotoManager.setIgnorePermissionCheck(false);
        addTearDown(() async => PhotoManager.setIgnorePermissionCheck(true));

        final container = _containerOfApp(tester);
        final initialStatus = await container
            .read(galleryPermissionNotifier.notifier)
            .requestGalleryPermission();
        expect(initialStatus, DevicePermissionStatus.limited);

        await container.read(backgroundSyncProvider).syncLocal(full: true);
        final initialAssetNames = await _localAssetNames(container);
        expect(
          initialAssetNames,
          isNot(contains('immich-e2e-limited-extra.mp4')),
        );

        final expandedStatus = await container
            .read(galleryPermissionNotifier.notifier)
            .requestGalleryPermission();
        expect(expandedStatus.hasAccess, isTrue);

        await container.read(backgroundSyncProvider).syncLocal(full: true);
        final expandedAssetNames = await _localAssetNames(container);
        expect(
          expandedAssetNames.length,
          greaterThan(initialAssetNames.length),
        );
        expect(expandedAssetNames, contains('immich-e2e-limited-extra.mp4'));
      },
    );

    _realStackSessionTest(
      'MOB-REAL-007-$_caseSuffix',
      'syncs local media from the simulator gallery',
      (tester) async {
        await _loadAppPreservingStore(tester);
        await _waitForAccessToken(tester);
        await _waitForCurrentUser(_email, tester);

        final container = _containerOfApp(tester);
        await container.read(backgroundSyncProvider).syncLocal(full: true);

        final assetNames = await _localAssetNames(container);

        expect(
          assetNames,
          containsAll([
            'immich-e2e-red.jpg',
            'immich-e2e-green.jpg',
            'immich-e2e-video.mp4',
          ]),
        );
        expect(assetNames.length, assetNames.toSet().length);
      },
    );

    _realStackSessionTest(
      'MOB-REAL-008-$_caseSuffix',
      'uploads one JPEG to the real server',
      (tester) async {
        await _loadAuthenticatedApp(tester);

        final container = _containerOfApp(tester);
        final asset = await _waitForLocalAssetByName(
          container,
          _uploadAssetName,
          tester,
        );
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
        final downloaded = await container
            .read(assetApiRepositoryProvider)
            .downloadAsset(remoteAssetId!, edited: false);
        expect(downloaded.statusCode, 200);
        expect(downloaded.bodyBytes, isNotEmpty);
      },
    );

    _realStackSessionTest(
      'MOB-REAL-009-$_caseSuffix',
      'uploads a batch of mixed photos with monotonic progress',
      (tester) async {
        await _loadAuthenticatedApp(tester);

        final container = _containerOfApp(tester);
        final assets = await _waitForLocalAssetsByPrefix(
          container,
          _batchAssetPrefix,
          _batchAssetCount,
          tester,
        );
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
          final downloaded = await container
              .read(assetApiRepositoryProvider)
              .downloadAsset(remoteId, edited: false);
          expect(downloaded.statusCode, 200);
          expect(downloaded.bodyBytes, isNotEmpty);
        }
      },
    );

    _realStackSessionTest(
      'MOB-REAL-010-$_caseSuffix',
      'uploads an MP4 and verifies thumbnail and playback',
      (tester) async {
        await _loadAuthenticatedApp(tester);

        final container = _containerOfApp(tester);
        final asset = await _waitForLocalAssetByName(
          container,
          _videoAssetName,
          tester,
        );
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

        final original = await container
            .read(assetApiRepositoryProvider)
            .downloadAsset(remoteAssetId!, edited: false);
        expect(original.statusCode, 200);
        expect(original.bodyBytes, isNotEmpty);

        final thumbnail = await _waitForSuccessfulResponse(
          tester,
          () => assetsApi.viewAssetWithHttpInfo(
            remoteAssetId!,
            size: api.AssetMediaSize.thumbnail,
          ),
        );
        expect(thumbnail.bodyBytes, isNotEmpty);

        final playback = await _waitForSuccessfulResponse(
          tester,
          () => assetsApi.playAssetVideoWithHttpInfo(remoteAssetId!),
          acceptedStatusCodes: const {200, 206},
        );
        expect(playback.bodyBytes, isNotEmpty);
      },
    );

    _realStackSessionTest(
      'MOB-REAL-011-$_caseSuffix',
      'deduplicates repeated backups by MD5 and size',
      (tester) async {
        await _loadAuthenticatedApp(tester);

        final container = _containerOfApp(tester);
        final assets = await _waitForLocalAssetsByPrefix(
          container,
          _duplicateAssetPrefix,
          _duplicateAssetCount,
          tester,
        );
        expect(assets.every((asset) => asset.isImage), isTrue);
        expect(
          assets.map((asset) => asset.name).toSet().length,
          _duplicateAssetCount,
        );

        final firstRemoteId = await _uploadSingleAssetToServer(
          container,
          assets[0],
        );
        final secondRemoteId = await _uploadSingleAssetToServer(
          container,
          assets[1],
        );

        expect(secondRemoteId, firstRemoteId);

        final downloaded = await container
            .read(assetApiRepositoryProvider)
            .downloadAsset(firstRemoteId, edited: false);
        expect(downloaded.statusCode, 200);
        expect(downloaded.bodyBytes, isNotEmpty);
      },
    );

    _realStackSessionTest(
      'MOB-REAL-012-$_caseSuffix',
      'resumes interrupted upload from server offset',
      (tester) async {
        await _loadAuthenticatedApp(tester);

        final container = _containerOfApp(tester);
        final asset = await _waitForLocalAssetByName(
          container,
          _resumableAssetName,
          tester,
        );
        final contentSize = asset.contentSize;
        if (contentSize == null) {
          fail(
            'Resumable upload asset $_resumableAssetName has no known content size',
          );
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
                  if (!cancel.isCompleted &&
                      bytes >= _resumableCancelAfterBytes) {
                    cancel.complete();
                  }
                },
                onSuccess: (_, remoteId) => interruptedRemoteId = remoteId,
                onError: (_, errorMessage) => interruptedError = errorMessage,
              ),
            );

        expect(interruptedRemoteId, isNull);
        expect(interruptedError, isNull);
        expect(
          firstProgress.every((bytes) => bytes >= 0 && bytes <= contentSize),
          isTrue,
        );
        expect(
          firstProgress.any((bytes) => bytes >= _resumableCancelAfterBytes),
          isTrue,
        );

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
        expect(
          retryProgress.every((bytes) => bytes >= 0 && bytes <= cancelledSize),
          isTrue,
        );
        expect(
          retryProgress.firstWhere((bytes) => bytes > 0),
          greaterThanOrEqualTo(cancelledOffset),
        );
        expect(retryProgress.last, cancelledSize);
        expect(await _resumableStateFiles(), isEmpty);
      },
    );

    _realStackSessionTest(
      'MOB-REAL-013-$_caseSuffix',
      'keeps upload stable across lifecycle changes',
      (tester) async {
        await _loadAuthenticatedApp(tester);

        final container = _containerOfApp(tester);
        final asset = await _waitForLocalAssetByName(
          container,
          _lifecycleAssetName,
          tester,
        );
        final contentSize = asset.contentSize;
        if (contentSize == null) {
          fail(
            'Lifecycle upload asset $_lifecycleAssetName has no known content size',
          );
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
          () =>
              progress.any((bytes) => bytes > 0) ||
              remoteAssetId != null ||
              uploadError != null,
          timeout: const Duration(seconds: 90),
        );
        expect(uploadError, isNull);
        expect(remoteAssetId, isNull);

        for (var i = 0; i < 2; i++) {
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.paused,
          );
          await Future<void>.delayed(const Duration(seconds: 2));
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          );
          await tester.pump();
          await Future<void>.delayed(const Duration(seconds: 2));
        }

        await upload.timeout(const Duration(minutes: 5));
        expect(uploadError, isNull);
        expect(remoteAssetId, isNotNull);
        expect(progress, isNotEmpty);
        expect(
          progress.every((bytes) => bytes >= 0 && bytes <= contentSize),
          isTrue,
        );
        for (var i = 1; i < progress.length; i++) {
          expect(progress[i], greaterThanOrEqualTo(progress[i - 1]));
        }
        expect(await _resumableStateFiles(), isEmpty);

        final info = await container
            .read(apiServiceProvider)
            .assetsApi
            .getAssetInfo(remoteAssetId!);
        expect(info, isNotNull);
      },
    );

    _realStackSessionTest(
      'MOB-REAL-014-$_caseSuffix',
      'uploads and replays Android Motion HEIC originals',
      (tester) async {
        await _loadAuthenticatedApp(tester);

        final container = _containerOfApp(tester);
        final asset = await _waitForLocalAssetByName(
          container,
          _motionPhotoAssetName,
          tester,
        );
        expect(asset.isImage, isTrue);
        expect(asset.isMotionPhoto, isTrue);

        final files = await StorageRepository().getLivePhotoFilesForAsset(
          asset,
        );
        expect(files, isNotNull);
        expect(files!.still.existsSync(), isTrue);
        expect(files.motion.existsSync(), isTrue);
        expect(files.still.lengthSync(), greaterThan(32));
        expect(files.motion.lengthSync(), greaterThan(32));

        final remoteAssetId = await _uploadSingleAssetToServer(
          container,
          asset,
        );
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
            Uri.parse(
              '${Store.get(StoreKey.serverEndpoint)}/assets/$remoteAssetId/original',
            ),
            headers: {
              ...ApiService.getRequestHeaders(),
              'Authorization': 'Bearer ${Store.get(StoreKey.accessToken)}',
              DownloadRepository.livePhotoFormatHeader:
                  DownloadRepository.androidMotionHeicFormat,
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

        final duplicateRemoteId = await _uploadSingleAssetToServer(
          container,
          asset,
        );
        expect(duplicateRemoteId, remoteAssetId);
      },
    );

    _realStackSessionTest(
      'MOB-REAL-015-$_caseSuffix',
      'preserves image metadata through upload',
      (tester) async {
        await _loadAuthenticatedApp(tester);

        final container = _containerOfApp(tester);
        final exifAsset = await _waitForLocalAssetByName(
          container,
          _metadataExifAssetName,
          tester,
        );
        final noExifAsset = await _waitForLocalAssetByName(
          container,
          _metadataNoExifAssetName,
          tester,
        );

        expect(exifAsset.isImage, isTrue);
        expect(exifAsset.orientation, 90);
        expect(exifAsset.width, 90);
        expect(exifAsset.height, 160);

        final exifRemoteId = await _uploadSingleAssetToServer(
          container,
          exifAsset,
        );
        final noExifRemoteId = await _uploadSingleAssetToServer(
          container,
          noExifAsset,
        );
        expect(noExifRemoteId, isNot(exifRemoteId));

        final assetsApi = container.read(apiServiceProvider).assetsApi;
        final exifInfo = await _waitForAssetInfo(
          tester,
          assetsApi,
          exifRemoteId,
        );
        expect(exifInfo.type, api.AssetTypeEnum.IMAGE);
        expect(exifInfo.originalFileName.toLowerCase(), endsWith('.jpg'));
        expect(exifInfo.width, 90);
        expect(exifInfo.height, 160);
        _expectUtcDateTimeParts(exifInfo.fileCreatedAt, 2024, 12, 31, 23, 30);

        final exif = exifInfo.exifInfo.orElse(null);
        expect(exif, isNotNull);
        expect(exif!.dateTimeOriginal.orElse(null), isNotNull);
        _expectUtcDateTimeParts(
          exif.dateTimeOriginal.orElse(null)!,
          2024,
          12,
          31,
          23,
          30,
        );
        expect(exif.exifImageWidth.orElse(null), 90);
        expect(exif.exifImageHeight.orElse(null), 160);
        expect(exif.make.orElse(null), 'ImmichE2E');
        expect(exif.model.orElse(null), 'Metadata015');
        expect(exif.latitude.orElse(null), closeTo(27.717245, 0.0001));
        expect(exif.longitude.orElse(null), closeTo(85.323959, 0.0001));

        final noExifInfo = await _waitForAssetInfo(
          tester,
          assetsApi,
          noExifRemoteId,
        );
        expect(noExifInfo.type, api.AssetTypeEnum.IMAGE);
        expect(noExifInfo.originalFileName.toLowerCase(), endsWith('.jpg'));
        expect(noExifInfo.width, 120);
        expect(noExifInfo.height, 80);
        _expectDateTimesClose(
          noExifInfo.fileCreatedAt,
          noExifAsset.createdAt,
          const Duration(minutes: 2),
        );
        final noExif = noExifInfo.exifInfo.orElse(null);
        expect(noExif, isNotNull);
        expect(noExif!.make.orElse(null), isNull);
        expect(noExif.model.orElse(null), isNull);
        expect(noExif.latitude.orElse(null), isNull);
        expect(noExif.longitude.orElse(null), isNull);
      },
    );

    _realStackSessionTest(
      'MOB-REAL-016-$_caseSuffix',
      'loads timeline first page, pagination, and date buckets',
      (tester) async {
        await _loadAuthenticatedApp(tester);

        final container = _containerOfApp(tester);
        final syncSuccess = await container
            .read(backgroundSyncProvider)
            .syncRemote();
        expect(syncSuccess, isTrue);

        final user = Store.tryGet(StoreKey.currentUser);
        expect(user, isNotNull);

        final timeline = container.read(timelineFactoryProvider).main([
          user!.id,
        ]);
        addTearDown(timeline.dispose);

        final buckets = await _waitForTimelineBuckets(
          tester,
          timeline,
          minAssets: _timelineMinimumAssetCount,
        );
        expect(
          timeline.totalAssets,
          greaterThanOrEqualTo(_timelineMinimumAssetCount),
        );
        expect(
          buckets.length,
          greaterThanOrEqualTo(2),
          reason: 'Expected cross-month seed data in the real timeline',
        );

        final totalFromBuckets = buckets.fold<int>(
          0,
          (total, bucket) => total + bucket.assetCount,
        );
        expect(totalFromBuckets, timeline.totalAssets);
        _expectTimelineBucketsDescending(buckets);
        expect(_spansMultipleMonths(buckets), isTrue);

        await _exerciseTimelineUiPagination(tester);

        final firstPageCount = _timelineCountForPage(timeline.totalAssets, 0);
        final firstPage = await timeline.loadAssets(0, firstPageCount);
        expect(firstPage.length, firstPageCount);

        final assets = <BaseAsset>[];
        for (
          var offset = 0;
          offset < timeline.totalAssets;
          offset += _timelinePageSize
        ) {
          final count = _timelineCountForPage(timeline.totalAssets, offset);
          final page = await timeline.loadAssets(offset, count);
          expect(page.length, count);
          assets.addAll(page);
        }

        expect(assets.length, timeline.totalAssets);
        expect(_timelineAssetIds(assets).length, assets.length);
        _expectTimelineAssetsDescending(assets);
        expect(
          _hasSharedTimestamp(assets),
          isTrue,
          reason: 'Expected same-timestamp assets in the real timeline',
        );

        final firstPageAgain = await timeline.loadAssets(0, firstPageCount);
        expect(_timelineAssetIds(firstPageAgain), _timelineAssetIds(firstPage));
      },
    );

    _realStackSessionTest(
      'MOB-REAL-017-$_caseSuffix',
      'opens remote image viewer and switches adjacent images',
      (tester) async {
        await _loadAuthenticatedApp(tester);

        final container = _containerOfApp(tester);
        final syncSuccess = await container
            .read(backgroundSyncProvider)
            .syncRemote();
        expect(syncSuccess, isTrue);

        final user = Store.tryGet(StoreKey.currentUser);
        expect(user, isNotNull);

        final timeline = container.read(timelineFactoryProvider).main([
          user!.id,
        ]);
        addTearDown(timeline.dispose);

        await _waitForTimelineBuckets(
          tester,
          timeline,
          minAssets: _timelineMinimumAssetCount,
        );
        final assets = await _loadAllTimelineAssets(timeline);
        final startIndex = _findRemoteImageWindow(
          assets,
          _assetViewerImageCount,
        );
        expect(
          startIndex,
          greaterThanOrEqualTo(0),
          reason: 'Expected remote images in the real timeline',
        );

        final imageAssets = _remoteImagesFrom(
          assets,
          startIndex,
          _assetViewerImageCount,
        );
        await _expectRemoteImageMedia(container, tester, imageAssets.first);

        await _openTimelineAsset(tester, imageAssets.first);
        await pumpUntilFound(
          tester,
          find.byType(AssetViewer),
          timeout: const Duration(seconds: 60),
        );
        expect(
          container.read(assetViewerProvider).currentAsset?.remoteId,
          imageAssets[0].id,
        );

        final secondImage = await _swipeViewerToNextRemoteImage(
          tester,
          container,
          const Offset(-700, 0),
        );
        expect(secondImage.remoteId, isNot(imageAssets[0].id));
        await _expectRemoteImageMedia(container, tester, secondImage);
        final thirdImage = await _swipeViewerToNextRemoteImage(
          tester,
          container,
          const Offset(-700, 0),
        );
        expect(
          thirdImage.remoteId,
          isNot(anyOf(imageAssets[0].id, secondImage.remoteId)),
        );
        await _expectRemoteImageMedia(container, tester, thirdImage);

        final previousImage = await _swipeViewerToNextRemoteImage(
          tester,
          container,
          const Offset(700, 0),
        );
        expect(previousImage.remoteId, secondImage.remoteId);

        await _zoomViewerImage(tester, container);

        EventStream.shared.emit(const ViewerShowDetailsEvent());
        await _pumpFor(tester, const Duration(seconds: 1));
        expect(container.read(assetViewerProvider).showingDetails, isTrue);

        await tester.tap(find.byIcon(Icons.arrow_back_rounded).first);
        await _pumpFor(tester, const Duration(seconds: 1));
        expect(find.byType(Timeline), findsWidgets);

        final firstPageAgain = await timeline.loadAssets(
          0,
          _timelineCountForPage(timeline.totalAssets, 0),
        );
        expect(
          firstPageAgain.any(
            (asset) => asset.refersToSameAsset(imageAssets.first),
          ),
          isTrue,
        );
      },
    );

    _realStackSessionTest(
      'MOB-REAL-018-$_caseSuffix',
      'plays, pauses, seeks, and resumes a remote video viewer',
      (tester) async {
        await _loadAuthenticatedApp(tester);

        final container = _containerOfApp(tester);
        final syncSuccess = await container
            .read(backgroundSyncProvider)
            .syncRemote();
        expect(syncSuccess, isTrue);

        final user = Store.tryGet(StoreKey.currentUser);
        expect(user, isNotNull);

        final timeline = container.read(timelineFactoryProvider).main([
          user!.id,
        ]);
        addTearDown(timeline.dispose);

        await _waitForTimelineBuckets(
          tester,
          timeline,
          minAssets: _timelineMinimumAssetCount,
        );
        final assets = await _loadAllTimelineAssets(timeline);
        final video = _firstRemoteVideo(assets);
        expect(
          video,
          isNotNull,
          reason: 'Expected at least one remote video in the real timeline',
        );

        await _expectRemoteVideoMedia(container, tester, video!);
        await _openTimelineAsset(tester, video);
        await pumpUntilFound(
          tester,
          find.byType(AssetViewer),
          timeout: const Duration(seconds: 60),
        );
        expect(
          container.read(assetViewerProvider).currentAsset?.remoteId,
          video.id,
        );
        await pumpUntilFound(
          tester,
          find.byType(NativeVideoViewer),
          timeout: const Duration(seconds: 60),
        );

        final loaded = await _waitForVideoState(
          tester,
          container,
          video.id,
          (state) => state.duration > Duration.zero,
          timeout: const Duration(seconds: 90),
        );
        expect(loaded.duration, greaterThan(const Duration(seconds: 2)));

        await _playVideoFromControls(tester, container, video.id);
        final firstPlayingPosition = await _waitForVideoPositionAfter(
          tester,
          container,
          video.id,
          Duration.zero,
        );
        expect(firstPlayingPosition, greaterThan(Duration.zero));

        await _pauseVideoFromControls(tester, container, video.id);
        final pausedPosition = container
            .read(videoPlayerProvider(video.id))
            .position;
        await _pumpFor(tester, const Duration(seconds: 2));
        final pausedAfterWait = container
            .read(videoPlayerProvider(video.id))
            .position;
        expect(
          pausedAfterWait,
          lessThanOrEqualTo(pausedPosition + const Duration(seconds: 1)),
        );

        final middleTarget = await _seekVideoWithSlider(
          tester,
          container,
          video.id,
          0.50,
        );
        final middlePosition = container
            .read(videoPlayerProvider(video.id))
            .position;
        expect(
          middlePosition,
          greaterThanOrEqualTo(middleTarget - const Duration(seconds: 1)),
        );

        await _playVideoFromControls(tester, container, video.id);
        await _waitForVideoPositionAfter(
          tester,
          container,
          video.id,
          middlePosition,
        );

        await _backgroundApp(tester);
        await _waitForVideoState(
          tester,
          container,
          video.id,
          (state) => state.status == VideoPlaybackStatus.paused,
          timeout: const Duration(seconds: 10),
        );
        final lifecyclePausePosition = container
            .read(videoPlayerProvider(video.id))
            .position;

        await _foregroundApp(tester);
        await _waitForVideoState(
          tester,
          container,
          video.id,
          (state) =>
              state.status == VideoPlaybackStatus.playing ||
              state.status == VideoPlaybackStatus.buffering,
          timeout: const Duration(seconds: 20),
        );
        final lifecycleResumePosition = container
            .read(videoPlayerProvider(video.id))
            .position;
        expect(
          lifecycleResumePosition,
          greaterThanOrEqualTo(
            lifecyclePausePosition - const Duration(seconds: 1),
          ),
        );

        await _pauseVideoFromControls(tester, container, video.id);
        final tailTarget = await _seekVideoWithSlider(
          tester,
          container,
          video.id,
          0.85,
        );
        final tailPosition = container
            .read(videoPlayerProvider(video.id))
            .position;
        expect(tailPosition, greaterThan(middlePosition));
        expect(
          tailPosition,
          greaterThanOrEqualTo(tailTarget - const Duration(seconds: 1)),
        );

        await _playVideoFromControls(tester, container, video.id);
        await _waitForVideoPositionAfter(
          tester,
          container,
          video.id,
          tailPosition,
        );
      },
    );

    _realStackSessionTest(
      'MOB-REAL-019-$_caseSuffix',
      'applies full sync stream and persists acknowledgements',
      (tester) async {
        final (container, drift) = await _loadAuthenticatedSyncContainer();
        addTearDown(container.dispose);

        await container
            .read(syncApiRepositoryProvider)
            .deleteSyncAck(_allReplayableSyncAckTypes);
        await Store.delete(StoreKey.syncMigrationStatus);
        await container.read(syncStreamRepositoryProvider).reset();

        final emptyCounts = await _remoteSyncRowCounts(drift);
        expect(
          emptyCounts.values.every((count) => count == 0),
          isTrue,
          reason:
              'Expected a fresh local remote-sync database, got $emptyCounts',
        );

        final expectedEvents = await _collectSyncStreamEvents(container);
        expect(
          expectedEvents,
          isNotEmpty,
          reason: 'Expected the real sync stream to return backfill events',
        );
        _expectRealSyncCoverage(expectedEvents);

        final expectedRows = _expectedRemoteSyncRowCounts(expectedEvents);
        expect(
          expectedRows['remote_asset_entity'],
          greaterThanOrEqualTo(_timelineMinimumAssetCount),
        );
        expect(expectedRows['remote_exif_entity'], greaterThan(0));

        final syncSuccess = await container
            .read(syncStreamServiceProvider)
            .sync();
        expect(syncSuccess, isTrue);

        final firstRows = await _remoteSyncRowCounts(drift);
        _expectRemoteSyncRows(firstRows, expectedRows, label: 'first sync');

        final firstAckSet = await _syncAckSet(container);
        _expectAckCoverage(firstAckSet, expectedEvents);

        final secondSyncSuccess = await container
            .read(syncStreamServiceProvider)
            .sync();
        expect(secondSyncSuccess, isTrue);

        final secondRows = await _remoteSyncRowCounts(drift);
        expect(
          secondRows,
          firstRows,
          reason: 'Second sync should not duplicate Drift rows',
        );

        final secondAckSet = await _syncAckSet(container);
        expect(
          secondAckSet,
          containsAll(firstAckSet),
          reason: 'ACKs from the first sync should remain persisted',
        );
      },
    );

    _realStackSessionTest(
      'MOB-REAL-020-$_caseSuffix',
      'resumes safely after an interrupted sync stream',
      (tester) async {
        final (container, drift) = await _loadAuthenticatedSyncContainer();
        addTearDown(container.dispose);

        await container
            .read(syncApiRepositoryProvider)
            .deleteSyncAck(_allReplayableSyncAckTypes);
        await Store.delete(StoreKey.syncMigrationStatus);
        await container.read(syncStreamRepositoryProvider).reset();

        final expectedEvents = await _collectSyncStreamEvents(container);
        expect(
          expectedEvents,
          isNotEmpty,
          reason: 'Expected the real sync stream to return backfill events',
        );
        _expectRealSyncCoverage(expectedEvents);
        final expectedRows = _expectedRemoteSyncRowCounts(expectedEvents);

        final interruptedEvents = await _interruptSyncAfterFirstSafeEvent(
          container,
        );
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
        expect(
          interruptedAckTypes,
          isNot(contains(api.SyncEntityType.syncCompleteV1)),
        );

        final resumedSyncSuccess = await container
            .read(syncStreamServiceProvider)
            .sync();
        expect(resumedSyncSuccess, isTrue);

        final resumedRows = await _remoteSyncRowCounts(drift);
        _expectRemoteSyncRows(resumedRows, expectedRows, label: 'resumed sync');

        final resumedAckSet = await _syncAckSet(container);
        expect(resumedAckSet.length, greaterThan(interruptedAckSet.length));
        _expectAckCoverage(resumedAckSet, expectedEvents);

        final secondSyncSuccess = await container
            .read(syncStreamServiceProvider)
            .sync();
        expect(secondSyncSuccess, isTrue);

        final secondRows = await _remoteSyncRowCounts(drift);
        expect(
          secondRows,
          resumedRows,
          reason: 'Second sync after recovery should not duplicate Drift rows',
        );

        final secondAckSet = await _syncAckSet(container);
        expect(
          secondAckSet,
          containsAll(resumedAckSet),
          reason: 'Recovered ACKs should remain persisted',
        );
      },
    );

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

        await container
            .read(syncApiRepositoryProvider)
            .deleteSyncAck(_allReplayableSyncAckTypes);
        await Store.delete(StoreKey.syncMigrationStatus);
        await container.read(syncStreamRepositoryProvider).reset();
        final baselineSyncSuccess = await container
            .read(syncStreamServiceProvider)
            .sync();
        expect(baselineSyncSuccess, isTrue);
        final baselineRows = await _remoteSyncRowCounts(drift);

        await _connectAndWaitForWebsocket(tester, container);

        final createdAt = DateTime.now().toUtc();
        final fileName =
            'immich-e2e-realtime-021-${createdAt.microsecondsSinceEpoch}.jpg';
        final uploadedId = await _uploadGeneratedJpegAsSecondClient(
          fileName,
          createdAt,
        );
        uploadedRemoteId = uploadedId;
        final uploadSyncSuccess = await container
            .read(syncStreamServiceProvider)
            .sync();
        expect(uploadSyncSuccess, isTrue);

        final uploadedAsset = await _waitForRemoteAssetState(
          tester,
          container,
          uploadedId,
          (asset) => !asset.isFavorite && !asset.isTrashed,
          reason:
              'Expected realtime remote-change handling to create a local remote asset row',
        );
        expect(uploadedAsset.isImage, isTrue);

        await assetsApi.updateAssets(
          api.AssetBulkUpdateDto(
            ids: [uploadedId],
            isFavorite: const api.Optional.present(true),
          ),
        );
        final updateSyncSuccess = await container
            .read(syncStreamServiceProvider)
            .sync();
        expect(updateSyncSuccess, isTrue);

        await _waitForRemoteAssetState(
          tester,
          container,
          uploadedId,
          (asset) => asset.isFavorite && !asset.isTrashed,
          reason:
              'Expected websocket-driven incremental sync to apply favorite update',
        );

        container.read(websocketProvider.notifier).disconnect();
        await _pumpUntil(
          tester,
          () => !container.read(websocketProvider).isConnected,
          timeout: const Duration(seconds: 10),
        );

        await assetsApi.updateAssets(
          api.AssetBulkUpdateDto(
            ids: [uploadedId],
            isFavorite: const api.Optional.present(false),
          ),
        );
        await assetsApi.deleteAssets(
          api.AssetBulkDeleteDto(
            ids: [uploadedId],
            force: const api.Optional.present(false),
          ),
        );
        await _pumpFor(tester, const Duration(seconds: 3));

        final staleAsset = await container
            .read(remoteAssetRepositoryProvider)
            .get(uploadedId);
        expect(staleAsset, isNotNull);
        expect(
          staleAsset!.isFavorite,
          isTrue,
          reason:
              'Disconnected websocket should not apply remote changes inline',
        );
        expect(staleAsset.isTrashed, isFalse);

        await _connectAndWaitForWebsocket(tester, container);
        final recoveredSyncSuccess = await container
            .read(syncStreamServiceProvider)
            .sync();
        expect(recoveredSyncSuccess, isTrue);

        await _waitForRemoteAssetGoneOrTrashed(
          tester,
          container,
          uploadedId,
          reason:
              'Expected reconnect sync to backfill offline favorite and trash changes',
        );
        expect(
          await _remoteAssetRowCountById(drift, uploadedId),
          lessThanOrEqualTo(1),
        );

        final recoveredRows = await _remoteSyncRowCounts(drift);
        expect(
          recoveredRows['remote_asset_entity'],
          greaterThanOrEqualTo(baselineRows['remote_asset_entity']!),
        );
        final secondSyncSuccess = await container
            .read(syncStreamServiceProvider)
            .sync();
        expect(secondSyncSuccess, isTrue);
        expect(
          await _remoteSyncRowCounts(drift),
          recoveredRows,
          reason:
              'Second sync after realtime recovery should not duplicate rows',
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

        await container
            .read(syncApiRepositoryProvider)
            .deleteSyncAck(_allReplayableSyncAckTypes);
        await Store.delete(StoreKey.syncMigrationStatus);
        await container.read(syncStreamRepositoryProvider).reset();
        final baselineSyncSuccess = await container
            .read(syncStreamServiceProvider)
            .sync();
        expect(baselineSyncSuccess, isTrue);

        final createdAt = DateTime.now().toUtc();
        final fileName =
            'immich-e2e-favorite-022-${createdAt.microsecondsSinceEpoch}.jpg';
        final uploadedId = await _uploadGeneratedJpegAsSecondClient(
          fileName,
          createdAt,
        );
        uploadedRemoteId = uploadedId;

        final initialSyncSuccess = await container
            .read(syncStreamServiceProvider)
            .sync();
        expect(initialSyncSuccess, isTrue);

        await _waitForRemoteAssetState(
          tester,
          container,
          uploadedId,
          (asset) => !asset.isFavorite && !asset.isTrashed,
          reason:
              'Expected uploaded asset to sync locally before favorite toggles',
        );
        expect(await _remoteAssetRowCountById(drift, uploadedId), 1);

        await assetsApi.updateAssets(
          api.AssetBulkUpdateDto(
            ids: [uploadedId],
            isFavorite: const api.Optional.present(true),
          ),
        );
        await assetsApi.updateAssets(
          api.AssetBulkUpdateDto(
            ids: [uploadedId],
            isFavorite: const api.Optional.present(true),
          ),
        );

        await _waitForAssetInfoState(
          tester,
          assetsApi,
          uploadedId,
          (info) => info.isFavorite && !info.isTrashed,
          reason:
              'Expected repeated favorite requests to converge on server favorite=true',
        );
        final favoriteSyncSuccess = await container
            .read(syncStreamServiceProvider)
            .sync();
        expect(favoriteSyncSuccess, isTrue);

        await _waitForRemoteAssetState(
          tester,
          container,
          uploadedId,
          (asset) => asset.isFavorite && !asset.isTrashed,
          reason:
              'Expected synced client to observe favorite=true from another client',
        );
        expect(await _remoteAssetRowCountById(drift, uploadedId), 1);

        await assetsApi.updateAssets(
          api.AssetBulkUpdateDto(
            ids: [uploadedId],
            isFavorite: const api.Optional.present(false),
          ),
        );
        await assetsApi.updateAssets(
          api.AssetBulkUpdateDto(
            ids: [uploadedId],
            isFavorite: const api.Optional.present(false),
          ),
        );

        await _waitForAssetInfoState(
          tester,
          assetsApi,
          uploadedId,
          (info) => !info.isFavorite && !info.isTrashed,
          reason:
              'Expected repeated unfavorite requests to converge on server favorite=false',
        );
        final unfavoriteSyncSuccess = await container
            .read(syncStreamServiceProvider)
            .sync();
        expect(unfavoriteSyncSuccess, isTrue);

        await _waitForRemoteAssetState(
          tester,
          container,
          uploadedId,
          (asset) => !asset.isFavorite && !asset.isTrashed,
          reason:
              'Expected original client to observe favorite=false after cross-client sync',
        );
        final rowsAfterUnfavorite = await _remoteSyncRowCounts(drift);
        expect(await _remoteAssetRowCountById(drift, uploadedId), 1);

        final secondSyncSuccess = await container
            .read(syncStreamServiceProvider)
            .sync();
        expect(secondSyncSuccess, isTrue);
        expect(
          await _remoteSyncRowCounts(drift),
          rowsAfterUnfavorite,
          reason:
              'Second sync after idempotent favorite toggles should not duplicate rows',
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

        await container
            .read(syncApiRepositoryProvider)
            .deleteSyncAck(_allReplayableSyncAckTypes);
        await Store.delete(StoreKey.syncMigrationStatus);
        await container.read(syncStreamRepositoryProvider).reset();
        final baselineSyncSuccess = await container
            .read(syncStreamServiceProvider)
            .sync();
        expect(baselineSyncSuccess, isTrue);

        final user = Store.tryGet(StoreKey.currentUser);
        expect(user, isNotNull);

        final baseCreatedAt = DateTime.now().toUtc();
        final normalCreatedAt = baseCreatedAt.subtract(
          const Duration(seconds: 2),
        );
        final favoriteCreatedAt = baseCreatedAt.subtract(
          const Duration(seconds: 1),
        );
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

        final uploadSyncSuccess = await container
            .read(syncStreamServiceProvider)
            .sync();
        expect(uploadSyncSuccess, isTrue);

        await _waitForRemoteAssetState(
          tester,
          container,
          normalId,
          (asset) =>
              asset.visibility == AssetVisibility.timeline &&
              !asset.isFavorite &&
              !asset.isTrashed,
          reason: 'Expected normal uploaded asset to sync as a timeline asset',
        );
        await _waitForRemoteAssetState(
          tester,
          container,
          favoriteId,
          (asset) =>
              asset.visibility == AssetVisibility.timeline &&
              asset.isFavorite &&
              !asset.isTrashed,
          reason:
              'Expected favorite uploaded asset to sync as a favorite timeline asset',
        );
        await _waitForRemoteAssetState(
          tester,
          container,
          hiddenId,
          (asset) =>
              asset.visibility == AssetVisibility.hidden && !asset.isTrashed,
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
          reason:
              'Initial main timeline should include timeline assets and exclude hidden assets',
        );
        await _expectTimelineAssetSet(
          tester,
          favoriteTimeline,
          includes: {favoriteId},
          excludes: {normalId, hiddenId},
          reason:
              'Initial favorite timeline should include only the favorited visible asset',
        );
        await _expectTimelineAssetSet(
          tester,
          archiveTimeline,
          includes: const {},
          excludes: {normalId, favoriteId, hiddenId},
          reason:
              'Initial archive timeline should not include timeline or hidden assets',
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
          (info) =>
              info.visibility == api.AssetVisibility.archive &&
              info.isFavorite &&
              !info.isTrashed,
          reason:
              'Expected archived favorite asset to keep favorite relation on the server',
        );
        final archiveSyncSuccess = await container
            .read(syncStreamServiceProvider)
            .sync();
        expect(archiveSyncSuccess, isTrue);

        await _waitForRemoteAssetState(
          tester,
          container,
          favoriteId,
          (asset) =>
              asset.visibility == AssetVisibility.archive &&
              asset.isFavorite &&
              !asset.isTrashed,
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
          reason:
              'Archive timeline should contain the archived asset and exclude hidden assets',
        );
        await _expectTimelineAssetSet(
          tester,
          favoriteTimeline,
          includes: {favoriteId},
          excludes: {normalId, hiddenId},
          reason:
              'Favorite timeline should retain archived favorite assets without leaking hidden assets',
        );

        await assetsApi.updateAssets(
          api.AssetBulkUpdateDto(
            ids: [favoriteId],
            visibility: const api.Optional.present(
              api.AssetVisibility.timeline,
            ),
          ),
        );
        await _waitForAssetInfoState(
          tester,
          assetsApi,
          favoriteId,
          (info) =>
              info.visibility == api.AssetVisibility.timeline &&
              info.isFavorite &&
              !info.isTrashed,
          reason:
              'Expected unarchived favorite asset to return to timeline visibility on the server',
        );
        final restoreSyncSuccess = await container
            .read(syncStreamServiceProvider)
            .sync();
        expect(restoreSyncSuccess, isTrue);

        final restoredAssets = await _expectTimelineAssetSet(
          tester,
          mainTimeline,
          includes: {normalId, favoriteId},
          excludes: {hiddenId},
          reason:
              'Restored favorite asset should return to the main timeline while hidden stays isolated',
        );
        final restoredFavoriteIndex = restoredAssets.indexWhere(
          (asset) => _timelineAssetId(asset) == favoriteId,
        );
        final normalIndex = restoredAssets.indexWhere(
          (asset) => _timelineAssetId(asset) == normalId,
        );
        expect(restoredFavoriteIndex, greaterThanOrEqualTo(0));
        expect(normalIndex, greaterThanOrEqualTo(0));
        expect(
          restoredFavoriteIndex,
          lessThan(normalIndex),
          reason:
              'Restored asset should return to the main timeline at its created-at position',
        );

        await _expectTimelineAssetSet(
          tester,
          archiveTimeline,
          includes: const {},
          excludes: {normalId, favoriteId, hiddenId},
          reason:
              'Archive timeline should be empty for restored and hidden test assets',
        );
        await _expectTimelineAssetSet(
          tester,
          favoriteTimeline,
          includes: {favoriteId},
          excludes: {normalId, hiddenId},
          reason:
              'Favorite timeline should still expose the restored favorite without hidden leakage',
        );

        final rowsAfterRestore = await _remoteSyncRowCounts(drift);
        final secondSyncSuccess = await container
            .read(syncStreamServiceProvider)
            .sync();
        expect(secondSyncSuccess, isTrue);
        expect(
          await _remoteSyncRowCounts(drift),
          rowsAfterRestore,
          reason:
              'Second sync after archive lifecycle should not duplicate local rows',
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

        await container
            .read(syncApiRepositoryProvider)
            .deleteSyncAck(_allReplayableSyncAckTypes);
        await Store.delete(StoreKey.syncMigrationStatus);
        await container.read(syncStreamRepositoryProvider).reset();
        final baselineSyncSuccess = await container
            .read(syncStreamServiceProvider)
            .sync();
        expect(baselineSyncSuccess, isTrue);

        final baseCreatedAt = DateTime.now().toUtc();
        final assetIds = <String>[];
        for (var index = 0; index < 3; index++) {
          final createdAt = baseCreatedAt.subtract(
            Duration(seconds: 3 - index),
          );
          final assetId = await _uploadGeneratedJpegAsSecondClient(
            'immich-e2e-album-024-$index-${createdAt.microsecondsSinceEpoch}.jpg',
            createdAt,
          );
          uploadedRemoteIds.add(assetId);
          assetIds.add(assetId);
        }

        final uploadSyncSuccess = await container
            .read(syncStreamServiceProvider)
            .sync();
        expect(uploadSyncSuccess, isTrue);
        for (final assetId in assetIds) {
          await _waitForRemoteAssetState(
            tester,
            container,
            assetId,
            (asset) =>
                asset.visibility == AssetVisibility.timeline &&
                !asset.isTrashed,
            reason:
                'Expected uploaded album candidate $assetId to sync locally',
          );
          expect(await _remoteAssetRowCountById(drift, assetId), 1);
        }

        final albumName =
            'immich-e2e-album-024-${baseCreatedAt.microsecondsSinceEpoch}';
        final createdAlbum = await albumsApi.createAlbum(
          api.CreateAlbumDto(
            albumName: albumName,
            assetIds: api.Optional.present(assetIds.take(2).toList()),
          ),
        );
        expect(createdAlbum, isNotNull);
        albumId = createdAlbum!.id;

        await _waitForAlbumInfoState(
          tester,
          albumsApi,
          albumId,
          (album) => album.albumName == albumName && album.assetCount == 2,
          reason:
              'Expected created album to contain the first two assets on the server',
        );

        final duplicateAdd = await albumsApi.addAssetsToAlbum(
          albumId,
          api.BulkIdsDto(ids: assetIds.take(2).toList()),
        );
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
          reason:
              'Repeated album add should not duplicate membership on the server',
        );

        final addThird = await albumsApi.addAssetsToAlbum(
          albumId,
          api.BulkIdsDto(ids: [assetIds[2]]),
        );
        _expectBulkSuccess(addThird, {
          assetIds[2],
        }, reason: 'Expected third asset to be added to album');

        await _waitForAlbumInfoState(
          tester,
          albumsApi,
          albumId,
          (album) => album.assetCount == 3,
          reason:
              'Expected album to contain three assets after adding the third asset',
        );

        final coverUpdate = await albumsApi.updateAlbumInfo(
          albumId,
          api.UpdateAlbumDto(
            albumThumbnailAssetId: api.Optional.present(assetIds[2]),
          ),
        );
        expect(coverUpdate, isNotNull);
        expect(coverUpdate!.albumThumbnailAssetId, assetIds[2]);

        final removeSecond = await albumsApi.removeAssetFromAlbum(
          albumId,
          api.BulkIdsDto(ids: [assetIds[1]]),
        );
        _expectBulkSuccess(removeSecond, {
          assetIds[1],
        }, reason: 'Expected second asset to be removed from album');

        await _waitForAlbumInfoState(
          tester,
          albumsApi,
          albumId,
          (album) =>
              album.assetCount == 2 &&
              album.albumThumbnailAssetId == assetIds[2],
          reason:
              'Expected removed asset to leave album count at two while preserving cover',
        );
        final removedAssetInfo = await assetsApi.getAssetInfo(assetIds[1]);
        expect(removedAssetInfo, isNotNull);
        expect(
          removedAssetInfo!.isTrashed,
          isFalse,
          reason: 'Removing from album must not trash the source asset',
        );

        final albumSyncSuccess = await container
            .read(syncStreamServiceProvider)
            .sync();
        expect(albumSyncSuccess, isTrue);

        await _waitForRemoteAlbumState(
          tester,
          container,
          albumId,
          (album) =>
              album.name == albumName &&
              album.assetCount == 2 &&
              album.thumbnailAssetId == assetIds[2],
          reason:
              'Expected local album to converge after cross-client album changes',
        );
        await _waitForRemoteAlbumAssetIds(
          tester,
          container,
          albumId,
          includes: {assetIds[0], assetIds[2]},
          excludes: {assetIds[1]},
          reason:
              'Expected local album membership to include first and third assets only',
        );
        expect(await _remoteAlbumRowCountById(drift, albumId), 1);
        expect(await _remoteAlbumAssetRowCountByAlbumId(drift, albumId), 2);
        expect(await _remoteAssetRowCountById(drift, assetIds[1]), 1);

        final rowsAfterAlbumSync = await _remoteSyncRowCounts(drift);
        final secondSyncSuccess = await container
            .read(syncStreamServiceProvider)
            .sync();
        expect(secondSyncSuccess, isTrue);
        expect(
          await _remoteSyncRowCounts(drift),
          rowsAfterAlbumSync,
          reason:
              'Second sync after album changes should not duplicate local rows',
        );
      },
    );

    _realStackSessionTest(
      'MOB-REAL-025-$_caseSuffix',
      'matches server search results across text and filters',
      (tester) async {
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

        await container
            .read(syncApiRepositoryProvider)
            .deleteSyncAck(_allReplayableSyncAckTypes);
        await Store.delete(StoreKey.syncMigrationStatus);
        await container.read(syncStreamRepositoryProvider).reset();
        final baselineSyncSuccess = await container
            .read(syncStreamServiceProvider)
            .sync();
        expect(baselineSyncSuccess, isTrue);

        final runToken = DateTime.now()
            .toUtc()
            .microsecondsSinceEpoch
            .toString();
        final sharedNeedle = 'search-025-$runToken';
        const cameraMake = 'ImmichE2E';
        const cameraModel = 'Search025';
        final baseCreatedAt = DateTime.utc(2026, 1, 25, 12);
        final timelineFavoriteCreatedAt = baseCreatedAt;
        final timelinePlainCreatedAt = baseCreatedAt.subtract(
          const Duration(days: 10),
        );
        final archiveFavoriteCreatedAt = baseCreatedAt.add(
          const Duration(minutes: 1),
        );
        final hiddenCreatedAt = baseCreatedAt.add(const Duration(minutes: 2));

        final timelineFavoriteName =
            'immich-e2e-$sharedNeedle-snow-東京-favorite.jpg';
        final timelineFavoriteId = await _uploadGeneratedJpegAsSecondClient(
          timelineFavoriteName,
          timelineFavoriteCreatedAt,
          isFavorite: true,
          sourceMetadata: {
            'device_make': cameraMake,
            'device_model': cameraModel,
            'width': 64,
            'height': 64,
          },
        );
        uploadedRemoteIds.add(timelineFavoriteId);

        final timelinePlainId = await _uploadGeneratedJpegAsSecondClient(
          'immich-e2e-$sharedNeedle-canyon-plain.jpg',
          timelinePlainCreatedAt,
          sourceMetadata: {
            'device_make': cameraMake,
            'device_model': 'Search025Plain',
            'width': 64,
            'height': 64,
          },
        );
        uploadedRemoteIds.add(timelinePlainId);

        final archiveFavoriteId = await _uploadGeneratedJpegAsSecondClient(
          'immich-e2e-$sharedNeedle-snow-archive.jpg',
          archiveFavoriteCreatedAt,
          isFavorite: true,
          visibility: api.AssetVisibility.archive,
          sourceMetadata: {
            'device_make': cameraMake,
            'device_model': cameraModel,
            'width': 64,
            'height': 64,
          },
        );
        uploadedRemoteIds.add(archiveFavoriteId);

        final hiddenId = await _uploadGeneratedJpegAsSecondClient(
          'immich-e2e-$sharedNeedle-snow-hidden.jpg',
          hiddenCreatedAt,
          visibility: api.AssetVisibility.hidden,
          sourceMetadata: {
            'device_make': cameraMake,
            'device_model': cameraModel,
            'width': 64,
            'height': 64,
          },
        );
        uploadedRemoteIds.add(hiddenId);

        final uploadSyncSuccess = await container
            .read(syncStreamServiceProvider)
            .sync();
        expect(uploadSyncSuccess, isTrue);

        await _waitForRemoteAssetState(
          tester,
          container,
          timelineFavoriteId,
          (asset) =>
              asset.visibility == AssetVisibility.timeline &&
              asset.isFavorite &&
              !asset.isTrashed,
          reason: 'Expected searchable favorite asset to sync locally',
        );
        await _waitForRemoteAssetState(
          tester,
          container,
          timelinePlainId,
          (asset) =>
              asset.visibility == AssetVisibility.timeline &&
              !asset.isFavorite &&
              !asset.isTrashed,
          reason: 'Expected searchable plain asset to sync locally',
        );
        await _waitForRemoteAssetState(
          tester,
          container,
          archiveFavoriteId,
          (asset) =>
              asset.visibility == AssetVisibility.archive &&
              asset.isFavorite &&
              !asset.isTrashed,
          reason: 'Expected searchable archive asset to sync locally',
        );
        await _waitForRemoteAssetState(
          tester,
          container,
          hiddenId,
          (asset) =>
              asset.visibility == AssetVisibility.hidden && !asset.isTrashed,
          reason: 'Expected searchable hidden asset to sync locally',
        );

        final exactFilter = _searchFilter(
          filename: timelineFavoriteName,
          mediaType: AssetType.image,
        );
        final exactServer = await _waitForServerSearchResponse(
          tester,
          searchApi,
          _metadataSearchDto(
            filename: timelineFavoriteName,
            type: api.AssetTypeEnum.IMAGE,
            visibility: api.AssetVisibility.timeline,
          ),
          (response) =>
              _serverSearchAssetIds(response).contains(timelineFavoriteId),
          reason:
              'Expected exact filename search to find the timeline favorite asset',
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

        final partialFilter = _searchFilter(
          filename: sharedNeedle,
          mediaType: AssetType.image,
        );
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
          reason:
              'Expected partial filename search to include timeline assets and exclude archive/hidden assets',
        );
        final partialAppIds = await _waitForSearchServiceAssetIds(
          tester,
          searchService,
          partialFilter,
          (ids) =>
              ids.containsAll({timelineFavoriteId, timelinePlainId}) &&
              !ids.contains(archiveFavoriteId) &&
              !ids.contains(hiddenId),
          reason:
              'Expected app partial search to mirror server timeline visibility',
        );
        expect(partialAppIds, _serverSearchAssetIds(partialServer));

        final unicodeNeedle = '$sharedNeedle-snow-東京';
        final unicodeFilter = _searchFilter(
          filename: unicodeNeedle,
          mediaType: AssetType.image,
        );
        final unicodeServer = await _waitForServerSearchResponse(
          tester,
          searchApi,
          _metadataSearchDto(
            filename: unicodeNeedle,
            type: api.AssetTypeEnum.IMAGE,
            visibility: api.AssetVisibility.timeline,
          ),
          (response) =>
              _serverSearchAssetIds(response).contains(timelineFavoriteId),
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
          (response) =>
              _serverSearchAssetIds(response).contains(timelineFavoriteId),
          reason:
              'Expected combined timeline filters to find only the matching favorite image',
        );
        final timelineComboAppIds = await _waitForSearchServiceAssetIds(
          tester,
          searchService,
          timelineComboFilter,
          (ids) => ids.contains(timelineFavoriteId),
          reason:
              'Expected app combined timeline search to mirror server results',
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
          (response) =>
              _serverSearchAssetIds(response).contains(archiveFavoriteId),
          reason:
              'Expected combined archive filters to find the archived favorite image',
        );
        final archiveComboAppIds = await _waitForSearchServiceAssetIds(
          tester,
          searchService,
          archiveComboFilter,
          (ids) => ids.contains(archiveFavoriteId),
          reason:
              'Expected app archive-filtered search to mirror server results',
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
          reason:
              'Expected explicit hidden search to prove the hidden asset exists',
        );
        expect(_serverSearchAssetIds(hiddenServer), contains(hiddenId));
        expect(
          partialAppIds,
          isNot(contains(hiddenId)),
          reason: 'Timeline search must not leak hidden assets',
        );

        final emptyFilter = _searchFilter(
          filename: 'immich-e2e-$sharedNeedle-no-result',
          mediaType: AssetType.image,
        );
        final emptyServer = await _waitForServerSearchResponse(
          tester,
          searchApi,
          _metadataSearchDto(
            filename: 'immich-e2e-$sharedNeedle-no-result',
            type: api.AssetTypeEnum.IMAGE,
            visibility: api.AssetVisibility.timeline,
          ),
          (response) =>
              response.assets.total == 0 && response.assets.items.isEmpty,
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
          (response) =>
              response.assets.total >= 2 && response.assets.items.length == 1,
          reason:
              'Expected first server search page to contain one timeline asset',
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
          (response) =>
              response.assets.total == pageOne.assets.total &&
              response.assets.items.length == 1,
          reason: 'Expected second server search page to be stable',
        );
        expect(pageOne.assets.nextPage, '2');
        expect(
          _serverSearchAssetIds(
            pageOne,
          ).intersection(_serverSearchAssetIds(pageTwo)),
          isEmpty,
        );
        expect(
          _serverSearchAssetIds(pageOne).union(_serverSearchAssetIds(pageTwo)),
          {timelineFavoriteId, timelinePlainId},
        );
      },
    );

    _realStackSessionTest(
      'MOB-REAL-026-$_caseSuffix',
      'shows synced people and places for processed assets',
      (tester) async {
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

        await container
            .read(syncApiRepositoryProvider)
            .deleteSyncAck(_allReplayableSyncAckTypes);
        await Store.delete(StoreKey.syncMigrationStatus);
        await container.read(syncStreamRepositoryProvider).reset();
        final baselineSyncSuccess = await container
            .read(syncStreamServiceProvider)
            .sync();
        expect(baselineSyncSuccess, isTrue);
        final user = Store.tryGet(StoreKey.currentUser);
        expect(user, isNotNull);

        final runToken = DateTime.now()
            .toUtc()
            .microsecondsSinceEpoch
            .toString();
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
          reason:
              'Expected server faces endpoint to link the test person and first asset',
        );
        expect(serverFaces, isNotEmpty);

        final serverPlaceAssets = await _waitForServerPlaces(
          tester,
          (assets) => assets.any(
            (asset) =>
                uploadedRemoteIds.contains(asset.id) &&
                asset.exifInfo.orElse(null)?.city.orElse(null) == city,
          ),
          reason:
              'Expected server places endpoint to include the uploaded city asset',
        );
        expect(
          serverPlaceAssets.map(
            (asset) => asset.exifInfo.orElse(null)?.city.orElse(null),
          ),
          contains(city),
        );

        final syncSuccess = await container
            .read(syncStreamServiceProvider)
            .sync();
        expect(syncSuccess, isTrue);

        final localAsset = await _waitForRemoteAssetState(
          tester,
          container,
          uploadedRemoteIds.first,
          (asset) =>
              asset.visibility == AssetVisibility.timeline && !asset.isTrashed,
          reason: 'Expected people/places asset to sync locally',
        );
        final localExif = await _waitForRemoteExifState(
          tester,
          assetService,
          localAsset,
          (exif) =>
              exif.city == city &&
              exif.state == state &&
              exif.country == country &&
              exif.hasCoordinates,
          reason: 'Expected uploaded GPS metadata to sync into local EXIF',
        );
        expect(localExif.city, city);

        final localPeople = await _waitForLocalPeopleState(
          tester,
          peopleService,
          (people) => people.any(
            (person) => person.id == personId && person.name == personName,
          ),
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
          expect(
            assetPeople.map((person) => person.name),
            contains(personName),
          );
          expect(await _remoteAssetFaceRowCount(drift, assetId, personId), 1);
        }

        final localPlaces = await _waitForLocalPlacesState(
          tester,
          assetService,
          user!.id,
          (places) => places.any(
            (place) => place.$1 == city && uploadedRemoteIds.contains(place.$2),
          ),
          reason: 'Expected synced places list to include the uploaded city',
        );
        expect(localPlaces.map((place) => place.$1), contains(city));
      },
    );

    _realStackSessionTest(
      'MOB-REAL-027-$_caseSuffix',
      'preserves assets and relations through trash restore',
      (tester) async {
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

        await container
            .read(syncApiRepositoryProvider)
            .deleteSyncAck(_allReplayableSyncAckTypes);
        await Store.delete(StoreKey.syncMigrationStatus);
        await container.read(syncStreamRepositoryProvider).reset();
        final baselineSyncSuccess = await container
            .read(syncStreamServiceProvider)
            .sync();
        expect(baselineSyncSuccess, isTrue);

        final user = Store.tryGet(StoreKey.currentUser);
        expect(user, isNotNull);

        final runToken = DateTime.now()
            .toUtc()
            .microsecondsSinceEpoch
            .toString();
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

        final initialSyncSuccess = await container
            .read(syncStreamServiceProvider)
            .sync();
        expect(initialSyncSuccess, isTrue);

        for (final assetId in uploadedRemoteIds) {
          await _waitForRemoteAssetState(
            tester,
            container,
            assetId,
            (asset) =>
                asset.visibility == AssetVisibility.timeline &&
                !asset.isTrashed,
            reason:
                'Expected uploaded trash/restore candidate $assetId to sync locally',
          );
          expect(await _remoteAssetRowCountById(drift, assetId), 1);
        }

        final albumName = 'immich-e2e-trash-restore-027-$runToken';
        final createdAlbum = await albumsApi.createAlbum(
          api.CreateAlbumDto(
            albumName: albumName,
            assetIds: api.Optional.present([albumAssetId]),
          ),
        );
        expect(createdAlbum, isNotNull);
        albumId = createdAlbum!.id;
        await _waitForAlbumInfoState(
          tester,
          albumsApi,
          albumId,
          (album) => album.albumName == albumName && album.assetCount == 1,
          reason:
              'Expected server album to contain the album-scoped test asset before trash',
        );

        final albumSyncSuccess = await container
            .read(syncStreamServiceProvider)
            .sync();
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
            () => container
                .read(assetApiRepositoryProvider)
                .downloadAsset(assetId, edited: false),
          );
          beforeDownloads[assetId] = base64Encode(
            md5.convert(download.bodyBytes).bytes,
          );
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
          reason:
              'Initial main timeline should include all trash/restore candidates',
        );
        await _expectTimelineAssetSet(
          tester,
          favoriteTimeline,
          includes: {favoriteId},
          excludes: {normalId, albumAssetId},
          reason:
              'Initial favorite timeline should contain only the favorited candidate',
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
            reason:
                'Expected App-side trash action to mark local asset $assetId as trashed',
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

        final trashSyncSuccess = await container
            .read(syncStreamServiceProvider)
            .sync();
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

        final restoreSyncSuccess = await container
            .read(syncStreamServiceProvider)
            .sync();
        expect(restoreSyncSuccess, isTrue);
        for (final assetId in uploadedRemoteIds) {
          final restoredAsset = await _waitForRemoteAssetState(
            tester,
            container,
            assetId,
            (asset) =>
                !asset.isTrashed &&
                asset.visibility == AssetVisibility.timeline,
            reason:
                'Expected restored asset $assetId to sync back into the local active set',
          );
          expect(restoredAsset.isFavorite, beforeInfos[assetId]!.isFavorite);
          expect(await _remoteAssetRowCountById(drift, assetId), 1);

          final download = await _waitForSuccessfulResponse(
            tester,
            () => container
                .read(assetApiRepositoryProvider)
                .downloadAsset(assetId, edited: false),
          );
          expect(
            base64Encode(md5.convert(download.bodyBytes).bytes),
            beforeDownloads[assetId],
          );
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
          (album) =>
              album.assetCount == 1 &&
              album.albumThumbnailAssetId == albumAssetId,
          reason:
              'Expected restored album asset to keep server album membership and cover',
        );
        await _waitForRemoteAlbumAssetIds(
          tester,
          container,
          albumId,
          includes: {albumAssetId},
          excludes: {normalId, favoriteId},
          reason:
              'Expected restored album asset to keep local album membership',
        );
        expect(await _remoteAlbumAssetRowCountByAlbumId(drift, albumId), 1);

        final rowsAfterRestore = await _remoteSyncRowCounts(drift);
        final secondSyncSuccess = await container
            .read(syncStreamServiceProvider)
            .sync();
        expect(secondSyncSuccess, isTrue);
        expect(
          await _remoteSyncRowCounts(drift),
          rowsAfterRestore,
          reason:
              'Second sync after trash restore should not duplicate local rows',
        );
      },
    );

    _realStackSessionTest(
      'MOB-REAL-028-$_caseSuffix',
      'converges permanent delete across server and local state',
      (tester) async {
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

        await container
            .read(syncApiRepositoryProvider)
            .deleteSyncAck(_allReplayableSyncAckTypes);
        await Store.delete(StoreKey.syncMigrationStatus);
        await container.read(syncStreamRepositoryProvider).reset();
        final baselineSyncSuccess = await container
            .read(syncStreamServiceProvider)
            .sync();
        expect(baselineSyncSuccess, isTrue);

        final user = Store.tryGet(StoreKey.currentUser);
        expect(user, isNotNull);

        final runToken = DateTime.now()
            .toUtc()
            .microsecondsSinceEpoch
            .toString();
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

        final initialSyncSuccess = await container
            .read(syncStreamServiceProvider)
            .sync();
        expect(initialSyncSuccess, isTrue);

        for (final assetId in [deleteId, controlId]) {
          await _waitForRemoteAssetState(
            tester,
            container,
            assetId,
            (asset) =>
                asset.visibility == AssetVisibility.timeline &&
                !asset.isTrashed,
            reason:
                'Expected uploaded permanent-delete candidate $assetId to sync locally',
          );
          expect(await _remoteAssetRowCountById(drift, assetId), 1);
        }

        final deleteInfo = await _waitForAssetInfoState(
          tester,
          assetsApi,
          deleteId,
          (asset) => !asset.isTrashed && asset.originalPath.isNotEmpty,
          reason:
              'Expected delete target to expose active server metadata before permanent delete',
        );
        final controlInfo = await _waitForAssetInfoState(
          tester,
          assetsApi,
          controlId,
          (asset) =>
              asset.isFavorite &&
              !asset.isTrashed &&
              asset.originalPath.isNotEmpty,
          reason:
              'Expected control asset to expose active server metadata before permanent delete',
        );
        final deleteOriginal = await _waitForSuccessfulResponse(
          tester,
          () => container
              .read(assetApiRepositoryProvider)
              .downloadAsset(deleteId, edited: false),
        );
        expect(
          base64Encode(md5.convert(deleteOriginal.bodyBytes).bytes),
          deleteInfo.checksum,
        );
        await _waitForSuccessfulResponse(
          tester,
          () => assetsApi.viewAssetWithHttpInfo(
            deleteId,
            size: api.AssetMediaSize.thumbnail,
          ),
        );
        final controlOriginal = await _waitForSuccessfulResponse(
          tester,
          () => container
              .read(assetApiRepositoryProvider)
              .downloadAsset(controlId, edited: false),
        );
        final controlChecksum = base64Encode(
          md5.convert(controlOriginal.bodyBytes).bytes,
        );
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
          reason:
              'Initial main timeline should include delete target and control asset',
        );
        await _expectTimelineAssetSet(
          tester,
          favoriteTimeline,
          includes: {controlId},
          excludes: {deleteId},
          reason:
              'Initial favorite timeline should include only the favorite control asset',
        );
        await _expectTimelineAssetSet(
          tester,
          trashTimeline,
          includes: const {},
          excludes: {deleteId, controlId},
          reason:
              'Initial trash timeline should not include active permanent-delete assets',
        );

        await assetService.trash([deleteId]);
        await _waitForAssetInfoState(
          tester,
          assetsApi,
          deleteId,
          (asset) => asset.isTrashed,
          reason:
              'Expected delete target to be logically trashed before permanent delete',
        );
        await _waitForRemoteAssetState(
          tester,
          container,
          deleteId,
          (asset) => asset.isTrashed,
          reason:
              'Expected mobile trash action to move delete target into local trash',
        );
        await _expectTimelineAssetSet(
          tester,
          mainTimeline,
          includes: {controlId},
          excludes: {deleteId},
          reason:
              'Main timeline should hide the logically trashed delete target',
        );
        await _expectTimelineAssetSet(
          tester,
          trashTimeline,
          includes: {deleteId},
          excludes: {controlId},
          reason:
              'Trash timeline should contain the logically trashed delete target',
        );

        await assetService.delete([deleteId]);
        await _waitForAssetInfoUnavailable(
          tester,
          assetsApi,
          deleteId,
          reason:
              'Expected hard-deleted asset info endpoint to become unavailable',
        );
        await _waitForRemoteAssetDeleted(
          tester,
          container,
          deleteId,
          reason:
              'Expected mobile permanent delete to remove the local remote asset row',
        );
        expect(await _remoteAssetRowCountById(drift, deleteId), 0);

        await _waitForRejectedResponse(
          tester,
          () => _authenticatedApiGet('/assets/$deleteId/original?edited=false'),
          reason:
              'Expected old original download URL to be unreadable after permanent delete',
        );
        await _waitForRejectedResponse(
          tester,
          () => _authenticatedApiGet(
            '/assets/$deleteId/thumbnail?size=thumbnail&edited=false',
          ),
          reason:
              'Expected old thumbnail URL to be unreadable after permanent delete',
        );

        await _expectTimelineAssetSet(
          tester,
          mainTimeline,
          includes: {controlId},
          excludes: {deleteId},
          reason:
              'Main timeline should keep only the unaffected control asset after permanent delete',
        );
        await _expectTimelineAssetSet(
          tester,
          favoriteTimeline,
          includes: {controlId},
          excludes: {deleteId},
          reason:
              'Favorite timeline should keep the unaffected control asset after permanent delete',
        );
        await _expectTimelineAssetSet(
          tester,
          trashTimeline,
          includes: const {},
          excludes: {deleteId, controlId},
          reason:
              'Trash timeline should no longer list the permanently deleted asset',
        );

        final deleteSyncSuccess = await container
            .read(syncStreamServiceProvider)
            .sync();
        expect(deleteSyncSuccess, isTrue);
        expect(await _remoteAssetRowCountById(drift, deleteId), 0);
        expect(await _remoteAssetRowCountById(drift, controlId), 1);

        final controlAfterDelete = await _waitForAssetInfoState(
          tester,
          assetsApi,
          controlId,
          (asset) => asset.isFavorite && !asset.isTrashed,
          reason:
              'Expected permanent delete to leave the control asset untouched',
        );
        _expectAssetInfoPreserved(controlAfterDelete, controlInfo);
        final controlDownloadAfterDelete = await _waitForSuccessfulResponse(
          tester,
          () => container
              .read(assetApiRepositoryProvider)
              .downloadAsset(controlId, edited: false),
        );
        expect(
          base64Encode(md5.convert(controlDownloadAfterDelete.bodyBytes).bytes),
          controlChecksum,
        );

        final rowsAfterDelete = await _remoteSyncRowCounts(drift);
        final secondSyncSuccess = await container
            .read(syncStreamServiceProvider)
            .sync();
        expect(secondSyncSuccess, isTrue);
        expect(
          await _remoteSyncRowCounts(drift),
          rowsAfterDelete,
          reason:
              'Second sync after permanent delete should not reinsert deleted local rows',
        );
      },
    );

    _realStackSessionTest(
      'MOB-REAL-029-$_caseSuffix',
      'browses cached assets across offline cold start and reconnect',
      (tester) async {
        await _loadAuthenticatedApp(
          tester,
          overrideCancellation: true,
          closeDriftOnDispose: false,
          resetSyncAcksBeforeStart: true,
        );
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

        await container
            .read(syncApiRepositoryProvider)
            .deleteSyncAck(_allReplayableSyncAckTypes);
        await Store.delete(StoreKey.syncMigrationStatus);
        await container.read(syncStreamRepositoryProvider).reset();
        final baselineSyncSuccess = await container
            .read(syncStreamServiceProvider)
            .sync();
        expect(baselineSyncSuccess, isTrue);
        if (Store.tryGet(StoreKey.currentUser) == null) {
          await Store.put(StoreKey.currentUser, user!);
        }

        final runToken = DateTime.now()
            .toUtc()
            .microsecondsSinceEpoch
            .toString();
        final createdAt = DateTime.utc(2026, 1, 29, 12).add(
          Duration(
            microseconds: int.parse(runToken) % Duration.microsecondsPerDay,
          ),
        );
        final cachedAssetId = await _uploadGeneratedJpegAsSecondClient(
          'immich-e2e-offline-recovery-029-cached-$runToken.jpg',
          createdAt,
        );
        uploadedRemoteIds.add(cachedAssetId);

        final uploadSyncSuccess = await container
            .read(syncStreamServiceProvider)
            .sync();
        expect(uploadSyncSuccess, isTrue);
        final cachedBeforeOffline = await _waitForRemoteAssetState(
          tester,
          container,
          cachedAssetId,
          (asset) =>
              asset.visibility == AssetVisibility.timeline &&
              !asset.isTrashed &&
              !asset.isFavorite,
          reason:
              'Expected uploaded offline-recovery asset to sync locally before disconnect',
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
          () => container
              .read(assetApiRepositoryProvider)
              .downloadAsset(cachedAssetId, edited: false),
        );
        expect(
          base64Encode(md5.convert(originalBeforeOffline.bodyBytes).bytes),
          infoBeforeOffline.checksum,
        );
        await _waitForSuccessfulResponse(
          tester,
          () => assetsApi.viewAssetWithHttpInfo(
            cachedAssetId,
            size: api.AssetMediaSize.thumbnail,
          ),
        );

        final onlineTimeline = container.read(timelineFactoryProvider).main([
          user!.id,
        ]);
        await _expectTimelineAssetSet(
          tester,
          onlineTimeline,
          includes: {cachedAssetId},
          excludes: const {},
          reason:
              'Expected online timeline to include the cached offline-recovery asset',
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

        await _loadAppPreservingStore(
          tester,
          overrideCancellation: true,
          closeDriftOnDispose: false,
        );
        await _waitForAccessToken(tester);
        await _waitForCurrentUser(_email, tester);
        container = _containerOfApp(tester);
        drift = container.read(driftProvider);

        final cachedAfterColdStart = await _waitForRemoteAssetState(
          tester,
          container,
          cachedAssetId,
          (asset) =>
              !asset.isTrashed &&
              !asset.isFavorite &&
              asset.createdAt.toUtc() == cachedBeforeOffline.createdAt.toUtc(),
          reason:
              'Expected offline cold start to keep the cached remote asset readable from Drift',
        );
        expect(cachedAfterColdStart.checksum, cachedBeforeOffline.checksum);

        final offlineTimeline = container.read(timelineFactoryProvider).main([
          user.id,
        ]);
        await _expectTimelineAssetSet(
          tester,
          offlineTimeline,
          includes: {cachedAssetId},
          excludes: const {},
          reason:
              'Expected offline timeline browsing to use cached remote rows',
        );
        await offlineTimeline.dispose();
        expect(await _remoteSyncRowCounts(drift), rowsBeforeOffline);

        final offlineWriteError = await _captureError(
          () => container.read(assetServiceProvider).update([
            cachedAssetId,
          ], isFavorite: const Option.some(true)),
        );
        expect(
          offlineWriteError,
          isNotNull,
          reason: 'Expected offline favorite write to fail explicitly',
        );
        expect(offlineWriteError.toString(), isNotEmpty);
        final assetAfterOfflineWrite = await container
            .read(remoteAssetRepositoryProvider)
            .get(cachedAssetId);
        expect(assetAfterOfflineWrite, isNotNull);
        expect(
          assetAfterOfflineWrite!.isFavorite,
          isFalse,
          reason: 'Failed offline write must not mutate local state',
        );

        await Store.put(StoreKey.serverEndpoint, realEndpoint);
        await Store.put(StoreKey.serverUrl, realEndpoint);
        final recoveredApiService = container.read(apiServiceProvider);
        recoveredApiService.setEndpoint(realEndpoint);
        await recoveredApiService.updateHeaders();

        final reconnectSyncSuccess = await container
            .read(syncStreamServiceProvider)
            .sync();
        expect(reconnectSyncSuccess, isTrue);
        await _waitForRemoteAssetState(
          tester,
          container,
          cachedAssetId,
          (asset) => !asset.isTrashed && !asset.isFavorite,
          reason:
              'Expected reconnect sync to preserve the server truth after rejected offline write',
        );
        expect(await _remoteAssetRowCountById(drift, cachedAssetId), 1);
        expect(
          await _remoteSyncRowCounts(drift),
          rowsBeforeOffline,
          reason:
              'Reconnect sync after offline cold start should not duplicate cached rows',
        );

        final infoAfterReconnect = await _waitForAssetInfoState(
          tester,
          recoveredApiService.assetsApi,
          cachedAssetId,
          (asset) => !asset.isTrashed && !asset.isFavorite,
          reason:
              'Expected restored network access to read server metadata again',
        );
        _expectAssetInfoPreserved(infoAfterReconnect, infoBeforeOffline);

        final secondSyncSuccess = await container
            .read(syncStreamServiceProvider)
            .sync();
        expect(secondSyncSuccess, isTrue);
        expect(
          await _remoteSyncRowCounts(drift),
          rowsBeforeOffline,
          reason:
              'Second sync after offline recovery should not duplicate cached rows',
        );
      },
    );

    _realStackSessionTest(
      'MOB-REAL-030-$_caseSuffix',
      'recovers session upload and sync after a real server restart',
      (tester) async {
        await _loadAuthenticatedApp(
          tester,
          overrideCancellation: true,
          closeDriftOnDispose: false,
        );
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

        await container
            .read(syncApiRepositoryProvider)
            .deleteSyncAck(_allReplayableSyncAckTypes);
        await Store.delete(StoreKey.syncMigrationStatus);
        await container.read(syncStreamRepositoryProvider).reset();
        final baselineSyncSuccess = await container
            .read(syncStreamServiceProvider)
            .sync();
        expect(baselineSyncSuccess, isTrue);
        if (Store.tryGet(StoreKey.currentUser) == null) {
          await Store.put(StoreKey.currentUser, user!);
        }
        final baselineRows = await _remoteSyncRowCounts(drift);

        final asset = await _waitForLocalAssetByName(
          container,
          _resumableAssetName,
          tester,
        );
        final contentSize = asset.contentSize;
        if (contentSize == null) {
          fail(
            'Server-restart upload asset $_resumableAssetName has no known content size',
          );
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
          () =>
              restartMarkerPrinted ||
              uploadedRemoteId != null ||
              firstUploadError != null,
          timeout: const Duration(seconds: 90),
        );
        expect(
          restartMarkerPrinted,
          isTrue,
          reason:
              'Expected upload progress before asking the host harness to restart the server',
        );

        await _waitForServerReachability(
          tester,
          realEndpoint,
          reachable: false,
          timeout: const Duration(seconds: 30),
        );
        await _waitForServerReachability(
          tester,
          realEndpoint,
          reachable: true,
          timeout: const Duration(seconds: 90),
        );

        await firstUpload.timeout(
          const Duration(seconds: 120),
          onTimeout: () => fail(
            'Timed out waiting for the in-flight upload to settle after server restart',
          ),
        );

        if (uploadedRemoteId == null) {
          expect(
            firstUploadError,
            isNotNull,
            reason:
                'Expected the interrupted upload to report a recoverable error',
          );
          expect(
            await _resumableStateFiles(),
            isNotEmpty,
            reason: 'Interrupted upload should persist resumable state',
          );

          final retryProgress = <int>[];
          String? retryError;
          await container
              .read(foregroundUploadServiceProvider)
              .uploadSingleAsset(
                asset,
                null,
                callbacks: UploadCallbacks(
                  onProgress: (_, _, bytes, totalBytes) =>
                      retryProgress.add(bytes),
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

        final postRestartSyncSuccess = await container
            .read(syncStreamServiceProvider)
            .sync();
        expect(postRestartSyncSuccess, isTrue);
        await _waitForRemoteAssetState(
          tester,
          container,
          uploadId,
          (asset) =>
              asset.visibility == AssetVisibility.timeline && !asset.isTrashed,
          reason:
              'Expected uploaded asset to sync locally after backend restart',
        );
        expect(await _remoteAssetRowCountById(drift, uploadId), 1);

        await tester.pumpWidget(const SizedBox.shrink());
        await _pumpFor(tester, const Duration(milliseconds: 500));
        await _loadAppPreservingStore(
          tester,
          overrideCancellation: true,
          closeDriftOnDispose: false,
        );
        await _waitForAccessToken(tester);
        await _waitForCurrentUser(_email, tester);
        container = _containerOfApp(tester);
        drift = container.read(driftProvider);

        final resumedSyncSuccess = await container
            .read(syncStreamServiceProvider)
            .sync();
        expect(resumedSyncSuccess, isTrue);
        final localAsset = await _waitForRemoteAssetState(
          tester,
          container,
          uploadId,
          (asset) =>
              asset.visibility == AssetVisibility.timeline && !asset.isTrashed,
          reason:
              'Expected relaunched client to preserve the uploaded asset after server recovery',
        );
        expect(localAsset.ownerId, user!.id);
        expect(await _remoteAssetRowCountById(drift, uploadId), 1);
        final resumedRows = await _remoteSyncRowCounts(drift);
        expect(
          resumedRows['remote_asset_entity'],
          greaterThanOrEqualTo(baselineRows['remote_asset_entity']! + 1),
        );

        final infoAfterRestart = await _waitForAssetInfoState(
          tester,
          container.read(apiServiceProvider).assetsApi,
          uploadId,
          (asset) => !asset.isTrashed && asset.originalPath.isNotEmpty,
          reason:
              'Expected session token to remain valid after backend restart',
        );
        expect(infoAfterRestart.originalFileName, _resumableAssetName);

        final downloaded = await _waitForSuccessfulResponse(
          tester,
          () => container
              .read(assetApiRepositoryProvider)
              .downloadAsset(uploadId, edited: false),
        );
        expect(downloaded.bodyBytes.length, contentSize);

        final secondSyncSuccess = await container
            .read(syncStreamServiceProvider)
            .sync();
        expect(secondSyncSuccess, isTrue);
        expect(
          await _remoteSyncRowCounts(drift),
          resumedRows,
          reason:
              'Second sync after server restart recovery should not duplicate local rows',
        );
      },
    );

    _realStackSessionTest(
      'MOB-REAL-032-$_caseSuffix',
      'preserves login and local library across app upgrade',
      (tester) async {
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
            fail(
              'Unknown IMMICH_E2E_UPGRADE_STAGE=$_upgradeStage; expected seed, verify, or single',
            );
        }
      },
    );

    _realStackSessionTest(
      'MOB-UI-033-$_caseSuffix',
      'keeps primary navigation state across tabs and rotation',
      (tester) async {
        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = const Size(430, 932);
        addTearDown(tester.view.reset);

        await _loadAuthenticatedApp(tester, overrideCancellation: true);
        final container = _containerOfApp(tester);
        final user = Store.tryGet(StoreKey.currentUser);
        expect(user, isNotNull);

        await container.read(backgroundSyncProvider).syncLocal(full: true);
        final syncSuccess = await container
            .read(syncStreamServiceProvider)
            .sync();
        expect(syncSuccess, isTrue);

        final timeline = container.read(timelineFactoryProvider).main([
          user!.id,
        ]);
        addTearDown(timeline.dispose);
        await _waitForTimelineBuckets(
          tester,
          timeline,
          minAssets: _timelineMinimumAssetCount,
        );

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
        await _openFavoritePageAndReturn(
          tester,
          container,
          expectedNavigationType: NavigationBar,
        );

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
      },
    );

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

        unawaited(
          router.push(const TabShellRoute(children: [DriftLibraryRoute()])),
        );
        await _pumpUntil(
          tester,
          () => find.byType(LoginPage).evaluate().isNotEmpty,
          timeout: const Duration(seconds: 30),
        );
        expect(Store.tryGet(StoreKey.accessToken), isNull);

        await _login(
          tester,
          serverUrl: _serverUrl,
          email: _email,
          password: _password,
        );
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
        final favoriteRouteCount = _currentRouteCount(
          router,
          DriftFavoriteRoute.name,
        );
        expect(favoriteRouteCount, 1);

        unawaited(router.push(const DriftFavoriteRoute()));
        await _pumpFor(tester, const Duration(milliseconds: 800));
        expect(find.byType(DriftFavoritePage), findsOneWidget);
        expect(
          _currentRouteCount(router, DriftFavoriteRoute.name),
          favoriteRouteCount,
        );

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
              find
                  .text('enter_your_pin_code_subtitle'.tr())
                  .evaluate()
                  .isNotEmpty,
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
        await pumpUntilFound(
          tester,
          find.byType(Timeline),
          timeout: const Duration(seconds: 60),
        );

        final mainTimeline = container.read(timelineServiceProvider);
        final buckets = await _ensureMultiSelectTimelineAssets(
          tester,
          container,
          mainTimeline,
          createdRemoteAssetIds,
        );
        expect(buckets.length, greaterThanOrEqualTo(2));
        expect(
          mainTimeline.totalAssets,
          greaterThanOrEqualTo(_multiSelectMinimumAssetCount),
        );

        await _waitForVisibleTimelineAssetTiles(tester, minCount: 3);
        expect(find.byType(NavigationBar), findsWidgets);
        final firstTile = _timelineAssetTiles().first;
        final firstAsset = _assetFromTimelineTile(tester, firstTile);

        await tester.longPress(firstTile);
        await _waitForMultiSelectCount(tester, container, 1);
        expect(
          container.read(multiSelectProvider).selectedAssets,
          contains(firstAsset),
        );
        await _pumpUntil(
          tester,
          () => find.byType(NavigationBar).evaluate().isEmpty,
          timeout: const Duration(seconds: 10),
        );
        expect(find.widgetWithText(ElevatedButton, '1'), findsOneWidget);

        await tester.tap(_timelineAssetTiles().at(1));
        await _waitForMultiSelectCount(tester, container, 2);
        final secondAsset = _assetFromTimelineTile(
          tester,
          _timelineAssetTiles().at(1),
        );
        expect(
          container.read(multiSelectProvider).selectedAssets,
          contains(secondAsset),
        );
        await tester.tap(_timelineAssetTileForAsset(secondAsset));
        await _waitForMultiSelectCount(tester, container, 1);
        expect(
          container.read(multiSelectProvider).selectedAssets,
          isNot(contains(secondAsset)),
        );

        final mainScrollable = find
            .descendant(
              of: find.byType(Timeline),
              matching: find.byType(Scrollable),
            )
            .first;
        await tester.fling(mainScrollable, const Offset(0, -1400), 1600);
        await _pumpFor(tester, const Duration(seconds: 1));
        expect(
          container.read(multiSelectProvider).selectedAssets,
          contains(firstAsset),
        );
        await _waitForVisibleTimelineAssetTiles(tester, minCount: 1);
        final scrolledAsset = _firstVisibleTimelineAssetWhere(
          tester,
          (asset) => !container
              .read(multiSelectProvider)
              .selectedAssets
              .contains(asset),
          minCenterY: 240,
          bottomPadding: 120,
        );
        await tester.tap(_timelineAssetTileForAsset(scrolledAsset));
        await _waitForMultiSelectCount(tester, container, 2);
        expect(
          container.read(multiSelectProvider).selectedAssets,
          containsAll([firstAsset, scrolledAsset]),
        );

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
          () => find
              .byType(DriftAssetSelectionTimelinePage)
              .evaluate()
              .isNotEmpty,
          timeout: const Duration(seconds: 30),
        );
        await pumpUntilFound(
          tester,
          find.byType(SelectionSliverAppBar),
          timeout: const Duration(seconds: 30),
        );
        final selectionContainer = ProviderScope.containerOf(
          tester.element(find.byType(Timeline).last),
          listen: false,
        );
        expect(
          selectionContainer.read(multiSelectProvider).forceEnable,
          isTrue,
        );
        await _waitForVisibleTimelineAssetTiles(tester, minCount: 3);
        expect(find.byType(NavigationBar), findsNothing);

        final routeFirstAsset = _assetFromTimelineTile(
          tester,
          _timelineAssetTiles().first,
        );
        await tester.tap(_timelineAssetTiles().first);
        await _waitForMultiSelectCount(tester, selectionContainer, 1);
        expect(
          selectionContainer.read(multiSelectProvider).selectedAssets,
          contains(routeFirstAsset),
        );
        expect(find.textContaining('1'), findsWidgets);

        final bucketSelectButton = find.descendant(
          of: find.byType(TimelineHeader),
          matching: find.byType(IconButton),
        );
        await pumpUntilFound(
          tester,
          bucketSelectButton,
          timeout: const Duration(seconds: 30),
        );
        final beforeBucketCount = selectionContainer
            .read(multiSelectProvider)
            .selectedAssets
            .length;
        await tester.tap(bucketSelectButton.first);
        await _pumpUntil(
          tester,
          () =>
              selectionContainer
                  .read(multiSelectProvider)
                  .selectedAssets
                  .length >
              beforeBucketCount,
          timeout: const Duration(seconds: 30),
        );
        final afterBucketCount = selectionContainer
            .read(multiSelectProvider)
            .selectedAssets
            .length;
        expect(afterBucketCount, greaterThan(beforeBucketCount));

        final selectionScrollable = find
            .descendant(
              of: find.byType(Timeline).last,
              matching: find.byType(Scrollable),
            )
            .first;
        await tester.fling(selectionScrollable, const Offset(0, -1800), 1800);
        await _pumpFor(tester, const Duration(seconds: 1));
        expect(
          selectionContainer.read(multiSelectProvider).selectedAssets.length,
          afterBucketCount,
        );
        await _waitForVisibleTimelineAssetTiles(tester, minCount: 1);
        final routeScrolledAsset = _firstVisibleTimelineAssetWhere(
          tester,
          (asset) => !selectionContainer
              .read(multiSelectProvider)
              .selectedAssets
              .contains(asset),
          minCenterY: 240,
          bottomPadding: 120,
        );
        await tester.tap(_timelineAssetTileForAsset(routeScrolledAsset));
        await _waitForMultiSelectCount(
          tester,
          selectionContainer,
          afterBucketCount + 1,
        );

        await tester.tap(
          find.descendant(
            of: find.byType(SelectionSliverAppBar),
            matching: find.byIcon(Icons.close_rounded),
          ),
        );
        await _pumpUntil(
          tester,
          () => find.byType(DriftAssetSelectionTimelinePage).evaluate().isEmpty,
          timeout: const Duration(seconds: 30),
        );

        unawaited(router.push(DriftAssetSelectionTimelineRoute()));
        await _pumpUntil(
          tester,
          () => find
              .byType(DriftAssetSelectionTimelinePage)
              .evaluate()
              .isNotEmpty,
          timeout: const Duration(seconds: 30),
        );
        final reenteredContainer = ProviderScope.containerOf(
          tester.element(find.byType(Timeline).last),
          listen: false,
        );
        await _waitForMultiSelectCount(tester, reenteredContainer, 0);
        await tester.tap(_timelineAssetTiles().first);
        await _waitForMultiSelectCount(tester, reenteredContainer, 1);
        await tester.tap(
          find.descendant(
            of: find.byType(SelectionSliverAppBar),
            matching: find.byIcon(Icons.close_rounded),
          ),
        );
      },
    );

    _realStackSessionTest(
      'MOB-UI-039-$_caseSuffix',
      'supports bulk favorite, unfavorite, archive, and archive undo',
      (tester) async {
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

        await container
            .read(syncApiRepositoryProvider)
            .deleteSyncAck(_allReplayableSyncAckTypes);
        await Store.delete(StoreKey.syncMigrationStatus);
        await container.read(syncStreamRepositoryProvider).reset();
        final baselineSyncSuccess = await container
            .read(syncStreamServiceProvider)
            .sync();
        expect(baselineSyncSuccess, isTrue);

        final runToken = DateTime.now()
            .toUtc()
            .microsecondsSinceEpoch
            .toString();
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
            () => assetsApi.viewAssetWithHttpInfo(
              assetId,
              size: api.AssetMediaSize.thumbnail,
            ),
          );
        }

        final initialSyncSuccess = await container
            .read(syncStreamServiceProvider)
            .sync();
        expect(initialSyncSuccess, isTrue);
        await _pumpFor(tester, const Duration(seconds: 2));
        await _pumpUntilFoundWithReason(
          tester,
          find.byType(Timeline),
          reason: 'Expected the 045 timeline to appear after sync',
          timeout: const Duration(seconds: 60),
        );

        await _waitForRemoteAssetState(
          tester,
          container,
          favoriteTargetId,
          (asset) =>
              asset.visibility == AssetVisibility.timeline && !asset.isFavorite,
          reason:
              'Expected favorite target to sync as an unfavorited timeline asset',
        );
        await _waitForRemoteAssetState(
          tester,
          container,
          alreadyFavoriteId,
          (asset) =>
              asset.visibility == AssetVisibility.timeline && asset.isFavorite,
          reason:
              'Expected favorite control to sync as an already favorited timeline asset',
        );
        await _waitForRemoteAssetState(
          tester,
          container,
          archiveTargetId,
          (asset) =>
              asset.visibility == AssetVisibility.timeline && !asset.isFavorite,
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
          reason:
              'Initial main timeline should include only unarchived bulk-action assets',
        );
        await _expectTimelineAssetSet(
          tester,
          favoriteTimeline,
          includes: {alreadyFavoriteId},
          excludes: {favoriteTargetId, archiveTargetId, alreadyArchivedId},
          reason:
              'Initial favorite timeline should include only the pre-favorited asset',
        );
        await _expectTimelineAssetSet(
          tester,
          archiveTimeline,
          includes: {alreadyArchivedId},
          excludes: {favoriteTargetId, alreadyFavoriteId, archiveTargetId},
          reason:
              'Initial archive timeline should include only the pre-archived asset',
        );

        await _selectTimelineAssetsById(tester, container, [
          favoriteTargetId,
          alreadyFavoriteId,
        ]);
        expect(
          _bottomSheetIcon(GeneralBottomSheet, Icons.favorite_border_rounded),
          findsOneWidget,
        );
        expect(
          _bottomSheetIcon(GeneralBottomSheet, Icons.favorite_rounded),
          findsNothing,
        );
        await _tapBottomSheetAction(
          tester,
          GeneralBottomSheet,
          Icons.favorite_border_rounded,
        );
        await _waitForMultiSelectCount(tester, container, 0);
        await _waitForAssetInfoState(
          tester,
          assetsApi,
          favoriteTargetId,
          (asset) =>
              asset.isFavorite &&
              asset.visibility == api.AssetVisibility.timeline,
          reason:
              'Expected selected unfavorited asset to become favorite on the server',
        );
        await _waitForAssetInfoState(
          tester,
          assetsApi,
          alreadyFavoriteId,
          (asset) =>
              asset.isFavorite &&
              asset.visibility == api.AssetVisibility.timeline,
          reason:
              'Expected selected already-favorited asset to remain favorite on the server',
        );
        await _expectTimelineAssetSet(
          tester,
          favoriteTimeline,
          includes: {favoriteTargetId, alreadyFavoriteId},
          excludes: {archiveTargetId, alreadyArchivedId},
          reason:
              'Favorite timeline should immediately include both selected favorites',
        );

        unawaited(router.push(const DriftFavoriteRoute()));
        await pumpUntilFound(
          tester,
          find.byType(DriftFavoritePage),
          timeout: const Duration(seconds: 30),
        );
        final favoriteContainer = ProviderScope.containerOf(
          tester.element(find.byType(Timeline).last),
          listen: false,
        );
        await _selectTimelineAssetsById(tester, favoriteContainer, [
          favoriteTargetId,
          alreadyFavoriteId,
        ]);
        expect(
          _bottomSheetIcon(FavoriteBottomSheet, Icons.favorite_rounded),
          findsOneWidget,
        );
        await _tapBottomSheetAction(
          tester,
          FavoriteBottomSheet,
          Icons.favorite_rounded,
        );
        await _waitForMultiSelectCount(tester, favoriteContainer, 0);
        for (final assetId in [favoriteTargetId, alreadyFavoriteId]) {
          await _waitForAssetInfoState(
            tester,
            assetsApi,
            assetId,
            (asset) =>
                !asset.isFavorite &&
                asset.visibility == api.AssetVisibility.timeline,
            reason:
                'Expected selected favorite asset $assetId to be removed from favorites',
          );
        }
        await _expectTimelineAssetSet(
          tester,
          favoriteTimeline,
          includes: const {},
          excludes: {
            favoriteTargetId,
            alreadyFavoriteId,
            archiveTargetId,
            alreadyArchivedId,
          },
          reason:
              'Favorite timeline should drop the bulk-unfavorited assets immediately',
        );

        await router.maybePop();
        await _pumpUntil(
          tester,
          () => find.byType(DriftFavoritePage).evaluate().isEmpty,
          timeout: const Duration(seconds: 30),
        );
        await pumpUntilFound(
          tester,
          find.byType(MainTimelinePage),
          timeout: const Duration(seconds: 30),
        );

        await _selectTimelineAssetsById(tester, container, [
          favoriteTargetId,
          archiveTargetId,
        ]);
        expect(
          _bottomSheetIcon(GeneralBottomSheet, Icons.archive_outlined),
          findsOneWidget,
        );
        await _tapBottomSheetAction(
          tester,
          GeneralBottomSheet,
          Icons.archive_outlined,
        );
        await _waitForMultiSelectCount(tester, container, 0);
        await _waitForRemoteAssetState(
          tester,
          container,
          favoriteTargetId,
          (asset) => asset.visibility == AssetVisibility.archive,
          reason:
              'Expected bulk-archived favorite target to update locally before undo',
        );
        await _waitForRemoteAssetState(
          tester,
          container,
          archiveTargetId,
          (asset) => asset.visibility == AssetVisibility.archive,
          reason:
              'Expected bulk-archived archive target to update locally before undo',
        );
        await _expectTimelineAssetSet(
          tester,
          archiveTimeline,
          includes: {alreadyArchivedId, favoriteTargetId, archiveTargetId},
          excludes: {alreadyFavoriteId},
          reason:
              'Archive timeline should include newly archived assets before undo',
        );

        await _tapSnackbarAction(tester);
        for (final assetId in [favoriteTargetId, archiveTargetId]) {
          await _waitForAssetInfoState(
            tester,
            assetsApi,
            assetId,
            (asset) =>
                !asset.isFavorite &&
                asset.visibility == api.AssetVisibility.timeline,
            reason:
                'Expected archive undo to restore asset $assetId to the server timeline',
          );
          await _waitForRemoteAssetState(
            tester,
            container,
            assetId,
            (asset) =>
                !asset.isFavorite &&
                asset.visibility == AssetVisibility.timeline,
            reason:
                'Expected archive undo to restore local asset $assetId to the timeline',
          );
        }

        unawaited(router.push(const DriftArchiveRoute()));
        await pumpUntilFound(
          tester,
          find.byType(DriftArchivePage),
          timeout: const Duration(seconds: 30),
        );
        await _expectTimelineAssetSet(
          tester,
          archiveTimeline,
          includes: {alreadyArchivedId},
          excludes: {favoriteTargetId, alreadyFavoriteId, archiveTargetId},
          reason:
              'Archive page should retain only the pre-archived control asset after undo',
        );

        final archiveContainer = ProviderScope.containerOf(
          tester.element(find.byType(Timeline).last),
          listen: false,
        );
        await _selectTimelineAssetsById(tester, archiveContainer, [
          alreadyArchivedId,
        ]);
        expect(
          _bottomSheetIcon(ArchiveBottomSheet, Icons.unarchive_outlined),
          findsOneWidget,
        );
        await _tapBottomSheetAction(
          tester,
          ArchiveBottomSheet,
          Icons.unarchive_outlined,
        );
        await _waitForMultiSelectCount(tester, archiveContainer, 0);
        await _waitForAssetInfoState(
          tester,
          assetsApi,
          alreadyArchivedId,
          (asset) => asset.visibility == api.AssetVisibility.timeline,
          reason:
              'Expected unarchive action to restore the archived control to the server timeline',
        );
        final refreshSyncSuccess = await container
            .read(syncStreamServiceProvider)
            .sync();
        expect(refreshSyncSuccess, isTrue);
        await _expectTimelineAssetSet(
          tester,
          mainTimeline,
          includes: {
            favoriteTargetId,
            alreadyFavoriteId,
            archiveTargetId,
            alreadyArchivedId,
          },
          excludes: const {},
          reason: 'Bulk-action state should stay stable after a server refresh',
        );
        await _expectTimelineAssetSet(
          tester,
          archiveTimeline,
          includes: const {},
          excludes: {
            favoriteTargetId,
            alreadyFavoriteId,
            archiveTargetId,
            alreadyArchivedId,
          },
          reason:
              'Archive timeline should remain empty for 039 assets after undo and unarchive',
        );
      },
    );

    _realStackSessionTest(
      'MOB-UI-040-$_caseSuffix',
      'supports bulk album add, create, and remove flows',
      (tester) async {
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
        final originalAlbumIsGrid =
            SettingsRepository.instance.appConfig.album.isGrid;

        addTearDown(() async {
          try {
            await SettingsRepository.instance.write(
              SettingsKey.albumIsGrid,
              originalAlbumIsGrid,
            );
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

        await container
            .read(syncApiRepositoryProvider)
            .deleteSyncAck(_allReplayableSyncAckTypes);
        await Store.delete(StoreKey.syncMigrationStatus);
        await container.read(syncStreamRepositoryProvider).reset();
        final baselineSyncSuccess = await container
            .read(syncStreamServiceProvider)
            .sync();
        expect(baselineSyncSuccess, isTrue);

        final runToken = DateTime.now()
            .toUtc()
            .microsecondsSinceEpoch
            .toString();
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
            () => _authenticatedApiGet(
              '/assets/$assetId/thumbnail?size=thumbnail&edited=false&c=$runToken',
            ),
            timeout: const Duration(minutes: 3),
          );
        }

        final existingAlbumName =
            'immich-e2e-album-actions-040-existing-$runToken';
        final existingAlbum = await albumsApi.createAlbum(
          api.CreateAlbumDto(
            albumName: existingAlbumName,
            assetIds: api.Optional.present([assetIds[0]]),
          ),
        );
        expect(existingAlbum, isNotNull);
        existingAlbumId = existingAlbum!.id;

        await _waitForAlbumInfoState(
          tester,
          albumsApi,
          existingAlbumId,
          (album) =>
              album.albumName == existingAlbumName && album.assetCount == 1,
          reason: 'Expected existing 040 album to start with one member',
        );

        final initialSyncSuccess = await container
            .read(syncStreamServiceProvider)
            .sync();
        expect(initialSyncSuccess, isTrue);
        await _pumpFor(tester, const Duration(seconds: 2));
        await pumpUntilFound(
          tester,
          find.byType(Timeline),
          timeout: const Duration(seconds: 60),
        );

        for (final assetId in assetIds) {
          await _waitForRemoteAssetState(
            tester,
            container,
            assetId,
            (asset) =>
                asset.visibility == AssetVisibility.timeline &&
                !asset.isTrashed,
            reason:
                'Expected 040 asset $assetId to sync locally before album actions',
          );
        }
        await _waitForRemoteAlbumAssetIds(
          tester,
          container,
          existingAlbumId,
          includes: {assetIds[0]},
          excludes: {
            assetIds[1],
            assetIds[2],
            assetIds[3],
            assetIds[4],
            assetIds[5],
          },
          reason: 'Expected existing 040 album local membership before UI add',
        );

        await SettingsRepository.instance.write(SettingsKey.albumIsGrid, false);
        await _selectTimelineAssetsById(tester, container, [
          assetIds[0],
          assetIds[1],
        ]);
        await _tapAlbumInSelector(
          tester,
          GeneralBottomSheet,
          existingAlbumName,
        );
        await _waitForMultiSelectCount(
          tester,
          container,
          0,
          timeout: const Duration(seconds: 30),
        );
        await _waitForAlbumInfoState(
          tester,
          albumsApi,
          existingAlbumId,
          (album) => album.assetCount == 2,
          reason:
              'Expected UI add to existing album to add only the missing asset',
        );
        await _waitForRemoteAlbumAssetIds(
          tester,
          container,
          existingAlbumId,
          includes: {assetIds[0], assetIds[1]},
          excludes: {assetIds[2], assetIds[3], assetIds[4], assetIds[5]},
          reason:
              'Expected local existing album to contain first two assets after UI add',
        );

        await _selectTimelineAssetsById(tester, container, [
          assetIds[0],
          assetIds[1],
        ]);
        await _tapAlbumInSelector(
          tester,
          GeneralBottomSheet,
          existingAlbumName,
        );
        await _waitForMultiSelectCount(
          tester,
          container,
          0,
          timeout: const Duration(seconds: 30),
        );
        await _waitForAlbumInfoState(
          tester,
          albumsApi,
          existingAlbumId,
          (album) => album.assetCount == 2,
          reason:
              'Expected repeated UI add to existing album to avoid duplicate members',
        );
        expect(
          await _remoteAlbumAssetRowCountByAlbumId(drift, existingAlbumId),
          2,
        );

        final newAlbumName = 'immich-e2e-album-actions-040-new-$runToken';
        await _selectTimelineAssetsById(tester, container, [
          assetIds[2],
          assetIds[3],
          assetIds[4],
        ]);
        await _createAlbumFromBottomSheet(tester, newAlbumName);
        await pumpUntilFound(
          tester,
          find.byType(RemoteAlbumPage),
          timeout: const Duration(seconds: 30),
        );

        final newAlbumIds = await _waitForServerAlbumIdsByName(
          tester,
          albumsApi,
          newAlbumName,
          (ids) => ids.length == 1,
          reason:
              'Expected bottom-sheet album creation to create one server album named $newAlbumName',
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

        final albumContainer = ProviderScope.containerOf(
          tester.element(find.byType(Timeline).last),
          listen: false,
        );
        await _selectTimelineAssetsById(tester, albumContainer, [
          assetIds[2],
          assetIds[3],
        ]);
        expect(
          _bottomSheetIcon(RemoteAlbumBottomSheet, Icons.remove_circle_outline),
          findsOneWidget,
        );
        await _tapBottomSheetAction(
          tester,
          RemoteAlbumBottomSheet,
          Icons.remove_circle_outline,
        );
        await _waitForMultiSelectCount(
          tester,
          albumContainer,
          0,
          timeout: const Duration(seconds: 30),
        );
        await _waitForAlbumInfoState(
          tester,
          albumsApi,
          newAlbumId,
          (album) => album.assetCount == 1,
          reason:
              'Expected removing selected assets from new album to leave one member',
        );
        await _waitForRemoteAlbumAssetIds(
          tester,
          container,
          newAlbumId,
          includes: {assetIds[4]},
          excludes: {
            assetIds[0],
            assetIds[1],
            assetIds[2],
            assetIds[3],
            assetIds[5],
          },
          reason:
              'Expected local new album membership to retain only the unselected asset',
        );

        for (final assetId in [assetIds[2], assetIds[3]]) {
          final assetInfo = await assetsApi.getAssetInfo(assetId);
          expect(assetInfo, isNotNull);
          expect(
            assetInfo!.isTrashed,
            isFalse,
            reason: 'Removing $assetId from an album must not delete the asset',
          );
        }

        await router.maybePop();
        await _pumpUntil(
          tester,
          () => find.byType(RemoteAlbumPage).evaluate().isEmpty,
          timeout: const Duration(seconds: 30),
        );
        await pumpUntilFound(
          tester,
          find.byType(MainTimelinePage),
          timeout: const Duration(seconds: 30),
        );
        final refreshSyncSuccess = await container
            .read(syncStreamServiceProvider)
            .sync();
        expect(refreshSyncSuccess, isTrue);

        final mainTimeline = container.read(timelineFactoryProvider).main([
          user!.id,
        ]);
        addTearDown(mainTimeline.dispose);
        await _expectTimelineAssetSet(
          tester,
          mainTimeline,
          includes: assetIds.toSet(),
          excludes: const {},
          reason:
              'Album add/remove actions should not remove assets from the main timeline',
        );
        expect(await _remoteAlbumRowCountById(drift, existingAlbumId), 1);
        expect(await _remoteAlbumRowCountById(drift, newAlbumId), 1);
        expect(
          await _remoteAlbumAssetRowCountByAlbumId(drift, existingAlbumId),
          2,
        );
        expect(await _remoteAlbumAssetRowCountByAlbumId(drift, newAlbumId), 1);
      },
    );

    _realStackSessionTest(
      'MOB-UI-041-$_caseSuffix',
      'supports viewer share, download, and browser actions',
      (tester) async {
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

        final runToken = DateTime.now()
            .toUtc()
            .microsecondsSinceEpoch
            .toString();
        final imageName =
            'immich-e2e-share-download-browser-041-image-$runToken.jpg';
        final localOnlyName =
            'immich-e2e-share-download-browser-041-local-$runToken.jpg';
        final imageId = await _uploadGeneratedJpegAsSecondClient(
          imageName,
          DateTime.now().toUtc(),
        );
        createdRemoteAssetIds.add(imageId);

        await _waitForSuccessfulResponse(
          tester,
          () => _authenticatedApiGet(
            '/assets/$imageId/thumbnail?size=thumbnail&edited=false&c=$runToken',
          ),
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
        final remoteSyncSuccess = await container
            .read(syncStreamServiceProvider)
            .sync();
        expect(remoteSyncSuccess, isTrue);
        await _pumpFor(tester, const Duration(seconds: 2));
        await pumpUntilFound(
          tester,
          find.byType(Timeline),
          timeout: const Duration(seconds: 60),
        );

        final remoteImage = await _waitForRemoteAssetState(
          tester,
          container,
          imageId,
          (asset) => asset.isRemoteOnly,
          reason:
              'Expected the 041 image to sync as a remote-only asset before download',
        );
        final localOnly = await _waitForLocalAssetByName(
          container,
          localOnlyName,
          tester,
        );
        expect(localOnly.isLocalOnly, isTrue);
        expect(
          await _serverAssetIdsByOriginalFilename(
            apiService.searchApi,
            localOnlyName,
          ),
          isEmpty,
          reason: 'Local-only 041 fixture must not already exist on the server',
        );

        final timeline = container.read(timelineFactoryProvider).main([
          user!.id,
        ]);
        addTearDown(timeline.dispose);
        final timelineAssets = await _expectTimelineAssetSet(
          tester,
          timeline,
          includes: {imageId},
          excludes: const {},
          reason:
              'Expected the 041 remote image in the main timeline before viewer actions',
        );
        final remoteVideo = _firstRemoteVideo(timelineAssets);
        expect(
          remoteVideo,
          isNotNull,
          reason:
              'Expected at least one remote video in the real timeline for sharing',
        );

        final mixedShareCount = await container
            .read(assetMediaRepositoryProvider)
            .shareAssets([
              remoteImage,
              remoteVideo!,
              localOnly,
            ], tester.element(find.byType(MainTimelinePage)));
        expect(mixedShareCount, 3);
        await _waitForShareInvocationCount(tester, shareInvocations, 1);
        _expectSharedDisplayNames(shareInvocations.single, {
          remoteImage.name,
          remoteVideo.name,
          localOnlyName,
        });

        await _openTimelineAsset(tester, remoteImage);
        await _showViewerControls(tester, container);

        await _tapViewerActionIcon(tester, Icons.share_rounded);
        await _waitForShareInvocationCount(tester, shareInvocations, 2);
        _expectSharedDisplayNames(shareInvocations.last, {remoteImage.name});

        await container.read(downloadRepositoryProvider).deleteRecordsWithIds([
          remoteImage.id,
        ]);
        await _tapViewerMenuAction(tester, Icons.download);
        final firstDownloadRecord = await _waitForDownloadRecordStatus(
          tester,
          remoteImage.id,
          TaskStatus.complete,
          reason:
              'Expected viewer download to complete for the 041 remote image',
        );
        expect(firstDownloadRecord.group, kDownloadGroupImage);
        expect(firstDownloadRecord.task.filename, remoteImage.name);
        final downloadedLocal = await _waitForLocalAssetByName(
          container,
          remoteImage.name,
          tester,
        );
        expect(downloadedLocal.hasLocal, isTrue);

        final completedDownloadUpdates = downloadUpdates
            .where(
              (update) =>
                  update.task.taskId == remoteImage.id &&
                  update.status == TaskStatus.complete,
            )
            .length;
        final repeatedDownload = await container
            .read(downloadRepositoryProvider)
            .downloadAllAssets([remoteImage]);
        expect(
          repeatedDownload,
          equals([true]),
          reason:
              'A repeated download should be explicitly accepted for re-save',
        );
        await _waitForDownloadUpdateCount(
          tester,
          downloadUpdates,
          remoteImage.id,
          TaskStatus.complete,
          completedDownloadUpdates + 1,
          reason:
              'Expected repeated download to run to completion instead of being silently ignored',
        );

        await _tapViewerMenuAction(tester, Icons.open_in_browser);
        await _pumpUntil(
          tester,
          () => launchedBrowserUrls.isNotEmpty,
          timeout: const Duration(seconds: 10),
        );
        final expectedBrowserUrl =
            '${Store.get(StoreKey.serverEndpoint).replaceFirst('/api', '')}/photos/${remoteImage.id}';
        expect(launchedBrowserUrls.single, expectedBrowserUrl);
        final browserAssetResponse = await _waitForSuccessfulResponse(
          tester,
          () => _authenticatedApiGet(
            '/assets/${remoteImage.id}/thumbnail?size=thumbnail&edited=false',
          ),
        );
        expect(browserAssetResponse.bodyBytes, isNotEmpty);
      },
    );

    _realStackSessionTest(
      'MOB-UI-042-$_caseSuffix',
      'imports shared media through the share intent upload flow',
      (tester) async {
        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = const Size(430, 932);
        addTearDown(tester.view.reset);

        await _loadAuthenticatedApp(tester, overrideCancellation: true);
        final container = _containerOfApp(tester);
        final apiService = container.read(apiServiceProvider);
        final assetsApi = apiService.assetsApi;
        final searchApi = apiService.searchApi;
        final createdRemoteAssetIds = <String>{};
        final fixtureRoot = await Directory.systemTemp.createTemp(
          'immich-share-intent-042-',
        );

        addTearDown(() async {
          for (final assetId in createdRemoteAssetIds) {
            await _deleteTestAssetBestEffort(assetsApi, assetId);
          }
          if (fixtureRoot.existsSync()) {
            fixtureRoot.deleteSync(recursive: true);
          }
        });

        final baselineSyncSuccess = await container
            .read(syncStreamServiceProvider)
            .sync();
        expect(baselineSyncSuccess, isTrue);
        await pumpUntilFound(
          tester,
          find.byType(Timeline),
          timeout: const Duration(seconds: 60),
        );
        final user = Store.tryGet(StoreKey.currentUser);
        expect(user, isNotNull);
        final timeline = container.read(timelineFactoryProvider).main([
          user!.id,
        ]);
        addTearDown(timeline.dispose);
        await _pumpUntil(
          tester,
          () => timeline.totalAssets > 0,
          timeout: const Duration(seconds: 60),
        );
        final timelineAssets = await _loadAllTimelineAssets(timeline);
        final sourceVideo = _firstRemoteVideo(timelineAssets);
        expect(
          sourceVideo,
          isNotNull,
          reason:
              'Expected at least one remote video for the share intent video fixture',
        );

        final runToken = DateTime.now()
            .toUtc()
            .microsecondsSinceEpoch
            .toString();
        final cancelImageName =
            'immich-e2e-share-intent-042-cancel-$runToken.jpg';
        final uploadImageName =
            'immich-e2e-share-intent-042-image-$runToken.jpg';
        final uploadVideoName =
            'immich-e2e-share-intent-042-video-$runToken.mp4';

        final cancelImageFile = await _writeShareIntentImageFile(
          fixtureRoot,
          cancelImageName,
          runToken.hashCode,
        );
        final uploadImageFile = await _writeShareIntentImageFile(
          fixtureRoot,
          uploadImageName,
          runToken.hashCode + 1,
        );
        final uploadVideoFile = await _writeShareIntentVideoFile(
          container,
          tester,
          sourceVideo!,
          fixtureRoot,
          uploadVideoName,
          runToken,
        );

        expect(
          await _serverAssetIdsByOriginalFilename(searchApi, cancelImageName),
          isEmpty,
        );
        expect(
          await _serverAssetIdsByOriginalFilename(searchApi, uploadImageName),
          isEmpty,
        );
        expect(
          await _serverAssetIdsByOriginalFilename(
            searchApi,
            uploadVideoName,
            type: api.AssetTypeEnum.VIDEO,
          ),
          isEmpty,
        );

        final notifier = container.read(shareIntentUploadProvider.notifier);
        final cancelAttachment = await _shareIntentAttachment(
          cancelImageFile,
          ShareIntentAttachmentType.image,
        );
        notifier.onSharedMedia([cancelAttachment]);
        await _waitForShareIntentPage(tester, {cancelImageName});
        await _waitForShareIntentState(
          tester,
          container,
          (attachments) =>
              attachments.length == 1 &&
              attachments.single.status == UploadStatus.enqueued,
          reason: 'Expected the single shared image to be listed before cancel',
        );

        final backButton = find.descendant(
          of: find.byType(ShareIntentPage),
          matching: find.byIcon(Icons.arrow_back),
        );
        await pumpUntilFound(
          tester,
          backButton,
          timeout: const Duration(seconds: 30),
        );
        await tester.tap(backButton.first, warnIfMissed: false);
        await _pumpUntil(
          tester,
          () => find.byType(ShareIntentPage).evaluate().isEmpty,
          timeout: const Duration(seconds: 30),
        );
        expect(
          await _serverAssetIdsByOriginalFilename(searchApi, cancelImageName),
          isEmpty,
          reason:
              'Cancelling the share intent page must not upload the shared image',
        );

        final uploadImageAttachment = await _shareIntentAttachment(
          uploadImageFile,
          ShareIntentAttachmentType.image,
        );
        final uploadVideoAttachment = await _shareIntentAttachment(
          uploadVideoFile,
          ShareIntentAttachmentType.video,
        );
        notifier.onSharedMedia([uploadImageAttachment, uploadVideoAttachment]);
        await _waitForShareIntentPage(tester, {
          uploadImageName,
          uploadVideoName,
        });
        await _waitForShareIntentState(
          tester,
          container,
          (attachments) =>
              attachments.length == 2 &&
              attachments.every(
                (attachment) => attachment.status == UploadStatus.enqueued,
              ) &&
              attachments.any((attachment) => attachment.isImage) &&
              attachments.any((attachment) => attachment.isVideo),
          reason:
              'Expected image and video attachments to be selected for upload',
        );

        final uploadButton = find.descendant(
          of: find.byType(ShareIntentPage),
          matching: find.widgetWithText(ElevatedButton, 'upload'.tr()),
        );
        await pumpUntilFound(
          tester,
          uploadButton,
          timeout: const Duration(seconds: 30),
        );
        await tester.tap(uploadButton.last, warnIfMissed: false);

        await _waitForShareIntentState(
          tester,
          container,
          (attachments) =>
              attachments.length == 2 &&
              attachments.every(
                (attachment) =>
                    attachment.status == UploadStatus.complete &&
                    attachment.uploadProgress == 1.0,
              ),
          reason: 'Expected all shared media uploads to complete',
        );

        final uploadedImageIds = await _waitForServerAssetIdsByOriginalFilename(
          tester,
          searchApi,
          uploadImageName,
          (ids) => ids.isNotEmpty,
          reason:
              'Expected the confirmed shared image to exist on the real server',
        );
        final uploadedVideoIds = await _waitForServerAssetIdsByOriginalFilename(
          tester,
          searchApi,
          uploadVideoName,
          (ids) => ids.isNotEmpty,
          reason:
              'Expected the confirmed shared video to exist on the real server',
          type: api.AssetTypeEnum.VIDEO,
          timeout: const Duration(minutes: 2),
        );
        createdRemoteAssetIds.addAll(uploadedImageIds);
        createdRemoteAssetIds.addAll(uploadedVideoIds);

        final syncSuccess = await container
            .read(syncStreamServiceProvider)
            .sync();
        expect(syncSuccess, isTrue);
        for (final assetId in createdRemoteAssetIds) {
          await _waitForRemoteAssetState(
            tester,
            container,
            assetId,
            (asset) =>
                asset.visibility == AssetVisibility.timeline &&
                !asset.isTrashed,
            reason:
                'Expected share intent uploaded asset $assetId to sync into the local timeline',
          );
        }
        expect(
          await _serverAssetIdsByOriginalFilename(searchApi, cancelImageName),
          isEmpty,
        );
      },
    );

    _realStackSessionTest(
      'MOB-UI-043-$_caseSuffix',
      'edits image crop transform reset and save',
      (tester) async {
        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = const Size(430, 932);
        addTearDown(tester.view.reset);

        await _loadAuthenticatedApp(tester, overrideCancellation: true);
        final container = _containerOfApp(tester);
        final apiService = container.read(apiServiceProvider);
        final assetsApi = apiService.assetsApi;
        final createdRemoteAssetIds = <String>[];

        addTearDown(() async {
          for (final assetId in createdRemoteAssetIds) {
            await _deleteTestAssetBestEffort(assetsApi, assetId);
          }
        });

        final runToken = DateTime.now()
            .toUtc()
            .microsecondsSinceEpoch
            .toString();
        final imageName = 'immich-e2e-image-edit-043-$runToken.png';
        final imageId = await _uploadGeneratedPngAsSecondClient(
          imageName,
          DateTime.now().toUtc(),
          width: 1600,
          height: 1000,
        );
        createdRemoteAssetIds.add(imageId);

        final originalDownload = await _waitForSuccessfulResponse(
          tester,
          () => container
              .read(assetApiRepositoryProvider)
              .downloadAsset(imageId, edited: false),
          timeout: const Duration(minutes: 3),
        );
        expect(await _decodeImageSize(originalDownload.bodyBytes), (
          width: 1600,
          height: 1000,
        ));
        await _waitForSuccessfulResponse(
          tester,
          () => _authenticatedApiGet(
            '/assets/$imageId/thumbnail?size=thumbnail&edited=false&c=$runToken',
          ),
          timeout: const Duration(minutes: 3),
        );

        final syncSuccess = await container
            .read(syncStreamServiceProvider)
            .sync();
        expect(syncSuccess, isTrue);
        await pumpUntilFound(
          tester,
          find.byType(Timeline),
          timeout: const Duration(seconds: 60),
        );
        final user = Store.tryGet(StoreKey.currentUser);
        expect(user, isNotNull);
        final timeline = container.read(timelineFactoryProvider).main([
          user!.id,
        ]);
        addTearDown(timeline.dispose);
        await _expectTimelineAssetSet(
          tester,
          timeline,
          includes: {imageId},
          excludes: const {},
          reason:
              'Expected the 043 high-resolution image in the main timeline before editing',
        );
        final remoteImage = await _waitForRemoteAssetState(
          tester,
          container,
          imageId,
          (asset) =>
              asset.isRemoteOnly &&
              asset.isEditable &&
              asset.width == 1600 &&
              asset.height == 1000,
          reason:
              'Expected the 043 image to sync with editable dimensions before opening the editor',
        );
        final exif = await _waitForRemoteExifState(
          tester,
          container.read(assetServiceProvider),
          remoteImage,
          (exif) => exif.width == 1600 && exif.height == 1000,
          reason:
              'Expected the 043 image EXIF dimensions before opening the editor action',
        );
        expect(exif.isFlipped, isFalse);

        await _openTimelineAsset(tester, remoteImage);
        await _showViewerControls(tester, container);
        await _tapViewerActionIcon(tester, Icons.tune);
        await pumpUntilFound(
          tester,
          find.byType(DriftEditImagePage),
          timeout: const Duration(seconds: 30),
        );
        await _waitForEditorState(
          tester,
          container,
          (state) =>
              state.originalWidth == 1600 &&
              state.originalHeight == 1000 &&
              !state.hasEdits,
          reason:
              'Expected the editor to load the original 043 image dimensions',
        );

        const finalCrop = Rect.fromLTWH(0.10, 0.10, 0.50, 0.45);
        container.read(editorStateProvider.notifier).setCrop(finalCrop);
        await _waitForEditorState(
          tester,
          container,
          (state) => state.crop == finalCrop && state.hasUnsavedEdits,
          reason: 'Expected free crop edits to update the editor state',
        );
        await _tapEditorAspectRatio(tester, '16:9');
        await _waitForEditorState(
          tester,
          container,
          (state) =>
              state.aspectRatio ==
              const CropAspectRatio(numerator: 16, denominator: 9),
          reason: 'Expected the fixed 16:9 crop ratio to be selected',
        );

        await _tapEditorIcon(tester, Icons.flip, occurrence: 0);
        await _waitForEditorState(
          tester,
          container,
          (state) => state.flipHorizontal,
          reason: 'Expected horizontal flip to update the editor state',
        );
        await _tapEditorIcon(tester, Icons.rotate_right);
        await _waitForEditorState(
          tester,
          container,
          (state) => state.rotationAngle == 90,
          reason: 'Expected clockwise rotation to update the editor state',
        );

        await _tapEditorReset(tester);
        await _waitForEditorState(
          tester,
          container,
          (state) =>
              !state.hasEdits &&
              state.crop == const Rect.fromLTRB(0, 0, 1, 1) &&
              state.aspectRatio == CropAspectRatio.free,
          reason:
              'Expected reset to restore the original crop, transform, and ratio',
        );

        container.read(editorStateProvider.notifier).setCrop(finalCrop);
        await _tapEditorAspectRatio(tester, '16:9');
        await _tapEditorIcon(tester, Icons.flip, occurrence: 0);
        await _tapEditorIcon(tester, Icons.rotate_right);
        await _waitForEditorState(
          tester,
          container,
          (state) =>
              state.hasEdits &&
              state.flipHorizontal &&
              state.rotationAngle == 90,
          reason: 'Expected final edit state before save',
        );
        final expectedCropParameters = convertRectToCropParameters(
          container.read(editorStateProvider).crop,
          1600,
          1000,
        );
        await _tapEditorIcon(tester, Icons.done_rounded);
        await _pumpUntil(
          tester,
          () => find.byType(DriftEditImagePage).evaluate().isEmpty,
          timeout: const Duration(minutes: 2),
        );

        final postEditSyncSuccess = await container
            .read(syncStreamServiceProvider)
            .sync();
        expect(postEditSyncSuccess, isTrue);
        final edits = await _waitForLocalAssetEdits(
          tester,
          container,
          imageId,
          (edits) =>
              edits.length == 3 &&
              edits[0] is CropEdit &&
              edits[1] is MirrorEdit &&
              edits[2] is RotateEdit,
          reason:
              'Expected saved crop, mirror, and rotate edits to sync locally',
        );
        final crop = edits[0] as CropEdit;
        expect(crop.parameters.x, expectedCropParameters.x);
        expect(crop.parameters.y, expectedCropParameters.y);
        expect(crop.parameters.width, expectedCropParameters.width);
        expect(crop.parameters.height, expectedCropParameters.height);
        expect(
          (edits[1] as MirrorEdit).parameters.axis,
          api.MirrorAxis.horizontal,
        );
        expect((edits[2] as RotateEdit).parameters.angle, 90);

        final editedDownload = await _waitForEditedAssetDownloadWithSize(
          tester,
          container,
          imageId,
          (size) =>
              size ==
              (
                width: expectedCropParameters.height,
                height: expectedCropParameters.width,
              ),
          reason:
              'Expected the edited 043 image download to reflect crop and rotation dimensions',
        );
        expect(editedDownload.statusCode, 200);
        final refreshedImage = await _waitForRemoteAssetState(
          tester,
          container,
          imageId,
          (asset) => asset.isEdited,
          reason:
              'Expected the 043 local asset row to be marked edited after save',
        );
        expect(refreshedImage.id, imageId);
      },
    );

    _realStackSessionTest(
      'MOB-UI-044-$_caseSuffix',
      'edits details date timezone location and clears location',
      (tester) async {
        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = const Size(430, 932);
        addTearDown(tester.view.reset);

        await _loadAuthenticatedApp(
          tester,
          overrideCancellation: true,
          closeDriftOnDispose: false,
        );
        var container = _containerOfApp(tester);
        var assetsApi = container.read(apiServiceProvider).assetsApi;
        final createdRemoteAssetIds = <String>[];
        var drift = container.read(driftProvider);

        addTearDown(() async {
          for (final assetId in createdRemoteAssetIds) {
            await _deleteTestAssetBestEffort(assetsApi, assetId);
          }
        });

        final runToken = DateTime.now()
            .toUtc()
            .microsecondsSinceEpoch
            .toString();
        final imageName = 'immich-e2e-metadata-edit-044-$runToken.jpg';
        final initialCreatedAt = DateTime.utc(2026, 2, 13, 20, 0);
        final imageId = await _uploadGeneratedJpegAsSecondClient(
          imageName,
          initialCreatedAt,
          sourceMetadata: const {
            'latitude': 40.7128,
            'longitude': -74.0060,
            'timezone_offset_minutes': -300,
          },
        );
        createdRemoteAssetIds.add(imageId);

        var syncSuccess = await container
            .read(syncStreamServiceProvider)
            .sync();
        expect(syncSuccess, isTrue);
        await pumpUntilFound(
          tester,
          find.byType(Timeline),
          timeout: const Duration(seconds: 60),
        );

        final user = Store.tryGet(StoreKey.currentUser);
        expect(user, isNotNull);
        var timeline = container.read(timelineFactoryProvider).main([user!.id]);
        await _expectTimelineAssetSet(
          tester,
          timeline,
          includes: {imageId},
          excludes: const {},
          reason:
              'Expected the 044 metadata-edit asset in the main timeline before editing',
        );
        final remoteImage = await _waitForRemoteAssetState(
          tester,
          container,
          imageId,
          (asset) => asset.isRemoteOnly && asset.isImage,
          reason: 'Expected the 044 asset to sync before opening details',
        );
        await _waitForRemoteExifState(
          tester,
          container.read(assetServiceProvider),
          remoteImage,
          (exif) =>
              exif.hasCoordinates && (exif.latitude! - 40.7128).abs() < 0.0001,
          reason: 'Expected initial 044 EXIF coordinates before editing',
        );

        await _openTimelineAsset(tester, remoteImage);
        EventStream.shared.emit(const ViewerShowDetailsEvent());
        await pumpUntilFound(
          tester,
          find.byType(DateTimeDetails),
          timeout: const Duration(seconds: 30),
        );
        await pumpUntilFound(
          tester,
          find.byType(LocationDetails),
          timeout: const Duration(seconds: 30),
        );
        final detailsContainer = ProviderScope.containerOf(
          tester.element(find.byType(LocationDetails).first),
          listen: false,
        );
        expect(find.textContaining('40.7128'), findsWidgets);

        const updatedDateTime = '2026-02-14T00:30:00.000+14:00';
        const updatedLocation = LatLng(35.6895, 139.6917);
        await container.read(assetServiceProvider).update([
          imageId,
        ], dateTime: const .some(updatedDateTime));
        await container.read(assetServiceProvider).update([
          imageId,
        ], location: const Option<LatLng?>.some(updatedLocation));
        detailsContainer.invalidate(assetExifProvider);

        syncSuccess = await container.read(syncStreamServiceProvider).sync();
        expect(syncSuccess, isTrue);
        final updatedAsset = await _waitForRemoteAssetState(
          tester,
          container,
          imageId,
          (asset) =>
              asset.createdAt.toUtc() ==
              DateTime.parse(updatedDateTime).toUtc(),
          reason:
              'Expected local asset timestamp to update after editing date and time',
        );
        final updatedExif = await _waitForRemoteExifState(
          tester,
          container.read(assetServiceProvider),
          updatedAsset,
          (exif) =>
              exif.dateTimeOriginal?.toUtc() ==
                  DateTime.parse(updatedDateTime).toUtc() &&
              exif.timeZone == 'UTC+14:00' &&
              exif.latitude != null &&
              exif.longitude != null &&
              (exif.latitude! - updatedLocation.latitude).abs() < 0.0001 &&
              (exif.longitude! - updatedLocation.longitude).abs() < 0.0001,
          reason:
              'Expected edited date/time, timezone, and coordinates to sync locally',
        );
        expect(updatedExif.hasCoordinates, isTrue);
        await _expectRemoteAssetLocalDateTime(
          drift,
          imageId,
          DateTime.parse('2026-02-14T00:30:00.000'),
        );

        await pumpUntilFound(
          tester,
          find.textContaining('GMT+14:00'),
          timeout: const Duration(seconds: 30),
        );
        await pumpUntilFound(
          tester,
          find.textContaining('35.6895'),
          timeout: const Duration(seconds: 30),
        );

        final clearLocationButton = find.descendant(
          of: find.byType(LocationDetails),
          matching: find.byIcon(Icons.location_off_outlined),
        );
        await pumpUntilFound(
          tester,
          clearLocationButton,
          timeout: const Duration(seconds: 30),
        );
        await tester.tap(
          clearLocationButton.hitTestable().last,
          warnIfMissed: false,
        );
        await _pumpFor(tester, const Duration(seconds: 1));

        final clearedExif = await _waitForRemoteExifState(
          tester,
          container.read(assetServiceProvider),
          updatedAsset,
          (exif) =>
              exif.latitude == null &&
              exif.longitude == null &&
              exif.timeZone == 'UTC+14:00',
          reason:
              'Expected clearing the 044 location to remove local EXIF coordinates without losing timezone',
        );
        expect(clearedExif.hasCoordinates, isFalse);
        expect(find.text('add_a_location'.tr()), findsWidgets);

        await timeline.dispose();
        await tester.pumpWidget(const SizedBox.shrink());
        await _pumpFor(tester, const Duration(milliseconds: 500));
        await _loadAppPreservingStore(
          tester,
          overrideCancellation: true,
          closeDriftOnDispose: false,
        );
        await _waitForAccessToken(tester);
        await _waitForCurrentUser(_email, tester);
        container = _containerOfApp(tester);
        assetsApi = container.read(apiServiceProvider).assetsApi;
        drift = container.read(driftProvider);
        await _dismissFeatureMessageIfVisible(tester);

        syncSuccess = await container.read(syncStreamServiceProvider).sync();
        expect(syncSuccess, isTrue);
        final restartedAsset = await _waitForRemoteAssetState(
          tester,
          container,
          imageId,
          (asset) =>
              asset.createdAt.toUtc() ==
              DateTime.parse(updatedDateTime).toUtc(),
          reason: 'Expected edited timestamp to persist after app restart',
        );
        await _waitForRemoteExifState(
          tester,
          container.read(assetServiceProvider),
          restartedAsset,
          (exif) =>
              exif.latitude == null &&
              exif.longitude == null &&
              exif.timeZone == 'UTC+14:00',
          reason:
              'Expected cleared location and edited timezone to persist after app restart',
        );
        await _expectRemoteAssetLocalDateTime(
          drift,
          imageId,
          DateTime.parse('2026-02-14T00:30:00.000'),
        );
        timeline = container.read(timelineFactoryProvider).main([user.id]);
        await _expectTimelineAssetSet(
          tester,
          timeline,
          includes: {imageId},
          excludes: const {},
          reason:
              'Expected restarted timeline to include the metadata-edited 044 asset',
        );
        await timeline.dispose();
      },
    );

    _realStackSessionTest(
      'MOB-UI-045-$_caseSuffix',
      'shows and edits tags rating and OCR metadata',
      (tester) async {
        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = const Size(430, 932);
        addTearDown(tester.view.reset);

        await _loadAuthenticatedApp(
          tester,
          overrideCancellation: true,
          closeDriftOnDispose: false,
        );
        var container = _containerOfApp(tester);
        final apiService = container.read(apiServiceProvider);
        var assetsApi = apiService.assetsApi;
        final searchApi = apiService.searchApi;
        final tagsApi = apiService.tagsApi;
        final createdRemoteAssetIds = <String>[];

        addTearDown(() async {
          for (final assetId in createdRemoteAssetIds) {
            await _deleteTestAssetBestEffort(assetsApi, assetId);
          }
        });

        final targetCreatedAt = DateTime.now().toUtc();
        final controlCreatedAt = targetCreatedAt.add(
          const Duration(microseconds: 1),
        );
        final runToken = targetCreatedAt.microsecondsSinceEpoch.toString();
        final tagValue = 'MOB-UI-045-$runToken';
        final ocrText = 'MOB UI 045 BOARDING PASS GATE A12 $runToken';
        final targetName = 'immich-e2e-tags-rating-ocr-045-$runToken.jpg';
        final controlName =
            'immich-e2e-tags-rating-ocr-045-control-$runToken.jpg';
        final targetId = await _uploadGeneratedJpegAsSecondClient(
          targetName,
          targetCreatedAt,
          sourceMetadata: {
            'width': 80,
            'height': 60,
            'immich_rating': 2,
            'immich_ocr_v1': [
              {
                'text': ocrText,
                'x1': 0.1,
                'y1': 0.2,
                'x2': 0.9,
                'y2': 0.2,
                'x3': 0.9,
                'y3': 0.8,
                'x4': 0.1,
                'y4': 0.8,
                'boxScore': 0.99,
                'textScore': 0.98,
                'isVisible': true,
              },
            ],
          },
        );
        final controlId = await _uploadGeneratedJpegAsSecondClient(
          controlName,
          controlCreatedAt,
          sourceMetadata: {
            'width': 80,
            'height': 60,
            'immich_rating': 5,
            'immich_ocr_text': 'MOB UI 045 CONTROL ONLY',
          },
        );
        createdRemoteAssetIds.addAll([targetId, controlId]);

        final createdTags = await container
            .read(tagProvider.notifier)
            .upsertTags([tagValue]);
        expect(createdTags, hasLength(1));
        final tagId = createdTags.single.id;
        expect(createdTags.single.value, tagValue);
        final taggedCount = await container
            .read(tagProvider.notifier)
            .bulkTagAssets([targetId], [tagId]);
        expect(taggedCount, 1);

        var syncSuccess = await container
            .read(syncStreamServiceProvider)
            .sync();
        expect(syncSuccess, isTrue);
        await pumpUntilFound(
          tester,
          find.byType(Timeline),
          timeout: const Duration(seconds: 60),
        );

        final user = Store.tryGet(StoreKey.currentUser);
        expect(user, isNotNull);
        final timeline = container.read(timelineFactoryProvider).main([
          user!.id,
        ]);
        await _expectTimelineAssetSet(
          tester,
          timeline,
          includes: {targetId, controlId},
          excludes: const {},
          reason:
              'Expected the 045 tagged/rated/OCR fixture assets in the main timeline',
        );
        final remoteImage = await _waitForRemoteAssetState(
          tester,
          container,
          targetId,
          (asset) => asset.isRemoteOnly && asset.isImage,
          reason: 'Expected the 045 target asset to sync before viewer checks',
        );
        await _waitForRemoteExifState(
          tester,
          container.read(assetServiceProvider),
          remoteImage,
          (exif) => exif.rating == 2,
          reason: 'Expected the initial 045 rating to sync into local EXIF',
        );
        final localOcr = await _waitForLocalOcrState(
          tester,
          container,
          targetId,
          (rows) => rows.any((row) => row.text == ocrText && row.isVisible),
          reason: 'Expected the 045 OCR text to sync into local OCR rows',
        );
        expect(localOcr.map((row) => row.text), contains(ocrText));

        final tagSearch = await _waitForSearchServiceAssetIds(
          tester,
          container.read(searchServiceProvider),
          _searchFilter().copyWith(tagIds: [tagId]),
          (ids) => ids.contains(targetId) && !ids.contains(controlId),
          reason: 'Expected tag search to return only the 045 tagged asset',
        );
        expect(tagSearch, contains(targetId));

        final ocrSearch = await _waitForSearchServiceAssetIds(
          tester,
          container.read(searchServiceProvider),
          _searchFilter().copyWith(ocr: 'boarding pass'),
          (ids) => ids.contains(targetId) && !ids.contains(controlId),
          reason: 'Expected OCR search to match the 045 target asset text',
        );
        expect(ocrSearch, contains(targetId));

        await _openTimelineAsset(tester, remoteImage);
        await _showViewerControls(tester, container);
        EventStream.shared.emit(const ViewerShowDetailsEvent());
        final ratingStars = find.descendant(
          of: find.byType(RatingDetails),
          matching: find.byIcon(Icons.star_rounded),
        );
        await _pumpUntilFoundWithReason(
          tester,
          ratingStars,
          reason: 'Expected the 045 detail panel to show five rating stars',
          timeout: const Duration(seconds: 30),
        );
        expect(ratingStars, findsNWidgets(5));

        final updateResult = await container
            .read(actionProvider.notifier)
            .updateRating(ActionSource.viewer, 5);
        expect(updateResult.success, isTrue);
        await _waitForRemoteExifState(
          tester,
          container.read(assetServiceProvider),
          remoteImage,
          (exif) => exif.rating == 5,
          reason:
              'Expected editing the 045 rating from the viewer to update local EXIF',
        );

        final combinedSearch = await _waitForServerSearchResponse(
          tester,
          searchApi,
          _metadataSearchDto(rating: 5, tagIds: [tagId], ocr: 'boarding pass'),
          (response) {
            final ids = _serverSearchAssetIds(response);
            return ids.contains(targetId) && !ids.contains(controlId);
          },
          reason:
              'Expected combined tag/rating/OCR server search to match only the target asset',
        );
        expect(_serverSearchAssetIds(combinedSearch), contains(targetId));

        await _waitForServerSearchResponse(
          tester,
          searchApi,
          _metadataSearchDto(rating: 2, tagIds: [tagId], ocr: 'boarding pass'),
          (response) => !_serverSearchAssetIds(response).contains(targetId),
          reason:
              'Expected the previous 045 rating to stop matching after edit',
        );

        final untagResponse = await tagsApi.untagAssets(
          tagId,
          api.BulkIdsDto(ids: [targetId]),
        );
        _expectBulkSuccess(untagResponse, {
          targetId,
        }, reason: 'Expected removing the 045 tag to succeed');
        await _waitForSearchServiceAssetIds(
          tester,
          container.read(searchServiceProvider),
          _searchFilter().copyWith(tagIds: [tagId]),
          (ids) => !ids.contains(targetId),
          reason:
              'Expected tag search to stop returning the 045 asset after tag removal',
        );
        final retagResponse = await tagsApi.tagAssets(
          tagId,
          api.BulkIdsDto(ids: [targetId]),
        );
        _expectBulkSuccess(retagResponse, {
          targetId,
        }, reason: 'Expected re-adding the 045 tag to succeed');

        container.read(assetViewerProvider.notifier).setShowingDetails(false);
        await _pumpUntil(
          tester,
          () => !container.read(assetViewerProvider).showingDetails,
          timeout: const Duration(seconds: 10),
        );
        await _showViewerControls(tester, container);

        final ocrButton = find.descendant(
          of: find.byType(AssetViewer),
          matching: find.byIcon(Icons.text_fields_rounded),
        );
        await _pumpUntilFoundWithReason(
          tester,
          ocrButton,
          reason: 'Expected the 045 viewer OCR toggle button to be visible',
          timeout: const Duration(seconds: 30),
        );
        await tester.tap(ocrButton.hitTestable().last, warnIfMissed: false);
        await _pumpFor(tester, const Duration(seconds: 1));
        final ocrOverlay = find.byType(OcrOverlay);
        await _pumpUntilFoundWithReason(
          tester,
          ocrOverlay,
          reason:
              'Expected the 045 OCR overlay to mount after tapping the OCR toggle',
          timeout: const Duration(seconds: 30),
        );
        expect(
          remoteImage.width,
          isNotNull,
          reason: 'Expected 045 OCR overlay target asset to have synced width',
        );
        expect(
          remoteImage.height,
          isNotNull,
          reason: 'Expected 045 OCR overlay target asset to have synced height',
        );
        final ocrBox = find.descendant(
          of: ocrOverlay,
          matching: find.byKey(const ValueKey(0)),
        );
        await _pumpUntilFoundWithReason(
          tester,
          ocrBox,
          reason: 'Expected the 045 OCR overlay to render a selectable OCR box',
          timeout: const Duration(seconds: 30),
        );
        await tester.tap(ocrBox.hitTestable().first, warnIfMissed: false);
        await _pumpFor(tester, const Duration(milliseconds: 500));
        await _pumpUntilFoundWithReason(
          tester,
          find.text(ocrText),
          reason: 'Expected the 045 OCR overlay to show the synced text',
          timeout: const Duration(seconds: 30),
        );

        await timeline.dispose();
        await tester.pumpWidget(const SizedBox.shrink());
        await _pumpFor(tester, const Duration(milliseconds: 500));
        await _loadAppPreservingStore(
          tester,
          overrideCancellation: true,
          closeDriftOnDispose: false,
        );
        await _waitForAccessToken(tester);
        await _waitForCurrentUser(_email, tester);
        container = _containerOfApp(tester);
        assetsApi = container.read(apiServiceProvider).assetsApi;
        await _dismissFeatureMessageIfVisible(tester);

        syncSuccess = await container.read(syncStreamServiceProvider).sync();
        expect(syncSuccess, isTrue);
        final restartedAsset = await _waitForRemoteAssetState(
          tester,
          container,
          targetId,
          (asset) => asset.isRemoteOnly && asset.isImage,
          reason: 'Expected the 045 asset to persist after app restart',
        );
        await _waitForRemoteExifState(
          tester,
          container.read(assetServiceProvider),
          restartedAsset,
          (exif) => exif.rating == 5,
          reason: 'Expected the edited 045 rating to persist after app restart',
        );
        await _waitForLocalOcrState(
          tester,
          container,
          targetId,
          (rows) => rows.any((row) => row.text == ocrText && row.isVisible),
          reason: 'Expected the 045 OCR row to persist after app restart',
        );
        await _waitForSearchServiceAssetIds(
          tester,
          container.read(searchServiceProvider),
          _searchFilter().copyWith(
            tagIds: [tagId],
            ocr: 'boarding pass',
            rating: SearchRatingFilter(rating: const .some(5)),
          ),
          (ids) => ids.contains(targetId) && !ids.contains(controlId),
          reason:
              'Expected combined app search to match only the persisted 045 target asset',
        );

        await timeline.dispose();
      },
    );

    _realStackSessionTest(
      'MOB-UI-046-$_caseSuffix',
      'creates browses promotes removes and splits stacks',
      (tester) async {
        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = const Size(430, 932);
        addTearDown(tester.view.reset);

        await _loadAuthenticatedApp(
          tester,
          overrideCancellation: true,
          closeDriftOnDispose: false,
        );
        var container = _containerOfApp(tester);
        var apiService = container.read(apiServiceProvider);
        var assetsApi = apiService.assetsApi;
        var stacksApi = apiService.stacksApi;
        final createdRemoteAssetIds = <String>[];
        String? stackId;
        final user = Store.tryGet(StoreKey.currentUser);
        expect(user, isNotNull);

        addTearDown(() async {
          try {
            container.read(multiSelectProvider.notifier).reset();
          } catch (_) {
            // ProviderScope may already be disposed when an earlier expectation fails.
          }
          final id = stackId;
          if (id != null) {
            try {
              await stacksApi.deleteStack(id);
            } catch (_) {
              // The test body may already have unstacked the temporary stack.
            }
          }
          for (final assetId in createdRemoteAssetIds) {
            await _deleteTestAssetBestEffort(assetsApi, assetId);
          }
        });

        await container
            .read(syncApiRepositoryProvider)
            .deleteSyncAck(_allReplayableSyncAckTypes);
        await Store.delete(StoreKey.syncMigrationStatus);
        await container.read(syncStreamRepositoryProvider).reset();
        var syncSuccess = await container
            .read(syncStreamServiceProvider)
            .sync();
        expect(syncSuccess, isTrue);
        if (Store.tryGet(StoreKey.currentUser) == null) {
          await Store.put(StoreKey.currentUser, user!);
        }
        final runToken = DateTime.now()
            .toUtc()
            .microsecondsSinceEpoch
            .toString();
        final baseCreatedAt = DateTime.now().toUtc();
        for (var index = 0; index < 4; index++) {
          final assetId = await _uploadGeneratedJpegAsSecondClient(
            'immich-e2e-stack-046-$runToken-$index.jpg',
            baseCreatedAt.add(Duration(microseconds: index)),
            sourceMetadata: {
              'device_make': 'ImmichE2E',
              'device_model': 'Stack046',
              'width': 72 + index,
              'height': 72 + index,
            },
          );
          createdRemoteAssetIds.add(assetId);
        }

        for (final assetId in createdRemoteAssetIds) {
          await _waitForSuccessfulResponse(
            tester,
            () => assetsApi.viewAssetWithHttpInfo(
              assetId,
              size: api.AssetMediaSize.thumbnail,
            ),
            timeout: const Duration(minutes: 3),
          );
        }

        syncSuccess = await container.read(syncStreamServiceProvider).sync();
        expect(syncSuccess, isTrue);
        await pumpUntilFound(
          tester,
          find.byType(Timeline),
          timeout: const Duration(seconds: 60),
        );

        var timeline = container.read(timelineFactoryProvider).main([user!.id]);
        await _expectTimelineAssetSet(
          tester,
          timeline,
          includes: createdRemoteAssetIds.toSet(),
          excludes: const {},
          reason:
              'Expected all 046 stack fixture assets to start visible in the timeline',
        );
        for (final assetId in createdRemoteAssetIds) {
          await _waitForRemoteAssetState(
            tester,
            container,
            assetId,
            (asset) =>
                asset.isRemoteOnly &&
                asset.isImage &&
                asset.stackId == null &&
                !asset.isTrashed,
            reason:
                'Expected 046 asset $assetId to start unstacked and not deleted',
          );
        }

        await _selectTimelineAssetsById(
          tester,
          container,
          createdRemoteAssetIds,
        );
        expect(
          _bottomSheetIcon(GeneralBottomSheet, Icons.filter_none_rounded),
          findsOneWidget,
        );
        await _tapBottomSheetAction(
          tester,
          GeneralBottomSheet,
          Icons.filter_none_rounded,
        );
        await _waitForMultiSelectCount(
          tester,
          container,
          0,
          timeout: const Duration(seconds: 30),
        );

        final createdStack = await _waitForServerStackWithMembers(
          tester,
          stacksApi,
          createdRemoteAssetIds.toSet(),
          reason:
              'Expected server stack to contain exactly the 046 assets after UI stack creation',
        );
        stackId = createdStack.id;
        var primaryAssetId = createdStack.primaryAssetId;
        expect(createdRemoteAssetIds, contains(primaryAssetId));

        syncSuccess = await container.read(syncStreamServiceProvider).sync();
        expect(syncSuccess, isTrue);
        await _waitForLocalStackMembership(
          tester,
          container,
          stackId,
          expectedPrimaryAssetId: primaryAssetId,
          stackedAssetIds: createdRemoteAssetIds.toSet(),
          unstackedAssetIds: const {},
          reason: 'Expected local DB to record the newly created 046 stack',
        );
        await _expectTimelineAssetSet(
          tester,
          timeline,
          includes: {primaryAssetId},
          excludes: createdRemoteAssetIds
              .where((assetId) => assetId != primaryAssetId)
              .toSet(),
          reason:
              'Expected main timeline to collapse 046 stack members behind the primary asset',
        );

        final primaryAsset = await _waitForRemoteAssetState(
          tester,
          container,
          primaryAssetId,
          (asset) => asset.stackId == stackId,
          reason: 'Expected local 046 primary asset to carry the stack id',
        );
        await _openTimelineAsset(tester, primaryAsset);
        await _showViewerControls(tester, container);
        await _pumpUntilFoundWithReason(
          tester,
          find.byType(AssetStackRow),
          reason: 'Expected the viewer to show the 046 stack member strip',
          timeout: const Duration(seconds: 30),
        );
        final browsedStack = await container
            .read(assetServiceProvider)
            .getStack(primaryAsset);
        expect(
          browsedStack.map((asset) => asset.id).toSet(),
          createdRemoteAssetIds.toSet(),
        );
        expect(browsedStack.first.id, primaryAssetId);
        final browsedAsset = browsedStack.firstWhere(
          (asset) => asset.id != primaryAssetId,
        );
        final browsedTile = find.byKey(ValueKey(browsedAsset.heroTag));
        await pumpUntilFound(
          tester,
          browsedTile,
          timeout: const Duration(seconds: 30),
        );
        await tester.tap(browsedTile.hitTestable().first, warnIfMissed: false);
        await _pumpUntil(
          tester,
          () =>
              container.read(assetViewerProvider).currentAsset?.id ==
              browsedAsset.id,
          timeout: const Duration(seconds: 20),
        );

        final updatedStack = await stacksApi.updateStack(
          stackId,
          api.StackUpdateDto(
            primaryAssetId: api.Optional.present(browsedAsset.id),
          ),
        );
        expect(updatedStack, isNotNull);
        expect(updatedStack!.primaryAssetId, browsedAsset.id);
        primaryAssetId = browsedAsset.id;

        syncSuccess = await container.read(syncStreamServiceProvider).sync();
        expect(syncSuccess, isTrue);
        await _waitForLocalStackMembership(
          tester,
          container,
          stackId,
          expectedPrimaryAssetId: primaryAssetId,
          stackedAssetIds: createdRemoteAssetIds.toSet(),
          unstackedAssetIds: const {},
          reason:
              'Expected local 046 stack primary asset to update after server primary change',
        );

        await container.read(appRouterProvider).maybePop();
        await pumpUntilFound(
          tester,
          find.byType(MainTimelinePage),
          timeout: const Duration(seconds: 30),
        );
        await _expectTimelineAssetSet(
          tester,
          timeline,
          includes: {primaryAssetId},
          excludes: createdRemoteAssetIds
              .where((assetId) => assetId != primaryAssetId)
              .toSet(),
          reason:
              'Expected timeline to swap the 046 visible primary after primary update',
        );

        final removedAssetId = createdRemoteAssetIds.firstWhere(
          (assetId) => assetId != primaryAssetId,
        );
        await stacksApi.removeAssetFromStack(removedAssetId, stackId);
        final remainingStackAssetIds = createdRemoteAssetIds
            .where((assetId) => assetId != removedAssetId)
            .toSet();
        await _waitForServerStackWithMembers(
          tester,
          stacksApi,
          remainingStackAssetIds,
          expectedPrimaryAssetId: primaryAssetId,
          reason:
              'Expected server stack to drop the removed 046 member without deleting it',
        );
        syncSuccess = await container.read(syncStreamServiceProvider).sync();
        expect(syncSuccess, isTrue);
        await _waitForLocalStackMembership(
          tester,
          container,
          stackId,
          expectedPrimaryAssetId: primaryAssetId,
          stackedAssetIds: remainingStackAssetIds,
          unstackedAssetIds: {removedAssetId},
          reason:
              'Expected local 046 stack membership to match server after member removal',
        );
        await _waitForAssetInfoState(
          tester,
          assetsApi,
          removedAssetId,
          (asset) => !asset.isTrashed && asset.stack.orElse(null) == null,
          reason:
              'Expected removing a 046 stack member to keep the asset alive and unstacked on the server',
        );
        await _expectTimelineAssetSet(
          tester,
          timeline,
          includes: {primaryAssetId, removedAssetId},
          excludes: remainingStackAssetIds
              .where((assetId) => assetId != primaryAssetId)
              .toSet(),
          reason:
              'Expected removed 046 member to return to the timeline while the remaining stack stays collapsed',
        );

        await _selectTimelineAssetsById(tester, container, [primaryAssetId]);
        expect(
          _bottomSheetIcon(GeneralBottomSheet, Icons.layers_clear_outlined),
          findsOneWidget,
        );
        await _tapBottomSheetAction(
          tester,
          GeneralBottomSheet,
          Icons.layers_clear_outlined,
        );
        await _waitForMultiSelectCount(
          tester,
          container,
          0,
          timeout: const Duration(seconds: 30),
        );
        await _waitForServerStackGone(
          tester,
          stacksApi,
          stackId,
          reason: 'Expected server stack to be gone after UI unstack',
        );
        syncSuccess = await container.read(syncStreamServiceProvider).sync();
        expect(syncSuccess, isTrue);
        await _waitForLocalStackMembership(
          tester,
          container,
          stackId,
          expectedPrimaryAssetId: null,
          stackedAssetIds: const {},
          unstackedAssetIds: createdRemoteAssetIds.toSet(),
          reason:
              'Expected local 046 stack relationship to be fully cleared after unstack',
        );
        await _expectTimelineAssetSet(
          tester,
          timeline,
          includes: createdRemoteAssetIds.toSet(),
          excludes: const {},
          reason:
              'Expected all 046 assets to remain in the timeline after full unstack',
        );

        await timeline.dispose();
        await tester.pumpWidget(const SizedBox.shrink());
        await _pumpFor(tester, const Duration(milliseconds: 500));
        await _loadAppPreservingStore(
          tester,
          overrideCancellation: true,
          closeDriftOnDispose: false,
        );
        await _waitForAccessToken(tester);
        await _waitForCurrentUser(_email, tester);
        container = _containerOfApp(tester);
        apiService = container.read(apiServiceProvider);
        assetsApi = apiService.assetsApi;
        stacksApi = apiService.stacksApi;
        await _dismissFeatureMessageIfVisible(tester);

        syncSuccess = await container.read(syncStreamServiceProvider).sync();
        expect(syncSuccess, isTrue);
        timeline = container.read(timelineFactoryProvider).main([user.id]);
        await _waitForLocalStackMembership(
          tester,
          container,
          stackId,
          expectedPrimaryAssetId: null,
          stackedAssetIds: const {},
          unstackedAssetIds: createdRemoteAssetIds.toSet(),
          reason: 'Expected 046 unstacked state to persist after app restart',
        );
        await _expectTimelineAssetSet(
          tester,
          timeline,
          includes: createdRemoteAssetIds.toSet(),
          excludes: const {},
          reason: 'Expected all 046 assets to remain visible after restart',
        );
        await timeline.dispose();
      },
    );

    _realStackSessionTest(
      'MOB-UI-047-$_caseSuffix',
      'opens similar photos and handles no-result assets',
      (tester) async {
        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = const Size(430, 932);
        addTearDown(tester.view.reset);

        for (final entry in {
          'IMMICH_E2E_SIMILAR_TARGET_ASSET_ID': _similarTargetAssetId,
          'IMMICH_E2E_SIMILAR_CANDIDATE_ASSET_ID': _similarCandidateAssetId,
          'IMMICH_E2E_SIMILAR_CONTROL_ASSET_ID': _similarControlAssetId,
        }.entries) {
          expect(
            entry.value,
            isNotEmpty,
            reason:
                'Pass --dart-define=${entry.key}=... from the 047 fixture seed',
          );
        }
        final targetAssetId = _similarTargetAssetId.trim();
        final candidateAssetId = _similarCandidateAssetId.trim();
        final controlAssetId = _similarControlAssetId.trim();

        await _loadAuthenticatedApp(
          tester,
          overrideCancellation: true,
          closeDriftOnDispose: false,
        );
        final container = _containerOfApp(tester);
        final apiService = container.read(apiServiceProvider);
        final assetsApi = apiService.assetsApi;
        final searchApi = apiService.searchApi;
        final user = Store.tryGet(StoreKey.currentUser);
        expect(user, isNotNull);
        final fixtureIds = [targetAssetId, candidateAssetId, controlAssetId];

        addTearDown(() async {
          try {
            container.read(multiSelectProvider.notifier).reset();
          } catch (_) {
            // ProviderScope may already be disposed when an earlier expectation fails.
          }
          for (final assetId in fixtureIds) {
            await _deleteTestAssetBestEffort(assetsApi, assetId);
          }
        });

        await container
            .read(syncApiRepositoryProvider)
            .deleteSyncAck(_allReplayableSyncAckTypes);
        await Store.delete(StoreKey.syncMigrationStatus);
        await container.read(syncStreamRepositoryProvider).reset();
        var syncSuccess = await container
            .read(syncStreamServiceProvider)
            .sync();
        expect(syncSuccess, isTrue);

        for (final assetId in fixtureIds) {
          await _waitForSuccessfulResponse(
            tester,
            () => assetsApi.viewAssetWithHttpInfo(
              assetId,
              size: api.AssetMediaSize.thumbnail,
            ),
            timeout: const Duration(minutes: 3),
          );
        }

        syncSuccess = await container.read(syncStreamServiceProvider).sync();
        expect(syncSuccess, isTrue);
        await pumpUntilFound(
          tester,
          find.byType(Timeline),
          timeout: const Duration(seconds: 60),
        );

        final targetAsset = await _waitForRemoteAssetState(
          tester,
          container,
          targetAssetId,
          (asset) => asset.isRemoteOnly && asset.isImage && !asset.isTrashed,
          reason:
              'Expected 047 similar target asset to sync as a visible remote image',
        );
        await _waitForRemoteAssetState(
          tester,
          container,
          candidateAssetId,
          (asset) => asset.isRemoteOnly && asset.isImage && !asset.isTrashed,
          reason:
              'Expected 047 similar candidate asset to sync as a visible remote image',
        );
        final controlAsset = await _waitForRemoteAssetState(
          tester,
          container,
          controlAssetId,
          (asset) => asset.isRemoteOnly && asset.isImage && !asset.isTrashed,
          reason:
              'Expected 047 no-result control asset to sync as a visible remote image',
        );

        final similarDto = api.SmartSearchDto(
          queryAssetId: api.Optional.present(targetAssetId),
          visibility: const api.Optional.present(api.AssetVisibility.timeline),
          page: const api.Optional.present(1),
          size: const api.Optional.present(10),
        );
        final serverSimilar = await _waitForServerSmartSearchResponse(
          tester,
          searchApi,
          similarDto,
          (response) =>
              _serverSearchAssetIds(response).contains(candidateAssetId),
          reason:
              'Expected smart search queryAssetId to return the paired 047 candidate',
        );
        expect(
          _serverSearchAssetIds(serverSimilar),
          contains(candidateAssetId),
        );
        expect(
          _serverSearchAssetIds(serverSimilar),
          isNot(contains(targetAssetId)),
        );
        expect(
          _serverSearchAssetIds(serverSimilar),
          isNot(contains(controlAssetId)),
        );

        final serverEmpty = await _waitForServerSmartSearchResponse(
          tester,
          searchApi,
          api.SmartSearchDto(
            queryAssetId: api.Optional.present(controlAssetId),
            visibility: const api.Optional.present(
              api.AssetVisibility.timeline,
            ),
            page: const api.Optional.present(1),
            size: const api.Optional.present(10),
          ),
          (response) =>
              response.assets.total == 0 && response.assets.items.isEmpty,
          reason:
              'Expected smart search for the 047 control asset to return no results',
        );
        expect(_serverSearchAssetIds(serverEmpty), isEmpty);

        final serviceIds = await _waitForSearchServiceAssetIds(
          tester,
          container.read(searchServiceProvider),
          _searchFilter().copyWith(assetId: targetAssetId),
          (ids) =>
              ids.contains(candidateAssetId) &&
              !ids.contains(targetAssetId) &&
              !ids.contains(controlAssetId),
          reason:
              'Expected app search service to mirror server similar-photo candidates',
        );
        expect(serviceIds, contains(candidateAssetId));

        await _openTimelineAsset(tester, targetAsset);
        await _showViewerControls(tester, container);
        await _tapViewerMenuAction(tester, Icons.compare);
        await pumpUntilFound(
          tester,
          find.byType(DriftSearchPage),
          timeout: const Duration(seconds: 30),
        );
        await _waitForPaginatedSearchAssetIds(
          tester,
          container,
          (ids) =>
              ids.contains(candidateAssetId) &&
              !ids.contains(targetAssetId) &&
              !ids.contains(controlAssetId),
          reason:
              'Expected viewer similar-photo action to show only the paired candidate',
        );
        await pumpUntilFound(
          tester,
          _timelineAssetTileForAssetId(candidateAssetId),
          timeout: const Duration(seconds: 30),
        );
        expect(_timelineAssetTileForAssetId(targetAssetId), findsNothing);
        expect(_timelineAssetTileForAssetId(controlAssetId), findsNothing);

        final searchTimelineContainer = ProviderScope.containerOf(
          tester.element(find.byType(Timeline).last),
          listen: false,
        );
        await _selectTimelineAssetsById(tester, searchTimelineContainer, [
          candidateAssetId,
        ]);
        expect(
          _bottomSheetIcon(GeneralBottomSheet, Icons.delete_outline),
          findsOneWidget,
        );
        await _tapBottomSheetAction(
          tester,
          GeneralBottomSheet,
          Icons.delete_outline,
        );
        await _waitForMultiSelectCount(
          tester,
          searchTimelineContainer,
          0,
          timeout: const Duration(seconds: 30),
        );
        await _waitForAssetInfoState(
          tester,
          assetsApi,
          candidateAssetId,
          (asset) => asset.isTrashed,
          reason:
              'Expected processing the non-kept 047 candidate to move it to trash',
        );

        final timelineFactory = container.read(timelineFactoryProvider);
        final mainTimeline = timelineFactory.main([user!.id]);
        final trashTimeline = timelineFactory.trash(user.id);
        addTearDown(mainTimeline.dispose);
        addTearDown(trashTimeline.dispose);
        await _expectTimelineAssetSet(
          tester,
          mainTimeline,
          includes: {targetAssetId, controlAssetId},
          excludes: {candidateAssetId},
          reason:
              'Expected kept/control 047 assets to remain in timeline after processing the candidate',
        );
        await _expectTimelineAssetSet(
          tester,
          trashTimeline,
          includes: {candidateAssetId},
          excludes: {targetAssetId, controlAssetId},
          reason: 'Expected processed 047 candidate to appear in trash',
        );

        final router = container.read(appRouterProvider);
        for (
          var attempt = 0;
          attempt < 3 && !tester.any(find.byType(MainTimelinePage));
          attempt++
        ) {
          await router.maybePop();
          await _pumpFor(tester, const Duration(milliseconds: 500));
        }
        await pumpUntilFound(
          tester,
          find.byType(MainTimelinePage),
          timeout: const Duration(seconds: 30),
        );
        await _openTimelineAsset(tester, controlAsset);
        await _showViewerControls(tester, container);
        await _tapViewerMenuAction(tester, Icons.compare);
        await pumpUntilFound(
          tester,
          find.byType(DriftSearchPage),
          timeout: const Duration(seconds: 30),
        );
        final emptyUiIds = await _waitForPaginatedSearchAssetIds(
          tester,
          container,
          (ids) => ids.isEmpty,
          reason:
              'Expected no-result 047 control asset to render an empty similar-photo search',
        );
        expect(emptyUiIds, isEmpty);
        await pumpUntilFound(
          tester,
          find.text('search_no_result'.tr()),
          timeout: const Duration(seconds: 30),
        );
      },
    );

    _realStackSessionTest(
      'MOB-UI-048-$_caseSuffix',
      'guards locked folder with PIN biometric and background relock',
      (tester) async {
        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = const Size(430, 932);
        addTearDown(tester.view.reset);

        final scriptedBiometrics = _ScriptedBiometricRepository([false, true]);
        await _loadAuthenticatedApp(
          tester,
          overrideCancellation: true,
          closeDriftOnDispose: false,
          extraOverrides: [
            biometricRepositoryProvider.overrideWithValue(scriptedBiometrics),
          ],
        );
        final container = _containerOfApp(tester);
        final apiService = container.read(apiServiceProvider);
        final assetsApi = apiService.assetsApi;
        final authApi = apiService.authenticationApi;
        final authRepository = container.read(authApiRepositoryProvider);
        final secureStorage = container.read(secureStorageServiceProvider);
        final router = container.read(appRouterProvider);
        final createdRemoteAssetIds = <String>[];
        final user = Store.tryGet(StoreKey.currentUser);
        expect(user, isNotNull);

        addTearDown(() async {
          try {
            container.read(multiSelectProvider.notifier).reset();
            await secureStorage.delete(kSecuredPinCode);
          } catch (_) {
            // ProviderScope may already be disposed when an earlier expectation fails.
          }
          for (final assetId in createdRemoteAssetIds) {
            try {
              await assetsApi.updateAssets(
                api.AssetBulkUpdateDto(
                  ids: [assetId],
                  visibility: const api.Optional.present(
                    api.AssetVisibility.timeline,
                  ),
                ),
              );
            } catch (_) {
              // The asset may already be gone or the API may be unavailable during cleanup.
            }
            await _deleteTestAssetBestEffort(assetsApi, assetId);
          }
        });

        await secureStorage.delete(kSecuredPinCode);
        await container
            .read(syncApiRepositoryProvider)
            .deleteSyncAck(_allReplayableSyncAckTypes);
        await Store.delete(StoreKey.syncMigrationStatus);
        await container.read(syncStreamRepositoryProvider).reset();
        var syncSuccess = await container
            .read(syncStreamServiceProvider)
            .sync();
        expect(syncSuccess, isTrue);

        await authRepository.setupPinCode(_lockedFolderPin);
        await _waitForAuthStatus(
          tester,
          authApi,
          (status) => status.pinCode && status.password && status.isElevated,
          reason:
              'Expected PIN setup to enable locked-folder protection and keep the current session elevated',
        );

        await authRepository.lockPinCode();
        expect(
          await authRepository.unlockPinCode(_lockedFolderWrongPin),
          isFalse,
        );
        await _waitForAuthStatus(
          tester,
          authApi,
          (status) => status.pinCode && !status.isElevated,
          reason: 'A wrong PIN must not unlock the current session',
        );
        expect(await authRepository.unlockPinCode(_lockedFolderPin), isTrue);
        await _waitForAuthStatus(
          tester,
          authApi,
          (status) => status.pinCode && status.isElevated,
          reason: 'The correct PIN should unlock the current session',
        );

        final runToken = DateTime.now()
            .toUtc()
            .microsecondsSinceEpoch
            .toString();
        final assetId = await _uploadGeneratedJpegAsSecondClient(
          'immich-e2e-locked-folder-048-$runToken.jpg',
          DateTime.now().toUtc(),
        );
        createdRemoteAssetIds.add(assetId);

        await _waitForSuccessfulResponse(
          tester,
          () => assetsApi.viewAssetWithHttpInfo(
            assetId,
            size: api.AssetMediaSize.thumbnail,
          ),
          timeout: const Duration(minutes: 3),
        );

        syncSuccess = await container.read(syncStreamServiceProvider).sync();
        expect(syncSuccess, isTrue);
        await pumpUntilFound(
          tester,
          find.byType(Timeline),
          timeout: const Duration(seconds: 60),
        );

        final timelineFactory = container.read(timelineFactoryProvider);
        final mainTimeline = timelineFactory.main([user!.id]);
        final lockedTimeline = timelineFactory.lockedFolder(user.id);
        addTearDown(mainTimeline.dispose);
        addTearDown(lockedTimeline.dispose);

        await _waitForRemoteAssetState(
          tester,
          container,
          assetId,
          (asset) =>
              asset.visibility == AssetVisibility.timeline && !asset.isTrashed,
          reason:
              'Expected 048 fixture asset to start as a visible timeline asset',
        );
        await _expectTimelineAssetSet(
          tester,
          mainTimeline,
          includes: {assetId},
          excludes: const {},
          reason: 'Main timeline should include the 048 fixture before locking',
        );
        await _expectTimelineAssetSet(
          tester,
          lockedTimeline,
          includes: const {},
          excludes: {assetId},
          reason:
              'Locked folder timeline should start empty for the 048 fixture',
        );

        await _selectTimelineAssetsById(tester, container, [assetId]);
        expect(
          _bottomSheetIcon(GeneralBottomSheet, Icons.lock_rounded),
          findsOneWidget,
        );
        await _tapBottomSheetAction(
          tester,
          GeneralBottomSheet,
          Icons.lock_rounded,
        );
        await _waitForMultiSelectCount(
          tester,
          container,
          0,
          timeout: const Duration(seconds: 30),
        );
        await _waitForAssetInfoState(
          tester,
          assetsApi,
          assetId,
          (asset) =>
              asset.visibility == api.AssetVisibility.locked &&
              !asset.isTrashed,
          reason:
              'Expected the UI lock action to move the 048 asset to locked visibility on the server',
        );
        await _waitForRemoteAssetState(
          tester,
          container,
          assetId,
          (asset) =>
              asset.visibility == AssetVisibility.locked && !asset.isTrashed,
          reason:
              'Expected the UI lock action to update the local 048 asset visibility',
        );
        await _expectTimelineAssetSet(
          tester,
          mainTimeline,
          includes: const {},
          excludes: {assetId},
          reason: 'Main timeline should not leak the locked 048 asset',
        );
        await _expectTimelineAssetSet(
          tester,
          lockedTimeline,
          includes: {assetId},
          excludes: const {},
          reason: 'Locked folder timeline should contain the locked 048 asset',
        );

        unawaited(router.push(const DriftLockedFolderRoute()));
        await pumpUntilFound(
          tester,
          find.byType(DriftLockedFolderPage),
          timeout: const Duration(seconds: 30),
        );
        await pumpUntilFound(
          tester,
          _timelineAssetTileForAssetId(assetId),
          timeout: const Duration(seconds: 30),
        );

        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        await _pumpFor(tester, const Duration(milliseconds: 500));
        expect(
          _timelineAssetTileForAssetId(assetId),
          findsNothing,
          reason:
              'Locked folder should hide sensitive content while the app is inactive',
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await pumpUntilFound(
          tester,
          _timelineAssetTileForAssetId(assetId),
          timeout: const Duration(seconds: 30),
        );

        final lockedFolderLifecycle =
            tester.state(find.byType(DriftLockedFolderPage))
                as WidgetsBindingObserver;
        lockedFolderLifecycle.didChangeAppLifecycleState(
          AppLifecycleState.paused,
        );
        await _pumpFor(tester, const Duration(milliseconds: 500));
        await _waitForAuthStatus(
          tester,
          authApi,
          (status) => status.pinCode && !status.isElevated,
          reason:
              'Backgrounding from the locked folder should relock the current session',
        );
        await _pumpUntil(
          tester,
          () => find.byType(DriftLockedFolderPage).evaluate().isEmpty,
          timeout: const Duration(seconds: 30),
        );

        unawaited(router.push(const DriftLockedFolderRoute()));
        await pumpUntilFound(
          tester,
          find.byType(PinAuthPage),
          timeout: const Duration(seconds: 30),
        );
        expect(find.byType(DriftLockedFolderPage), findsNothing);
        await pumpUntilFound(
          tester,
          find.text('use_biometric'.tr()),
          timeout: const Duration(seconds: 30),
        );

        await router.replaceAll([
          const TabShellRoute(children: [MainTimelineRoute()]),
        ]);
        await pumpUntilFound(
          tester,
          find.byType(MainTimelinePage),
          timeout: const Duration(seconds: 30),
        );
        await secureStorage.write(kSecuredPinCode, _lockedFolderPin);

        unawaited(router.push(const DriftLockedFolderRoute()));
        await _pumpFor(tester, const Duration(seconds: 1));
        expect(
          find.byType(DriftLockedFolderPage),
          findsNothing,
          reason: 'A failed biometric check must not open locked assets',
        );
        await _waitForAuthStatus(
          tester,
          authApi,
          (status) => status.pinCode && !status.isElevated,
          reason: 'A failed biometric check must leave the session locked',
        );

        unawaited(router.push(const DriftLockedFolderRoute()));
        await pumpUntilFound(
          tester,
          find.byType(DriftLockedFolderPage),
          timeout: const Duration(seconds: 30),
        );
        await _waitForAuthStatus(
          tester,
          authApi,
          (status) => status.pinCode && status.isElevated,
          reason:
              'A successful biometric check should unlock the session using the saved PIN',
        );
        await pumpUntilFound(
          tester,
          _timelineAssetTileForAssetId(assetId),
          timeout: const Duration(seconds: 30),
        );

        final lockedContainer = ProviderScope.containerOf(
          tester.element(find.byType(Timeline).last),
          listen: false,
        );
        await _selectTimelineAssetsById(tester, lockedContainer, [assetId]);
        expect(
          _bottomSheetIcon(LockedFolderBottomSheet, Icons.lock_open_rounded),
          findsOneWidget,
        );
        await _tapBottomSheetAction(
          tester,
          LockedFolderBottomSheet,
          Icons.lock_open_rounded,
        );
        await _waitForMultiSelectCount(
          tester,
          lockedContainer,
          0,
          timeout: const Duration(seconds: 30),
        );
        await _waitForAssetInfoState(
          tester,
          assetsApi,
          assetId,
          (asset) =>
              asset.visibility == api.AssetVisibility.timeline &&
              !asset.isTrashed,
          reason:
              'Expected removing the 048 asset from locked folder to restore server timeline visibility',
        );
        await _waitForRemoteAssetState(
          tester,
          container,
          assetId,
          (asset) =>
              asset.visibility == AssetVisibility.timeline && !asset.isTrashed,
          reason:
              'Expected removing the 048 asset from locked folder to restore local timeline visibility',
        );
        await _expectTimelineAssetSet(
          tester,
          mainTimeline,
          includes: {assetId},
          excludes: const {},
          reason:
              'Main timeline should include the 048 asset after removing it from locked folder',
        );
        await _expectTimelineAssetSet(
          tester,
          lockedTimeline,
          includes: const {},
          excludes: {assetId},
          reason:
              'Locked folder timeline should exclude the 048 asset after move out',
        );
      },
    );

    _realStackSessionTest(
      'MOB-UI-049-$_caseSuffix',
      'restores and empties trash with dangerous confirmations',
      (tester) async {
        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = const Size(430, 932);
        addTearDown(tester.view.reset);

        await _loadAuthenticatedApp(
          tester,
          overrideCancellation: true,
          closeDriftOnDispose: false,
        );
        final container = _containerOfApp(tester);
        final drift = container.read(driftProvider);
        final apiService = container.read(apiServiceProvider);
        final assetsApi = apiService.assetsApi;
        final albumsApi = apiService.albumsApi;
        final assetService = container.read(assetServiceProvider);
        final router = container.read(appRouterProvider);
        final createdRemoteAssetIds = <String>[];
        final user = Store.tryGet(StoreKey.currentUser);
        expect(user, isNotNull);
        String? albumId;

        addTearDown(() async {
          final id = albumId;
          if (id != null) {
            await _deleteAlbumBestEffort(albumsApi, id);
          }
          for (final assetId in createdRemoteAssetIds) {
            await _deleteTestAssetBestEffort(assetsApi, assetId);
          }
        });

        await container
            .read(syncApiRepositoryProvider)
            .deleteSyncAck(_allReplayableSyncAckTypes);
        await Store.delete(StoreKey.syncMigrationStatus);
        await container.read(syncStreamRepositoryProvider).reset();
        final baselineSyncSuccess = await container
            .read(syncStreamServiceProvider)
            .sync();
        expect(baselineSyncSuccess, isTrue);
        if (Store.tryGet(StoreKey.currentUser) == null) {
          await Store.put(StoreKey.currentUser, user!);
        }

        final timelineFactory = container.read(timelineFactoryProvider);

        final runToken = DateTime.now()
            .toUtc()
            .microsecondsSinceEpoch
            .toString();
        final baseCreatedAt = DateTime.utc(
          2026,
          2,
          18,
          12,
        ).add(Duration(microseconds: int.parse(runToken) % 1000));
        final partialRestoreId = await _uploadGeneratedJpegAsSecondClient(
          'immich-e2e-trash-ui-049-partial-$runToken.jpg',
          baseCreatedAt,
        );
        createdRemoteAssetIds.add(partialRestoreId);
        final restoreAllId = await _uploadGeneratedMp4AsSecondClient(
          'immich-e2e-trash-ui-049-video-$runToken.mp4',
          baseCreatedAt.add(const Duration(minutes: 1)),
        );
        createdRemoteAssetIds.add(restoreAllId);
        final albumRestoreId = await _uploadGeneratedJpegAsSecondClient(
          'immich-e2e-trash-ui-049-album-$runToken.jpg',
          baseCreatedAt.add(const Duration(minutes: 2)),
        );
        createdRemoteAssetIds.add(albumRestoreId);
        final emptyCancelId = await _uploadGeneratedJpegAsSecondClient(
          'immich-e2e-trash-ui-049-empty-cancel-$runToken.jpg',
          baseCreatedAt.add(const Duration(minutes: 3)),
        );
        createdRemoteAssetIds.add(emptyCancelId);
        final emptyConfirmId = await _uploadGeneratedJpegAsSecondClient(
          'immich-e2e-trash-ui-049-empty-confirm-$runToken.jpg',
          baseCreatedAt.add(const Duration(minutes: 4)),
        );
        createdRemoteAssetIds.add(emptyConfirmId);

        final createdAlbum = await albumsApi.createAlbum(
          api.CreateAlbumDto(
            albumName: 'immich-e2e-trash-ui-049-$runToken',
            assetIds: api.Optional.present([albumRestoreId]),
          ),
        );
        expect(createdAlbum, isNotNull);
        albumId = createdAlbum!.id;

        final uploadSyncSuccess = await container
            .read(syncStreamServiceProvider)
            .sync();
        expect(uploadSyncSuccess, isTrue);
        for (final assetId in createdRemoteAssetIds) {
          await _waitForRemoteAssetState(
            tester,
            container,
            assetId,
            (asset) =>
                asset.visibility == AssetVisibility.timeline &&
                !asset.isTrashed,
            reason:
                'Expected 049 fixture asset $assetId to sync before trashing',
          );
        }
        await _waitForRemoteAlbumAssetIds(
          tester,
          container,
          albumId,
          includes: {albumRestoreId},
          excludes: const {},
          reason: 'Expected 049 album-source asset membership before trash',
        );

        final trashTimeline = timelineFactory.trash(user!.id);
        addTearDown(trashTimeline.dispose);

        await assetService.trash(createdRemoteAssetIds);
        for (final assetId in createdRemoteAssetIds) {
          await _waitForAssetInfoState(
            tester,
            assetsApi,
            assetId,
            (asset) => asset.isTrashed,
            reason: 'Expected 049 fixture asset $assetId to be in server trash',
          );
          await _waitForRemoteAssetState(
            tester,
            container,
            assetId,
            (asset) => asset.isTrashed,
            reason: 'Expected 049 fixture asset $assetId to be in local trash',
          );
        }

        unawaited(router.push(const DriftTrashRoute()));
        await pumpUntilFound(
          tester,
          find.byType(DriftTrashPage),
          timeout: const Duration(seconds: 30),
        );
        final trashContainer = ProviderScope.containerOf(
          tester.element(find.byType(Timeline).last),
          listen: false,
        );
        await _expectTimelineAssetSet(
          tester,
          trashTimeline,
          includes: createdRemoteAssetIds.toSet(),
          excludes: const {},
          reason: 'Trash page should show all 049 prepared assets',
        );

        await _selectTimelineAssetsById(tester, trashContainer, [
          partialRestoreId,
          restoreAllId,
        ]);
        expect(
          _bottomSheetIcon(TrashBottomBar, Icons.history_rounded),
          findsOneWidget,
        );
        await _tapBottomSheetAction(
          tester,
          TrashBottomBar,
          Icons.history_rounded,
        );
        await _waitForMultiSelectCount(
          tester,
          trashContainer,
          0,
          timeout: const Duration(seconds: 30),
        );
        await _expectTimelineAssetSet(
          tester,
          trashTimeline,
          includes: {albumRestoreId, emptyCancelId, emptyConfirmId},
          excludes: {partialRestoreId, restoreAllId},
          reason:
              'Partial restore should immediately remove only the selected 049 assets from trash',
        );
        for (final assetId in [partialRestoreId, restoreAllId]) {
          await _waitForAssetInfoState(
            tester,
            assetsApi,
            assetId,
            (asset) => !asset.isTrashed,
            reason:
                'Expected partial restore asset $assetId to be active on the server',
          );
        }

        await _tapTrashMenuAction(tester, 'restore_all');
        await _tapConfirmDialogButton(tester, confirm: true);
        await _expectTimelineAssetSet(
          tester,
          trashTimeline,
          includes: const {},
          excludes: {albumRestoreId, emptyCancelId, emptyConfirmId},
          reason:
              'Restore all should empty the 049 trash candidates from the trash timeline',
        );
        for (final assetId in [albumRestoreId, emptyCancelId, emptyConfirmId]) {
          await _waitForAssetInfoState(
            tester,
            assetsApi,
            assetId,
            (asset) => !asset.isTrashed,
            reason:
                'Expected restore all asset $assetId to be active on the server',
          );
        }
        await _waitForRemoteAlbumAssetIds(
          tester,
          container,
          albumId,
          includes: {albumRestoreId},
          excludes: const {},
          reason:
              'Restore all should preserve the 049 album-source asset membership',
        );

        await assetService.trash([emptyCancelId, emptyConfirmId]);
        await _expectTimelineAssetSet(
          tester,
          trashTimeline,
          includes: {emptyCancelId, emptyConfirmId},
          excludes: const {},
          reason: 'Re-trash should expose 049 empty-trash candidates',
        );

        await _tapTrashMenuAction(tester, 'empty_trash');
        await _tapConfirmDialogButton(tester, confirm: false);
        await _expectTimelineAssetSet(
          tester,
          trashTimeline,
          includes: {emptyCancelId, emptyConfirmId},
          excludes: const {},
          reason: 'Cancelling empty trash must leave 049 candidates in trash',
        );
        for (final assetId in [emptyCancelId, emptyConfirmId]) {
          await _waitForAssetInfoState(
            tester,
            assetsApi,
            assetId,
            (asset) => asset.isTrashed,
            reason:
                'Cancelling empty trash must not change server trash state for $assetId',
          );
        }

        await _tapTrashMenuAction(tester, 'empty_trash');
        await _tapConfirmDialogButton(tester, confirm: true);
        for (final assetId in [emptyCancelId, emptyConfirmId]) {
          await _waitForAssetInfoUnavailable(
            tester,
            assetsApi,
            assetId,
            reason:
                'Confirmed empty trash should permanently delete 049 asset $assetId',
          );
          await _waitForRemoteAssetDeleted(
            tester,
            container,
            assetId,
            reason:
                'Confirmed empty trash should remove local 049 asset row $assetId',
          );
          expect(await _remoteAssetRowCountById(drift, assetId), 0);
        }
        await _expectTimelineAssetSet(
          tester,
          trashTimeline,
          includes: const {},
          excludes: {emptyCancelId, emptyConfirmId},
          reason:
              'Trash timeline should no longer list 049 assets after confirmed empty trash',
        );
      },
    );

    _realStackSessionTest(
      'MOB-UI-050-$_caseSuffix',
      'opens library shortcut collections with isolated populated and empty states',
      (tester) async {
        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = const Size(430, 932);
        addTearDown(tester.view.reset);

        await _loadAuthenticatedApp(
          tester,
          overrideCancellation: true,
          closeDriftOnDispose: false,
        );
        final container = _containerOfApp(tester);
        final assetsApi = container.read(apiServiceProvider).assetsApi;
        final router = container.read(appRouterProvider);
        final createdRemoteAssetIds = <String>[];
        final user = Store.tryGet(StoreKey.currentUser);
        expect(user, isNotNull);

        addTearDown(() async {
          for (final assetId in createdRemoteAssetIds) {
            await _deleteTestAssetBestEffort(assetsApi, assetId);
          }
        });

        await container
            .read(syncApiRepositoryProvider)
            .deleteSyncAck(_allReplayableSyncAckTypes);
        await Store.delete(StoreKey.syncMigrationStatus);
        await container.read(syncStreamRepositoryProvider).reset();
        final baselineSyncSuccess = await container
            .read(syncStreamServiceProvider)
            .sync();
        expect(baselineSyncSuccess, isTrue);
        if (Store.tryGet(StoreKey.currentUser) == null) {
          await Store.put(StoreKey.currentUser, user!);
        }

        final runToken = DateTime.now()
            .toUtc()
            .microsecondsSinceEpoch
            .toString();
        final baseCreatedAt = DateTime.now().toUtc().add(
          const Duration(days: 3650),
        );
        final olderTimelineId = await _uploadGeneratedJpegAsSecondClient(
          'immich-e2e-library-shortcuts-050-older-$runToken.jpg',
          baseCreatedAt,
        );
        createdRemoteAssetIds.add(olderTimelineId);
        final favoriteId = await _uploadGeneratedJpegAsSecondClient(
          'immich-e2e-library-shortcuts-050-favorite-$runToken.jpg',
          baseCreatedAt.add(const Duration(minutes: 1)),
          isFavorite: true,
        );
        createdRemoteAssetIds.add(favoriteId);
        final archiveId = await _uploadGeneratedJpegAsSecondClient(
          'immich-e2e-library-shortcuts-050-archive-$runToken.jpg',
          baseCreatedAt.add(const Duration(minutes: 2)),
          visibility: api.AssetVisibility.archive,
        );
        createdRemoteAssetIds.add(archiveId);
        final videoId = await _uploadGeneratedMp4AsSecondClient(
          'immich-e2e-library-shortcuts-050-video-$runToken.mp4',
          baseCreatedAt.add(const Duration(minutes: 3)),
        );
        createdRemoteAssetIds.add(videoId);
        final newestTimelineId = await _uploadGeneratedJpegAsSecondClient(
          'immich-e2e-library-shortcuts-050-newest-$runToken.jpg',
          baseCreatedAt.add(const Duration(minutes: 4)),
        );
        createdRemoteAssetIds.add(newestTimelineId);

        final uploadSyncSuccess = await container
            .read(syncStreamServiceProvider)
            .sync();
        expect(uploadSyncSuccess, isTrue);
        await _waitForRemoteAssetState(
          tester,
          container,
          olderTimelineId,
          (asset) =>
              asset.visibility == AssetVisibility.timeline &&
              !asset.isFavorite &&
              !asset.isTrashed,
          reason:
              'Expected the 050 older control asset to sync as a normal timeline asset',
        );
        await _waitForRemoteAssetState(
          tester,
          container,
          favoriteId,
          (asset) =>
              asset.visibility == AssetVisibility.timeline &&
              asset.isFavorite &&
              !asset.isTrashed,
          reason:
              'Expected the 050 favorite fixture to sync as a favorite timeline asset',
        );
        await _waitForRemoteAssetState(
          tester,
          container,
          archiveId,
          (asset) =>
              asset.visibility == AssetVisibility.archive && !asset.isTrashed,
          reason:
              'Expected the 050 archive fixture to sync as an archived asset',
        );
        await _waitForRemoteAssetState(
          tester,
          container,
          videoId,
          (asset) =>
              asset.visibility == AssetVisibility.timeline &&
              asset.isVideo &&
              !asset.isTrashed,
          reason:
              'Expected the 050 video fixture to sync as a video timeline asset',
        );
        await _waitForRemoteAssetState(
          tester,
          container,
          newestTimelineId,
          (asset) =>
              asset.visibility == AssetVisibility.timeline &&
              !asset.isFavorite &&
              !asset.isTrashed,
          reason:
              'Expected the 050 newest control asset to sync as a normal timeline asset',
        );

        final timelineFactory = container.read(timelineFactoryProvider);
        final mainTimeline = timelineFactory.main([user!.id]);
        final favoriteTimeline = timelineFactory.favorite(user.id);
        final archiveTimeline = timelineFactory.archive(user.id);
        final videoTimeline = timelineFactory.video(user.id);
        final recentlyAddedTimeline = timelineFactory.recentlyAdded(user.id);
        final recentlyTakenTimeline = timelineFactory.remoteAssets(user.id);
        final emptyTimeline = timelineFactory.fromAssets(
          const <BaseAsset>[],
          TimelineOrigin.favorite,
        );
        addTearDown(mainTimeline.dispose);
        addTearDown(favoriteTimeline.dispose);
        addTearDown(archiveTimeline.dispose);
        addTearDown(videoTimeline.dispose);
        addTearDown(recentlyAddedTimeline.dispose);
        addTearDown(recentlyTakenTimeline.dispose);
        addTearDown(emptyTimeline.dispose);

        await _expectTimelineAssetSet(
          tester,
          mainTimeline,
          includes: {olderTimelineId, favoriteId, videoId, newestTimelineId},
          excludes: {archiveId},
          reason:
              'Main timeline should include only unarchived 050 shortcut assets',
        );
        final favoriteAssets = await _expectTimelineAssetSet(
          tester,
          favoriteTimeline,
          includes: {favoriteId},
          excludes: {olderTimelineId, archiveId, videoId, newestTimelineId},
          reason:
              'Favorite shortcut should include only the favorited 050 asset',
        );
        final archiveAssets = await _expectTimelineAssetSet(
          tester,
          archiveTimeline,
          includes: {archiveId},
          excludes: {olderTimelineId, favoriteId, videoId, newestTimelineId},
          reason: 'Archive shortcut should include only the archived 050 asset',
        );
        final videoAssets = await _expectTimelineAssetSet(
          tester,
          videoTimeline,
          includes: {videoId},
          excludes: {olderTimelineId, favoriteId, archiveId, newestTimelineId},
          reason: 'Video shortcut should include only the 050 video asset',
        );
        await _expectTimelineAssetSet(
          tester,
          recentlyAddedTimeline,
          includes: {
            olderTimelineId,
            favoriteId,
            archiveId,
            videoId,
            newestTimelineId,
          },
          excludes: const {},
          reason:
              'Recently added shortcut should include every non-trashed 050 fixture',
        );
        final recentlyTakenAssets = await _expectTimelineAssetSet(
          tester,
          recentlyTakenTimeline,
          includes: {olderTimelineId, favoriteId, videoId, newestTimelineId},
          excludes: {archiveId},
          reason:
              'Recently taken shortcut should include visible 050 assets and exclude archived assets',
        );
        _expectTimelineOrder(
          recentlyTakenAssets,
          [newestTimelineId, videoId, favoriteId, olderTimelineId],
          reason:
              'Recently taken shortcut should sort 050 assets by captured time descending',
        );
        await _expectTimelineAssetSet(
          tester,
          emptyTimeline,
          includes: const {},
          excludes: createdRemoteAssetIds.toSet(),
          reason: 'Empty shortcut timeline should expose no 050 fixture assets',
        );
        expect(
          emptyTimeline.totalAssets,
          0,
          reason: 'Empty shortcut state should have no assets',
        );

        final favoriteAsset = favoriteAssets.singleWhere(
          (asset) => _timelineAssetId(asset) == favoriteId,
        );
        final archiveAsset = archiveAssets.singleWhere(
          (asset) => _timelineAssetId(asset) == archiveId,
        );
        final videoAsset = videoAssets.singleWhere(
          (asset) => _timelineAssetId(asset) == videoId,
        );
        final recentlyTakenAsset = recentlyTakenAssets.singleWhere(
          (asset) => _timelineAssetId(asset) == newestTimelineId,
        );

        await _selectPrimaryNavigationTab(tester, kLibraryTabIndex);
        await pumpUntilFound(
          tester,
          find.byType(DriftLibraryPage),
          timeout: const Duration(seconds: 30),
        );
        await _openShortcutEntryAndReturn(
          tester,
          sourcePage: DriftLibraryPage,
          label: 'favorites'.tr(),
          targetPage: DriftFavoritePage,
          title: 'favorites'.tr(),
          assetToOpen: favoriteAsset,
        );
        await _openShortcutEntryAndReturn(
          tester,
          sourcePage: DriftLibraryPage,
          label: 'archived'.tr(),
          targetPage: DriftArchivePage,
          title: 'archive'.tr(),
          assetToOpen: archiveAsset,
        );

        await _selectPrimaryNavigationTab(tester, kSearchTabIndex);
        await pumpUntilFound(
          tester,
          find.byType(DriftSearchPage),
          timeout: const Duration(seconds: 30),
        );
        await _openShortcutEntryAndReturn(
          tester,
          sourcePage: DriftSearchPage,
          label: 'videos'.tr(),
          targetPage: DriftVideoPage,
          title: 'videos'.tr(),
          assetToOpen: videoAsset,
        );
        await _openShortcutEntryAndReturn(
          tester,
          sourcePage: DriftSearchPage,
          label: 'recently_added'.tr(),
          targetPage: DriftRecentlyAddedPage,
          title: 'recently_added'.tr(),
        );
        await _openShortcutEntryAndReturn(
          tester,
          sourcePage: DriftSearchPage,
          label: 'recently_taken'.tr(),
          targetPage: DriftRecentlyTakenPage,
          title: 'recently_taken'.tr(),
          assetToOpen: recentlyTakenAsset,
        );

        expect(
          router.currentSegments.map((route) => route.name),
          isNot(contains(DriftFavoriteRoute.name)),
        );
        expect(
          router.currentSegments.map((route) => route.name),
          isNot(contains(DriftArchiveRoute.name)),
        );
        expect(
          router.currentSegments.map((route) => route.name),
          isNot(contains(DriftVideoRoute.name)),
        );
        expect(
          router.currentSegments.map((route) => route.name),
          isNot(contains(DriftRecentlyAddedRoute.name)),
        );
        expect(
          router.currentSegments.map((route) => route.name),
          isNot(contains(DriftRecentlyTakenRoute.name)),
        );
      },
    );

    _realStackSessionTest(
      'MOB-UI-051-$_caseSuffix',
      'browses local albums, server folders, and local timeline',
      (tester) async {
        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = const Size(430, 932);
        addTearDown(tester.view.reset);

        await _loadAuthenticatedApp(
          tester,
          overrideCancellation: true,
          closeDriftOnDispose: false,
        );
        final container = _containerOfApp(tester);
        final apiService = container.read(apiServiceProvider);
        final router = container.read(appRouterProvider);
        final createdLocalAssetIds = <String>{};
        final createdRemoteAssetIds = <String>[];

        addTearDown(() async {
          await _deleteLocalTestAssetsBestEffort(createdLocalAssetIds);
          for (final assetId in createdRemoteAssetIds) {
            await _deleteTestAssetBestEffort(apiService.assetsApi, assetId);
          }
        });

        final runToken = DateTime.now()
            .toUtc()
            .microsecondsSinceEpoch
            .toString();
        final shortToken = runToken.substring(runToken.length - 8);
        final cameraAlbumName = 'ImmichE2E051Camera$shortToken';
        final nestedAlbumName = 'ImmichE2E051Nested$shortToken';
        final sameAlbumName = 'ImmichE2E051Same$shortToken';
        final emptyAlbumName = 'ImmichE2E051Empty$shortToken';
        final inaccessibleAlbumName = 'ImmichE2E051Private$shortToken';
        final cameraAssetName = 'immich-e2e-local-051-camera-$shortToken.jpg';
        final nestedAssetName = 'immich-e2e-local-051-nested-$shortToken.jpg';
        final sameAssetNameA = 'immich-e2e-local-051-same-a-$shortToken.jpg';
        final sameAssetNameB = 'immich-e2e-local-051-same-b-$shortToken.jpg';
        final refreshAssetName = 'immich-e2e-local-051-refresh-$shortToken.jpg';
        final folderAssetName = 'immich-e2e-folder-051-$shortToken.jpg';

        await _saveLocalTestImage(
          container,
          createdLocalAssetIds,
          title: cameraAssetName,
          relativePath: 'Pictures/$cameraAlbumName',
          seed: runToken.hashCode,
        );
        await _saveLocalTestImage(
          container,
          createdLocalAssetIds,
          title: nestedAssetName,
          relativePath: 'Pictures/ImmichE2E051Root$shortToken/$nestedAlbumName',
          seed: runToken.hashCode + 1,
        );
        await _saveLocalTestImage(
          container,
          createdLocalAssetIds,
          title: sameAssetNameA,
          relativePath: 'Pictures/ImmichE2E051DupA$shortToken/$sameAlbumName',
          seed: runToken.hashCode + 2,
        );
        await _saveLocalTestImage(
          container,
          createdLocalAssetIds,
          title: sameAssetNameB,
          relativePath: 'DCIM/ImmichE2E051DupB$shortToken/$sameAlbumName',
          seed: runToken.hashCode + 3,
        );

        final cameraAsset = await _waitForLocalAssetByName(
          container,
          cameraAssetName,
          tester,
        );
        final nestedAsset = await _waitForLocalAssetByName(
          container,
          nestedAssetName,
          tester,
        );
        final sameAssetA = await _waitForLocalAssetByName(
          container,
          sameAssetNameA,
          tester,
        );
        final sameAssetB = await _waitForLocalAssetByName(
          container,
          sameAssetNameB,
          tester,
        );
        final localAlbums = await _waitForLocalAlbumFixtures(
          tester,
          container,
          requiredNames: {cameraAlbumName, nestedAlbumName, sameAlbumName},
          duplicatedName: sameAlbumName,
        );
        final cameraAlbum = _singleAlbumNamed(localAlbums, cameraAlbumName);
        final nestedAlbum = _singleAlbumNamed(localAlbums, nestedAlbumName);
        final sameAlbums = _albumsNamed(localAlbums, sameAlbumName);
        final albumNames = localAlbums.map((album) => album.name).toSet();

        expect(cameraAlbum.assetCount, 1);
        expect(nestedAlbum.assetCount, 1);
        expect(sameAlbums, hasLength(greaterThanOrEqualTo(2)));
        expect(sameAlbums.every((album) => album.assetCount == 1), isTrue);
        expect(albumNames, isNot(contains(emptyAlbumName)));
        expect(albumNames, isNot(contains(inaccessibleAlbumName)));
        expect(
          await _localAssetSourceAlbumNames(container, cameraAsset),
          contains(cameraAlbumName),
        );
        expect(
          await _localAssetSourceAlbumNames(container, nestedAsset),
          contains(nestedAlbumName),
        );
        expect(
          await _localAssetSourceAlbumNames(container, sameAssetA),
          contains(sameAlbumName),
        );
        expect(
          await _localAssetSourceAlbumNames(container, sameAssetB),
          contains(sameAlbumName),
        );

        final cameraTimeline = container
            .read(timelineFactoryProvider)
            .localAlbum(albumId: cameraAlbum.id);
        addTearDown(cameraTimeline.dispose);
        final cameraTimelineAssets = await _expectTimelineAssetSet(
          tester,
          cameraTimeline,
          includes: {cameraAsset.id},
          excludes: {nestedAsset.id, sameAssetA.id, sameAssetB.id},
          reason:
              'Local camera album timeline should contain only its 051 fixture asset',
        );
        final cameraTimelineAsset = cameraTimelineAssets.singleWhere(
          (asset) => _timelineAssetId(asset) == cameraAsset.id,
        );
        expect(cameraTimelineAsset.isLocalOnly, isTrue);

        await _selectPrimaryNavigationTab(tester, kLibraryTabIndex);
        await pumpUntilFound(
          tester,
          find.byType(DriftLibraryPage),
          timeout: const Duration(seconds: 30),
        );
        await _tapTextEntryInPage(
          tester,
          pageType: DriftLibraryPage,
          label: 'on_this_device'.tr(),
        );
        await pumpUntilFound(
          tester,
          find.byType(DriftLocalAlbumsPage),
          timeout: const Duration(seconds: 30),
        );
        await _ensureTextVisibleInPage(
          tester,
          DriftLocalAlbumsPage,
          cameraAlbumName,
        );
        await _ensureTextVisibleInPage(
          tester,
          DriftLocalAlbumsPage,
          nestedAlbumName,
        );
        await _ensureTextVisibleInPage(
          tester,
          DriftLocalAlbumsPage,
          sameAlbumName,
        );
        await _tapTextEntryInPage(
          tester,
          pageType: DriftLocalAlbumsPage,
          label: cameraAlbumName,
        );
        await pumpUntilFound(
          tester,
          find.byType(LocalTimelinePage),
          timeout: const Duration(seconds: 30),
        );
        await pumpUntilFound(
          tester,
          find.text(cameraAlbumName),
          timeout: const Duration(seconds: 30),
        );
        await _exerciseTimelineUiPagination(tester);
        await _openTimelineAsset(tester, cameraTimelineAsset);
        await tester.binding.handlePopRoute();
        await _pumpUntil(
          tester,
          () =>
              find.byType(AssetViewer).evaluate().isEmpty &&
              find.byType(LocalTimelinePage).evaluate().isNotEmpty,
          timeout: const Duration(seconds: 30),
        );
        await pumpUntilFound(
          tester,
          _timelineAssetTileForAssetId(cameraAsset.id),
          timeout: const Duration(seconds: 30),
        );
        await tester.binding.handlePopRoute();
        await _pumpUntil(
          tester,
          () => find.byType(DriftLocalAlbumsPage).evaluate().isNotEmpty,
          timeout: const Duration(seconds: 30),
        );
        await _ensureTextVisibleInPage(
          tester,
          DriftLocalAlbumsPage,
          cameraAlbumName,
        );
        await tester.binding.handlePopRoute();
        await _pumpUntil(
          tester,
          () => find.byType(DriftLibraryPage).evaluate().isNotEmpty,
          timeout: const Duration(seconds: 30),
        );

        final refreshAsset = await _saveLocalTestImage(
          container,
          createdLocalAssetIds,
          title: refreshAssetName,
          relativePath: 'Pictures/$cameraAlbumName',
          seed: runToken.hashCode + 4,
        );
        await _waitForLocalAssetByName(container, refreshAssetName, tester);
        var refreshedAlbums = await _waitForLocalAlbumFixtures(
          tester,
          container,
          requiredNames: {cameraAlbumName},
        );
        expect(
          _singleAlbumNamed(refreshedAlbums, cameraAlbumName).assetCount,
          2,
        );
        final deletedLocalAssetIds = await PhotoManager.editor.deleteWithIds([
          refreshAsset.id,
        ]);
        expect(deletedLocalAssetIds, contains(refreshAsset.id));
        createdLocalAssetIds.remove(refreshAsset.id);
        await _waitForLocalAssetGoneByName(container, refreshAssetName, tester);
        refreshedAlbums = await _waitForLocalAlbumFixtures(
          tester,
          container,
          requiredNames: {cameraAlbumName},
        );
        expect(
          _singleAlbumNamed(refreshedAlbums, cameraAlbumName).assetCount,
          1,
        );

        final folderAssetId = await _uploadGeneratedJpegAsSecondClient(
          folderAssetName,
          DateTime.now().toUtc().add(const Duration(days: 3650)),
        );
        createdRemoteAssetIds.add(folderAssetId);
        await _waitForSuccessfulResponse(
          tester,
          () => _authenticatedApiGet(
            '/assets/$folderAssetId/thumbnail?size=thumbnail&edited=false&c=$runToken',
          ),
          timeout: const Duration(minutes: 3),
        );
        final folderPaths = await _waitForFolderPaths(
          tester,
          apiService.viewApi,
          (paths) => paths.any((path) => path.contains(folderAssetId)),
          reason:
              'Server folder view should expose the 051 fixture folder path',
          timeout: const Duration(seconds: 30),
        );
        expect(
          folderPaths.any((path) => path.contains(inaccessibleAlbumName)),
          isFalse,
        );

        await _selectPrimaryNavigationTab(tester, kLibraryTabIndex);
        await pumpUntilFound(
          tester,
          find.byType(DriftLibraryPage),
          timeout: const Duration(seconds: 30),
        );
        await _tapTextEntryInPage(
          tester,
          pageType: DriftLibraryPage,
          label: 'folders'.tr(),
        );
        await pumpUntilFound(
          tester,
          find.byType(FolderPage),
          timeout: const Duration(seconds: 30),
        );
        await _tapTextEntryInPage(
          tester,
          pageType: FolderPage,
          label: 'library',
        );
        await _tapTextEntryInPage(tester, pageType: FolderPage, label: 'photo');
        await container
            .read(folderStructureProvider.notifier)
            .fetchFolders(SortOrder.asc);
        final rootFolderState = container.read(folderStructureProvider);
        expect(rootFolderState.hasValue, isTrue);
        final assetFolder = _expectFolderPath(
          rootFolderState.requireValue,
          '/library/photo/$folderAssetId',
        );
        unawaited(router.push(FolderRoute(folder: assetFolder)));
        await pumpUntilFound(
          tester,
          find.text(folderAssetId),
          timeout: const Duration(seconds: 30),
        );
        await _ensureTextVisibleInPage(tester, FolderPage, folderAssetName);
        expect(find.text(inaccessibleAlbumName), findsNothing);
        await _tapTextEntryInPage(
          tester,
          pageType: FolderPage,
          label: folderAssetName,
        );
        await pumpUntilFound(
          tester,
          find.byType(AssetViewer),
          timeout: const Duration(seconds: 30),
        );
        await tester.binding.handlePopRoute();
        await _pumpUntil(
          tester,
          () =>
              find.byType(AssetViewer).evaluate().isEmpty &&
              find.byType(FolderPage).evaluate().isNotEmpty,
          timeout: const Duration(seconds: 30),
        );
        await _ensureTextVisibleInPage(tester, FolderPage, folderAssetName);

        await container
            .read(folderStructureProvider.notifier)
            .fetchFolders(SortOrder.asc);
        unawaited(
          router.push(
            FolderRoute(
              folder: RecursiveFolder(
                path: '/library/photo',
                name: emptyAlbumName,
                subfolders: [],
              ),
            ),
          ),
        );
        await pumpUntilFound(
          tester,
          find.byType(FolderPage),
          timeout: const Duration(seconds: 30),
        );
        await pumpUntilFound(
          tester,
          find.text(emptyAlbumName),
          timeout: const Duration(seconds: 30),
        );
        await pumpUntilFound(
          tester,
          find.text('empty_folder'.tr()),
          timeout: const Duration(seconds: 30),
        );
        await _popUntilVisible(tester, DriftLibraryPage);
      },
    );

    _realStackSessionTest(
      'MOB-UI-052-$_caseSuffix',
      'browses and manages memories',
      (tester) async {
        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = const Size(430, 932);
        addTearDown(tester.view.reset);

        await _loadAuthenticatedApp(
          tester,
          overrideCancellation: true,
          closeDriftOnDispose: false,
        );
        final container = _containerOfApp(tester);
        final apiService = container.read(apiServiceProvider);
        final downloadService = container.read(downloadServiceProvider);
        final downloadRepository = container.read(downloadRepositoryProvider);
        final shareInvocations = <_ShareInvocation>[];
        final downloadUpdates = <TaskStatusUpdate>[];
        final createdRemoteAssetIds = <String>[];

        _recordSharePlusInvocations(shareInvocations);
        downloadService.onImageDownloadStatus = downloadUpdates.add;
        downloadService.onVideoDownloadStatus = downloadUpdates.add;
        addTearDown(() async {
          _clearSharePlusInvocationRecorder();
          downloadService.onImageDownloadStatus = null;
          downloadService.onVideoDownloadStatus = null;
          await downloadRepository.deleteRecordsWithIds(createdRemoteAssetIds);
          for (final assetId in createdRemoteAssetIds) {
            await _deleteTestAssetBestEffort(apiService.assetsApi, assetId);
          }
        });

        final now = DateTime.now().toUtc();
        final runToken = now.microsecondsSinceEpoch.toString();
        final memoryPhotoName = 'immich-e2e-memory-052-photo-$runToken.jpg';
        final memoryVideoName = 'immich-e2e-memory-052-video-$runToken.mp4';
        final otherMemoryName = 'immich-e2e-memory-052-other-$runToken.jpg';
        final photoId = await _uploadGeneratedJpegAsSecondClient(
          memoryPhotoName,
          DateTime.utc(now.year - 1, now.month, now.day, 9),
        );
        createdRemoteAssetIds.add(photoId);
        final videoId = await _uploadGeneratedMp4AsSecondClient(
          memoryVideoName,
          DateTime.utc(now.year - 1, now.month, now.day, 10),
        );
        createdRemoteAssetIds.add(videoId);
        final otherMemoryId = await _uploadGeneratedJpegAsSecondClient(
          otherMemoryName,
          DateTime.utc(now.year - 2, now.month, now.day, 9),
        );
        createdRemoteAssetIds.add(otherMemoryId);

        for (final assetId in createdRemoteAssetIds) {
          await _waitForSuccessfulResponse(
            tester,
            () => _authenticatedApiGet(
              '/assets/$assetId/thumbnail?size=thumbnail&edited=false&c=$runToken',
            ),
            timeout: const Duration(minutes: 3),
          );
        }

        await container
            .read(syncApiRepositoryProvider)
            .deleteSyncAck(_allReplayableSyncAckTypes);
        await container.read(syncStreamRepositoryProvider).reset();
        final syncSuccess = await container
            .read(syncStreamServiceProvider)
            .sync();
        expect(syncSuccess, isTrue);
        container.invalidate(driftMemoryFutureProvider);
        await _pumpFor(tester, const Duration(seconds: 1));

        final memories = await _waitForMemoryLane(
          tester,
          container,
          (items) =>
              items.any(
                (memory) =>
                    _memoryAssetIds(memory).containsAll({photoId, videoId}),
              ) &&
              items.any(
                (memory) => _memoryAssetIds(memory).contains(otherMemoryId),
              ),
          reason:
              'Expected synced on-this-day memories for the 052 image/video fixtures',
        );
        expect(
          memories.map((memory) => memory.data.year),
          isNot(contains(now.year)),
        );
        final targetMemory = memories.singleWhere(
          (memory) => _memoryAssetIds(memory).containsAll({photoId, videoId}),
        );
        final otherMemory = memories.singleWhere(
          (memory) => _memoryAssetIds(memory).contains(otherMemoryId),
        );
        final targetIds = _memoryAssetIds(targetMemory);
        final photoAsset = targetMemory.assets.singleWhere(
          (asset) => asset.id == photoId,
        );
        expect(targetMemory.assets, hasLength(greaterThanOrEqualTo(2)));
        expect(targetIds, contains(photoId));
        expect(targetIds, contains(videoId));

        final providerMemories = await container.read(
          driftMemoryFutureProvider.future,
        );
        expect(
          providerMemories.map((memory) => memory.id),
          contains(targetMemory.id),
        );
        await _selectPrimaryNavigationTab(tester, kPhotoTabIndex);
        await pumpUntilFound(
          tester,
          find.byType(Timeline),
          timeout: const Duration(seconds: 60),
        );
        await _openMemoryFromTimeline(tester, targetMemory.id);
        await _pumpUntilFoundWithReason(
          tester,
          find.byType(DriftMemoryPage),
          reason:
              'Expected tapping the 052 memory card to open the memory viewer',
          timeout: const Duration(seconds: 30),
        );
        await _pumpUntil(
          tester,
          () =>
              container.read(assetViewerProvider).currentAsset?.id ==
              targetMemory.assets.first.id,
          timeout: const Duration(seconds: 10),
        );

        await _advanceMemoryAssetTo(
          tester,
          container,
          photoId,
          maxTaps: targetMemory.assets.length,
        );
        await _tapMemoryActionButton(tester, const Key('memory-share-button'));
        await _waitForShareInvocationCount(tester, shareInvocations, 1);
        _expectSharedDisplayNames(shareInvocations.single, {photoAsset.name});

        await downloadRepository.deleteRecordsWithIds([photoId]);
        await _tapMemoryActionButton(
          tester,
          const Key('memory-download-button'),
        );
        final downloadRecord = await _waitForDownloadRecordStatus(
          tester,
          photoId,
          TaskStatus.complete,
          reason: 'Expected memory download to complete for the current asset',
        );
        expect(downloadRecord.task.filename, photoAsset.name);

        await _tapMemoryActionButton(tester, const Key('memory-save-button'));
        await _waitForMemory(
          tester,
          container,
          targetMemory.id,
          (memory) => memory?.isSaved ?? false,
          reason: 'Expected memory save action to persist locally',
          timeout: const Duration(seconds: 10),
        );

        await _advanceMemoryAssetTo(
          tester,
          container,
          videoId,
          maxTaps: targetMemory.assets.length,
        );
        await _waitForVideoState(
          tester,
          container,
          videoId,
          (state) =>
              state.status == VideoPlaybackStatus.playing ||
              state.status == VideoPlaybackStatus.buffering,
          timeout: const Duration(seconds: 30),
        );
        await _tapMemoryActionButton(
          tester,
          const Key('memory-video-play-pause-button'),
        );
        await _waitForVideoState(
          tester,
          container,
          videoId,
          (state) => state.status == VideoPlaybackStatus.paused,
          timeout: const Duration(seconds: 30),
        );
        await _tapMemoryActionButton(
          tester,
          const Key('memory-video-play-pause-button'),
        );
        await _waitForVideoState(
          tester,
          container,
          videoId,
          (state) =>
              state.status == VideoPlaybackStatus.playing ||
              state.status == VideoPlaybackStatus.buffering,
          timeout: const Duration(seconds: 30),
        );

        await tester.fling(
          find.byType(PageView).first,
          const Offset(0, -700),
          1200,
        );
        await _pumpUntil(
          tester,
          () =>
              container.read(assetViewerProvider).currentAsset?.id ==
              otherMemory.assets.first.id,
          timeout: const Duration(seconds: 10),
        );
        await tester.fling(
          find.byType(PageView).first,
          const Offset(0, 700),
          1200,
        );
        await _pumpUntil(
          tester,
          () =>
              container.read(assetViewerProvider).currentAsset?.id ==
              targetMemory.assets.first.id,
          timeout: const Duration(seconds: 10),
        );

        await _tapMemoryActionButton(tester, const Key('memory-hide-button'));
        await _pumpUntil(
          tester,
          () => find.byType(DriftMemoryPage).evaluate().isEmpty,
          timeout: const Duration(seconds: 30),
        );

        final hidden = await container
            .read(driftMemoryServiceProvider)
            .get(targetMemory.id);
        expect(hidden, isNotNull);
        expect(hidden!.hideAt, isNotNull);
        container.invalidate(driftMemoryFutureProvider);
        final refreshedMemories = await _waitForMemoryLane(
          tester,
          container,
          (items) => !items.any((memory) => memory.id == targetMemory.id),
          reason:
              'Expected the hidden 052 memory to disappear from the memory lane',
        );
        expect(
          refreshedMemories.map((memory) => memory.id),
          contains(otherMemory.id),
        );
      },
    );

    _realStackSessionTest(
      'MOB-UI-053-$_caseSuffix',
      'edits album details, cover, ordering, permissions, and deletion',
      (tester) async {
        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = const Size(430, 932);
        addTearDown(tester.view.reset);

        await _loadAuthenticatedApp(
          tester,
          overrideCancellation: true,
          closeDriftOnDispose: false,
        );
        final container = _containerOfApp(tester);
        final drift = container.read(driftProvider);
        final apiService = container.read(apiServiceProvider);
        final albumsApi = apiService.albumsApi;
        final assetsApi = apiService.assetsApi;
        final router = container.read(appRouterProvider);
        final createdRemoteAssetIds = <String>[];
        String? ownedAlbumId;
        final user = Store.tryGet(StoreKey.currentUser);
        expect(user, isNotNull);

        addTearDown(() async {
          final albumId = ownedAlbumId;
          if (albumId != null) {
            await _deleteAlbumBestEffort(albumsApi, albumId);
          }
          for (final assetId in createdRemoteAssetIds) {
            await _deleteTestAssetBestEffort(assetsApi, assetId);
          }
        });

        await container
            .read(syncApiRepositoryProvider)
            .deleteSyncAck(_allReplayableSyncAckTypes);
        await Store.delete(StoreKey.syncMigrationStatus);
        await container.read(syncStreamRepositoryProvider).reset();
        final baselineSyncSuccess = await container
            .read(syncStreamServiceProvider)
            .sync();
        expect(baselineSyncSuccess, isTrue);

        final runToken = DateTime.now()
            .toUtc()
            .microsecondsSinceEpoch
            .toString();
        final shortToken = runToken.substring(runToken.length - 8);
        final baseCreatedAt = DateTime.now().toUtc().add(
          const Duration(days: 3650),
        );
        final assetIds = <String>[];
        for (var index = 0; index < 8; index++) {
          final assetId = await _uploadGeneratedJpegAsSecondClient(
            'immich-e2e-album-edit-053-$index-$runToken.jpg',
            baseCreatedAt.subtract(Duration(days: index)),
          );
          createdRemoteAssetIds.add(assetId);
          assetIds.add(assetId);
        }

        for (final assetId in assetIds) {
          await _waitForSuccessfulResponse(
            tester,
            () => _authenticatedApiGet(
              '/assets/$assetId/thumbnail?size=thumbnail&edited=false&c=$runToken',
            ),
            timeout: const Duration(minutes: 3),
          );
        }

        final originalAlbumName = 'immich-e2e-album-edit-053-$shortToken';
        final createdAlbum = await albumsApi.createAlbum(
          api.CreateAlbumDto(
            albumName: originalAlbumName,
            assetIds: api.Optional.present(assetIds),
          ),
        );
        expect(createdAlbum, isNotNull);
        ownedAlbumId = createdAlbum!.id;

        await _waitForAlbumInfoState(
          tester,
          albumsApi,
          ownedAlbumId,
          (album) =>
              album.albumName == originalAlbumName && album.assetCount == 8,
          reason:
              'Expected the 053 owned album to start with eight server assets',
        );

        final initialSyncSuccess = await container
            .read(syncStreamServiceProvider)
            .sync();
        expect(initialSyncSuccess, isTrue);
        final ownedAlbum = await _waitForRemoteAlbumState(
          tester,
          container,
          ownedAlbumId,
          (album) => album.name == originalAlbumName && album.assetCount == 8,
          reason: 'Expected the 053 owned album to sync locally before opening',
        );
        await _waitForRemoteAlbumAssetIds(
          tester,
          container,
          ownedAlbumId,
          includes: assetIds.toSet(),
          excludes: const {},
          reason:
              'Expected the local 053 owned album to contain all fixture assets',
        );

        unawaited(router.push(RemoteAlbumRoute(album: ownedAlbum)));
        await pumpUntilFound(
          tester,
          find.byType(RemoteAlbumPage),
          timeout: const Duration(seconds: 30),
        );
        await pumpUntilFound(
          tester,
          find.text(originalAlbumName),
          timeout: const Duration(seconds: 30),
        );

        final editedAlbumName = 'immich-e2e-album-edit-053-renamed-$shortToken';
        final editedDescription = 'Album edit description 053 $shortToken';
        await _tapRemoteAlbumMenuAction(
          tester,
          const Key('remote-album-edit-action'),
        );
        await pumpUntilFound(
          tester,
          find.byKey(const Key('remote-album-edit-dialog')),
          timeout: const Duration(seconds: 30),
        );
        await tester.enterText(
          find.byKey(const Key('remote-album-title-field')),
          editedAlbumName,
        );
        await tester.enterText(
          find.byKey(const Key('remote-album-description-field')),
          editedDescription,
        );
        await tester.ensureVisible(
          find.byKey(const Key('remote-album-edit-save-button')),
        );
        await tester.tap(
          find.byKey(const Key('remote-album-edit-save-button')),
          warnIfMissed: false,
        );
        await _pumpUntil(
          tester,
          () => find
              .byKey(const Key('remote-album-edit-dialog'))
              .evaluate()
              .isEmpty,
          timeout: const Duration(seconds: 30),
        );
        await _waitForAlbumInfoState(
          tester,
          albumsApi,
          ownedAlbumId,
          (album) =>
              album.albumName == editedAlbumName &&
              album.description == editedDescription,
          reason:
              'Expected 053 album title and description edits to persist on the server',
        );
        await _waitForRemoteAlbumState(
          tester,
          container,
          ownedAlbumId,
          (album) =>
              album.name == editedAlbumName &&
              album.description == editedDescription,
          reason:
              'Expected 053 album title and description edits to sync locally',
        );
        await pumpUntilFound(
          tester,
          find.text(editedAlbumName),
          timeout: const Duration(seconds: 30),
        );
        await pumpUntilFound(
          tester,
          find.text(editedDescription),
          timeout: const Duration(seconds: 30),
        );

        final coverAssetId = assetIds.first;
        final albumContainer = ProviderScope.containerOf(
          tester.element(find.byType(Timeline).last),
          listen: false,
        );
        await _selectTimelineAssetsById(tester, albumContainer, [coverAssetId]);
        expect(
          _bottomSheetIcon(RemoteAlbumBottomSheet, Icons.image_outlined),
          findsOneWidget,
        );
        await _tapBottomSheetAction(
          tester,
          RemoteAlbumBottomSheet,
          Icons.image_outlined,
        );
        await _waitForAlbumInfoState(
          tester,
          albumsApi,
          ownedAlbumId,
          (album) => album.albumThumbnailAssetId == coverAssetId,
          reason: 'Expected 053 album cover selection to persist on the server',
        );
        await _waitForRemoteAlbumState(
          tester,
          container,
          ownedAlbumId,
          (album) => album.thumbnailAssetId == coverAssetId,
          reason: 'Expected 053 album cover selection to sync locally',
        );

        final beforeOrder = await albumsApi.getAlbumInfo(ownedAlbumId);
        final expectedOrder =
            beforeOrder?.order.orElse(null) == api.AssetOrder.asc
            ? api.AssetOrder.desc
            : api.AssetOrder.asc;
        final expectedLocalOrder = expectedOrder == api.AssetOrder.asc
            ? AlbumAssetOrder.asc
            : AlbumAssetOrder.desc;
        await _tapRemoteAlbumMenuAction(
          tester,
          const Key('remote-album-change-order-action'),
        );
        await _waitForAlbumInfoState(
          tester,
          albumsApi,
          ownedAlbumId,
          (album) => album.order.orElse(null) == expectedOrder,
          reason:
              'Expected 053 album display order toggle to persist on the server',
        );
        final reorderedAlbum = await _waitForRemoteAlbumState(
          tester,
          container,
          ownedAlbumId,
          (album) => album.order == expectedLocalOrder,
          reason: 'Expected 053 album display order toggle to sync locally',
        );

        await router.maybePop();
        await _pumpUntil(
          tester,
          () => find.byType(RemoteAlbumPage).evaluate().isEmpty,
          timeout: const Duration(seconds: 30),
        );
        unawaited(router.push(RemoteAlbumRoute(album: reorderedAlbum)));
        await pumpUntilFound(
          tester,
          find.byType(RemoteAlbumPage),
          timeout: const Duration(seconds: 30),
        );
        await pumpUntilFound(
          tester,
          find.text(editedAlbumName),
          timeout: const Duration(seconds: 30),
        );
        await pumpUntilFound(
          tester,
          find.text(editedDescription),
          timeout: const Duration(seconds: 30),
        );
        await _waitForRemoteAlbumState(
          tester,
          container,
          ownedAlbumId,
          (album) =>
              album.name == editedAlbumName &&
              album.description == editedDescription &&
              album.thumbnailAssetId == coverAssetId &&
              album.order == expectedLocalOrder,
          reason:
              'Expected 053 album metadata, cover, and order to remain stable after reopening',
        );

        await _tapRemoteAlbumMenuAction(
          tester,
          const Key('remote-album-delete-action'),
        );
        await pumpUntilFound(
          tester,
          find.byKey(const Key('remote-album-delete-dialog')),
          timeout: const Duration(seconds: 30),
        );
        await tester.tap(
          find.byKey(const Key('remote-album-delete-cancel-button')),
          warnIfMissed: false,
        );
        await _pumpUntil(
          tester,
          () => find
              .byKey(const Key('remote-album-delete-dialog'))
              .evaluate()
              .isEmpty,
          timeout: const Duration(seconds: 30),
        );
        await _waitForAlbumInfoState(
          tester,
          albumsApi,
          ownedAlbumId,
          (album) =>
              album.albumName == editedAlbumName && album.assetCount == 8,
          reason:
              'Cancelling 053 album deletion must leave the album on the server',
        );
        await _waitForRemoteAlbumRowCount(
          tester,
          drift,
          ownedAlbumId,
          1,
          reason:
              'Cancelling 053 album deletion must leave the local album row',
        );

        await _tapRemoteAlbumMenuAction(
          tester,
          const Key('remote-album-delete-action'),
        );
        await pumpUntilFound(
          tester,
          find.byKey(const Key('remote-album-delete-dialog')),
          timeout: const Duration(seconds: 30),
        );
        await tester.tap(
          find.byKey(const Key('remote-album-delete-confirm-button')),
          warnIfMissed: false,
        );
        await pumpUntilFound(
          tester,
          find.byType(DriftAlbumsPage),
          timeout: const Duration(seconds: 30),
        );
        await _waitForServerAlbumIdsByName(
          tester,
          albumsApi,
          editedAlbumName,
          (ids) => ids.isEmpty,
          reason: 'Confirmed 053 album deletion should remove only the album',
        );
        await _waitForRemoteAlbumRowCount(
          tester,
          drift,
          ownedAlbumId,
          0,
          reason:
              'Confirmed 053 album deletion should remove the local album row',
        );
        for (final assetId in assetIds) {
          await _waitForAssetInfoState(
            tester,
            assetsApi,
            assetId,
            (asset) => !asset.isTrashed,
            reason:
                'Deleting the 053 album must not delete or trash asset $assetId',
          );
        }
        ownedAlbumId = null;

        final readOnlyAlbum = RemoteAlbum(
          id: '00000000-0000-4000-8000-000000000053',
          name: 'immich-e2e-album-edit-053-readonly-$shortToken',
          ownerId: '00000000-0000-4000-8000-000000000001',
          ownerName: 'Read Only Owner',
          description: 'Read-only shared album fixture',
          createdAt: DateTime.now().toUtc(),
          updatedAt: DateTime.now().toUtc(),
          thumbnailAssetId: coverAssetId,
          isActivityEnabled: true,
          order: AlbumAssetOrder.desc,
          assetCount: 1,
          isShared: true,
        );
        expect(readOnlyAlbum.ownerId, isNot(user!.id));
        unawaited(router.push(RemoteAlbumRoute(album: readOnlyAlbum)));
        await pumpUntilFound(
          tester,
          find.byType(RemoteAlbumPage),
          timeout: const Duration(seconds: 30),
        );
        await pumpUntilFound(
          tester,
          find.text(readOnlyAlbum.name),
          timeout: const Duration(seconds: 30),
        );

        await _openRemoteAlbumMenu(tester);
        expect(find.byKey(const Key('remote-album-edit-action')), findsNothing);
        expect(
          find.byKey(const Key('remote-album-add-photos-action')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('remote-album-add-users-action')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('remote-album-change-order-action')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('remote-album-delete-action')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('remote-album-options-action')),
          findsOneWidget,
        );
        await tester.tap(
          find.byKey(const Key('remote-album-options-action')),
          warnIfMissed: false,
        );
        await pumpUntilFound(
          tester,
          find.byType(DriftAlbumOptionsPage),
          timeout: const Duration(seconds: 30),
        );
        expect(
          find.byKey(const Key('remote-album-options-activity-switch')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('remote-album-options-invite-people-action')),
          findsNothing,
        );
      },
    );

    _realStackSessionTest(
      'MOB-UI-054-$_caseSuffix',
      'selects members, presents roles, shares, removes, and leaves albums',
      (tester) async {
        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = const Size(430, 932);
        addTearDown(tester.view.reset);

        final collaboratorPassword = _albumSharingCollaboratorPassword;
        final viewerPassword = _albumSharingViewerPassword;
        final collaboratorToken = await _loginForAccessToken(
          _albumSharingCollaboratorEmail,
          collaboratorPassword,
        );
        final viewerToken = await _loginForAccessToken(
          _albumSharingViewerEmail,
          viewerPassword,
        );

        await _loadAuthenticatedApp(
          tester,
          overrideCancellation: true,
          closeDriftOnDispose: false,
        );
        var container = _containerOfApp(tester);
        var drift = container.read(driftProvider);
        var albumsApi = container.read(apiServiceProvider).albumsApi;
        final ownerToken = Store.get(StoreKey.accessToken);
        final owner = Store.tryGet(StoreKey.currentUser);
        expect(owner, isNotNull);
        expect(
          owner!.id,
          isNot(anyOf(_albumSharingCollaboratorId, _albumSharingViewerId)),
        );

        final createdRemoteAssetIds = <String>[];
        String? ownedAlbumId;
        addTearDown(() async {
          final albumId = ownedAlbumId;
          if (albumId != null) {
            await _deleteAlbumBestEffortWithToken(albumId, ownerToken);
          }
          for (final assetId in createdRemoteAssetIds) {
            await _deleteTestAssetBestEffortWithToken(assetId, ownerToken);
          }
        });

        await _resetAndSyncRemoteState(tester, container);

        final runToken = DateTime.now()
            .toUtc()
            .microsecondsSinceEpoch
            .toString();
        final shortToken = runToken.substring(runToken.length - 8);
        final ownerAssetId = await _uploadGeneratedJpegAsSecondClient(
          'immich-e2e-album-sharing-054-owner-$runToken.jpg',
          DateTime.now().toUtc().add(const Duration(days: 3651)),
        );
        createdRemoteAssetIds.add(ownerAssetId);

        final albumName = 'immich-e2e-album-sharing-054-$shortToken';
        final createdAlbum = await albumsApi.createAlbum(
          api.CreateAlbumDto(
            albumName: albumName,
            assetIds: api.Optional.present([ownerAssetId]),
          ),
        );
        expect(createdAlbum, isNotNull);
        ownedAlbumId = createdAlbum!.id;

        await _waitForAlbumInfoState(
          tester,
          albumsApi,
          ownedAlbumId,
          (album) =>
              album.albumName == albumName &&
              album.albumUsers.length == 1 &&
              _albumHasUserRole(album, owner.id, api.AlbumUserRole.owner),
          reason:
              'Expected the 054 album to start owned by the login user only',
        );

        await container.read(syncStreamServiceProvider).sync();
        final ownedAlbum = await _waitForRemoteAlbumState(
          tester,
          container,
          ownedAlbumId,
          (album) => album.name == albumName && album.ownerId == owner.id,
          reason:
              'Expected the 054 owner album to sync before member selection',
        );

        final ownerRouter = container.read(appRouterProvider);
        unawaited(ownerRouter.push(RemoteAlbumRoute(album: ownedAlbum)));
        await pumpUntilFound(
          tester,
          find.byType(RemoteAlbumPage),
          timeout: const Duration(seconds: 30),
        );
        await pumpUntilFound(
          tester,
          find.text(albumName),
          timeout: const Duration(seconds: 30),
        );

        await _tapRemoteAlbumMenuAction(
          tester,
          const Key('remote-album-add-users-action'),
        );
        await pumpUntilFound(
          tester,
          find.byKey(const Key('drift-user-selection-page')),
          timeout: const Duration(seconds: 30),
        );
        final collaboratorTile = find.byKey(
          const Key('drift-user-selection-tile-$_albumSharingCollaboratorId'),
        );
        final viewerTile = find.byKey(
          const Key('drift-user-selection-tile-$_albumSharingViewerId'),
        );
        await pumpUntilFound(
          tester,
          collaboratorTile,
          timeout: const Duration(seconds: 30),
        );
        await pumpUntilFound(
          tester,
          viewerTile,
          timeout: const Duration(seconds: 30),
        );
        await tester.ensureVisible(collaboratorTile.first);
        await tester.tap(collaboratorTile.first, warnIfMissed: false);
        await pumpUntilFound(
          tester,
          find.byKey(
            const Key('drift-user-selection-chip-$_albumSharingCollaboratorId'),
          ),
          timeout: const Duration(seconds: 30),
        );
        await tester.tap(
          find.byKey(const Key('drift-user-selection-add-action')),
          warnIfMissed: false,
        );
        await _pumpUntil(
          tester,
          () => find
              .byKey(const Key('drift-user-selection-page'))
              .evaluate()
              .isEmpty,
          timeout: const Duration(seconds: 30),
        );

        await _waitForAlbumInfoState(
          tester,
          albumsApi,
          ownedAlbumId,
          (album) => _albumHasUserRole(
            album,
            _albumSharingCollaboratorId,
            api.AlbumUserRole.editor,
          ),
          reason:
              'Expected owner UI member selection to add the collaborator as an editor',
        );

        await _addAlbumUserViaApi(
          tester,
          ownedAlbumId,
          userId: _albumSharingViewerId,
          role: 'viewer',
          accessToken: ownerToken,
        );
        await _waitForAlbumInfoState(
          tester,
          albumsApi,
          ownedAlbumId,
          (album) =>
              album.albumUsers.length == 3 &&
              _albumHasUserRole(
                album,
                _albumSharingCollaboratorId,
                api.AlbumUserRole.editor,
              ) &&
              _albumHasUserRole(
                album,
                _albumSharingViewerId,
                api.AlbumUserRole.viewer,
              ),
          reason:
              'Expected the 054 album server membership list to contain owner, editor, and viewer',
        );

        await container.read(syncStreamServiceProvider).sync();
        container.invalidate(remoteAlbumSharedUsersProvider(ownedAlbumId));
        await _waitForRemoteAlbumSharedUsersState(
          tester,
          container,
          ownedAlbumId,
          (users) => users.map((user) => user.id).toSet().containsAll({
            _albumSharingCollaboratorId,
            _albumSharingViewerId,
          }),
          reason:
              'Expected owner local shared-user list to contain the editor and viewer',
        );

        await _tapRemoteAlbumMenuAction(
          tester,
          const Key('remote-album-options-action'),
        );
        await pumpUntilFound(
          tester,
          find.byType(DriftAlbumOptionsPage),
          timeout: const Duration(seconds: 30),
        );
        await pumpUntilFound(
          tester,
          find.byKey(const Key('remote-album-options-owner-row')),
          timeout: const Duration(seconds: 30),
        );
        await pumpUntilFound(
          tester,
          find.byKey(
            const Key(
              'remote-album-options-shared-user-$_albumSharingCollaboratorId',
            ),
          ),
          timeout: const Duration(seconds: 30),
        );
        await pumpUntilFound(
          tester,
          find.byKey(
            const Key(
              'remote-album-options-shared-user-$_albumSharingViewerId',
            ),
          ),
          timeout: const Duration(seconds: 30),
        );
        expect(
          find.byKey(const Key('remote-album-options-leave-album-action')),
          findsNothing,
        );
        await tester.binding.handlePopRoute();
        await pumpUntilFound(
          tester,
          find.byType(RemoteAlbumPage),
          timeout: const Duration(seconds: 30),
        );

        container = await _restartAuthenticatedApp(
          tester,
          email: _albumSharingCollaboratorEmail,
          password: collaboratorPassword,
        );
        drift = container.read(driftProvider);
        await _resetAndSyncRemoteState(tester, container);
        var sharedAlbum = await _waitForRemoteAlbumState(
          tester,
          container,
          ownedAlbumId,
          (album) => album.name == albumName && album.ownerId == owner.id,
          reason:
              'Expected the editor member to see the shared 054 album after refresh',
        );
        await _waitForRemoteAlbumUserRole(
          tester,
          container,
          ownedAlbumId,
          _albumSharingCollaboratorId,
          (role) => role == AlbumUserRole.editor,
          reason: 'Expected the collaborator to sync as an editor',
        );

        var router = container.read(appRouterProvider);
        unawaited(router.push(RemoteAlbumRoute(album: sharedAlbum)));
        await pumpUntilFound(
          tester,
          find.byType(RemoteAlbumPage),
          timeout: const Duration(seconds: 30),
        );
        await pumpUntilFound(
          tester,
          find.text(albumName),
          timeout: const Duration(seconds: 30),
        );
        await _openRemoteAlbumMenu(tester);
        await pumpUntilFound(
          tester,
          find.byKey(const Key('remote-album-add-photos-action')),
          timeout: const Duration(seconds: 30),
        );
        expect(
          find.byKey(const Key('remote-album-add-users-action')),
          findsNothing,
        );
        expect(find.byKey(const Key('remote-album-edit-action')), findsNothing);
        expect(
          find.byKey(const Key('remote-album-delete-action')),
          findsNothing,
        );
        await _tapHitTestableFinder(
          tester,
          find.byKey(const Key('remote-album-add-photos-action')),
        );
        await pumpUntilFound(
          tester,
          find.byType(DriftAssetSelectionTimelinePage),
          timeout: const Duration(seconds: 30),
        );
        await tester.binding.handlePopRoute();
        await pumpUntilFound(
          tester,
          find.byType(RemoteAlbumPage),
          timeout: const Duration(seconds: 30),
        );

        await _tapRemoteAlbumMenuAction(
          tester,
          const Key('remote-album-options-action'),
        );
        await pumpUntilFound(
          tester,
          find.byType(DriftAlbumOptionsPage),
          timeout: const Duration(seconds: 30),
        );
        await pumpUntilFound(
          tester,
          find.byKey(
            const Key(
              'remote-album-options-shared-user-$_albumSharingCollaboratorId',
            ),
          ),
          timeout: const Duration(seconds: 30),
        );
        await _tapHitTestableFinder(
          tester,
          find.byKey(
            const Key(
              'remote-album-options-shared-user-$_albumSharingCollaboratorId',
            ),
          ),
        );
        await pumpUntilFound(
          tester,
          find.byKey(const Key('remote-album-options-leave-album-action')),
          timeout: const Duration(seconds: 30),
        );
        await _tapHitTestableFinder(
          tester,
          find.byKey(const Key('remote-album-options-leave-album-action')),
        );
        await pumpUntilFound(
          tester,
          find.byType(DriftAlbumsPage),
          timeout: const Duration(seconds: 30),
        );
        await _waitForRejectedResponse(
          tester,
          () => _authenticatedApiRequest(
            'GET',
            '/albums/$ownedAlbumId',
            accessToken: collaboratorToken,
          ),
          reason:
              'Expected the collaborator to lose server access after leaving the 054 album',
          acceptedStatusCodes: const {403, 404},
        );
        final leaveSyncSuccess = await container
            .read(syncStreamServiceProvider)
            .sync();
        expect(leaveSyncSuccess, isTrue);
        await _waitForRemoteAlbumRowCount(
          tester,
          drift,
          ownedAlbumId,
          0,
          reason:
              'Expected the local album row to be removed after the collaborator leaves',
        );

        container = await _restartAuthenticatedApp(
          tester,
          email: _albumSharingViewerEmail,
          password: viewerPassword,
        );
        await _resetAndSyncRemoteState(tester, container);
        sharedAlbum = await _waitForRemoteAlbumState(
          tester,
          container,
          ownedAlbumId,
          (album) => album.name == albumName && album.ownerId == owner.id,
          reason:
              'Expected the viewer member to see the shared 054 album after refresh',
        );
        await _waitForRemoteAlbumUserRole(
          tester,
          container,
          ownedAlbumId,
          _albumSharingViewerId,
          (role) => role == AlbumUserRole.viewer,
          reason: 'Expected the ordinary member to sync as a viewer',
        );

        router = container.read(appRouterProvider);
        unawaited(router.push(RemoteAlbumRoute(album: sharedAlbum)));
        await pumpUntilFound(
          tester,
          find.byType(RemoteAlbumPage),
          timeout: const Duration(seconds: 30),
        );
        await pumpUntilFound(
          tester,
          find.text(albumName),
          timeout: const Duration(seconds: 30),
        );
        await _openRemoteAlbumMenu(tester);
        await _pumpFor(tester, const Duration(seconds: 1));
        expect(
          find.byKey(const Key('remote-album-add-photos-action')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('remote-album-add-users-action')),
          findsNothing,
        );
        expect(find.byKey(const Key('remote-album-edit-action')), findsNothing);
        expect(
          find.byKey(const Key('remote-album-delete-action')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('remote-album-options-action')),
          findsOneWidget,
        );

        container = await _restartAuthenticatedApp(
          tester,
          email: _email,
          password: _password,
        );
        drift = container.read(driftProvider);
        albumsApi = container.read(apiServiceProvider).albumsApi;
        await _resetAndSyncRemoteState(tester, container);
        final ownerAlbum = await _waitForRemoteAlbumState(
          tester,
          container,
          ownedAlbumId,
          (album) => album.name == albumName && album.ownerId == owner.id,
          reason:
              'Expected the owner to still see the 054 album after another member leaves',
        );
        await _waitForRemoteAlbumSharedUsersState(
          tester,
          container,
          ownedAlbumId,
          (users) =>
              !users.any((user) => user.id == _albumSharingCollaboratorId) &&
              users.any((user) => user.id == _albumSharingViewerId),
          reason:
              'Expected owner sync to retain only the viewer after the collaborator leaves',
        );

        router = container.read(appRouterProvider);
        unawaited(router.push(RemoteAlbumRoute(album: ownerAlbum)));
        await pumpUntilFound(
          tester,
          find.byType(RemoteAlbumPage),
          timeout: const Duration(seconds: 30),
        );
        await _tapRemoteAlbumMenuAction(
          tester,
          const Key('remote-album-options-action'),
        );
        await pumpUntilFound(
          tester,
          find.byType(DriftAlbumOptionsPage),
          timeout: const Duration(seconds: 30),
        );
        await pumpUntilFound(
          tester,
          find.byKey(
            const Key(
              'remote-album-options-shared-user-$_albumSharingViewerId',
            ),
          ),
          timeout: const Duration(seconds: 30),
        );
        await _tapHitTestableFinder(
          tester,
          find.byKey(
            const Key(
              'remote-album-options-shared-user-$_albumSharingViewerId',
            ),
          ),
        );
        await pumpUntilFound(
          tester,
          find.byKey(
            const Key(
              'remote-album-options-remove-user-action-$_albumSharingViewerId',
            ),
          ),
          timeout: const Duration(seconds: 30),
        );
        await _tapHitTestableFinder(
          tester,
          find.byKey(
            const Key(
              'remote-album-options-remove-user-action-$_albumSharingViewerId',
            ),
          ),
        );
        await _waitForAlbumInfoState(
          tester,
          albumsApi,
          ownedAlbumId,
          (album) =>
              album.albumUsers.length == 1 &&
              _albumHasUserRole(album, owner.id, api.AlbumUserRole.owner) &&
              !_albumHasUserRole(
                album,
                _albumSharingViewerId,
                api.AlbumUserRole.viewer,
              ),
          reason:
              'Expected owner removal to leave the album owned and unshared',
        );
        await _waitForRejectedResponse(
          tester,
          () => _authenticatedApiRequest(
            'GET',
            '/albums/$ownedAlbumId',
            accessToken: viewerToken,
          ),
          reason:
              'Expected the removed viewer to lose server access to the 054 album',
          acceptedStatusCodes: const {403, 404},
        );
        await container.read(syncStreamServiceProvider).sync();
        await _waitForRemoteAlbumSharedUsersState(
          tester,
          container,
          ownedAlbumId,
          (users) => users.isEmpty,
          reason:
              'Expected owner local shared-user list to be empty after removing all members',
        );
        await _waitForRemoteAlbumRowCount(
          tester,
          drift,
          ownedAlbumId,
          1,
          reason:
              'The owner must not lose the album while removing other members',
        );
      },
    );

    _realStackSessionTest(
      'MOB-UI-055-$_caseSuffix',
      'validates shared album activity stream and slideshow controls',
      (tester) async {
        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = const Size(430, 932);
        addTearDown(tester.view.reset);

        final collaboratorPassword = _albumSharingCollaboratorPassword;
        final viewerPassword = _albumSharingViewerPassword;
        final collaboratorToken = await _loginForAccessToken(
          _albumSharingCollaboratorEmail,
          collaboratorPassword,
        );
        final viewerToken = await _loginForAccessToken(
          _albumSharingViewerEmail,
          viewerPassword,
        );

        await _loadAuthenticatedApp(
          tester,
          overrideCancellation: true,
          closeDriftOnDispose: false,
        );
        var container = _containerOfApp(tester);
        var albumsApi = container.read(apiServiceProvider).albumsApi;
        final ownerToken = Store.get(StoreKey.accessToken);
        final owner = Store.tryGet(StoreKey.currentUser);
        expect(owner, isNotNull);

        final originalSlideshowDuration =
            SettingsRepository.instance.appConfig.slideshow.duration;
        addTearDown(() async {
          await SettingsRepository.instance.write(
            SettingsKey.slideshowDuration,
            originalSlideshowDuration,
          );
        });
        await SettingsRepository.instance.write(
          SettingsKey.slideshowDuration,
          30,
        );

        final createdRemoteAssetIds = <String>[];
        String? ownedAlbumId;
        addTearDown(() async {
          final albumId = ownedAlbumId;
          if (albumId != null) {
            await _deleteAlbumBestEffortWithToken(albumId, ownerToken);
          }
          for (final assetId in createdRemoteAssetIds) {
            await _deleteTestAssetBestEffortWithToken(assetId, ownerToken);
          }
        });

        await _resetAndSyncRemoteState(tester, container);

        final runToken = DateTime.now()
            .toUtc()
            .microsecondsSinceEpoch
            .toString();
        final shortToken = runToken.substring(runToken.length - 8);
        final photoId = await _uploadGeneratedJpegAsSecondClient(
          'immich-e2e-activity-slideshow-055-photo-$runToken.jpg',
          DateTime.now().toUtc().add(const Duration(days: 3652)),
        );
        createdRemoteAssetIds.add(photoId);
        final videoId = await _uploadGeneratedMp4AsSecondClient(
          'immich-e2e-activity-slideshow-055-video-$runToken.mp4',
          DateTime.now().toUtc().add(const Duration(days: 3652, seconds: 1)),
        );
        createdRemoteAssetIds.add(videoId);

        final albumName = 'immich-e2e-activity-slideshow-055-$shortToken';
        final createdAlbum = await albumsApi.createAlbum(
          api.CreateAlbumDto(
            albumName: albumName,
            assetIds: api.Optional.present([photoId, videoId]),
          ),
        );
        expect(createdAlbum, isNotNull);
        ownedAlbumId = createdAlbum!.id;
        await _addAlbumUserViaApi(
          tester,
          ownedAlbumId,
          userId: _albumSharingCollaboratorId,
          role: 'editor',
          accessToken: ownerToken,
        );
        await _addAlbumUserViaApi(
          tester,
          ownedAlbumId,
          userId: _albumSharingViewerId,
          role: 'viewer',
          accessToken: ownerToken,
        );
        await _waitForAlbumInfoState(
          tester,
          albumsApi,
          ownedAlbumId,
          (album) =>
              album.isActivityEnabled &&
              album.assetCount == 2 &&
              album.albumUsers.length == 3,
          reason:
              'Expected the 055 shared album to enable activities with image and video assets',
        );

        await container.read(syncStreamServiceProvider).sync();
        var ownerAlbum = await _waitForRemoteAlbumState(
          tester,
          container,
          ownedAlbumId,
          (album) =>
              album.name == albumName &&
              album.isShared &&
              album.isActivityEnabled,
          reason: 'Expected owner local shared album to show activity controls',
        );
        await _waitForRemoteAlbumAssetIds(
          tester,
          container,
          ownedAlbumId,
          includes: {photoId, videoId},
          excludes: const {},
          reason: 'Expected the 055 album to sync both image and video members',
        );

        var router = container.read(appRouterProvider);
        unawaited(router.push(RemoteAlbumRoute(album: ownerAlbum)));
        await pumpUntilFound(
          tester,
          find.byType(RemoteAlbumPage),
          timeout: const Duration(seconds: 30),
        );
        await pumpUntilFound(
          tester,
          find.text(albumName),
          timeout: const Duration(seconds: 30),
        );
        await _pressRemoteAlbumAppBarAction(
          tester,
          const Key('remote-album-activity-action'),
        );
        await pumpUntilFound(
          tester,
          find.byType(DriftActivitiesPage),
          timeout: const Duration(seconds: 30),
        );
        await pumpUntilFound(
          tester,
          find.byKey(const Key('drift-activity-comment-field')),
          timeout: const Duration(seconds: 30),
        );

        final ownerComment = 'owner activity 055 $shortToken';
        await tester.enterText(
          find.byKey(const Key('drift-activity-comment-field')),
          ownerComment,
        );
        await _pumpFor(tester, const Duration(milliseconds: 300));
        await _pressIconButtonByKey(
          tester,
          const Key('drift-activity-send-action'),
          reason:
              'Expected the non-empty activity comment to enable the send action',
        );
        await pumpUntilFound(
          tester,
          find.text(ownerComment),
          timeout: const Duration(seconds: 30),
        );

        var activities = await _waitForActivityComments(
          tester,
          ownedAlbumId,
          accessToken: ownerToken,
          includes: {ownerComment},
          reason:
              'Expected the owner UI comment to be persisted by the activity API',
        );
        final ownerActivity = _activityWithComment(activities, ownerComment);
        expect(
          (ownerActivity['user'] as Map<String, dynamic>)['id'],
          owner!.id,
        );

        final collaboratorComment = 'collaborator reply 055 $shortToken';
        final collaboratorActivity = await _createAlbumActivityViaApi(
          ownedAlbumId,
          comment: collaboratorComment,
          accessToken: collaboratorToken,
        );
        expect(
          (collaboratorActivity['user'] as Map<String, dynamic>)['id'],
          _albumSharingCollaboratorId,
        );
        await _waitForRejectedResponse(
          tester,
          () => _authenticatedApiRequest(
            'DELETE',
            '/activities/${collaboratorActivity['id']}',
            accessToken: viewerToken,
          ),
          reason:
              'Expected a viewer member to be unable to delete another user comment',
          acceptedStatusCodes: const {403, 404},
        );

        container = await _restartAuthenticatedApp(
          tester,
          email: _albumSharingCollaboratorEmail,
          password: collaboratorPassword,
        );
        await _resetAndSyncRemoteState(tester, container);
        final sharedAlbum = await _waitForRemoteAlbumState(
          tester,
          container,
          ownedAlbumId,
          (album) =>
              album.name == albumName &&
              album.isShared &&
              album.isActivityEnabled,
          reason:
              'Expected the collaborator to see the 055 shared album after refresh',
        );
        router = container.read(appRouterProvider);
        unawaited(router.push(RemoteAlbumRoute(album: sharedAlbum)));
        await pumpUntilFound(
          tester,
          find.byType(RemoteAlbumPage),
          timeout: const Duration(seconds: 30),
        );
        await _pressRemoteAlbumAppBarAction(
          tester,
          const Key('remote-album-activity-action'),
        );
        await pumpUntilFound(
          tester,
          find.byType(DriftActivitiesPage),
          timeout: const Duration(seconds: 30),
        );
        await pumpUntilFound(
          tester,
          find.text(ownerComment),
          timeout: const Duration(seconds: 30),
        );
        await pumpUntilFound(
          tester,
          find.text(collaboratorComment),
          timeout: const Duration(seconds: 30),
        );

        activities = await _waitForActivityComments(
          tester,
          ownedAlbumId,
          accessToken: collaboratorToken,
          includes: {ownerComment, collaboratorComment},
          reason: 'Expected both comments to be visible to another account',
        );
        final createdTimes = activities
            .map((activity) => DateTime.parse(activity['createdAt'] as String))
            .toList();
        expect(createdTimes, orderedEquals([...createdTimes]..sort()));

        container = await _restartAuthenticatedApp(
          tester,
          email: _email,
          password: _password,
        );
        albumsApi = container.read(apiServiceProvider).albumsApi;
        await _resetAndSyncRemoteState(tester, container);
        ownerAlbum = await _waitForRemoteAlbumState(
          tester,
          container,
          ownedAlbumId,
          (album) =>
              album.name == albumName &&
              album.assetCount == 2 &&
              album.isActivityEnabled,
          reason:
              'Expected the owner album to remain available before activity deletion',
        );
        router = container.read(appRouterProvider);
        unawaited(router.push(RemoteAlbumRoute(album: ownerAlbum)));
        await pumpUntilFound(
          tester,
          find.byType(RemoteAlbumPage),
          timeout: const Duration(seconds: 30),
        );
        await _pressRemoteAlbumAppBarAction(
          tester,
          const Key('remote-album-activity-action'),
        );
        await pumpUntilFound(
          tester,
          find.byType(DriftActivitiesPage),
          timeout: const Duration(seconds: 30),
        );
        await pumpUntilFound(
          tester,
          find.text(collaboratorComment),
          timeout: const Duration(seconds: 30),
        );

        await tester.drag(
          find.byKey(Key(collaboratorActivity['id'] as String)).first,
          const Offset(-600, 0),
        );
        await pumpUntilFound(
          tester,
          find.byType(ConfirmDialog),
          timeout: const Duration(seconds: 30),
        );
        final deleteButton = find.widgetWithText(TextButton, 'delete'.tr());
        await pumpUntilFound(
          tester,
          deleteButton,
          timeout: const Duration(seconds: 30),
        );
        await tester.tap(deleteButton.last, warnIfMissed: false);
        await _pumpFor(tester, const Duration(milliseconds: 500));
        await _waitForActivityComments(
          tester,
          ownedAlbumId,
          accessToken: ownerToken,
          includes: {ownerComment},
          excludes: {collaboratorComment},
          reason:
              'Expected owner deletion to remove the collaborator comment from the activity API',
        );

        await tester.binding.handlePopRoute();
        await pumpUntilFound(
          tester,
          find.byType(RemoteAlbumPage),
          timeout: const Duration(seconds: 30),
        );
        await _pressRemoteAlbumAppBarAction(
          tester,
          const Key('remote-album-slideshow-action'),
        );
        await pumpUntilFound(
          tester,
          find.byType(DriftSlideshowPage),
          timeout: const Duration(seconds: 30),
        );
        await pumpUntilFound(
          tester,
          find.byKey(const Key('slideshow-page-view')),
          timeout: const Duration(seconds: 30),
        );

        await _showSlideshowControls(tester);
        const pauseKey = Key('slideshow-pause-action');
        const playKey = Key('slideshow-play-action');
        final firstPlaybackKey = await _waitForAnyKey(tester, const [
          pauseKey,
          playKey,
        ]);
        final secondPlaybackKey = firstPlaybackKey == pauseKey
            ? playKey
            : pauseKey;
        await _tapHitTestableFinder(tester, find.byKey(firstPlaybackKey));
        await _pumpUntil(
          tester,
          () =>
              find.byKey(secondPlaybackKey).hitTestable().evaluate().isNotEmpty,
          timeout: const Duration(seconds: 30),
        );
        await _tapHitTestableFinder(tester, find.byKey(secondPlaybackKey));
        await _pumpUntil(
          tester,
          () =>
              find.byKey(firstPlaybackKey).hitTestable().evaluate().isNotEmpty,
          timeout: const Duration(seconds: 30),
        );
        await _tapHitTestableFinder(
          tester,
          find.byKey(const Key('slideshow-settings-action')),
        );
        await pumpUntilFound(
          tester,
          find.byType(SettingsSubPage),
          timeout: const Duration(seconds: 30),
        );
        await _ensureTextVisibleInPage(
          tester,
          SettingsSubPage,
          'slideshow'.tr(),
        );
        await pumpUntilFound(
          tester,
          find.byType(SlideshowSettings),
          timeout: const Duration(seconds: 30),
        );
        final durationSlider = find.descendant(
          of: find.byType(SlideshowSettings),
          matching: find.byType(Slider),
        );
        await pumpUntilFound(
          tester,
          durationSlider,
          timeout: const Duration(seconds: 30),
        );
        await tester.drag(
          durationSlider.first,
          const Offset(-240, 0),
          warnIfMissed: false,
        );
        await _pumpFor(tester, const Duration(milliseconds: 500));
        expect(
          SettingsRepository.instance.appConfig.slideshow.duration,
          lessThan(30),
        );

        await tester.binding.handlePopRoute();
        await pumpUntilFound(
          tester,
          find.byType(DriftSlideshowPage),
          timeout: const Duration(seconds: 30),
        );
        await tester.binding.handlePopRoute();
        await pumpUntilFound(
          tester,
          find.byType(RemoteAlbumPage),
          timeout: const Duration(seconds: 30),
        );
        await pumpUntilFound(
          tester,
          find.text(albumName),
          timeout: const Duration(seconds: 30),
        );

        final ownerActivityDeleted = await _captureError(
          () async => await _waitForRejectedResponse(
            tester,
            () => _authenticatedApiRequest(
              'DELETE',
              '/activities/${ownerActivity['id']}',
              accessToken: viewerToken,
            ),
            reason:
                'Expected viewer to still be unable to delete the owner comment after slideshow flow',
            acceptedStatusCodes: const {403, 404},
          ),
        );
        expect(ownerActivityDeleted, isNull);
      },
    );

    _realStackSessionTest(
      'MOB-UI-056-$_caseSuffix',
      'creates edits copies opens and deletes shared links',
      (tester) async {
        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = const Size(430, 932);
        addTearDown(tester.view.reset);

        await _loadAuthenticatedApp(
          tester,
          overrideCancellation: true,
          closeDriftOnDispose: false,
        );
        final container = _containerOfApp(tester);
        final albumsApi = container.read(apiServiceProvider).albumsApi;
        final ownerToken = Store.get(StoreKey.accessToken);

        final createdRemoteAssetIds = <String>[];
        String? ownedAlbumId;
        String? sharedLinkId;
        addTearDown(() async {
          final linkId = sharedLinkId;
          if (linkId != null) {
            await _deleteSharedLinkBestEffortWithToken(linkId, ownerToken);
          }
          final albumId = ownedAlbumId;
          if (albumId != null) {
            await _deleteAlbumBestEffortWithToken(albumId, ownerToken);
          }
          for (final assetId in createdRemoteAssetIds) {
            await _deleteTestAssetBestEffortWithToken(assetId, ownerToken);
          }
        });

        final runToken = DateTime.now()
            .toUtc()
            .microsecondsSinceEpoch
            .toString();
        final shortToken = runToken.substring(runToken.length - 8);
        final photoId = await _uploadGeneratedJpegAsSecondClient(
          'immich-e2e-shared-link-056-photo-$runToken.jpg',
          DateTime.now().toUtc().add(const Duration(days: 3653)),
        );
        createdRemoteAssetIds.add(photoId);

        final albumName = 'immich-e2e-shared-link-056-$shortToken';
        final createdAlbum = await albumsApi.createAlbum(
          api.CreateAlbumDto(
            albumName: albumName,
            assetIds: api.Optional.present([photoId]),
          ),
        );
        expect(createdAlbum, isNotNull);
        ownedAlbumId = createdAlbum!.id;
        await _waitForAlbumInfoState(
          tester,
          albumsApi,
          ownedAlbumId,
          (album) => album.assetCount == 1,
          reason:
              'Expected the 056 album to contain its uploaded fixture before sharing',
        );

        final createSlug = 'immich-e2e-056-$shortToken';
        final editSlug = 'immich-e2e-056-edit-$shortToken';
        final initialDescription = 'shared link 056 initial $shortToken';
        final editedDescription = 'shared link 056 edited $shortToken';
        final initialPassword = 'link-056-$shortToken';
        final editedPassword = 'link-056-edit-$shortToken';

        final router = container.read(appRouterProvider);
        unawaited(router.push(SharedLinkEditRoute(albumId: ownedAlbumId)));
        await pumpUntilFound(
          tester,
          find.byType(SharedLinkEditPage),
          timeout: const Duration(seconds: 30),
        );

        await tester.enterText(
          find.byKey(const Key('shared-link-description-field')),
          initialDescription,
        );
        await tester.enterText(
          find.byKey(const Key('shared-link-password-field')),
          initialPassword,
        );
        await tester.enterText(
          find.byKey(const Key('shared-link-slug-field')),
          createSlug,
        );
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await _pumpFor(tester, const Duration(milliseconds: 300));
        await _tapHitTestableFinder(
          tester,
          find.byKey(const Key('shared-link-allow-download-switch')),
        );
        await _tapHitTestableFinder(
          tester,
          find.byKey(const Key('shared-link-allow-upload-switch')),
        );
        await _ensureKeyVisibleInPage(
          tester,
          SharedLinkEditPage,
          const Key('shared-link-expiry-tile'),
        );
        await _tapHitTestableFinder(
          tester,
          find.byKey(const Key('shared-link-expiry-tile')),
        );
        await pumpUntilFound(
          tester,
          find.byKey(const Key('shared-link-expiry-preset-3600')),
          timeout: const Duration(seconds: 30),
        );
        await _tapHitTestableFinder(
          tester,
          find.byKey(const Key('shared-link-expiry-preset-3600')),
        );
        await _ensureKeyVisibleInPage(
          tester,
          SharedLinkEditPage,
          const Key('shared-link-submit-button'),
        );
        await _tapHitTestableFinder(
          tester,
          find.byKey(const Key('shared-link-submit-button')),
        );
        await pumpUntilFound(
          tester,
          find.byKey(const Key('shared-link-copy-field')),
          timeout: const Duration(seconds: 30),
        );

        final createdLink = await _waitForSharedLinkState(
          tester,
          container,
          (link) => link.slug == createSlug,
          reason:
              'Expected the 056 shared link to be created from the edit route',
        );
        sharedLinkId = createdLink.id;
        expect(createdLink.description, initialDescription);
        expect(createdLink.allowDownload, isFalse);
        expect(createdLink.allowUpload, isTrue);
        expect(createdLink.showMetadata, isTrue);
        expect(createdLink.expiresAt, isNotNull);
        expect(createdLink.password?.isNotEmpty ?? false, isTrue);

        final createdShareUrl = buildSharedLinkUrl(
          baseUrl: getServerUrl(),
          slug: createdLink.slug,
          key: createdLink.key,
        );
        expect(createdShareUrl, isNotNull);
        final copiedAfterCreate = await Clipboard.getData('text/plain');
        expect(copiedAfterCreate?.text, createdShareUrl);

        await _waitForRejectedResponse(
          tester,
          () => _publicApiRequest(
            'GET',
            '/shared-links/me?${_sharedLinkLookupQuery(createdLink)}',
          ),
          reason:
              'Expected the 056 password-protected link to require login before public access',
          acceptedStatusCodes: const {401},
        );
        await _waitForSuccessfulResponse(
          tester,
          () => _publicApiRequest(
            'POST',
            '/shared-links/login?${_sharedLinkLookupQuery(createdLink)}',
            jsonBody: {'password': initialPassword},
          ),
        );

        await _tapHitTestableFinder(
          tester,
          find.byKey(const Key('shared-link-done-button')),
        );
        await _pumpFor(tester, const Duration(milliseconds: 500));
        unawaited(router.push(const SharedLinkRoute()));
        await pumpUntilFound(
          tester,
          find.byType(SharedLinkPage),
          timeout: const Duration(seconds: 30),
        );
        await container.read(sharedLinksStateProvider.notifier).fetchLinks();
        await pumpUntilFound(
          tester,
          find.byKey(Key('shared-link-item-${createdLink.id}')),
          timeout: const Duration(seconds: 30),
        );
        await tester.longPress(
          find.byKey(Key('shared-link-item-${createdLink.id}')),
        );
        await _pumpFor(tester, const Duration(milliseconds: 500));
        final copiedFromList = await Clipboard.getData('text/plain');
        expect(copiedFromList?.text, createdShareUrl);

        await _tapHitTestableFinder(
          tester,
          find.byKey(Key('shared-link-item-${createdLink.id}')),
        );
        await pumpUntilFound(
          tester,
          find.byType(SharedLinkEditPage),
          timeout: const Duration(seconds: 30),
        );
        await pumpUntilFound(
          tester,
          find.byKey(const Key('shared-link-copy-field')),
          timeout: const Duration(seconds: 30),
        );
        await tester.binding.handlePopRoute();
        await pumpUntilFound(
          tester,
          find.byType(SharedLinkPage),
          timeout: const Duration(seconds: 30),
        );

        final serviceEditedLink = await container
            .read(sharedLinkServiceProvider)
            .updateSharedLink(
              createdLink.id,
              showMeta: false,
              allowDownload: true,
              allowUpload: false,
              description: Option<String?>.some(editedDescription),
              password: Option<String?>.some(editedPassword),
              slug: editSlug,
              expiresAt: const Option<DateTime?>.some(null),
            );
        expect(serviceEditedLink, isNotNull);
        await container.read(sharedLinksStateProvider.notifier).fetchLinks();

        final editedLink = await _waitForSharedLinkState(
          tester,
          container,
          (link) => link.id == createdLink.id && link.slug == editSlug,
          reason: 'Expected the 056 shared link edits to persist',
        );
        expect(editedLink.description, editedDescription);
        expect(editedLink.allowDownload, isTrue);
        expect(editedLink.allowUpload, isFalse);
        expect(editedLink.showMetadata, isFalse);
        expect(editedLink.expiresAt, isNull);
        expect(editedLink.password?.isNotEmpty ?? false, isTrue);

        await _waitForRejectedResponse(
          tester,
          () => _publicApiRequest(
            'GET',
            '/shared-links/me?slug=${Uri.encodeQueryComponent(createSlug)}',
          ),
          reason:
              'Expected the 056 old custom URL to stop resolving after edit',
          acceptedStatusCodes: const {404},
        );
        await _waitForSuccessfulResponse(
          tester,
          () => _publicApiRequest(
            'POST',
            '/shared-links/login?${_sharedLinkLookupQuery(editedLink)}',
            jsonBody: {'password': editedPassword},
          ),
        );

        await pumpUntilFound(
          tester,
          find.byType(SharedLinkPage),
          timeout: const Duration(seconds: 30),
        );
        final listItem = find.byKey(ValueKey(createdLink.id));
        await pumpUntilFound(
          tester,
          listItem,
          timeout: const Duration(seconds: 30),
        );
        await tester.fling(
          listItem,
          const Offset(-800, 0),
          2000,
          warnIfMissed: false,
        );
        await pumpUntilFound(
          tester,
          find.byType(ConfirmDialog),
          timeout: const Duration(seconds: 30),
        );
        await tester.tap(
          find
              .descendant(
                of: find.byType(ConfirmDialog),
                matching: find.byType(TextButton),
              )
              .last,
        );
        await _waitForSharedLinkDeleted(
          tester,
          container,
          editedLink.id,
          reason:
              'Expected the 056 list delete action to remove the shared link',
        );
        sharedLinkId = null;
        await _waitForRejectedResponse(
          tester,
          () => _publicApiRequest(
            'GET',
            '/shared-links/me?${_sharedLinkLookupQuery(editedLink)}',
          ),
          reason: 'Expected the 056 deleted shared link to be inaccessible',
          acceptedStatusCodes: const {404},
        );
      },
    );

    _realStackSessionTest(
      'MOB-UI-057-$_caseSuffix',
      'adds browses toggles and removes partner sharing',
      (tester) async {
        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = const Size(430, 932);
        addTearDown(tester.view.reset);

        final partnerPassword = _partnerSharingPasswordOverride.isEmpty
            ? _password
            : _partnerSharingPasswordOverride;

        await _loadAuthenticatedApp(
          tester,
          overrideCancellation: true,
          closeDriftOnDispose: false,
        );
        var container = _containerOfApp(tester);
        final owner = container.read(currentUserProvider);
        expect(owner, isNotNull);
        final ownerId = owner!.id;
        final ownerName = owner.name;
        final ownerToken = Store.get(StoreKey.accessToken);
        final partnerToken = await _loginForAccessToken(
          _partnerSharingEmail,
          partnerPassword,
        );
        addTearDown(() async {
          await _deletePartnerBestEffortWithToken(
            _partnerSharingId,
            ownerToken,
          );
          await _deletePartnerBestEffortWithToken(ownerId, partnerToken);
        });

        await _deletePartnerBestEffortWithToken(_partnerSharingId, ownerToken);
        await _deletePartnerBestEffortWithToken(ownerId, partnerToken);

        await _resetAndSyncRemoteState(tester, container);
        var drift = container.read(driftProvider);
        await _waitForUserRow(
          tester,
          drift,
          _partnerSharingId,
          reason:
              'Expected the 057 partner test account to sync before opening the candidate picker',
        );
        await _waitForPartnerMissing(
          tester,
          drift,
          ownerId,
          _partnerSharingId,
          reason:
              'Expected 057 to start without a stale owner-to-partner local relation',
        );

        var router = container.read(appRouterProvider);
        unawaited(router.push(const PartnerRoute()));
        await pumpUntilFound(
          tester,
          find.byType(PartnerPage),
          timeout: const Duration(seconds: 30),
        );
        await _tapHitTestableFinder(
          tester,
          find.byKey(const Key('partner-add-action')),
        );
        await _tapHitTestableFinder(
          tester,
          find.byKey(const Key('partner-candidate-$_partnerSharingId')),
        );
        await _waitForPartnerRowState(
          tester,
          drift,
          ownerId,
          _partnerSharingId,
          expectedInTimeline: false,
          reason:
              'Expected the 057 owner app to persist the new partner share locally',
        );
        await pumpUntilFound(
          tester,
          find.byKey(const Key('partner-shared-by-$_partnerSharingId')),
          timeout: const Duration(seconds: 30),
        );

        final sharedByEntry = await _waitForPartnerListEntry(
          tester,
          accessToken: ownerToken,
          direction: 'shared-by',
          partnerId: _partnerSharingId,
          reason:
              'Expected the 057 owner API list to include the selected partner',
        );
        expect(sharedByEntry['email'], _partnerSharingEmail);
        await _waitForPartnerListEntry(
          tester,
          accessToken: partnerToken,
          direction: 'shared-with',
          partnerId: ownerId,
          reason:
              'Expected the 057 partner API list to include the owner after sharing',
        );

        container = await _restartAuthenticatedApp(
          tester,
          email: _partnerSharingEmail,
          password: partnerPassword,
        );
        await _resetAndSyncRemoteState(tester, container);
        drift = container.read(driftProvider);
        await _waitForPartnerRowState(
          tester,
          drift,
          ownerId,
          _partnerSharingId,
          expectedInTimeline: false,
          reason:
              'Expected the 057 partner app to sync the incoming share before opening details',
        );
        router = container.read(appRouterProvider);
        unawaited(
          router.push(const TabShellRoute(children: [DriftLibraryRoute()])),
        );
        await pumpUntilFound(
          tester,
          find.byType(DriftLibraryPage),
          timeout: const Duration(seconds: 30),
        );
        await _ensureKeyVisibleInPage(
          tester,
          DriftLibraryPage,
          Key('partner-shared-with-$ownerId'),
        );
        await _tapHitTestableFinder(
          tester,
          find.byKey(Key('partner-shared-with-$ownerId')),
        );
        await pumpUntilFound(
          tester,
          find.byType(DriftPartnerDetailPage),
          timeout: const Duration(seconds: 30),
        );
        await pumpUntilFound(
          tester,
          find.text(ownerName),
          timeout: const Duration(seconds: 30),
        );
        await _exerciseTimelineUiPagination(tester);

        final inTimelineSwitch = find.byKey(
          const Key('partner-in-timeline-switch'),
        );
        await pumpUntilFound(
          tester,
          inTimelineSwitch,
          timeout: const Duration(seconds: 30),
        );
        expect(tester.widget<Switch>(inTimelineSwitch.last).value, isFalse);
        await _tapHitTestableFinder(tester, inTimelineSwitch);
        await _waitForPartnerRowState(
          tester,
          drift,
          ownerId,
          _partnerSharingId,
          expectedInTimeline: true,
          reason:
              'Expected the 057 partner app to persist the visible range toggle locally',
        );
        final updatedPartnerEntry = await _waitForPartnerListEntry(
          tester,
          accessToken: partnerToken,
          direction: 'shared-with',
          partnerId: ownerId,
          reason:
              'Expected the 057 partner API list to reflect the visible range toggle',
        );
        expect(updatedPartnerEntry['inTimeline'], isTrue);

        container = await _restartAuthenticatedApp(
          tester,
          email: _email,
          password: _password,
        );
        await _resetAndSyncRemoteState(tester, container);
        drift = container.read(driftProvider);
        router = container.read(appRouterProvider);
        unawaited(router.push(const PartnerRoute()));
        await pumpUntilFound(
          tester,
          find.byType(PartnerPage),
          timeout: const Duration(seconds: 30),
        );
        await pumpUntilFound(
          tester,
          find.byKey(const Key('partner-shared-by-$_partnerSharingId')),
          timeout: const Duration(seconds: 30),
        );
        await _tapHitTestableFinder(
          tester,
          find.byKey(const Key('partner-remove-$_partnerSharingId')),
        );
        await pumpUntilFound(
          tester,
          find.byType(ConfirmDialog),
          timeout: const Duration(seconds: 30),
        );
        await tester.tap(
          find
              .descendant(
                of: find.byType(ConfirmDialog),
                matching: find.byType(TextButton),
              )
              .last,
        );
        await _waitForPartnerMissing(
          tester,
          drift,
          ownerId,
          _partnerSharingId,
          reason:
              'Expected the 057 owner app to remove the partner relation after confirmation',
        );
        await _waitForPartnerListMissing(
          tester,
          accessToken: ownerToken,
          direction: 'shared-by',
          partnerId: _partnerSharingId,
          reason: 'Expected the 057 owner API list to drop the removed partner',
        );

        container = await _restartAuthenticatedApp(
          tester,
          email: _partnerSharingEmail,
          password: partnerPassword,
        );
        await _resetAndSyncRemoteState(tester, container);
        drift = container.read(driftProvider);
        await _waitForPartnerMissing(
          tester,
          drift,
          ownerId,
          _partnerSharingId,
          reason:
              'Expected the 057 partner app to drop the incoming share after refresh',
        );
        await _waitForPartnerListMissing(
          tester,
          accessToken: partnerToken,
          direction: 'shared-with',
          partnerId: ownerId,
          reason:
              'Expected the 057 partner API list to drop the owner after removal',
        );
        await _waitForRejectedResponse(
          tester,
          () => _authenticatedApiRequest(
            'PUT',
            '/partners/$ownerId',
            accessToken: partnerToken,
            jsonBody: {'inTimeline': false},
          ),
          acceptedStatusCodes: const {404},
          reason:
              'Expected the 057 removed partner to lose update permission without stale cache access',
        );

        router = container.read(appRouterProvider);
        unawaited(
          router.push(const TabShellRoute(children: [DriftLibraryRoute()])),
        );
        await pumpUntilFound(
          tester,
          find.byType(DriftLibraryPage),
          timeout: const Duration(seconds: 30),
        );
        await _pumpFor(tester, const Duration(milliseconds: 500));
        expect(find.byKey(Key('partner-shared-with-$ownerId')), findsNothing);
      },
    );

    _realStackSessionTest(
      'MOB-UI-058-$_caseSuffix',
      'searches text suggestions and empty states',
      (tester) async {
        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = const Size(430, 932);
        addTearDown(tester.view.reset);

        await _loadAuthenticatedApp(
          tester,
          overrideCancellation: true,
          closeDriftOnDispose: false,
        );
        final container = _containerOfApp(tester);
        final apiService = container.read(apiServiceProvider);
        final assetsApi = apiService.assetsApi;
        final searchApi = apiService.searchApi;
        final searchService = container.read(searchServiceProvider);
        final createdRemoteAssetIds = <String>[];

        addTearDown(() async {
          for (final assetId in createdRemoteAssetIds) {
            await _deleteTestAssetBestEffort(assetsApi, assetId);
          }
        });

        await _resetAndSyncRemoteState(tester, container);

        final runToken = DateTime.now()
            .toUtc()
            .microsecondsSinceEpoch
            .toString();
        final sharedNeedle = 'search-058-$runToken';
        final contextNeedle = 'context-058-$runToken';
        final filenameNeedle = '$sharedNeedle-東京';
        final descriptionNeedle = 'gallery description 058 cafe $runToken';
        final ocrNeedle = 'boarding gate 058 $runToken';
        final cameraMake = 'ImmichE2E058-$runToken';
        const cameraModel = 'SearchTextSuggestions';
        final baseCreatedAt = DateTime.utc(2026, 2, 28, 12);

        final firstName = 'immich-e2e-$filenameNeedle-alpha.jpg';
        final firstAssetId = await _uploadGeneratedJpegAsSecondClient(
          firstName,
          baseCreatedAt,
          sourceMetadata: {
            'width': 96,
            'height': 64,
            'device_make': cameraMake,
            'device_model': cameraModel,
            'immich_description': '$descriptionNeedle primary',
            'immich_ocr_text': '$ocrNeedle primary',
          },
        );
        createdRemoteAssetIds.add(firstAssetId);

        final secondAssetId = await _uploadGeneratedJpegAsSecondClient(
          'immich-e2e-$filenameNeedle-beta.jpg',
          baseCreatedAt.add(const Duration(minutes: 1)),
          sourceMetadata: {
            'width': 96,
            'height': 64,
            'device_make': cameraMake,
            'device_model': cameraModel,
            'immich_description': 'secondary search description $runToken',
            'immich_ocr_text': 'secondary OCR $runToken',
          },
        );
        createdRemoteAssetIds.add(secondAssetId);

        final createdTags = await container
            .read(tagProvider.notifier)
            .upsertTags([contextNeedle]);
        expect(createdTags, hasLength(1));
        final taggedCount = await container
            .read(tagProvider.notifier)
            .bulkTagAssets([firstAssetId], [createdTags.single.id]);
        expect(taggedCount, 1);

        final syncSuccess = await container
            .read(syncStreamServiceProvider)
            .sync();
        expect(syncSuccess, isTrue);
        await _waitForRemoteAssetState(
          tester,
          container,
          firstAssetId,
          (asset) => asset.isRemoteOnly && asset.isImage && !asset.isTrashed,
          reason: 'Expected the primary 058 search asset to sync locally',
        );
        await _waitForRemoteAssetState(
          tester,
          container,
          secondAssetId,
          (asset) => asset.isRemoteOnly && asset.isImage && !asset.isTrashed,
          reason: 'Expected the secondary 058 search asset to sync locally',
        );

        final contextServer = await _waitForServerSmartSearchResponse(
          tester,
          searchApi,
          api.SmartSearchDto(
            query: api.Optional.present(contextNeedle),
            visibility: const api.Optional.present(
              api.AssetVisibility.timeline,
            ),
            page: const api.Optional.present(1),
            size: const api.Optional.present(10),
          ),
          (response) {
            final ids = _serverSearchAssetIds(response);
            return ids.contains(firstAssetId) && !ids.contains(secondAssetId);
          },
          reason:
              'Expected context smart search to match the tagged 058 asset only',
        );
        expect(_serverSearchAssetIds(contextServer), contains(firstAssetId));

        final filenameServer = await _waitForServerSearchResponse(
          tester,
          searchApi,
          _metadataSearchDto(
            filename: filenameNeedle,
            type: api.AssetTypeEnum.IMAGE,
            visibility: api.AssetVisibility.timeline,
          ),
          (response) => _serverSearchAssetIds(
            response,
          ).containsAll({firstAssetId, secondAssetId}),
          reason: 'Expected filename search to match both 058 fixtures',
        );
        expect(
          _serverSearchAssetIds(filenameServer),
          containsAll({firstAssetId, secondAssetId}),
        );

        final descriptionServer = await _waitForServerSearchResponse(
          tester,
          searchApi,
          _metadataSearchDto(
            description: descriptionNeedle,
            type: api.AssetTypeEnum.IMAGE,
          ),
          (response) {
            final ids = _serverSearchAssetIds(response);
            return ids.contains(firstAssetId) && !ids.contains(secondAssetId);
          },
          reason:
              'Expected description search to match only the primary 058 asset',
        );
        expect(
          _serverSearchAssetIds(descriptionServer),
          contains(firstAssetId),
        );

        final ocrServer = await _waitForServerSearchResponse(
          tester,
          searchApi,
          _metadataSearchDto(ocr: ocrNeedle, type: api.AssetTypeEnum.IMAGE),
          (response) {
            final ids = _serverSearchAssetIds(response);
            return ids.contains(firstAssetId) && !ids.contains(secondAssetId);
          },
          reason: 'Expected OCR search to match only the primary 058 asset',
        );
        expect(_serverSearchAssetIds(ocrServer), contains(firstAssetId));

        final cameraSuggestions = await _waitForSearchSuggestions(
          tester,
          searchService,
          api.SearchSuggestionType.cameraMake,
          (values) => values.contains(cameraMake),
          reason:
              'Expected camera-make suggestions to include the 058 fixture make',
        );
        expect(cameraSuggestions, contains(cameraMake));

        final pageOne = await _waitForServerSearchResponse(
          tester,
          searchApi,
          _metadataSearchDto(
            filename: filenameNeedle,
            page: 1,
            size: 1,
            type: api.AssetTypeEnum.IMAGE,
            visibility: api.AssetVisibility.timeline,
          ),
          (response) =>
              response.assets.total >= 2 && response.assets.items.length == 1,
          reason: 'Expected the first 058 filename page to contain one asset',
        );
        final pageTwo = await _waitForServerSearchResponse(
          tester,
          searchApi,
          _metadataSearchDto(
            filename: filenameNeedle,
            page: 2,
            size: 1,
            type: api.AssetTypeEnum.IMAGE,
            visibility: api.AssetVisibility.timeline,
          ),
          (response) =>
              response.assets.total == pageOne.assets.total &&
              response.assets.items.length == 1,
          reason: 'Expected the second 058 filename page to be stable',
        );
        expect(
          _serverSearchAssetIds(
            pageOne,
          ).intersection(_serverSearchAssetIds(pageTwo)),
          isEmpty,
        );

        await _selectPrimaryNavigationTab(tester, kSearchTabIndex);
        await pumpUntilFound(
          tester,
          find.byType(DriftSearchPage),
          timeout: const Duration(seconds: 30),
        );
        await pumpUntilFound(
          tester,
          find.byKey(const Key('search-suggestions')),
          timeout: const Duration(seconds: 30),
        );
        await _tapHitTestableFinder(
          tester,
          find.byKey(const Key('search-quick-link-recently-added')),
        );
        await pumpUntilFound(
          tester,
          find.byType(DriftRecentlyAddedPage),
          timeout: const Duration(seconds: 30),
        );
        await container.read(appRouterProvider).maybePop();
        await pumpUntilFound(
          tester,
          find.byType(DriftSearchPage),
          timeout: const Duration(seconds: 30),
        );

        await _selectSearchTextType(tester, const Key('search-type-context'));
        await _submitSearchText(tester, contextNeedle);
        await _waitForPaginatedSearchAssetIds(
          tester,
          container,
          (ids) => ids.contains(firstAssetId) && !ids.contains(secondAssetId),
          reason:
              'Expected context UI search to show only the primary 058 asset',
        );
        await pumpUntilFound(
          tester,
          find.byKey(const Key('search-result-grid')),
          timeout: const Duration(seconds: 30),
        );

        await _selectSearchTextType(tester, const Key('search-type-filename'));
        await _submitSearchText(tester, filenameNeedle);
        final filenameUiIds = await _waitForPaginatedSearchAssetIds(
          tester,
          container,
          (ids) => ids.containsAll({firstAssetId, secondAssetId}),
          reason: 'Expected filename UI search to show both 058 assets',
        );
        expect(filenameUiIds.length, filenameUiIds.toSet().length);
        await _exerciseTimelineUiPagination(tester);

        await _selectSearchTextType(
          tester,
          const Key('search-type-description'),
        );
        await _submitSearchText(tester, 'transient-$runToken');
        await _pumpFor(tester, const Duration(milliseconds: 100));
        await _submitSearchText(tester, descriptionNeedle);
        await _waitForPaginatedSearchAssetIds(
          tester,
          container,
          (ids) => ids.contains(firstAssetId) && !ids.contains(secondAssetId),
          reason:
              'Expected description UI search to settle on the latest rapid query',
        );

        await _selectSearchTextType(tester, const Key('search-type-ocr'));
        await _submitSearchText(tester, ocrNeedle);
        await _waitForPaginatedSearchAssetIds(
          tester,
          container,
          (ids) => ids.contains(firstAssetId) && !ids.contains(secondAssetId),
          reason: 'Expected OCR UI search to show only the primary 058 asset',
        );

        await _submitSearchText(tester, 'immich-e2e-no-result-$runToken');
        final noResultIds = await _waitForPaginatedSearchAssetIds(
          tester,
          container,
          (ids) => ids.isEmpty,
          reason: 'Expected no-result UI search to return an empty asset set',
        );
        expect(noResultIds, isEmpty);
        await pumpUntilFound(
          tester,
          find.byKey(const Key('search-no-results')),
          timeout: const Duration(seconds: 30),
        );

        await _submitSearchText(tester, '');
        await pumpUntilFound(
          tester,
          find.byKey(const Key('search-suggestions')),
          timeout: const Duration(seconds: 30),
        );
      },
    );

    _realStackSessionTest(
      'MOB-UI-059-$_caseSuffix',
      'applies search filters and clears them',
      (tester) async {
        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = const Size(430, 932);
        addTearDown(tester.view.reset);

        await _loadAuthenticatedApp(
          tester,
          overrideCancellation: true,
          closeDriftOnDispose: false,
        );
        final container = _containerOfApp(tester);
        final apiService = container.read(apiServiceProvider);
        final assetsApi = apiService.assetsApi;
        final albumsApi = apiService.albumsApi;
        final peopleApi = apiService.peopleApi;
        final searchApi = apiService.searchApi;
        final searchService = container.read(searchServiceProvider);
        final createdRemoteAssetIds = <String>[];
        String? albumId;
        String? personId;

        addTearDown(() async {
          final createdPersonId = personId;
          if (createdPersonId != null) {
            await _deletePersonBestEffort(peopleApi, createdPersonId);
          }
          final createdAlbumId = albumId;
          if (createdAlbumId != null) {
            await _deleteAlbumBestEffort(albumsApi, createdAlbumId);
          }
          for (final assetId in createdRemoteAssetIds) {
            await _deleteTestAssetBestEffort(assetsApi, assetId);
          }
        });

        await _resetAndSyncRemoteState(tester, container);

        final runToken = DateTime.now()
            .toUtc()
            .microsecondsSinceEpoch
            .toString();
        final sharedNeedle = 'filter-059-$runToken';
        final tagValue = 'MOB-UI-059-$runToken';
        final personName = 'Immich E2E Person 059 $runToken';
        final country = 'E2E Country 059 $runToken';
        const state = 'E2E State 059';
        final city = 'E2E City 059 $runToken';
        final cameraMake = 'ImmichE2E059-$runToken';
        const cameraModel = 'SearchFilters';
        final baseCreatedAt = DateTime.utc(2026, 3, 1, 12);
        final takenAfter = baseCreatedAt.subtract(const Duration(minutes: 1));
        final takenBefore = baseCreatedAt.add(const Duration(minutes: 10));

        final targetId = await _uploadGeneratedJpegAsSecondClient(
          'immich-e2e-$sharedNeedle-target.jpg',
          baseCreatedAt,
          isFavorite: true,
          sourceMetadata: {
            'width': 96,
            'height': 64,
            'device_make': cameraMake,
            'device_model': cameraModel,
            'country': country,
            'state': state,
            'city': city,
            'latitude': 37.7749,
            'longitude': -122.4194,
            'immich_rating': 4,
          },
        );
        createdRemoteAssetIds.add(targetId);

        final controlId = await _uploadGeneratedJpegAsSecondClient(
          'immich-e2e-$sharedNeedle-control.jpg',
          baseCreatedAt.add(const Duration(minutes: 1)),
          sourceMetadata: {
            'width': 96,
            'height': 64,
            'device_make': 'ImmichE2E059-Control',
            'device_model': 'SearchFiltersControl',
            'country': 'Other Country 059',
            'state': 'Other State 059',
            'city': 'Other City 059',
            'immich_rating': 2,
          },
        );
        createdRemoteAssetIds.add(controlId);

        final archiveId = await _uploadGeneratedJpegAsSecondClient(
          'immich-e2e-$sharedNeedle-archive.jpg',
          baseCreatedAt.add(const Duration(minutes: 2)),
          isFavorite: true,
          visibility: api.AssetVisibility.archive,
          sourceMetadata: {
            'width': 96,
            'height': 64,
            'device_make': cameraMake,
            'device_model': cameraModel,
            'country': country,
            'state': state,
            'city': city,
            'latitude': 37.7749,
            'longitude': -122.4194,
            'immich_rating': 4,
          },
        );
        createdRemoteAssetIds.add(archiveId);

        final videoId = await _uploadGeneratedMp4AsSecondClient(
          'immich-e2e-$sharedNeedle-video.mp4',
          baseCreatedAt.add(const Duration(minutes: 3)),
        );
        createdRemoteAssetIds.add(videoId);

        final createdTags = await container
            .read(tagProvider.notifier)
            .upsertTags([tagValue]);
        expect(createdTags, hasLength(1));
        final tagId = createdTags.single.id;
        final taggedCount = await container
            .read(tagProvider.notifier)
            .bulkTagAssets([targetId], [tagId]);
        expect(taggedCount, 1);

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
        final createdPersonId = createdPerson!.id;
        personId = createdPersonId;
        await _createFaceAsSecondClient(
          assetId: targetId,
          personId: createdPersonId,
          x: 6,
          y: 7,
          width: 24,
          height: 28,
          imageWidth: 96,
          imageHeight: 64,
        );

        final albumName = 'immich-e2e-search-filter-059-$runToken';
        final createdAlbum = await albumsApi.createAlbum(
          api.CreateAlbumDto(
            albumName: albumName,
            assetIds: api.Optional.present([targetId]),
          ),
        );
        expect(createdAlbum, isNotNull);
        albumId = createdAlbum!.id;

        final syncSuccess = await container
            .read(syncStreamServiceProvider)
            .sync();
        expect(syncSuccess, isTrue);
        for (final assetId in createdRemoteAssetIds) {
          await _waitForRemoteAssetState(
            tester,
            container,
            assetId,
            (asset) => !asset.isTrashed,
            reason: 'Expected 059 fixture asset $assetId to sync locally',
          );
        }

        final personDto = PersonDto(
          id: createdPersonId,
          isHidden: false,
          name: personName,
          thumbnailPath: createdPerson.thumbnailPath,
        );

        final fullFilter = _searchFilter(
          filename: sharedNeedle,
          people: {personDto},
          country: country,
          state: state,
          city: city,
          tagIds: [tagId],
          make: cameraMake,
          model: cameraModel,
          takenAfter: takenAfter,
          takenBefore: takenBefore,
          isFavorite: true,
          mediaType: AssetType.image,
          rating: 4,
        );
        final fullServer = await _waitForServerSearchResponse(
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
            rating: 4,
            tagIds: [tagId],
            personIds: [createdPersonId],
            country: country,
            state: state,
            city: city,
          ),
          (response) {
            final ids = _serverSearchAssetIds(response);
            return ids.contains(targetId) &&
                !ids.contains(controlId) &&
                !ids.contains(archiveId) &&
                !ids.contains(videoId);
          },
          reason:
              'Expected all 059 server filters to intersect on the target asset only',
        );
        final fullAppIds = await _waitForSearchServiceAssetIds(
          tester,
          searchService,
          fullFilter,
          (ids) => ids.contains(targetId) && ids.length == 1,
          reason:
              'Expected all 059 app filters to intersect on the target asset only',
        );
        expect(fullAppIds, _serverSearchAssetIds(fullServer));

        final videoServer = await _waitForServerSearchResponse(
          tester,
          searchApi,
          _metadataSearchDto(
            filename: sharedNeedle,
            type: api.AssetTypeEnum.VIDEO,
            visibility: api.AssetVisibility.timeline,
          ),
          (response) => _serverSearchAssetIds(response).contains(videoId),
          reason: 'Expected media type filter to find the 059 video fixture',
        );
        expect(_serverSearchAssetIds(videoServer), contains(videoId));

        final notInAlbumServer = await _waitForServerSearchResponse(
          tester,
          searchApi,
          _metadataSearchDto(
            filename: sharedNeedle,
            type: api.AssetTypeEnum.IMAGE,
            visibility: api.AssetVisibility.timeline,
            isNotInAlbum: true,
          ),
          (response) {
            final ids = _serverSearchAssetIds(response);
            return ids.contains(controlId) && !ids.contains(targetId);
          },
          reason:
              'Expected not-in-album filter to exclude the album member and include the loose image',
        );
        expect(_serverSearchAssetIds(notInAlbumServer), contains(controlId));

        final archiveServer = await _waitForServerSearchResponse(
          tester,
          searchApi,
          _metadataSearchDto(
            filename: sharedNeedle,
            isFavorite: true,
            type: api.AssetTypeEnum.IMAGE,
            visibility: api.AssetVisibility.archive,
          ),
          (response) => _serverSearchAssetIds(response).contains(archiveId),
          reason:
              'Expected display archive filter to find the 059 archived image',
        );
        expect(_serverSearchAssetIds(archiveServer), contains(archiveId));

        await _selectPrimaryNavigationTab(tester, kSearchTabIndex);
        await pumpUntilFound(
          tester,
          find.byType(DriftSearchPage),
          timeout: const Duration(seconds: 30),
        );
        await _selectSearchTextType(tester, const Key('search-type-filename'));
        await _submitSearchText(tester, sharedNeedle);
        await _waitForPaginatedSearchAssetIds(
          tester,
          container,
          (ids) =>
              ids.containsAll({targetId, controlId, videoId}) &&
              !ids.contains(archiveId),
          reason:
              'Expected initial 059 UI filename search to include timeline fixtures only',
        );

        await _openSearchFilterSheet(tester, const Key('media_type_chip'));
        await _tapHitTestableFinder(
          tester,
          find.byKey(const Key('search-media-type-image')),
        );
        await _applySearchFilterSheet(tester);
        await _waitForPaginatedSearchAssetIds(
          tester,
          container,
          (ids) =>
              ids.containsAll({targetId, controlId}) &&
              !ids.contains(videoId) &&
              !ids.contains(archiveId),
          reason:
              'Expected UI media type image filter to exclude the 059 video',
        );
        await pumpUntilFound(
          tester,
          find.text('image'.tr()),
          timeout: const Duration(seconds: 30),
        );

        await _openSearchFilterSheet(
          tester,
          const Key('search-filter-chip-display'),
        );
        await _tapHitTestableFinder(
          tester,
          find.byKey(const Key('search-display-favorite')),
        );
        await _applySearchFilterSheet(tester);
        await _waitForPaginatedSearchAssetIds(
          tester,
          container,
          (ids) => ids.contains(targetId) && ids.length == 1,
          reason:
              'Expected UI favorite display filter to narrow 059 results to the favorite image',
        );
        await pumpUntilFound(
          tester,
          find.text('favorite'.tr()),
          timeout: const Duration(seconds: 30),
        );

        await _openSearchFilterSheet(
          tester,
          const Key('search-filter-chip-rating'),
        );
        await _tapHitTestableFinder(
          tester,
          find.byKey(const Key('search-rating-4')),
        );
        await _applySearchFilterSheet(tester);
        await _waitForPaginatedSearchAssetIds(
          tester,
          container,
          (ids) => ids.contains(targetId) && ids.length == 1,
          reason: 'Expected UI rating filter to keep the 059 rated target only',
        );

        await _openSearchFilterSheet(
          tester,
          const Key('search-filter-chip-rating'),
        );
        await _clearSearchFilterSheet(tester);
        await _openSearchFilterSheet(
          tester,
          const Key('search-filter-chip-display'),
        );
        await _clearSearchFilterSheet(tester);
        await _waitForPaginatedSearchAssetIds(
          tester,
          container,
          (ids) =>
              ids.containsAll({targetId, controlId}) &&
              !ids.contains(videoId) &&
              !ids.contains(archiveId),
          reason:
              'Expected clearing rating/display filters to restore 059 image results',
        );

        await _openSearchFilterSheet(
          tester,
          const Key('search-filter-chip-display'),
        );
        await _tapHitTestableFinder(
          tester,
          find.byKey(const Key('search-display-not-in-album')),
        );
        await _applySearchFilterSheet(tester);
        await _waitForPaginatedSearchAssetIds(
          tester,
          container,
          (ids) =>
              ids.contains(controlId) &&
              !ids.contains(targetId) &&
              !ids.contains(videoId),
          reason:
              'Expected UI not-in-album filter to exclude the 059 album member',
        );

        await _openSearchFilterSheet(tester, const Key('media_type_chip'));
        await _clearSearchFilterSheet(tester);
        await _openSearchFilterSheet(
          tester,
          const Key('search-filter-chip-display'),
        );
        await _clearSearchFilterSheet(tester);
        await _submitSearchText(tester, '');
        await pumpUntilFound(
          tester,
          find.byKey(const Key('search-suggestions')),
          timeout: const Duration(seconds: 30),
        );
      },
    );

    _realStackSessionTest(
      'MOB-UI-060-$_caseSuffix',
      'browses and filters map locations',
      (tester) async {
        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = const Size(430, 932);
        addTearDown(tester.view.reset);

        await _loadAuthenticatedApp(
          tester,
          overrideCancellation: true,
          closeDriftOnDispose: false,
          resetSyncAcksBeforeStart: true,
        );
        final container = _containerOfApp(tester);
        final apiService = container.read(apiServiceProvider);
        final assetsApi = apiService.assetsApi;
        final searchApi = apiService.searchApi;
        final assetService = container.read(assetServiceProvider);
        final createdRemoteAssetIds = <String>[];

        addTearDown(() async {
          for (final assetId in createdRemoteAssetIds) {
            await _deleteTestAssetBestEffort(assetsApi, assetId);
          }
        });

        await _resetAndSyncRemoteState(tester, container);

        final currentUser = container.read(currentUserProvider);
        expect(currentUser, isNotNull);
        final userId = currentUser!.id;

        final runToken = DateTime.now()
            .toUtc()
            .microsecondsSinceEpoch
            .toString();
        final sharedNeedle = 'map-060-$runToken';
        final city = 'E2E Map City 060 $runToken';
        const state = 'E2E Map State 060';
        const country = 'E2E Map Country 060';
        final baseCreatedAt = DateTime.now().toUtc();
        final oldCreatedAt = baseCreatedAt.subtract(const Duration(days: 90));
        const targetLocation = LatLng(37.7749, -122.4194);
        const farLocation = LatLng(35.6895, 139.6917);
        final bayBounds = LatLngBounds(
          southwest: const LatLng(37.0, -123.0),
          northeast: const LatLng(38.2, -121.5),
        );
        final tokyoBounds = LatLngBounds(
          southwest: const LatLng(35.0, 139.0),
          northeast: const LatLng(36.2, 140.3),
        );

        Future<String> uploadMapAsset(
          String label,
          DateTime createdAt, {
          LatLng? location,
          bool isFavorite = false,
          api.AssetVisibility? visibility,
          String? assetCity,
        }) async {
          final metadata = <String, Object>{
            'width': 96,
            'height': 64,
            'country': country,
            'state': state,
            'city': assetCity ?? city,
            'device_make': 'ImmichE2E060',
            'device_model': 'MapFlow',
            if (location != null) ...{
              'latitude': location.latitude,
              'longitude': location.longitude,
            },
          };
          final assetId = await _uploadGeneratedJpegAsSecondClient(
            'immich-e2e-$sharedNeedle-$label.jpg',
            createdAt,
            isFavorite: isFavorite,
            visibility: visibility,
            sourceMetadata: metadata,
          );
          createdRemoteAssetIds.add(assetId);
          return assetId;
        }

        final targetId = await uploadMapAsset(
          'target',
          baseCreatedAt,
          location: targetLocation,
          isFavorite: true,
        );
        final sameCoordinateId = await uploadMapAsset(
          'same-coordinate',
          baseCreatedAt.add(const Duration(minutes: 1)),
          location: targetLocation,
        );
        final farId = await uploadMapAsset(
          'far',
          baseCreatedAt.add(const Duration(minutes: 2)),
          location: farLocation,
          assetCity: 'E2E Far Map City 060 $runToken',
        );
        final archivedId = await uploadMapAsset(
          'archived',
          baseCreatedAt.add(const Duration(minutes: 3)),
          location: targetLocation,
          visibility: api.AssetVisibility.archive,
        );
        final oldId = await uploadMapAsset(
          'old',
          oldCreatedAt,
          location: const LatLng(37.7800, -122.4100),
        );
        final noCoordinateId = await uploadMapAsset(
          'no-coordinate',
          baseCreatedAt.add(const Duration(minutes: 4)),
          assetCity: 'E2E No Coordinate Map City 060 $runToken',
        );

        final syncSuccess = await container
            .read(syncStreamServiceProvider)
            .sync();
        expect(syncSuccess, isTrue);

        final syncedAssets = <String, BaseAsset>{};
        for (final assetId in createdRemoteAssetIds) {
          syncedAssets[assetId] = await _waitForRemoteAssetState(
            tester,
            container,
            assetId,
            (asset) => !asset.isTrashed,
            reason: 'Expected 060 fixture asset $assetId to sync locally',
          );
        }

        final targetExif = await _waitForRemoteExifState(
          tester,
          assetService,
          syncedAssets[targetId]!,
          (exif) =>
              exif.hasCoordinates &&
              (exif.latitude! - targetLocation.latitude).abs() < 0.0001 &&
              (exif.longitude! - targetLocation.longitude).abs() < 0.0001,
          reason: 'Expected 060 target asset to keep GPS metadata locally',
        );
        expect(targetExif.city, city);

        final citySearch = await _waitForServerSearchResponse(
          tester,
          searchApi,
          _metadataSearchDto(
            filename: sharedNeedle,
            city: city,
            type: api.AssetTypeEnum.IMAGE,
            visibility: api.AssetVisibility.timeline,
          ),
          (response) {
            final ids = _serverSearchAssetIds(response);
            return ids.containsAll({targetId, sameCoordinateId, oldId}) &&
                !ids.contains(farId) &&
                !ids.contains(archivedId);
          },
          reason: 'Expected 060 city search to match only timeline city assets',
        );
        expect(
          _serverSearchAssetIds(citySearch),
          containsAll({targetId, sameCoordinateId, oldId}),
        );

        final places = await _waitForLocalPlacesState(
          tester,
          assetService,
          userId,
          (places) => places.any((place) => place.$1 == city),
          reason: 'Expected 060 city to appear in local places',
        );
        expect(places.map((place) => place.$1), contains(city));

        final defaultMarkerIds = await _waitForMapMarkerAssetIds(
          tester,
          container,
          (ids) =>
              ids.containsAll({targetId, sameCoordinateId, oldId}) &&
              !ids.contains(farId) &&
              !ids.contains(archivedId) &&
              !ids.contains(noCoordinateId),
          bounds: bayBounds,
          options: TimelineMapOptions(bounds: bayBounds),
          reason: 'Expected 060 bay bounds to include only timeline GPS assets',
        );
        expect(defaultMarkerIds, containsAll({targetId, sameCoordinateId}));

        await _waitForMapMarkerAssetIds(
          tester,
          container,
          (ids) =>
              ids.contains(targetId) &&
              !ids.contains(sameCoordinateId) &&
              !ids.contains(oldId),
          bounds: bayBounds,
          options: TimelineMapOptions(bounds: bayBounds, onlyFavorites: true),
          reason: 'Expected 060 favorite-only map filter to keep target only',
        );

        await _waitForMapMarkerAssetIds(
          tester,
          container,
          (ids) => ids.contains(archivedId),
          bounds: bayBounds,
          options: TimelineMapOptions(bounds: bayBounds, includeArchived: true),
          reason: 'Expected 060 archived map filter to include archive asset',
        );

        await _waitForMapMarkerAssetIds(
          tester,
          container,
          (ids) => ids.contains(targetId) && !ids.contains(oldId),
          bounds: bayBounds,
          options: TimelineMapOptions(bounds: bayBounds, relativeDays: 30),
          reason: 'Expected 060 relative date map filter to exclude old asset',
        );

        await _waitForMapMarkerAssetIds(
          tester,
          container,
          (ids) => ids.contains(oldId) && !ids.contains(targetId),
          bounds: bayBounds,
          options: TimelineMapOptions(
            bounds: bayBounds,
            timeRange: TimeRange(
              from: oldCreatedAt.subtract(const Duration(minutes: 1)),
              to: oldCreatedAt.add(const Duration(minutes: 1)),
            ),
          ),
          reason: 'Expected 060 custom date map filter to isolate old asset',
        );

        await _waitForMapMarkerAssetIds(
          tester,
          container,
          (ids) => ids.contains(farId) && !ids.contains(targetId),
          bounds: tokyoBounds,
          options: TimelineMapOptions(bounds: tokyoBounds),
          reason: 'Expected 060 panned map bounds to isolate far asset',
        );

        final router = container.read(appRouterProvider);
        unawaited(
          router.push(DriftPlaceRoute(currentLocation: targetLocation)),
        );
        await pumpUntilFound(
          tester,
          find.byType(DriftPlacePage),
          timeout: const Duration(seconds: 30),
        );
        await pumpUntilFound(
          tester,
          find.text(city),
          timeout: const Duration(seconds: 30),
        );
        await _tapHitTestableFinder(
          tester,
          find.text(city),
          reason: 'Expected 060 place tile to be tappable',
        );
        await pumpUntilFound(
          tester,
          find.byType(DriftPlaceDetailPage),
          timeout: const Duration(seconds: 30),
        );
        await pumpUntilFound(
          tester,
          find.text(city),
          timeout: const Duration(seconds: 30),
        );
        await router.maybePop();
        await router.maybePop();

        unawaited(router.push(DriftMapRoute(initialLocation: targetLocation)));
        await pumpUntilFound(
          tester,
          find.byType(DriftMapPage),
          timeout: const Duration(seconds: 30),
        );
        await pumpUntilFound(
          tester,
          find.byKey(const Key('drift-map-settings-button')),
          timeout: const Duration(seconds: 30),
        );
        await _tapHitTestableFinder(
          tester,
          find.byKey(const Key('drift-map-settings-button')),
          reason: 'Expected 060 map settings button to be tappable',
        );
        await pumpUntilFound(
          tester,
          find.byKey(const Key('map-settings-favorite-only')),
          timeout: const Duration(seconds: 30),
        );
        final favoriteOnlyTile =
            find.byKey(const Key('map-settings-favorite-only'));
        await tester.ensureVisible(favoriteOnlyTile.first);
        await _tapHitTestableFinder(
          tester,
          favoriteOnlyTile,
          reason: 'Expected 060 favorite-only setting tile to be tappable',
        );
        await _pumpFor(tester, const Duration(milliseconds: 300));
        expect(container.read(mapStateProvider).onlyFavorites, isTrue);
        await router.maybePop();
        await pumpUntilFound(
          tester,
          find.byKey(const Key('drift-map-my-location-button')),
          timeout: const Duration(seconds: 30),
        );
        await router.maybePop();

        final selectedLocation = router.push<LatLng>(
          MapLocationPickerRoute(initialLatLng: targetLocation),
        );
        await pumpUntilFound(
          tester,
          find.byType(MapLocationPickerPage),
          timeout: const Duration(seconds: 30),
        );
        await pumpUntilFound(
          tester,
          find.text('37.7749, -122.4194'),
          timeout: const Duration(seconds: 30),
        );
        await _tapHitTestableFinder(
          tester,
          find.byKey(const Key('map-location-picker-use-location')),
          reason: 'Expected 060 location picker use button to be tappable',
        );
        final picked = await selectedLocation;
        expect(picked?.latitude, targetLocation.latitude);
        expect(picked?.longitude, targetLocation.longitude);
      },
    );

    _realStackSessionTest(
      'MOB-UI-061-$_caseSuffix',
      'manages people details, merges people, and hides people',
      (tester) async {
        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = const Size(430, 932);
        addTearDown(tester.view.reset);

        await _loadAuthenticatedApp(
          tester,
          overrideCancellation: true,
          closeDriftOnDispose: false,
          resetSyncAcksBeforeStart: true,
        );
        var container = _containerOfApp(tester);
        final apiService = container.read(apiServiceProvider);
        final assetsApi = apiService.assetsApi;
        final peopleApi = apiService.peopleApi;
        var peopleService = container.read(driftPeopleServiceProvider);
        final createdRemoteAssetIds = <String>[];
        final createdPeopleIds = <String>{};

        addTearDown(() async {
          for (final personId in createdPeopleIds) {
            await _deletePersonBestEffort(peopleApi, personId);
          }
          for (final assetId in createdRemoteAssetIds) {
            await _deleteTestAssetBestEffort(assetsApi, assetId);
          }
        });

        await _resetAndSyncRemoteState(tester, container);

        final runToken = DateTime.now()
            .toUtc()
            .microsecondsSinceEpoch
            .toString();
        final sharedNeedle = 'people-061-$runToken';
        final primaryName = 'Immich E2E Person 061 Primary $runToken';
        final mergeName = 'Immich E2E Person 061 Merge $runToken';
        final hiddenName = 'Immich E2E Person 061 Hidden $runToken';
        final editedName = 'Immich E2E Person 061 Edited $runToken';
        final birthday = DateTime(DateTime.now().year - 30, 1, 1);
        final baseCreatedAt = DateTime.utc(2026, 3, 2, 12);

        Future<String> createPerson(String name) async {
          final createdPerson = await peopleApi.createPerson(
            api.PersonCreateDto(
              name: api.Optional.present(name),
              isHidden: const api.Optional.present(false),
              isFavorite: const api.Optional.present(false),
              birthDate: const api.Optional.present(null),
              color: const api.Optional.present(null),
            ),
          );
          expect(createdPerson, isNotNull);
          createdPeopleIds.add(createdPerson!.id);
          return createdPerson.id;
        }

        Future<String> uploadPersonAsset(
          String label,
          String personId,
          int index,
        ) async {
          final createdAt = baseCreatedAt.add(Duration(minutes: index));
          final assetId = await _uploadGeneratedJpegAsSecondClient(
            'immich-e2e-$sharedNeedle-$label-$index.jpg',
            createdAt,
            sourceMetadata: {
              'width': 96,
              'height': 64,
              'device_make': 'ImmichE2E061',
              'device_model': 'PeopleManagement',
            },
          );
          createdRemoteAssetIds.add(assetId);
          await _createFaceAsSecondClient(
            assetId: assetId,
            personId: personId,
            x: 8 + index,
            y: 9 + index,
            width: 24,
            height: 28,
            imageWidth: 96,
            imageHeight: 64,
          );
          return assetId;
        }

        final primaryPersonId = await createPerson(primaryName);
        final mergePersonId = await createPerson(mergeName);
        final hiddenPersonId = await createPerson(hiddenName);
        final unnamedPersonId = await createPerson('');

        final primaryAssetIds = [
          await uploadPersonAsset('primary', primaryPersonId, 0),
          await uploadPersonAsset('primary', primaryPersonId, 1),
        ];
        final mergeAssetIds = [
          await uploadPersonAsset('merge', mergePersonId, 2),
          await uploadPersonAsset('merge', mergePersonId, 3),
        ];
        final hiddenAssetId = await uploadPersonAsset(
          'hidden',
          hiddenPersonId,
          4,
        );
        final unnamedAssetIds = [
          await uploadPersonAsset('unnamed', unnamedPersonId, 5),
          await uploadPersonAsset('unnamed', unnamedPersonId, 6),
          await uploadPersonAsset('unnamed', unnamedPersonId, 7),
        ];

        final syncSuccess = await container
            .read(syncStreamServiceProvider)
            .sync();
        expect(syncSuccess, isTrue);

        for (final assetId in createdRemoteAssetIds) {
          await _waitForRemoteAssetState(
            tester,
            container,
            assetId,
            (asset) => !asset.isTrashed,
            reason: 'Expected 061 fixture asset $assetId to sync locally',
          );
        }

        final initialPeople = await _waitForLocalPeopleState(
          tester,
          peopleService,
          (people) =>
              people.any((person) => person.id == primaryPersonId) &&
              people.any((person) => person.id == mergePersonId) &&
              people.any((person) => person.id == hiddenPersonId) &&
              people.any(
                (person) => person.id == unnamedPersonId && person.name.isEmpty,
              ),
          reason:
              'Expected 061 visible and unnamed people to sync into the people collection',
        );
        expect(
          initialPeople.map((person) => person.id),
          contains(primaryPersonId),
        );
        expect(
          initialPeople.map((person) => person.id),
          contains(unnamedPersonId),
        );

        final router = container.read(appRouterProvider);
        unawaited(router.push(const DriftPeopleCollectionRoute()));
        await _pumpUntilFoundWithReason(
          tester,
          find.byType(DriftPeopleCollectionPage),
          reason: 'Expected 061 people collection page to open',
          timeout: const Duration(seconds: 30),
        );
        await _tapHitTestableFinder(
          tester,
          find.byKey(const Key('people-collection-search-button')),
          reason: 'Expected 061 people search button to be tappable',
        );
        await _pumpUntilFoundWithReason(
          tester,
          find.byKey(const Key('people-collection-search-field')),
          reason: 'Expected 061 people search field to appear',
          timeout: const Duration(seconds: 30),
        );
        final peopleSearchInput = find.descendant(
          of: find.byKey(const Key('people-collection-search-field')),
          matching: find.byType(TextField),
        );
        await tester.enterText(peopleSearchInput, primaryName);
        await _pumpFor(tester, const Duration(milliseconds: 300));
        expect(find.text(primaryName), findsWidgets);
        expect(find.text(mergeName), findsNothing);

        final primaryPerson = initialPeople.singleWhere(
          (person) => person.id == primaryPersonId,
        );
        unawaited(router.push(DriftPersonRoute(person: primaryPerson)));
        await _pumpUntilFoundWithReason(
          tester,
          find.byType(DriftPersonPage),
          reason: 'Expected 061 person detail page to open',
          timeout: const Duration(seconds: 30),
        );
        await _pumpUntilFoundWithReason(
          tester,
          find.text(primaryName),
          reason: 'Expected 061 person detail to show the initial name',
          timeout: const Duration(seconds: 30),
        );

        await _tapHitTestableFinder(
          tester,
          find.byKey(Key('person-detail-name-$primaryPersonId')),
          reason: 'Expected 061 person name to open edit dialog',
        );
        await _pumpUntilFoundWithReason(
          tester,
          find.byKey(const Key('person-edit-name-field')),
          reason: 'Expected 061 person name edit field to appear',
          timeout: const Duration(seconds: 30),
        );
        await tester.enterText(
          find.byKey(const Key('person-edit-name-field')),
          editedName,
        );
        await _tapHitTestableFinder(
          tester,
          find.byKey(const Key('person-edit-name-save')),
          reason: 'Expected 061 person name save button to be tappable',
        );

        await _tapHitTestableFinder(
          tester,
          find.byKey(Key('person-detail-options-$primaryPersonId')),
          reason: 'Expected 061 person options button to be tappable',
        );
        await _pumpUntilFoundWithReason(
          tester,
          find.byKey(const Key('person-option-edit-birthday')),
          reason: 'Expected 061 person option sheet to show birthday action',
          timeout: const Duration(seconds: 30),
        );
        await _tapHitTestableFinder(
          tester,
          find.byKey(const Key('person-option-edit-birthday')),
          reason: 'Expected 061 birthday option to be tappable',
        );
        await _pumpUntilFoundWithReason(
          tester,
          find.byKey(const Key('person-edit-birthday-save')),
          reason: 'Expected 061 birthday edit dialog to appear',
          timeout: const Duration(seconds: 30),
        );
        await _tapHitTestableFinder(
          tester,
          find.byKey(const Key('person-edit-birthday-save')),
          reason: 'Expected 061 birthday save button to be tappable',
        );

        final editedPrimary = await _waitForLocalPersonState(
          tester,
          peopleService,
          primaryPersonId,
          (person) =>
              person != null &&
              person.name == editedName &&
              person.birthDate != null &&
              person.birthDate!.year == birthday.year &&
              person.birthDate!.month == birthday.month &&
              person.birthDate!.day == birthday.day,
          reason:
              'Expected 061 UI edits to persist to the local primary person',
        );
        expect(editedPrimary!.name, editedName);

        await _waitForServerPeopleState(
          tester,
          peopleApi,
          withHidden: true,
          matches: (people) => people.any(
            (person) =>
                person.id == primaryPersonId &&
                person.name == editedName &&
                person.birthDate?.year == birthday.year &&
                person.birthDate?.month == birthday.month &&
                person.birthDate?.day == birthday.day,
          ),
          reason:
              'Expected 061 UI edits to persist to the server primary person',
        );

        _expectBulkSuccess(
          await peopleApi.mergePerson(
            primaryPersonId,
            api.MergePersonDto(ids: [mergePersonId]),
          ),
          {mergePersonId},
          reason: 'Expected 061 merge API to accept the source person',
        );
        createdPeopleIds.remove(mergePersonId);
        await _resetAndSyncRemoteState(tester, container);

        for (final assetId in mergeAssetIds) {
          await _waitForAssetPeopleState(
            tester,
            peopleService,
            assetId,
            (people) =>
                people.any((person) => person.id == primaryPersonId) &&
                !people.any((person) => person.id == mergePersonId),
            reason:
                'Expected 061 merged asset $assetId to belong to the primary person locally',
          );
          expect(
            await _remoteAssetFaceRowCount(
              container.read(driftProvider),
              assetId,
              primaryPersonId,
            ),
            1,
          );
          expect(
            await _remoteAssetFaceRowCount(
              container.read(driftProvider),
              assetId,
              mergePersonId,
            ),
            0,
          );
        }

        final personTimeline = container
            .read(timelineFactoryProvider)
            .person(container.read(currentUserProvider)!.id, primaryPersonId);
        addTearDown(personTimeline.dispose);
        await _expectTimelineAssetSet(
          tester,
          personTimeline,
          includes: {...primaryAssetIds, ...mergeAssetIds},
          excludes: {hiddenAssetId, ...unnamedAssetIds},
          reason:
              'Expected 061 person timeline to include primary and merged assets only',
        );

        _expectBulkSuccess(
          await peopleApi.updatePeople(
            api.PeopleUpdateDto(
              people: [
                api.PeopleUpdateItem(
                  id: hiddenPersonId,
                  isHidden: const api.Optional.present(true),
                ),
              ],
            ),
          ),
          {hiddenPersonId},
          reason: 'Expected 061 hidden person update to succeed',
        );
        await _resetAndSyncRemoteState(tester, container);

        final visibleAfterHide = await _waitForLocalPeopleState(
          tester,
          peopleService,
          (people) =>
              people.any((person) => person.id == primaryPersonId) &&
              people.any((person) => person.id == unnamedPersonId) &&
              !people.any((person) => person.id == hiddenPersonId) &&
              !people.any((person) => person.id == mergePersonId),
          reason:
              'Expected 061 hidden and merged people to disappear from the local collection',
        );
        expect(
          visibleAfterHide.map((person) => person.id),
          isNot(contains(hiddenPersonId)),
        );
        expect(
          await _waitForAssetPeopleState(
            tester,
            peopleService,
            hiddenAssetId,
            (people) => people.isEmpty,
            reason:
                'Expected 061 hidden person to be filtered from asset people locally',
          ),
          isEmpty,
        );

        await _waitForServerPeopleState(
          tester,
          peopleApi,
          withHidden: true,
          matches: (people) => people.any(
            (person) => person.id == hiddenPersonId && person.isHidden,
          ),
          reason: 'Expected 061 server people list to retain hidden person',
        );
        await _waitForServerPeopleState(
          tester,
          peopleApi,
          withHidden: false,
          matches: (people) =>
              !people.any((person) => person.id == hiddenPersonId),
          reason:
              'Expected 061 visible server people list to exclude hidden person',
        );

        await router.maybePop();
        container = await _restartAuthenticatedApp(
          tester,
          email: _email,
          password: _password,
        );
        peopleService = container.read(driftPeopleServiceProvider);
        await _resetAndSyncRemoteState(tester, container);
        await _waitForLocalPersonState(
          tester,
          peopleService,
          primaryPersonId,
          (person) =>
              person != null &&
              person.name == editedName &&
              person.birthDate != null &&
              person.birthDate!.year == birthday.year &&
              person.birthDate!.month == birthday.month &&
              person.birthDate!.day == birthday.day,
          reason:
              'Expected 061 edited name and birthday to persist after restart',
        );
        await _waitForLocalPeopleState(
          tester,
          peopleService,
          (people) =>
              people.any((person) => person.id == primaryPersonId) &&
              !people.any((person) => person.id == hiddenPersonId) &&
              !people.any((person) => person.id == mergePersonId),
          reason:
              'Expected 061 hidden and merged people to remain filtered after restart',
        );
      },
    );

    _realStackSessionTest('MOB-UI-062-$_caseSuffix', 'updates account security and network settings', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(430, 932);
      addTearDown(tester.view.reset);

      await _loadAuthenticatedApp(
        tester,
        overrideCancellation: true,
        closeDriftOnDispose: false,
        resetSyncAcksBeforeStart: true,
      );
      var container = _containerOfApp(tester);
      var apiService = container.read(apiServiceProvider);
      final assetsApi = apiService.assetsApi;
      final originalEndpoint = Store.get(StoreKey.serverEndpoint);
      final originalServerUrl = Store.tryGet(StoreKey.serverUrl);
      final originalHeaders = Map<String, String>.from(container.read(appConfigProvider).network.customHeaders);
      final createdRemoteAssetIds = <String>[];
      var activePassword = _password;

      addTearDown(() async {
        for (final assetId in createdRemoteAssetIds) {
          await _deleteTestAssetBestEffort(assetsApi, assetId);
        }
        if (activePassword != _password) {
          final restored = await _changePasswordViaAuthEndpoint(
            currentPassword: activePassword,
            newPassword: _password,
          );
          if (restored) {
            activePassword = _password;
          }
        }
        await Store.put(StoreKey.serverEndpoint, originalEndpoint);
        if (originalServerUrl == null) {
          await Store.delete(StoreKey.serverUrl);
        } else {
          await Store.put(StoreKey.serverUrl, originalServerUrl);
        }
        await SettingsRepository.instance.write(SettingsKey.networkCustomHeaders, originalHeaders);
      });

      await _resetAndSyncRemoteState(tester, container);

      final currentUser = container.read(currentUserProvider);
      expect(currentUser, isNotNull);
      final runToken = DateTime.now().toUtc().microsecondsSinceEpoch.toString();
      final profileAssetId = await _uploadGeneratedJpegAsSecondClient(
        'immich-e2e-account-062-profile-$runToken.jpg',
        DateTime.now().toUtc(),
        sourceMetadata: {'width': 96, 'height': 64, 'device_make': 'ImmichE2E062', 'device_model': 'AccountSecurity'},
      );
      createdRemoteAssetIds.add(profileAssetId);

      final syncSuccess = await container.read(syncStreamServiceProvider).sync();
      expect(syncSuccess, isTrue);
      final profileAsset = await _waitForRemoteAssetState(
        tester,
        container,
        profileAssetId,
        (asset) => !asset.isTrashed,
        reason: 'Expected 062 profile source asset to sync locally',
      );

      final router = container.read(appRouterProvider);
      unawaited(router.push(ProfilePictureCropRoute(asset: profileAsset)));
      await _pumpUntilFoundWithReason(
        tester,
        find.byType(ProfilePictureCropPage),
        reason: 'Expected 062 profile crop page to open',
        timeout: const Duration(seconds: 30),
      );
      final cropSaveButton = find.byKey(const Key('profile-picture-crop-save'));
      await _pumpUntil(tester, () {
        final iconButton = find.descendant(of: cropSaveButton, matching: find.byType(IconButton));
        if (!tester.any(iconButton)) {
          return false;
        }

        return tester.widget<IconButton>(iconButton.first).onPressed != null;
      }, timeout: const Duration(seconds: 60));
      await _tapHitTestableFinder(
        tester,
        cropSaveButton,
        reason: 'Expected 062 profile crop save button to be tappable',
        timeout: const Duration(seconds: 60),
      );
      await _pumpUntil(
        tester,
        () =>
            container.read(uploadProfileImageProvider).status == UploadProfileStatus.success &&
            container.read(uploadProfileImageProvider).profileImagePath.isNotEmpty,
        timeout: const Duration(seconds: 60),
      );
      final uploadedProfilePath = container.read(uploadProfileImageProvider).profileImagePath;
      final refreshedUser = await container.read(userServiceProvider).refreshMyUser();
      expect(refreshedUser, isNotNull);
      expect(refreshedUser!.hasProfileImage, isTrue);

      final profileImageResponse = await http.get(
        Uri.parse('${Store.get(StoreKey.serverEndpoint)}/users/${currentUser!.id}/profile-image'),
        headers: {...ApiService.getRequestHeaders(), 'Authorization': 'Bearer ${Store.get(StoreKey.accessToken)}'},
      );
      expect(profileImageResponse.statusCode, HttpStatus.ok);
      expect(profileImageResponse.bodyBytes, isNotEmpty);
      expect(profileImageResponse.headers[HttpHeaders.contentTypeHeader], startsWith('image/'));
      expect(uploadedProfilePath, contains(currentUser.id));
      await _deleteProfileImageBestEffort(Store.tryGet(StoreKey.accessToken));
      await _deleteTestAssetBestEffort(assetsApi, profileAssetId);
      createdRemoteAssetIds.remove(profileAssetId);

      await container.read(settingsProvider).write(SettingsKey.networkCustomHeaders, <String, String>{});
      await apiService.updateHeaders();
      const headerName = 'X-Immich-E2E-062';
      final headerValue = 'account-$runToken';
      unawaited(router.push(const HeaderSettingsRoute()));
      await _pumpUntilFoundWithReason(
        tester,
        find.byType(HeaderSettingsPage),
        reason: 'Expected 062 custom header settings page to open',
        timeout: const Duration(seconds: 30),
      );
      await tester.enterText(find.byKey(const Key('header-settings-key-0')), headerName);
      await tester.enterText(find.byKey(const Key('header-settings-value-0')), headerValue);
      await router.maybePop();
      await _pumpUntil(
        tester,
        () => container.read(appConfigProvider).network.customHeaders[headerName] == headerValue,
        timeout: const Duration(seconds: 30),
      );
      expect(ApiService.getRequestHeaders()[headerName], headerValue);
      expect(ApiService.getServerUrls(), contains(originalEndpoint));
      expect(ApiService.getServerUrls(), isNot(contains(_apiEndpoint(_badServerUrl))));

      final badAuxiliaryValid = await container.read(authProvider.notifier).validateAuxilaryServerUrl(_badServerUrl);
      expect(badAuxiliaryValid, isFalse);
      expect(apiService.apiClient.basePath, originalEndpoint);
      expect(Store.get(StoreKey.serverEndpoint), originalEndpoint);
      await _waitForSuccessfulResponse(tester, () => apiService.serverInfoApi.pingServerWithHttpInfo());

      final newPassword = 'ImmichE2E062$runToken!';
      unawaited(router.push(const ChangePasswordRoute()));
      await _pumpUntilFoundWithReason(
        tester,
        find.byType(ChangePasswordPage),
        reason: 'Expected 062 change password page to open',
        timeout: const Duration(seconds: 30),
      );
      await tester.enterText(find.byKey(ChangePasswordForm.passwordFieldKey), newPassword);
      await tester.enterText(find.byKey(ChangePasswordForm.confirmPasswordFieldKey), newPassword);
      await _tapHitTestableFinder(
        tester,
        find.byKey(ChangePasswordForm.submitButtonKey),
        reason: 'Expected 062 change password submit button to be tappable',
      );
      await _pumpUntil(tester, () => Store.tryGet(StoreKey.accessToken) == null, timeout: const Duration(seconds: 60));
      activePassword = newPassword;
      expect(await _loginStatus(_email, _password), HttpStatus.unauthorized);
      expect(await _loginStatus(_email, newPassword), anyOf(HttpStatus.ok, HttpStatus.created));

      final restored = await _changePasswordViaAuthEndpoint(currentPassword: newPassword, newPassword: _password);
      expect(restored, isTrue);
      activePassword = _password;

      await _loadUnauthenticatedApp(tester, overrideCancellation: true, closeDriftOnDispose: false);
      await _login(tester, serverUrl: _serverUrl, email: _email, password: _password);
      await _waitForAccessToken(tester);
      await _waitForCurrentUser(_email, tester);
      container = _containerOfApp(tester);
      apiService = container.read(apiServiceProvider);
      expect(apiService.apiClient.basePath, originalEndpoint);
    });

    _realStackSessionTest('MOB-UI-063-$_caseSuffix', 'persists settings preferences across restart', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(430, 932);
      addTearDown(tester.view.reset);

      await _loadAuthenticatedApp(tester, overrideCancellation: true, closeDriftOnDispose: false);
      var container = _containerOfApp(tester);
      var originalLocale = const Locale('en');

      addTearDown(() async {
        await _restoreSettingsPreferenceDefaults();
        await _restoreLocaleIfPossible(tester, originalLocale);
      });

      await _restoreSettingsPreferenceDefaults();

      await _openSettingsSection(tester, container, SettingSection.languages);
      final currentLocale = Localizations.localeOf(tester.element(find.byType(SettingsSubPage)));
      originalLocale = currentLocale;
      final changedLocale = _isSimplifiedChinese(currentLocale)
          ? const Locale('en')
          : const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans');
      await _applyLanguageLocale(tester, changedLocale);
      expect(Localizations.localeOf(tester.element(find.byType(SettingsSubPage))).toString(), changedLocale.toString());
      await _restoreLocaleIfPossible(tester, currentLocale);
      await _pumpUntil(
        tester,
        () =>
            Localizations.localeOf(tester.element(find.byType(SettingsSubPage))).toString() == currentLocale.toString(),
        timeout: const Duration(seconds: 10),
      );
      expect(tester.takeException(), isNull);

      await _openSettingsSection(tester, container, SettingSection.notifications);
      await _expectNotificationSettingsBranch(tester);

      await _openSettingsSection(tester, container, SettingSection.preferences);
      await _setSettingsSwitchValue(tester, const ValueKey('settings-theme-system-switch'), false);
      await _pumpUntil(
        tester,
        () => SettingsRepository.instance.appConfig.theme.mode != ThemeMode.system,
        timeout: const Duration(seconds: 10),
      );
      await _setSettingsSwitchValue(tester, const ValueKey('settings-haptic-enabled-switch'), false);
      await _pumpUntil(
        tester,
        () => Store.get(StoreKey.enableHapticFeedback, true) == false,
        timeout: const Duration(seconds: 10),
      );
      await _selectSettingsRadioValue(tester, 'settings-share-quality', ShareAssetType.preview);
      await _waitForAppConfigSetting(tester, SettingsKey.shareFileType, ShareAssetType.preview);

      await _openSettingsSection(tester, container, SettingSection.timeline);
      await _setSettingsSwitchValue(tester, const ValueKey('settings-timeline-storage-indicator-switch'), false);
      await _waitForAppConfigSetting(tester, SettingsKey.timelineStorageIndicator, false);
      await _setSettingsSliderFraction(tester, const ValueKey('settings-timeline-tiles-per-row-slider'), 0.75);
      await _waitForAppConfigSetting(tester, SettingsKey.timelineTilesPerRow, 5);
      await _selectSettingsRadioValue(tester, 'settings-timeline-group-by', GroupAssetsBy.month);
      await _waitForAppConfigSetting(tester, SettingsKey.timelineGroupAssetsBy, GroupAssetsBy.month);

      await _openSettingsSection(tester, container, SettingSection.assetViewer);
      await _setSettingsSwitchValue(tester, const ValueKey('settings-viewer-load-original-image-switch'), true);
      await _waitForAppConfigSetting(tester, SettingsKey.imageLoadOriginal, true);
      await _setSettingsSwitchValue(tester, const ValueKey('settings-viewer-tap-to-navigate-switch'), true);
      await _waitForAppConfigSetting(tester, SettingsKey.viewerTapToNavigate, true);
      await _setSettingsSwitchValue(tester, const ValueKey('settings-viewer-video-autoplay-switch'), false);
      await _waitForAppConfigSetting(tester, SettingsKey.viewerAutoPlayVideo, false);
      await _setSettingsSwitchValue(tester, const ValueKey('settings-slideshow-repeat-switch'), false);
      await _waitForAppConfigSetting(tester, SettingsKey.slideshowRepeat, false);
      await _setSettingsSliderFraction(tester, const ValueKey('settings-slideshow-duration-slider'), 0.2);
      await _waitForAppConfigSetting(tester, SettingsKey.slideshowDuration, 10);
      await _selectSettingsRadioValue(tester, 'settings-slideshow-look', SlideshowLook.cover);
      await _waitForAppConfigSetting(tester, SettingsKey.slideshowLook, SlideshowLook.cover);
      await _selectSettingsRadioValue(tester, 'settings-slideshow-direction', SlideshowDirection.shuffle);
      await _waitForAppConfigSetting(tester, SettingsKey.slideshowDirection, SlideshowDirection.shuffle);

      container = await _restartAuthenticatedApp(tester, email: _email, password: _password);
      await _waitForAppConfigSetting(tester, SettingsKey.shareFileType, ShareAssetType.preview);
      await _waitForAppConfigSetting(tester, SettingsKey.timelineTilesPerRow, 5);
      await _waitForAppConfigSetting(tester, SettingsKey.timelineGroupAssetsBy, GroupAssetsBy.month);
      await _waitForAppConfigSetting(tester, SettingsKey.imageLoadOriginal, true);
      await _waitForAppConfigSetting(tester, SettingsKey.viewerTapToNavigate, true);
      await _waitForAppConfigSetting(tester, SettingsKey.viewerAutoPlayVideo, false);
      await _waitForAppConfigSetting(tester, SettingsKey.slideshowDirection, SlideshowDirection.shuffle);

      await _restoreSettingsPreferenceDefaults();
      await _waitForAppConfigSetting(tester, SettingsKey.themeMode, ThemeMode.system);
      await _waitForAppConfigSetting(tester, SettingsKey.shareFileType, ShareAssetType.original);
      await _waitForAppConfigSetting(tester, SettingsKey.timelineTilesPerRow, 4);
      await _waitForAppConfigSetting(tester, SettingsKey.timelineGroupAssetsBy, GroupAssetsBy.day);
      await _waitForAppConfigSetting(tester, SettingsKey.imageLoadOriginal, false);
      await _waitForAppConfigSetting(tester, SettingsKey.viewerTapToNavigate, false);
      await _waitForAppConfigSetting(tester, SettingsKey.viewerAutoPlayVideo, true);
      await _waitForAppConfigSetting(tester, SettingsKey.slideshowDirection, SlideshowDirection.forward);
      expect(Store.get(StoreKey.enableHapticFeedback, true), isTrue);
      expect(container.read(apiServiceProvider).apiClient.basePath, _apiEndpoint(_serverUrl));
    });

    _realStackSessionTest(
      'MOB-UI-064-$_caseSuffix',
      'opens sync maintenance diagnostics without destructive side effects',
      (tester) async {
        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = const Size(430, 932);
        addTearDown(tester.view.reset);

        await _loadAuthenticatedApp(
          tester,
          overrideCancellation: true,
          closeDriftOnDispose: false,
          resetSyncAcksBeforeStart: true,
        );
        final container = _containerOfApp(tester);
        final router = container.read(appRouterProvider);
        final apiService = container.read(apiServiceProvider);
        final assetsApi = apiService.assetsApi;
        final downloadService = container.read(downloadServiceProvider);
        final downloadRepository = container.read(downloadRepositoryProvider);
        final downloadUpdates = <TaskStatusUpdate>[];
        final createdRemoteAssetIds = <String>[];
        final createdLocalAssetIds = <String>{};

        downloadService.onImageDownloadStatus = downloadUpdates.add;
        addTearDown(() async {
          downloadService.onImageDownloadStatus = null;
          for (final assetId in createdRemoteAssetIds) {
            await _deleteTestAssetBestEffort(assetsApi, assetId);
          }
        });

        await _resetAndSyncRemoteState(tester, container);

        final now = DateTime.now().toUtc();
        final runToken = now.microsecondsSinceEpoch.toString();
        final remoteName = 'immich-e2e-maintenance-064-remote-$runToken.jpg';
        final localName = 'immich-e2e-maintenance-064-local-$runToken.jpg';
        final remoteId = await _uploadGeneratedJpegAsSecondClient(
          remoteName,
          now,
          sourceMetadata: const {
            'width': 128,
            'height': 96,
            'device_make': 'ImmichE2E064',
            'device_model': 'Maintenance',
          },
        );
        createdRemoteAssetIds.add(remoteId);
        await _waitForSuccessfulResponse(
          tester,
          () => _authenticatedApiGet(
            '/assets/$remoteId/thumbnail?size=thumbnail&edited=false&c=$runToken',
          ),
          timeout: const Duration(minutes: 3),
        );

        final createdLocal = await _saveLocalTestImage(
          container,
          createdLocalAssetIds,
          title: localName,
          relativePath: 'Pictures/ImmichE2E064',
          seed: runToken.hashCode,
        );
        await container.read(backgroundSyncProvider).syncLocal(full: true);
        final localOnly = await _waitForLocalAssetByName(
          container,
          localName,
          tester,
        );
        expect(localOnly.id, createdLocal.id);
        expect(localOnly.isLocalOnly, isTrue);

        await _resetAndSyncRemoteState(tester, container);
        final remoteAsset = await _waitForRemoteAssetState(
          tester,
          container,
          remoteId,
          (asset) => asset.isRemoteOnly,
          reason:
              'Expected the 064 diagnostic image to sync as remote-only before download',
        );

        final assetCounts = await container
            .read(assetServiceProvider)
            .getAssetCounts();
        expect(
          assetCounts.$1,
          greaterThanOrEqualTo(1),
          reason: 'Expected local sync diagnostics to see local assets',
        );
        expect(
          assetCounts.$2,
          greaterThanOrEqualTo(1),
          reason: 'Expected remote sync diagnostics to see remote assets',
        );

        unawaited(router.push(const SyncStatusRoute()));
        await _pumpUntilFoundWithReason(
          tester,
          find.byType(SyncStatusPage),
          reason: 'Expected 064 sync status page to open',
          timeout: const Duration(seconds: 30),
        );
        await _pumpUntilFoundWithReason(
          tester,
          find.byType(SyncStatusAndActions),
          reason: 'Expected 064 sync status actions to render',
          timeout: const Duration(seconds: 30),
        );
        await _tapTextEntryInPage(
          tester,
          pageType: SyncStatusPage,
          label: 'sync_local'.tr(),
        );
        await _tapTextEntryInPage(
          tester,
          pageType: SyncStatusPage,
          label: 'sync_remote'.tr(),
        );
        expect(tester.takeException(), isNull);
        await _popUntilVisible(tester, MainTimelinePage);

        unawaited(router.push(const LocalMediaSummaryRoute()));
        await _pumpUntilFoundWithReason(
          tester,
          find.byType(LocalMediaSummaryPage),
          reason: 'Expected 064 local media summary page to open',
          timeout: const Duration(seconds: 30),
        );
        await _pumpUntilFoundWithReason(
          tester,
          find.text('Local Assets'),
          reason: 'Expected 064 local media summary to expose asset counts',
          timeout: const Duration(seconds: 30),
        );
        await _pumpUntilFoundWithReason(
          tester,
          find.text('Local Albums'),
          reason: 'Expected 064 local media summary to expose album counts',
          timeout: const Duration(seconds: 30),
        );
        await _popUntilVisible(tester, MainTimelinePage);

        unawaited(router.push(const RemoteMediaSummaryRoute()));
        await _pumpUntilFoundWithReason(
          tester,
          find.byType(RemoteMediaSummaryPage),
          reason: 'Expected 064 remote media summary page to open',
          timeout: const Duration(seconds: 30),
        );
        await _pumpUntilFoundWithReason(
          tester,
          find.text('Remote Assets'),
          reason: 'Expected 064 remote media summary to expose asset counts',
          timeout: const Duration(seconds: 30),
        );
        await _pumpUntilFoundWithReason(
          tester,
          find.text('Exif Entities'),
          reason: 'Expected 064 remote media summary to expose exif counts',
          timeout: const Duration(seconds: 30),
        );
        await _popUntilVisible(tester, MainTimelinePage);

        unawaited(router.push(CleanupPreviewRoute(assets: [localOnly])));
        await _pumpUntilFoundWithReason(
          tester,
          find.byType(CleanupPreviewPage),
          reason: 'Expected 064 cleanup preview page to open',
          timeout: const Duration(seconds: 30),
        );
        await _pumpUntilFoundWithReason(
          tester,
          find.byType(Timeline),
          reason: 'Expected 064 cleanup preview to render a read-only timeline',
          timeout: const Duration(seconds: 30),
        );
        await _pumpUntilFoundWithReason(
          tester,
          _timelineAssetTileForAssetId(localOnly.id),
          reason: 'Expected 064 cleanup preview to show the local-only asset',
          timeout: const Duration(seconds: 30),
        );
        await _popUntilVisible(tester, MainTimelinePage);
        final retainedLocal = await _waitForLocalAssetByName(
          container,
          localName,
          tester,
        );
        expect(
          retainedLocal.id,
          localOnly.id,
          reason: 'Cleanup preview must not delete media without confirmation',
        );

        await downloadRepository.deleteRecordsWithIds([remoteAsset.id]);
        final acceptedDownloads = await downloadRepository.downloadAllAssets([
          remoteAsset,
        ]);
        expect(
          acceptedDownloads,
          equals([true]),
          reason: 'Expected 064 remote diagnostic image download to enqueue',
        );
        final downloadRecord = await _waitForDownloadRecordStatus(
          tester,
          remoteAsset.id,
          TaskStatus.complete,
          reason: 'Expected 064 diagnostic image download to complete',
        );
        expect(downloadRecord.group, kDownloadGroupImage);
        expect(downloadRecord.task.filename, remoteAsset.name);
        await _waitForDownloadUpdateCount(
          tester,
          downloadUpdates,
          remoteAsset.id,
          TaskStatus.complete,
          1,
          reason:
              'Expected 064 download service to emit a completed image update',
        );
        final downloadedLocal = await _waitForLocalAssetByName(
          container,
          remoteAsset.name,
          tester,
        );
        createdLocalAssetIds.add(downloadedLocal.id);
        expect(downloadedLocal.hasLocal, isTrue);

        unawaited(router.push(const DownloadInfoRoute()));
        await _pumpUntilFoundWithReason(
          tester,
          find.byType(DownloadInfoPage),
          reason: 'Expected 064 download info page to open',
          timeout: const Duration(seconds: 30),
        );
        await _pumpUntilFoundWithReason(
          tester,
          find.text('clear_all'.tr()),
          reason: 'Expected 064 download info clear-all control to render',
          timeout: const Duration(seconds: 30),
        );
        await _popUntilVisible(tester, MainTimelinePage);

        final logMessage = 'MOB-UI-064 diagnostic log $runToken';
        Logger('MOB-UI-064').warning(logMessage);
        expect(
          logMessage.contains(_password),
          isFalse,
          reason:
              'Expected the 064 diagnostic log message to avoid the current test credential',
        );
        unawaited(router.push(const AppLogRoute()));
        await _pumpUntilFoundWithReason(
          tester,
          find.byType(AppLogPage),
          reason: 'Expected 064 app log page to open',
          timeout: const Duration(seconds: 30),
        );
        await _pumpUntilFoundWithReason(
          tester,
          find.byIcon(Icons.delete_outline_rounded),
          reason: 'Expected 064 app log page controls to render',
          timeout: const Duration(seconds: 30),
        );
        await _popUntilVisible(tester, MainTimelinePage);

        unawaited(router.push(AssetTroubleshootRoute(asset: remoteAsset)));
        await _pumpUntilFoundWithReason(
          tester,
          find.byType(AssetTroubleshootPage),
          reason: 'Expected 064 asset troubleshoot page to open',
          timeout: const Duration(seconds: 30),
        );
        await _pumpUntilFoundWithReason(
          tester,
          find.text(remoteAsset.name),
          reason:
              'Expected 064 asset troubleshoot page to render asset metadata',
          timeout: const Duration(seconds: 30),
        );
        await _pumpUntilFoundWithReason(
          tester,
          find.text('matching_assets'.tr()),
          reason:
              'Expected 064 asset troubleshoot page to render matching assets',
          timeout: const Duration(seconds: 30),
        );
        await _popUntilVisible(tester, MainTimelinePage);

        unawaited(router.push(const WhatsNewRoute()));
        await _pumpUntilFoundWithReason(
          tester,
          find.byType(WhatsNewPage),
          reason: 'Expected 064 whats-new page to open',
          timeout: const Duration(seconds: 30),
        );
        await _pumpUntilFoundWithReason(
          tester,
          find.byType(ListView),
          reason: 'Expected 064 whats-new page to render its highlight list',
          timeout: const Duration(seconds: 30),
        );
        expect(tester.takeException(), isNull);
      },
    );

    _realStackSessionTest(
      'MOB-MEDIA-065-$_caseSuffix',
      'uploads one gallery photo and verifies client/server consistency',
      (tester) async {
        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = const Size(430, 932);
        addTearDown(tester.view.reset);

        await _loadAuthenticatedApp(
          tester,
          overrideCancellation: true,
          closeDriftOnDispose: false,
          resetSyncAcksBeforeStart: true,
        );
        final container = _containerOfApp(tester);
        final apiService = container.read(apiServiceProvider);
        final assetsApi = apiService.assetsApi;
        final searchApi = apiService.searchApi;
        final createdRemoteAssetIds = <String>[];
        final createdLocalAssetIds = <String>{};

        addTearDown(() async {
          for (final assetId in createdRemoteAssetIds) {
            await _deleteTestAssetBestEffort(assetsApi, assetId);
          }
          unawaited(_deleteLocalTestAssetsBestEffort(createdLocalAssetIds));
        });

        await _resetAndSyncRemoteState(tester, container);

        final runToken = DateTime.now().toUtc().microsecondsSinceEpoch.toString();
        final localName = 'immich-e2e-media-065-upload-$runToken.jpg';
        final sourceBytes = _generatedJpegBytes(runToken.hashCode);
        final expectedSourceMd5 = base64Encode(md5.convert(sourceBytes).bytes);
        expect(
          await _serverAssetIdsByOriginalFilename(searchApi, localName),
          isEmpty,
          reason: 'The 065 upload filename must be unique before the test',
        );

        final createdLocal = await container.read(fileMediaRepositoryProvider).saveLocalAsset(
          sourceBytes,
          title: localName,
          relativePath: 'Pictures/ImmichE2E065',
        );
        expect(
          createdLocal,
          isNotNull,
          reason: 'Expected PhotoManager to inject the 065 gallery fixture',
        );
        createdLocalAssetIds.add(createdLocal!.id);

        await container.read(backgroundSyncProvider).syncLocal(full: true);
        final localAsset = await _waitForLocalAssetByNameState(
          container,
          localName,
          tester,
          (asset) => asset.isImage && asset.contentSize != null && asset.contentSize! > 0,
          reason:
              'Expected the 065 gallery fixture to sync with uploadable metadata',
        );
        expect(localAsset.isLocalOnly, isTrue);

        final localFile = await container.read(storageRepositoryProvider).getFileForAsset(localAsset.id);
        expect(localFile, isNotNull);
        final localBytes = await localFile!.readAsBytes();
        final localMd5 = base64Encode(md5.convert(localBytes).bytes);
        expect(localBytes.length, localAsset.contentSize);
        expect(
          localMd5,
          expectedSourceMd5,
          reason:
              'Expected Android MediaStore to preserve the generated 065 JPEG bytes',
        );

        final progressById = <String, List<double>>{};
        String? remoteAssetId;
        String? uploadError;
        await container.read(foregroundUploadServiceProvider).uploadSingleAsset(
          localAsset,
          Completer<void>(),
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
            onSuccess: (_, remoteId) => remoteAssetId = remoteId,
            onError: (_, errorMessage) => uploadError = errorMessage,
          ),
        );

        expect(uploadError, isNull);
        expect(remoteAssetId, isNotNull);
        createdRemoteAssetIds.add(remoteAssetId!);

        final serverIds = await _waitForServerAssetIdsByOriginalFilename(
          tester,
          searchApi,
          localName,
          (ids) => ids.contains(remoteAssetId),
          reason:
              'Expected the 065 uploaded photo to be indexed by filename on the real server',
        );
        expect(serverIds, hasLength(1));

        final info = await _waitForAssetInfoState(
          tester,
          assetsApi,
          remoteAssetId!,
          (asset) =>
              asset.type == api.AssetTypeEnum.IMAGE &&
              asset.originalFileName == localName &&
              asset.width != null &&
              asset.height != null,
          reason:
              'Expected the 065 uploaded photo to expose server metadata',
        );
        expect(info.fileCreatedAt.toUtc(), localAsset.createdAt.toUtc());
        expect(info.width, localAsset.width);
        expect(info.height, localAsset.height);

        final original = await _waitForSuccessfulResponse(
          tester,
          () => container
              .read(assetApiRepositoryProvider)
              .downloadAsset(remoteAssetId!, edited: false),
          timeout: const Duration(minutes: 3),
        );
        expect(original.bodyBytes.length, localBytes.length);
        expect(base64Encode(md5.convert(original.bodyBytes).bytes), localMd5);

        final thumbnail = await _waitForSuccessfulResponse(
          tester,
          () => assetsApi.viewAssetWithHttpInfo(
            remoteAssetId!,
            size: api.AssetMediaSize.thumbnail,
          ),
          timeout: const Duration(minutes: 3),
        );
        expect(thumbnail.bodyBytes, isNotEmpty);

        await _resetAndSyncRemoteState(tester, container);
        final syncedAsset = await _waitForRemoteAssetState(
          tester,
          container,
          remoteAssetId!,
          (asset) =>
              asset.isImage &&
              asset.hasLocal &&
              asset.hasRemote &&
              asset.checksum == localMd5,
          reason:
              'Expected the 065 upload to sync back as one merged local/remote asset',
        );

        final timeline = container.read(timelineFactoryProvider).main([
          syncedAsset.ownerId,
        ]);
        addTearDown(timeline.dispose);
        final timelineAssets = await _expectTimelineAssetSet(
          tester,
          timeline,
          includes: {remoteAssetId!},
          excludes: const {},
          reason:
              'Expected the 065 uploaded photo to appear in the client timeline',
        );
        final timelineMatches = timelineAssets
            .where(
              (asset) =>
                  _timelineAssetId(asset) == remoteAssetId ||
                  asset.refersToSameAsset(syncedAsset),
            )
            .toList();
        expect(
          timelineMatches,
          hasLength(1),
          reason:
              'Expected exactly one visible client asset for the 065 upload',
        );
        expect(timelineMatches.single.hasRemote, isTrue);
        expect(timelineMatches.single.hasLocal, isTrue);

        await _openTimelineAsset(tester, syncedAsset);
        await pumpUntilFound(
          tester,
          find.byType(AssetViewer),
          timeout: const Duration(seconds: 60),
        );
        EventStream.shared.emit(const ViewerShowDetailsEvent());
        await _pumpFor(tester, const Duration(seconds: 1));
        expect(container.read(assetViewerProvider).showingDetails, isTrue);
        expect(tester.takeException(), isNull);

        debugPrint(
          'MOB-MEDIA-065-A uploaded remoteId=$remoteAssetId '
          'sourceFilename=$localName syncedFilename=${syncedAsset.name} '
          'md5=$localMd5 size=${localBytes.length}',
        );
      },
    );

    if (_selectedCaseId.isNotEmpty && !_registeredSelectedCase) {
      test(
        _selectedCaseId,
        () => fail('No real stack auth test registered for $_selectedCaseId'),
      );
    }
  });
}

Future<void> _exerciseTimelineUiPagination(WidgetTester tester) async {
  await pumpUntilFound(
    tester,
    find.byType(Timeline),
    timeout: const Duration(seconds: 60),
  );
  await _dismissFeatureMessageIfVisible(tester);
  final scrollable = find.descendant(
    of: find.byType(Timeline),
    matching: find.byType(Scrollable),
  );
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

Future<void> _openShortcutEntryAndReturn(
  WidgetTester tester, {
  required Type sourcePage,
  required String label,
  required Type targetPage,
  required String title,
  BaseAsset? assetToOpen,
}) async {
  await pumpUntilFound(
    tester,
    find.byType(sourcePage),
    timeout: const Duration(seconds: 30),
  );
  final entry = find.descendant(
    of: find.byType(sourcePage),
    matching: find.text(label),
  );
  await pumpUntilFound(tester, entry, timeout: const Duration(seconds: 30));
  await tester.ensureVisible(entry.first);
  await _pumpFor(tester, const Duration(milliseconds: 250));
  await tester.tap(entry.first, warnIfMissed: false);
  await _pumpUntil(
    tester,
    () => find.byType(targetPage).evaluate().isNotEmpty,
    timeout: const Duration(seconds: 30),
  );
  await pumpUntilFound(
    tester,
    find.byType(Timeline),
    timeout: const Duration(seconds: 60),
  );
  await pumpUntilFound(
    tester,
    find.text(title),
    timeout: const Duration(seconds: 30),
  );
  await _exerciseTimelineUiPagination(tester);

  if (assetToOpen != null) {
    await _openTimelineAsset(tester, assetToOpen);
    await tester.binding.handlePopRoute();
    await _pumpUntil(
      tester,
      () => find.byType(AssetViewer).evaluate().isEmpty,
      timeout: const Duration(seconds: 30),
    );
    await pumpUntilFound(
      tester,
      find.byType(targetPage),
      timeout: const Duration(seconds: 30),
    );
    await pumpUntilFound(
      tester,
      _timelineAssetTileForAssetId(_timelineAssetId(assetToOpen)),
      timeout: const Duration(seconds: 30),
    );
  }

  await tester.binding.handlePopRoute();
  await _pumpUntil(
    tester,
    () =>
        find.byType(targetPage).evaluate().isEmpty &&
        find.byType(sourcePage).evaluate().isNotEmpty,
    timeout: const Duration(seconds: 30),
  );
}

Future<void> _openRemoteAlbumMenu(WidgetTester tester) async {
  final menuButton = find.byKey(const Key('remote-album-menu-button'));
  await pumpUntilFound(
    tester,
    menuButton,
    timeout: const Duration(seconds: 30),
  );
  expect(
    menuButton.hitTestable(),
    findsWidgets,
    reason: 'Expected the remote album menu button to be tappable',
  );
  await tester.tap(menuButton.hitTestable().last, warnIfMissed: false);
  await _pumpFor(tester, const Duration(milliseconds: 300));
}

Future<void> _tapRemoteAlbumMenuAction(WidgetTester tester, Key key) async {
  await _openRemoteAlbumMenu(tester);
  final action = find.byKey(key);
  await _tapHitTestableFinder(
    tester,
    action,
    reason: 'Expected remote album menu action $key to be tappable',
  );
  await _pumpFor(tester, const Duration(milliseconds: 500));
}

Future<void> _tapHitTestableFinder(
  WidgetTester tester,
  Finder finder, {
  String? reason,
  Duration timeout = const Duration(seconds: 30),
}) async {
  await _pumpUntilFoundWithReason(
    tester,
    finder,
    reason: reason ?? 'Expected finder to be tappable',
    timeout: timeout,
  );
  await _pumpUntil(
    tester,
    () => finder.hitTestable().evaluate().isNotEmpty,
    timeout: timeout,
  );
  expect(finder.hitTestable(), findsWidgets, reason: reason);
  await tester.tap(finder.hitTestable().last, warnIfMissed: false);
}

Future<void> _pressRemoteAlbumAppBarAction(WidgetTester tester, Key key) async {
  final action = find.byKey(key);
  await pumpUntilFound(tester, action, timeout: const Duration(seconds: 30));
  final tappable = action.hitTestable();
  if (tappable.evaluate().isNotEmpty) {
    await tester.tap(tappable.last, warnIfMissed: false);
  } else {
    final iconButton = tester.widget<IconButton>(action.last);
    expect(
      iconButton.onPressed,
      isNotNull,
      reason: 'Expected remote album action $key to be enabled',
    );
    iconButton.onPressed!();
  }
  await _pumpFor(tester, const Duration(milliseconds: 500));
}

Future<void> _pressIconButtonByKey(
  WidgetTester tester,
  Key key, {
  String? reason,
}) async {
  final button = find.byKey(key);
  await pumpUntilFound(tester, button, timeout: const Duration(seconds: 30));
  final iconButton = tester.widget<IconButton>(button.last);
  expect(iconButton.onPressed, isNotNull, reason: reason);
  iconButton.onPressed!();
  await _pumpFor(tester, const Duration(milliseconds: 500));
}

Future<void> _showSlideshowControls(WidgetTester tester) async {
  final settingsAction = find.byKey(const Key('slideshow-settings-action'));

  for (var attempt = 0; attempt < 8; attempt++) {
    if (settingsAction.hitTestable().evaluate().isNotEmpty) {
      return;
    }

    final photoView = find.byType(PhotoView);
    if (photoView.evaluate().isNotEmpty) {
      await tester.tap(photoView.last, warnIfMissed: false);
    } else {
      await tester.tap(
        find.byKey(const Key('slideshow-page-view')).first,
        warnIfMissed: false,
      );
    }
    await _pumpFor(tester, const Duration(milliseconds: 400));
  }

  fail('Expected slideshow controls to become visible and tappable');
}

Future<Key> _waitForAnyKey(
  WidgetTester tester,
  List<Key> keys, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  Key? foundKey;
  await _pumpUntil(tester, () {
    for (final key in keys) {
      if (find.byKey(key).evaluate().isNotEmpty) {
        foundKey = key;
        return true;
      }
    }
    return false;
  }, timeout: timeout);
  return foundKey!;
}

Future<void> _ensureTextVisibleInPage(
  WidgetTester tester,
  Type pageType,
  String label, {
  int maxScrolls = 40,
}) async {
  await pumpUntilFound(
    tester,
    find.byType(pageType),
    timeout: const Duration(seconds: 30),
  );
  for (var attempt = 0; attempt < maxScrolls; attempt++) {
    final page = find.byType(pageType);
    final target = find.descendant(of: page, matching: find.text(label));
    if (target.evaluate().isNotEmpty) {
      await tester.ensureVisible(target.first);
      await _pumpFor(tester, const Duration(milliseconds: 200));
      return;
    }

    var scrollable = find.descendant(
      of: page,
      matching: find.byKey(const Key('shared-link-edit-form')),
    );
    if (scrollable.evaluate().isEmpty) {
      scrollable = find.descendant(of: page, matching: find.byType(ListView));
    }
    if (scrollable.evaluate().isEmpty) {
      scrollable = find.descendant(of: page, matching: find.byType(Scrollable));
    }
    if (scrollable.evaluate().isEmpty) {
      scrollable = find.byType(Scrollable);
    }
    if (scrollable.evaluate().isNotEmpty) {
      await tester.drag(scrollable.first, const Offset(0, -500));
    }
    await _pumpFor(tester, const Duration(milliseconds: 250));
  }

  fail('Expected "$label" to be visible in $pageType');
}

Future<void> _ensureKeyVisibleInPage(
  WidgetTester tester,
  Type pageType,
  Key key, {
  int maxScrolls = 40,
}) async {
  await pumpUntilFound(
    tester,
    find.byType(pageType),
    timeout: const Duration(seconds: 30),
  );
  final page = find.byType(pageType);
  final target = find.descendant(of: page, matching: find.byKey(key));
  var scrollable = find.descendant(of: page, matching: find.byType(Scrollable));
  if (scrollable.evaluate().isNotEmpty) {
    try {
      await tester.scrollUntilVisible(
        target,
        500,
        scrollable: scrollable.first,
        maxScrolls: maxScrolls,
        duration: const Duration(milliseconds: 100),
      );
      await _pumpFor(tester, const Duration(milliseconds: 200));
      return;
    } catch (_) {
      // Fall back to explicit drags below for custom scrollable layouts.
    }
  }

  for (var attempt = 0; attempt < maxScrolls; attempt++) {
    if (target.evaluate().isNotEmpty) {
      await tester.ensureVisible(target.first);
      await _pumpFor(tester, const Duration(milliseconds: 200));
      return;
    }

    scrollable = find.descendant(
      of: page,
      matching: find.byKey(const Key('shared-link-edit-form')),
    );
    if (scrollable.evaluate().isEmpty) {
      scrollable = find.descendant(of: page, matching: find.byType(ListView));
    }
    if (scrollable.evaluate().isEmpty) {
      scrollable = find.descendant(of: page, matching: find.byType(Scrollable));
    }
    if (scrollable.evaluate().isEmpty) {
      scrollable = find.byType(Scrollable);
    }
    if (scrollable.evaluate().isNotEmpty) {
      await tester.drag(scrollable.first, const Offset(0, -500));
    }
    await _pumpFor(tester, const Duration(milliseconds: 250));
  }

  fail('Expected key "$key" to be visible in $pageType');
}

Future<void> _tapTextEntryInPage(
  WidgetTester tester, {
  required Type pageType,
  required String label,
}) async {
  await _ensureTextVisibleInPage(tester, pageType, label);
  final target = find.descendant(
    of: find.byType(pageType),
    matching: find.text(label),
  );
  await tester.tap(target.first, warnIfMissed: false);
  await _pumpFor(tester, const Duration(milliseconds: 700));
}

Future<void> _popUntilVisible(
  WidgetTester tester,
  Type pageType, {
  int maxPops = 8,
}) async {
  for (var attempt = 0; attempt < maxPops; attempt++) {
    if (find.byType(pageType).evaluate().isNotEmpty) {
      return;
    }
    await tester.binding.handlePopRoute();
    await _pumpFor(tester, const Duration(milliseconds: 700));
  }

  fail('Could not pop back to $pageType');
}

void _expectTimelineOrder(
  List<BaseAsset> assets,
  List<String> orderedIds, {
  required String reason,
}) {
  var previousIndex = -1;
  final ids = assets.map(_timelineAssetId).toList(growable: false);
  for (final assetId in orderedIds) {
    final index = ids.indexOf(assetId);
    expect(
      index,
      greaterThanOrEqualTo(0),
      reason: '$reason; missing $assetId in ${ids.join(', ')}',
    );
    expect(
      index,
      greaterThan(previousIndex),
      reason: '$reason; order was ${ids.join(', ')}',
    );
    previousIndex = index;
  }
}

final _allReplayableSyncAckTypes = api.SyncEntityType.values.toList(
  growable: false,
);

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

const _assetDeleteSyncTypes = {
  api.SyncEntityType.assetDeleteV1,
  api.SyncEntityType.partnerAssetDeleteV1,
};

const _exifUpsertSyncTypes = {
  api.SyncEntityType.assetExifV1,
  api.SyncEntityType.partnerAssetExifV1,
  api.SyncEntityType.partnerAssetExifBackfillV1,
  api.SyncEntityType.albumAssetExifCreateV1,
  api.SyncEntityType.albumAssetExifUpdateV1,
  api.SyncEntityType.albumAssetExifBackfillV1,
};

const _albumUpsertSyncTypes = {
  api.SyncEntityType.albumV1,
  api.SyncEntityType.albumV2,
};

const _albumAssetUpsertSyncTypes = {
  api.SyncEntityType.albumToAssetV1,
  api.SyncEntityType.albumToAssetBackfillV1,
};

const _stackUpsertSyncTypes = {
  api.SyncEntityType.stackV1,
  api.SyncEntityType.partnerStackV1,
  api.SyncEntityType.partnerStackBackfillV1,
};

const _stackDeleteSyncTypes = {
  api.SyncEntityType.stackDeleteV1,
  api.SyncEntityType.partnerStackDeleteV1,
};

const _assetFaceUpsertSyncTypes = {
  api.SyncEntityType.assetFaceV1,
  api.SyncEntityType.assetFaceV2,
};

Future<List<SyncEvent>> _collectSyncStreamEvents(
  ProviderContainer container,
) async {
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
        serverVersion: SemVer(
          major: serverVersion!.major,
          minor: serverVersion.minor,
          patch: serverVersion.patch_,
        ),
        initialBatchSize: 25,
        batchSize: 50,
      );
  return events;
}

Future<List<SyncEvent>> _interruptSyncAfterFirstSafeEvent(
  ProviderContainer container,
) async {
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
          await container.read(syncStreamRepositoryProvider).updateAuthUsersV1([
            event.data as api.SyncAuthUserV1,
          ]);
          await container.read(syncApiRepositoryProvider).ack([event.ack]);
          abort();
        },
        serverVersion: SemVer(
          major: serverVersion!.major,
          minor: serverVersion.minor,
          patch: serverVersion.patch_,
        ),
        initialBatchSize: 1,
        batchSize: 1,
      );
  return events;
}

Set<String> _memoryAssetIds(DriftMemory memory) =>
    memory.assets.map((asset) => asset.id).toSet();

Future<List<DriftMemory>> _waitForMemoryLane(
  WidgetTester tester,
  ProviderContainer container,
  bool Function(List<DriftMemory>) matches, {
  required String reason,
  Duration timeout = const Duration(seconds: 60),
}) async {
  final currentUser = container.read(currentUserProvider);
  expect(currentUser, isNotNull);
  final userId = currentUser!.id;

  var latest = const <DriftMemory>[];
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    latest = await container
        .read(driftMemoryServiceProvider)
        .getMemoryLane(userId);
    if (matches(latest)) {
      return latest;
    }
    await _pumpFor(tester, const Duration(milliseconds: 500));
  }

  fail(
    '$reason; latest memory ids=${latest.map((memory) => memory.id).join(', ')}',
  );
}

Future<DriftMemory?> _waitForMemory(
  WidgetTester tester,
  ProviderContainer container,
  String memoryId,
  bool Function(DriftMemory?) matches, {
  required String reason,
  Duration timeout = const Duration(seconds: 60),
}) async {
  DriftMemory? latest;
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    latest = await container.read(driftMemoryServiceProvider).get(memoryId);
    if (matches(latest)) {
      return latest;
    }
    await _pumpFor(tester, const Duration(milliseconds: 500));
  }

  fail('$reason; latest=$latest');
}

Future<void> _tapMemoryActionButton(WidgetTester tester, Key key) async {
  final button = find.byKey(key);
  await pumpUntilFound(tester, button, timeout: const Duration(seconds: 30));
  expect(
    button.hitTestable(),
    findsWidgets,
    reason: 'Expected memory action $key to be tappable',
  );
  await tester.tap(button.hitTestable().first, warnIfMissed: false);
  await _pumpFor(tester, const Duration(milliseconds: 500));
}

Future<void> _openMemoryFromTimeline(
  WidgetTester tester,
  String memoryId,
) async {
  final card = find.byKey(Key(memoryId));
  final scrollable = find.descendant(
    of: find.byType(Timeline),
    matching: find.byType(Scrollable),
  );
  expect(
    scrollable,
    findsWidgets,
    reason: 'Expected timeline scrollable before opening memory $memoryId',
  );

  for (var attempt = 0; attempt < 12; attempt++) {
    if (card.evaluate().isNotEmpty) {
      await tester.ensureVisible(card.first);
      await _pumpFor(tester, const Duration(milliseconds: 300));
      await tester.tapAt(tester.getCenter(card.first));
      await _pumpFor(tester, const Duration(milliseconds: 700));
      return;
    }

    await tester.drag(scrollable.first, const Offset(0, 700));
    await _pumpFor(tester, const Duration(milliseconds: 500));
  }

  fail(
    'Expected the 052 memory card in the timeline memory lane; memoryId=$memoryId',
  );
}

Future<void> _advanceMemoryAssetTo(
  WidgetTester tester,
  ProviderContainer container,
  String assetId, {
  required int maxTaps,
}) async {
  for (var attempt = 0; attempt <= maxTaps; attempt++) {
    if (container.read(assetViewerProvider).currentAsset?.id == assetId) {
      return;
    }

    final page = find.byType(DriftMemoryPage);
    await pumpUntilFound(tester, page, timeout: const Duration(seconds: 30));
    final viewerRect = tester.getRect(page.first);
    await tester.tapAt(Offset(viewerRect.right - 24, viewerRect.center.dy));
    await _pumpFor(tester, const Duration(milliseconds: 700));
  }

  fail('Could not advance memory viewer to asset $assetId');
}

Future<void> _connectAndWaitForWebsocket(
  WidgetTester tester,
  ProviderContainer container,
) async {
  container.read(websocketProvider.notifier).connect();
  await _pumpUntil(
    tester,
    () => container.read(websocketProvider).isConnected,
    timeout: const Duration(seconds: 30),
  );
}

void _expectRealSyncCoverage(List<SyncEvent> events) {
  final eventTypes = events.map((event) => event.type).toSet();
  final logicalTypes = _logicalSyncTypes(events);
  expect(
    logicalTypes,
    containsAll([api.SyncEntityType.authUserV1, api.SyncEntityType.userV1]),
  );
  expect(
    eventTypes.intersection(_assetUpsertSyncTypes),
    isNotEmpty,
    reason: 'Expected asset sync events',
  );
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
  expect(
    logicalTypes,
    containsAll([
      api.SyncEntityType.personV1,
      api.SyncEntityType.syncCompleteV1,
    ]),
  );

  final syncedMediaTypes = events
      .where((event) => _assetUpsertSyncTypes.contains(event.type))
      .map((event) => (event.data as dynamic).type)
      .toSet();
  expect(
    syncedMediaTypes,
    containsAll([api.AssetTypeEnum.IMAGE, api.AssetTypeEnum.VIDEO]),
  );
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
  final row = await drift
      .customSelect('SELECT COUNT(*) AS count FROM $table')
      .getSingle();
  return row.read<int>('count');
}

void _expectRemoteSyncRows(
  Map<String, int> actualRows,
  Map<String, int> expectedRows, {
  required String label,
}) {
  for (final entry in expectedRows.entries) {
    expect(
      actualRows[entry.key],
      entry.value,
      reason:
          '$label row mismatch for ${entry.key}: expected $expectedRows, got $actualRows',
    );
  }
}

Future<Set<String>> _syncAckSet(ProviderContainer container) async {
  final syncAcks = await container
      .read(apiServiceProvider)
      .syncApi
      .getSyncAck();
  return {
    for (final ack in syncAcks ?? <api.SyncAckDto>[])
      '${ack.type.toJson()}\t${ack.ack}',
  };
}

Set<api.SyncEntityType> _syncAckTypes(Set<String> ackSet) {
  return {
    for (final ack in ackSet)
      api.SyncEntityType.fromJson(ack.split('\t').first),
  }.whereType<api.SyncEntityType>().toSet();
}

void _expectAckCoverage(Set<String> ackSet, List<SyncEvent> expectedEvents) {
  final ackedTypes = _syncAckTypes(ackSet);

  final expectedTypes = _logicalSyncTypes(expectedEvents);
  final requiredTypes = {
    for (final type in expectedTypes)
      if (type != api.SyncEntityType.syncAckV1 &&
          type != api.SyncEntityType.syncResetV1)
        type,
  };

  for (final type in requiredTypes) {
    expect(
      ackedTypes,
      contains(type),
      reason: 'Expected persisted sync ACK for ${type.toJson()} in $ackSet',
    );
  }
}

Future<List<BaseAsset>> _loadAllTimelineAssets(TimelineService timeline) async {
  final assets = <BaseAsset>[];
  for (
    var offset = 0;
    offset < timeline.totalAssets;
    offset += _timelinePageSize
  ) {
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

List<RemoteAsset> _remoteImagesFrom(
  List<BaseAsset> assets,
  int start,
  int count,
) => assets
    .skip(start)
    .whereType<RemoteAsset>()
    .where((asset) => asset.isImage)
    .take(count)
    .toList();

RemoteAsset? _firstRemoteVideo(List<BaseAsset> assets) {
  for (final asset in assets.whereType<RemoteAsset>()) {
    if (asset.isVideo) {
      return asset;
    }
  }
  return null;
}

Future<void> _expectRemoteImageMedia(
  ProviderContainer container,
  WidgetTester tester,
  RemoteAsset asset,
) async {
  final assetsApi = container.read(apiServiceProvider).assetsApi;
  final info = await _waitForBasicAssetInfo(tester, assetsApi, asset.id);
  expect(info.type, api.AssetTypeEnum.IMAGE);
  expect(info.originalFileName, isNotEmpty);
  expect(info.fileCreatedAt.toUtc(), asset.createdAt.toUtc());

  final thumbnail = await _waitForSuccessfulResponse(
    tester,
    () => assetsApi.viewAssetWithHttpInfo(
      asset.id,
      size: api.AssetMediaSize.thumbnail,
    ),
  );
  expect(thumbnail.bodyBytes, isNotEmpty);

  final preview = await _waitForSuccessfulResponse(
    tester,
    () => assetsApi.viewAssetWithHttpInfo(
      asset.id,
      size: api.AssetMediaSize.preview,
    ),
  );
  expect(preview.bodyBytes, isNotEmpty);

  final original = await _waitForSuccessfulResponse(
    tester,
    () => container
        .read(assetApiRepositoryProvider)
        .downloadAsset(asset.id, edited: false),
  );
  expect(original.bodyBytes, isNotEmpty);
  final checksum = asset.checksum;
  expect(checksum, isNotNull);
  expect(base64Encode(md5.convert(original.bodyBytes).bytes), checksum);
}

Future<void> _expectRemoteVideoMedia(
  ProviderContainer container,
  WidgetTester tester,
  RemoteAsset asset,
) async {
  final assetsApi = container.read(apiServiceProvider).assetsApi;
  final info = await _waitForBasicAssetInfo(tester, assetsApi, asset.id);
  expect(info.type, api.AssetTypeEnum.VIDEO);
  expect(info.originalFileName, isNotEmpty);
  expect(info.fileCreatedAt.toUtc(), asset.createdAt.toUtc());

  final thumbnail = await _waitForSuccessfulResponse(
    tester,
    () => assetsApi.viewAssetWithHttpInfo(
      asset.id,
      size: api.AssetMediaSize.thumbnail,
    ),
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
      Uri.parse(
        '${Store.get(StoreKey.serverEndpoint)}/assets/${asset.id}/video/playback',
      ),
      headers: {
        ...ApiService.getRequestHeaders(),
        'Authorization': 'Bearer ${Store.get(StoreKey.accessToken)}',
        HttpHeaders.rangeHeader: 'bytes=0-2047',
      },
    ),
    acceptedStatusCodes: const {206},
  );
  expect(rangedPlayback.bodyBytes, isNotEmpty);
  expect(
    rangedPlayback.headers[HttpHeaders.contentRangeHeader],
    startsWith('bytes 0-'),
  );
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
    (widget) =>
        widget is ThumbnailTile &&
        widget.asset != null &&
        widget.asset!.refersToSameAsset(asset),
  );
}

Future<void> _openTimelineAsset(WidgetTester tester, BaseAsset asset) async {
  await _pumpUntilFoundWithReason(
    tester,
    find.byType(Timeline),
    reason: 'Expected timeline before opening asset ${asset.id}',
    timeout: const Duration(seconds: 60),
  );
  await _dismissFeatureMessageIfVisible(tester);

  final tile = _thumbnailTileForAsset(asset);
  final scrollable = find.descendant(
    of: find.byType(Timeline),
    matching: find.byType(Scrollable),
  );
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
  fail(
    'Expected viewer to reach a remote image after swipe, got ${current?.remoteId ?? current?.id ?? 'none'}',
  );
}

Future<BaseAsset> _swipeViewerPage(
  WidgetTester tester,
  ProviderContainer container,
  Offset gestureOffset,
) async {
  final pageView = find.descendant(
    of: find.byType(AssetViewer),
    matching: find.byType(PageView),
  );
  await pumpUntilFound(tester, pageView, timeout: const Duration(seconds: 30));
  final before = container.read(assetViewerProvider).currentAsset;
  await tester.timedDrag(
    pageView.first,
    gestureOffset,
    const Duration(milliseconds: 450),
  );
  await _pumpUntil(tester, () {
    final current = container.read(assetViewerProvider).currentAsset;
    return current != null &&
        (before == null || !current.refersToSameAsset(before));
  }, timeout: const Duration(seconds: 20));
  return container.read(assetViewerProvider).currentAsset!;
}

Future<void> _zoomViewerImage(
  WidgetTester tester,
  ProviderContainer container,
) async {
  final photoView = find.byType(PhotoView);
  await pumpUntilFound(tester, photoView, timeout: const Duration(seconds: 30));
  await tester.tap(photoView.first, warnIfMissed: false);
  await tester.pump(const Duration(milliseconds: 80));
  await tester.tap(photoView.first, warnIfMissed: false);
  await _pumpUntil(
    tester,
    () => container.read(assetViewerProvider).isZoomed,
    timeout: const Duration(seconds: 10),
  );
}

Future<void> _backgroundApp(WidgetTester tester) async {
  for (final state in [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(state);
    if (state != AppLifecycleState.paused) {
      await tester.pump();
    }
  }
}

Future<void> _foregroundApp(WidgetTester tester) async {
  for (final state in [
    AppLifecycleState.hidden,
    AppLifecycleState.inactive,
    AppLifecycleState.resumed,
  ]) {
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

Finder _videoControlsFor(String assetId) => find.byWidgetPredicate(
  (widget) => widget is VideoControls && widget.videoPlayerName == assetId,
);

Future<void> _showVideoControls(
  WidgetTester tester,
  ProviderContainer container,
  String assetId,
) async {
  container.read(assetViewerProvider.notifier).setControls(true);
  await tester.pump();
  await pumpUntilFound(
    tester,
    _videoControlsFor(assetId),
    timeout: const Duration(seconds: 30),
  );
}

Future<void> _tapVideoPlayPauseControl(
  WidgetTester tester,
  ProviderContainer container,
  String assetId,
) async {
  await _showVideoControls(tester, container, assetId);
  final button = find.descendant(
    of: _videoControlsFor(assetId),
    matching: find.byType(IconButton),
  );
  await pumpUntilFound(tester, button, timeout: const Duration(seconds: 30));
  final iconButton = tester.widget<IconButton>(button.first);
  expect(iconButton.onPressed, isNotNull);
  iconButton.onPressed!();
  await _pumpFor(tester, const Duration(milliseconds: 500));
}

Future<void> _playVideoFromControls(
  WidgetTester tester,
  ProviderContainer container,
  String assetId,
) async {
  final state = container.read(videoPlayerProvider(assetId));
  if (state.status == VideoPlaybackStatus.paused ||
      state.status == VideoPlaybackStatus.completed) {
    await _tapVideoPlayPauseControl(tester, container, assetId);
  }

  await _waitForVideoState(
    tester,
    container,
    assetId,
    (state) =>
        state.status == VideoPlaybackStatus.playing ||
        state.status == VideoPlaybackStatus.buffering,
    timeout: const Duration(seconds: 30),
  );
}

Future<void> _pauseVideoFromControls(
  WidgetTester tester,
  ProviderContainer container,
  String assetId,
) async {
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
  final target = Duration(
    microseconds: (loaded.duration.inMicroseconds * fraction).round(),
  );

  await _showVideoControls(tester, container, assetId);
  final slider = find.descendant(
    of: _videoControlsFor(assetId),
    matching: find.byType(Slider),
  );
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

void _realStackSessionTest(
  String caseId,
  String description,
  Future<void> Function(WidgetTester) body,
) {
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

void _realStackAuthTest(
  String caseId,
  String description,
  Future<void> Function(WidgetTester, ImmichTestHelper) body,
) {
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
  expect(
    _serverUrl,
    isNotEmpty,
    reason: 'Pass --dart-define=IMMICH_E2E_SERVER_URL=...',
  );
  expect(_email, isNotEmpty, reason: 'Pass --dart-define=IMMICH_E2E_EMAIL=...');
  expect(
    _password,
    isNotEmpty,
    reason: 'Pass --dart-define=IMMICH_E2E_PASSWORD=...',
  );
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
  List<Override> extraOverrides = const [],
}) async {
  await EasyLocalization.ensureInitialized();
  final (drift, _) = await Bootstrap.initDomain();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        driftProvider.overrideWith(
          _driftOverrideForTest(drift, closeOnDispose: closeDriftOnDispose),
        ),
        if (overrideCancellation)
          cancellationProvider.overrideWithValue(Completer()),
        ...extraOverrides,
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
  bool resetSyncAcksBeforeStart = false,
  List<Override> extraOverrides = const [],
  String email = _email,
  String password = _password,
}) async {
  await EasyLocalization.ensureInitialized();
  final (drift, _) = await Bootstrap.initDomain();
  await Store.clear();

  await _seedAuthenticatedStore(email: email, password: password);
  if (resetSyncAcksBeforeStart) {
    await _deleteSyncAckForStoredSession();
  }

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        driftProvider.overrideWith(
          _driftOverrideForTest(drift, closeOnDispose: closeDriftOnDispose),
        ),
        if (overrideCancellation)
          cancellationProvider.overrideWithValue(Completer()),
        ...extraOverrides,
      ],
      child: const app.MainWidget(),
    ),
  );
  await EasyLocalization.ensureInitialized();
  await _pumpFor(tester, const Duration(milliseconds: 500));
  await _waitForAccessToken(tester);
  await _waitForCurrentUser(email, tester);
  await _dismissFeatureMessageIfVisible(tester);
}

Future<void> _deleteSyncAckForStoredSession() async {
  final apiService = ApiService()..setEndpoint(_apiEndpoint(_serverUrl));
  await apiService.updateHeaders();
  await SyncApiRepository(apiService).deleteSyncAck(_allReplayableSyncAckTypes);
}

Future<ProviderContainer> _restartAuthenticatedApp(
  WidgetTester tester, {
  required String email,
  required String password,
}) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await _pumpFor(tester, const Duration(milliseconds: 500));
  await _loadAuthenticatedApp(
    tester,
    overrideCancellation: true,
    closeDriftOnDispose: false,
    email: email,
    password: password,
  );
  return _containerOfApp(tester);
}

Future<void> _resetAndSyncRemoteState(
  WidgetTester tester,
  ProviderContainer container,
) async {
  await container
      .read(syncApiRepositoryProvider)
      .deleteSyncAck(_allReplayableSyncAckTypes);
  await Store.delete(StoreKey.syncMigrationStatus);
  await container.read(syncStreamRepositoryProvider).reset();
  final syncSuccess = await container.read(syncStreamServiceProvider).sync();
  expect(syncSuccess, isTrue);
  await pumpUntilFound(
    tester,
    find.byType(Timeline),
    timeout: const Duration(seconds: 60),
  );
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
        driftProvider.overrideWith(
          _driftOverrideForTest(drift, closeOnDispose: closeDriftOnDispose),
        ),
        if (overrideCancellation)
          cancellationProvider.overrideWithValue(Completer()),
      ],
      child: const app.MainWidget(),
    ),
  );
  await EasyLocalization.ensureInitialized();
  await _pumpFor(tester, const Duration(milliseconds: 500));
}

Drift Function(Ref ref) _driftOverrideForTest(
  Drift drift, {
  required bool closeOnDispose,
}) => (ref) {
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

Future<void> _seedAuthenticatedStore({
  String email = _email,
  String password = _password,
}) async {
  final endpoint = _apiEndpoint(_serverUrl);
  await Store.put(StoreKey.serverEndpoint, endpoint);
  await Store.put(StoreKey.serverUrl, endpoint);
  await _ensureDeviceId();

  final apiService = ApiService()..setEndpoint(endpoint);
  final response = await AuthApiRepository(apiService).login(email, password);
  expect(response.userEmail, email);
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

Future<String> _loginForAccessToken(String email, String password) async {
  final response = await http.post(
    Uri.parse('${_apiEndpoint(_serverUrl)}/auth/login'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'email': email, 'password': password}),
  );
  expect(
    response.statusCode,
    anyOf(200, 201),
    reason: 'Expected helper login for $email to succeed',
  );
  final body = jsonDecode(response.body) as Map<String, dynamic>;
  expect(body['userEmail'], email);
  return body['accessToken'] as String;
}

Future<int> _loginStatus(String email, String password) async {
  final response = await http.post(
    Uri.parse('${_apiEndpoint(_serverUrl)}/auth/login'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'email': email, 'password': password}),
  );
  return response.statusCode;
}

Future<bool> _changePasswordViaAuthEndpoint({required String currentPassword, required String newPassword}) async {
  final login = await http.post(
    Uri.parse('${_apiEndpoint(_serverUrl)}/auth/login'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'email': _email, 'password': currentPassword}),
  );
  if (login.statusCode < HttpStatus.ok || login.statusCode >= HttpStatus.multipleChoices) {
    return false;
  }
  final token = (jsonDecode(login.body) as Map<String, dynamic>)['accessToken'] as String;
  final response = await http.post(
    Uri.parse('${_apiEndpoint(_serverUrl)}/auth/change-password'),
    headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
    body: jsonEncode({'password': currentPassword, 'newPassword': newPassword, 'invalidateSessions': true}),
  );
  return response.statusCode >= HttpStatus.ok && response.statusCode < HttpStatus.multipleChoices;
}

Future<void> _deleteProfileImageBestEffort(String? accessToken) async {
  if (accessToken == null || accessToken.isEmpty) {
    return;
  }
  try {
    await http.delete(
      Uri.parse('${_apiEndpoint(_serverUrl)}/users/profile-image'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );
  } catch (_) {}
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
  return ProviderScope.containerOf(
    tester.element(find.byType(app.MainWidget)),
    listen: false,
  );
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
    assets.addAll(
      await container.read(localAlbumRepository).getAssets(album.id),
    );
  }
  return assets;
}

Future<LocalAsset> _waitForLocalAssetByName(
  ProviderContainer container,
  String name,
  WidgetTester tester,
) async {
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

Future<LocalAsset> _waitForLocalAssetByNameState(
  ProviderContainer container,
  String name,
  WidgetTester tester,
  bool Function(LocalAsset asset) matches, {
  required String reason,
}) async {
  LocalAsset? latest;
  for (var attempt = 0; attempt < 12; attempt++) {
    await container.read(backgroundSyncProvider).syncLocal(full: true);
    final assets = await _localAssets(container);
    latest = assets.where((asset) => asset.name == name).firstOrNull;
    if (latest != null && matches(latest)) {
      return latest;
    }
    await _pumpFor(tester, const Duration(seconds: 2));
  }

  fail('$reason; latest local asset=$latest');
}

Future<LocalAsset> _saveLocalTestImage(
  ProviderContainer container,
  Set<String> createdLocalAssetIds, {
  required String title,
  required String relativePath,
  required int seed,
}) async {
  final created = await container
      .read(fileMediaRepositoryProvider)
      .saveLocalAsset(
        _generatedJpegBytes(seed),
        title: title,
        relativePath: relativePath,
      );
  expect(
    created,
    isNotNull,
    reason: 'Expected PhotoManager to save local fixture $title',
  );
  createdLocalAssetIds.add(created!.id);
  return created;
}

Future<void> _deleteLocalTestAssetsBestEffort(Iterable<String> assetIds) async {
  final ids = assetIds.toSet().toList(growable: false);
  if (ids.isEmpty) {
    return;
  }
  try {
    await PhotoManager.editor.deleteWithIds(ids);
  } catch (_) {
    // Best-effort cleanup for app-created local media fixtures.
  }
}

Future<void> _waitForLocalAssetGoneByName(
  ProviderContainer container,
  String name,
  WidgetTester tester,
) async {
  var lastSeen = const <String>{};
  for (var attempt = 0; attempt < 12; attempt++) {
    await container.read(backgroundSyncProvider).syncLocal(full: true);
    final assets = await _localAssets(container);
    lastSeen = assets.map((asset) => asset.name).toSet();
    if (!lastSeen.contains(name)) {
      return;
    }
    await _pumpFor(tester, const Duration(seconds: 2));
  }

  final sorted = lastSeen.toList()..sort();
  fail(
    'Local asset $name was still discovered after deletion; saw ${sorted.join(', ')}',
  );
}

Future<List<LocalAlbum>> _waitForLocalAlbumFixtures(
  WidgetTester tester,
  ProviderContainer container, {
  required Set<String> requiredNames,
  String? duplicatedName,
}) async {
  var visibleAlbums = <LocalAlbum>[];
  for (var attempt = 0; attempt < 12; attempt++) {
    await container.read(backgroundSyncProvider).syncLocal(full: true);
    container.invalidate(localAlbumProvider);
    final albums = await container.read(localAlbumServiceProvider).getAll();
    visibleAlbums = albums.where((album) => album.assetCount > 0).toList();
    final names = visibleAlbums.map((album) => album.name).toSet();
    final hasRequired = requiredNames.every(names.contains);
    final hasDuplicatedName =
        duplicatedName == null ||
        visibleAlbums.where((album) => album.name == duplicatedName).length >=
            2;
    if (hasRequired && hasDuplicatedName) {
      return visibleAlbums;
    }
    await _pumpFor(tester, const Duration(seconds: 2));
  }

  final seenNames = visibleAlbums.map((album) => album.name).toSet().toList()
    ..sort();
  final duplicateExpectation = duplicatedName == null
      ? ''
      : ' and two "$duplicatedName" albums';
  fail(
    'Expected local album fixtures $requiredNames$duplicateExpectation; saw ${seenNames.join(', ')}',
  );
}

Future<Set<String>> _localAssetSourceAlbumNames(
  ProviderContainer container,
  LocalAsset asset,
) async {
  final sourceAlbums = await container
      .read(localAssetRepository)
      .getSourceAlbums(asset.id);
  return sourceAlbums.map((album) => album.name).toSet();
}

LocalAlbum _singleAlbumNamed(List<LocalAlbum> albums, String name) {
  final matches = _albumsNamed(albums, name);
  expect(
    matches,
    hasLength(1),
    reason: 'Expected exactly one local album named $name',
  );
  return matches.single;
}

List<LocalAlbum> _albumsNamed(List<LocalAlbum> albums, String name) {
  return albums.where((album) => album.name == name).toList();
}

RecursiveFolder _expectFolderPath(RootFolder root, String path) {
  final normalizedPath = path.startsWith('/') ? path : '/$path';

  RecursiveFolder? visit(RootFolder folder) {
    for (final subfolder in folder.subfolders) {
      final fullPath = subfolder.path.isEmpty
          ? '/${subfolder.name}'
          : '${subfolder.path}/${subfolder.name}';
      if (fullPath == normalizedPath) {
        return subfolder;
      }

      final nested = visit(subfolder);
      if (nested != null) {
        return nested;
      }
    }
    return null;
  }

  final match = visit(root);
  if (match == null) {
    fail('Expected folder path $normalizedPath in server folder structure');
  }
  return match;
}

Future<void> _waitForAppConfigSetting<T>(
  WidgetTester tester,
  SettingsKey<T> settingKey,
  T expected,
) async {
  await _pumpUntil(
    tester,
    () => SettingsRepository.instance.appConfig.read(settingKey) == expected,
    timeout: const Duration(seconds: 10),
  );
}

Future<void> _openSettingsRoot(
  WidgetTester tester,
  ProviderContainer container,
) async {
  final router = container.read(appRouterProvider);

  for (var attempt = 0; attempt < 4; attempt++) {
    final onRoot = find.byType(SettingsPage).evaluate().isNotEmpty && find.byType(SettingsSubPage).evaluate().isEmpty;
    if (onRoot) {
      return;
    }

    if (find.byType(SettingsSubPage).evaluate().isNotEmpty) {
      await router.maybePop();
    } else if (find.byType(SettingsPage).evaluate().isEmpty) {
      unawaited(router.push(const SettingsRoute()));
    }

    await _pumpFor(tester, const Duration(milliseconds: 500));
  }

  await _pumpUntil(
    tester,
    () => find.byType(SettingsPage).evaluate().isNotEmpty && find.byType(SettingsSubPage).evaluate().isEmpty,
    timeout: const Duration(seconds: 30),
  );
}

Future<void> _openSettingsSection(
  WidgetTester tester,
  ProviderContainer container,
  SettingSection section,
) async {
  await _openSettingsRoot(tester, container);
  final card = find.byKey(ValueKey('settings-card-${section.name}'));
  await _scrollSettingsRootUntilHitTestable(tester, card);
  await _tapHitTestableFinder(tester, card, reason: 'Expected ${section.name} settings card to be tappable');
  await _pumpUntil(
    tester,
    () => find.byType(SettingsSubPage).evaluate().any((element) {
      final widget = element.widget;
      return widget is SettingsSubPage && widget.section == section;
    }),
    timeout: const Duration(seconds: 30),
  );
}

Future<void> _scrollSettingsRootUntilHitTestable(
  WidgetTester tester,
  Finder target,
) async {
  final scrollable = find.descendant(
    of: find.byType(SettingsPage),
    matching: find.byType(Scrollable),
  );
  expect(scrollable, findsWidgets);

  for (final delta in const [Offset(0, -350), Offset(0, 350)]) {
    for (var attempt = 0; attempt < 24; attempt++) {
      if (tester.any(target.hitTestable())) {
        return;
      }
      await tester.drag(scrollable.last, delta);
      await _pumpFor(tester, const Duration(milliseconds: 100));
    }
  }

  fail('Expected $target to become hit testable on the settings root page');
}

Future<void> _setSettingsSwitchValue(
  WidgetTester tester,
  Key tileKey,
  bool expected,
) async {
  final tile = find.byKey(tileKey);
  await pumpUntilFound(tester, tile, timeout: const Duration(seconds: 30));
  await tester.ensureVisible(tile.first);
  await _pumpFor(tester, const Duration(milliseconds: 200));
  final switchFinder = find.descendant(of: tile, matching: find.byType(Switch));
  expect(switchFinder, findsOneWidget);
  if (tester.widget<Switch>(switchFinder).value == expected) {
    return;
  }

  await _tapHitTestableFinder(tester, tile, reason: 'Expected $tileKey settings switch to be tappable');
  await _pumpUntil(
    tester,
    () => tester.widget<Switch>(switchFinder).value == expected,
    timeout: const Duration(seconds: 10),
  );
}

Future<void> _setSettingsSliderFraction(
  WidgetTester tester,
  Key sliderKey,
  double fraction,
) async {
  final slider = find.byKey(sliderKey);
  await pumpUntilFound(tester, slider, timeout: const Duration(seconds: 30));
  await tester.ensureVisible(slider.first);
  await _pumpFor(tester, const Duration(milliseconds: 200));
  final rect = tester.getRect(slider.first);
  await tester.tapAt(Offset(rect.left + rect.width * fraction, rect.center.dy));
  await _pumpFor(tester, const Duration(milliseconds: 500));
}

Future<void> _selectSettingsRadioValue(
  WidgetTester tester,
  String keyPrefix,
  Object value,
) async {
  final radio = find.byKey(ValueKey('$keyPrefix-$value'));
  await pumpUntilFound(tester, radio, timeout: const Duration(seconds: 30));
  await tester.ensureVisible(radio.first);
  await _pumpFor(tester, const Duration(milliseconds: 200));
  await _tapHitTestableFinder(tester, radio, reason: 'Expected $keyPrefix $value radio option to be tappable');
  await _pumpFor(tester, const Duration(milliseconds: 500));
}

Future<void> _applyLanguageLocale(WidgetTester tester, Locale locale) async {
  final language = find.text(_languageListLabel(locale), skipOffstage: false);
  await _scrollSettingsListUntilHitTestable(tester, language);
  await _tapHitTestableFinder(tester, language, reason: 'Expected $locale language option to be tappable');

  final apply = find.byKey(const ValueKey('language-settings-apply-button'));
  await _pumpUntil(tester, () {
    final buttons = apply.evaluate();
    return buttons.isNotEmpty && (buttons.first.widget as ElevatedButton).onPressed != null;
  }, timeout: const Duration(seconds: 10));
  await _tapHitTestableFinder(tester, apply, reason: 'Expected language apply button to be tappable');
  await _pumpUntil(
    tester,
    () => Localizations.localeOf(tester.element(find.byType(SettingsSubPage))).toString() == locale.toString(),
    timeout: const Duration(seconds: 10),
  );
}

String _languageListLabel(Locale locale) {
  if (_isSimplifiedChinese(locale)) {
    return 'Chinese Simplified (zh_CN)';
  }

  if (locale.languageCode == 'en') {
    return 'English (en)';
  }

  return locale.toString();
}

bool _isSimplifiedChinese(Locale locale) => locale.languageCode == 'zh' && locale.scriptCode == 'Hans';

Future<void> _scrollSettingsListUntilHitTestable(
  WidgetTester tester,
  Finder target,
) async {
  final scrollable = find.descendant(
    of: find.byType(SettingsSubPage),
    matching: find.byType(Scrollable),
  );
  expect(scrollable, findsWidgets);

  for (final delta in const [Offset(0, -350), Offset(0, 350)]) {
    for (var attempt = 0; attempt < 24; attempt++) {
      if (tester.any(target.hitTestable())) {
        return;
      }
      await tester.drag(scrollable.last, delta);
      await _pumpFor(tester, const Duration(milliseconds: 100));
    }
  }

  fail('Expected $target to become hit testable');
}

Future<void> _expectNotificationSettingsBranch(WidgetTester tester) async {
  final enableButton = find.byKey(const ValueKey('settings-notifications-enable-button'));
  final openButton = find.byKey(const ValueKey('settings-notifications-open-button'));
  await _pumpUntil(
    tester,
    () => enableButton.evaluate().isNotEmpty || openButton.evaluate().isNotEmpty,
    timeout: const Duration(seconds: 30),
  );
  expect(enableButton.evaluate().length + openButton.evaluate().length, 1);
}

Future<void> _restoreSettingsPreferenceDefaults() async {
  await SettingsRepository.instance.write(SettingsKey.themeMode, ThemeMode.system);
  await SettingsRepository.instance.write(SettingsKey.themeColorfulInterface, true);
  await SettingsRepository.instance.write(SettingsKey.shareFileType, ShareAssetType.original);
  await SettingsRepository.instance.write(SettingsKey.timelineStorageIndicator, true);
  await SettingsRepository.instance.write(SettingsKey.timelineTilesPerRow, 4);
  await SettingsRepository.instance.write(SettingsKey.timelineGroupAssetsBy, GroupAssetsBy.day);
  await SettingsRepository.instance.write(SettingsKey.imageLoadOriginal, false);
  await SettingsRepository.instance.write(SettingsKey.viewerTapToNavigate, false);
  await SettingsRepository.instance.write(SettingsKey.viewerAutoPlayVideo, true);
  await SettingsRepository.instance.write(SettingsKey.viewerLoopVideo, true);
  await SettingsRepository.instance.write(SettingsKey.viewerLoadOriginalVideo, false);
  await SettingsRepository.instance.write(SettingsKey.slideshowRepeat, true);
  await SettingsRepository.instance.write(SettingsKey.slideshowDuration, 5);
  await SettingsRepository.instance.write(SettingsKey.slideshowLook, SlideshowLook.blurredBackground);
  await SettingsRepository.instance.write(SettingsKey.slideshowDirection, SlideshowDirection.forward);
  await Store.put(StoreKey.enableHapticFeedback, true);
}

Future<void> _restoreLocaleIfPossible(WidgetTester tester, Locale locale) async {
  final candidateFinders = [
    find.byType(SettingsSubPage),
    find.byType(SettingsPage),
    find.byType(MaterialApp),
    find.byType(app.MainWidget),
  ];

  for (final finder in candidateFinders) {
    for (final element in finder.evaluate()) {
      final localization = EasyLocalization.of(element);
      if (localization != null) {
        await localization.setLocale(locale);
        return;
      }
    }
  }
}

Finder _timelineAssetTiles() {
  return find.byWidgetPredicate(
    (widget) => widget is ThumbnailTile && widget.asset != null,
  );
}

Finder _timelineAssetTileForAsset(BaseAsset asset) {
  return find.byWidgetPredicate(
    (widget) => widget is ThumbnailTile && widget.asset == asset,
  );
}

Finder _timelineAssetTileForAssetId(String assetId) {
  return find.byWidgetPredicate(
    (widget) =>
        widget is ThumbnailTile &&
        widget.asset != null &&
        _timelineAssetId(widget.asset!) == assetId,
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

Future<void> _waitForVisibleTimelineAssetTiles(
  WidgetTester tester, {
  required int minCount,
}) async {
  await _pumpUntil(
    tester,
    () => _timelineAssetTiles().evaluate().length >= minCount,
    timeout: const Duration(seconds: 60),
  );
}

Future<void> _selectTimelineAssetsById(
  WidgetTester tester,
  ProviderContainer container,
  List<String> assetIds,
) async {
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
    await _waitForSelectedTimelineAssetIds(
      tester,
      container,
      assetIds.take(index + 1).toSet(),
    );
  }
}

Finder _bottomSheetIcon(Type bottomSheetType, IconData icon) {
  return find.descendant(
    of: find.byType(bottomSheetType),
    matching: find.byIcon(icon),
  );
}

Future<void> _tapBottomSheetAction(
  WidgetTester tester,
  Type bottomSheetType,
  IconData icon,
) async {
  await pumpUntilFound(
    tester,
    find.byType(bottomSheetType),
    timeout: const Duration(seconds: 30),
  );
  final actionIcon = _bottomSheetIcon(bottomSheetType, icon);
  await pumpUntilFound(
    tester,
    actionIcon,
    timeout: const Duration(seconds: 30),
  );

  final actionScroll = find.descendant(
    of: find.byType(bottomSheetType),
    matching: find.byType(SingleChildScrollView),
  );
  await tester.ensureVisible(actionIcon.last);
  await _pumpFor(tester, const Duration(milliseconds: 200));
  for (
    var attempt = 0;
    attempt < 16 && actionIcon.hitTestable().evaluate().isEmpty;
    attempt++
  ) {
    if (actionScroll.evaluate().isEmpty) {
      break;
    }
    await tester.drag(actionScroll.first, const Offset(-520, 0));
    await _pumpFor(tester, const Duration(milliseconds: 200));
  }

  expect(
    actionIcon.hitTestable(),
    findsWidgets,
    reason: 'Expected action icon $icon to be tappable',
  );
  await tester.tap(actionIcon.hitTestable().first);
  await _pumpFor(tester, const Duration(milliseconds: 500));
}

Future<void> _tapTrashMenuAction(WidgetTester tester, String labelKey) async {
  await pumpUntilFound(
    tester,
    find.byType(DriftTrashPage),
    timeout: const Duration(seconds: 30),
  );
  final menuButton = find.descendant(
    of: find.byType(DriftTrashPage),
    matching: find.byIcon(Icons.more_vert_rounded),
  );
  await tester.tap(menuButton.last);
  await _pumpFor(tester, const Duration(milliseconds: 300));
  await tester.tap(find.text(labelKey.tr()).last);
  await _pumpFor(tester, const Duration(milliseconds: 300));
}

Future<void> _tapConfirmDialogButton(
  WidgetTester tester, {
  required bool confirm,
}) async {
  await pumpUntilFound(
    tester,
    find.byType(ConfirmDialog),
    timeout: const Duration(seconds: 30),
  );
  final label = confirm
      ? 'backup_controller_page_background_battery_info_ok'.tr()
      : 'cancel'.tr();
  final button = find.descendant(
    of: find.byType(ConfirmDialog),
    matching: find.text(label),
  );
  expect(
    button,
    findsWidgets,
    reason: 'Expected confirmation dialog button "$label"',
  );
  await tester.tap(button.last);
  await _pumpFor(tester, const Duration(milliseconds: 500));
}

const _sharePlusChannel = MethodChannel('dev.fluttercommunity.plus/share');
const _legacyUrlLauncherChannel = MethodChannel(
  'plugins.flutter.io/url_launcher',
);

BasicMessageChannel<Object?> _urlLauncherPigeonChannel(String method) =>
    BasicMessageChannel<Object?>(
      'dev.flutter.pigeon.url_launcher_android.UrlLauncherApi.$method',
      const StandardMessageCodec(),
    );

class _ShareInvocation {
  final List<String> paths;
  final List<String> mimeTypes;
  final List<bool> existedWhenShared;

  const _ShareInvocation({
    required this.paths,
    required this.mimeTypes,
    required this.existedWhenShared,
  });
}

void _recordSharePlusInvocations(List<_ShareInvocation> invocations) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_sharePlusChannel, (call) async {
        if (call.method != 'shareFiles') {
          return '';
        }

        final arguments = call.arguments as Map<dynamic, dynamic>;
        final paths = (arguments['paths'] as List<dynamic>).cast<String>();
        final mimeTypes = (arguments['mimeTypes'] as List<dynamic>)
            .cast<String>();
        invocations.add(
          _ShareInvocation(
            paths: paths,
            mimeTypes: mimeTypes,
            existedWhenShared: paths
                .map((path) => File(path).existsSync())
                .toList(growable: false),
          ),
        );
        return '';
      });
}

void _clearSharePlusInvocationRecorder() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_sharePlusChannel, null);
}

void _recordUrlLauncherInvocations(List<String> launchedUrls) {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockDecodedMessageHandler<Object?>(
    _urlLauncherPigeonChannel('canLaunchUrl'),
    (_) async {
      return <Object?>[true];
    },
  );
  messenger.setMockDecodedMessageHandler<Object?>(
    _urlLauncherPigeonChannel('launchUrl'),
    (message) async {
      final arguments = message! as List<Object?>;
      launchedUrls.add(arguments.first! as String);
      return <Object?>[true];
    },
  );
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
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockDecodedMessageHandler<Object?>(
    _urlLauncherPigeonChannel('canLaunchUrl'),
    null,
  );
  messenger.setMockDecodedMessageHandler<Object?>(
    _urlLauncherPigeonChannel('launchUrl'),
    null,
  );
  messenger.setMockMethodCallHandler(_legacyUrlLauncherChannel, null);
}

Future<void> _waitForShareInvocationCount(
  WidgetTester tester,
  List<_ShareInvocation> invocations,
  int count,
) async {
  await _pumpUntil(
    tester,
    () => invocations.length >= count,
    timeout: const Duration(seconds: 30),
  );
}

void _expectSharedDisplayNames(
  _ShareInvocation invocation,
  Set<String> displayNames,
) {
  expect(invocation.paths, hasLength(displayNames.length));
  expect(invocation.mimeTypes, hasLength(displayNames.length));
  expect(invocation.existedWhenShared, everyElement(isTrue));
  for (final name in displayNames) {
    expect(
      invocation.paths.any(
        (path) => path.endsWith('/$name') || path.endsWith('-$name'),
      ),
      isTrue,
      reason:
          'Expected a shared file path for $name in ${invocation.paths.join(', ')}',
    );
  }
}

Future<File> _writeShareIntentImageFile(
  Directory directory,
  String filename,
  int seed,
) async {
  final file = File('${directory.path}/$filename');
  await file.writeAsBytes(_generatedJpegBytes(seed));
  return file;
}

Future<File> _writeShareIntentVideoFile(
  ProviderContainer container,
  WidgetTester tester,
  RemoteAsset source,
  Directory directory,
  String filename,
  String token,
) async {
  final original = await _waitForSuccessfulResponse(
    tester,
    () => container
        .read(assetApiRepositoryProvider)
        .downloadAsset(source.id, edited: false),
  );
  final file = File('${directory.path}/$filename');
  final sink = file.openWrite();
  sink.add(original.bodyBytes);
  sink.add(_mp4FreeBoxBytes('immich-e2e-share-intent-042-$token'));
  await sink.close();
  return file;
}

List<int> _mp4FreeBoxBytes(String payload) {
  final payloadBytes = utf8.encode(payload);
  final size = payloadBytes.length + 8;
  return [
    (size >> 24) & 0xff,
    (size >> 16) & 0xff,
    (size >> 8) & 0xff,
    size & 0xff,
    0x66,
    0x72,
    0x65,
    0x65,
    ...payloadBytes,
  ];
}

Future<ShareIntentAttachment> _shareIntentAttachment(
  File file,
  ShareIntentAttachmentType type,
) async {
  return ShareIntentAttachment(
    path: file.path,
    type: type,
    status: UploadStatus.enqueued,
    fileLength: await file.length(),
  );
}

Future<void> _waitForShareIntentPage(
  WidgetTester tester,
  Set<String> filenames,
) async {
  await pumpUntilFound(
    tester,
    find.byType(ShareIntentPage),
    timeout: const Duration(seconds: 30),
  );
  for (final filename in filenames) {
    await pumpUntilFound(
      tester,
      find.text(filename),
      timeout: const Duration(seconds: 30),
    );
  }
}

Future<List<ShareIntentAttachment>> _waitForShareIntentState(
  WidgetTester tester,
  ProviderContainer container,
  bool Function(List<ShareIntentAttachment> attachments) matches, {
  required String reason,
  Duration timeout = const Duration(seconds: 90),
}) async {
  var latest = const <ShareIntentAttachment>[];
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    latest = container.read(shareIntentUploadProvider);
    if (matches(latest)) {
      return latest;
    }
    await _pumpFor(tester, const Duration(milliseconds: 200));
  }

  fail(
    '$reason; latest share intent state=${_describeShareIntentState(latest)}',
  );
}

Future<EditorState> _waitForEditorState(
  WidgetTester tester,
  ProviderContainer container,
  bool Function(EditorState state) matches, {
  required String reason,
}) async {
  EditorState? latest;
  final end = DateTime.now().add(const Duration(seconds: 30));
  while (DateTime.now().isBefore(end)) {
    final current = container.read(editorStateProvider);
    latest = current;
    if (matches(current)) {
      return current;
    }
    await _pumpFor(tester, const Duration(milliseconds: 200));
  }

  fail('$reason; latest editor state=$latest');
}

Future<List<AssetEdit>> _waitForLocalAssetEdits(
  WidgetTester tester,
  ProviderContainer container,
  String remoteAssetId,
  bool Function(List<AssetEdit> edits) matches, {
  required String reason,
}) async {
  var latest = const <AssetEdit>[];
  final end = DateTime.now().add(const Duration(seconds: 60));
  while (DateTime.now().isBefore(end)) {
    latest = await container
        .read(remoteAssetRepositoryProvider)
        .getAssetEdits(remoteAssetId);
    if (matches(latest)) {
      return latest;
    }
    await _pumpFor(tester, const Duration(milliseconds: 500));
  }

  fail(
    '$reason; latest edits=${latest.map((edit) => edit.runtimeType).join(', ')}',
  );
}

Future<http.Response> _waitForEditedAssetDownloadWithSize(
  WidgetTester tester,
  ProviderContainer container,
  String remoteAssetId,
  bool Function(({int width, int height}) size) matches, {
  required String reason,
}) async {
  ({int width, int height})? latestSize;
  http.Response? lastResponse;
  Object? lastError;
  final end = DateTime.now().add(const Duration(minutes: 2));
  while (DateTime.now().isBefore(end)) {
    try {
      final response = await container
          .read(assetApiRepositoryProvider)
          .downloadAsset(remoteAssetId, edited: true);
      lastResponse = response;
      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        latestSize = await _decodeImageSize(response.bodyBytes);
        if (matches(latestSize)) {
          return response;
        }
      }
    } catch (error) {
      lastError = error;
    }
    await _pumpFor(tester, const Duration(seconds: 2));
  }

  fail(
    '$reason; latest edited image size=$latestSize; '
    'last status=${lastResponse?.statusCode}; last error=$lastError',
  );
}

Future<void> _tapEditorAspectRatio(WidgetTester tester, String label) async {
  final ratioText = find.descendant(
    of: find.byType(DriftEditImagePage),
    matching: find.text(label),
  );
  final ratioStrip = find.descendant(
    of: find.byType(DriftEditImagePage),
    matching: find.byType(SingleChildScrollView),
  );
  await pumpUntilFound(tester, ratioText, timeout: const Duration(seconds: 30));

  for (var attempt = 0; attempt < 8; attempt++) {
    final visibleText = ratioText.hitTestable();
    if (tester.any(visibleText)) {
      final textCenter = tester.getCenter(visibleText.first);
      await tester.tapAt(textCenter.translate(0, -38));
      await _pumpFor(tester, const Duration(milliseconds: 400));
      return;
    }
    expect(
      ratioStrip,
      findsWidgets,
      reason: 'Expected the editor aspect ratio strip to be visible',
    );
    await tester.drag(ratioStrip.last, const Offset(-240, 0));
    await _pumpFor(tester, const Duration(milliseconds: 300));
  }

  fail('Could not tap editor aspect ratio $label');
}

Future<void> _tapEditorIcon(
  WidgetTester tester,
  IconData icon, {
  int occurrence = 0,
}) async {
  final iconFinder = find
      .descendant(
        of: find.byType(DriftEditImagePage),
        matching: find.byIcon(icon),
      )
      .hitTestable();
  await pumpUntilFound(
    tester,
    iconFinder,
    timeout: const Duration(seconds: 30),
  );
  expect(
    iconFinder,
    findsAtLeastNWidgets(occurrence + 1),
    reason: 'Expected editor icon $icon to be tappable',
  );
  await tester.tap(iconFinder.at(occurrence), warnIfMissed: false);
  await _pumpFor(tester, const Duration(milliseconds: 500));
}

Future<void> _tapEditorReset(WidgetTester tester) async {
  final resetButton = find.descendant(
    of: find.byType(DriftEditImagePage),
    matching: find.text('reset'.tr()),
  );
  await pumpUntilFound(
    tester,
    resetButton,
    timeout: const Duration(seconds: 30),
  );
  expect(
    resetButton.hitTestable(),
    findsWidgets,
    reason: 'Expected the editor reset button to be tappable',
  );
  await tester.tap(resetButton.hitTestable().last, warnIfMissed: false);
  await _pumpFor(tester, const Duration(milliseconds: 500));
}

String _describeShareIntentState(List<ShareIntentAttachment> attachments) {
  return attachments
      .map(
        (attachment) =>
            '${attachment.fileName}:${attachment.type.name}:${attachment.status.name}:${attachment.uploadProgress}',
      )
      .join(', ');
}

Future<void> _showViewerControls(
  WidgetTester tester,
  ProviderContainer container,
) async {
  await _pumpUntilFoundWithReason(
    tester,
    find.byType(AssetViewer),
    reason: 'Expected asset viewer before showing controls',
    timeout: const Duration(seconds: 30),
  );
  container.read(assetViewerProvider.notifier).setControls(true);
  await _pumpFor(tester, const Duration(milliseconds: 300));
}

Future<void> _tapViewerActionIcon(WidgetTester tester, IconData icon) async {
  final actionIcon = find.descendant(
    of: find.byType(AssetViewer),
    matching: find.byIcon(icon),
  );
  await pumpUntilFound(
    tester,
    actionIcon,
    timeout: const Duration(seconds: 30),
  );
  expect(
    actionIcon.hitTestable(),
    findsWidgets,
    reason: 'Expected viewer action icon $icon to be tappable',
  );
  await tester.tap(actionIcon.hitTestable().first, warnIfMissed: false);
  await _pumpFor(tester, const Duration(milliseconds: 500));
}

Future<void> _tapViewerMenuAction(WidgetTester tester, IconData icon) async {
  final menuButton = find.descendant(
    of: find.byType(AssetViewer),
    matching: find.byIcon(Icons.more_vert_rounded),
  );
  await pumpUntilFound(
    tester,
    menuButton,
    timeout: const Duration(seconds: 30),
  );
  expect(
    menuButton.hitTestable(),
    findsWidgets,
    reason: 'Expected viewer menu button to be tappable',
  );
  await tester.tap(menuButton.hitTestable().last, warnIfMissed: false);
  await _pumpFor(tester, const Duration(milliseconds: 500));

  final actionIcon = find.byIcon(icon);
  await pumpUntilFound(
    tester,
    actionIcon,
    timeout: const Duration(seconds: 30),
  );
  expect(
    actionIcon.hitTestable(),
    findsWidgets,
    reason: 'Expected viewer menu action icon $icon to be tappable',
  );
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
    final currentCount = updates
        .where(
          (update) => update.task.taskId == taskId && update.status == status,
        )
        .length;
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

Future<void> _expandBottomSheet(
  WidgetTester tester,
  Type bottomSheetType,
) async {
  await pumpUntilFound(
    tester,
    find.byType(bottomSheetType),
    timeout: const Duration(seconds: 30),
  );

  final sheet = find.descendant(
    of: find.byType(bottomSheetType),
    matching: find.byType(DraggableScrollableSheet),
  );
  final dragTarget = sheet.evaluate().isNotEmpty
      ? sheet.last
      : find.byType(bottomSheetType).last;
  await tester.drag(dragTarget, const Offset(0, -520), warnIfMissed: false);
  await _pumpFor(tester, const Duration(milliseconds: 400));
}

Future<void> _tapAlbumInSelector(
  WidgetTester tester,
  Type bottomSheetType,
  String albumName,
) async {
  await _expandBottomSheet(tester, bottomSheetType);
  await pumpUntilFound(
    tester,
    find.byType(AlbumSelector),
    timeout: const Duration(seconds: 30),
  );

  final selector = find.byType(AlbumSelector);
  final searchField = find.descendant(
    of: selector,
    matching: find.byType(TextField),
  );
  await pumpUntilFound(
    tester,
    searchField,
    timeout: const Duration(seconds: 30),
  );
  await tester.tap(searchField.first, warnIfMissed: false);
  await tester.enterText(searchField.first, albumName);
  await _pumpFor(tester, const Duration(milliseconds: 500));
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await _pumpFor(tester, const Duration(milliseconds: 300));

  final albumText = find.descendant(
    of: selector,
    matching: find.byWidgetPredicate(
      (widget) => widget is Text && widget.data == albumName,
    ),
  );
  final scrollable = find.descendant(
    of: find.byType(bottomSheetType),
    matching: find.byType(Scrollable),
  );

  await _pumpUntil(
    tester,
    () => albumText.evaluate().isNotEmpty,
    timeout: const Duration(seconds: 30),
  );

  for (
    var attempt = 0;
    attempt < 8 && albumText.hitTestable().evaluate().isEmpty;
    attempt++
  ) {
    if (scrollable.evaluate().isEmpty) {
      break;
    }
    await tester.drag(
      scrollable.last,
      const Offset(0, -360),
      warnIfMissed: false,
    );
    await _pumpFor(tester, const Duration(milliseconds: 200));
  }

  expect(
    albumText.hitTestable(),
    findsWidgets,
    reason: 'Expected album "$albumName" to be tappable in selector',
  );
  final inkWell = find
      .ancestor(of: albumText, matching: find.byType(InkWell))
      .hitTestable();
  final gestureDetector = find
      .ancestor(of: albumText, matching: find.byType(GestureDetector))
      .hitTestable();
  if (inkWell.evaluate().isNotEmpty) {
    await tester.tap(inkWell.first, warnIfMissed: false);
  } else if (gestureDetector.evaluate().isNotEmpty) {
    await tester.tap(gestureDetector.last, warnIfMissed: false);
  } else {
    await tester.tap(albumText.hitTestable().first, warnIfMissed: false);
  }
  await _pumpFor(tester, const Duration(milliseconds: 500));
}

Future<void> _createAlbumFromBottomSheet(
  WidgetTester tester,
  String albumName,
) async {
  await _expandBottomSheet(tester, GeneralBottomSheet);
  await pumpUntilFound(
    tester,
    find.byType(AddToAlbumHeader),
    timeout: const Duration(seconds: 30),
  );

  final createButton = find.descendant(
    of: find.byType(AddToAlbumHeader),
    matching: find.widgetWithText(TextButton, 'common_create_new_album'.tr()),
  );
  await pumpUntilFound(
    tester,
    createButton,
    timeout: const Duration(seconds: 30),
  );
  for (
    var attempt = 0;
    attempt < 4 && createButton.hitTestable().evaluate().isEmpty;
    attempt++
  ) {
    await _expandBottomSheet(tester, GeneralBottomSheet);
  }
  expect(
    createButton.hitTestable(),
    findsWidgets,
    reason:
        'Expected the create-new-album button to be tappable in the bottom sheet',
  );
  await tester.tap(createButton.hitTestable().last, warnIfMissed: false);

  await pumpUntilFound(
    tester,
    find.byType(AlertDialog),
    timeout: const Duration(seconds: 30),
  );
  final nameField = find.descendant(
    of: find.byType(AlertDialog),
    matching: find.byType(TextFormField),
  );
  await pumpUntilFound(tester, nameField, timeout: const Duration(seconds: 30));
  await tester.enterText(nameField.first, albumName);
  await _pumpFor(tester, const Duration(milliseconds: 200));
  FocusManager.instance.primaryFocus?.unfocus();
  await _pumpFor(tester, const Duration(milliseconds: 300));

  final dialogCreate = find.descendant(
    of: find.byType(AlertDialog),
    matching: find.widgetWithText(TextButton, 'create_album'.tr()),
  );
  await pumpUntilFound(
    tester,
    dialogCreate,
    timeout: const Duration(seconds: 30),
  );
  expect(
    dialogCreate.hitTestable(),
    findsWidgets,
    reason: 'Expected the dialog create-album button to be tappable',
  );
  await tester.tap(dialogCreate.hitTestable().last, warnIfMissed: false);
  await _pumpFor(tester, const Duration(milliseconds: 500));
}

Future<void> _tapSnackbarAction(WidgetTester tester) async {
  await pumpUntilFound(
    tester,
    find.byType(SnackBarAction),
    timeout: const Duration(seconds: 10),
  );
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
    latest = _timelineAssetIds(
      container.read(multiSelectProvider).selectedAssets,
    );
    if (latest.length == expected.length && latest.containsAll(expected)) {
      return;
    }
    await _pumpFor(tester, const Duration(milliseconds: 200));
  }

  final sortedExpected = expected.toList()..sort();
  final sortedLatest = latest.toList()..sort();
  fail(
    'Expected selected timeline asset ids $sortedExpected but saw $sortedLatest',
  );
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
      final createdAt = DateTime.utc(
        2024,
        1 + (i % 12),
        1 + (i % 24),
        12,
        i % 60,
        i % 60,
      );
      final fileName =
          '$_multiSelectRemoteSeedPrefix$runId-${i.toString().padLeft(2, '0')}.jpg';
      final assetId = await _uploadGeneratedJpegAsSecondClient(
        fileName,
        createdAt,
      );
      createdRemoteAssetIds.add(assetId);
    }

    final syncSuccess = await container.read(syncStreamServiceProvider).sync();
    expect(
      syncSuccess,
      isTrue,
      reason: 'Expected 038 remote seed assets to sync into the Drift timeline',
    );
    await _pumpFor(tester, const Duration(seconds: 2));
  }

  return _waitForTimelineBuckets(
    tester,
    timeline,
    minAssets: _multiSelectMinimumAssetCount,
  );
}

Future<void> _seedUpgradeState(WidgetTester tester) async {
  final snapshotFile = await _upgradeSnapshotFile();
  if (snapshotFile.existsSync()) {
    snapshotFile.deleteSync();
  }

  await _loadAuthenticatedApp(
    tester,
    overrideCancellation: true,
    closeDriftOnDispose: false,
  );
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
  expect(
    localAssets,
    isNotEmpty,
    reason:
        'Expected the seeded app data to include the simulator media library',
  );

  final syncSuccess = await container.read(syncStreamServiceProvider).sync();
  expect(syncSuccess, isTrue);

  final localRows = await _upgradeLocalRowCounts(drift);
  expect(localRows['local_asset_entity'], greaterThan(0));
  expect(localRows['local_album_entity'], greaterThan(0));
  expect(localRows['store_entity'], greaterThan(0));
  expect(localRows['settings'], greaterThan(0));

  final remoteRows = await _remoteSyncRowCounts(drift);
  expect(remoteRows['remote_asset_entity'], greaterThan(0));

  final localAssetNames =
      localAssets.map((asset) => asset.name).toSet().toList()..sort();
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

  await _loadAppPreservingStore(
    tester,
    overrideCancellation: true,
    closeDriftOnDispose: false,
  );
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
    localAssetNames
        .intersection(_jsonStringSet(snapshot['localAssetNames']))
        .isNotEmpty,
    isTrue,
    reason:
        'Expected simulator library assets discovered before upgrade to remain visible after upgrade',
  );

  final beforeLocalRows = _jsonIntMap(snapshot['localRows']);
  final afterLocalRows = await _upgradeLocalRowCounts(drift);
  _expectRowsNotReduced(
    afterLocalRows,
    beforeLocalRows,
    label: 'local library after upgrade',
  );

  final beforeRemoteRows = _jsonIntMap(snapshot['remoteRows']);
  final syncSuccess = await container.read(syncStreamServiceProvider).sync();
  expect(syncSuccess, isTrue);
  final afterRemoteRows = await _remoteSyncRowCounts(drift);
  _expectRowsNotReduced(
    afterRemoteRows,
    beforeRemoteRows,
    label: 'remote sync after upgrade',
  );

  final secondSyncSuccess = await container
      .read(syncStreamServiceProvider)
      .sync();
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
    reason:
        'Expected upgrade seed snapshot to survive app reinstall without data wipe',
  );
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

Future<void> _writeUpgradeBackupSettings() async {
  await SettingsRepository.instance.write(SettingsKey.backupEnabled, true);
  await SettingsRepository.instance.write(
    SettingsKey.backupUseCellularForPhotos,
    true,
  );
  await SettingsRepository.instance.write(
    SettingsKey.backupUseCellularForVideos,
    true,
  );
  await SettingsRepository.instance.write(
    SettingsKey.backupRequireCharging,
    true,
  );
  await SettingsRepository.instance.write(SettingsKey.backupTriggerDelay, 17);
}

Map<String, Object> _readUpgradeBackupSettings() {
  final config = SettingsRepository.instance.appConfig;
  return {
    'backupEnabled': config.read(SettingsKey.backupEnabled),
    'backupUseCellularForPhotos': config.read(
      SettingsKey.backupUseCellularForPhotos,
    ),
    'backupUseCellularForVideos': config.read(
      SettingsKey.backupUseCellularForVideos,
    ),
    'backupRequireCharging': config.read(SettingsKey.backupRequireCharging),
    'backupTriggerDelay': config.read(SettingsKey.backupTriggerDelay),
  };
}

Future<Map<String, int>> _upgradeLocalRowCounts(Drift drift) async {
  const tables = [
    'store_entity',
    'settings',
    'local_album_entity',
    'local_asset_entity',
    'local_album_asset_entity',
  ];
  return {for (final table in tables) table: await _rowCount(drift, table)};
}

void _expectRowsNotReduced(
  Map<String, int> actualRows,
  Map<String, int> minimumRows, {
  required String label,
}) {
  for (final entry in minimumRows.entries) {
    expect(
      actualRows[entry.key],
      greaterThanOrEqualTo(entry.value),
      reason:
          '$label row count for ${entry.key} should not shrink: before=$minimumRows after=$actualRows',
    );
  }
}

Map<String, int> _jsonIntMap(Object? raw) {
  final map = raw! as Map<String, dynamic>;
  return {
    for (final entry in map.entries) entry.key: (entry.value as num).toInt(),
  };
}

Set<String> _jsonStringSet(Object? raw) =>
    (raw! as List).cast<String>().toSet();

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
    await _pumpUntil(
      tester,
      () => find.byType(pageType).evaluate().isNotEmpty,
      timeout: const Duration(seconds: 30),
    );
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
    expect(
      tester.widget<NavigationRail>(find.byType(NavigationRail)).selectedIndex,
      selectedIndex,
    );
    return;
  }

  expect(find.byType(NavigationBar), findsOneWidget);
  expect(find.byType(NavigationRail), findsNothing);
  expect(
    tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
    selectedIndex,
  );
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

Future<void> _selectSearchTextType(WidgetTester tester, Key menuItemKey) async {
  await _tapHitTestableFinder(
    tester,
    find.byKey(const Key('search-type-menu-button')),
  );
  await _tapHitTestableFinder(
    tester,
    find.byKey(menuItemKey),
    reason: 'Expected search type menu item $menuItemKey to be tappable',
  );
  await _pumpFor(tester, const Duration(milliseconds: 300));
}

Future<void> _openSearchFilterSheet(WidgetTester tester, Key chipKey) async {
  final chipList = find.byKey(const Key('search_filter_chip_list'));
  await pumpUntilFound(tester, chipList, timeout: const Duration(seconds: 30));
  final chipScrollable = find.descendant(
    of: chipList,
    matching: find.byType(Scrollable),
  );
  await pumpUntilFound(
    tester,
    chipScrollable,
    timeout: const Duration(seconds: 30),
  );

  final chip = find.byKey(chipKey);
  for (final offset in const [Offset(-260, 0), Offset(260, 0)]) {
    for (var attempt = 0; attempt < 12 && !tester.any(chip); attempt++) {
      await tester.drag(chipScrollable.first, offset);
      await _pumpFor(tester, const Duration(milliseconds: 150));
    }
    if (tester.any(chip)) {
      break;
    }
  }

  await pumpUntilFound(tester, chip, timeout: const Duration(seconds: 30));
  await tester.ensureVisible(chip);
  await _pumpFor(tester, const Duration(milliseconds: 200));
  await _tapHitTestableFinder(
    tester,
    chip,
    reason: 'Expected search filter chip $chipKey to be tappable',
  );
  await pumpUntilFound(
    tester,
    find.byKey(const Key('search_filter_apply')),
    timeout: const Duration(seconds: 30),
  );
}

Future<void> _applySearchFilterSheet(WidgetTester tester) async {
  await _tapHitTestableFinder(
    tester,
    find.byKey(const Key('search_filter_apply')),
  );
  await _pumpFor(tester, const Duration(milliseconds: 500));
}

Future<void> _clearSearchFilterSheet(WidgetTester tester) async {
  await _tapHitTestableFinder(
    tester,
    find.byKey(const Key('search_filter_clear')),
  );
  await _pumpFor(tester, const Duration(milliseconds: 500));
}

Future<void> _submitSearchText(WidgetTester tester, String value) async {
  final searchField = find.descendant(
    of: find.byKey(const Key('search_text_field')),
    matching: find.byType(TextField),
  );
  await pumpUntilFound(
    tester,
    searchField,
    timeout: const Duration(seconds: 30),
  );
  await tester.tap(searchField.first, warnIfMissed: false);
  await tester.enterText(searchField.first, value);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await _pumpFor(tester, const Duration(milliseconds: 500));
}

Future<void> _expectPhotoRetapScrollsToTop(WidgetTester tester) async {
  await pumpUntilFound(
    tester,
    find.byType(Timeline),
    timeout: const Duration(seconds: 60),
  );
  final scrollable = find.descendant(
    of: find.byType(Timeline),
    matching: find.byType(Scrollable),
  );
  await pumpUntilFound(
    tester,
    scrollable,
    timeout: const Duration(seconds: 30),
  );
  final position = tester.state<ScrollableState>(scrollable.first).position;
  await _pumpUntil(
    tester,
    () => position.maxScrollExtent > 0,
    timeout: const Duration(seconds: 60),
  );

  await tester.fling(scrollable.first, const Offset(0, -1500), 1500);
  await _pumpFor(tester, const Duration(milliseconds: 700));
  expect(position.pixels, greaterThan(0));

  await _selectPrimaryNavigationTab(tester, kPhotoTabIndex);
  await _pumpUntil(
    tester,
    () => position.pixels <= 1,
    timeout: const Duration(seconds: 10),
  );
}

Future<void> _openFavoritePageAndReturn(
  WidgetTester tester,
  ProviderContainer container, {
  required Type expectedNavigationType,
}) async {
  final favorites = find.descendant(
    of: find.byType(DriftLibraryPage),
    matching: find.text('favorites'.tr()),
  );
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
  return router.currentSegments
      .where((route) => route.name == routeName)
      .length;
}

void _expectRouteCount(AppRouter router, String routeName, int count) {
  expect(
    _currentRouteCount(router, routeName),
    count,
    reason:
        'Current route stack: ${router.currentSegments.map((route) => route.name).join(' > ')}',
  );
}

String _routeStackDescription(AppRouter router) {
  return router.currentSegments.map((route) => route.name).join(' > ');
}

Future<Set<String>> _serverAssetIdsByOriginalFilename(
  api.SearchApi searchApi,
  String filename, {
  api.AssetTypeEnum type = api.AssetTypeEnum.IMAGE,
}) async {
  final response = await searchApi.searchAssets(
    _metadataSearchDto(filename: filename, type: type),
  );
  expect(response, isNotNull, reason: 'Expected search response for $filename');
  return _serverSearchAssetIds(response!);
}

Future<Set<String>> _serverAlbumIdsByName(
  api.AlbumsApi albumsApi,
  String albumName,
) async {
  final albums = await albumsApi.getAllAlbums(name: albumName, isOwned: true);
  expect(
    albums,
    isNotNull,
    reason: 'Expected album search response for $albumName',
  );
  return albums!
      .where((album) => album.albumName == albumName)
      .map((album) => album.id)
      .toSet();
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
  fail(
    '$reason; latest server album ids=${sorted.join(', ')}; last error=$lastError',
  );
}

Future<Set<String>> _waitForServerAssetIdsByOriginalFilename(
  WidgetTester tester,
  api.SearchApi searchApi,
  String filename,
  bool Function(Set<String> ids) matches, {
  required String reason,
  api.AssetTypeEnum type = api.AssetTypeEnum.IMAGE,
  Duration timeout = const Duration(seconds: 60),
}) async {
  var latest = const <String>{};
  Object? lastError;
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    try {
      latest = await _serverAssetIdsByOriginalFilename(
        searchApi,
        filename,
        type: type,
      );
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
    final matches = assets
        .where((asset) => asset.name.startsWith(prefix))
        .toList();
    if (matches.length >= count) {
      matches.sort((a, b) => a.name.compareTo(b.name));
      return matches.take(count).toList();
    }
    lastSeen = assets.map((asset) => asset.name).toSet();
    await _pumpFor(tester, const Duration(seconds: 2));
  }

  final sorted = lastSeen.toList()..sort();
  fail(
    'Local assets matching $prefix did not reach $count; saw ${sorted.join(', ')}',
  );
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
      final acceptsEmptyBody = acceptedEmptyBodyStatusCodes.contains(
        response.statusCode,
      );
      if (acceptedStatusCodes.contains(response.statusCode) &&
          (response.bodyBytes.isNotEmpty || acceptsEmptyBody)) {
        return response;
      }
      lastResponse = response;
    } catch (error) {
      lastError = error;
    }
    await _pumpFor(tester, const Duration(seconds: 2));
  }

  if (lastResponse != null) {
    fail(
      'Expected HTTP ${acceptedStatusCodes.join('/')} with body, got ${lastResponse.statusCode}',
    );
  }
  fail(
    'Expected HTTP ${acceptedStatusCodes.join('/')} with body, last error: $lastError',
  );
}

Future<List<String>> _waitForFolderPaths(
  WidgetTester tester,
  api.ViewsApi viewApi,
  bool Function(List<String> paths) matches, {
  required String reason,
  Duration timeout = const Duration(seconds: 60),
}) async {
  var latest = const <String>[];
  Object? lastError;
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    try {
      latest = await viewApi.getUniqueOriginalPaths() ?? const <String>[];
      if (matches(latest)) {
        return latest;
      }
    } catch (error) {
      lastError = error;
    }
    await _pumpFor(tester, const Duration(milliseconds: 500));
  }

  fail(
    '$reason; latest folder paths=${latest.join(', ')}; last error=$lastError',
  );
}

Future<String> _uploadSingleAssetToServer(
  ProviderContainer container,
  LocalAsset asset,
) async {
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
  final request =
      http.MultipartRequest(
          'POST',
          Uri.parse('${Store.get(StoreKey.serverEndpoint)}/assets'),
        )
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
        ..files.add(
          http.MultipartFile.fromBytes('assetData', bytes, filename: fileName),
        );

  final response = await http.Response.fromStream(await request.send());
  expect(
    response.statusCode,
    inInclusiveRange(200, 299),
    reason: response.body,
  );
  final payload = jsonDecode(response.body) as Map<String, dynamic>;
  expect(payload['status'], 'created', reason: response.body);
  final assetId = payload['id'] as String;
  if (sourceMetadata != null && sourceMetadata.isNotEmpty) {
    await _updateTestAssetSourceMetadata(
      assetId,
      fileName,
      createdAt,
      sourceMetadata,
    );
  }
  return assetId;
}

Future<String> _uploadGeneratedMp4AsSecondClient(
  String fileName,
  DateTime createdAt,
) async {
  final bytes = <int>[
    ...base64Decode(_tinyMp4FixtureBase64),
    ..._mp4FreeBoxBytes(fileName),
  ];
  final request =
      http.MultipartRequest(
          'POST',
          Uri.parse('${Store.get(StoreKey.serverEndpoint)}/assets'),
        )
        ..headers.addAll({
          ...ApiService.getRequestHeaders(),
          'Authorization': 'Bearer ${Store.get(StoreKey.accessToken)}',
          'x-immich-checksum': base64Encode(md5.convert(bytes).bytes),
        })
        ..fields.addAll({
          'fileCreatedAt': createdAt.toIso8601String(),
          'fileModifiedAt': createdAt.toIso8601String(),
          'filename': fileName,
          'isFavorite': 'false',
        })
        ..files.add(
          http.MultipartFile.fromBytes('assetData', bytes, filename: fileName),
        );

  final response = await http.Response.fromStream(await request.send());
  expect(
    response.statusCode,
    inInclusiveRange(200, 299),
    reason: response.body,
  );
  final payload = jsonDecode(response.body) as Map<String, dynamic>;
  expect(payload['status'], 'created', reason: response.body);
  return payload['id'] as String;
}

const _tinyMp4FixtureBase64 =
    ''
    'AAAAIGZ0eXBpc29tAAACAGlzb21pc28yYXZjMW1wNDEAAARlbW9vdgAAAGxtdmhkAAAAAAAAAAAAAAAAAAAD6AAAA+gAAQAA'
    'AQAAAAAAAAAAAAAAAAEAAAAAAAAAAAAAAAAAAAABAAAAAAAAAAAAAAAAAABAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'
    'AAAAAgAAA490cmFrAAAAXHRraGQAAAADAAAAAAAAAAAAAAABAAAAAAAAA+gAAAAAAAAAAAAAAAAAAAAAAAEAAAAAAAAAAAAA'
    'AAAAAAABAAAAAAAAAAAAAAAAAABAAAAAABAAAAAQAAAAAAAkZWR0cwAAABxlbHN0AAAAAAAAAAEAAAPoAAAEAAABAAAAAAMH'
    'bWRpYQAAACBtZGhkAAAAAAAAAAAAAAAAAAAyAAAAMgBVxAAAAAAALWhkbHIAAAAAAAAAAHZpZGUAAAAAAAAAAAAAAABWaWRl'
    'b0hhbmRsZXIAAAACsm1pbmYAAAAUdm1oZAAAAAEAAAAAAAAAAAAAACRkaW5mAAAAHGRyZWYAAAAAAAAAAQAAAAx1cmwgAAAA'
    'AQAAAnJzdGJsAAAAvnN0c2QAAAAAAAAAAQAAAK5hdmMxAAAAAAAAAAEAAAAAAAAAAAAAAAAAAAAAABAAEABIAAAASAAAAAAA'
    'AAABFUxhdmM2Mi4yOC4xMDIgbGlieDI2NAAAAAAAAAAAAAAAGP//AAAANGF2Y0MBZAAK/+EAF2dkAAqs2V7ARAAAAwAEAAAD'
    'AMg8SJZYAQAGaOvjyyLA/fj4AAAAABBwYXNwAAAAAQAAAAEAAAAUYnRydAAAAAAAACBoAAAAAAAAABhzdHRzAAAAAAAAAAEA'
    'AAAZAAACAAAAABRzdHNzAAAAAAAAAAEAAAABAAAA2GN0dHMAAAAAAAAAGQAAAAEAAAQAAAAAAQAACgAAAAABAAAEAAAAAAEA'
    'AAAAAAAAAQAAAgAAAAABAAAKAAAAAAEAAAQAAAAAAQAAAAAAAAABAAACAAAAAAEAAAoAAAAAAQAABAAAAAABAAAAAAAAAAEA'
    'AAIAAAAAAQAACgAAAAABAAAEAAAAAAEAAAAAAAAAAQAAAgAAAAABAAAKAAAAAAEAAAQAAAAAAQAAAAAAAAABAAACAAAAAAEA'
    'AAoAAAAAAQAABAAAAAABAAAAAAAAAAEAAAIAAAAAHHN0c2MAAAAAAAAAAQAAAAEAAAAZAAAAAQAAAHhzdHN6AAAAAAAAAAAA'
    'AAAZAAACxQAAAAwAAAAMAAAADAAAAAwAAAASAAAADgAAAAwAAAAMAAAAEgAAAA4AAAAMAAAADAAAABIAAAAOAAAADAAAAAwA'
    'AAASAAAADgAAAAwAAAAMAAAAEgAAAA4AAAAMAAAADAAAABRzdGNvAAAAAAAAAAEAAASVAAAAYnVkdGEAAABabWV0YQAAAAAA'
    'AAAhaGRscgAAAAAAAAAAbWRpcmFwcGwAAAAAAAAAAAAAAAAtaWxzdAAAACWpdG9vAAAAHWRhdGEAAAABAAAAAExhdmY2Mi4x'
    'Mi4xMDIAAAAIZnJlZQAABBVtZGF0AAACrgYF//+q3EXpvebZSLeWLNgg2SPu73gyNjQgLSBjb3JlIDE2NSByMzIyMiBiMzU2'
    'MDVhIC0gSC4yNjQvTVBFRy00IEFWQyBjb2RlYyAtIENvcHlsZWZ0IDIwMDMtMjAyNSAtIGh0dHA6Ly93d3cudmlkZW9sYW4u'
    'b3JnL3gyNjQuaHRtbCAtIG9wdGlvbnM6IGNhYmFjPTEgcmVmPTMgZGVibG9jaz0xOjA6MCBhbmFseXNlPTB4MzoweDExMyBt'
    'ZT1oZXggc3VibWU9NyBwc3k9MSBwc3lfcmQ9MS4wMDowLjAwIG1peGVkX3JlZj0xIG1lX3JhbmdlPTE2IGNocm9tYV9tZT0x'
    'IHRyZWxsaXM9MSA4eDhkY3Q9MSBjcW09MCBkZWFkem9uZT0yMSwxMSBmYXN0X3Bza2lwPTEgY2hyb21hX3FwX29mZnNldD0t'
    'MiB0aHJlYWRzPTEgbG9va2FoZWFkX3RocmVhZHM9MSBzbGljZWRfdGhyZWFkcz0wIG5yPTAgZGVjaW1hdGU9MSBpbnRlcmxh'
    'Y2VkPTAgYmx1cmF5X2NvbXBhdD0wIGNvbnN0cmFpbmVkX2ludHJhPTAgYmZyYW1lcz0zIGJfcHlyYW1pZD0yIGJfYWRhcHQ9'
    'MSBiX2JpYXM9MCBkaXJlY3Q9MSB3ZWlnaHRiPTEgb3Blbl9nb3A9MCB3ZWlnaHRwPTIga2V5aW50PTI1MCBrZXlpbnRfbWlu'
    'PTI1IHNjZW5lY3V0PTQwIGludHJhX3JlZnJlc2g9MCByY19sb29rYWhlYWQ9NDAgcmM9Y3JmIG1idHJlZT0xIGNyZj0yMy4w'
    'IHFjb21wPTAuNjAgcXBtaW49MCBxcG1heD02OSBxcHN0ZXA9NCBpcF9yYXRpbz0xLjQwIGFxPTE6MS4wMACAAAAAD2WIhAA7'
    '//73Tr8Cm1TCYQAAAAhBmiRsQ7/+4AAAAAhBnkJ4hf/BgQAAAAgBnmF0Qr/EgAAAAAgBnmNqQr/EgQAAAA5BmmhJqEFomUwI'
    'd//+4QAAAApBnoZFESwv/8GBAAAACAGepXRCv8SBAAAACAGep2pCv8SAAAAADkGarEmoQWyZTAh3//7gAAAACkGeykUVLC//'
    'wYEAAAAIAZ7pdEK/xIAAAAAIAZ7rakK/xIAAAAAOQZrwSahBbJlMCG///uEAAAAKQZ8ORRUsL//BgQAAAAgBny10Qr/EgQAA'
    'AAgBny9qQr/EgAAAAA5BmzRJqEFsmUwIZ//+4AAAAApBn1JFFSwv/8GBAAAACAGfcXRCv8SAAAAACAGfc2pCv8SAAAAADkGb'
    'eEmoQWyZTAhX//7BAAAACkGflkUVLC//wYAAAAAIAZ+1dEK/xIEAAAAIAZ+3akK/xIE=';

Future<String> _uploadGeneratedPngAsSecondClient(
  String fileName,
  DateTime createdAt, {
  required int width,
  required int height,
}) async {
  final bytes = await _generatedPngBytes(
    createdAt.microsecondsSinceEpoch,
    width: width,
    height: height,
  );
  final request =
      http.MultipartRequest(
          'POST',
          Uri.parse('${Store.get(StoreKey.serverEndpoint)}/assets'),
        )
        ..headers.addAll({
          ...ApiService.getRequestHeaders(),
          'Authorization': 'Bearer ${Store.get(StoreKey.accessToken)}',
          'x-immich-checksum': base64Encode(md5.convert(bytes).bytes),
        })
        ..fields.addAll({
          'fileCreatedAt': createdAt.toIso8601String(),
          'fileModifiedAt': createdAt.toIso8601String(),
          'filename': fileName,
          'isFavorite': 'false',
        })
        ..files.add(
          http.MultipartFile.fromBytes('assetData', bytes, filename: fileName),
        );

  final response = await http.Response.fromStream(await request.send());
  expect(
    response.statusCode,
    inInclusiveRange(200, 299),
    reason: response.body,
  );
  final payload = jsonDecode(response.body) as Map<String, dynamic>;
  expect(payload['status'], 'created', reason: response.body);
  return payload['id'] as String;
}

Future<void> _updateTestAssetSourceMetadata(
  String remoteAssetId,
  String fileName,
  DateTime createdAt,
  Map<String, Object> sourceMetadata,
) async {
  final utcCreatedAt = createdAt.toUtc();
  final mergedSourceMetadata = <String, Object>{
    'uploaded_original_name': fileName,
    ...sourceMetadata,
  };
  final metadata = <String, Object>{
    'original_created_unix_nano': utcCreatedAt.microsecondsSinceEpoch * 1000,
    'original_modified_unix_nano': utcCreatedAt.microsecondsSinceEpoch * 1000,
    'source_metadata': mergedSourceMetadata,
  };
  final request =
      http.Request(
          'POST',
          Uri.parse(
            '${Store.get(StoreKey.serverEndpoint)}/assets/bulk-metadata',
          ),
        )
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
  final request =
      http.Request(
          'POST',
          Uri.parse('${Store.get(StoreKey.serverEndpoint)}/faces'),
        )
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
  expect(
    response.statusCode,
    inInclusiveRange(200, 299),
    reason: response.body,
  );
}

Future<void> _deleteTestAssetBestEffort(
  api.AssetsApi assetsApi,
  String remoteAssetId,
) async {
  try {
    await assetsApi.deleteAssets(
      api.AssetBulkDeleteDto(
        ids: [remoteAssetId],
        force: const api.Optional.present(false),
      ),
    );
  } catch (_) {
    // The asset may already be trashed or deleted by the test body.
  }
  try {
    await assetsApi.deleteAssets(
      api.AssetBulkDeleteDto(
        ids: [remoteAssetId],
        force: const api.Optional.present(true),
      ),
    );
  } catch (_) {
    // Best-effort cleanup for a test-created asset.
  }
}

Future<void> _deletePersonBestEffort(
  api.PeopleApi peopleApi,
  String personId,
) async {
  try {
    await peopleApi.deletePerson(personId);
  } catch (_) {
    // Best-effort cleanup for a test-created person.
  }
}

Future<void> _deleteAlbumBestEffort(
  api.AlbumsApi albumsApi,
  String albumId,
) async {
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
  Set<PersonDto>? people,
  List<String>? tagIds,
  String? country,
  String? state,
  String? city,
  String? make,
  String? model,
  int? rating,
}) {
  return SearchFilter(
    filename: filename,
    people: people ?? {},
    location: SearchLocationFilter(country: country, state: state, city: city),
    camera: SearchCameraFilter(make: make, model: model),
    date: SearchDateFilter(takenAfter: takenAfter, takenBefore: takenBefore),
    display: SearchDisplayFilters(
      isNotInAlbum: isNotInAlbum,
      isArchive: isArchive,
      isFavorite: isFavorite,
    ),
    rating: rating == null
        ? SearchRatingFilter()
        : SearchRatingFilter(rating: Option.some(rating)),
    mediaType: mediaType,
    tagIds: tagIds,
  );
}

api.MetadataSearchDto _metadataSearchDto({
  String? filename,
  String? description,
  DateTime? takenAfter,
  DateTime? takenBefore,
  bool? isFavorite,
  int page = 1,
  int size = 1000,
  api.AssetTypeEnum? type,
  api.AssetVisibility? visibility,
  String? make,
  String? model,
  int? rating,
  List<String>? tagIds,
  List<String>? personIds,
  String? country,
  String? state,
  String? city,
  bool? isNotInAlbum,
  String? ocr,
}) {
  return api.MetadataSearchDto(
    originalFileName: filename == null
        ? const api.Optional.absent()
        : api.Optional.present(filename),
    description: description == null
        ? const api.Optional.absent()
        : api.Optional.present(description),
    takenAfter: takenAfter == null
        ? const api.Optional.absent()
        : api.Optional.present(takenAfter),
    takenBefore: takenBefore == null
        ? const api.Optional.absent()
        : api.Optional.present(takenBefore),
    isFavorite: isFavorite == null
        ? const api.Optional.absent()
        : api.Optional.present(isFavorite),
    page: api.Optional.present(page),
    size: api.Optional.present(size),
    type: type == null
        ? const api.Optional.absent()
        : api.Optional.present(type),
    visibility: visibility == null
        ? const api.Optional.absent()
        : api.Optional.present(visibility),
    make: make == null
        ? const api.Optional.absent()
        : api.Optional.present(make),
    model: model == null
        ? const api.Optional.absent()
        : api.Optional.present(model),
    rating: rating == null
        ? const api.Optional.absent()
        : api.Optional.present(rating),
    tagIds: tagIds == null
        ? const api.Optional.absent()
        : api.Optional.present(tagIds),
    personIds: personIds == null
        ? const api.Optional.absent()
        : api.Optional.present(personIds),
    country: country == null
        ? const api.Optional.absent()
        : api.Optional.present(country),
    state: state == null
        ? const api.Optional.absent()
        : api.Optional.present(state),
    city: city == null
        ? const api.Optional.absent()
        : api.Optional.present(city),
    isNotInAlbum: isNotInAlbum == null
        ? const api.Optional.absent()
        : api.Optional.present(isNotInAlbum),
    ocr: ocr == null ? const api.Optional.absent() : api.Optional.present(ocr),
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

Future<api.SearchResponseDto> _waitForServerSmartSearchResponse(
  WidgetTester tester,
  api.SearchApi searchApi,
  api.SmartSearchDto dto,
  bool Function(api.SearchResponseDto response) matches, {
  required String reason,
}) async {
  api.SearchResponseDto? latest;
  Object? lastError;
  final end = DateTime.now().add(const Duration(seconds: 60));
  while (DateTime.now().isBefore(end)) {
    try {
      latest = await searchApi.searchSmart(dto);
      if (latest != null && matches(latest)) {
        return latest;
      }
    } catch (error) {
      lastError = error;
    }
    await _pumpFor(tester, const Duration(milliseconds: 500));
  }

  fail('$reason; latest server smart search=$latest; last error=$lastError');
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

  fail(
    '$reason; latest app search ids=${latest.toList()..sort()}; last error=$lastError',
  );
}

Future<List<String>> _waitForSearchSuggestions(
  WidgetTester tester,
  SearchService searchService,
  api.SearchSuggestionType type,
  bool Function(List<String> values) matches, {
  required String reason,
}) async {
  var latest = const <String>[];
  Object? lastError;
  final end = DateTime.now().add(const Duration(seconds: 60));
  while (DateTime.now().isBefore(end)) {
    try {
      latest =
          await searchService.getSearchSuggestions(type) ?? const <String>[];
      if (matches(latest)) {
        return latest;
      }
    } catch (error) {
      lastError = error;
    }
    await _pumpFor(tester, const Duration(milliseconds: 500));
  }

  fail(
    '$reason; latest suggestions=${latest.toList()..sort()}; last error=$lastError',
  );
}

Future<Set<String>> _waitForPaginatedSearchAssetIds(
  WidgetTester tester,
  ProviderContainer container,
  bool Function(Set<String> ids) matches, {
  required String reason,
}) async {
  var latest = const <String>{};
  final end = DateTime.now().add(const Duration(seconds: 60));
  while (DateTime.now().isBefore(end)) {
    final searchState = container.read(paginatedSearchProvider);
    latest = {
      for (final asset in searchState.assets)
        if (asset.remoteId != null) asset.remoteId!,
    };
    if (!searchState.isLoading && matches(latest)) {
      return latest;
    }
    await _pumpFor(tester, const Duration(milliseconds: 500));
  }

  fail('$reason; latest search page ids=${latest.toList()..sort()}');
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
        headers: {
          ...ApiService.getRequestHeaders(),
          'Authorization': 'Bearer ${Store.get(StoreKey.accessToken)}',
        },
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final payload = jsonDecode(response.body);
        if (payload is List) {
          latest = payload
              .whereType<Map>()
              .map((face) => face.cast<String, dynamic>())
              .toList(growable: false);
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
        headers: {
          ...ApiService.getRequestHeaders(),
          'Authorization': 'Bearer ${Store.get(StoreKey.accessToken)}',
        },
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final payload = jsonDecode(response.body);
        if (payload is List) {
          latest = [
            for (final item in payload)
              if (api.AssetResponseDto.fromJson(item) != null)
                api.AssetResponseDto.fromJson(item)!,
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

Future<List<Ocr>> _waitForLocalOcrState(
  WidgetTester tester,
  ProviderContainer container,
  String remoteAssetId,
  bool Function(List<Ocr> rows) matches, {
  required String reason,
}) async {
  var latest = const <Ocr>[];
  final end = DateTime.now().add(const Duration(seconds: 60));
  while (DateTime.now().isBefore(end)) {
    latest =
        await container.read(ocrServiceProvider).get(remoteAssetId) ??
        const <Ocr>[];
    if (matches(latest)) {
      return latest;
    }
    await _pumpFor(tester, const Duration(milliseconds: 500));
  }

  fail('$reason; latest local OCR=$latest');
}

Future<void> _pumpUntilFoundWithReason(
  WidgetTester tester,
  Finder finder, {
  required String reason,
  Duration timeout = const Duration(seconds: 10),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await _pumpAllowingExpectedRemoteImage404s(tester);
    if (tester.any(finder)) {
      return;
    }
  }

  fail('$reason; finder=$finder; found=${finder.evaluate().length}');
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

Future<DriftPerson?> _waitForLocalPersonState(
  WidgetTester tester,
  DriftPeopleService peopleService,
  String personId,
  bool Function(DriftPerson? person) matches, {
  required String reason,
}) async {
  DriftPerson? latest;
  final end = DateTime.now().add(const Duration(seconds: 60));
  while (DateTime.now().isBefore(end)) {
    latest = await peopleService.get(personId);
    if (matches(latest)) {
      return latest;
    }
    await _pumpFor(tester, const Duration(milliseconds: 500));
  }

  fail('$reason; latest local person=$latest');
}

Future<List<api.PersonResponseDto>> _waitForServerPeopleState(
  WidgetTester tester,
  api.PeopleApi peopleApi, {
  required bool withHidden,
  required bool Function(List<api.PersonResponseDto> people) matches,
  required String reason,
}) async {
  var latest = const <api.PersonResponseDto>[];
  Object? lastError;
  final end = DateTime.now().add(const Duration(seconds: 60));
  while (DateTime.now().isBefore(end)) {
    try {
      latest =
          (await peopleApi.getAllPeople(
            withHidden: withHidden,
            size: 1000,
          ))?.people ??
          const <api.PersonResponseDto>[];
      if (matches(latest)) {
        return latest;
      }
    } catch (error) {
      lastError = error;
    }
    await _pumpFor(tester, const Duration(milliseconds: 500));
  }

  fail('$reason; latest server people=$latest; last error=$lastError');
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

Future<Set<String>> _waitForMapMarkerAssetIds(
  WidgetTester tester,
  ProviderContainer container,
  bool Function(Set<String> ids) matches, {
  required LatLngBounds bounds,
  required TimelineMapOptions options,
  required String reason,
}) async {
  final currentUser = container.read(currentUserProvider);
  expect(currentUser, isNotNull);
  final userId = currentUser!.id;

  var latest = const <String>{};
  final end = DateTime.now().add(const Duration(seconds: 60));
  while (DateTime.now().isBefore(end)) {
    final markers = await container
        .read(mapFactoryProvider)
        .remote([userId], options)
        .getMarkers(bounds);
    latest = markers.map((marker) => marker.assetId).toSet();
    if (matches(latest)) {
      return latest;
    }
    await _pumpFor(tester, const Duration(milliseconds: 500));
  }

  fail('$reason; latest map marker ids=${latest.toList()..sort()}');
}

Future<int> _remoteAssetFaceRowCount(
  Drift drift,
  String remoteAssetId,
  String personId,
) async {
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
        variables: [
          Variable.withString(remoteAssetId),
          Variable.withString(personId),
        ],
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

Future<Uint8List> _generatedPngBytes(
  int seed, {
  required int width,
  required int height,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  final paint = ui.Paint()..color = const ui.Color(0xff19435f);
  canvas.drawRect(
    ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    paint,
  );

  paint.color = ui.Color(0xff000000 | ((seed >> 8) & 0x00ffffff));
  canvas.drawRect(
    ui.Rect.fromLTWH(width * 0.05, height * 0.08, width * 0.40, height * 0.48),
    paint,
  );
  paint.color = ui.Color(0xff000000 | ((seed * 2654435761) & 0x00ffffff));
  canvas.drawRect(
    ui.Rect.fromLTWH(width * 0.52, height * 0.16, width * 0.36, height * 0.62),
    paint,
  );
  paint.color = const ui.Color(0xfff4c542);
  canvas.drawCircle(
    ui.Offset(width * 0.72, height * 0.35),
    height * 0.12,
    paint,
  );
  paint.color = const ui.Color(0xffd9480f);
  canvas.drawRect(
    ui.Rect.fromLTWH(width * 0.18, height * 0.72, width * 0.60, height * 0.12),
    paint,
  );

  final image = await recorder.endRecording().toImage(width, height);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  if (byteData == null) {
    fail('Failed to encode generated PNG fixture');
  }
  return byteData.buffer.asUint8List(
    byteData.offsetInBytes,
    byteData.lengthInBytes,
  );
}

Future<({int width, int height})> _decodeImageSize(List<int> bodyBytes) async {
  final bytes = bodyBytes is Uint8List
      ? bodyBytes
      : Uint8List.fromList(bodyBytes);
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  final image = frame.image;
  final size = (width: image.width, height: image.height);
  image.dispose();
  codec.dispose();
  return size;
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
    latest = await container
        .read(remoteAssetRepositoryProvider)
        .get(remoteAssetId);
    if (latest != null && matches(latest)) {
      return latest;
    }
    await _pumpFor(tester, const Duration(milliseconds: 500));
  }

  fail('$reason; latest local asset=$latest');
}

Future<api.StackResponseDto> _waitForServerStackWithMembers(
  WidgetTester tester,
  api.StacksApi stacksApi,
  Set<String> expectedAssetIds, {
  String? expectedPrimaryAssetId,
  required String reason,
}) async {
  var latest = const <api.StackResponseDto>[];
  Object? lastError;
  final end = DateTime.now().add(const Duration(seconds: 60));
  while (DateTime.now().isBefore(end)) {
    try {
      latest = await stacksApi.searchStacks() ?? const <api.StackResponseDto>[];
      for (final stack in latest) {
        final ids = _stackDtoAssetIds(stack);
        if (ids.length == expectedAssetIds.length &&
            ids.containsAll(expectedAssetIds) &&
            (expectedPrimaryAssetId == null ||
                stack.primaryAssetId == expectedPrimaryAssetId)) {
          return stack;
        }
      }
    } catch (error) {
      lastError = error;
    }
    await _pumpFor(tester, const Duration(milliseconds: 500));
  }

  final observed = latest
      .map(
        (stack) => {
          'id': stack.id,
          'primaryAssetId': stack.primaryAssetId,
          'assetIds': _stackDtoAssetIds(stack),
        },
      )
      .toList();
  fail('$reason; latest server stacks=$observed; last error=$lastError');
}

Future<void> _waitForServerStackGone(
  WidgetTester tester,
  api.StacksApi stacksApi,
  String stackId, {
  required String reason,
}) async {
  api.StackResponseDto? latest;
  Object? lastError;
  final end = DateTime.now().add(const Duration(seconds: 60));
  while (DateTime.now().isBefore(end)) {
    try {
      latest = await stacksApi.getStack(stackId);
      if (latest == null) {
        return;
      }
    } catch (error) {
      lastError = error;
      if (error is api.ApiException && error.code == HttpStatus.notFound) {
        return;
      }
    }
    await _pumpFor(tester, const Duration(milliseconds: 500));
  }

  fail('$reason; latest server stack=$latest; last error=$lastError');
}

Future<void> _waitForLocalStackMembership(
  WidgetTester tester,
  ProviderContainer container,
  String stackId, {
  required String? expectedPrimaryAssetId,
  required Set<String> stackedAssetIds,
  required Set<String> unstackedAssetIds,
  required String reason,
}) async {
  final drift = container.read(driftProvider);
  final remoteAssets = container.read(remoteAssetRepositoryProvider);
  final allAssetIds = {...stackedAssetIds, ...unstackedAssetIds};
  var latestStackExists = false;
  String? latestPrimaryAssetId;
  Map<String, String?> latestAssignments = const {};
  final end = DateTime.now().add(const Duration(seconds: 60));

  while (DateTime.now().isBefore(end)) {
    final stackRows = await drift
        .customSelect(
          'SELECT primary_asset_id FROM stack_entity WHERE id = ?',
          variables: [Variable.withString(stackId)],
        )
        .get();
    latestStackExists = stackRows.isNotEmpty;
    latestPrimaryAssetId = stackRows.isEmpty
        ? null
        : stackRows.single.read<String>('primary_asset_id');
    latestAssignments = <String, String?>{};
    for (final assetId in allAssetIds) {
      latestAssignments[assetId] = (await remoteAssets.get(assetId))?.stackId;
    }
    final stackMatches = expectedPrimaryAssetId == null
        ? !latestStackExists
        : latestStackExists && latestPrimaryAssetId == expectedPrimaryAssetId;
    final stackedMatches = stackedAssetIds.every(
      (assetId) => latestAssignments[assetId] == stackId,
    );
    final unstackedMatches = unstackedAssetIds.every(
      (assetId) => latestAssignments[assetId] == null,
    );
    if (stackMatches && stackedMatches && unstackedMatches) {
      return;
    }
    await _pumpFor(tester, const Duration(milliseconds: 500));
  }

  fail(
    '$reason; stackExists=$latestStackExists primary=$latestPrimaryAssetId assignments=$latestAssignments',
  );
}

Set<String> _stackDtoAssetIds(api.StackResponseDto stack) =>
    stack.assets.map((asset) => asset.id).toSet();

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

Future<api.AuthStatusResponseDto> _waitForAuthStatus(
  WidgetTester tester,
  api.AuthenticationApi authApi,
  bool Function(api.AuthStatusResponseDto status) matches, {
  required String reason,
}) async {
  api.AuthStatusResponseDto? latest;
  Object? lastError;
  final end = DateTime.now().add(const Duration(seconds: 30));
  while (DateTime.now().isBefore(end)) {
    try {
      latest = await authApi.getAuthStatus();
      if (latest != null && matches(latest)) {
        return latest;
      }
    } catch (error) {
      lastError = error;
    }
    await _pumpFor(tester, const Duration(milliseconds: 300));
  }

  fail('$reason; latest auth status=$latest; last error=$lastError');
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
    latest = timeline.totalAssets == 0
        ? const <BaseAsset>[]
        : await _loadAllTimelineAssets(timeline);
    final latestIds = _timelineAssetIds(latest);
    final hasExpected = includes.every(latestIds.contains);
    final hasNoUnexpected = excludes.every(
      (assetId) => !latestIds.contains(assetId),
    );
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

bool _albumHasUserRole(
  api.AlbumResponseDto album,
  String userId,
  api.AlbumUserRole role,
) {
  return album.albumUsers.any(
    (albumUser) => albumUser.user.id == userId && albumUser.role == role,
  );
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

Future<List<UserDto>> _waitForRemoteAlbumSharedUsersState(
  WidgetTester tester,
  ProviderContainer container,
  String albumId,
  bool Function(List<UserDto> users) matches, {
  required String reason,
}) async {
  var latest = const <UserDto>[];
  final end = DateTime.now().add(const Duration(seconds: 60));
  while (DateTime.now().isBefore(end)) {
    latest = await container
        .read(remoteAlbumServiceProvider)
        .getSharedUsers(albumId);
    if (matches(latest)) {
      return latest;
    }
    await _pumpFor(tester, const Duration(milliseconds: 500));
  }

  fail(
    '$reason; latest shared users=${latest.map((user) => '${user.id}:${user.email}').join(', ')}',
  );
}

Future<AlbumUserRole?> _waitForRemoteAlbumUserRole(
  WidgetTester tester,
  ProviderContainer container,
  String albumId,
  String userId,
  bool Function(AlbumUserRole? role) matches, {
  required String reason,
}) async {
  AlbumUserRole? latest;
  final end = DateTime.now().add(const Duration(seconds: 60));
  while (DateTime.now().isBefore(end)) {
    latest = await container
        .read(remoteAlbumServiceProvider)
        .getUserRole(albumId, userId);
    if (matches(latest)) {
      return latest;
    }
    await _pumpFor(tester, const Duration(milliseconds: 500));
  }

  fail('$reason; latest role=$latest');
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
    final assets = await container
        .read(remoteAlbumServiceProvider)
        .getAssets(albumId);
    latestIds = assets
        .map((asset) => asset.remoteId)
        .whereType<String>()
        .toSet();
    final hasExpected = includes.every(latestIds.contains);
    final hasNoUnexpected = excludes.every(
      (assetId) => !latestIds.contains(assetId),
    );
    if (hasExpected && hasNoUnexpected) {
      return latestIds;
    }
    await _pumpFor(tester, const Duration(milliseconds: 500));
  }

  final sorted = latestIds.toList()..sort();
  fail('$reason; latest album asset ids=${sorted.join(', ')}');
}

void _expectBulkSuccess(
  List<api.BulkIdResponseDto>? response,
  Set<String> ids, {
  required String reason,
}) {
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
    final isDuplicate =
        !result.success &&
        result.error.orElse(null) == api.BulkIdErrorReason.duplicate;
    expect(
      result.success || isDuplicate,
      isTrue,
      reason: '$reason; result=$result',
    );
  }
}

void _expectAssetInfoPreserved(
  api.AssetResponseDto restored,
  api.AssetResponseDto beforeTrash,
) {
  expect(restored.id, beforeTrash.id);
  expect(
    restored.checksum,
    beforeTrash.checksum,
    reason: 'Restore must not rewrite asset bytes',
  );
  expect(restored.originalFileName, beforeTrash.originalFileName);
  expect(
    restored.originalPath,
    beforeTrash.originalPath,
    reason: 'Restore must keep the original media path',
  );
  expect(restored.fileCreatedAt.toUtc(), beforeTrash.fileCreatedAt.toUtc());
  expect(restored.fileModifiedAt.toUtc(), beforeTrash.fileModifiedAt.toUtc());
  expect(
    restored.isFavorite,
    beforeTrash.isFavorite,
    reason: 'Restore must preserve favorite state',
  );
  expect(
    restored.visibility,
    beforeTrash.visibility,
    reason: 'Restore must preserve visibility',
  );
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
    latest = await container
        .read(remoteAssetRepositoryProvider)
        .get(remoteAssetId);
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
    latest = await container
        .read(remoteAssetRepositoryProvider)
        .get(remoteAssetId);
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

Future<SharedLink> _waitForSharedLinkState(
  WidgetTester tester,
  ProviderContainer container,
  bool Function(SharedLink link) matches, {
  required String reason,
}) async {
  var latestCount = 0;
  var sawAnyLink = false;
  Object? lastError;
  final end = DateTime.now().add(const Duration(seconds: 60));
  while (DateTime.now().isBefore(end)) {
    try {
      final state = await container
          .read(sharedLinkServiceProvider)
          .getAllSharedLinks();
      if (state.hasValue) {
        final links = state.requireValue;
        latestCount = links.length;
        sawAnyLink = sawAnyLink || links.isNotEmpty;
        for (final link in links) {
          if (matches(link)) {
            return link;
          }
        }
      } else if (state.hasError) {
        lastError = state.error;
      }
    } catch (error) {
      lastError = error;
    }
    await _pumpFor(tester, const Duration(milliseconds: 500));
  }

  fail(
    '$reason; latest shared-link count=$latestCount sawAnyLink=$sawAnyLink last error=$lastError',
  );
}

Future<void> _waitForSharedLinkDeleted(
  WidgetTester tester,
  ProviderContainer container,
  String id, {
  required String reason,
}) async {
  var latestCount = 0;
  Object? lastError;
  final end = DateTime.now().add(const Duration(seconds: 60));
  while (DateTime.now().isBefore(end)) {
    try {
      final state = await container
          .read(sharedLinkServiceProvider)
          .getAllSharedLinks();
      if (state.hasValue) {
        final links = state.requireValue;
        latestCount = links.length;
        if (!links.any((link) => link.id == id)) {
          return;
        }
      } else if (state.hasError) {
        lastError = state.error;
      }
    } catch (error) {
      lastError = error;
    }
    await _pumpFor(tester, const Duration(milliseconds: 500));
  }

  fail('$reason; latest shared-link count=$latestCount last error=$lastError');
}

Future<Map<String, dynamic>> _waitForPartnerListEntry(
  WidgetTester tester, {
  required String accessToken,
  required String direction,
  required String partnerId,
  required String reason,
}) async {
  List<Map<String, dynamic>> latest = const [];
  Object? lastError;
  final end = DateTime.now().add(const Duration(seconds: 60));
  while (DateTime.now().isBefore(end)) {
    try {
      final response = await _authenticatedApiRequest(
        'GET',
        '/partners?direction=$direction',
        accessToken: accessToken,
      );
      if (response.statusCode == 200) {
        latest = (jsonDecode(response.body) as List<dynamic>)
            .cast<Map<String, dynamic>>();
        for (final partner in latest) {
          if (partner['id'] == partnerId) {
            return partner;
          }
        }
      } else {
        lastError = 'status=${response.statusCode} body=${response.body}';
      }
    } catch (error) {
      lastError = error;
    }
    await _pumpFor(tester, const Duration(milliseconds: 500));
  }

  fail('$reason; latest partners=$latest last error=$lastError');
}

Future<void> _waitForPartnerListMissing(
  WidgetTester tester, {
  required String accessToken,
  required String direction,
  required String partnerId,
  required String reason,
}) async {
  List<Map<String, dynamic>> latest = const [];
  Object? lastError;
  final end = DateTime.now().add(const Duration(seconds: 60));
  while (DateTime.now().isBefore(end)) {
    try {
      final response = await _authenticatedApiRequest(
        'GET',
        '/partners?direction=$direction',
        accessToken: accessToken,
      );
      if (response.statusCode == 200) {
        latest = (jsonDecode(response.body) as List<dynamic>)
            .cast<Map<String, dynamic>>();
        if (!latest.any((partner) => partner['id'] == partnerId)) {
          return;
        }
      } else {
        lastError = 'status=${response.statusCode} body=${response.body}';
      }
    } catch (error) {
      lastError = error;
    }
    await _pumpFor(tester, const Duration(milliseconds: 500));
  }

  fail('$reason; latest partners=$latest last error=$lastError');
}

Future<void> _deletePartnerBestEffortWithToken(
  String sharedWithId,
  String accessToken,
) async {
  try {
    await _authenticatedApiRequest(
      'DELETE',
      '/partners/$sharedWithId',
      accessToken: accessToken,
    );
  } catch (_) {
    // Best-effort cleanup for a test-created partner relation.
  }
}

Future<void> _waitForUserRow(
  WidgetTester tester,
  Drift drift,
  String userId, {
  required String reason,
}) async {
  var latestCount = 0;
  final end = DateTime.now().add(const Duration(seconds: 60));
  while (DateTime.now().isBefore(end)) {
    latestCount = await _rowCountWhere(drift, 'user_entity', 'id = ?', [
      Variable.withString(userId),
    ]);
    if (latestCount > 0) {
      return;
    }
    await _pumpFor(tester, const Duration(milliseconds: 500));
  }

  fail('$reason; latest user row count=$latestCount');
}

Future<void> _waitForPartnerRowState(
  WidgetTester tester,
  Drift drift,
  String sharedById,
  String sharedWithId, {
  required bool expectedInTimeline,
  required String reason,
}) async {
  bool? latest;
  final end = DateTime.now().add(const Duration(seconds: 60));
  while (DateTime.now().isBefore(end)) {
    latest = await _partnerInTimeline(
      drift,
      sharedById: sharedById,
      sharedWithId: sharedWithId,
    );
    if (latest == expectedInTimeline) {
      return;
    }
    await _pumpFor(tester, const Duration(milliseconds: 500));
  }

  fail('$reason; latest inTimeline=$latest expected=$expectedInTimeline');
}

Future<void> _waitForPartnerMissing(
  WidgetTester tester,
  Drift drift,
  String sharedById,
  String sharedWithId, {
  required String reason,
}) async {
  bool? latest;
  final end = DateTime.now().add(const Duration(seconds: 60));
  while (DateTime.now().isBefore(end)) {
    latest = await _partnerInTimeline(
      drift,
      sharedById: sharedById,
      sharedWithId: sharedWithId,
    );
    if (latest == null) {
      return;
    }
    await _pumpFor(tester, const Duration(milliseconds: 500));
  }

  fail('$reason; latest inTimeline=$latest');
}

Future<bool?> _partnerInTimeline(
  Drift drift, {
  required String sharedById,
  required String sharedWithId,
}) async {
  final rows = await drift
      .customSelect(
        '''
SELECT CASE WHEN in_timeline THEN 1 ELSE 0 END AS in_timeline_value
FROM partner_entity
WHERE shared_by_id = ? AND shared_with_id = ?
''',
        variables: [
          Variable.withString(sharedById),
          Variable.withString(sharedWithId),
        ],
      )
      .get();
  if (rows.isEmpty) {
    return null;
  }
  return rows.single.read<int>('in_timeline_value') != 0;
}

Future<int> _rowCountWhere(
  Drift drift,
  String table,
  String where,
  List<Variable> variables,
) async {
  final row = await drift
      .customSelect(
        'SELECT COUNT(*) AS count FROM $table WHERE $where',
        variables: variables,
      )
      .getSingle();
  return row.read<int>('count');
}

String _sharedLinkLookupQuery(SharedLink link) {
  final slug = link.slug;
  if (slug != null && slug.isNotEmpty) {
    return 'slug=${Uri.encodeQueryComponent(slug)}';
  }
  return 'key=${Uri.encodeQueryComponent(link.key)}';
}

bool _isMissingAssetError(Object error) =>
    error is api.ApiException && (error.code == 404 || error.code == 410);

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
      final response = await http
          .get(pingUri)
          .timeout(const Duration(seconds: 2));
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
    headers: {
      ...ApiService.getRequestHeaders(),
      'Authorization': 'Bearer ${Store.get(StoreKey.accessToken)}',
    },
  );
}

Future<http.Response> _authenticatedApiRequest(
  String method,
  String path, {
  String? accessToken,
  Object? jsonBody,
}) async {
  final endpoint = Store.get(StoreKey.serverEndpoint);
  final separator = path.startsWith('/') ? '' : '/';
  final request = http.Request(method, Uri.parse('$endpoint$separator$path'))
    ..headers.addAll({
      ...ApiService.getRequestHeaders(),
      'Authorization':
          'Bearer ${accessToken ?? Store.get(StoreKey.accessToken)}',
      if (jsonBody != null) HttpHeaders.contentTypeHeader: 'application/json',
    });
  if (jsonBody != null) {
    request.body = jsonEncode(jsonBody);
  }
  return http.Response.fromStream(await request.send());
}

Future<http.Response> _publicApiRequest(
  String method,
  String path, {
  Object? jsonBody,
}) async {
  final endpoint = Store.get(StoreKey.serverEndpoint);
  final separator = path.startsWith('/') ? '' : '/';
  final request = http.Request(method, Uri.parse('$endpoint$separator$path'))
    ..headers.addAll({
      ...ApiService.getRequestHeaders(),
      if (jsonBody != null) HttpHeaders.contentTypeHeader: 'application/json',
    });
  if (jsonBody != null) {
    request.body = jsonEncode(jsonBody);
  }
  return http.Response.fromStream(await request.send());
}

Future<Map<String, dynamic>> _createAlbumActivityViaApi(
  String albumId, {
  required String comment,
  required String accessToken,
}) async {
  final response = await _authenticatedApiRequest(
    'POST',
    '/activities',
    accessToken: accessToken,
    jsonBody: {'albumId': albumId, 'type': 'comment', 'comment': comment},
  );
  expect(
    response.statusCode,
    inInclusiveRange(200, 299),
    reason: response.body,
  );
  return jsonDecode(response.body) as Map<String, dynamic>;
}

Future<List<Map<String, dynamic>>> _waitForActivityComments(
  WidgetTester tester,
  String albumId, {
  required String accessToken,
  required Set<String> includes,
  Set<String> excludes = const {},
  required String reason,
}) async {
  List<Map<String, dynamic>> latest = const [];
  Object? lastError;
  final end = DateTime.now().add(const Duration(seconds: 60));
  while (DateTime.now().isBefore(end)) {
    try {
      final response = await _authenticatedApiRequest(
        'GET',
        '/activities?albumId=$albumId&type=comment',
        accessToken: accessToken,
      );
      if (response.statusCode == 200) {
        latest = (jsonDecode(response.body) as List<dynamic>)
            .cast<Map<String, dynamic>>();
        final comments = latest
            .map((activity) => activity['comment'] as String?)
            .whereType<String>()
            .toSet();
        if (includes.every(comments.contains) &&
            excludes.every((comment) => !comments.contains(comment))) {
          return latest;
        }
      } else {
        lastError = 'status=${response.statusCode} body=${response.body}';
      }
    } catch (error) {
      lastError = error;
    }
    await _pumpFor(tester, const Duration(milliseconds: 500));
  }

  final comments = latest.map((activity) => activity['comment']).join(', ');
  fail('$reason; latest comments=$comments; last error=$lastError');
}

Map<String, dynamic> _activityWithComment(
  List<Map<String, dynamic>> activities,
  String comment,
) {
  return activities.singleWhere(
    (activity) => activity['comment'] == comment,
    orElse: () => fail('Expected activity comment "$comment" in $activities'),
  );
}

Future<void> _addAlbumUserViaApi(
  WidgetTester tester,
  String albumId, {
  required String userId,
  required String role,
  required String accessToken,
}) async {
  await _waitForSuccessfulResponse(
    tester,
    () => _authenticatedApiRequest(
      'PUT',
      '/albums/$albumId/users',
      accessToken: accessToken,
      jsonBody: {
        'albumUsers': [
          {'userId': userId, 'role': role},
        ],
      },
    ),
    acceptedStatusCodes: const {200, 204},
    acceptedEmptyBodyStatusCodes: const {204},
  );
}

Future<void> _deleteAlbumBestEffortWithToken(
  String albumId,
  String accessToken,
) async {
  try {
    await _authenticatedApiRequest(
      'DELETE',
      '/albums/$albumId',
      accessToken: accessToken,
    );
  } catch (_) {
    // Best-effort cleanup for a test-created album.
  }
}

Future<void> _deleteSharedLinkBestEffortWithToken(
  String linkId,
  String accessToken,
) async {
  try {
    await _authenticatedApiRequest(
      'DELETE',
      '/shared-links/$linkId',
      accessToken: accessToken,
    );
  } catch (_) {
    // Best-effort cleanup for a test-created shared link.
  }
}

Future<void> _deleteTestAssetBestEffortWithToken(
  String remoteAssetId,
  String accessToken,
) async {
  for (final force in const [false, true]) {
    try {
      await _authenticatedApiRequest(
        'DELETE',
        '/assets',
        accessToken: accessToken,
        jsonBody: {
          'ids': [remoteAssetId],
          'force': force,
        },
      );
    } catch (_) {
      // Best-effort cleanup for a test-created asset.
    }
  }
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

Future<void> _expectRemoteAssetLocalDateTime(
  Drift drift,
  String remoteAssetId,
  DateTime expected,
) async {
  final row = await drift
      .customSelect(
        'SELECT local_date_time FROM remote_asset_entity WHERE id = ?',
        variables: [Variable.withString(remoteAssetId)],
      )
      .getSingle();
  expect(row.read<DateTime?>('local_date_time'), expected);
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

Future<void> _waitForRemoteAlbumRowCount(
  WidgetTester tester,
  Drift drift,
  String albumId,
  int expected, {
  required String reason,
}) async {
  var latest = -1;
  final end = DateTime.now().add(const Duration(seconds: 30));
  while (DateTime.now().isBefore(end)) {
    latest = await _remoteAlbumRowCountById(drift, albumId);
    if (latest == expected) {
      return;
    }
    await _pumpFor(tester, const Duration(milliseconds: 500));
  }

  fail('$reason; expected $expected local album rows but saw $latest');
}

Future<int> _remoteAlbumAssetRowCountByAlbumId(
  Drift drift,
  String albumId,
) async {
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
      if (info != null &&
          info.hasMetadata &&
          info.exifInfo.orElse(null) != null) {
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
      final totalFromBuckets = latest.fold<int>(
        0,
        (total, bucket) => total + bucket.assetCount,
      );
      if (latest.isNotEmpty &&
          timeBuckets.length == latest.length &&
          timeBuckets.length >= 2 &&
          totalFromBuckets >= minAssets &&
          timeline.totalAssets == totalFromBuckets) {
        return timeBuckets;
      }
      await _pumpFor(tester, const Duration(milliseconds: 500));
    }

    final totalFromBuckets = latest.fold<int>(
      0,
      (total, bucket) => total + bucket.assetCount,
    );
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
  return buckets
          .map((bucket) => '${bucket.date.year}-${bucket.date.month}')
          .toSet()
          .length >
      1;
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

void _expectUtcDateTimeParts(
  DateTime value,
  int year,
  int month,
  int day,
  int hour,
  int minute,
) {
  final utc = value.toUtc();
  expect(utc.year, year);
  expect(utc.month, month);
  expect(utc.day, day);
  expect(utc.hour, hour);
  expect(utc.minute, minute);
}

void _expectDateTimesClose(
  DateTime actual,
  DateTime expected,
  Duration tolerance,
) {
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
  final prefixLength = bodyBytes.length < 2 * 1024 * 1024
      ? bodyBytes.length
      : 2 * 1024 * 1024;
  final ranges = parseMotionPhotoRanges(
    Uint8List.fromList(bodyBytes.take(prefixLength).toList()),
    bodyBytes.length,
  );
  expect(ranges, isNotNull);
  final motionOffset = ranges!.motionOffset;
  expect(motionOffset + 12, lessThanOrEqualTo(bodyBytes.length));
  expect(
    ascii.decode(
      bodyBytes.sublist(motionOffset + 4, motionOffset + 8),
      allowInvalid: true,
    ),
    'ftyp',
  );
}

Future<void> _waitForLoginScreen(WidgetTester tester) async {
  await pumpUntilFound(
    tester,
    find.byType(TextFormField),
    timeout: const Duration(seconds: 60),
  );
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

Future<void> _enterCredentials(
  WidgetTester tester, {
  required String email,
  required String password,
}) async {
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
    await _pumpAllowingExpectedRemoteImage404s(
      tester,
      const Duration(milliseconds: 100),
    );
  }
}

Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  required Duration timeout,
}) async {
  final end = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(end)) {
      throw TimeoutException('Timed out waiting for condition');
    }
    await _pumpAllowingExpectedRemoteImage404s(
      tester,
      const Duration(milliseconds: 100),
    );
  }
}

Future<void> _pumpAllowingExpectedRemoteImage404s(
  WidgetTester tester, [
  Duration? duration,
]) async {
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
    return exception.code == 'IOException' &&
        exception.message?.contains('HTTP 404') == true;
  }

  final text = exception.toString();
  return text.contains('PlatformException(IOException') &&
      text.contains('HTTP 404');
}
