
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/focus_provider.dart';
import '../../providers/task_provider.dart';
import '../../theme/app_styles.dart';
import '../../utils/feedback.dart';
import '../../widgets/ui.dart';

/// Pomodoro-style countdown for one task. The session keeps running when the
/// user leaves this screen; the Home screen shows a strip to return to it.
class FocusScreen extends StatelessWidget {
  const FocusScreen({super.key});

  static String _clock(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _finish(BuildContext context, {required bool completed}) async {
    final focus = context.read<FocusProvider>();
    final tasks = context.read<TaskProvider>();
    final task = focus.currentTask;
    final navigator = Navigator.of(context);
    final messenger = context;
    await guarded(messenger, () async {
      if (completed && task != null) await tasks.completeTask(task);
      await focus.stopFocus();
    }, successMessage: completed ? 'Task completed. Nice work!' : 'Focus time saved');
    if (navigator.canPop()) navigator.pop();
  }

  Future<void> _confirmStop(BuildContext context) async {
    final focus = context.read<FocusProvider>();
    final wasRunning = focus.state == FocusState.running;
    if (wasRunning) await focus.pauseFocus();
    if (!context.mounted) return;

    final minutes = focus.elapsedSeconds ~/ 60;
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('End focus session?'),
        content: Text('You have focused for $minutes min. Did you finish "${focus.currentTask?.title ?? 'this task'}"?'),
        actionsOverflowDirection: VerticalDirection.down,
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Keep going')),
          TextButton(onPressed: () => Navigator.pop(ctx, 'stop'), child: const Text('Not finished')),
          FilledButton(onPressed: () => Navigator.pop(ctx, 'done'), child: const Text('Finished')),
        ],
      ),
    );

    if (!context.mounted) return;
    if (choice == null) {
      if (wasRunning) focus.resumeFocus();
      return;
    }
    await _finish(context, completed: choice == 'done');
  }

  @override
  Widget build(BuildContext context) {
    final focus = context.watch<FocusProvider>();
    final task = focus.currentTask;

    if (task == null) {
      return Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              const ScreenHeader(title: 'Focus'),
              const Expanded(
                child: EmptyFocus(),
              ),
            ],
          ),
        ),
      );
    }

    final finished = focus.state == FocusState.finished;
    final running = focus.state == FocusState.running;
    final ringColor = context.primary;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            ScreenHeader(
              title: 'Focus mode',
              subtitle: 'Leaving this screen keeps the timer running',
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final ring = (constraints.maxHeight * 0.5).clamp(180.0, 260.0);
                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: constraints.maxHeight),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            task.title,
                            style: context.h1,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          TintBadge(label: task.category, color: categoryColor(task.category)),
                          const SizedBox(height: 28),
                          Semantics(
                            label: finished
                                ? 'Time is up'
                                : '${_clock(focus.remainingSeconds)} remaining${running ? '' : ', paused'}',
                            child: SizedBox(
                              width: ring,
                              height: ring,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  SizedBox.expand(
                                    child: TweenAnimationBuilder<double>(
                                      tween: Tween<double>(begin: 0, end: focus.progress),
                                      duration: const Duration(milliseconds: 500),
                                      builder: (context, value, _) => CircularProgressIndicator(
                                        value: value,
                                        strokeWidth: 12,
                                        backgroundColor: context.cs.outline,
                                        color: ringColor,
                                        strokeCap: StrokeCap.round,
                                      ),
                                    ),
                                  ),
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _clock(focus.remainingSeconds),
                                        style: TextStyle(
                                          fontSize: ring > 220 ? 48 : 40,
                                          fontWeight: FontWeight.w800,
                                          color: context.cs.onSurface,
                                          fontFeatures: const [FontFeature.tabularFigures()],
                                        ),
                                      ),
                                      Text(
                                        finished ? 'TIME IS UP' : (running ? 'FOCUSING' : 'PAUSED'),
                                        style: context.caption.copyWith(
                                          letterSpacing: 2,
                                          color: finished ? readableOn(context.primary, context.cs.surface) : null,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '${focus.elapsedSeconds ~/ 60} of ${focus.totalSeconds ~/ 60} min focused',
                            style: context.bodyMuted,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.page, 8, AppSpacing.page, 20),
              child: finished
                  ? Column(
                      children: [
                        GradientButton(
                          label: 'Mark completed',
                          icon: Icons.check,
                          gradient: const LinearGradient(colors: [Color(0xFF15803D), Color(0xFF166534)]),
                          onPressed: () => _finish(context, completed: true),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => focus.extendFocus(15),
                                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                                child: const Text('Add 15 min'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => _finish(context, completed: false),
                                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                                child: const Text('Exit'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Tooltip(
                          message: running ? 'Pause' : 'Resume',
                          child: Material(
                            color: context.primary,
                            shape: const CircleBorder(),
                            elevation: 3,
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: () => running ? focus.pauseFocus() : focus.resumeFocus(),
                              child: SizedBox(
                                width: 72,
                                height: 72,
                                child: Icon(running ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white, size: 38),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 28),
                        Tooltip(
                          message: 'End session',
                          child: Material(
                            color: context.cs.surfaceContainer,
                            shape: CircleBorder(side: BorderSide(color: context.cs.outline)),
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: () => _confirmStop(context),
                              child: SizedBox(
                                width: 56,
                                height: 56,
                                child: Icon(Icons.stop_rounded, color: context.cs.error, size: 28),
                              ),
                            ),
                          ),
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

/// Shown if Focus is opened with no session (for example after it was ended).
class EmptyFocus extends StatelessWidget {
  const EmptyFocus({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.timer_off_outlined, size: 56, color: context.cs.onSurfaceVariant),
            const SizedBox(height: 16),
            Text('No active focus session', style: context.h3),
            const SizedBox(height: 8),
            Text('Start one from a task: open its menu and choose "Focus on task".',
                style: context.bodyMuted, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
