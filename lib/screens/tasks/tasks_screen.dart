import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/task.dart';
import '../../providers/auth_provider.dart';
import '../../providers/task_provider.dart';
import '../../widgets/task_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/fade_in_list_item.dart';
import 'add_task_screen.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(length: 3, vsync: this);

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _openTask(BuildContext context, {Task? task}) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AddTaskScreen(task: task)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userId = context.watch<AuthProvider>().currentUser?.uid ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Tasks'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Upcoming'),
            Tab(text: 'Overdue'),
            Tab(text: 'Completed'),
          ],
        ),
      ),
      body: StreamBuilder<List<Task>>(
        stream: context.read<TaskProvider>().getUserTasksStream(userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return EmptyState(
              icon: Icons.error_outline,
              title: 'Could not load tasks',
              subtitle: snapshot.error.toString(),
            );
          }

          final tasks = [...?snapshot.data]
            ..sort((a, b) => a.deadline.compareTo(b.deadline));

          final upcoming = tasks.where((t) => t.status == TaskStatus.upcoming).toList();
          final overdue = tasks.where((t) => t.status == TaskStatus.overdue).toList();
          final completed = tasks.where((t) => t.status == TaskStatus.completed).toList();

          return TabBarView(
            controller: _tabController,
            children: [
              _TaskList(
                tasks: upcoming,
                emptyIcon: Icons.checklist,
                emptyTitle: 'No upcoming tasks',
                emptySubtitle: 'Tap + to add your first task',
                onTap: (t) => _openTask(context, task: t),
              ),
              _TaskList(
                tasks: overdue,
                emptyIcon: Icons.event_available,
                emptyTitle: 'Nothing overdue',
                emptySubtitle: 'You\'re all caught up',
                onTap: (t) => _openTask(context, task: t),
              ),
              _TaskList(
                tasks: completed,
                emptyIcon: Icons.task_alt,
                emptyTitle: 'No completed tasks yet',
                onTap: (t) => _openTask(context, task: t),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openTask(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _TaskList extends StatelessWidget {
  final List<Task> tasks;
  final IconData emptyIcon;
  final String emptyTitle;
  final String? emptySubtitle;
  final void Function(Task) onTap;

  const _TaskList({
    required this.tasks,
    required this.emptyIcon,
    required this.emptyTitle,
    required this.onTap,
    this.emptySubtitle,
  });

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return EmptyState(icon: emptyIcon, title: emptyTitle, subtitle: emptySubtitle);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];
        return FadeInListItem(
          index: index,
          child: TaskCard(
            task: task,
            onTap: () => onTap(task),
            onComplete: () => context.read<TaskProvider>().completeTask(task),
            onDelete: () => _confirmDeleteTask(context, task),
          ),
        );
      },
    );
  }
}

Future<void> _confirmDeleteTask(BuildContext context, Task task) async {
  final taskProvider = context.read<TaskProvider>();

  if (!task.isRecurring) {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete task?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed == true) await taskProvider.deleteTask(task.id);
    return;
  }

  final scope = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete repeating task'),
      content: const Text(
        'This task repeats. Delete just this occurrence, or every occurrence in the series?',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        TextButton(
          onPressed: () => Navigator.pop(context, 'this'),
          child: const Text('This occurrence'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, 'series'),
          child: const Text('Entire series'),
        ),
      ],
    ),
  );
  if (scope == 'this') {
    await taskProvider.deleteTask(task.id);
  } else if (scope == 'series') {
    await taskProvider.deleteTaskSeries(task.recurrenceId!);
  }
}
