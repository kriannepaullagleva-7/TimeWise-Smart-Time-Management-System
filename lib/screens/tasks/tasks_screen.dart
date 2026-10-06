import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/task.dart';
import '../../providers/task_provider.dart';
import '../../theme/app_styles.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/task_actions.dart';
import '../../widgets/task_card.dart';
import '../../widgets/ui.dart';
import 'add_task_screen.dart';
import 'task_detail_screen.dart';

enum _TaskFilter { all, pending, completed }

/// Tasks tab: search, filter and act on every task. Repeating tasks show only
/// their next occurrence so a daily task does not bury the list.
class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  _TaskFilter _filter = _TaskFilter.all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Task> _visible(List<Task> all) {
    final needle = _query.trim().toLowerCase();
    final filtered = all.where((t) {
      final matchesSearch = needle.isEmpty ||
          t.title.toLowerCase().contains(needle) ||
          t.category.toLowerCase().contains(needle);
      final matchesFilter = switch (_filter) {
        _TaskFilter.all => true,
        _TaskFilter.pending => !t.isCompleted,
        _TaskFilter.completed => t.isCompleted,
      };
      return matchesSearch && matchesFilter;
    }).toList();

    // Searching shows every match; browsing hides future repeats of a series.
    final base = needle.isEmpty ? TaskProvider.collapseSeries(filtered) : filtered;
    return base
      ..sort((a, b) {
        if (a.isCompleted != b.isCompleted) return a.isCompleted ? 1 : -1;
        final aLate = a.status == TaskStatus.overdue;
        final bLate = b.status == TaskStatus.overdue;
        if (aLate != bLate) return aLate ? -1 : 1;
        if (a.priority != b.priority) return b.priority.compareTo(a.priority);
        return a.deadline.compareTo(b.deadline);
      });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskProvider>();
    final all = provider.tasks;
    // Counts match the list: a repeating series counts once (its next occurrence).
    final listed = TaskProvider.collapseSeries(all);
    final pendingCount = listed.where((t) => !t.isCompleted).length;
    final doneCount = listed.length - pendingCount;

    Widget body;
    if (provider.streamError != null) {
      body = EmptyState(
        icon: Icons.cloud_off_outlined,
        title: 'Could not load tasks',
        subtitle: 'Check your connection and try again.',
        action: FilledButton.icon(onPressed: provider.retry, icon: const Icon(Icons.refresh), label: const Text('Retry')),
      );
    } else if (!provider.isLoaded) {
      body = const Center(child: CircularProgressIndicator());
    } else {
      final tasks = _visible(all);
      if (tasks.isEmpty) {
        final searching = _query.trim().isNotEmpty;
        body = EmptyState(
          icon: searching ? Icons.search_off : Icons.checklist,
          title: searching
              ? 'No matching tasks'
              : _filter == _TaskFilter.completed
                  ? 'Nothing completed yet'
                  : all.isEmpty
                      ? 'No tasks yet'
                      : 'No tasks here',
          subtitle: searching
              ? 'Try a different word, or clear the search.'
              : all.isEmpty
                  ? 'Add your first task and TimeWise will help you plan it.'
                  : 'Change the filter to see your other tasks.',
          action: all.isEmpty && !searching
              ? FilledButton.icon(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddTaskScreen())),
                  icon: const Icon(Icons.add),
                  label: const Text('Add task'),
                )
              : null,
        );
      } else {
        body = ListView.builder(
          padding: const EdgeInsets.fromLTRB(AppSpacing.page, 0, AppSpacing.page, 24),
          itemCount: tasks.length,
          itemBuilder: (context, index) {
            final task = tasks[index];
            return TaskCard(
              task: task,
              onComplete: () => toggleTaskCompletion(context, task),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TaskDetailScreen(task: task))),
              onFocus: () => startFocusOn(context, task),
              onEdit: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AddTaskScreen(task: task))),
              onDelete: () => confirmAndDeleteTask(context, task),
            );
          },
        );
      }
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.page, 20, AppSpacing.page, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('My Tasks', style: context.h1),
                  const SizedBox(height: 2),
                  Text(
                    provider.isLoaded ? '$pendingCount pending · $doneCount done' : 'Loading…',
                    style: context.label,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
              child: Container(
                decoration: BoxDecoration(
                  color: context.cs.surfaceContainer,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: context.cs.outline),
                ),
                child: Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 16, right: 4),
                      child: Icon(Icons.search, size: 20, color: context.cs.onSurfaceVariant),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: (v) => setState(() => _query = v),
                        textInputAction: TextInputAction.search,
                        style: context.body.copyWith(fontWeight: FontWeight.w600),
                        decoration: InputDecoration(
                          hintText: 'Search by title or category',
                          hintStyle: context.bodyMuted,
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
                        ),
                      ),
                    ),
                    if (_query.isNotEmpty)
                      IconButton(
                        tooltip: 'Clear search',
                        icon: Icon(Icons.close, size: 20, color: context.cs.onSurfaceVariant),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.page, 12, AppSpacing.page, 12),
              child: Wrap(
                spacing: 8,
                children: [
                  PillChip(label: 'All', selected: _filter == _TaskFilter.all, onTap: () => setState(() => _filter = _TaskFilter.all)),
                  PillChip(
                    label: 'Pending',
                    count: pendingCount,
                    selected: _filter == _TaskFilter.pending,
                    onTap: () => setState(() => _filter = _TaskFilter.pending),
                  ),
                  PillChip(
                    label: 'Completed',
                    selected: _filter == _TaskFilter.completed,
                    onTap: () => setState(() => _filter = _TaskFilter.completed),
                  ),
                ],
              ),
            ),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}
