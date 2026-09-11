// ignore_for_file: avoid_slow_async_io, prefer_initializing_formals

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:immich_mobile/domain/models/asset/base_asset.model.dart';
import 'package:immich_mobile/domain/models/original_media.model.dart';
import 'package:immich_mobile/domain/models/store.model.dart';
import 'package:immich_mobile/entities/store.entity.dart';
import 'package:immich_mobile/infrastructure/repositories/network.repository.dart';
import 'package:immich_mobile/services/api.service.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

typedef OriginalMediaCacheRequest = ({RemoteAsset asset, OriginalMediaType type});

class OriginalMediaCacheLimitException implements Exception {
  final int limit;

  const OriginalMediaCacheLimitException(this.limit);

  @override
  String toString() => 'Original media exceeds the cache limit of $limit bytes';
}

class OriginalMediaCacheClearedException implements Exception {
  const OriginalMediaCacheClearedException();

  @override
  String toString() => 'Original media cache was cleared while downloading';
}

final originalMediaCacheRepositoryProvider = Provider(
  (_) => OriginalMediaCacheRepository(
    clientProvider: () => NetworkRepository.client,
    cacheDirectory: () async => Directory(p.join((await getTemporaryDirectory()).path, 'original-media')),
  ),
);

final originalMediaCacheFileProvider = FutureProvider.autoDispose.family<File?, OriginalMediaCacheRequest>(
  (ref, request) => ref.watch(originalMediaCacheRepositoryProvider).get(request.asset, request.type),
);

final originalMediaRemoteSizeProvider = FutureProvider.autoDispose.family<int?, OriginalMediaCacheRequest>(
  (ref, request) => ref.watch(originalMediaCacheRepositoryProvider).getRemoteSize(request.asset, request.type),
);

class OriginalMediaCacheRepository {
  static const maxCacheBytes = 1024 * 1024 * 1024;

  final http.Client Function() _clientProvider;
  final Future<Directory> Function() _cacheDirectory;
  final String Function() _serverEndpoint;
  final Map<String, String> Function() _requestHeaders;
  final Map<String, Future<File>> _inFlight = {};
  final Map<String, Completer<void>> _abortTriggers = {};
  final Map<String, Set<void Function(OriginalMediaDownloadProgress)>> _progressListeners = {};
  final Map<String, OriginalMediaDownloadProgress> _latestProgress = {};
  final int _maxCacheBytes;
  Future<void> _downloadQueue = Future.value();
  Future<void> _maintenance = Future.value();
  int _generation = 0;

  OriginalMediaCacheRepository({
    http.Client? client,
    http.Client Function()? clientProvider,
    required Future<Directory> Function() cacheDirectory,
    String Function()? serverEndpoint,
    Map<String, String> Function()? requestHeaders,
    int maxCacheSize = maxCacheBytes,
  }) : assert(client != null || clientProvider != null),
       _clientProvider = clientProvider ?? (() => client!),
       _cacheDirectory = cacheDirectory,
       _serverEndpoint = serverEndpoint ?? (() => Store.get(StoreKey.serverEndpoint)),
       _requestHeaders = requestHeaders ?? ApiService.getRequestHeaders,
       _maxCacheBytes = maxCacheSize;

  Future<File?> get(RemoteAsset asset, OriginalMediaType type) async {
    final file = await _fileFor(asset, type);
    return _runMaintenance(() async {
      try {
        if (!await file.exists()) {
          return null;
        }
        if (await file.length() == 0) {
          await file.delete();
          return null;
        }
        try {
          await file.setLastModified(DateTime.now());
        } on FileSystemException {
          // Cache reads should still succeed when the platform cannot update mtime.
        }
        return file;
      } on FileSystemException {
        return null;
      }
    });
  }

  Future<int?> getRemoteSize(RemoteAsset asset, OriginalMediaType type) async {
    final request = http.Request('GET', _urlFor(asset, type))
      ..headers.addAll(_requestHeaders())
      ..headers['Range'] = 'bytes=0-0'
      ..headers['Cache-Control'] = 'no-store';
    try {
      final response = await _clientProvider().send(request);
      final contentRange = response.headers['content-range'];
      final rangeSize = int.tryParse(RegExp(r'/(\d+)$').firstMatch(contentRange ?? '')?.group(1) ?? '');
      final responseSize = switch (response.statusCode) {
        206 => rangeSize,
        >= 200 && < 300 => response.contentLength,
        _ => null,
      };
      await response.stream.listen(null).cancel();
      if (responseSize == null || responseSize <= 0) {
        return null;
      }
      return responseSize;
    } catch (_) {
      return null;
    }
  }

