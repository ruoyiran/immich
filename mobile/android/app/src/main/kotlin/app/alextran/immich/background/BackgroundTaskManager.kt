package app.alextran.immich.background

interface BackgroundTaskServiceHost {
  fun refreshNotification()
  fun stop()
}

data class BackgroundTaskInfo(
  val title: String,
  val description: String,
  var completed: Long = 0,
  var total: Long = 0,
)

/** Application-owned leases. All calls run on the Android main thread. */
class BackgroundTaskManager(
  private val startService: () -> Boolean,
  private val stopPendingService: () -> Unit,
  private val scheduleStartTimeout: (() -> Unit) -> (() -> Unit),
) {
  private data class Key(val owner: Any, val taskId: String)

  private class Task(
    val info: BackgroundTaskInfo,
    val onExpired: () -> Unit,
    val pending: MutableList<(Boolean) -> Unit>,
  )

  private val entries = linkedMapOf<Key, Task>()
  private var service: BackgroundTaskServiceHost? = null
  private var starting = false
  private var cancelStartTimeout: (() -> Unit)? = null

  val tasks: List<BackgroundTaskInfo>
    get() = entries.values.map { it.info }

  fun start(
    owner: Any,
    taskId: String,
    title: String,
    description: String,
    onExpired: () -> Unit,
    onStarted: (Boolean) -> Unit,
  ) {
    if (taskId.isBlank()) {
      onStarted(false)
      return
    }
    val key = Key(owner, taskId)
    val existing = entries[key]
    if (existing != null) {
      if (service != null) onStarted(true) else existing.pending.add(onStarted)
      return
    }

    val task = Task(BackgroundTaskInfo(title, description), onExpired, mutableListOf(onStarted))
    entries[key] = task
    if (service != null) {
      service?.refreshNotification()
      completeStart(task, entries[key] === task && service != null)
      return
    }
    if (starting) return

    starting = true
    cancelStartTimeout = scheduleStartTimeout(::onServiceStartFailed)
    if (!startService()) onServiceStartFailed()
  }

  fun isActive(owner: Any, taskId: String): Boolean =
    service != null && entries.containsKey(Key(owner, taskId))

  fun updateProgress(owner: Any, taskId: String, completed: Long, total: Long) {
    val task = entries[Key(owner, taskId)] ?: return
    task.info.total = if (total < 0) -1 else total
    task.info.completed = if (total < 0) completed.coerceAtLeast(0) else completed.coerceIn(0, total)
    service?.refreshNotification()
  }

  fun finish(owner: Any, taskId: String) {
    val task = entries.remove(Key(owner, taskId)) ?: return
    completeStart(task, false)
    refreshOrStop()
  }

  fun finishOwner(owner: Any) {
    val removed = entries.filterKeys { it.owner === owner }
    removed.keys.forEach(entries::remove)
    removed.values.forEach { completeStart(it, false) }
    refreshOrStop()
  }

  fun onServiceStarted(host: BackgroundTaskServiceHost) {
    if (entries.isEmpty()) {
      host.stop()
      return
    }
    service = host
    clearStartTimeout()
    entries.values.toList().forEach { completeStart(it, true) }
  }

  fun onServiceStartFailed() {
    if (!starting) return
    val pending = entries.values.toList()
    entries.clear()
    clearStartTimeout()
    stopPendingService()
    pending.forEach { completeStart(it, false) }
  }

  fun onServiceExpired(host: BackgroundTaskServiceHost) {
    if (service !== host) return
    val expired = entries.values.toList()
    entries.clear()
    service = null
    clearStartTimeout()
    // Android requires timeout cleanup immediately, without waiting for Dart.
    host.stop()
    expired.forEach {
      completeStart(it, false)
      it.onExpired()
    }
  }

  private fun refreshOrStop() {
    if (entries.isNotEmpty()) {
      service?.refreshNotification()
      return
    }
    val host = service
    service = null
    clearStartTimeout()
    if (host != null) host.stop() else stopPendingService()
  }

  private fun clearStartTimeout() {
    starting = false
    cancelStartTimeout?.invoke()
    cancelStartTimeout = null
  }

  private fun completeStart(task: Task, active: Boolean) {
    val callbacks = task.pending.toList()
    task.pending.clear()
    callbacks.forEach { it(active) }
  }
}
