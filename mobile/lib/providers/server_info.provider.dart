import 'dart:async';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/domain/models/user.model.dart';
import 'package:immich_mobile/models/server_info/server_config.model.dart';
import 'package:immich_mobile/models/server_info/server_disk_info.model.dart';
import 'package:immich_mobile/models/server_info/server_features.model.dart';
import 'package:immich_mobile/models/server_info/server_info.model.dart';
import 'package:immich_mobile/models/server_info/server_version.model.dart';
import 'package:immich_mobile/services/server_info.service.dart';
import 'package:immich_mobile/utils/semver.dart';
import 'package:logging/logging.dart';
import 'package:package_info_plus/package_info_plus.dart';

class ServerInfoNotifier extends StateNotifier<ServerInfo> {
  ServerInfoNotifier(this._serverInfoService)
    : super(
        const ServerInfo(
          serverVersion: ServerVersion(major: 0, minor: 0, patch: 0),
          serverFeatures: ServerFeatures(map: true, trash: true, oauthEnabled: false, passwordLogin: true),
          serverConfig: ServerConfig(
            trashDays: 30,
            oauthButtonText: '',
            externalDomain: '',
            mapLightStyleUrl: 'https://tiles.immich.cloud/v1/style/light.json',
            mapDarkStyleUrl: 'https://tiles.immich.cloud/v1/style/dark.json',
          ),
          serverDiskInfo: ServerDiskInfo(diskAvailable: "0", diskSize: "0", diskUse: "0", diskUsagePercentage: 0),
          versionStatus: VersionStatus.upToDate,
        ),
      );

  final ServerInfoService _serverInfoService;
  final _log = Logger("ServerInfoNotifier");

  Future<ServerInfo> getServerInfo() async {
    final previousState = state;
    await getServerVersion();
    if (!mounted) {
      return previousState;
    }
    await getServerFeatures();
    if (!mounted) {
      return previousState;
    }
    await getServerConfig();
    if (!mounted) {
      return previousState;
    }
    return state;
  }

  Future<void> getServerVersion() async {
    try {
      final serverVersion = await _serverInfoService.getServerVersion();

      // using isClientOutOfDate since that will show to users regardless of if they are an admin
      if (serverVersion == null) {
        if (!mounted) {
          return;
        }
        state = state.copyWith(versionStatus: VersionStatus.error);
        return;
      }

      await _checkServerVersionMismatch(serverVersion);
    } catch (e, stackTrace) {
      _log.severe("Failed to get server version", e, stackTrace);
      if (!mounted) {
        return;
      }
      state = state.copyWith(versionStatus: VersionStatus.error);
      return;
    }
  }

  Future<void> _checkServerVersionMismatch(ServerVersion serverVersion, {ServerVersion? latestVersion}) async {
    if (!mounted) {
      return;
    }
    final effectiveLatestVersion = latestVersion ?? state.latestVersion;
    state = state.copyWith(serverVersion: serverVersion, latestVersion: effectiveLatestVersion);

    final packageInfo = await PackageInfo.fromPlatform();
    if (!mounted) {
      return;
    }
    final SemVer clientVersion = SemVer.fromString(packageInfo.version);

    if (serverVersion < clientVersion || (effectiveLatestVersion != null && serverVersion < effectiveLatestVersion)) {
      state = state.copyWith(versionStatus: VersionStatus.serverOutOfDate);
      return;
    }

    if (clientVersion < serverVersion && clientVersion.differenceType(serverVersion) != SemVerType.patch) {
      state = state.copyWith(versionStatus: VersionStatus.clientOutOfDate);
      return;
    }

    state = state.copyWith(versionStatus: VersionStatus.upToDate);
  }

  void handleReleaseInfo(ServerVersion serverVersion, ServerVersion? latestVersion) {
    // Update local server version
    unawaited(_checkServerVersionMismatch(serverVersion, latestVersion: latestVersion));
  }

  Future<void> getServerFeatures() async {
    final serverFeatures = await _serverInfoService.getServerFeatures();
    if (!mounted || serverFeatures == null) {
      return;
    }
    state = state.copyWith(serverFeatures: serverFeatures);
  }

  Future<void> getServerConfig() async {
    final serverConfig = await _serverInfoService.getServerConfig();
    if (!mounted || serverConfig == null) {
      return;
    }
    state = state.copyWith(serverConfig: serverConfig);
  }
}

final serverInfoProvider = StateNotifierProvider<ServerInfoNotifier, ServerInfo>((ref) {
  return ServerInfoNotifier(ref.read(serverInfoServiceProvider));
});

final versionWarningPresentProvider = Provider.family<bool, UserDto?>((ref, user) {
  final serverInfo = ref.watch(serverInfoProvider);
  return switch (serverInfo.versionStatus) {
    VersionStatus.clientOutOfDate || VersionStatus.error => true,
    VersionStatus.serverOutOfDate => serverInfo.latestVersion != null && (user?.isAdmin ?? false),
    VersionStatus.upToDate => false,
  };
});
