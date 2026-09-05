import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:immich_mobile/domain/models/asset/base_asset.model.dart';
import 'package:immich_mobile/infrastructure/loaders/image_request.dart';
import 'package:immich_mobile/infrastructure/loaders/remote_image_request_scheduler.dart';
import 'package:immich_mobile/infrastructure/repositories/settings.repository.dart';
import 'package:immich_mobile/presentation/widgets/images/animated_image_stream_completer.dart';
import 'package:immich_mobile/presentation/widgets/images/image_provider.dart';
import 'package:immich_mobile/presentation/widgets/images/one_frame_multi_image_stream_completer.dart';
import 'package:immich_mobile/utils/image_url_builder.dart';
import 'package:openapi/api.dart';

class RemoteImageProvider extends CancellableImageProvider<RemoteImageProvider>
    with CancellableImageProviderMixin<RemoteImageProvider> {
  static const _retryDelays = [
    Duration(milliseconds: 500),
    Duration(seconds: 1),
    Duration(seconds: 2),
    Duration(seconds: 4),
    Duration(seconds: 8),
    Duration(seconds: 16),
    Duration(seconds: 32),
  ];

  final String url;
  final bool edited;
  final bool retryTransientErrors;

  /// Physical size to decode, or null for the source size.
  final Size? decodeSize;

  RemoteImageProvider({required this.url, this.edited = true, this.retryTransientErrors = false, this.decodeSize});

  RemoteImageProvider.thumbnail({
    required String assetId,
    required String? thumbhash,
    this.edited = true,
    this.decodeSize,
  }) : url = getThumbnailUrlForRemoteId(assetId, thumbhash: thumbhash, edited: edited),
       retryTransientErrors = true;

  @override
  Future<RemoteImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture(this);
  }

  @override
  ImageStreamCompleter loadImage(RemoteImageProvider key, ImageDecoderCallback decode) {
    return OneFramePlaceholderImageStreamCompleter(
      _codec(key, decode),
      informationCollector: () => <DiagnosticsNode>[
        DiagnosticsProperty<ImageProvider>('Image provider', this),
        DiagnosticsProperty<String>('URL', key.url),
      ],
      onLastListenerRemoved: cancel,
    );
  }

  Stream<ImageInfo> _codec(RemoteImageProvider key, ImageDecoderCallback decode) {
    if (!key.retryTransientErrors) {
      final request = this.request = RemoteImageRequest(uri: key.url, decodeSize: key.decodeSize);
      return loadRequest(request, decode, isFinal: true);
    }
    return _loadThumbnailWithRetry(key, decode);
  }

  Stream<ImageInfo> _loadThumbnailWithRetry(RemoteImageProvider key, ImageDecoderCallback decode) async* {
    final retryBudget = RemoteImageRetryBudget(_retryDelays);
    var enqueuedAt = DateTime.now();
    while (true) {
      if (isCancelled) {
        request = null;
        return;
      }

      final currentRequest = request = RemoteImageRequest(
        uri: key.url,
        decodeSize: key.decodeSize,
        queuePriority: retryBudget.priority,
        enqueuedAt: enqueuedAt,
      );
      try {
        final image = await currentRequest.load(decode);
        if (isCancelled || image == null) {
          image?.dispose();
          return;
        }
        isFinished = true;
        yield image;
        return;
      } catch (error, stackTrace) {
        if (isCancelled) {
          return;
        }
        PaintingBinding.instance.imageCache.evict(this);
        if (error is RemoteImageRequestDeferredException) {
          if (request == currentRequest) {
            request = null;
          }
          await Future<void>.delayed(retryBudget.deferralDelay);
          continue;
        }
        final retryDelay = retryBudget.nextFailureDelay(retryable: _isRetriableThumbnailError(error));
        if (retryDelay == null) {
          isFinished = true;
          Error.throwWithStackTrace(error, stackTrace);
        }
        if (request == currentRequest) {
          request = null;
        }
        await Future<void>.delayed(retryDelay);
        enqueuedAt = DateTime.now();
      } finally {
        if (request == currentRequest) {
          request = null;
        }
      }
    }
  }

  bool _isRetriableThumbnailError(Object error) {
    final message = switch (error) {
      PlatformException(:final code, :final message) => '$code ${message ?? ''}',
      _ => error.toString(),
    };
    if (error is RemoteImageRequestDeferredException) {
      return true;
    }
    final status = int.tryParse(RegExp(r'HTTP (\d{3})').firstMatch(message)?.group(1) ?? '');
    if (status != null) {
      return status == 404 || status == 408 || status == 429 || status >= 500 && status <= 504;
    }
    final normalized = message.toLowerCase();
    return normalized.contains('not found') ||
        normalized.contains('socketexception') ||
        normalized.contains('connection reset') ||
        normalized.contains('connection abort') ||
        normalized.contains('timed out');
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is RemoteImageProvider) {
      return url == other.url &&
          edited == other.edited &&
          retryTransientErrors == other.retryTransientErrors &&
          decodeSize == other.decodeSize;
    }
    return false;
  }

  @override
  int get hashCode => url.hashCode ^ edited.hashCode ^ retryTransientErrors.hashCode ^ decodeSize.hashCode;
}

