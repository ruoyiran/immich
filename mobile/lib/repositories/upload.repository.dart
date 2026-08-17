// ignore_for_file: prefer_initializing_formals

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:background_downloader/background_downloader.dart' hide Request;
import 'package:crypto/crypto.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:http/http.dart';
import 'package:immich_mobile/constants/constants.dart';
import 'package:immich_mobile/domain/models/store.model.dart';
import 'package:immich_mobile/entities/store.entity.dart';
import 'package:immich_mobile/infrastructure/repositories/local_asset.repository.dart';
import 'package:immich_mobile/infrastructure/repositories/network.repository.dart';
import 'package:immich_mobile/platform/native_sync_api.g.dart';
import 'package:immich_mobile/providers/infrastructure/asset.provider.dart';
import 'package:immich_mobile/services/api.service.dart';
import 'package:immich_mobile/utils/debug_print.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

final uploadRepositoryProvider = Provider(
  (ref) => UploadRepository(localAssetRepository: ref.watch(localAssetRepository)),
);

class UploadRepository {
  static const int resumableChunkBytes = 4 * 1024 * 1024;
  static const Duration pmliveArtifactMaxAge = Duration(days: 1);
  static final RegExp _pmliveBundleName = RegExp(r'^pc-[0-9a-f]{64}\.pmlive$');
  static final RegExp _pmlivePartName = RegExp(
    r'^\.pc-[0-9a-f]{64}\.pmlive\.[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.part$',
    caseSensitive: false,
  );
  final Logger logger = Logger('UploadRepository');
  final NativeSyncApi _nativeSyncApi;
  final DriftLocalAssetRepository? _localAssetRepository;
  final Client? _clientOverride;
  final Directory? _stateDirectoryOverride;
  final String? _endpointOverride;
  final Map<String, String>? _headersOverride;
  final Map<String, Future<void>> _serverCapabilityChecks = {};
  void Function(TaskStatusUpdate)? onUploadStatus;
  void Function(TaskProgressUpdate)? onTaskProgress;

  UploadRepository({
    NativeSyncApi? nativeSyncApi,
    DriftLocalAssetRepository? localAssetRepository,
    Client? client,
    Directory? stateDirectory,
    String? endpoint,
    Map<String, String>? headers,
    bool registerDownloaderCallbacks = true,
  }) : _nativeSyncApi = nativeSyncApi ?? NativeSyncApi(),
       _localAssetRepository = localAssetRepository,
       _clientOverride = client,
       _stateDirectoryOverride = stateDirectory,
       _endpointOverride = endpoint,
       _headersOverride = headers {
    if (registerDownloaderCallbacks) {
      FileDownloader().registerCallbacks(
        group: kBackupGroup,
        taskStatusCallback: (update) => onUploadStatus?.call(update),
        taskProgressCallback: (update) => onTaskProgress?.call(update),
      );
      FileDownloader().registerCallbacks(
        group: kBackupLivePhotoGroup,
        taskStatusCallback: (update) => onUploadStatus?.call(update),
        taskProgressCallback: (update) => onTaskProgress?.call(update),
      );
      FileDownloader().registerCallbacks(
        group: kManualUploadGroup,
        taskStatusCallback: (update) => onUploadStatus?.call(update),
        taskProgressCallback: (update) => onTaskProgress?.call(update),
      );
    }
  }

  Client get _client => _clientOverride ?? NetworkRepository.client;

  Map<String, String> get _requestHeaders => _headersOverride ?? ApiService.getRequestHeaders();

  Future<void> enqueueBackground(UploadTask task) {
    return FileDownloader().enqueue(task);
  }

  Future<List<bool>> enqueueBackgroundAll(List<UploadTask> tasks) {
    return FileDownloader().enqueueAll(tasks);
  }

  Future<void> deleteDatabaseRecords(String group) {
    return FileDownloader().database.deleteAllRecords(group: group);
  }

  Future<bool> cancelAll(String group) {
    return FileDownloader().cancelAll(group: group);
  }

  Future<int> reset(String group) {
    return FileDownloader().reset(group: group);
  }

  /// Get a list of tasks that are ENQUEUED or RUNNING
  Future<List<Task>> getActiveTasks(String group) {
    return FileDownloader().allTasks(group: group);
  }

  Future<void> start() {
    return FileDownloader().start();
  }

  Future<void> getUploadInfo() async {
    final [enqueuedTasks, runningTasks, canceledTasks, waitingTasks, pausedTasks] = await Future.wait([
      FileDownloader().database.allRecordsWithStatus(TaskStatus.enqueued, group: kBackupGroup),
      FileDownloader().database.allRecordsWithStatus(TaskStatus.running, group: kBackupGroup),
      FileDownloader().database.allRecordsWithStatus(TaskStatus.canceled, group: kBackupGroup),
      FileDownloader().database.allRecordsWithStatus(TaskStatus.waitingToRetry, group: kBackupGroup),
      FileDownloader().database.allRecordsWithStatus(TaskStatus.paused, group: kBackupGroup),
    ]);

    dPrint(
      () =>
          """
      Upload Info:
      Enqueued: ${enqueuedTasks.length}
      Running: ${runningTasks.length}
      Canceled: ${canceledTasks.length}
      Waiting: ${waitingTasks.length}
      Paused: ${pausedTasks.length}
    """,
    );
  }

