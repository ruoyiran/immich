package app.alextran.immich.background

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class BackgroundTaskManagerTest {
  private val owner = Any()
  private var startAllowed = true
  private var expireStart: (() -> Unit)? = null
  private val results = mutableListOf<Boolean>()
  private val expired = mutableListOf<String>()
  private val manager = BackgroundTaskManager(
    startService = { startAllowed },
    stopPendingService = {},
    scheduleStartTimeout = { timeout ->
      expireStart = timeout
      { expireStart = null }
    },
  )
  private val service = TestService()

  @Test
  fun startConfirmsOnlyAfterForegroundPromotion() {
    start("sync")
    assertTrue(results.isEmpty())
    assertFalse(manager.isActive(owner, "sync"))

    manager.onServiceStarted(service)

    assertEquals(listOf(true), results)
    assertTrue(manager.isActive(owner, "sync"))
  }

  @Test
  fun rejectedStartDoesNotLeaveAnActiveTask() {
    startAllowed = false
    start("sync")

    assertEquals(listOf(false), results)
    assertFalse(manager.isActive(owner, "sync"))
    assertTrue(manager.tasks.isEmpty())
  }

  @Test
  fun missingServiceAcknowledgmentCompletesStartWithFalse() {
    start("sync")
    expireStart!!.invoke()

    assertEquals(listOf(false), results)
    assertTrue(manager.tasks.isEmpty())
    manager.onServiceStarted(service)
    assertTrue(service.stopped)
  }

  @Test
  fun finishingSyncKeepsConcurrentUploadProtected() {
    start("sync")
    manager.onServiceStarted(service)
    start("upload")

    manager.finish(owner, "sync")

    assertFalse(manager.isActive(owner, "sync"))
    assertTrue(manager.isActive(owner, "upload"))
    assertFalse(service.stopped)
    manager.finish(owner, "upload")
    assertTrue(service.stopped)
  }

  @Test
  fun engineDetachCannotReleaseAnotherEnginesTaskWithSameId() {
    val otherOwner = Any()
    start("sync")
    manager.onServiceStarted(service)
    manager.start(otherOwner, "sync", "Sync", "Metadata", {}, {})

    manager.finishOwner(owner)

    assertFalse(manager.isActive(owner, "sync"))
    assertTrue(manager.isActive(otherOwner, "sync"))
    assertFalse(service.stopped)
  }

  @Test
  fun detachBeforeServiceStartsCompletesPendingCall() {
    start("sync")
    manager.finishOwner(owner)

    assertEquals(listOf(false), results)
    assertTrue(manager.tasks.isEmpty())
  }

  @Test
  fun expirationStopsProtectionBeforeNotifyingEveryTask() {
    start("sync")
    start("upload")
    manager.onServiceStarted(service)

    manager.onServiceExpired(service)

    assertEquals(listOf("sync", "upload"), expired)
    assertTrue(service.stopped)
    assertFalse(manager.isActive(owner, "sync"))
    assertFalse(manager.isActive(owner, "upload"))
  }

  @Test
  fun unknownTotalKeepsActualCompletedWorkForIndeterminateProgress() {
    start("sync")
    manager.onServiceStarted(service)
    manager.updateProgress(owner, "sync", 256, -1)
    assertEquals(256L, manager.tasks.single().completed)
    assertEquals(-1L, manager.tasks.single().total)
  }

  @Test
  fun progressIsClampedAndCannotBeChangedByAnotherEngine() {
    start("upload")
    manager.onServiceStarted(service)
    manager.updateProgress(owner, "upload", 25, 10)
    manager.updateProgress(Any(), "upload", 1, 10)

    assertEquals(10L, manager.tasks.single().completed)
    assertEquals(10L, manager.tasks.single().total)
  }

  private fun start(taskId: String) {
    manager.start(owner, taskId, "Title", "Description", {
      assertTrue(service.stopped)
      assertFalse(manager.isActive(owner, taskId))
      expired.add(taskId)
    }, results::add)
  }

  private class TestService : BackgroundTaskServiceHost {
    var stopped = false

    override fun refreshNotification() {}

    override fun stop() {
      stopped = true
    }
  }
}