  Future<File> getOrDownload(
    RemoteAsset asset,
    OriginalMediaType type, {
    void Function(OriginalMediaDownloadProgress progress)? onProgress,
  }) async {
    final generation = _generation;
    final cached = await get(asset, type);
    if (generation != _generation) {
      throw const OriginalMediaCacheClearedException();
    }
    if (cached != null) {
      if (!await cached.exists()) {
        throw const OriginalMediaCacheClearedException();
      }
      final size = await cached.length();
      onProgress?.call((downloadedBytes: size, totalBytes: size));
      return cached;
    }

    final target = await _fileFor(asset, type);
    final inFlight = _inFlight[target.path];
    if (inFlight != null) {
      _addProgressListener(target.path, onProgress);
      return inFlight;
    }

    _addProgressListener(target.path, onProgress);
    final download = _downloadQueue.then((_) => _downloadAndMaintain(asset, type, target, generation));
    _downloadQueue = download.then<void>((_) {}, onError: (_, __) {});
    _inFlight[target.path] = download;
    return download;
  }

  Future<File> _downloadAndMaintain(RemoteAsset asset, OriginalMediaType type, File target, int generation) async {
    File? downloaded;
    try {
      downloaded = await _download(asset, type, target, generation);
    } finally {
      final _ = _inFlight.remove(target.path);
      if (_inFlight.isEmpty) {
        await _prune(protectedPath: downloaded?.path);
      }
      _progressListeners.remove(target.path);
      _latestProgress.remove(target.path);
    }
    if (generation != _generation || !await downloaded.exists()) {
      throw const OriginalMediaCacheClearedException();
    }
    return downloaded;
  }

