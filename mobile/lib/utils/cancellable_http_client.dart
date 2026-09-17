import 'package:http/http.dart' as http;

/// Adds cancellation to one API session without taking ownership of its client.
class CancellableHttpClient extends http.BaseClient {
  final http.Client _inner;
  final Future<void> _cancellation;

  CancellableHttpClient(this._inner, this._cancellation);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    final requestCancellation = request is http.Abortable ? request.abortTrigger : null;
    final cancellation = requestCancellation == null
        ? _cancellation
        : Future.any<void>([_cancellation, requestCancellation]);
    return _inner.send(_CancellableRequest(request, cancellation));
  }

  // NetworkRepository owns the shared native client. Closing one API session
  // must not interrupt another session's upload or foreground request.
  @override
  void close() {}
}

class _CancellableRequest extends http.BaseRequest with http.Abortable {
  final http.BaseRequest _request;

  @override
  final Future<void> abortTrigger;

  _CancellableRequest(this._request, this.abortTrigger) : super(_request.method, _request.url) {
    followRedirects = _request.followRedirects;
    maxRedirects = _request.maxRedirects;
    persistentConnection = _request.persistentConnection;
    contentLength = _request.contentLength;
    headers.addAll(_request.headers);
  }

  @override
  http.ByteStream finalize() {
    final body = _request.finalize();
    // MultipartRequest chooses its boundary and content type when finalized.
    // Forward the resulting headers and stream without buffering or re-encoding.
    headers
      ..clear()
      ..addAll(_request.headers);
    contentLength = _request.contentLength;
    super.finalize();
    return body;
  }
}
