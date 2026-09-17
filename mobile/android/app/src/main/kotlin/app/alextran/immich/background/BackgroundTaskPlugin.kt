package app.alextran.immich.background

import android.app.Activity
import android.util.Log
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import app.alextran.immich.ImmichApp
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding

class BackgroundTaskPlugin : FlutterPlugin, ActivityAware, BackgroundTaskHostApi {
  private val owner = Any()
  private var manager: BackgroundTaskManager? = null
  private var flutterApi: BackgroundTaskFlutterApi? = null
  private var activity: Activity? = null

  override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    manager = (binding.applicationContext as ImmichApp).backgroundTasks
    flutterApi = BackgroundTaskFlutterApi(binding.binaryMessenger)
    BackgroundTaskHostApi.setUp(binding.binaryMessenger, this)
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    BackgroundTaskHostApi.setUp(binding.binaryMessenger, null)
    manager?.finishOwner(owner)
    manager = null
    flutterApi = null
    activity = null
  }

  override fun start(
    taskId: String,
    title: String,
    description: String,
    mode: BackgroundTaskMode,
    callback: (Result<Boolean>) -> Unit,
  ) {
    val manager = manager
    if (manager == null) {
      callback(Result.success(false))
      return
    }
    if (manager.isActive(owner, taskId)) {
      callback(Result.success(true))
      return
    }
    val lifecycle = (activity as? LifecycleOwner)?.lifecycle
    if (lifecycle?.currentState?.isAtLeast(Lifecycle.State.RESUMED) != true) {
      callback(Result.success(false))
      return
    }
    manager.start(owner, taskId, title, description, {
      flutterApi?.onExpired(taskId) { result ->
        result.exceptionOrNull()?.let { Log.w("BackgroundTaskPlugin", "Expiration callback failed", it) }
      }
    }, { callback(Result.success(it)) })
  }

  override fun updateProgress(taskId: String, completed: Long, total: Long) {
    manager?.updateProgress(owner, taskId, completed, total)
  }

  override fun isActive(taskId: String): Boolean = manager?.isActive(owner, taskId) == true

  override fun finish(taskId: String) {
    manager?.finish(owner, taskId)
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    activity = binding.activity
  }

  override fun onDetachedFromActivityForConfigChanges() {
    activity = null
  }

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
    activity = binding.activity
  }

  override fun onDetachedFromActivity() {
    activity = null
  }
}