  Future<int> clear() async {
    _generation++;
    for (final abortTrigger in _abortTriggers.values) {
      if (!abortTrigger.isCompleted) {
        abortTrigger.complete();
      }
    }
    return _runMaintenance(() async {
      final directory = await _cacheDirectory();
      if (!await directory.exists()) {
        return 0;
      }

      var bytes = 0;
      await for (final entity in directory.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          bytes += await entity.length();
        }
      }
      await directory.delete(recursive: true);
      return bytes;
    });
  }

  Future<File> _download(RemoteAsset asset, OriginalMediaType type, File target, int generation) async {
    if (generation != _generation) {
      throw const OriginalMediaCacheClearedException();
    }
    await target.parent.create(recursive: true);
    await _removeStalePartials(target.parent);
    final partial = File('${target.path}.part');
    if (await partial.exists()) {
      await partial.delete();
    }

    final url = _urlFor(asset, type);
    if (generation != _generation) {
      throw const OriginalMediaCacheClearedException();
    }
    final abortTrigger = Completer<void>();
    _abortTriggers[target.path] = abortTrigger;
    final request = http.AbortableRequest('GET', url, abortTrigger: abortTrigger.future)
      ..headers.addAll(_requestHeaders())
      ..headers['Cache-Control'] = 'no-store';

    try {
      final response = await _clientProvider().send(request);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        await response.stream.drain<void>();
        throw HttpException('HTTP ${response.statusCode} while caching original media', uri: request.url);
      }
      final contentLength = response.contentLength;
      if (contentLength != null && contentLength > _maxCacheBytes) {
        if (!abortTrigger.isCompleted) {
          abortTrigger.complete();
        }
        await response.stream.listen(null).cancel();
        throw OriginalMediaCacheLimitException(_maxCacheBytes);
      }
      _reportProgress(target.path, (downloadedBytes: 0, totalBytes: contentLength));
      await _prune(maxBytes: contentLength == null ? 0 : _maxCacheBytes - contentLength);
      if (generation != _generation) {
        throw const OriginalMediaCacheClearedException();
      }

      final output = partial.openWrite();
      var receivedBytes = 0;
      try {
        await for (final chunk in response.stream) {
          receivedBytes += chunk.length;
          if (receivedBytes > _maxCacheBytes) {
            throw OriginalMediaCacheLimitException(_maxCacheBytes);
          }
          output.add(chunk);
          _reportProgress(target.path, (downloadedBytes: receivedBytes, totalBytes: contentLength));
        }
        await output.flush();
      } finally {
        await output.close();
      }
      if (generation != _generation) {
        throw const OriginalMediaCacheClearedException();
      }
      if (receivedBytes == 0) {
        throw const FileSystemException('Downloaded original media is empty');
      }
      return await _runMaintenance(() async {
        if (generation != _generation) {
          throw const OriginalMediaCacheClearedException();
        }
        await target.parent.create(recursive: true);
        if (await target.exists()) {
          await target.delete();
        }
        final cached = await partial.rename(target.path);
        if (generation != _generation) {
          await cached.delete();
          throw const OriginalMediaCacheClearedException();
        }
        return cached;
      });
    } catch (_) {
      if (await partial.exists()) {
        await partial.delete();
      }
      if (generation != _generation) {
        throw const OriginalMediaCacheClearedException();
      }
      rethrow;
    } finally {
      _abortTriggers.remove(target.path);
    }
  }

  Uri _urlFor(RemoteAsset asset, OriginalMediaType type) {
    final endpoint = _serverEndpoint().replaceFirst(RegExp(r'/+$'), '');
    final assetId = type == OriginalMediaType.video ? asset.livePhotoVideoId ?? asset.id : asset.id;
    return Uri.parse('$endpoint/assets/$assetId/original?edited=${asset.isEdited}');
  }

  String cacheKey(RemoteAsset asset, OriginalMediaType type) {
    final targetId = type == OriginalMediaType.video ? asset.livePhotoVideoId ?? asset.id : asset.id;
    final identity = [
      _serverEndpoint(),
      asset.ownerId,
      asset.id,
      targetId,
      asset.checksum,
      asset.thumbHash,
      asset.updatedAt.toUtc().microsecondsSinceEpoch,
      asset.isEdited,
      type.name,
    ].join('|');
    return sha256.convert(utf8.encode(identity)).toString();
  }

  Future<File> _fileFor(RemoteAsset asset, OriginalMediaType type) async {
    final directory = await _cacheDirectory();
    final sourceName = type == OriginalMediaType.video && !asset.isVideo
        ? p.setExtension(asset.name, '.mov')
        : asset.name;
    final extension = _safeExtension(sourceName);
    return File(p.join(directory.path, '${cacheKey(asset, type)}$extension'));
  }

  String _safeExtension(String filename) {
    final extension = p.extension(filename).toLowerCase();
    if (extension.isEmpty || extension.length > 10 || !RegExp(r'^\.[a-z0-9]+$').hasMatch(extension)) {
      return '.bin';
    }
    return extension;
  }

  void _addProgressListener(String path, void Function(OriginalMediaDownloadProgress progress)? listener) {
    if (listener == null) {
      return;
    }
    _progressListeners.putIfAbsent(path, () => {}).add(listener);
    final latest = _latestProgress[path];
    if (latest != null) {
      listener(latest);
    }
  }

  void _reportProgress(String path, OriginalMediaDownloadProgress progress) {
    _latestProgress[path] = progress;
    for (final listener in _progressListeners[path]?.toList() ?? const []) {
      try {
        listener(progress);
      } catch (_) {
        // Progress listeners must not interrupt the download.
      }
    }
  }

  Future<void> _removeStalePartials(Directory directory) async {
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is! File || !entity.path.endsWith('.part')) {
        continue;
      }
      final targetPath = entity.path.substring(0, entity.path.length - '.part'.length);
      if (_abortTriggers.containsKey(targetPath)) {
        continue;
      }
      await entity.delete();
    }
  }

  Future<T> _runMaintenance<T>(Future<T> Function() operation) {
    final result = _maintenance.then((_) => operation());
    _maintenance = result.then<void>((_) {}, onError: (_, __) {});
    return result;
  }

  Future<void> _prune({String? protectedPath, int? maxBytes}) =>
      _runMaintenance(() => _pruneUnlocked(protectedPath: protectedPath, maxBytes: maxBytes ?? _maxCacheBytes));

  Future<void> _pruneUnlocked({required String? protectedPath, required int maxBytes}) async {
    final directory = await _cacheDirectory();
    if (!await directory.exists()) {
      return;
    }

    final entries = <({File file, FileStat stat})>[];
    var totalBytes = 0;
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is! File || entity.path.endsWith('.part')) {
        continue;
      }
      final stat = await entity.stat();
      totalBytes += stat.size;
      entries.add((file: entity, stat: stat));
    }
    if (totalBytes <= maxBytes) {
      return;
    }

    entries.sort((a, b) => a.stat.modified.compareTo(b.stat.modified));
    for (final entry in entries) {
      if (totalBytes <= maxBytes) {
        break;
      }
      if (entry.file.path == protectedPath) {
        continue;
      }
      if (_inFlight.containsKey(entry.file.path)) {
        continue;
      }
      await entry.file.delete();
      totalBytes -= entry.stat.size;
    }
  }
}
