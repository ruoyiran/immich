import Foundation

/// One attempt's protection. All calls are serialized on the main thread by the plugin.
final class BackgroundTaskSession {
  private let onExpired: () -> Void
  private let onFinished: () -> Void
  private var finished = false
  private var continuationRequested = false
  private var endFallback: (() -> Void)?
  private var cancelRequest: (() -> Void)?
  private var completeContinuation: ((Bool) -> Void)?
  private var progress: Progress?
  private var completed: Int64 = 0
  private var total: Int64 = 1

  var isActive: Bool { !finished && (endFallback != nil || completeContinuation != nil) }

  init(onExpired: @escaping () -> Void, onFinished: @escaping () -> Void) {
    self.onExpired = onExpired
    self.onFinished = onFinished
  }

  func trackFallback(end: @escaping () -> Void) {
    guard !finished else {
      end()
      return
    }
    endFallback = end
  }

  func trackRequest(cancel: @escaping () -> Void) {
    guard !finished else {
      cancel()
      return
    }
    cancelRequest = cancel
  }

  func requestContinuation(allowed: Bool, submit: () -> Void) {
    guard allowed && !finished && !continuationRequested else { return }
    continuationRequested = true
    submit()
  }

  func attachContinuation(progress: Progress, complete: @escaping (Bool) -> Void) {
    guard !finished else {
      complete(false)
      return
    }
    cancelRequest = nil
    self.progress = progress
    completeContinuation = complete
    updateProgress(completed: completed, total: total)
    // Clear before releasing: an already enqueued UIKit expiration must not expire the new task.
    let end = endFallback
    endFallback = nil
    end?()
  }

  func updateProgress(completed: Int64, total: Int64) {
    guard !finished else { return }
    self.completed = max(0, completed)
    self.total = total < 0 ? -1 : max(1, total, self.completed)
    progress?.totalUnitCount = self.total
    progress?.completedUnitCount = self.completed
  }

  func expireFallback() {
    guard endFallback != nil else { return }
    expire()
  }

  func expire() {
    guard !finished else { return }
    finished = true
    // Sending the Dart cancellation does not wait for its reply before releasing OS protection.
    onExpired()
    release(success: false)
  }

  func finish(success: Bool) {
    guard !finished else { return }
    finished = true
    release(success: success)
  }

  private func release(success: Bool) {
    cancelRequest?()
    cancelRequest = nil
    let end = endFallback
    endFallback = nil
    end?()
    completeContinuation?(success)
    completeContinuation = nil
    progress = nil
    onFinished()
  }
}