  Future<UploadResult> uploadFile({
    required File file,
    required String originalFileName,
    required Map<String, String> fields,
    required Completer<void>? cancelToken,
    void Function(int bytes, int totalBytes)? onProgress,
    required String logContext,
    required String checksum,
    required String uploadId,
  }) async {
    try {
      final endpoint =
          _endpointOverride ?? Store.get(StoreKey.serverEndpoint) ?? (throw StateError('Server endpoint is missing'));
      await _ensureServerCapability(endpoint);
      final logicalUploadId = _deriveResumableUploadId(endpoint, uploadId, checksum);
      if (await _readResumableAttempt(logicalUploadId, checksum) == null) {
        final size = await file.length();
        final duplicate = await _bulkUploadCheck(
          endpoint: endpoint,
          localAssetId: uploadId,
          checksum: checksum,
          size: size,
        );
        if (duplicate != null) {
          final metadata =
              _buildResumableMetadata(
                  file: file,
                  fields: fields,
                  originalFileName: originalFileName,
                  isPMLive: p.extension(originalFileName).toLowerCase() == '.pmlive',
                )
                ..remove('live_photo_role')
                ..remove('container');
          await _updateDuplicateMetadata(endpoint, duplicate.remoteAssetId!, metadata);
          return duplicate;
        }
      }
      return await _uploadResumable(
        file: file,
        originalFileName: originalFileName,
        fields: fields,
        checksum: checksum,
        localAssetId: uploadId,
        cancelToken: cancelToken,
        onProgress: onProgress,
      );
    } on _UploadHTTPException catch (error) {
      return UploadResult.error(statusCode: error.statusCode, errorMessage: error.message);
    } catch (error, stackTrace) {
      logger.warning("Error uploading $logContext: $error: $stackTrace");
      return UploadResult.error(errorMessage: error.toString());
    }
  }

  Future<UploadResult?> preflightResumableTerminal({required String checksum, required String uploadId}) async {
    try {
      await cleanupStalePMLiveArtifacts();
      final endpoint =
          _endpointOverride ?? Store.get(StoreKey.serverEndpoint) ?? (throw StateError('Server endpoint is missing'));
      await _ensureServerCapability(endpoint);
      final logicalUploadId = _deriveResumableUploadId(endpoint, uploadId, checksum);
      final attempt = await _readResumableAttempt(logicalUploadId, checksum);
      if (attempt == null) {
        return null;
      }
      final status = await _sendResumableJSON(Uri.parse('$endpoint/uploads/resumable'), 'POST', attempt.startBody);
      await _persistResumableState(attempt, status);
      if (!status.complete) {
        return null;
      }
      if (status.assetId == null || (status.assetStatus != 'created' && status.assetStatus != 'duplicate')) {
        return UploadResult.error(errorMessage: 'Server completed upload without a stable asset result');
      }
      await _deleteResumableState(logicalUploadId);
      await _deleteOwnedPMLiveArtifact(attempt.sourcePath, attempt.uploadId);
      return UploadResult.success(remoteAssetId: status.assetId!, assetStatus: status.assetStatus);
    } on _UploadHTTPException catch (error) {
      return UploadResult.error(statusCode: error.statusCode, errorMessage: error.message);
    } catch (error, stackTrace) {
      logger.warning('Error checking persisted resumable upload $uploadId: $error: $stackTrace');
      return UploadResult.error(errorMessage: error.toString());
    }
  }

  Future<String> ensureAssetChecksum(
    String assetId,
    String? checksum, {
    String? contentMd5,
    int? contentSize,
    String? hashAlgorithm,
    DateTime? hashedModifiedAt,
    required DateTime modifiedAt,
  }) async {
    final cachedHashIsCurrent =
        hashAlgorithm == 'md5' &&
        contentMd5 != null &&
        RegExp(r'^[0-9a-f]{32}$').hasMatch(contentMd5) &&
        contentSize != null &&
        contentSize > 0 &&
        hashedModifiedAt == modifiedAt;
    if (cachedHashIsCurrent && _isBase64MD5(checksum) && _md5Hex(checksum!) == contentMd5) {
      return checksum;
    }
    final results = await _nativeSyncApi.hashAssets([assetId]);
    if (results.length != 1 ||
        results.first.hash == null ||
        results.first.algorithm != 'md5' ||
        results.first.size == null ||
        results.first.size! <= 0 ||
        !_isBase64MD5(results.first.hash)) {
      throw StateError(
        results.isEmpty
            ? 'Failed to hash asset before upload'
            : results.first.error ?? 'Failed to hash asset before upload',
      );
    }
    final result = results.first;
    final value = result.hash!;
    await _localAssetRepository?.updateContentHashes({
      assetId: (checksum: value, md5: _md5Hex(value), size: result.size!, modifiedAt: modifiedAt),
    });
    return value;
  }

  /// Share-intent files are not [LocalAsset] records and therefore have no
  /// native library identifier. Local asset uploads must use
  /// [ensureAssetChecksum] instead.
  Future<String> hashShareIntentFile(File file) async {
    final digest = await md5.bind(file.openRead()).first;
    return base64Encode(digest.bytes);
  }

