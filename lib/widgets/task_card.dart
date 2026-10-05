import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/task.dart';
import '../theme/app_styles.dart';
import 'ui.dart';

/// One task in a list: completion circle, title, deadline, metadata, badges and a menu.
class TaskCard extends StatelessWidget {
  final Task task;
  final VoidCallback onComplete;
  final VoidCallback onTap;
  final VoidCallback onFocus;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const TaskCard({
    required this.task,
    required this.onComplete,
    required this.onTap,
    required this.onFocus,
    required this.onEdit,
    required this.onDelete,
    super.key,
  });

  void _showMenu(BuildContext context) {
    showAppSheet<void>(
      context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SheetHeader(task.title),
          if (!task.isCompleted)
            SheetAction(
              icon: Icons.timer_outlined,
              title: 'Focus on task',
              description: 'Start a ${task.estimatedMinutes}-minute focus session',
              onTap: () {
                Navigator.pop(ctx);
                onFocus();
              },
            ),
          SheetAction(
            icon: Icons.edit_outlined,
            title: 'Edit task',
            onTap: () {
              Navigator.pop(ctx);
              onEdit();
            },
          ),
          SheetAction(
            icon: Icons.delete_outline,
            title: 'Delete',
            color: ctx.cs.error,
            onTap: () {
              Navigator.pop(ctx);
              onDelete();
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCompleted = task.isCompleted;
    final pColor = priorityColor(task.priority);
    final overdue = task.status == TaskStatus.overdue;
    final timeFormat = DateFormat('MMM d, h:mm a');
    final subtasksDone = task.subtasks.where((s) => s.isCompleted).length;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Opacity(
        opacity: isCompleted ? 0.72 : 1.0,
        child: AppCard(
          color: context.cs.surface,
          radius: AppRadius.md,
          padding: EdgeInsets.zero,
          onTap: onTap,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 44 px tap area around the 22 px completion circle
              Semantics(
                button: true,
                label: isCompleted ? 'Mark ${task.title} as not done' : 'Mark ${task.title} as done',
                child: InkResponse(
                  onTap: onComplete,
                  radius: 26,
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: Center(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: isCompleted ? context.primary : pColor, width: 2),
                          color: isCompleted ? context.primary : Colors.transparent,
                        ),
                        child: isCompleted ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 12, 0, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.body.copyWith(
                          fontWeight: FontWeight.w700,
                          decoration: isCompleted ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 10,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            timeFormat.format(task.deadline),
                            style: context.label.copyWith(
                              color: overdue ? readableOn(context.cs.error, context.cs.surface) : null,
                              fontWeight: overdue ? FontWeight.w800 : FontWeight.w600,
                            ),
                          ),
                          _meta(context, Icons.timer_outlined, '${task.estimatedMinutes}m'),
                          if (task.subtasks.isNotEmpty)
                            _meta(context, Icons.checklist, '$subtasksDone/${task.subtasks.length}'),
                          if (task.reminderMinutesBefore != null)
                            Icon(Icons.notifications_active_outlined, size: 14, color: context.cs.onSurfaceVariant),
                          if (task.isRecurring)
                            Icon(Icons.repeat, size: 14, color: context.cs.onSurfaceVariant),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    TintBadge(label: task.priorityText, color: pColor),
                    const SizedBox(height: 4),
                    TintBadge(label: task.category, color: categoryColor(task.category)),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'More actions',
                onPressed: () => _showMenu(context),
                icon: Icon(Icons.more_horiz, color: context.cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _meta(BuildContext context, IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: context.cs.onSurfaceVariant),
        const SizedBox(width: 3),
        Text(text, style: context.label),
      ],
    );
  }
}
