import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:immich_mobile/utils/cancellation.dart';
import 'package:openapi/api.dart';
import 'package:worker_manager/worker_manager.dart';

void main() {
  test('recognizes explicit HTTP and worker cancellation', () {
    expect(isCancellationError(RequestAbortedException(Uri.parse('http://sync.invalid'))), isTrue);
    expect(isCancellationError(CanceledError()), isTrue);
  });

  test('recognizes an aborted request wrapped by the generated API client', () {
    final aborted = RequestAbortedException(Uri.parse('http://sync.invalid'));
    expect(isCancellationError(ApiException.withInner(400, 'HTTP failed', aborted, StackTrace.current)), isTrue);
  });

  test('does not classify network, server, or database failures as cancellation', () {
    expect(isCancellationError(ClientException('connection lost')), isFalse);
    expect(isCancellationError(ApiException(401, 'unauthorized')), isFalse);
    expect(isCancellationError(StateError('database failure')), isFalse);
    expect(
      isCancellationError(ApiException.withInner(400, 'HTTP failed', ClientException('offline'), StackTrace.current)),
      isFalse,
    );
  });
}
