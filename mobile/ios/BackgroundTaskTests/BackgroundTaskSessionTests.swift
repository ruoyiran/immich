import Foundation
import XCTest

@testable import BackgroundTaskCore

final class BackgroundTaskSessionTests: XCTestCase {
  func testAutomaticTasksNeverSubmitAContinuation() {
    let session = BackgroundTaskSession(onExpired: {}, onFinished: {})
    var submissions = 0
    session.requestContinuation(allowed: false) { submissions += 1 }
    XCTAssertEqual(submissions, 0)
  }

  func testManualPromotionSubmitsOnceWithoutReleasingProtection() {
    let session = BackgroundTaskSession(onExpired: {}, onFinished: {})
    var submissions = 0
    var leaseEnds = 0
    session.trackFallback { leaseEnds += 1 }
    session.requestContinuation(allowed: false) { submissions += 1 }
    session.requestContinuation(allowed: true) { submissions += 1 }
    session.requestContinuation(allowed: true) { submissions += 1 }
    XCTAssertEqual(submissions, 1)
    XCTAssertEqual(leaseEnds, 0)
    XCTAssertTrue(session.isActive)
  }

  func testFinishedTasksCannotBePromoted() {
    let session = BackgroundTaskSession(onExpired: {}, onFinished: {})
    var submissions = 0
    session.finish(success: true)
    session.requestContinuation(allowed: true) { submissions += 1 }
    XCTAssertEqual(submissions, 0)
  }

  func testUnknownTotalPreservesActualWorkWithoutInventingAPercentage() {
    let session = BackgroundTaskSession(onExpired: {}, onFinished: {})
    let progress = Progress(totalUnitCount: 1)
    session.attachContinuation(progress: progress, complete: { _ in })
    session.updateProgress(completed: 256, total: -1)
    XCTAssertTrue(progress.isIndeterminate)
    XCTAssertEqual(progress.completedUnitCount, 256)
    session.updateProgress(completed: 512, total: -1)
    XCTAssertTrue(progress.isIndeterminate)
    XCTAssertEqual(progress.completedUnitCount, 512)
  }

  func testPendingRequestDoesNotClaimProtectionWithoutAnActualLease() {
    let session = BackgroundTaskSession(onExpired: {}, onFinished: {})
    session.trackRequest(cancel: {})
    XCTAssertFalse(session.isActive)
    session.trackFallback(end: {})
    XCTAssertTrue(session.isActive)
  }

  func testContinuationHandoffPreservesProgressAndIgnoresOldLeaseExpiration() {
    var leaseEnds = 0
    var expirations = 0
    var requestCancellations = 0
    var completions: [Bool] = []
    let session = BackgroundTaskSession(onExpired: { expirations += 1 }, onFinished: {})
    session.trackFallback { leaseEnds += 1 }
    session.trackRequest { requestCancellations += 1 }
    session.updateProgress(completed: 31, total: 100)
    let progress = Progress(totalUnitCount: 1)
    session.attachContinuation(progress: progress) { completions.append($0) }

    XCTAssertEqual(leaseEnds, 1)
    XCTAssertEqual(progress.completedUnitCount, 31)
    XCTAssertEqual(progress.totalUnitCount, 100)
    session.expireFallback()
    XCTAssertTrue(session.isActive)
    XCTAssertEqual(expirations, 0)
    XCTAssertTrue(completions.isEmpty)

    session.finish(success: true)
    session.finish(success: true)
    XCTAssertEqual(completions, [true])
    XCTAssertEqual(requestCancellations, 0)
    XCTAssertFalse(session.isActive)
  }

  func testContinuedTaskExpirationFailsOnceAndStopsUpdatingReleasedProgress() {
    var expirations = 0
    var completions: [Bool] = []
    let session = BackgroundTaskSession(onExpired: { expirations += 1 }, onFinished: {})
    let progress = Progress(totalUnitCount: 1)
    session.attachContinuation(progress: progress) { completions.append($0) }
    session.updateProgress(completed: 20, total: 100)
    session.expire()
    session.expire()
    session.updateProgress(completed: 80, total: 100)
    session.finish(success: true)

    XCTAssertEqual(expirations, 1)
    XCTAssertEqual(completions, [false])
    XCTAssertEqual(progress.completedUnitCount, 20)
    XCTAssertFalse(session.isActive)
  }

  func testExpirationNotifiesBeforeReleasingProtectionAndCancelsPendingRequest() {
    var events: [String] = []
    let session = BackgroundTaskSession(
      onExpired: { events.append("expired") }, onFinished: { events.append("finished") }
    )
    session.trackFallback { events.append("lease-ended") }
    session.trackRequest { events.append("request-cancelled") }
    session.expireFallback()
    session.expire()

    XCTAssertEqual(events, ["expired", "request-cancelled", "lease-ended", "finished"])
    XCTAssertFalse(session.isActive)
  }

  func testLateLaunchAfterFinishIsCompletedUnsuccessfully() {
    var cancellations = 0
    var completions: [Bool] = []
    let session = BackgroundTaskSession(onExpired: {}, onFinished: {})
    session.trackFallback(end: {})
    session.trackRequest { cancellations += 1 }
    session.finish(success: true)
    session.attachContinuation(progress: Progress(totalUnitCount: 1)) { completions.append($0) }

    XCTAssertEqual(cancellations, 1)
    XCTAssertEqual(completions, [false])
    XCTAssertFalse(session.isActive)
  }

  func testExpiredSessionCannotReleaseAnotherConcurrentSessionsProtection() {
    var firstEnds = 0
    var secondEnds = 0
    let first = BackgroundTaskSession(onExpired: {}, onFinished: {})
    let second = BackgroundTaskSession(onExpired: {}, onFinished: {})
    first.trackFallback { firstEnds += 1 }
    second.trackFallback { secondEnds += 1 }
    first.expire()
    first.finish(success: true)

    XCTAssertEqual(firstEnds, 1)
    XCTAssertEqual(secondEnds, 0)
    XCTAssertTrue(second.isActive)
    second.finish(success: false)
  }

  func testUnknownAndInvalidProgressCannotExceedItsTotal() {
    let session = BackgroundTaskSession(onExpired: {}, onFinished: {})
    let progress = Progress(totalUnitCount: 1)
    session.attachContinuation(progress: progress, complete: { _ in })
    session.updateProgress(completed: -3, total: 0)
    XCTAssertEqual(progress.completedUnitCount, 0)
    XCTAssertEqual(progress.totalUnitCount, 1)
    session.updateProgress(completed: 75, total: 50)
    XCTAssertEqual(progress.completedUnitCount, 75)
    XCTAssertEqual(progress.totalUnitCount, 75)
  }
}
