import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../models/schedule.dart';
import '../../models/task.dart';
import '../../providers/auth_provider.dart';
import '../../providers/preferences_provider.dart';
import '../../providers/schedule_provider.dart';
import '../../providers/task_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_styles.dart';
import '../../utils/feedback.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/schedule_item_card.dart';
import '../../widgets/ui.dart';
import '../tasks/task_detail_screen.dart';
import 'add_fixed_event_screen.dart';
import 'ai_schedule_flow.dart';

/// Calendar tab: week/month view with day markers, the selected day's events
/// and due tasks, and the entry point of the AI planner for that day.
class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  DateTime _selectedDate = DateTime.now();
  DateTime _focusedDate = DateTime.now();
  CalendarFormat _format = CalendarFormat.week;

  String? _uid;
  Stream<List<ScheduleItem>>? _dayStream;
  Stream<List<ScheduleItem>>? _rangeStream;
  DateTime? _rangeAnchor;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final uid = context.read<AuthProvider>().currentUser?.uid;
    if (uid != _uid) {
      _uid = uid;
      _dayStream = null;
      _rangeStream = null;
      _rangeAnchor = null;
    }
    _ensureStreams();
  }

  /// Streams are created once per selected day / visible month, never inside
  /// build, so rebuilding the screen does not restart the Firestore queries.
  void _ensureStreams() {
    final uid = _uid;
    if (uid == null) return;
    final provider = context.read<ScheduleProvider>();
    _dayStream ??= provider.watchDay(uid, _selectedDate);
    final anchor = DateTime(_focusedDate.year, _focusedDate.month);
    if (_rangeStream == null || _rangeAnchor != anchor) {
      _rangeAnchor = anchor;
      _rangeStream = provider.watchRange(
        uid,
        DateTime(anchor.year, anchor.month, 1 - 7),
        DateTime(anchor.year, anchor.month + 1, 8),
      );
    }
  }

  void _select(DateTime day, DateTime focused) {
    setState(() {
      final dayChanged = !isSameDay(day, _selectedDate);
      _selectedDate = day;
      _focusedDate = focused;
      if (dayChanged) _dayStream = null;
      _ensureStreams();
    });
  }

  void _goToToday() {
    final now = DateTime.now();
    _select(now, now);
  }

  void _addEvent() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => AddFixedEventScreen(date: _selectedDate)));
  }

  void _openItem(ScheduleItem item) {
    if (item.isTaskRow) {
      final task = context.read<TaskProvider>().byId(item.taskId ?? '');
      if (task != null) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => TaskDetailScreen(task: task)));
      }
      return;
    }
    showAppSheet<void>(
      context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SheetHeader(item.title),
          SheetAction(
            icon: Icons.edit_outlined,
            title: 'Edit event',
            description: item.isRecurring ? 'Changes only this occurrence' : null,
            onTap: () {
              Navigator.pop(ctx);
              Navigator.push(context, MaterialPageRoute(builder: (_) => AddFixedEventScreen(date: item.startTime, item: item)));
            },
          ),
          SheetAction(
            icon: Icons.delete_outline,
            title: 'Delete',
            color: ctx.cs.error,
            onTap: () {
              Navigator.pop(ctx);
              _confirmDelete(item);
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(ScheduleItem item) async {
    final provider = context.read<ScheduleProvider>();

    if (!item.isRecurring) {
      final ok = await confirmAction(
        context,
        title: 'Delete event?',
        message: '"${item.title}" will be removed from your calendar.',
      );
      if (!ok || !mounted) return;
      await guarded(context, () => provider.deleteScheduleItem(item.id), successMessage: 'Event deleted');
      return;
    }

    final scope = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete repeating event'),
        content: Text('"${item.title}" repeats. Delete just this occurrence, or every occurrence in the series?'),
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
    if (scope == null || !mounted) return;
    if (scope == 'this') {
      await guarded(context, () => provider.deleteScheduleItem(item.id), successMessage: 'Event deleted');
    } else {
      await guarded(
        context,
        () => provider.deleteScheduleSeries(item.userId, item.recurrenceId!),
        successMessage: 'Series deleted',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final aiEnabled = context.watch<PreferencesProvider>().aiSuggestions;
    final tasks = context.watch<TaskProvider>().tasks;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addEvent,
        icon: const Icon(Icons.add),
        label: const Text('Event', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.page, 20, AppSpacing.page, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Calendar', style: context.h1),
                        const SizedBox(height: 2),
                        Text(DateFormat('MMMM yyyy').format(_focusedDate), style: context.label),
                      ],
                    ),
                  ),
                  OutlinedButton(
                    onPressed: _goToToday,
                    style: OutlinedButton.styleFrom(minimumSize: const Size(72, 44)),
                    child: const Text('Today'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
              child: Row(
                children: [
                  PillChip(
                    label: 'Week',
                    selected: _format == CalendarFormat.week,
                    onTap: () => setState(() => _format = CalendarFormat.week),
                  ),
                  const SizedBox(width: 8),
                  PillChip(
                    label: 'Month',
                    selected: _format == CalendarFormat.month,
                    onTap: () => setState(() => _format = CalendarFormat.month),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
              child: _CalendarCard(
                rangeStream: _rangeStream,
                tasks: tasks,
                selected: _selectedDate,
                focused: _focusedDate,
                format: _format,
                onSelected: _select,
                onPageChanged: (focused) => setState(() {
                  _focusedDate = focused;
                  _ensureStreams();
                }),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.page, 12, AppSpacing.page, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      DateFormat('EEEE, MMMM d').format(_selectedDate),
                      style: context.h3,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (aiEnabled)
                    FilledButton.icon(
                      onPressed: () => startAiScheduleFlow(context, _selectedDate),
                      icon: const Icon(Icons.auto_awesome, size: 18),
                      label: const Text('AI Schedule'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 44),
                        backgroundColor: context.primary.withValues(alpha: 0.12),
                        foregroundColor: readableOn(context.primary, context.cs.surface),
                        elevation: 0,
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: _DayList(
                stream: _dayStream,
                day: _selectedDate,
                tasks: tasks,
                onTapItem: _openItem,
                aiEnabled: aiEnabled,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CalendarCard extends StatelessWidget {
  final Stream<List<ScheduleItem>>? rangeStream;
  final List<Task> tasks;
  final DateTime selected;
  final DateTime focused;
  final CalendarFormat format;
  final void Function(DateTime selected, DateTime focused) onSelected;
  final ValueChanged<DateTime> onPageChanged;

  const _CalendarCard({
    required this.rangeStream,
    required this.tasks,
    required this.selected,
    required this.focused,
    required this.format,
    required this.onSelected,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ScheduleItem>>(
      stream: rangeStream,
      builder: (context, snapshot) {
        // Days that have an event or a task due get a dot.
        final marked = <DateTime>{
          for (final item in snapshot.data ?? const <ScheduleItem>[])
            DateTime(item.startTime.year, item.startTime.month, item.startTime.day),
          for (final task in tasks)
            if (!task.isCompleted) DateTime(task.deadline.year, task.deadline.month, task.deadline.day),
        };
        final today = DateTime.now();
        return AppCard(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
          child: TableCalendar<int>(
            firstDay: DateTime(today.year - 1, today.month, today.day),
            lastDay: DateTime(today.year + 2, today.month, today.day),
            focusedDay: focused,
            selectedDayPredicate: (day) => isSameDay(day, selected),
            onDaySelected: onSelected,
            onPageChanged: onPageChanged,
            calendarFormat: format,
            availableCalendarFormats: const {CalendarFormat.month: 'Month', CalendarFormat.week: 'Week'},
            headerVisible: false,
            startingDayOfWeek: StartingDayOfWeek.monday,
            rowHeight: 46,
            eventLoader: (day) => marked.contains(DateTime(day.year, day.month, day.day)) ? const [1] : const [],
            calendarStyle: CalendarStyle(
              defaultTextStyle: context.body,
              weekendTextStyle: context.body,
              outsideTextStyle: context.bodyMuted.copyWith(color: context.cs.onSurfaceVariant.withValues(alpha: 0.6)),
              selectedDecoration: BoxDecoration(color: context.primary, shape: BoxShape.circle),
              selectedTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
              todayDecoration: BoxDecoration(color: context.primary.withValues(alpha: 0.16), shape: BoxShape.circle),
              todayTextStyle: TextStyle(fontWeight: FontWeight.w800, color: readableOn(context.primary, context.cs.surfaceContainer)),
              markersMaxCount: 1,
              markerSize: 5,
              markerMargin: const EdgeInsets.only(top: 2),
              markerDecoration: BoxDecoration(color: readableOn(AppColors.secondary, context.cs.surfaceContainer, minRatio: 3), shape: BoxShape.circle),
            ),
            daysOfWeekStyle: DaysOfWeekStyle(
              weekdayStyle: context.caption,
              weekendStyle: context.caption,
            ),
          ),
        );
      },
    );
  }
}

/// Events and due tasks of one day. Owns no stream: the parent creates it once
/// per selected day.
class _DayList extends StatelessWidget {
  final Stream<List<ScheduleItem>>? stream;
  final DateTime day;
  final List<Task> tasks;
  final ValueChanged<ScheduleItem> onTapItem;
  final bool aiEnabled;

  const _DayList({
    required this.stream,
    required this.day,
    required this.tasks,
    required this.onTapItem,
    required this.aiEnabled,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ScheduleItem>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const EmptyState(
            icon: Icons.cloud_off_outlined,
            title: 'Could not load this day',
            subtitle: 'Check your connection. Your calendar will refresh when you are back online.',
          );
        }
        if (snapshot.data == null) {
          return const Center(child: CircularProgressIndicator());
        }

        final schedule = [...snapshot.data!];
        final plannedTaskIds = schedule.where((s) => s.taskId != null).map((s) => s.taskId!).toSet();

        // A task due on this day appears as a "Due" row unless the AI already planned it.
        final dueRows = tasks
            .where((t) =>
                t.deadline.year == day.year &&
                t.deadline.month == day.month &&
                t.deadline.day == day.day &&
                !plannedTaskIds.contains(t.id))
            .map((t) => ScheduleItem(
                  id: '$kTaskRowPrefix${t.id}',
                  userId: t.userId,
                  title: t.isCompleted ? '${t.title} (done)' : t.title,
                  startTime: t.deadline,
                  endTime: t.deadline.add(Duration(minutes: t.estimatedMinutes)),
                  type: ScheduleTypes.task,
                  taskId: t.id,
                ));

        final items = [...schedule, ...dueRows]..sort((a, b) => a.startTime.compareTo(b.startTime));

        if (items.isEmpty) {
          return EmptyState(
            icon: Icons.event_available_outlined,
            title: 'Nothing planned',
            subtitle: aiEnabled
                ? 'Add an event, or let AI Schedule plan your tasks for this day.'
                : 'Add an event to start planning this day.',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(AppSpacing.page, 8, AppSpacing.page, 88),
          itemCount: items.length,
          itemBuilder: (context, index) => ScheduleItemCard(item: items[index], onTap: () => onTapItem(items[index])),
        );
      },
    );
  }
}
