import 'package:pigeon/pigeon.dart';

enum BackgroundTaskMode { limited, continued }

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/platform/background_task_api.g.dart',
    swiftOut: 'ios/Runner/Background/BackgroundTask.g.swift',
    swiftOptions: SwiftOptions(includeErrorClass: false),
    kotlinOut: 'android/app/src/main/kotlin/app/alextran/immich/background/BackgroundTask.g.kt',
    kotlinOptions: KotlinOptions(package: 'app.alextran.immich.background', includeErrorClass: false),
    dartPackageName: 'immich_mobile',
  ),
)
@HostApi()
abstract class BackgroundTaskHostApi {
  @async
  bool start(String taskId, String title, String description, BackgroundTaskMode mode);

  void updateProgress(String taskId, int completed, int total);

  bool isActive(String taskId);

  void finish(String taskId);
}

@FlutterApi()
abstract class BackgroundTaskFlutterApi {
  @async
  void onExpired(String taskId);
}
