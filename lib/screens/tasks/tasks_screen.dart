import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/task.dart';
import '../../providers/auth_provider.dart';
import '../../providers/task_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/task_card.dart';
import '../../widgets/empty_state.dart';
import 'add_task_screen.dart';
import 'task_detail_screen.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  String _searchQuery = '';
  String _filter = 'all'; // 'all', 'pending', 'completed'

  void _openTask(BuildContext context, {Task? task}) {
    if (task == null) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const AddTaskScreen()),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => TaskDetailScreen(task: task)),
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
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
              onPressed: () => Navigator.pop(context, true), 
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (confirmed == true) {
        if (context.mounted) {
          await taskProvider.deleteTask(task.id);
        }
      }
      return;
    }

    if (!context.mounted) return;
    
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
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final userId = context.watch<AuthProvider>().currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: StreamBuilder<List<Task>>(
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

            final allTasks = snapshot.data ?? [];
            final pendingCount = allTasks.where((t) => !t.isCompleted).length;
            final completedCount = allTasks.length - pendingCount;

            final filteredTasks = allTasks.where((t) {
              final matchesSearch = t.title.toLowerCase().contains(_searchQuery.toLowerCase());
              final matchesFilter = _filter == 'all'
                  ? true
                  : _filter == 'pending'
                      ? !t.isCompleted
                      : t.isCompleted;
              return matchesSearch && matchesFilter;
            }).toList();

            // Sort logic: incomplete first, then by priority (3 is high), then deadline
            filteredTasks.sort((a, b) {
              if (a.isCompleted != b.isCompleted) return a.isCompleted ? 1 : -1;
              if (a.priority != b.priority) return b.priority.compareTo(a.priority);
              return a.deadline.compareTo(b.deadline);
            });

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'My Tasks',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$pendingCount pending · $completedCount done',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),

                // Search Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: theme.colorScheme.outline),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.search, size: 20, color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            onChanged: (val) => setState(() => _searchQuery = val),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: theme.colorScheme.onSurface,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Search tasks...',
                              hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                        if (_searchQuery.isNotEmpty)
                          GestureDetector(
                            onTap: () => setState(() => _searchQuery = ''),
                            child: Icon(Icons.close, size: 16, color: theme.colorScheme.onSurfaceVariant),
                          ),
                      ],
                    ),
                  ),
                ),

                // Filter Tabs
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  child: Row(
                    children: [
                      _buildFilterBtn('all', 'All'),
                      const SizedBox(width: 8),
                      _buildFilterBtn('pending', 'Pending', badgeCount: pendingCount),
                      const SizedBox(width: 8),
                      _buildFilterBtn('completed', 'Completed'),
                    ],
                  ),
                ),

                // Task List
                Expanded(
                  child: filteredTasks.isEmpty
                      ? EmptyState(
                          icon: Icons.checklist,
                          title: 'No tasks found',
                          subtitle: _searchQuery.isNotEmpty ? 'Try a different search term.' : 'Add your first task to get started.',
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                          itemCount: filteredTasks.length,
                          itemBuilder: (context, index) {
                            final task = filteredTasks[index];
                            return TaskCard(
                              task: task,
                              onComplete: () {
                                context.read<TaskProvider>().updateTask(task.copyWith(isCompleted: !task.isCompleted));
                              },
                              onDelete: () => _confirmDeleteTask(context, task),
                              onTap: () => _openTask(context, task: task),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildFilterBtn(String value, String label, {int? badgeCount}) {
    final theme = Theme.of(context);
    final isSelected = _filter == value;
    
    return GestureDetector(
      onTap: () => setState(() => _filter = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : theme.colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? AppColors.primary : theme.colorScheme.outline,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: isSelected ? Colors.white : theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (badgeCount != null && badgeCount > 0 && value == 'pending')
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.white.withValues(alpha: 0.25) : AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    badgeCount.toString(),
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: isSelected ? Colors.white : AppColors.primary,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
