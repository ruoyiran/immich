import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/domain/models/duplicate_group.model.dart';
import 'package:immich_mobile/generated/translations.g.dart';
import 'package:immich_mobile/presentation/widgets/images/thumbnail.widget.dart';
import 'package:immich_mobile/providers/duplicates.provider.dart';
import 'package:intl/intl.dart';

@RoutePage()
class DriftDuplicatesPage extends ConsumerWidget {
  const DriftDuplicatesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(duplicatesProvider);
    return Scaffold(
      appBar: AppBar(title: Text(context.t.review_duplicates)),
      body: state.when(
        loading: () => const Center(key: Key('duplicates-loading'), child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(error.toString(), textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => ref.read(duplicatesProvider.notifier).load(),
                child: Text(context.t.refresh),
              ),
            ],
          ),
        ),
        data: (data) {
          final group = data.currentGroup;
          if (group == null) {
            return Center(key: const Key('duplicates-empty-state'), child: Text(context.t.no_duplicates_found));
          }
          return _DuplicateGroupView(group: group, index: data.currentIndex, total: data.groups.length);
        },
      ),
    );
  }
}

class _DuplicateGroupView extends ConsumerWidget {
  const _DuplicateGroupView({required this.group, required this.index, required this.total});

  final DuplicateGroup group;
  final int index;
  final int total;

  Future<void> _resolve(BuildContext context, WidgetRef ref) async {
    final trashCount = ref.read(duplicatesProvider).value?.trashIdsFor(group.id).length ?? 0;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.t.review_duplicates),
        content: Text(context.t.assets_moved_to_trash_count(count: trashCount)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(context.t.cancel)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(context.t.confirm)),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    try {
      await ref.read(duplicatesProvider.notifier).resolveCurrent();
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  Future<void> _dismiss(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.t.keep_all),
        content: Text(context.t.bulk_keep_duplicates_confirmation(count: 1)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(context.t.cancel)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(context.t.confirm)),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(duplicatesProvider.notifier).dismissCurrent();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trashIds = ref.watch(duplicatesProvider).value?.trashIdsFor(group.id) ?? const <String>{};
    final width = MediaQuery.sizeOf(context).width;
    final columns = width >= 900
        ? 4
        : width >= 600
        ? 3
        : 2;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  DateFormat.yMMMd().format(group.captureDay),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Text('${index + 1} / $total'),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: .78,
            ),
            itemCount: group.assets.length,
            itemBuilder: (context, assetIndex) {
              final asset = group.assets[assetIndex];
              final selected = trashIds.contains(asset.id);
              final suggestedKeep = group.suggestedKeepIds.contains(asset.id);
              return Card(
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => ref.read(duplicatesProvider.notifier).toggleTrash(group.id, asset.id),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Thumbnail.remote(remoteId: asset.id, fit: BoxFit.cover, thumbhash: asset.thumbHash ?? ''),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Checkbox(
                                value: selected,
                                onChanged: (_) => ref.read(duplicatesProvider.notifier).toggleTrash(group.id, asset.id),
                              ),
                            ),
                            if (suggestedKeep)
                              Positioned(
                                left: 8,
                                bottom: 8,
                                child: Chip(label: Text(context.t.keep), visualDensity: VisualDensity.compact),
                              ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          '${DateFormat.Hm().format(asset.createdAt)}  ${asset.width ?? 0}×${asset.height ?? 0}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: index == 0 ? null : ref.read(duplicatesProvider.notifier).previous,
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: trashIds.isEmpty ? null : () => _resolve(context, ref),
                        icon: const Icon(Icons.delete_outline),
                        label: Text(context.t.to_trash),
                      ),
                    ),
                    IconButton(
                      onPressed: index >= total - 1 ? null : ref.read(duplicatesProvider.notifier).next,
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
                TextButton(onPressed: () => _dismiss(context, ref), child: Text(context.t.keep_all)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
