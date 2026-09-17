import 'dart:async';

import 'package:immich_mobile/platform/background_task_api.g.dart';

class RecordingBackgroundTaskHost extends BackgroundTaskHostApi {
  final modes = <BackgroundTaskMode>[];
  final continuedStarted = Completer<void>();

  @override
  Future<bool> start(String taskId, String title, String description, BackgroundTaskMode mode) async {
    modes.add(mode);
    final granted = await super.start(taskId, title, description, mode);
    if (granted && mode == BackgroundTaskMode.continued && !continuedStarted.isCompleted) {
      continuedStarted.complete();
    }
    return granted;
  }
}