  Future<UploadResult?> preflightLocalAssetIdentity({
    required String assetId,
    required String localAssetId,
    required String deviceId,
    required int size,
    required DateTime modifiedAt,
    required String originalFileName,
    required Map<String, String> fields,
  }) async {
    if (deviceId.isEmpty || localAssetId.isEmpty || size <= 0) {
      return null;
    }
    final endpoint =
        _endpointOverride ?? Store.get(StoreKey.serverEndpoint) ?? (throw StateError('Server endpoint is missing'));
    await _ensureServerCapability(endpoint);
    final request = Request('POST', Uri.parse('$endpoint/assets/bulk-device-check'))
      ..headers.addAll(_requestHeaders)
      ..headers['Content-Type'] = 'application/json'
      ..body = jsonEncode({
        'assets': [
          {
            'id': assetId,
            'deviceId': deviceId,
            'localAssetId': localAssetId,
            'size': size,
            'modifiedTime': modifiedAt.toUtc().microsecondsSinceEpoch * 1000,
          },
        ],
      });
    final response = await _client.send(request);
    final body = await response.stream.bytesToString();
    if (response.statusCode != 200) {
      throw _UploadHTTPException(response.statusCode, _errorMessage(response.statusCode, body));
    }
    final value = jsonDecode(body) as Map<String, dynamic>;
    final results = value['results'] as List<dynamic>?;
    if (results == null || results.length != 1) {
      throw const FormatException('Invalid bulk device check response');
    }
    final result = results.single as Map<String, dynamic>;
    if (result['id'] != assetId || (result['action'] != 'accept' && result['action'] != 'reject')) {
      throw const FormatException('Invalid bulk device check result');
    }
    if (result['action'] == 'accept') {
      return null;
    }
    final remoteAssetId = result['assetId'];
    final checksum = result['checksum'];
    if (remoteAssetId is! String || remoteAssetId.isEmpty || checksum is! String || !_isBase64MD5(checksum)) {
      throw const FormatException('Device match is missing its asset identity');
    }
    await _localAssetRepository?.updateContentHashes({
      assetId: (checksum: checksum, md5: _md5Hex(checksum), size: size, modifiedAt: modifiedAt),
    });
    final metadata = _buildMetadataWithoutFile(fields: fields, originalFileName: originalFileName, isPMLive: false);
    await _updateDuplicateMetadata(endpoint, remoteAssetId, metadata);
    return UploadResult.success(remoteAssetId: remoteAssetId, assetStatus: 'duplicate');
  }

  Future<String> ensureAssetFileChecksum(
    String assetId,
    File file, {
    String? checksum,
    String? contentMd5,
    int? contentSize,
    String? hashAlgorithm,
    DateTime? hashedModifiedAt,
    required DateTime modifiedAt,
  }) async {
    final size = await file.length();
    final cachedHashIsCurrent =
        hashAlgorithm == 'md5' &&
        contentMd5 != null &&
        RegExp(r'^[0-9a-f]{32}$').hasMatch(contentMd5) &&
        contentSize == size &&
        hashedModifiedAt == modifiedAt;
    if (cachedHashIsCurrent && _isBase64MD5(checksum) && _md5Hex(checksum!) == contentMd5) {
      return checksum;
    }
    final value = await hashShareIntentFile(file);
    await _localAssetRepository?.updateContentHashes({
      assetId: (checksum: value, md5: _md5Hex(value), size: size, modifiedAt: modifiedAt),
    });
    return value;
  }

  Future<void> _ensureServerCapability(String endpoint) async {
    final existing = _serverCapabilityChecks[endpoint];
    if (existing != null) {
      return existing;
    }
    final check = () async {
      final request = Request('GET', Uri.parse('$endpoint/server/config'))..headers.addAll(_requestHeaders);
      final response = await _client.send(request);
      final body = await response.stream.bytesToString();
      if (response.statusCode != 200) {
        throw _UploadHTTPException(response.statusCode, _errorMessage(response.statusCode, body));
      }
      try {
        final value = jsonDecode(body) as Map<String, dynamic>;
        if (value['checksumAlgorithm'] != 'md5-size') {
          throw const FormatException('unsupported checksum algorithm');
        }
      } catch (_) {
        throw StateError('Server does not support MD5+size uploads. Upgrade photo-classifier before syncing.');
      }
    }();
    _serverCapabilityChecks[endpoint] = check;
    try {
      await check;
    } catch (_) {
      if (identical(_serverCapabilityChecks[endpoint], check)) {
        _serverCapabilityChecks.remove(endpoint)?.ignore();
      }
      rethrow;
    }
  }

  Future<UploadResult?> _bulkUploadCheck({
    required String endpoint,
    required String localAssetId,
    required String checksum,
    required int size,
  }) async {
    final request = Request('POST', Uri.parse('$endpoint/assets/bulk-upload-check'))
      ..headers.addAll(_requestHeaders)
      ..headers['Content-Type'] = 'application/json'
      ..body = jsonEncode({
        'algorithm': 'md5',
        'assets': [
          {'id': localAssetId, 'md5': _md5Hex(checksum), 'size': size},
        ],
      });
    final response = await _client.send(request);
    final body = await response.stream.bytesToString();
    if (response.statusCode != 200) {
      throw _UploadHTTPException(response.statusCode, _errorMessage(response.statusCode, body));
    }
    final value = jsonDecode(body) as Map<String, dynamic>;
    final results = value['results'] as List<dynamic>?;
    if (results == null || results.length != 1) {
      throw const FormatException('Invalid bulk upload check response');
    }
    final result = results.single as Map<String, dynamic>;
    if (result['id'] != localAssetId || (result['action'] != 'accept' && result['action'] != 'reject')) {
      throw const FormatException('Invalid bulk upload check result');
    }
    if (result['action'] == 'accept') {
      return null;
    }
    final assetId = result['assetId'];
    if (assetId is! String || assetId.isEmpty) {
      throw const FormatException('Duplicate result is missing assetId');
    }
    return UploadResult.success(remoteAssetId: assetId, assetStatus: 'duplicate');
  }

