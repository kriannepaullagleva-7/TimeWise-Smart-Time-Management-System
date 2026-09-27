import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/schedule.dart';
import '../theme/app_colors.dart';

class ScheduleItemCard extends StatelessWidget {
  final ScheduleItem item;
  final VoidCallback? onDelete;

  const ScheduleItemCard({required this.item, this.onDelete, super.key});

  Color _getBackgroundColor() {
    if (item.isFixed) return AppColors.primary.withValues(alpha: 0.1);
    if (item.isAISuggested) return AppColors.secondary.withValues(alpha: 0.1);
    if (item.type == 'break') return const Color(0xFFF59E0B).withValues(alpha: 0.1);
    return const Color(0xFF22C55E).withValues(alpha: 0.1); // Personal/Available
  }

  Color _getAccentColor() {
    if (item.isFixed) return AppColors.primary;
    if (item.isAISuggested) return AppColors.secondary;
    if (item.type == 'break') return const Color(0xFFF59E0B);
    return const Color(0xFF22C55E); // Personal/Available
  }

  String _getTypeLabel() {
    if (item.isFixed) return '🔒 Fixed';
    if (item.isAISuggested) return '✨ AI';
    if (item.type == 'break') return '☕ Break';
    return '👤 Personal';
  }

  void _showMenu(BuildContext context) {
    if (onDelete == null) return;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final theme = Theme.of(context);
        return Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: theme.colorScheme.outline),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Color(0xFFEF4444)),
                title: const Text('Delete', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(context);
                  onDelete!();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeFormat = DateFormat('h:mm a');
    final bg = _getBackgroundColor();
    final accent = _getAccentColor();
    final now = DateTime.now();
    final isPast = now.isAfter(item.endTime);

    return GestureDetector(
      onTap: onDelete != null ? () => _showMenu(context) : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accent.withValues(alpha: 0.3)),
        ),
        child: Opacity(
          opacity: isPast ? 0.6 : 1.0,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 2,
                height: 36,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${timeFormat.format(item.startTime)} - ${timeFormat.format(item.endTime)} · ${item.duration.inMinutes}m',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _getTypeLabel(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: accent,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
