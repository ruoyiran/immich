package app.alextran.immich

import android.app.Application
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.util.Log
import app.alextran.immich.background.BackgroundTaskManager
import app.alextran.immich.background.BackgroundTaskService
import app.alextran.immich.background.BackgroundWorkerApiImpl

class ImmichApp : Application() {
  val backgroundTasks by lazy {
    val handler = Handler(Looper.getMainLooper())
    BackgroundTaskManager(
      startService = {
        try {
          startForegroundService(Intent(this, BackgroundTaskService::class.java)) != null
        } catch (error: RuntimeException) {
          Log.w("ImmichApp", "Foreground task service was rejected", error)
          false
        }
      },
      stopPendingService = { stopService(Intent(this, BackgroundTaskService::class.java)) },
      scheduleStartTimeout = { timeout ->
        val runnable = Runnable(timeout)
        handler.postDelayed(runnable, 10_000)
        val cancel = { handler.removeCallbacks(runnable) }
        cancel
      },
    )
  }

  override fun onCreate() {
    super.onCreate()
    BackgroundWorkerApiImpl(this).disable()
  }
}
