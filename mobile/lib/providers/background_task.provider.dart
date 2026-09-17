import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/domain/services/background_task.service.dart';
import 'package:immich_mobile/platform/background_task_api.g.dart';

final backgroundTaskServiceProvider = Provider((ref) {
  final service = BackgroundTaskService(BackgroundTaskHostApi());
  ref.onDispose(service.dispose);
  return service;
});
