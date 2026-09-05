import 'package:flutter/material.dart';
import 'package:immich_mobile/domain/models/asset/base_asset.model.dart';
import 'package:immich_mobile/domain/models/config/app_config.dart';
import 'package:immich_mobile/extensions/translate_extensions.dart';

enum OriginalMediaKind { image, video }

OriginalMediaKind? originalMediaActionFor({
  required BaseAsset asset,
  required AppConfig config,
  bool isPlayingMotionVideo = false,
  bool originalRequested = false,
  bool hasDirectFile = false,
}) {
  if (originalRequested || hasDirectFile) {
    return null;
  }

  if (asset.isVideo || isPlayingMotionVideo) {
    if (asset.hasLocal || config.viewer.loadOriginalVideo) {
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

class OriginalMediaActionButton extends StatelessWidget {
  const OriginalMediaActionButton({super.key, required this.kind, required this.onPressed});

  final OriginalMediaKind kind;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final label = switch (kind) {
      OriginalMediaKind.image => 'view_original_image'.t(context: context),
      OriginalMediaKind.video => 'view_original_video'.t(context: context),
    };

    return TextButton(
      key: const Key('view-original-media-button'),
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: Colors.black54,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: const StadiumBorder(),
      ),
      child: Text(label),
    );
  }
}
