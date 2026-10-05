import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/schedule.dart';
import '../theme/app_colors.dart';
import '../theme/app_styles.dart';
import 'ui.dart';

/// Visual identity of a schedule row: color, icon and label by kind.
class ScheduleKind {
  final Color color;
  final IconData icon;
  final String label;
  const ScheduleKind(this.color, this.icon, this.label);

  static const _due = Color(0xFF8B5CF6);
  static const _meal = Color(0xFFF97316);

  static ScheduleKind of(ScheduleItem item) {
    if (item.isTaskRow) return const ScheduleKind(_due, Icons.flag_outlined, 'Due');
    if (item.isFixed) return ScheduleKind(AppColors.primary, Icons.lock_outline, 'Fixed');
    if (item.isAISuggested) {
      switch (item.type) {
        case ScheduleTypes.breakTime:
          return const ScheduleKind(AppColors.warning, Icons.coffee_outlined, 'AI break');
        case ScheduleTypes.meal:
          return const ScheduleKind(_meal, Icons.restaurant_outlined, 'AI meal');
        default:
          return const ScheduleKind(AppColors.secondary, Icons.auto_awesome, 'AI');
      }
    }
    switch (item.type) {
      case ScheduleTypes.breakTime:
        return const ScheduleKind(AppColors.warning, Icons.coffee_outlined, 'Break');
      case ScheduleTypes.meal:
        return const ScheduleKind(_meal, Icons.restaurant_outlined, 'Meal');
      case ScheduleTypes.exercise:
        return const ScheduleKind(AppColors.success, Icons.fitness_center, 'Exercise');
      default:
        return ScheduleKind(AppColors.success, Icons.person_outline, ScheduleTypes.label(item.type));
    }
  }
}

class ScheduleItemCard extends StatelessWidget {
  final ScheduleItem item;
  final VoidCallback? onTap;

  /// Finished items are dimmed on the calendar; a plan being reviewed is not.
  final bool dimPast;

  const ScheduleItemCard({required this.item, this.onTap, this.dimPast = true, super.key});

  @override
  Widget build(BuildContext context) {
    final kind = ScheduleKind.of(item);
    final timeFormat = DateFormat('h:mm a');
    final isPast = dimPast && !item.isTaskRow && DateTime.now().isAfter(item.endTime);
    final timeText = item.isTaskRow
        ? 'Due ${timeFormat.format(item.startTime)} · ${item.duration.inMinutes}m'
        : '${timeFormat.format(item.startTime)} – ${timeFormat.format(item.endTime)} · ${item.duration.inMinutes}m';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Opacity(
        opacity: isPast ? 0.65 : 1.0,
        child: Semantics(
          button: onTap != null,
          label: '${item.title}, ${kind.label}, $timeText',
          child: Material(
            color: kind.color.withValues(alpha: context.isDark ? 0.16 : 0.10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              side: BorderSide(color: kind.color.withValues(alpha: 0.30)),
            ),
            child: InkWell(
              customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 38,
                      decoration: BoxDecoration(color: kind.color, borderRadius: BorderRadius.circular(2)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.body.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 2),
                          Text(timeText, style: context.label),
                          if (item.note != null && item.note!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                item.note!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.label.copyWith(fontStyle: FontStyle.italic, fontWeight: FontWeight.w500),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    TintBadge(label: kind.label, color: kind.color, icon: kind.icon),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