  Future<void> _updateDuplicateMetadata(String endpoint, String assetId, Map<String, Object> metadata) async {
    final request = Request('POST', Uri.parse('$endpoint/assets/bulk-metadata'))
      ..headers.addAll(_requestHeaders)
      ..headers['Content-Type'] = 'application/json'
      ..body = jsonEncode({
        'assets': [
          {'assetId': assetId, 'metadata': metadata},
        ],
      });
    final response = await _client.send(request);
    final body = await response.stream.bytesToString();
    if (response.statusCode != 200) {
      throw _UploadHTTPException(response.statusCode, _errorMessage(response.statusCode, body));
    }
  }

  Future<File> createPMLiveBundle({
    required String assetId,
    required String checksum,
    required File stillFile,
    required File motionFile,
    required String stillOriginalName,
    required String motionOriginalName,
    required DateTime createdAt,
    required DateTime modifiedAt,
  }) async {
    await cleanupStalePMLiveArtifacts();
    final endpoint =
        _endpointOverride ?? Store.get(StoreKey.serverEndpoint) ?? (throw StateError('Server endpoint is missing'));
    final support = await _supportDirectory();
    final directory = Directory(p.join(support.path, 'pmlive-upload-attempts'));
    await directory.create(recursive: true);
    final logicalUploadId = _deriveResumableUploadId(endpoint, assetId, checksum);
    final persisted = await _readResumableAttempt(logicalUploadId, checksum);
    if (persisted != null &&
        persisted.isPMLive &&
        _isOwnedPMLiveBundlePath(directory, persisted.sourcePath, persisted.uploadId) &&
        await _pmliveSourceMatchesAttempt(File(persisted.sourcePath), persisted)) {
      return File(persisted.sourcePath);
    }
    final provisional = File(p.join(directory.path, '.$logicalUploadId.pmlive.${const Uuid().v4()}.part'));
    try {
      final path = await _nativeSyncApi.createPMLive(
        PMLiveInput(
          stillPath: stillFile.path,
          motionPath: motionFile.path,
          outputPath: provisional.path,
          stillOriginalName: stillOriginalName,
          motionOriginalName: motionOriginalName,
          stillUTI: _utiForName(stillOriginalName, fallback: 'public.image'),
          motionUTI: _utiForName(motionOriginalName, fallback: 'com.apple.quicktime-movie'),
          createdUnixNano: createdAt.microsecondsSinceEpoch * 1000,
          modifiedUnixNano: modifiedAt.microsecondsSinceEpoch * 1000,
        ),
      );
      if (p.normalize(p.absolute(path)) != p.normalize(p.absolute(provisional.path)) ||
          FileSystemEntity.typeSync(provisional.path, followLinks: false) != FileSystemEntityType.file) {
        throw StateError('Native PMLive writer returned an invalid provisional artifact');
      }
      final containerDigest = await _sha256File(provisional);
      final attemptUploadId = _derivePMLiveUploadId(logicalUploadId, containerDigest);
      final output = File(p.join(directory.path, '$attemptUploadId.pmlive'));
      final outputType = FileSystemEntity.typeSync(output.path, followLinks: false);
      if (outputType != FileSystemEntityType.notFound) {
        if (outputType != FileSystemEntityType.file || await _sha256File(output) != containerDigest) {
          throw StateError('PMLive attempt output path is not the expected regular artifact');
        }
        await provisional.delete();
      } else {
        await provisional.rename(output.path);
      }
      if (persisted != null && persisted.sourcePath != output.path) {
        await _deleteOwnedPMLiveArtifact(persisted.sourcePath, persisted.uploadId);
      }
      return output;
    } catch (_) {
      if (FileSystemEntity.typeSync(provisional.path, followLinks: false) == FileSystemEntityType.file) {
        await provisional.delete();
      }
      rethrow;
    }
  }

