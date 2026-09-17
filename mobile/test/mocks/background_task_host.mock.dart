import 'dart:async';

import 'package:immich_mobile/platform/background_task_api.g.dart';

class FakeBackgroundTaskHost extends BackgroundTaskHostApi {
  final active = <String>{};
  final finished = <String>[];
  final modes = <BackgroundTaskMode>[];
  bool grant = true;
  Completer<bool>? startResult;
  Completer<bool>? activityResult;

  @override
  Future<bool> start(String taskId, String title, String description, BackgroundTaskMode mode) async {
    modes.add(mode);
    final granted = await (startResult?.future ?? Future.value(grant));
    if (granted) {
      active.add(taskId);
    }
    return granted;
  }

  @override
  Future<bool> isActive(String taskId) async => activityResult?.future ?? active.contains(taskId);

  @override
  Future<void> finish(String taskId) async {
    active.remove(taskId);
    finished.add(taskId);
  }

  @override
  Future<void> updateProgress(String taskId, int completed, int total) async {}
}
