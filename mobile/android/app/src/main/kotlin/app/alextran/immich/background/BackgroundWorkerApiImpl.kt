package app.alextran.immich.background

import android.content.Context
import android.util.Log
import androidx.work.WorkManager
import io.flutter.embedding.engine.FlutterEngineCache

private const val TAG = "BackgroundWorkerApiImpl"

class BackgroundWorkerApiImpl(context: Context) : BackgroundWorkerFgHostApi {
  private val ctx: Context = context.applicationContext

  override fun enable() = cancelAll(ctx)

  override fun saveNotificationMessage(title: String, body: String) = Unit

  override fun configure(settings: BackgroundWorkerSettings) = cancelAll(ctx)

  override fun disable() = cancelAll(ctx)

  companion object {
    private const val BACKGROUND_WORKER_NAME = "immich/BackgroundWorkerV1"
    private const val OBSERVER_WORKER_NAME = "immich/MediaObserverV1"
    private const val PERIODIC_WORKER_NAME = "immich/PeriodicBackgroundWorkerV1"
    const val ENGINE_CACHE_KEY = "immich::background_worker::engine"

    fun enqueueMediaObserver(ctx: Context) = cancelAll(ctx)

    fun enqueuePeriodicWorker(ctx: Context) = cancelAll(ctx)

    fun enqueueBackgroundWorker(ctx: Context) = cancelAll(ctx)

    fun isBackgroundWorkerRunning(): Boolean {
      return FlutterEngineCache.getInstance().get(ENGINE_CACHE_KEY) != null
    }

    fun cancelBackgroundWorker(ctx: Context) {
      cancelAll(ctx)
      FlutterEngineCache.getInstance().remove(ENGINE_CACHE_KEY)
    }

    private fun cancelAll(ctx: Context) {
      WorkManager.getInstance(ctx).apply {
        cancelUniqueWork(OBSERVER_WORKER_NAME)
        cancelUniqueWork(BACKGROUND_WORKER_NAME)
        cancelUniqueWork(PERIODIC_WORKER_NAME)
      }
      Log.i(TAG, "Automatic backup is disabled; cancelled background upload tasks")
    }
  }
}
