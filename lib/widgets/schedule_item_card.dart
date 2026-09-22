import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/schedule.dart';

class ScheduleItemCard extends StatelessWidget {
  final ScheduleItem item;
  final VoidCallback? onDelete;

  const ScheduleItemCard({required this.item, this.onDelete, super.key});

  IconData _getTypeIcon() {
    switch (item.type) {
      case ScheduleTypes.class_:
        return Icons.school;
      case ScheduleTypes.work:
        return Icons.work;
      case ScheduleTypes.appointment:
        return Icons.event;
      case ScheduleTypes.travel:
        return Icons.directions_car;
      case ScheduleTypes.breakTime:
        return Icons.free_breakfast;
      case ScheduleTypes.meal:
        return Icons.restaurant;
      case ScheduleTypes.sleep:
        return Icons.bedtime;
      case ScheduleTypes.exercise:
        return Icons.fitness_center;
      case ScheduleTypes.personal:
        return Icons.self_improvement;
      default:
        return Icons.task_alt;
    }
  }

  Color _getTypeColor() {
    switch (item.type) {
      case ScheduleTypes.class_:
        return Colors.purple;
      case ScheduleTypes.work:
        return Colors.blue;
      case ScheduleTypes.appointment:
        return Colors.orange;
      case ScheduleTypes.travel:
        return Colors.brown;
      case ScheduleTypes.breakTime:
        return Colors.grey;
      case ScheduleTypes.meal:
        return Colors.amber[800]!;
      case ScheduleTypes.sleep:
        return Colors.indigo;
      case ScheduleTypes.exercise:
        return Colors.green;
      case ScheduleTypes.personal:
        return Colors.pink;
      default:
        return Colors.teal;
    }
  }

  @override
  Widget build(BuildContext context) {
    final timeFormat = DateFormat('HH:mm');
    final color = _getTypeColor();
    final now = DateTime.now();
    final isCurrent = now.isAfter(item.startTime) && now.isBefore(item.endTime);
    final isPast = now.isAfter(item.endTime);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: isCurrent
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: color, width: 2),
            )
          : null,
      child: Opacity(
        opacity: isPast ? 0.6 : 1,
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.15),
            child: Icon(_getTypeIcon(), color: color),
          ),
          title: Text(
            item.title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                '${timeFormat.format(item.startTime)} - ${timeFormat.format(item.endTime)}',
                style: const TextStyle(fontSize: 12),
              ),
              if (item.note != null && item.note!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  item.note!,
                  style: TextStyle(fontSize: 11, color: Colors.grey[600], fontStyle: FontStyle.italic),
                ),
              ],
              const SizedBox(height: 4),
              Wrap(
                spacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (item.isFixed) ...[
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.push_pin, size: 12, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text('Fixed', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                    ]),
                  ] else if (item.isAISuggested) ...[
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.auto_awesome, size: 12, color: Colors.deepPurple),
                      const SizedBox(width: 4),
                      const Text(
                        'AI Suggested',
                        style: TextStyle(fontSize: 11, color: Colors.deepPurple),
                      ),
                    ]),
                  ],
                  if (item.isRecurring)
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.repeat, size: 12, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text('Repeats', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                    ]),
                ],
              ),
            ],
          ),
          trailing: onDelete != null
              ? IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: onDelete,
                )
              : null,
        ),
      ),
    );
  }
}
