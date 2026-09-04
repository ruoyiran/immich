// ignore_for_file: require_trailing_commas

import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/constants/enums.dart';
import 'package:immich_mobile/domain/models/asset/base_asset.model.dart';
import 'package:immich_mobile/domain/models/events.model.dart';
import 'package:immich_mobile/domain/models/memory.model.dart';
import 'package:immich_mobile/domain/utils/event_stream.dart';
import 'package:immich_mobile/generated/translations.g.dart';
import 'package:immich_mobile/presentation/actions/download.action.dart';
import 'package:immich_mobile/presentation/actions/share.action.dart';
import 'package:immich_mobile/providers/infrastructure/memory.provider.dart';
import 'package:immich_mobile/routing/router.dart';

class DriftMemoryBottomInfo extends ConsumerStatefulWidget {
  final DriftMemory memory;
  final RemoteAsset asset;
  final String title;

  const DriftMemoryBottomInfo({super.key, required this.memory, required this.asset, required this.title});

  @override
  ConsumerState<DriftMemoryBottomInfo> createState() => _DriftMemoryBottomInfoState();
}

class _DriftMemoryBottomInfoState extends ConsumerState<DriftMemoryBottomInfo> {
  late bool _isSaved;

  @override
  void initState() {
    super.initState();
    _isSaved = widget.memory.isSaved;
  }

  @override
  void didUpdateWidget(covariant DriftMemoryBottomInfo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.memory.id != widget.memory.id || oldWidget.memory.isSaved != widget.memory.isSaved) {
      _isSaved = widget.memory.isSaved;
    }
  }

  Future<void> _toggleSaved() async {
    final isSaved = !_isSaved;
    setState(() => _isSaved = isSaved);
    await ref.read(driftMemoryServiceProvider).setSaved(widget.memory.id, isSaved);
    ref.invalidate(driftMemoryFutureProvider);
  }

  Future<void> _hide(BuildContext context) async {
    await ref.read(driftMemoryServiceProvider).hide(widget.memory.id);
    ref.invalidate(driftMemoryFutureProvider);
    if (context.mounted) {
      await context.maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat.yMMMMd();
    final fileCreatedDate = widget.asset.createdAt;
    final shareAction = const ShareAction(source: ActionSource.viewer).create(context, ref);
    final downloadAction = const DownloadAction(source: ActionSource.viewer).create(context, ref);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: TextStyle(color: Colors.grey[400], fontSize: 13.0, fontWeight: FontWeight.w500),
                ),
                Text(
                  df.format(fileCreatedDate.toLocal()),
                  style: const TextStyle(color: Colors.white, fontSize: 15.0, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Wrap(
            spacing: 8,
            children: [
              _MemoryActionButton(
                key: const Key('memory-save-button'),
                tooltip: context.t.save,
                icon: _isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                onPressed: _toggleSaved,
              ),
              if (downloadAction != null)
                _MemoryActionButton(
                  key: const Key('memory-download-button'),
                  tooltip: downloadAction.label,
                  icon: downloadAction.icon,
                  onPressed: downloadAction.onAction,
                ),
              if (shareAction != null)
                _MemoryActionButton(
                  key: const Key('memory-share-button'),
                  tooltip: shareAction.label,
                  icon: shareAction.icon,
                  onPressed: shareAction.onAction,
                ),
              _MemoryActionButton(
                key: const Key('memory-hide-button'),
                tooltip: 'Hide memory',
                icon: Icons.visibility_off_outlined,
                onPressed: () => _hide(context),
              ),
              _MemoryActionButton(
                key: const Key('memory-open-timeline-button'),
                tooltip: 'view_in_timeline'.tr(),
                icon: Icons.open_in_new,
                onPressed: () async {
                  await context.router.navigate(const TabShellRoute(children: [MainTimelineRoute()]));
                  EventStream.shared.emit(ScrollToDateEvent(fileCreatedDate.toLocal()));
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MemoryActionButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final FutureOr<void> Function() onPressed;

  const _MemoryActionButton({super.key, required this.tooltip, required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: MaterialButton(
        minWidth: 0,
        padding: const EdgeInsets.all(10),
        onPressed: () => unawaited(Future.sync(onPressed)),
        shape: const CircleBorder(),
        color: Colors.white.withValues(alpha: 0.2),
        elevation: 0,
        child: Icon(icon, color: Colors.white),
      ),
    );
  }
}
