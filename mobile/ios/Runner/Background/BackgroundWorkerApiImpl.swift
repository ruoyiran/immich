import BackgroundTasks

class BackgroundWorkerApiImpl: BackgroundWorkerFgHostApi {
  func enable() throws {
    try disable()
  }

  func configure(settings: BackgroundWorkerSettings) throws {
    try disable()
  }

  func saveNotificationMessage(title: String, body: String) throws {
    // Android only.
  }

  func disable() throws {
    BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: BackgroundWorkerApiImpl.refreshTaskID)
    BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: BackgroundWorkerApiImpl.processingTaskID)
    print("BackgroundWorkerApiImpl:disable Automatic backup is disabled")
  }

  private static let refreshTaskID = "app.alextran.immich.background.refreshUpload"
  private static let processingTaskID = "app.alextran.immich.background.processingUpload"

  public static func registerBackgroundWorkers() {
    BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: refreshTaskID)
    BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: processingTaskID)

    BGTaskScheduler.shared.register(forTaskWithIdentifier: processingTaskID, using: nil) { task in
      task.setTaskCompleted(success: true)
    }

    BGTaskScheduler.shared.register(forTaskWithIdentifier: refreshTaskID, using: nil) { task in
      task.setTaskCompleted(success: true)
    }
  }
}
