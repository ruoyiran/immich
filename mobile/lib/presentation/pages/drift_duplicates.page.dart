import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/domain/models/asset/base_asset.model.dart';
import 'package:immich_mobile/domain/models/duplicate_group.model.dart';
import 'package:immich_mobile/domain/services/timeline.service.dart';
import 'package:immich_mobile/presentation/widgets/asset_viewer/asset_viewer.page.dart';
import 'package:immich_mobile/presentation/widgets/images/thumbnail.widget.dart';
import 'package:immich_mobile/providers/duplicates.provider.dart';
import 'package:immich_mobile/providers/infrastructure/timeline.provider.dart';
import 'package:immich_mobile/routing/router.dart';
import 'package:intl/intl.dart';

@RoutePage()
class DriftDuplicatesPage extends ConsumerWidget {
  const DriftDuplicatesPage({super.key});

  void _openAsset(
    BuildContext context,
    WidgetRef ref,
    DuplicateGroup group,
    BaseAsset asset,
  ) {
    final index = group.assets.indexWhere((item) => item.id == asset.id);
    if (index < 0) return;

    AssetViewer.setAsset(ref, asset);
    unawaited(
      context.pushRoute(
        AssetViewerRoute(
          initialIndex: index,
          timelineService: ref
              .read(timelineFactoryProvider)
              .fromAssets(group.assets, TimelineOrigin.search),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final duplicates = ref.watch(duplicatesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('相似照片清理')),
      body: duplicates.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48),
                const SizedBox(height: 12),
                const Text('无法加载相似照片'),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => ref.invalidate(duplicatesProvider),
                  child: const Text('重试'),
                ),
              ],
            ),
          ),
        ),
        data: (data) {
          if (data.groups.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_awesome, size: 56),
                  SizedBox(height: 16),
                  Text('没有需要清理的相似照片'),
                ],
              ),
            );
          }

          return CustomScrollView(
            key: const PageStorageKey<String>('duplicates-scroll-list'),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                sliver: SliverList.builder(
                  itemCount: data.groups.length,
                  itemBuilder: (context, index) {
                    final group = data.groups[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: DuplicateGroupCard(
                        key: ValueKey('duplicate-group-${group.id}'),
                        group: group,
                        trashIds: data.trashIdsFor(group.id),
                        onOpenAsset: (asset) =>
                            _openAsset(context, ref, group, asset),
                        onToggleAsset: (assetId) {
                          final trashIds = {...data.trashIdsFor(group.id)};
                          if (trashIds.contains(assetId)) {
                            trashIds.remove(assetId);
                          } else if (trashIds.length < group.assets.length - 1) {
                            trashIds.add(assetId);
                          }
                          ref
                              .read(duplicatesProvider.notifier)
                              .setTrashIdsForGroup(group.id, trashIds);
                        },
                        onResolve: () => ref
                            .read(duplicatesProvider.notifier)
                            .resolveGroup(group.id),
                        onDismiss: () => ref
                            .read(duplicatesProvider.notifier)
                            .dismissGroup(group.id),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class DuplicateGroupCard extends StatelessWidget {
  const DuplicateGroupCard({
    required this.group,
    required this.trashIds,
    required this.onOpenAsset,
    this.onToggleAsset,
    this.onResolve,
    this.onDismiss,
    super.key,
  });

  final DuplicateGroup group;
  final Set<String> trashIds;
  final ValueChanged<BaseAsset> onOpenAsset;
  final ValueChanged<String>? onToggleAsset;
  final Future<void> Function()? onResolve;
  final Future<void> Function()? onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final date = group.assets.isEmpty
        ? ''
        : DateFormat.yMMMd().format(group.assets.first.createdAt.toLocal());

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    date,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  '${group.assets.length} 张',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 0.86,
              ),
              itemCount: group.assets.length,
              itemBuilder: (context, index) {
                final asset = group.assets[index];
                final selected = trashIds.contains(asset.id);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Material(
                            clipBehavior: Clip.antiAlias,
                            borderRadius: BorderRadius.circular(14),
                            child: InkWell(
                              key: ValueKey('duplicate-asset-${asset.id}'),
                              onTap: () => onOpenAsset(asset),
                              child: Thumbnail.fromAsset(asset: asset),
                            ),
                          ),
                          Positioned(
                            top: 6,
                            right: 6,
                            child: Material(
                              color: theme.colorScheme.surface.withAlpha(220),
                              shape: const CircleBorder(),
                              child: Checkbox(
                                value: selected,
                                onChanged: onToggleAsset == null
                                    ? null
                                    : (_) => onToggleAsset!(asset.id),
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                          ),
                          if (!selected)
                            Positioned(
                              left: 8,
                              bottom: 8,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(99),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 9,
                                    vertical: 4,
                                  ),
                                  child: Text(
                                    '保留',
                                    style: theme.textTheme.labelMedium?.copyWith(
                                      color: theme
                                          .colorScheme.onPrimaryContainer,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      asset.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onDismiss == null
                        ? null
                        : () => unawaited(onDismiss!()),
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('全部保留'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: trashIds.isEmpty || onResolve == null
                        ? null
                        : () => unawaited(onResolve!()),
                    icon: const Icon(Icons.delete_outline),
                    label: Text('移入回收站 (${trashIds.length})'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
