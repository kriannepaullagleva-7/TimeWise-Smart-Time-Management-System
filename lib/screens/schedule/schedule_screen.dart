import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../providers/auth_provider.dart';
import '../../providers/task_provider.dart';
import '../../providers/schedule_provider.dart';
import '../../models/schedule.dart';
import '../../models/task.dart';
import '../../theme/app_colors.dart';
import '../../widgets/schedule_item_card.dart';
import '../../widgets/empty_state.dart';
import 'ai_schedule_preview_screen.dart';
import 'add_fixed_event_screen.dart';
import '../../services/ai_service.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  late DateTime _selectedDate;
  late DateTime _focusedDate;
  CalendarFormat _calendarFormat = CalendarFormat.week;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _focusedDate = DateTime.now();
  }

  Future<List<ScheduleItem>> _generatePreview() async {
    final authProvider = context.read<AuthProvider>();
    final taskProvider = context.read<TaskProvider>();
    final scheduleProvider = context.read<ScheduleProvider>();
    final user = authProvider.currentUser;
    if (user == null) return [];

    final tasks = await taskProvider.getActiveTasksStream(user.uid).first;

    return scheduleProvider.generateAISchedulePreview(
      userId: user.uid,
      tasks: tasks,
      scheduleDate: _selectedDate,
      user: user,
    );
  }

  Future<void> _generateAISchedule() async {
    final scheduleProvider = context.read<ScheduleProvider>();
    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.currentUser?.uid ?? '';

    if (!scheduleProvider.isAIConfigured) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'AI Schedule Assistant is not configured. Launch the app with '
            '--dart-define=GEMINI_API_KEY=your_key to enable it.',
          ),
        ),
      );
      return;
    }

    try {
      final preview = await _generatePreview();
      if (!mounted) return;

      if (preview.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No pending tasks to schedule for this day')),
        );
        return;
      }

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AIedSchedulePreviewScreen(
            userId: userId,
            scheduleDate: _selectedDate,
            initialItems: preview,
            onRegenerate: _generatePreview,
          ),
        ),
      );
    } on AIConfigException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    }
  }

  void _addFixedEvent() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AddFixedEventScreen(date: _selectedDate)),
    );
  }

  Future<void> _confirmDeleteScheduleItem(ScheduleItem item) async {
    final scheduleProvider = context.read<ScheduleProvider>();

    if (!item.isRecurring) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete event?'),
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
        if (mounted) {
          await scheduleProvider.deleteScheduleItem(item.id);
        }
      }
      return;
    }

    if (!mounted) return;

    final scope = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete repeating event'),
        content: const Text(
          'This event repeats. Delete just this occurrence, or every occurrence in the series?',
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
      await scheduleProvider.deleteScheduleItem(item.id);
    } else if (scope == 'series') {
      await scheduleProvider.deleteScheduleSeries(item.recurrenceId!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final userId = context.watch<AuthProvider>().currentUser?.uid ?? '';
    final monthFormat = DateFormat('MMMM yyyy');
    final dayFormat = DateFormat('EEEE, MMMM d');

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            // Custom Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Calendar',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        monthFormat.format(_focusedDate),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          final now = DateTime.now();
                          setState(() {
                            _selectedDate = now;
                            _focusedDate = now;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                          ),
                          child: const Text(
                            'Today',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Format Toggle
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _buildFormatBtn(CalendarFormat.month, 'Month'),
                  const SizedBox(width: 8),
                  _buildFormatBtn(CalendarFormat.week, 'Week'),
                ],
              ),
            ),
            
            const SizedBox(height: 16),

            // Calendar
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: theme.colorScheme.outline),
              ),
              child: TableCalendar(
                firstDay: DateTime.now().subtract(const Duration(days: 365)),
                lastDay: DateTime.now().add(const Duration(days: 365)),
                focusedDay: _focusedDate,
                selectedDayPredicate: (day) => isSameDay(day, _selectedDate),
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDate = selectedDay;
                    _focusedDate = focusedDay;
                  });
                },
                onPageChanged: (focusedDay) {
                  setState(() {
                    _focusedDate = focusedDay;
                  });
                },
                calendarFormat: _calendarFormat,
                availableCalendarFormats: const {
                  CalendarFormat.month: 'Month',
                  CalendarFormat.week: 'Week',
                },
                headerVisible: false,
                calendarStyle: CalendarStyle(
                  selectedDecoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  todayDecoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  todayTextStyle: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                  selectedTextStyle: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                daysOfWeekStyle: DaysOfWeekStyle(
                  weekdayStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurfaceVariant),
                  weekendStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Schedule Items Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    dayFormat.format(_selectedDate),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: _generateAISchedule,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.secondary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.auto_awesome, size: 14, color: AppColors.secondary),
                              SizedBox(width: 4),
                              Text(
                                'AI Schedule',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.secondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 12),

            // Schedule List
            Expanded(
              child: StreamBuilder<List<ScheduleItem>>(
                stream: context.read<ScheduleProvider>().getUserScheduleStream(userId, _selectedDate),
                builder: (context, scheduleSnapshot) {
                  return StreamBuilder<List<Task>>(
                    stream: context.read<TaskProvider>().getUserTasksStream(userId),
                    builder: (context, taskSnapshot) {
                      if (scheduleSnapshot.connectionState == ConnectionState.waiting && taskSnapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (scheduleSnapshot.hasError || taskSnapshot.hasError) {
                        return EmptyState(
                          icon: Icons.error_outline,
                          title: 'Could not load calendar data',
                          subtitle: scheduleSnapshot.error?.toString() ?? taskSnapshot.error?.toString(),
                        );
                      }

                      final schedules = [...?scheduleSnapshot.data];
                      final scheduledTaskIds = schedules.where((s) => s.taskId != null).map((s) => s.taskId!).toSet();
                      
                      final tasks = (taskSnapshot.data ?? []).where((t) {
                        return t.deadline.year == _selectedDate.year &&
                               t.deadline.month == _selectedDate.month &&
                               t.deadline.day == _selectedDate.day &&
                               !scheduledTaskIds.contains(t.id);
                      });

                      final combinedItems = [
                        ...schedules,
                        ...tasks.map((t) => ScheduleItem(
                          id: t.id, // We prefix with task_ to avoid ID collisions if any, though UUIDs shouldn't collide
                          userId: t.userId,
                          title: t.title,
                          startTime: t.deadline,
                          endTime: t.deadline.add(Duration(minutes: t.estimatedMinutes)),
                          type: 'task',
                          isFixed: false,
                          taskId: t.id,
                        ))
                      ];

                      combinedItems.sort((a, b) => a.startTime.compareTo(b.startTime));

                      if (combinedItems.isEmpty) {
                        return EmptyState(
                          icon: Icons.calendar_today,
                          title: 'No schedule for this day',
                          subtitle: 'Add fixed events or use AI Schedule to plan your day.',
                          action: ElevatedButton(
                            onPressed: _addFixedEvent,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Add Event'),
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                        itemCount: combinedItems.length,
                        itemBuilder: (context, index) {
                          final item = combinedItems[index];
                          return ScheduleItemCard(
                            item: item,
                            onDelete: () {
                              if (item.type == 'task') {
                                context.read<TaskProvider>().deleteTask(item.taskId!);
                              } else {
                                _confirmDeleteScheduleItem(item);
                              }
                            },
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 72), // Avoid bottom nav
        child: FloatingActionButton.extended(
          onPressed: _addFixedEvent,
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add),
          label: const Text('Event', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _buildFormatBtn(CalendarFormat format, String label) {
    final theme = Theme.of(context);
    final isSelected = _calendarFormat == format;
    
    return GestureDetector(
      onTap: () => setState(() => _calendarFormat = format),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : theme.colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : theme.colorScheme.outline,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            color: isSelected ? Colors.white : theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
