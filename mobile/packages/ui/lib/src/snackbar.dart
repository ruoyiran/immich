import 'dart:async';

import 'package:flutter/material.dart';
import 'package:immich_ui/immich_ui.dart';

final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

class SnackbarManager {
  const SnackbarManager();

  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? show(
    String message,
    SnackbarType type, {
    Duration? duration,
    String? actionLabel,
    FutureOr<void> Function()? onAction,
  }) {
    final messenger = scaffoldMessengerKey.currentState;
    final context = scaffoldMessengerKey.currentContext;
    if (messenger == null || context == null) {
      return null;
    }

    duration ??= const .new(seconds: 4);
    messenger.hideCurrentSnackBar();
    return messenger.showSnackBar(
      _build(
        context,
        message,
        type,
        duration,
        actionLabel: actionLabel,
        onAction: onAction,
      ),
    );
  }

  SnackBar _build(
    BuildContext context,
    String message,
    SnackbarType type,
    Duration duration, {
    String? actionLabel,
    FutureOr<void> Function()? onAction,
  }) {
    final theme = Theme.of(context);
    final colors =
        theme.extension<ImmichColors>() ??
        ImmichColors.harmonized(theme.colorScheme);
    final (IconData icon, Color background, Color foreground) = switch (type) {
      .info => (Icons.info_rounded, colors.info, colors.onInfo),
      .success => (
        Icons.check_circle_rounded,
        colors.success,
        colors.onSuccess,
      ),
      .error => (Icons.warning_rounded, colors.error, colors.onError),
    };

    return SnackBar(
      behavior: .floating,
      backgroundColor: background,
      duration: duration,
      shape: const RoundedRectangleBorder(
        borderRadius: .all(.circular(ImmichRadius.sm)),
      ),
      action: actionLabel != null && onAction != null
          ? SnackBarAction(
              label: actionLabel,
              textColor: foreground,
              onPressed: () => unawaited(Future.sync(onAction)),
            )
          : null,
      content: Row(
        children: [
          Icon(icon, color: foreground, size: ImmichIconSize.sm),
          const SizedBox(width: ImmichSpacing.md),
          Expanded(
            child: Text(
              message,
              maxLines: 2,
              overflow: .ellipsis,
              style: .new(
                color: foreground,
                fontWeight: .w600,
                fontSize: ImmichTextSize.body,
              ),
            ),
          ),
        ],
      ),
    );
  }

  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? info(
    String message, {
    Duration? duration,
    String? actionLabel,
    FutureOr<void> Function()? onAction,
  }) => show(
    message,
    .info,
    duration: duration,
    actionLabel: actionLabel,
    onAction: onAction,
  );

  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? success(
    String message, {
    Duration? duration,
    String? actionLabel,
    FutureOr<void> Function()? onAction,
  }) => show(
    message,
    .success,
    duration: duration,
    actionLabel: actionLabel,
    onAction: onAction,
  );

  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? error(
    String message, {
    Duration? duration,
    String? actionLabel,
    FutureOr<void> Function()? onAction,
  }) => show(
    message,
    .error,
    duration: duration,
    actionLabel: actionLabel,
    onAction: onAction,
  );
}

const snackbar = SnackbarManager();
