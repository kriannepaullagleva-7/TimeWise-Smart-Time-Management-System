import 'package:flutter/material.dart';

import '../models/task.dart';

class TaskCard extends StatelessWidget {
  final Task task;
  final VoidCallback onDelete;
  final VoidCallback onComplete;
  final VoidCallback? onTap;

  const TaskCard({
    required this.task,
    required this.onDelete,
    required this.onComplete,
    this.onTap,
    super.key,
  });

  Color _getPriorityColor() {
    switch (task.priority) {
      case 1:
        return Colors.green;
      case 3:
        return Colors.red;
      case 2:
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOverdue = task.status == TaskStatus.overdue;
    final daysLeft = task.deadline.difference(DateTime.now()).inDays;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: onTap,
        leading: Checkbox(
          value: task.isCompleted,
          onChanged: (_) => onComplete(),
        ),
        title: Text(
          task.title,
          style: TextStyle(
            decoration: task.isCompleted ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getPriorityColor().withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    task.priorityText,
                    style: TextStyle(
                      fontSize: 12,
                      color: _getPriorityColor(),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(task.category, style: const TextStyle(fontSize: 12)),
                Text(
                  '${task.estimatedMinutes} min',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                if (task.reminderMinutesBefore != null)
                  const Icon(Icons.notifications_active, size: 14, color: Colors.grey),
                if (task.isRecurring)
                  const Icon(Icons.repeat, size: 14, color: Colors.grey),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              task.isCompleted
                  ? 'Completed'
                  : isOverdue
                      ? 'Overdue by ${-daysLeft} days'
                      : daysLeft == 0
                          ? 'Due today'
                          : 'Due in $daysLeft days',
              style: TextStyle(
                fontSize: 12,
                color: isOverdue ? Colors.red : Colors.grey[600],
                fontWeight: isOverdue ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'delete') onDelete();
            if (value == 'edit') onTap?.call();
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'edit', child: Text('Edit')),
            const PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
      ),
    );
  }
}