  Future<UploadResult> _uploadResumable({
    required File file,
    required String originalFileName,
    required Map<String, String> fields,
    required String checksum,
    required String localAssetId,
    required Completer<void>? cancelToken,
    void Function(int bytes, int totalBytes)? onProgress,
  }) async {
    await cleanupStalePMLiveArtifacts();
    final endpoint =
        _endpointOverride ?? Store.get(StoreKey.serverEndpoint) ?? (throw StateError('Server endpoint is missing'));
    final logicalUploadId = _deriveResumableUploadId(endpoint, localAssetId, checksum);
    final isPMLive = p.extension(originalFileName).toLowerCase() == '.pmlive';
    var attempt = await _readResumableAttempt(logicalUploadId, checksum);
    final candidatePMLiveDigest = isPMLive ? await _regularFileSha256(file) : null;
    final pmliveContainerDigest =
        candidatePMLiveDigest ?? (isPMLive && attempt?.isPMLive == true ? attempt!.pmliveContainerSha256 : null);
    if (isPMLive && pmliveContainerDigest == null) {
      throw StateError('PMLive resumable upload source is unavailable or changed');
    }
    final uploadId = pmliveContainerDigest == null
        ? logicalUploadId
        : _derivePMLiveUploadId(logicalUploadId, pmliveContainerDigest);
    final uri = Uri.parse('$endpoint/uploads/resumable');
    if (attempt != null &&
        (attempt.uploadId != uploadId ||
            attempt.isPMLive != isPMLive ||
            (isPMLive && attempt.pmliveContainerSha256 != pmliveContainerDigest))) {
      // The server has no reset endpoint. A changed PMLive container therefore
      // gets a digest-specific server attempt while this logical-id state file
      // remains the single bounded local slot. The old server partial may age
      // out remotely, but its acknowledged prefix can never be spliced into
      // the replacement container.
      attempt = null;
    }
    if (attempt == null) {
      attempt = _ResumableAttempt(
        logicalUploadId: logicalUploadId,
        uploadId: uploadId,
        sourcePath: file.path,
        originalFileName: originalFileName,
        checksum: checksum,
        pmliveContainerSha256: pmliveContainerDigest,
        size: await file.length(),
        metadata: _buildResumableMetadata(
          file: file,
          fields: fields,
          originalFileName: originalFileName,
          isPMLive: isPMLive,
        ),
        isFavorite: fields['isFavorite'] == 'true',
        visibility: fields['visibility'] ?? 'timeline',
      );
      await _persistResumableState(
        attempt,
        _ResumableStatus(generation: '', offset: 0, size: attempt.size, complete: false),
      );
    }
    final size = attempt.size;
    var status = await _sendResumableJSON(uri, 'POST', attempt.startBody);
    await _persistResumableState(attempt, status);
    if (!status.complete) {
      var source = File(attempt.sourcePath);
      if (attempt.isPMLive) {
        if (!await _pmliveSourceMatchesAttempt(source, attempt)) {
          if (!await _pmliveSourceMatchesAttempt(file, attempt)) {
            throw StateError('Persisted PMLive resumable upload source is unavailable or changed');
          }
          attempt = attempt.withSourcePath(file.path);
          source = file;
          await _persistResumableState(attempt, status);
        }
      } else if (!await _normalSourceMatchesAttempt(source, attempt)) {
        attempt = await _rebindVerifiedNormalSource(attempt, file);
        source = File(attempt.sourcePath);
        await _persistResumableState(attempt, status);
      }
      final handle = await source.open();
      try {
        while (!status.complete) {
          if (cancelToken?.isCompleted ?? false) {
            await _persistResumableState(attempt, status);
            await _deleteOwnedPMLiveArtifact(attempt.sourcePath, attempt.uploadId);
            return UploadResult.cancelled();
          }
          final offset = status.offset;
          if (offset < 0 || offset >= size || status.generation.isEmpty) {
            return UploadResult.error(errorMessage: 'Invalid resumable upload status');
          }
          await handle.setPosition(offset);
          final length = minInt(resumableChunkBytes, size - offset);
          final chunk = await handle.read(length);
          if (chunk.length != length) {
            return UploadResult.error(errorMessage: 'Upload source changed while reading');
          }
          final request = Request('PUT', uri.replace(path: '${uri.path}/$uploadId'))
            ..headers.addAll(_requestHeaders)
            ..headers['Content-Type'] = 'application/octet-stream'
            ..headers['Content-Range'] = 'bytes $offset-${offset + length - 1}/$size'
            ..headers['Content-MD5'] = base64Encode(md5.convert(chunk).bytes)
            ..headers['X-Upload-Generation'] = status.generation
            ..bodyBytes = chunk;
          final response = await _client.send(request);
          final responseBody = await response.stream.bytesToString();
          if (response.statusCode == 409) {
            final conflict = _ResumableStatus.tryConflict(responseBody, fallbackSize: size);
            if (conflict == null) {
              await _persistResumableState(attempt, status);
              return _uploadError(response.statusCode, responseBody);
            }
            status = conflict;
            await _persistResumableState(attempt, status);
            continue;
          }
          if (response.statusCode != 200) {
            await _persistResumableState(attempt, status);
            return _uploadError(response.statusCode, responseBody);
          }
          status = _ResumableStatus.fromJSON(responseBody, fallbackSize: size);
          await _persistResumableState(attempt, status);
          onProgress?.call(status.offset, size);
        }
      } finally {
        await handle.close();
      }
    }
    if (status.assetId == null || (status.assetStatus != 'created' && status.assetStatus != 'duplicate')) {
      return UploadResult.error(errorMessage: 'Server completed upload without a stable asset result');
    }
    await _deleteResumableState(logicalUploadId);
    await _deleteOwnedPMLiveArtifact(attempt.sourcePath, attempt.uploadId);
    return UploadResult.success(remoteAssetId: status.assetId!, assetStatus: status.assetStatus);
  }