class RemoteFullImageProvider extends CancellableImageProvider<RemoteFullImageProvider>
    with CancellableImageProviderMixin<RemoteFullImageProvider> {
  final String assetId;
  final String thumbhash;
  final AssetType assetType;
  final bool isAnimated;
  final bool edited;
  final bool forceOriginal;

  /// Physical size of the thumbnail shown before the preview.
  final Size? thumbnailSize;

  RemoteFullImageProvider({
    required this.assetId,
    required this.thumbhash,
    required this.assetType,
    required this.isAnimated,
    this.edited = true,
    this.thumbnailSize,
    this.forceOriginal = false,
  });

  @override
  Future<RemoteFullImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture(this);
  }

  @override
  ImageStreamCompleter loadImage(RemoteFullImageProvider key, ImageDecoderCallback decode) {
    if (key.isAnimated) {
      return AnimatedImageStreamCompleter(
        stream: _animatedCodec(key, decode),
        scale: 1.0,
        initialImage: getInitialImage(
          RemoteImageProvider.thumbnail(assetId: key.assetId, thumbhash: key.thumbhash, decodeSize: key.thumbnailSize),
        ),
        informationCollector: () => <DiagnosticsNode>[
          DiagnosticsProperty<ImageProvider>('Image provider', this),
          DiagnosticsProperty<String>('Asset Id', key.assetId),
          DiagnosticsProperty<bool>('isAnimated', key.isAnimated),
        ],
        onLastListenerRemoved: cancel,
      );
    }

    return OneFramePlaceholderImageStreamCompleter(
      _codec(key, decode),
      initialImage: getInitialImage(
        RemoteImageProvider.thumbnail(
          assetId: key.assetId,
          thumbhash: key.thumbhash,
          edited: key.edited,
          decodeSize: key.thumbnailSize,
        ),
      ),
      informationCollector: () => <DiagnosticsNode>[
        DiagnosticsProperty<ImageProvider>('Image provider', this),
        DiagnosticsProperty<String>('Asset Id', key.assetId),
        DiagnosticsProperty<bool>('isAnimated', key.isAnimated),
      ],
      onLastListenerRemoved: cancel,
    );
  }

  Stream<ImageInfo> _codec(RemoteFullImageProvider key, ImageDecoderCallback decode) async* {
    yield* initialImageStream();

    if (isCancelled) {
      return;
    }

    final previewRequest = request = RemoteImageRequest(
      uri: getThumbnailUrlForRemoteId(
        key.assetId,
        type: AssetMediaSize.preview,
        thumbhash: key.thumbhash,
        edited: key.edited,
      ),
    );
    final loadOriginal =
        assetType == AssetType.image && (key.forceOriginal || SettingsRepository.instance.appConfig.image.loadOriginal);
    yield* loadRequest(previewRequest, decode, isFinal: !loadOriginal);

    if (!loadOriginal) {
      return;
    }

    if (isCancelled) {
      return;
    }

    final originalRequest = request = RemoteImageRequest(
      uri: getOriginalUrlForRemoteId(key.assetId, edited: key.edited),
    );
    yield* loadRequest(originalRequest, decode, isFinal: true);
  }

  Stream<Object> _animatedCodec(RemoteFullImageProvider key, ImageDecoderCallback decode) async* {
    yield* initialImageStream();

    if (isCancelled) {
      return;
    }

    final previewRequest = request = RemoteImageRequest(
      uri: getThumbnailUrlForRemoteId(
        key.assetId,
        type: AssetMediaSize.preview,
        thumbhash: key.thumbhash,
        edited: key.edited,
      ),
    );
    yield* loadRequest(previewRequest, decode, isFinal: false);

    if (isCancelled) {
      return;
    }

    // always try original for animated, since previews don't support animation
    final originalRequest = request = RemoteImageRequest(
      uri: getOriginalUrlForRemoteId(key.assetId, edited: key.edited),
    );
    final codec = await loadCodecRequest(originalRequest, isFinal: true);
    if (codec == null) {
      if (isCancelled) {
        return;
      }
      throw StateError('Failed to load animated codec for asset ${key.assetId}');
    }
    yield codec;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is RemoteFullImageProvider) {
      return assetId == other.assetId &&
          thumbhash == other.thumbhash &&
          isAnimated == other.isAnimated &&
          edited == other.edited &&
          forceOriginal == other.forceOriginal;
    }

    return false;
  }

  @override
  int get hashCode => Object.hash(assetId, thumbhash, isAnimated, edited, forceOriginal);
}
