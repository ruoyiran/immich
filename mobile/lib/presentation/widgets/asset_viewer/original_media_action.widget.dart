import 'package:flutter/material.dart';
import 'package:immich_mobile/domain/models/asset/base_asset.model.dart';
import 'package:immich_mobile/domain/models/config/app_config.dart';
import 'package:immich_mobile/domain/models/original_media.model.dart';
import 'package:immich_mobile/generated/translations.g.dart';

enum OriginalMediaKind { image, video }

String originalMediaViewerKey(BaseAsset asset, {required bool forceOriginal}) => asset.heroTag;

OriginalMediaType? originalMediaTypeFor(BaseAsset asset, {bool isPlayingMotionVideo = false}) {
  if (!asset.isRemoteOnly) {
    return null;
  }
  return asset.isVideo || isPlayingMotionVideo ? OriginalMediaType.video : OriginalMediaType.image;
}

OriginalMediaKind? originalMediaActionFor({
  required BaseAsset asset,
  required AppConfig config,
  bool isPlayingMotionVideo = false,
  bool originalRequested = false,
  bool hasDirectFile = false,
}) {
  if (!asset.isRemoteOnly || originalRequested || hasDirectFile) {
    return null;
  }

  if (asset.isVideo || isPlayingMotionVideo) {
    if (config.viewer.loadOriginalVideo) {
      return null;
    }
    return OriginalMediaKind.video;
  }

  if (asset.isImage && !asset.isAnimatedImage && !config.image.loadOriginal) {
    return OriginalMediaKind.image;
  }

  return null;
}

String selectRemoteVideoEndpoint({required bool loadOriginalVideo, required bool forceOriginal}) =>
    loadOriginalVideo || forceOriginal ? 'original' : 'video/playback';

class OriginalMediaActionOverlay extends StatelessWidget {
  const OriginalMediaActionOverlay({
    super.key,
    required this.kind,
    required this.showingControls,
    required this.onPressed,
    this.loading = false,
    this.progress,
    this.sizeLabel,
  });

  final OriginalMediaKind kind;
  final bool showingControls;
  final VoidCallback onPressed;
  final bool loading;
  final double? progress;
  final String? sizeLabel;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: MediaQuery.paddingOf(context).bottom + 72,
      child: IgnorePointer(
        ignoring: !showingControls,
        child: AnimatedOpacity(
          opacity: showingControls ? 1 : 0,
          duration: Durations.short2,
          child: Center(
            child: OriginalMediaActionButton(
              kind: kind,
              onPressed: loading ? null : onPressed,
              loading: loading,
              progress: progress,
              sizeLabel: sizeLabel,
            ),
          ),
        ),
      ),
    );
  }
}

class OriginalMediaActionButton extends StatelessWidget {
  const OriginalMediaActionButton({
    super.key,
    required this.kind,
    required this.onPressed,
    this.loading = false,
    this.progress,
    this.sizeLabel,
  });

  final OriginalMediaKind kind;
  final VoidCallback? onPressed;
  final bool loading;
  final double? progress;
  final String? sizeLabel;

  @override
  Widget build(BuildContext context) {
    final displayProgress = progress?.clamp(0.0, 1.0);
    return TextButton(
      key: const Key('view-original-media-button'),
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: Colors.black54,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: const StadiumBorder(),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 140),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              children: [
                Text(
                  loading
                      ? context.t.downloading
                      : switch (kind) {
                          OriginalMediaKind.image => context.t.view_original_image,
                          OriginalMediaKind.video => context.t.view_original_video,
                        },
                ),
                if (sizeLabel case final sizeLabel?) Text(sizeLabel, style: const TextStyle(color: Colors.white70)),
                if (loading && displayProgress != null) Text('${(displayProgress * 100).round()}%'),
              ],
            ),
            if (loading) ...[
              const SizedBox(height: 6),
              SizedBox(
                height: 2,
                child: LinearProgressIndicator(
                  value: displayProgress,
                  color: Colors.white,
                  backgroundColor: Colors.white24,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
