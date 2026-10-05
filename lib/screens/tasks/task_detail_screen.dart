import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/task.dart';
import '../../providers/task_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_styles.dart';
import '../../utils/feedback.dart';
import '../../widgets/task_actions.dart';
import '../../widgets/ui.dart';
import 'add_task_screen.dart';

/// Everything about one task: status, focus progress, subtasks, details and
/// the main actions. Reads the live task, so edits made elsewhere show at once.
class TaskDetailScreen extends StatelessWidget {
  final Task task;

  const TaskDetailScreen({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskProvider>();
    final live = provider.byId(task.id);
    if (live == null) {
      // Deleted (here or on another screen): leave once the frame is built.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted && Navigator.of(context).canPop()) Navigator.of(context).pop();
      });
      return const Scaffold(body: SizedBox.shrink());
    }
    return _TaskDetailView(task: live);
  }
}

class _TaskDetailView extends StatelessWidget {
  final Task task;

  const _TaskDetailView({required this.task});

  String _focusText(int seconds) {
    final minutes = seconds ~/ 60;
    return minutes < 1 ? (seconds == 0 ? '0 min' : '${seconds}s') : '$minutes min';
  }

  Future<void> _toggleSubtask(BuildContext context, int index, bool done) {
    final updated = [...task.subtasks];
    updated[index] = updated[index].copyWith(isCompleted: done);
    return guarded(context, () => context.read<TaskProvider>().setSubtasks(task, updated));
  }

  @override
  Widget build(BuildContext context) {
    final pColor = priorityColor(task.priority);
    final status = task.status;
    final subtasksDone = task.subtasks.where((s) => s.isCompleted).length;
    final estimatedSeconds = task.estimatedMinutes * 60;
    final focusProgress = estimatedSeconds == 0 ? 0.0 : (task.elapsedSeconds / estimatedSeconds).clamp(0.0, 1.0);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            ScreenHeader(
              title: task.title,
              trailing: AppBackButton(
                icon: Icons.edit_outlined,
                tooltip: 'Edit task',
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AddTaskScreen(task: task))),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(AppSpacing.page, 0, AppSpacing.page, 24),
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      TintBadge(label: '${task.priorityText} priority', color: pColor),
                      TintBadge(label: task.category, color: categoryColor(task.category)),
                      if (status == TaskStatus.completed) const TintBadge(label: 'Done', color: AppColors.success, icon: Icons.check),
                      if (status == TaskStatus.overdue) const TintBadge(label: 'Overdue', color: AppColors.error, icon: Icons.warning_amber),
                      if (status == TaskStatus.inProgress) TintBadge(label: 'In progress', color: context.primary, icon: Icons.timer_outlined),
                      if (task.isRecurring) TintBadge(label: 'Repeats', color: context.cs.onSurfaceVariant, icon: Icons.repeat),
                    ],
                  ),
                  const SizedBox(height: 16),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text('FOCUS TIME', style: context.caption.copyWith(letterSpacing: 1.2))),
                            Text(
                              '${_focusText(task.elapsedSeconds)} of ${task.estimatedMinutes} min',
                              style: context.body.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: focusProgress,
                            minHeight: 8,
                            backgroundColor: context.cs.outline,
                          ),
                        ),
                        if (task.subtasks.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(child: Text('SUBTASKS', style: context.caption.copyWith(letterSpacing: 1.2))),
                              Text('$subtasksDone of ${task.subtasks.length} done', style: context.body.copyWith(fontWeight: FontWeight.w800)),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  AppCard(
                    child: Column(
                      children: [
                        _DetailRow(Icons.calendar_today_outlined, 'Deadline', DateFormat('EEE, MMM d, yyyy · h:mm a').format(task.deadline)),
                        _DetailRow(Icons.timer_outlined, 'Estimated time', '${task.estimatedMinutes} min'),
                        _DetailRow(
                          Icons.notifications_none,
                          'Reminder',
                          task.reminderMinutesBefore == null
                              ? 'None'
                              : '${task.reminderMinutesBefore! >= 60 ? '${task.reminderMinutesBefore! ~/ 60} h' : '${task.reminderMinutesBefore} min'} before'
                                  ' (${DateFormat('MMM d, h:mm a').format(task.reminderTime!)})',
                        ),
                        if (task.isRecurring) _DetailRow(Icons.repeat, 'Repeat', task.recurrence.summary),
                        _DetailRow(Icons.add_circle_outline, 'Created', DateFormat('MMM d, yyyy').format(task.createdAt), last: true),
                      ],
                    ),
                  ),
                  if (task.subtasks.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    AppCard(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        children: [
                          for (var i = 0; i < task.subtasks.length; i++)
                            CheckboxListTile(
                              value: task.subtasks[i].isCompleted,
                              onChanged: (v) => _toggleSubtask(context, i, v ?? false),
                              controlAffinity: ListTileControlAffinity.leading,
                              title: Text(
                                task.subtasks[i].title,
                                style: context.body.copyWith(
                                  decoration: task.subtasks[i].isCompleted ? TextDecoration.lineThrough : null,
                                  color: task.subtasks[i].isCompleted ? context.cs.onSurfaceVariant : null,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                  if (task.description.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('DESCRIPTION', style: context.caption.copyWith(letterSpacing: 1.2)),
                          const SizedBox(height: 8),
                          Text(task.description, style: context.body.copyWith(height: 1.5)),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            BottomActionBar(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (task.isCompleted)
                    OutlinedButton.icon(
                      onPressed: () => toggleTaskCompletion(context, task),
                      icon: const Icon(Icons.undo),
                      label: const Text('Mark incomplete'),
                      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                    )
                  else
                    GradientButton(
                      label: 'Mark complete',
                      icon: Icons.check,
                      onPressed: () => toggleTaskCompletion(context, task),
                    ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      if (!task.isCompleted) ...[
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => startFocusOn(context, task),
                            icon: const Icon(Icons.timer_outlined),
                            label: const Text('Focus'),
                            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final deleted = await confirmAndDeleteTask(context, task);
                            if (deleted && context.mounted && Navigator.of(context).canPop()) Navigator.of(context).pop();
                          },
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Delete'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            foregroundColor: readableOn(context.cs.error, context.cs.surface),
                            side: BorderSide(color: context.cs.error.withValues(alpha: 0.5)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool last;

  const _DetailRow(this.icon, this.label, this.value, {this.last = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: context.cs.onSurfaceVariant),
          const SizedBox(width: 12),
          SizedBox(width: 104, child: Text(label, style: context.label)),
          Expanded(child: Text(value, style: context.body.copyWith(fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }
}
