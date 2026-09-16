import 'package:flutter/material.dart';
import 'package:immich_mobile/domain/models/timeline.model.dart';
import 'package:intl/intl.dart';

class TimelineScrollDateOverlay extends StatelessWidget {
  const TimelineScrollDateOverlay({super.key, required this.date, required this.header, required this.visible});

  final DateTime? date;
  final HeaderType? header;
  final bool visible;

  String _formatDate(BuildContext context, DateTime date, HeaderType header) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    final isCurrentYear = date.year == DateTime.now().year;
    final formatter = switch (header) {
      HeaderType.month => isCurrentYear ? DateFormat.MMMM(locale) : DateFormat.yMMMM(locale),
      HeaderType.day || HeaderType.monthAndDay => isCurrentYear ? DateFormat.MMMd(locale) : DateFormat.yMMMd(locale),
      HeaderType.none => null,
    };

    return formatter?.format(date) ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final date = this.date;
    final header = this.header;
    final showLabel = visible && date != null && header != null && header != HeaderType.none;
    final colorScheme = Theme.of(context).colorScheme;

    return ExcludeSemantics(
      child: IgnorePointer(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          reverseDuration: const Duration(milliseconds: 140),
          child: showLabel
              ? ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.85),
                  child: Material(
                    key: const ValueKey('timeline-scroll-date-overlay'),
                    elevation: 4,
                    color: colorScheme.inverseSurface.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(18),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      child: Text(
                        _formatDate(context, date, header),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: colorScheme.onInverseSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                )
              : const SizedBox.shrink(key: ValueKey('timeline-scroll-date-overlay-hidden')),
        ),
      ),
    );
  }
}
