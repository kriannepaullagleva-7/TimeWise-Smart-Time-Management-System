import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/schedule.dart';
import '../models/task.dart';
import '../providers/auth_provider.dart';
import '../providers/preferences_provider.dart';
import '../providers/schedule_provider.dart';
import '../providers/task_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_styles.dart';
import '../utils/day_usage.dart';
import '../widgets/empty_state.dart';
import '../widgets/schedule_item_card.dart';
import '../widgets/task_actions.dart';
import '../widgets/task_card.dart';
import '../widgets/ui.dart';
import 'schedule/add_fixed_event_screen.dart';
import 'schedule/ai_schedule_flow.dart';
import 'tasks/add_task_screen.dart';
import 'tasks/task_detail_screen.dart';

/// Home tab: today's progress, the AI planner, quick actions, today's
/// schedule and the most urgent pending tasks.
class DashboardScreen extends StatelessWidget {
  final ValueChanged<int> onNavigateToTab;

  const DashboardScreen({super.key, required this.onNavigateToTab});

  static String greeting(DateTime now) {
    if (now.hour < 12) return 'Good morning';
    if (now.hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final taskProvider = context.watch<TaskProvider>();
    final now = DateTime.now();
    final firstName = (user?.name ?? '').trim().split(' ').first;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => taskProvider.retry(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.page, 20, AppSpacing.page, 24),
            children: [
              _Header(
                greeting: '${greeting(now)}${firstName.isEmpty ? '' : ', $firstName'}',
                date: DateFormat('EEEE, MMMM d').format(now),
                streak: taskProvider.calculateStreak(taskProvider.tasks),
              ),
              const SizedBox(height: 20),
              if (taskProvider.streamError != null)
                _LoadError(onRetry: taskProvider.retry)
              else if (!taskProvider.isLoaded)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 80),
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                _ProgressRow(tasks: taskProvider.tasks, now: now),
                const SizedBox(height: 16),
                if (context.watch<PreferencesProvider>().aiSuggestions) ...[
                  _AiCard(tasks: taskProvider.tasks, now: now),
                  const SizedBox(height: 20),
                ],
                _QuickActions(onNavigateToTab: onNavigateToTab),
                const SizedBox(height: 24),
                if (user != null) _TodaySchedule(userId: user.uid, onViewAll: () => onNavigateToTab(2)),
                const SizedBox(height: 24),
                _PendingTasks(tasks: taskProvider.tasks, onViewAll: () => onNavigateToTab(1)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String greeting;
  final String date;
  final int streak;

  const _Header({required this.greeting, required this.date, required this.streak});

  @override
  Widget build(BuildContext context) {
    final amber = readableOn(AppColors.warning, context.cs.surface);
    return Row(
      children: [
        Image.asset('assets/images/timewise_pet.png', width: 48, height: 48, excludeFromSemantics: true),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(date, style: context.label),
              const SizedBox(height: 2),
              Text(greeting, style: context.h1.copyWith(fontSize: 20), maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
        Semantics(
          label: '$streak day streak',
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.local_fire_department, size: 18, color: amber),
                const SizedBox(width: 4),
                Text('$streak', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: amber)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ProgressRow extends StatelessWidget {
  final List<Task> tasks;
  final DateTime now;

  const _ProgressRow({required this.tasks, required this.now});

  @override
  Widget build(BuildContext context) {
    final todayTasks = tasks
        .where((t) => t.deadline.year == now.year && t.deadline.month == now.month && t.deadline.day == now.day)
        .toList();
    final done = todayTasks.where((t) => t.isCompleted).length;
    final total = todayTasks.length;
    final streak = context.read<TaskProvider>().calculateStreak(tasks, now: now);

    final today = DateTime(now.year, now.month, now.day);
    final monday = DateTime(today.year, today.month, today.day - (today.weekday - 1));
    final days = TaskProvider.completionDays(tasks);
    final amber = readableOn(AppColors.warning, context.cs.surfaceContainer);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: AppCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  SizedBox(
                    width: 52,
                    height: 52,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox.expand(
                          child: CircularProgressIndicator(
                            value: total == 0 ? 0 : done / total,
                            backgroundColor: context.cs.outline,
                            strokeWidth: 5,
                          ),
                        ),
                        Text(
                          total == 0 ? '–' : '${((done / total) * 100).round()}%',
                          style: context.body.copyWith(fontSize: 12, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('TODAY', style: context.caption.copyWith(letterSpacing: 1.2)),
                        const SizedBox(height: 2),
                        Text(
                          total == 0 ? 'No tasks due' : '$done of $total done',
                          style: context.body.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: AppCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('STREAK', style: context.caption.copyWith(letterSpacing: 1.2)),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text('$streak', style: context.h1.copyWith(fontSize: 26, height: 1)),
                      const SizedBox(width: 4),
                      Text('day${streak == 1 ? '' : 's'}', style: context.label.copyWith(color: amber)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      for (var i = 0; i < 7; i++)
                        Expanded(
                          child: Column(
                            children: [
                              Container(
                                height: 6,
                                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                                decoration: BoxDecoration(
                                  color: days.contains(DateTime(monday.year, monday.month, monday.day + i))
                                      ? AppColors.warning
                                      : context.cs.outline,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'MTWTFSS'[i],
                                style: TextStyle(fontSize: 11, color: context.cs.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Entry point to the AI planner. States the situation from the real task
/// list and starts the real planner (no canned text).
class _AiCard extends StatelessWidget {
  final List<Task> tasks;
  final DateTime now;

  const _AiCard({required this.tasks, required this.now});

  @override
  Widget build(BuildContext context) {
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final pending = TaskProvider.collapseSeries(tasks.where((t) => !t.isCompleted).toList(), now: now);
    final overdue = pending.where((t) => t.deadline.isBefore(now)).length;
    final dueToday = pending.where((t) => !t.deadline.isBefore(now) && t.deadline.isBefore(tomorrow)).length;
    final highPriority = pending.where((t) => t.priority == 3).length;

    final String message;
    if (pending.isEmpty) {
      message = 'You have nothing pending. Add a task and I will plan your time around your fixed events.';
    } else {
      final parts = <String>[
        '${pending.length} pending task${pending.length == 1 ? '' : 's'}',
        if (overdue > 0) '$overdue overdue',
        if (dueToday > 0) '$dueToday due today',
        if (highPriority > 0) '$highPriority high priority',
      ];
      message = '${parts.join(' · ')}. Let the AI fit them around your fixed events and sleep.';
    }

    const onCard = Colors.white;
    return Container(
      decoration: BoxDecoration(gradient: AppColors.aiGradient, borderRadius: BorderRadius.circular(AppRadius.lg)),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.auto_awesome, size: 18, color: onCard),
              ),
              const SizedBox(width: 10),
              const Text(
                'AI SCHEDULE',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.4, color: onCard),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(message, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, height: 1.45, color: onCard)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _CardButton(
                  label: 'Plan today',
                  filled: true,
                  onPressed: () => startAiScheduleFlow(context, today),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _CardButton(
                  label: 'Plan tomorrow',
                  filled: false,
                  onPressed: () => startAiScheduleFlow(context, tomorrow),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CardButton extends StatelessWidget {
  final String label;
  final bool filled;
  final VoidCallback onPressed;

  const _CardButton({required this.label, required this.filled, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm));
    return SizedBox(
      height: 48,
      child: filled
          ? FilledButton(
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF003DA5),
                shape: shape,
                textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
              ),
              child: Text(label),
            )
          : OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white, width: 1.5),
                shape: shape,
                textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
              ),
              child: Text(label),
            ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  final ValueChanged<int> onNavigateToTab;

  const _QuickActions({required this.onNavigateToTab});

  @override
  Widget build(BuildContext context) {
    void push(Widget screen) => Navigator.push(context, MaterialPageRoute(builder: (_) => screen));

    Widget action(IconData icon, String label, VoidCallback onTap) {
      return Expanded(
        child: AppCard(
          padding: const EdgeInsets.symmetric(vertical: 14),
          radius: AppRadius.md,
          onTap: onTap,
          child: Column(
            children: [
              Icon(icon, size: 24, color: context.primary),
              const SizedBox(height: 6),
              Text(label, style: context.label.copyWith(color: context.cs.onSurface), textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        action(Icons.add_task, 'Add task', () => push(const AddTaskScreen())),
        const SizedBox(width: 8),
        action(Icons.event_available_outlined, 'Add event', () => push(AddFixedEventScreen(date: DateTime.now()))),
        const SizedBox(width: 8),
        action(Icons.calendar_month_outlined, 'Calendar', () => onNavigateToTab(2)),
        const SizedBox(width: 8),
        action(Icons.checklist_rtl, 'Tasks', () => onNavigateToTab(1)),
      ],
    );
  }
}

/// Free-time bar and today's schedule. Owns its Firestore stream so rebuilds
/// of the dashboard do not restart the query.
class _TodaySchedule extends StatefulWidget {
  final String userId;
  final VoidCallback onViewAll;

  const _TodaySchedule({required this.userId, required this.onViewAll});

  @override
  State<_TodaySchedule> createState() => _TodayScheduleState();
}

class _TodayScheduleState extends State<_TodaySchedule> {
  late final Stream<List<ScheduleItem>> _stream =
      context.read<ScheduleProvider>().watchDay(widget.userId, DateTime.now());

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    return StreamBuilder<List<ScheduleItem>>(
      stream: _stream,
      builder: (context, snapshot) {
        final items = [...?snapshot.data]..sort((a, b) => a.startTime.compareTo(b.startTime));
        final usage = DayUsage.compute(
          items,
          DateTime.now(),
          wakeMinutes: user?.wakeMinutes ?? 7 * 60,
          sleepMinutes: user?.sleepMinutes ?? 23 * 60,
        );
        final free = usage.freeMinutes < 0 ? 0 : usage.freeMinutes;
        final freeText = free >= 60 ? '${(free / 60).toStringAsFixed(1)} h free' : '$free min free';

        Widget segment(int minutes, Color color, {bool last = false}) => minutes <= 0
            ? const SizedBox.shrink()
            : Expanded(
                flex: minutes,
                child: Container(
                  height: 14,
                  margin: EdgeInsets.only(right: last ? 0 : 3),
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
                ),
              );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text('AVAILABLE TODAY', style: context.caption.copyWith(letterSpacing: 1.2))),
                      TintBadge(label: freeText, color: AppColors.success),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Semantics(
                    label: 'Today: ${usage.fixedMinutes} minutes fixed, ${usage.aiMinutes} minutes AI planned, '
                        '${usage.breakMinutes} minutes breaks, $free minutes free',
                    child: ExcludeSemantics(
                      child: Row(
                        children: [
                          segment(usage.fixedMinutes, AppColors.primary),
                          segment(usage.aiMinutes, AppColors.secondary),
                          segment(usage.breakMinutes, AppColors.warning),
                          segment(usage.otherMinutes, const Color(0xFF8B5CF6)),
                          segment(free, AppColors.success.withValues(alpha: 0.55), last: true),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 14,
                    runSpacing: 4,
                    children: [
                      _Legend(AppColors.primary, 'Fixed'),
                      _Legend(AppColors.secondary, 'AI plan'),
                      _Legend(AppColors.warning, 'Break'),
                      _Legend(AppColors.success.withValues(alpha: 0.55), 'Free'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SectionHeader("Today's schedule", actionLabel: 'Calendar', onAction: widget.onViewAll),
            const SizedBox(height: 4),
            if (snapshot.hasError)
              AppCard(
                child: Text('Could not load today\'s schedule. Pull down to retry.', style: context.bodyMuted),
              )
            else if (snapshot.connectionState == ConnectionState.waiting && snapshot.data == null)
              const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
            else if (items.isEmpty)
              AppCard(
                child: Row(
                  children: [
                    Icon(Icons.event_busy_outlined, color: context.cs.onSurfaceVariant),
                    const SizedBox(width: 12),
                    Expanded(child: Text('Nothing scheduled today.', style: context.bodyMuted)),
                  ],
                ),
              )
            else
              for (final item in items) ScheduleItemCard(item: item),
          ],
        );
      },
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;

  const _Legend(this.color, this.label);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(label, style: context.label),
      ],
    );
  }
}

class _PendingTasks extends StatelessWidget {
  final List<Task> tasks;
  final VoidCallback onViewAll;

  const _PendingTasks({required this.tasks, required this.onViewAll});

  @override
  Widget build(BuildContext context) {
    final pending = TaskProvider.collapseSeries(tasks.where((t) => !t.isCompleted).toList())
      ..sort((a, b) {
        final aLate = a.status == TaskStatus.overdue;
        final bLate = b.status == TaskStatus.overdue;
        if (aLate != bLate) return aLate ? -1 : 1;
        if (a.priority != b.priority) return b.priority.compareTo(a.priority);
        return a.deadline.compareTo(b.deadline);
      });
    final shown = pending.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader('Pending tasks', actionLabel: pending.length > 5 ? 'View all (${pending.length})' : 'View all', onAction: onViewAll),
        const SizedBox(height: 4),
        if (shown.isEmpty)
          const EmptyState(
            compact: true,
            title: 'All caught up',
            subtitle: 'No pending tasks. Add one from the + button.',
          )
        else
          for (final task in shown)
            TaskCard(
              task: task,
              onComplete: () => toggleTaskCompletion(context, task),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TaskDetailScreen(task: task))),
              onFocus: () => startFocusOn(context, task),
              onEdit: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AddTaskScreen(task: task))),
              onDelete: () => confirmAndDeleteTask(context, task),
            ),
      ],
    );
  }
}

class _LoadError extends StatelessWidget {
  final VoidCallback onRetry;

  const _LoadError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: EmptyState(
        icon: Icons.cloud_off_outlined,
        title: 'Could not load your tasks',
        subtitle: 'Check your connection and try again.',
        action: FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Retry')),
      ),
    );
  }
}
