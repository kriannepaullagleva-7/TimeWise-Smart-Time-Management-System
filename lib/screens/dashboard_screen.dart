import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/schedule.dart';
import '../models/task.dart';
import '../providers/auth_provider.dart';
import '../providers/schedule_provider.dart';
import '../providers/task_provider.dart';
import 'tasks/add_task_screen.dart';

class DashboardScreen extends StatelessWidget {
  final ValueChanged<int> onNavigateToTab;

  const DashboardScreen({required this.onNavigateToTab, super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final userId = user?.uid ?? '';
    final today = DateTime.now();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('TimeWise')),
      body: RefreshIndicator(
        onRefresh: () async {},
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('EEEE, MMMM d').format(today),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Welcome back${user?.name.isNotEmpty == true ? ', ${user!.name}' : ''}!',
                      style: TextStyle(color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.8)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              StreamBuilder<List<Task>>(
                stream: context.read<TaskProvider>().getUserTasksStream(userId),
                builder: (context, snapshot) {
                  final tasks = snapshot.data ?? [];
                  final pending = tasks.where((t) => t.status == TaskStatus.upcoming).length;
                  final overdue = tasks.where((t) => t.status == TaskStatus.overdue).length;
                  final completed = tasks.where((t) => t.status == TaskStatus.completed).length;
                  final upcomingDeadlines = tasks
                      .where((t) => t.status != TaskStatus.completed)
                      .toList()
                    ..sort((a, b) => a.deadline.compareTo(b.deadline));

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _StatCard(
                            label: 'Pending',
                            value: '$pending',
                            icon: Icons.hourglass_top_rounded,
                            color: Colors.orange,
                          ),
                          const SizedBox(width: 12),
                          _StatCard(
                            label: 'Overdue',
                            value: '$overdue',
                            icon: Icons.warning_amber_rounded,
                            color: Colors.red,
                          ),
                          const SizedBox(width: 12),
                          _StatCard(
                            label: 'Completed',
                            value: '$completed',
                            icon: Icons.check_circle_rounded,
                            color: Colors.green,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Text('Upcoming Deadlines', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      if (upcomingDeadlines.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'Nothing due — you\'re all caught up.',
                            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                          ),
                        )
                      else
                        ...upcomingDeadlines.take(3).map(
                              (t) => Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  dense: true,
                                  leading: Icon(
                                    t.status == TaskStatus.overdue ? Icons.warning_amber : Icons.flag,
                                    color: t.status == TaskStatus.overdue ? theme.colorScheme.error : theme.colorScheme.onSurfaceVariant,
                                  ),
                                  title: Text(t.title),
                                  subtitle: Text(DateFormat('MMM d, HH:mm').format(t.deadline)),
                                  trailing: Text(t.priorityText),
                                ),
                              ),
                            ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
              Text('Today\'s Schedule', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              StreamBuilder<List<ScheduleItem>>(
                stream: context.read<ScheduleProvider>().getUserScheduleStream(userId, today),
                builder: (context, snapshot) {
                  final items = [...?snapshot.data]..sort((a, b) => a.startTime.compareTo(b.startTime));
                  final now = DateTime.now();
                  final upNext = items.where((i) => i.endTime.isAfter(now)).take(3).toList();

                  if (upNext.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Nothing scheduled for the rest of today.',
                        style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    );
                  }

                  final timeFormat = DateFormat('HH:mm');
                  return Column(
                    children: upNext
                        .map(
                          (i) => Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              dense: true,
                              leading: const Icon(Icons.schedule),
                              title: Text(i.title),
                              subtitle: Text('${timeFormat.format(i.startTime)} - ${timeFormat.format(i.endTime)}'),
                            ),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const AddTaskScreen()),
                      ),
                      icon: const Icon(Icons.add_task),
                      label: const Text('Quick Add Task'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => onNavigateToTab(2),
                      icon: const Icon(Icons.auto_awesome),
                      label: const Text('AI Assistant'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 12, color: color)),
          ],
        ),
      ),
    );
  }
}
