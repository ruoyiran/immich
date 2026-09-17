import 'package:http/http.dart';
import 'package:openapi/api.dart';
import 'package:worker_manager/worker_manager.dart';

bool isCancellationError(Object error) {
  if (error is ApiException) {
    final inner = error.innerException;
    return inner != null && isCancellationError(inner);
  }
  return error is RequestAbortedException || error is CanceledError;
}
