import 'dart:async';

import 'package:hooks_riverpod/hooks_riverpod.dart';

enum AssetUploadPhase { uploading, processing, error }

class AssetUploadProgress {
  final double value;
  final AssetUploadPhase phase;

  const AssetUploadProgress.uploading(this.value) : phase = AssetUploadPhase.uploading;
  AssetUploadProgress.processing() : value = 1.0, phase = AssetUploadPhase.processing;
  AssetUploadProgress.error() : value = 0.0, phase = AssetUploadPhase.error;
}

/// Tracks per-asset upload transfer and server-processing state.
class AssetUploadProgressNotifier extends Notifier<Map<String, AssetUploadProgress>> {
  @override
  Map<String, AssetUploadProgress> build() => {};

  void setProgress(String localAssetId, double progress) {
    state = {...state, localAssetId: AssetUploadProgress.uploading(progress)};
  }

  void setProcessing(String localAssetId) {
    state = {...state, localAssetId: AssetUploadProgress.processing()};
  }

  void setError(String localAssetId) {
    state = {...state, localAssetId: AssetUploadProgress.error()};
  }

  void remove(String localAssetId) {
    state = Map.from(state)..remove(localAssetId);
  }

  void clear() {
    state = {};
  }

  void clearAssets(Iterable<String> assetIds, {Duration delay = Duration.zero}) {
    final entries = {for (final id in assetIds) id: state[id]};
    void clearOwnedEntries() {
      state = Map.from(state)..removeWhere((id, value) => identical(entries[id], value));
    }

    if (delay == Duration.zero) {
      clearOwnedEntries();
    } else {
      final timer = Timer(delay, clearOwnedEntries);
      ref.onDispose(timer.cancel);
    }
  }
}

final assetUploadProgressProvider = NotifierProvider<AssetUploadProgressNotifier, Map<String, AssetUploadProgress>>(
  AssetUploadProgressNotifier.new,
);

class ManualUploadCancellationNotifier extends Notifier<Completer<void>?> {
  final _batches = <Completer<void>>[];

  @override
  Completer<void>? build() => null;

  void register(Completer<void> token) {
    _batches.add(token);
    state = token;
  }

  void unregister(Completer<void> token) {
    _batches.removeWhere((batch) => identical(batch, token) || batch.isCompleted);
    state = _batches.lastOrNull;
  }

  void cancelCurrent() {
    final token = state;
    if (token == null) {
      return;
    }
    if (!token.isCompleted) {
      token.complete();
    }
    unregister(token);
  }
}

final manualUploadCancelTokenProvider = NotifierProvider<ManualUploadCancellationNotifier, Completer<void>?>(
  ManualUploadCancellationNotifier.new,
);
