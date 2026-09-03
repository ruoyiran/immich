import 'dart:async';

import 'package:immich_mobile/generated/translations.g.dart';
import 'package:immich_ui/immich_ui.dart';

class ToastOption {
  final Duration? timeout;
  final FutureOr<void> Function()? onUndo;

  const ToastOption({this.timeout, this.onUndo});
}

class ToastService {
  const ToastService();

  FutureOr<void> success(String message, {ToastOption? toast}) {
    snackbar.success(
      message,
      duration: toast?.timeout,
      actionLabel: toast?.onUndo == null ? null : StaticTranslations.instance.undo,
      onAction: toast?.onUndo,
    );
  }

  FutureOr<void> info(String message, {ToastOption? toast}) {
    snackbar.info(message, duration: toast?.timeout);
  }

  FutureOr<void> error(String message, {ToastOption? toast}) {
    snackbar.error(message, duration: toast?.timeout);
  }
}
