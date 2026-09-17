package app.alextran.immich.background

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import app.alextran.immich.ImmichApp
import app.alextran.immich.MainActivity
import app.alextran.immich.R

/** Protects work already running in the foreground Flutter engine; never schedules backup. */
class BackgroundTaskService : Service(), BackgroundTaskServiceHost {
  private val manager: BackgroundTaskManager
    get() = (application as ImmichApp).backgroundTasks
  private val handler = Handler(Looper.getMainLooper())
  private var wakeLock: PowerManager.WakeLock? = null
  private var foreground = false
  private val expire = Runnable { manager.onServiceExpired(this) }

  override fun onBind(intent: Intent?): IBinder? = null

  override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
    if (manager.tasks.isEmpty()) {
      stop()
      return START_NOT_STICKY
    }
    try {
      if (!foreground) {
        ServiceCompat.startForeground(
          this,
          NOTIFICATION_ID,
          notification(),
          if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) FOREGROUND_SERVICE_TYPE_DATA_SYNC else 0,
        )
        val powerManager = getSystemService(POWER_SERVICE) as PowerManager
        wakeLock = powerManager.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "$packageName:backgroundTask").apply {
          setReferenceCounted(false)
          acquire(MAX_DURATION_MILLIS)
        }
        foreground = true
        handler.postDelayed(expire, MAX_DURATION_MILLIS)
      }
      manager.onServiceStarted(this)
    } catch (error: RuntimeException) {
      Log.w(TAG, "Unable to protect the current task", error)
      manager.onServiceStartFailed()
      stop()
    }
    return START_NOT_STICKY
  }

  override fun refreshNotification() {
    if (!foreground) return
    try {
      (getSystemService(NOTIFICATION_SERVICE) as NotificationManager).notify(NOTIFICATION_ID, notification())
    } catch (error: RuntimeException) {
      Log.w(TAG, "Unable to update foreground notification", error)
      manager.onServiceExpired(this)
    }
  }

  override fun onTimeout(startId: Int, fgsType: Int) {
    manager.onServiceExpired(this)
    stop()
  }

  override fun onDestroy() {
    manager.onServiceExpired(this)
    releaseResources()
    super.onDestroy()
  }

  override fun stop() {
    releaseResources()
    stopSelf()
  }

  private fun releaseResources() {
    handler.removeCallbacks(expire)
    wakeLock?.let { if (it.isHeld) it.release() }
    wakeLock = null
    foreground = false
    ServiceCompat.stopForeground(this, ServiceCompat.STOP_FOREGROUND_REMOVE)
  }

  private fun notification(): Notification {
    val tasks = manager.tasks
    val first = tasks.first()
    val notificationManager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
    notificationManager.createNotificationChannel(
      NotificationChannel(CHANNEL_ID, first.title, NotificationManager.IMPORTANCE_LOW),
    )
    val openApp = PendingIntent.getActivity(
      this,
      0,
      Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
      PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )
    val total = tasks.sumOf { it.total.toDouble() }
    val completed = tasks.sumOf { it.completed.toDouble() }
    val indeterminate = tasks.any { it.total <= 0 }
    val builder = NotificationCompat.Builder(this, CHANNEL_ID)
      .setSmallIcon(R.drawable.notification_icon)
      .setContentTitle(first.title)
      .setContentText(first.description)
      .setContentIntent(openApp)
      .setOnlyAlertOnce(true)
      .setOngoing(true)
      .setCategory(NotificationCompat.CATEGORY_PROGRESS)
      .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
      .setProgress(1000, if (total > 0) (completed / total * 1000).toInt() else 0, indeterminate)
    if (tasks.size > 1) {
      builder.setStyle(NotificationCompat.InboxStyle().also { style ->
        tasks.forEach { style.addLine("${it.title}: ${it.description}") }
      })
    }
    return builder.build()
  }

  companion object {
    private const val TAG = "BackgroundTaskService"
    private const val CHANNEL_ID = "immich::active_tasks"
    private const val NOTIFICATION_ID = 101
    private const val MAX_DURATION_MILLIS = 6 * 60 * 60 * 1000L
  }
}
