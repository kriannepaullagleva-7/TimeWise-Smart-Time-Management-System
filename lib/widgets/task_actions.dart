import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/task.dart';
import '../providers/focus_provider.dart';
import '../providers/task_provider.dart';
import '../screens/tasks/focus_screen.dart';
import '../utils/feedback.dart';
import '../theme/app_styles.dart';
import 'ui.dart';

/// Actions shared by the Dashboard, Tasks list, Task Detail and Calendar, so
/// every screen asks the same questions and reports errors the same way.

Future<void> toggleTaskCompletion(BuildContext context, Task task) async {
  final provider = context.read<TaskProvider>();
  await guarded(
    context,
    () => task.isCompleted ? provider.reopenTask(task) : provider.completeTask(task),
  );
}

/// Asks for confirmation (and for repeating tasks, whether to delete one
/// occurrence or the whole series), then deletes. Returns true if deleted.
Future<bool> confirmAndDeleteTask(BuildContext context, Task task) async {
  final provider = context.read<TaskProvider>();

  if (!task.isRecurring) {
    final ok = await confirmAction(
      context,
      title: 'Delete task?',
      message: '"${task.title}" will be removed. This cannot be undone.',
    );
    if (!ok || !context.mounted) return false;
    return guarded(context, () => provider.deleteTask(task.id), successMessage: 'Task deleted');
  }

  final scope = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Delete repeating task'),
      content: Text('"${task.title}" repeats. Delete just this occurrence, or every occurrence in the series?'),
      actionsOverflowDirection: VerticalDirection.down,
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(ctx, 'this'), child: const Text('This occurrence')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: ctx.cs.error, foregroundColor: Colors.white),
          onPressed: () => Navigator.pop(ctx, 'series'),
          child: const Text('Entire series'),
        ),
      ],
    ),
  );
  if (scope == null || !context.mounted) return false;
  if (scope == 'this') {
    return guarded(context, () => provider.deleteTask(task.id), successMessage: 'Task deleted');
  }
  return guarded(
    context,
    () => provider.deleteTaskSeries(task.userId, task.recurrenceId!),
    successMessage: 'Series deleted',
  );
}

/// Starts (or continues) a focus session on [task] and opens Focus Mode.
Future<void> startFocusOn(BuildContext context, Task task) async {
  if (task.isCompleted) return;
  final focus = context.read<FocusProvider>();
  final navigator = Navigator.of(context);
  await focus.startFocus(task);
  navigator.push(MaterialPageRoute(builder: (_) => const FocusScreen()));
}
