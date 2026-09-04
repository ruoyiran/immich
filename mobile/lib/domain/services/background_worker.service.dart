import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:immich_mobile/extensions/platform_extensions.dart';
import 'package:immich_mobile/platform/background_worker_api.g.dart';
import 'package:immich_mobile/platform/background_worker_lock_api.g.dart';
import 'package:logging/logging.dart';

/// Compatibility wrapper used to cancel background backup work scheduled by
/// older app versions. Automatic backup must not be enabled again.
class BackgroundWorkerFgService {
  final BackgroundWorkerFgHostApi _foregroundHostApi;

  const BackgroundWorkerFgService(this._foregroundHostApi);

  Future<void> disable() => _foregroundHostApi.disable();
}

/// Handles a background callback that was already queued before the app was
/// upgraded. The callback deliberately performs no sync or upload work.
class BackgroundWorkerBgService extends BackgroundWorkerFlutterApi {
  final BackgroundWorkerBgHostApi _backgroundHostApi;
  final Logger _logger = Logger('BackgroundWorkerBgService');

  BackgroundWorkerBgService() : _backgroundHostApi = BackgroundWorkerBgHostApi() {
    BackgroundWorkerFlutterApi.setUp(this);
  }

  Future<void> init() async {
    try {
      await _backgroundHostApi.onInitialized();
    } catch (error, stack) {
      _logger.severe('Failed to initialize disabled background worker', error, stack);
      unawaited(_backgroundHostApi.close());
    }
  }

  @override
  Future<void> onAndroidUpload(int? maxMinutes) async {
    _logger.info('Ignoring legacy Android automatic backup callback');
  }

  @override
  Future<void> onIosUpload(bool isRefresh, int? maxSeconds) async {
    _logger.info('Ignoring legacy iOS automatic backup callback');
  }

  @override
  Future<void> cancel() async {
    _logger.info('Disabled background worker cancelled');
  }
}

class BackgroundWorkerLockService {
  final BackgroundWorkerLockApi _hostApi;
  const BackgroundWorkerLockService(this._hostApi);

  Future<void> lock() async {
    if (CurrentPlatform.isAndroid) {
      return _hostApi.lock();
    }
  }

  Future<void> unlock() async {
    if (CurrentPlatform.isAndroid) {
      return _hostApi.unlock();
    }
  }
}

/// Native entry invoked by a background task scheduled by an older app
/// version. Keep the symbol until those installations have had time to
/// upgrade, but complete the task without uploading anything.
@pragma('vm:entry-point')
Future<void> backgroundSyncNativeEntrypoint() async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  await BackgroundWorkerBgService().init();
}
