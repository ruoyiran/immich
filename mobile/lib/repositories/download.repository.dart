import 'dart:convert';
import 'dart:io';

import 'package:background_downloader/background_downloader.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/constants/constants.dart';
import 'package:immich_mobile/domain/models/asset/base_asset.model.dart';
import 'package:immich_mobile/models/download/livephotos_medatada.model.dart';
import 'package:immich_mobile/services/api.service.dart';
import 'package:immich_mobile/utils/image_url_builder.dart';

// ignore: dispose-provided-instances
final downloadRepositoryProvider = Provider((ref) => DownloadRepository());

class DownloadRepository {
  static const livePhotoFormatHeader = 'X-Immich-Live-Photo-Format';
  static const androidMotionHeicFormat = 'android-motion-heic';
  static final _downloader = FileDownloader();
  static final _dummyTask = DownloadTask(
    taskId: 'dummy',
    url: '',
    filename: 'dummy',
    group: '',
    updates: Updates.statusAndProgress,
  );
  static final _dummyMetadata = {'part': LivePhotosPart.image.index, 'id': ''};

  void Function(TaskStatusUpdate)? onImageDownloadStatus;

  void Function(TaskStatusUpdate)? onVideoDownloadStatus;

  void Function(TaskProgressUpdate)? onTaskProgress;

  // #29900: `taskStatusCallback` is called before the DB has been updated, causing a race between the two Live Photo tasks
  // This callback instead listens directly to DB updates
  void Function(TaskRecord)? onLivePhotoRecordComplete;

  DownloadRepository() {
    _downloader.registerCallbacks(
      group: kDownloadGroupImage,
      taskStatusCallback: (update) => onImageDownloadStatus?.call(update),
      taskProgressCallback: (update) => onTaskProgress?.call(update),
    );

    _downloader.registerCallbacks(
      group: kDownloadGroupVideo,
      taskStatusCallback: (update) => onVideoDownloadStatus?.call(update),
      taskProgressCallback: (update) => onTaskProgress?.call(update),
    );

    _downloader.registerCallbacks(
      group: kDownloadGroupLivePhoto,
      taskProgressCallback: (update) => onTaskProgress?.call(update),
    );

    _downloader.database.updates
        .where((record) => record.group == kDownloadGroupLivePhoto && record.status == TaskStatus.complete)
        .listen((record) => onLivePhotoRecordComplete?.call(record));
  }

  Future<List<bool>> downloadAll(List<DownloadTask> tasks) {
    return _downloader.enqueueAll(tasks);
  }

  Future<void> deleteAllTrackingRecords() {
    return _downloader.database.deleteAllRecords();
  }

  Future<bool> cancel(String id) {
    return _downloader.cancelTaskWithId(id);
  }

  Future<List<TaskRecord>> getLiveVideoTasks() {
    return _downloader.database.allRecordsWithStatus(TaskStatus.complete, group: kDownloadGroupLivePhoto);
  }

  Future<void> deleteRecordsWithIds(List<String> ids) {
    return _downloader.database.deleteRecordsWithIds(ids);
  }

  Future<List<bool>> downloadAllAssets(List<RemoteAsset> assets) async {
    if (assets.isEmpty) {
      return Future.value(const []);
    }

    final length = Platform.isAndroid ? assets.length : assets.length * 2;
    final tasks = List.filled(length, _dummyTask);
    int taskIndex = 0;
    final headers = ApiService.getRequestHeaders();
    for (final asset in assets) {
      if (!asset.isRemoteOnly) {
        continue;
      }

      final id = asset.id;
      final livePhotoVideoId = asset.livePhotoVideoId;
      final isVideo = asset.isVideo;
      final url = getOriginalUrlForRemoteId(id);

      if (Platform.isAndroid || livePhotoVideoId == null || isVideo) {
        final isAndroidLivePhoto = Platform.isAndroid && livePhotoVideoId != null && !isVideo;
        tasks[taskIndex++] = DownloadTask(
          taskId: id,
          url: url,
          headers: downloadHeaders(headers, isAndroidLivePhoto: isAndroidLivePhoto),
          filename: downloadFilename(asset.name, isAndroidLivePhoto: isAndroidLivePhoto),
          updates: Updates.statusAndProgress,
          group: isVideo ? kDownloadGroupVideo : kDownloadGroupImage,
        );
        continue;
      }

      _dummyMetadata['part'] = LivePhotosPart.image.index;
      _dummyMetadata['id'] = id;
      tasks[taskIndex++] = DownloadTask(
        taskId: id,
        url: url,
        headers: headers,
        filename: asset.name,
        updates: Updates.statusAndProgress,
        group: kDownloadGroupLivePhoto,
        metaData: json.encode(_dummyMetadata),
      );

      _dummyMetadata['part'] = LivePhotosPart.video.index;
      tasks[taskIndex++] = DownloadTask(
        taskId: livePhotoVideoId,
        url: getOriginalUrlForRemoteId(livePhotoVideoId),
        headers: headers,
        filename: asset.name.toUpperCase().replaceAll(RegExp(r"\.(JPG|HEIC)$"), '.MOV'),
        updates: Updates.statusAndProgress,
        group: kDownloadGroupLivePhoto,
        metaData: json.encode(_dummyMetadata),
      );
    }
    if (taskIndex == 0) {
      return Future.value(const []);
    }
    return _downloader.enqueueAll(tasks.slice(0, taskIndex));
  }

  @visibleForTesting
  static Map<String, String> downloadHeaders(Map<String, String> base, {required bool isAndroidLivePhoto}) {
    if (!isAndroidLivePhoto) {
      return base;
    }
    return {...base, livePhotoFormatHeader: androidMotionHeicFormat};
  }

  @visibleForTesting
  static String downloadFilename(String original, {required bool isAndroidLivePhoto}) {
    if (!isAndroidLivePhoto || original.toLowerCase().endsWith('.heic')) {
      return original;
    }
    final extension = RegExp(r'\.[^.]+$');
    return '${original.replaceFirst(extension, '')}.heic';
  }
}
