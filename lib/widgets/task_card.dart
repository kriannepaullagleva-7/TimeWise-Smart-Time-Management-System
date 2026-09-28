import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/task.dart';
import '../providers/focus_provider.dart';
import '../screens/tasks/focus_screen.dart';
import '../theme/app_colors.dart';

class TaskCard extends StatefulWidget {
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

  @override
  State<TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends State<TaskCard> {
  Color _getPriorityColor() {
    switch (widget.task.priority) {
      case 3:
        return const Color(0xFFEF4444);
      case 2:
        return const Color(0xFFF59E0B);
      case 1:
      default:
        return const Color(0xFF10B981);
    }
  }

  Color _getCategoryColor() {
    final cat = widget.task.category.toLowerCase();
    if (cat == 'school') return const Color(0xFF6366F1);
    if (cat == 'work') return const Color(0xFF0EA5E9);
    if (cat == 'personal') return const Color(0xFF10B981);
    return const Color(0xFF8B5CF6);
  }

  void _showMenu(BuildContext context) {
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
              if (!widget.task.isCompleted) ...[
                ListTile(
                  leading: const Icon(Icons.timer_outlined, color: AppColors.primary),
                  title: const Text('Focus on task', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                  onTap: () {
                    Navigator.pop(context);
                    context.read<FocusProvider>().startFocus(widget.task);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const FocusScreen()));
                  },
                ),
                Divider(height: 1, color: theme.colorScheme.outline),
              ],
              ListTile(
                leading: Icon(Icons.edit_outlined, color: theme.colorScheme.onSurface),
                title: Text('Edit task', style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(context);
                  widget.onTap?.call();
                },
              ),
              Divider(height: 1, color: theme.colorScheme.outline),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Color(0xFFEF4444)),
                title: const Text('Delete', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(context);
                  widget.onDelete();
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
    final isCompleted = widget.task.isCompleted;
    final pColor = _getPriorityColor();
    final cColor = _getCategoryColor();

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.colorScheme.outline),
        ),
        child: Opacity(
          opacity: isCompleted ? 0.7 : 1.0,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: widget.onComplete,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.only(right: 12, top: 2),
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isCompleted ? AppColors.primary : pColor,
                        width: 2,
                      ),
                      color: isCompleted ? AppColors.primary : Colors.transparent,
                    ),
                    alignment: Alignment.center,
                    child: isCompleted
                        ? const Icon(Icons.check, size: 12, color: Colors.white)
                        : null,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.task.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                        decoration: isCompleted ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          DateFormat('MMM d, HH:mm').format(widget.task.deadline),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          '⏱ ${widget.task.estimatedMinutes}m',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        if (widget.task.subtasks.isNotEmpty)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.list, size: 12, color: theme.colorScheme.onSurfaceVariant),
                              const SizedBox(width: 2),
                              Text(
                                '${widget.task.subtasks.where((s) => s.isCompleted).length}/${widget.task.subtasks.length}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        if (widget.task.reminderMinutesBefore != null)
                          Icon(Icons.notifications_active, size: 12, color: theme.colorScheme.onSurfaceVariant),
                        if (widget.task.isRecurring)
                          Icon(Icons.repeat, size: 12, color: theme.colorScheme.onSurfaceVariant),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: pColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      widget.task.priorityText,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: pColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: cColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      widget.task.category,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: cColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _showMenu(context),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.more_horiz,
                    size: 20,
                    color: theme.colorScheme.onSurfaceVariant,
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