  Map<String, Object?>? _decodeSourceMetadata(String? encoded) {
    if (encoded == null || encoded.isEmpty) {
      return null;
    }
    if (utf8.encode(encoded).length > 64 * 1024) {
      throw const FormatException('sourceMetadata exceeds 64 KiB');
    }
    final decoded = jsonDecode(encoded);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('sourceMetadata must be a JSON object');
    }
    return Map<String, Object?>.from(decoded);
  }

  Map<String, Object> _buildResumableMetadata({
    required File file,
    required Map<String, String> fields,
    required String originalFileName,
    required bool isPMLive,
  }) {
    final sourceStat = file.statSync();
    return _buildMetadataWithoutFile(
      fields: fields,
      originalFileName: originalFileName,
      isPMLive: isPMLive,
      accessedAt: sourceStat.accessed,
    );
  }

  Map<String, Object> _buildMetadataWithoutFile({
    required Map<String, String> fields,
    required String originalFileName,
    required bool isPMLive,
    DateTime? accessedAt,
  }) {
    final createdAt = DateTime.parse(fields['fileCreatedAt']!).toUtc();
    final modifiedAt = DateTime.parse(fields['fileModifiedAt']!).toUtc();
    final sourceMetadata = <String, Object?>{
      'schema_version': 1,
      'source': 'mobile',
      if (fields['deviceId'] != null) 'device_id': fields['deviceId'],
      if (fields['deviceAssetId'] != null) 'platform_asset_id': fields['deviceAssetId'],
      ...?_decodeSourceMetadata(fields['sourceMetadata']),
      'uploaded_original_name': originalFileName,
    };
    return <String, Object>{
      'original_created_unix_nano': createdAt.microsecondsSinceEpoch * 1000,
      'original_modified_unix_nano': modifiedAt.microsecondsSinceEpoch * 1000,
      if (accessedAt != null) 'original_accessed_unix_nano': accessedAt.toUtc().microsecondsSinceEpoch * 1000,
      'source_metadata': sourceMetadata,
      if (fields['livePhotoRole'] != null) 'live_photo_role': fields['livePhotoRole']!,
      if (fields['livePhotoVideoId'] != null) 'live_photo_video_id': fields['livePhotoVideoId']!,
      if (isPMLive) 'is_live': true,
      if (isPMLive) 'container': 'pmlive-v1',
    };
  }

  Future<_ResumableStatus> _sendResumableJSON(Uri uri, String method, String body) async {
    final request = Request(method, uri)
      ..headers.addAll(_requestHeaders)
      ..headers['Content-Type'] = 'application/json'
      ..body = body;
    final response = await _client.send(request);
    final responseBody = await response.stream.bytesToString();
    if (response.statusCode != 200) {
      throw _UploadHTTPException(response.statusCode, _errorMessage(response.statusCode, responseBody));
    }
    return _ResumableStatus.fromJSON(responseBody);
  }

  Future<File> _resumableStateFile(String uploadId) async {
    final support = await _supportDirectory();
    final directory = Directory(p.join(support.path, 'resumable-uploads'));
    await directory.create(recursive: true);
    return File(p.join(directory.path, '${sha256.convert(utf8.encode(uploadId))}.json'));
  }

  Future<Directory> _supportDirectory() async => _stateDirectoryOverride ?? await getApplicationSupportDirectory();

  Future<String> _sha256File(File file) async => (await sha256.bind(file.openRead()).first).toString();

  Future<String?> _regularFileSha256(File file) async {
    if (FileSystemEntity.typeSync(file.path, followLinks: false) != FileSystemEntityType.file) {
      return null;
    }
    return _sha256File(file);
  }

  Future<bool> _pmliveSourceMatchesAttempt(File source, _ResumableAttempt attempt) async {
    final expectedDigest = attempt.pmliveContainerSha256;
    if (expectedDigest == null ||
        FileSystemEntity.typeSync(source.path, followLinks: false) != FileSystemEntityType.file) {
      return false;
    }
    final stat = source.statSync();
    if (stat.type != FileSystemEntityType.file || stat.size != attempt.size) {
      return false;
    }
    return await _sha256File(source) == expectedDigest;
  }

  Future<_ResumableAttempt> _rebindVerifiedNormalSource(_ResumableAttempt attempt, File candidate) async {
    final stat = candidate.statSync();
    if (stat.type != FileSystemEntityType.file || stat.size != attempt.size) {
      throw StateError('Fresh resumable upload source is unavailable or changed');
    }
    final digest = await md5.bind(candidate.openRead()).first;
    if (base64Encode(digest.bytes) != attempt.checksum) {
      throw StateError('Fresh resumable upload source checksum does not match the persisted attempt');
    }
    return attempt.withSourcePath(candidate.path);
  }

  Future<bool> _normalSourceMatchesAttempt(File source, _ResumableAttempt attempt) async {
    final stat = source.statSync();
    if (stat.type != FileSystemEntityType.file || stat.size != attempt.size) {
      return false;
    }
    final digest = await md5.bind(source.openRead()).first;
    return base64Encode(digest.bytes) == attempt.checksum;
  }

  Future<void> cleanupStalePMLiveArtifacts({DateTime? now, Duration maxAge = pmliveArtifactMaxAge}) async {
    final support = await _supportDirectory();
    final attempts = Directory(p.join(support.path, 'pmlive-upload-attempts'));
    if (!attempts.existsSync()) {
      return;
    }
    final referenced = <String>{};
    final states = Directory(p.join(support.path, 'resumable-uploads'));
    if (states.existsSync()) {
      await for (final entity in states.list(followLinks: false)) {
        if (entity is! File || !p.basename(entity.path).endsWith('.json')) {
          continue;
        }
        try {
          final value = jsonDecode(await entity.readAsString()) as Map<String, dynamic>;
          final sourcePath = value['source_path'];
          final uploadId = value['upload_id'];
          if (sourcePath is String && uploadId is String && _isOwnedPMLiveBundlePath(attempts, sourcePath, uploadId)) {
            referenced.add(p.normalize(p.absolute(sourcePath)));
          }
        } catch (_) {
          // Corrupt state is handled by the resumable state reader. It does not
          // authorize deletion of paths outside the dedicated attempt folder.
        }
      }
    }
    final cutoff = (now ?? DateTime.now()).subtract(maxAge);
    await for (final entity in attempts.list(followLinks: false)) {
      if (entity is! File) {
        continue;
      }
      final name = p.basename(entity.path);
      if (!_pmliveBundleName.hasMatch(name) && !_pmlivePartName.hasMatch(name)) {
        continue;
      }
      final absolute = p.normalize(p.absolute(entity.path));
      if (referenced.contains(absolute)) {
        continue;
      }
      try {
        if (entity.lastModifiedSync().isBefore(cutoff)) {
          entity.deleteSync();
        }
      } catch (error) {
        logger.warning('Failed to clean stale PMLive artifact ${entity.path}: $error');
      }
    }
  }

  bool _isOwnedPMLiveBundlePath(Directory attempts, String pathValue, String uploadId) {
    final absoluteRoot = p.normalize(p.absolute(attempts.path));
    final absolutePath = p.normalize(p.absolute(pathValue));
    return p.dirname(absolutePath) == absoluteRoot &&
        _pmliveBundleName.hasMatch(p.basename(absolutePath)) &&
        p.basename(absolutePath) == '$uploadId.pmlive';
  }

  Future<void> _deleteOwnedPMLiveArtifact(String pathValue, String uploadId) async {
    final support = await _supportDirectory();
    final attempts = Directory(p.join(support.path, 'pmlive-upload-attempts'));
    if (!_isOwnedPMLiveBundlePath(attempts, pathValue, uploadId)) {
      return;
    }
    final file = File(pathValue);
    try {
      if (FileSystemEntity.typeSync(file.path, followLinks: false) == FileSystemEntityType.file) {
        file.deleteSync();
      }
    } catch (error) {
      logger.warning('Failed to clean terminal PMLive artifact $pathValue: $error');
    }
  }

  Future<void> _persistResumableState(_ResumableAttempt attempt, _ResumableStatus status) async {
    final target = await _resumableStateFile(attempt.logicalUploadId);
    final temporary = File('${target.path}.part');
    await temporary.writeAsString(jsonEncode(attempt.toStateJSON(status)), flush: true);
    await temporary.rename(target.path);
  }

  Future<void> _deleteResumableState(String uploadId) async {
    final state = await _resumableStateFile(uploadId);
    if (state.existsSync()) {
      state.deleteSync();
    }
  }

  Future<_ResumableAttempt?> _readResumableAttempt(String logicalUploadId, String checksum) async {
    final state = await _resumableStateFile(logicalUploadId);
    if (!state.existsSync()) {
      return null;
    }
    try {
      final value = jsonDecode(await state.readAsString()) as Map<String, dynamic>;
      final attempt = _ResumableAttempt.fromStateJSON(value);
      if (attempt.logicalUploadId == logicalUploadId && attempt.checksum == checksum) {
        return attempt;
      }
    } catch (_) {
      // Corrupt process-local metadata is discarded. The server query remains
      // the authority for generation and acknowledged offset.
    }
    state.deleteSync();
    return null;
  }

  UploadResult _uploadError(int statusCode, String body) =>
      UploadResult.error(statusCode: statusCode, errorMessage: _errorMessage(statusCode, body));

  String _errorMessage(int statusCode, String body) {
    if (statusCode == 413) {
      return 'Error(413) File is too large to upload';
    }
    try {
      final value = jsonDecode(body) as Map<String, dynamic>;
      return (value['message'] ?? value['error'] ?? 'Upload failed with status $statusCode') as String;
    } catch (_) {
      return body.isNotEmpty ? body : 'Upload failed with status $statusCode';
    }
  }

  static String _utiForName(String name, {required String fallback}) {
    return switch (p.extension(name).toLowerCase()) {
      '.heic' || '.heif' => 'public.heic',
      '.jpg' || '.jpeg' => 'public.jpeg',
      '.png' => 'public.png',
      '.mov' => 'com.apple.quicktime-movie',
      '.mp4' => 'public.mpeg-4',
      _ => fallback,
    };
  }

  static String _deriveResumableUploadId(String endpoint, String localAssetId, String checksum) {
    final uri = Uri.parse(endpoint);
    final path = uri.path.replaceFirst(RegExp(r'/+$'), '');
    final serverIdentity = uri.replace(path: path, query: null, fragment: null).toString();
    final identity = utf8.encode('$serverIdentity\u0000$localAssetId\u0000$checksum');
    return 'pc-${sha256.convert(identity)}';
  }

  static String _derivePMLiveUploadId(String logicalUploadId, String containerSha256) {
    final identity = utf8.encode('$logicalUploadId\u0000pmlive-v1\u0000$containerSha256');
    return 'pc-${sha256.convert(identity)}';
  }

  static bool _isBase64MD5(String? value) {
    if (value == null || value.isEmpty) {
      return false;
    }
    try {
      return base64Decode(value).length == 16;
    } catch (_) {
      return false;
    }
  }

  static String _md5Hex(String checksum) {
    final bytes = base64Decode(checksum);
    if (bytes.length != 16 || base64Encode(bytes) != checksum) {
      throw const FormatException('Asset checksum is not a canonical MD5 digest');
    }
    return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }
}

