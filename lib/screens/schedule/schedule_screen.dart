import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../models/schedule.dart';
import '../../providers/auth_provider.dart';
import '../../providers/schedule_provider.dart';
import '../../providers/task_provider.dart';
import '../../services/ai_service.dart';
import '../../widgets/schedule_item_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/fade_in_list_item.dart';
import 'add_fixed_event_screen.dart';
import 'ai_schedule_preview_screen.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
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
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
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
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
          ],
        ),
      );
      if (confirmed == true) await scheduleProvider.deleteScheduleItem(item.id);
      return;
    }

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
    final userId = context.watch<AuthProvider>().currentUser?.uid ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Schedule'),
        actions: [
          IconButton(
            icon: const Icon(Icons.event_available),
            onPressed: _addFixedEvent,
            tooltip: 'Add fixed event',
          ),
          IconButton(
            icon: const Icon(Icons.auto_awesome),
            onPressed: _generateAISchedule,
            tooltip: 'Generate AI Schedule',
          ),
        ],
      ),
      body: StreamBuilder(
        stream: context.read<ScheduleProvider>().getUserScheduleStream(
          userId,
          _selectedDate,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return EmptyState(
              icon: Icons.error_outline,
              title: 'Could not load schedule',
              subtitle: snapshot.error.toString(),
            );
          }

          final schedules = [...?snapshot.data]
            ..sort((a, b) => a.startTime.compareTo(b.startTime));

          return Column(
            children: [
              Container(
                color: Theme.of(context).colorScheme.surfaceContainer,
                padding: const EdgeInsets.all(8),
                child: TableCalendar(
                  firstDay: DateTime.now().subtract(const Duration(days: 365)),
                  lastDay: DateTime.now().add(const Duration(days: 365)),
                  focusedDay: _selectedDate,
                  selectedDayPredicate: (day) => isSameDay(day, _selectedDate),
                  onDaySelected: (selectedDay, focusedDay) {
                    setState(() => _selectedDate = selectedDay);
                  },
                  calendarFormat: CalendarFormat.week,
                ),
              ),
              Expanded(
                child: schedules.isEmpty
                    ? EmptyState(
                        icon: Icons.calendar_today,
                        title: 'No schedule for this day',
                        action: Wrap(
                          spacing: 8,
                          alignment: WrapAlignment.center,
                          children: [
                            OutlinedButton.icon(
                              onPressed: _addFixedEvent,
                              icon: const Icon(Icons.event_available),
                              label: const Text('Add Fixed Event'),
                            ),
                            ElevatedButton.icon(
                              onPressed: _generateAISchedule,
                              icon: const Icon(Icons.auto_awesome),
                              label: const Text('Generate Schedule'),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: schedules.length,
                        itemBuilder: (context, index) {
                          final item = schedules[index];
                          return FadeInListItem(
                            index: index,
                            child: ScheduleItemCard(
                              item: item,
                              onDelete: () => _confirmDeleteScheduleItem(item),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
