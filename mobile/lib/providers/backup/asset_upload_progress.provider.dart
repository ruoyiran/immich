import 'dart:async';

import 'package:hooks_riverpod/hooks_riverpod.dart';

enum AssetUploadPhase { uploading, processing, error }

class AssetUploadProgress {
  final double value;
  final AssetUploadPhase phase;

  const AssetUploadProgress.uploading(this.value) : phase = AssetUploadPhase.uploading;
  const AssetUploadProgress.processing() : value = 1.0, phase = AssetUploadPhase.processing;
  const AssetUploadProgress.error() : value = 0.0, phase = AssetUploadPhase.error;
}

/// Tracks per-asset upload transfer and server-processing state.
class AssetUploadProgressNotifier extends Notifier<Map<String, AssetUploadProgress>> {
  @override
  Map<String, AssetUploadProgress> build() => {};

  void setProgress(String localAssetId, double progress) {
    state = {...state, localAssetId: AssetUploadProgress.uploading(progress)};
  }

  void setProcessing(String localAssetId) {
    state = {...state, localAssetId: const AssetUploadProgress.processing()};
  }

  void setError(String localAssetId) {
    state = {...state, localAssetId: const AssetUploadProgress.error()};
  }

  void remove(String localAssetId) {
    state = Map.from(state)..remove(localAssetId);
  }

  void clear() {
    state = {};
  }
}

final assetUploadProgressProvider = NotifierProvider<AssetUploadProgressNotifier, Map<String, AssetUploadProgress>>(
  AssetUploadProgressNotifier.new,
);

final manualUploadCancelTokenProvider = StateProvider<Completer<void>?>((ref) => null);