int minInt(int left, int right) => left < right ? left : right;

class _ResumableAttempt {
  static const int stateVersion = 2;

  final String logicalUploadId;
  final String uploadId;
  final String sourcePath;
  final String originalFileName;
  final String checksum;
  final String? pmliveContainerSha256;
  final int size;
  final Map<String, Object> metadata;
  final bool isFavorite;
  final String visibility;

  const _ResumableAttempt({
    required this.logicalUploadId,
    required this.uploadId,
    required this.sourcePath,
    required this.originalFileName,
    required this.checksum,
    required this.pmliveContainerSha256,
    required this.size,
    required this.metadata,
    required this.isFavorite,
    required this.visibility,
  });

  bool get isPMLive => metadata['container'] == 'pmlive-v1' && metadata['is_live'] == true;

  _ResumableAttempt withSourcePath(String value) => _ResumableAttempt(
    logicalUploadId: logicalUploadId,
    uploadId: uploadId,
    sourcePath: value,
    originalFileName: originalFileName,
    checksum: checksum,
    pmliveContainerSha256: pmliveContainerSha256,
    size: size,
    metadata: metadata,
    isFavorite: isFavorite,
    visibility: visibility,
  );

  String get startBody => jsonEncode({
    'upload_id': uploadId,
    'original_name': originalFileName,
    'size': size,
    'metadata': metadata,
    'generation_capability': 'required-v1',
    'md5': UploadRepository._md5Hex(checksum),
    'is_favorite': isFavorite,
    'visibility': visibility,
  });

