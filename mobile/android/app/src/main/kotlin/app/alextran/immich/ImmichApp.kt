package app.alextran.immich

import android.app.Application
import app.alextran.immich.background.BackgroundWorkerApiImpl

class ImmichApp : Application() {
  override fun onCreate() {
    super.onCreate()
    BackgroundWorkerApiImpl(this).disable()
  }
}
