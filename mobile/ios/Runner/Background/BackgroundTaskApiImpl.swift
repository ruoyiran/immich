import BackgroundTasks
import Flutter
import UIKit

/// Protects work already running in the owning Flutter engine; never launches automatic backup.
final class BackgroundTaskApiImpl: NSObject, FlutterPlugin, BackgroundTaskHostApi {
  static let name = "BackgroundTaskApi"

  private static var continuedTaskPrefix: String {
    "\(Bundle.main.bundleIdentifier!).background.continued."
  }

  private let messenger: FlutterBinaryMessenger
  private var flutterApi: BackgroundTaskFlutterApi?
  private var sessions: [String: BackgroundTaskSession] = [:]
  private var detached = false

  private init(messenger: FlutterBinaryMessenger) {
    self.messenger = messenger
    flutterApi = BackgroundTaskFlutterApi(binaryMessenger: messenger)
  }

  static func register(with registrar: FlutterPluginRegistrar) {
    let instance = BackgroundTaskApiImpl(messenger: registrar.messenger())
    BackgroundTaskHostApiSetup.setUp(binaryMessenger: registrar.messenger(), api: instance)
    registrar.publish(instance)
  }

  func start(
    taskId: String, title: String, description: String, mode: BackgroundTaskMode,
    completion: @escaping (Result<Bool, Error>) -> Void
  ) {
    guard !detached else {
      completion(.success(false))
      return
    }
    if let session = sessions[taskId] {
      requestContinuation(for: session, mode: mode, title: title, subtitle: description)
      completion(.success(session.isActive))
      return
    }
    // Continued processing requests must originate from foreground work. Dart retries an
    // unprotected attempt on the next foreground transition instead of scheduling new work here.
    guard UIApplication.shared.applicationState == .active else {
      completion(.success(false))
      return
    }

    let session = BackgroundTaskSession(
      onExpired: { [weak self] in
        self?.flutterApi?.onExpired(taskId: taskId) { _ in }
      },
      onFinished: { [weak self] in
        self?.sessions.removeValue(forKey: taskId)
      }
    )
    sessions[taskId] = session
    let lease = UIApplication.shared.beginBackgroundTask(withName: title) { [weak session] in
      Self.onMain { session?.expireFallback() }
    }
    guard lease != .invalid else {
      session.finish(success: false)
      completion(.success(false))
      return
    }
    session.trackFallback { UIApplication.shared.endBackgroundTask(lease) }

    requestContinuation(for: session, mode: mode, title: title, subtitle: description)
    // A valid UIKit lease already protects the attempt while the continued task is launching.
    completion(.success(session.isActive))
  }

  @available(iOS 26.0, *)
  private func submitContinuation(
    for session: BackgroundTaskSession, title: String, subtitle: String
  ) {
    let identifier = Self.continuedTaskPrefix + UUID().uuidString
    let request = BGContinuedProcessingTaskRequest(
      identifier: identifier, title: title, subtitle: subtitle)
    // The plist permits a wildcard, but the scheduler registers a concrete request identifier.
    // Continued-processing handlers may register after app launch. There is no unregister API;
    // weak capture prevents the scheduler's retained handler from retaining an engine or session.
    let registered = BGTaskScheduler.shared.register(
      forTaskWithIdentifier: identifier, using: .main
    ) { [weak session] task in
      guard let session, let continuedTask = task as? BGContinuedProcessingTask else {
        task.setTaskCompleted(success: false)
        return
      }
      continuedTask.expirationHandler = { [weak session] in
        Self.onMain { session?.expire() }
      }
      session.attachContinuation(progress: continuedTask.progress) { success in
        continuedTask.expirationHandler = nil
        continuedTask.setTaskCompleted(success: success)
      }
      NSLog("BackgroundTaskApi: continued processing launched: %@", identifier)
    }
    guard registered else {
      NSLog("BackgroundTaskApi: continued processing registration rejected: %@", identifier)
      return
    }
    // The Dart operation is already running. A queued future launch would be unrelated to it.
    request.strategy = .fail
    session.trackRequest {
      BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: identifier)
    }
    do {
      try BGTaskScheduler.shared.submit(request)
    } catch {
      // Keep the UIKit lease on older/unsupported devices or if system conditions deny continuation.
      NSLog("BackgroundTaskApi: continued processing unavailable: %@", String(describing: error))
    }
  }

  private func requestContinuation(
    for session: BackgroundTaskSession, mode: BackgroundTaskMode, title: String, subtitle: String
  ) {
    if #available(iOS 26.0, *) {
      session.requestContinuation(allowed: mode == .continued) {
        submitContinuation(for: session, title: title, subtitle: subtitle)
      }
    }
  }

  func updateProgress(taskId: String, completed: Int64, total: Int64) throws {
    sessions[taskId]?.updateProgress(completed: completed, total: total)
  }

  func isActive(taskId: String) throws -> Bool {
    sessions[taskId]?.isActive ?? false
  }

  func finish(taskId: String) throws {
    sessions[taskId]?.finish(success: true)
  }

  func detachFromEngine(for registrar: FlutterPluginRegistrar) {
    detachFromEngine()
  }

  func detachFromEngine() {
    guard !detached else { return }
    detached = true
    BackgroundTaskHostApiSetup.setUp(binaryMessenger: messenger, api: nil)
    flutterApi = nil
    for session in Array(sessions.values) {
      session.finish(success: false)
    }
    sessions.removeAll()
  }

  private static func onMain(_ action: @escaping () -> Void) {
    if Thread.isMainThread {
      action()
    } else {
      DispatchQueue.main.async(execute: action)
    }
  }
}