  Map<String, Object> toStateJSON(_ResumableStatus status) => {
    'version': isPMLive && pmliveContainerSha256 == null ? 1 : stateVersion,
    'upload_id': uploadId,
    if (!isPMLive || pmliveContainerSha256 != null) 'logical_upload_id': logicalUploadId,
    'source_path': sourcePath,
    'original_name': originalFileName,
    'checksum': checksum,
    if (pmliveContainerSha256 != null) 'pmlive_container_sha256': pmliveContainerSha256!,
    'size': size,
    'metadata': metadata,
    'is_favorite': isFavorite,
    'visibility': visibility,
    'generation': status.generation,
    'offset': status.offset,
  };

  factory _ResumableAttempt.fromStateJSON(Map<String, dynamic> value) {
    final version = value['version'];
    if ((version != 1 && version != stateVersion) ||
        value['upload_id'] is! String ||
        value['source_path'] is! String ||
        value['original_name'] is! String ||
        value['checksum'] is! String ||
        value['size'] is! int ||
        value['metadata'] is! Map<String, dynamic> ||
        value['is_favorite'] is! bool ||
        value['visibility'] is! String) {
      throw const FormatException('Invalid resumable attempt state');
    }
    final size = value['size'] as int;
    final visibility = value['visibility'] as String;
    final logicalUploadId = version == 1 ? value['upload_id'] : value['logical_upload_id'];
    final pmliveContainerSha256 = value['pmlive_container_sha256'];
    if (logicalUploadId is! String ||
        (pmliveContainerSha256 != null &&
            (pmliveContainerSha256 is! String || !RegExp(r'^[0-9a-f]{64}$').hasMatch(pmliveContainerSha256))) ||
        size <= 0 ||
        (visibility != 'timeline' && visibility != 'hidden')) {
      throw const FormatException('Invalid resumable attempt values');
    }
    return _ResumableAttempt(
      logicalUploadId: logicalUploadId,
      uploadId: value['upload_id'] as String,
      sourcePath: value['source_path'] as String,
      originalFileName: value['original_name'] as String,
      checksum: value['checksum'] as String,
      pmliveContainerSha256: pmliveContainerSha256 as String?,
      size: size,
      metadata: Map<String, Object>.from(value['metadata'] as Map<String, dynamic>),
      isFavorite: value['is_favorite'] as bool,
      visibility: visibility,
    );
  }
}

class _UploadHTTPException implements Exception {
  final int statusCode;
  final String message;

  const _UploadHTTPException(this.statusCode, this.message);

  @override
  String toString() => message;
}

class _ResumableStatus {
  final String generation;
  final int offset;
  final int size;
  final bool complete;
  final String? assetId;
  final String? assetStatus;

  const _ResumableStatus({
    required this.generation,
    required this.offset,
    required this.size,
    required this.complete,
    this.assetId,
    this.assetStatus,
  });

  factory _ResumableStatus.fromJSON(String body, {int fallbackSize = 0}) {
    final value = jsonDecode(body) as Map<String, dynamic>;
    return _ResumableStatus(
      generation: value['generation'] as String? ?? '',
      offset: (value['offset'] as num?)?.toInt() ?? 0,
      size: (value['size'] as num?)?.toInt() ?? fallbackSize,
      complete: value['complete'] as bool? ?? false,
      assetId: value['asset_id'] as String?,
      assetStatus: value['asset_status'] as String?,
    );
  }

  static _ResumableStatus? tryConflict(String body, {required int fallbackSize}) {
    try {
      final value = jsonDecode(body) as Map<String, dynamic>;
      final generation = value['generation'] as String?;
      final offset = (value['offset'] as num?)?.toInt();
      if (generation == null || generation.isEmpty || offset == null) {
        return null;
      }
      return _ResumableStatus(
        generation: generation,
        offset: offset,
        size: fallbackSize,
        complete: offset == fallbackSize,
      );
    } catch (_) {
      return null;
    }
  }
}

class ProgressMultipartRequest extends MultipartRequest with Abortable {
  ProgressMultipartRequest(super.method, super.url, {this.abortTrigger, this.onProgress});

  @override
  final Future<void>? abortTrigger;

  final void Function(int bytes, int totalBytes)? onProgress;

  @override
  ByteStream finalize() {
    final byteStream = super.finalize();
    if (onProgress == null) {
      return byteStream;
    }

    final total = contentLength;
    var bytes = 0;
    final stream = byteStream.transform(
      StreamTransformer.fromHandlers(
        handleData: (List<int> data, EventSink<List<int>> sink) {
          bytes += data.length;
          onProgress!(bytes, total);
          sink.add(data);
        },
      ),
    );
    return ByteStream(stream);
  }
}

class UploadResult {
  final bool isSuccess;
  final bool isCancelled;
  final String? remoteAssetId;
  final String? errorMessage;
  final int? statusCode;
  final String? assetStatus;

  const UploadResult({
    required this.isSuccess,
    required this.isCancelled,
    this.remoteAssetId,
    this.errorMessage,
    this.statusCode,
    this.assetStatus,
  });

  factory UploadResult.success({required String remoteAssetId, String? assetStatus}) {
    return UploadResult(isSuccess: true, isCancelled: false, remoteAssetId: remoteAssetId, assetStatus: assetStatus);
  }

  factory UploadResult.error({String? errorMessage, int? statusCode}) {
    return UploadResult(isSuccess: false, isCancelled: false, errorMessage: errorMessage, statusCode: statusCode);
  }

  factory UploadResult.cancelled() {
    return const UploadResult(isSuccess: false, isCancelled: true);
  }
}
