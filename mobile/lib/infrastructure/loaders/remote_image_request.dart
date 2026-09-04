part of 'image_request.dart';

class RemoteImageRequest extends ImageRequest {
  static final _scheduler = RemoteImageRequestScheduler();

  final String uri;

  /// Physical size to decode, or null for the source size.
  final ui.Size? decodeSize;
  final RemoteImageRequestPriority? queuePriority;
  final DateTime? enqueuedAt;

  ScheduledRemoteImageRequest<Map<String, int>?>? _scheduledRequest;

  RemoteImageRequest({required this.uri, this.decodeSize, this.queuePriority, this.enqueuedAt});

  Future<Map<String, int>?> _requestImage({
    required bool preferEncoded,
    required int? width,
    required int? height,
  }) async {
    Future<Map<String, int>?> operation() => remoteImageApi.requestImage(
      uri,
      requestId: requestId,
      preferEncoded: preferEncoded,
      width: width,
      height: height,
    );

    final priority = queuePriority;
    if (priority == null) {
      return operation();
    }
    final scheduled = _scheduledRequest = _scheduler.schedule(
      priority: priority,
      operation: operation,
      enqueuedAt: enqueuedAt,
    );
    try {
      return await scheduled.value;
    } finally {
      if (_scheduledRequest == scheduled) {
        _scheduledRequest = null;
      }
    }
  }

  @override
  Future<ImageInfo?> load(ImageDecoderCallback decode, {double scale = 1.0}) async {
    if (_isCancelled) {
      return null;
    }

    final info = await _requestImage(
      preferEncoded: false,
      width: decodeSize?.width.ceil(),
      height: decodeSize?.height.ceil(),
    );
    // Android falls back to encoded data if native decoding fails, so check for both shapes of the response.
    final frame = switch (info) {
      {'pointer': final int pointer, 'length': final int length} => await _fromEncodedPlatformImage(
        pointer,
        length,
        decodeSize: decodeSize,
      ),
      {
        'pointer': final int pointer,
        'width': final int width,
        'height': final int height,
        'rowBytes': final int rowBytes,
      } =>
        await _fromDecodedPlatformImage(pointer, width, height, rowBytes),
      _ => null,
    };
    return frame == null ? null : ImageInfo(image: frame.image, scale: scale);
  }

  @override
  Future<ui.Codec?> loadCodec() async {
    if (_isCancelled) {
      return null;
    }

    final info = await _requestImage(preferEncoded: true, width: null, height: null);
    if (info == null) {
      return null;
    }

    final (codec, _) = await _codecFromEncodedPlatformImage(info['pointer']!, info['length']!) ?? (null, null);
    return codec;
  }

  @override
  Future<void> _onCancelled() {
    _scheduledRequest?.cancel();
    return remoteImageApi.cancelRequest(requestId);
  }
}
