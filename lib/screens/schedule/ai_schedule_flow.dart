import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/schedule.dart';
import '../../providers/auth_provider.dart';
import '../../providers/schedule_provider.dart';
import '../../providers/task_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_styles.dart';
import '../../utils/app_logger.dart';
import '../../utils/feedback.dart';
import 'ai_schedule_preview_screen.dart';

/// The whole "AI Schedule" journey, shared by the Dashboard card and the
/// Calendar button: check set-up and tasks, show the analyzing dialog while
/// Gemini works, then open the review screen (or a readable error).
Future<void> startAiScheduleFlow(BuildContext context, DateTime date) async {
  final user = context.read<AuthProvider>().currentUser;
  final taskProvider = context.read<TaskProvider>();
  final scheduleProvider = context.read<ScheduleProvider>();
  if (user == null) return;

  if (!scheduleProvider.isAIConfigured) {
    showMessage(
      context,
      'The AI planner is not set up in this build. Run the app with --dart-define=GEMINI_API_KEY=your_key.',
      error: true,
    );
    return;
  }

  final dayLabel = DateFormat('EEE, MMM d').format(date);
  if (TaskProvider.planningCandidates(taskProvider.tasks, date).isEmpty) {
    showMessage(context, 'No pending tasks to plan for $dayLabel. Add a task first.');
    return;
  }

  final navigator = Navigator.of(context, rootNavigator: true);
  unawaited(showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const AnalyzingDialog(),
  ));

  Future<List<ScheduleItem>> generate() => scheduleProvider.generateAISchedulePreview(
        userId: user.uid,
        tasks: taskProvider.tasks,
        scheduleDate: date,
        user: user,
      );

  List<ScheduleItem>? preview;
  Object? failure;
  try {
    preview = await generate();
  } catch (e, st) {
    AppLogger.error('AIFlow', 'generation failed', e, st);
    failure = e;
  }

  navigator.pop(); // close the analyzing dialog
  if (!context.mounted) return;

  if (failure != null) {
    showMessage(context, friendlyError(failure), error: true);
    return;
  }

  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => AIedSchedulePreviewScreen(
        userId: user.uid,
        scheduleDate: date,
        initialItems: preview!,
        onRegenerate: generate,
      ),
    ),
  );
}

/// Non-dismissible dialog shown while the AI request runs.
class AnalyzingDialog extends StatefulWidget {
  const AnalyzingDialog({super.key});

  @override
  State<AnalyzingDialog> createState() => _AnalyzingDialogState();
}

class _AnalyzingDialogState extends State<AnalyzingDialog> {
  static const _steps = [
    'Checking your tasks',
    'Reviewing deadlines',
    'Finding available time',
    'Creating your schedule',
  ];

  int _step = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Progress cues only: the request itself reports no intermediate stages.
    _timer = Timer.periodic(const Duration(milliseconds: 1500), (_) {
      if (mounted && _step < _steps.length - 1) setState(() => _step++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(shape: BoxShape.circle, gradient: AppColors.aiGradient),
                child: const Icon(Icons.auto_awesome, color: Colors.white, size: 34),
              ),
              const SizedBox(height: 20),
              Text('AI is analyzing your schedule…', style: context.h3, textAlign: TextAlign.center),
              const SizedBox(height: 6),
              Text('This usually takes a few seconds.', style: context.label, textAlign: TextAlign.center),
              const SizedBox(height: 20),
              for (var i = 0; i < _steps.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 22,
                        height: 22,
                        child: i < _step
                            ? Icon(Icons.check_circle, size: 20, color: readableOn(AppColors.success, context.cs.surface, minRatio: 3))
                            : i == _step
                                ? const Padding(
                                    padding: EdgeInsets.all(2),
                                    child: CircularProgressIndicator(strokeWidth: 2.4),
                                  )
                                : Icon(Icons.radio_button_unchecked, size: 20, color: context.cs.outlineVariant),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _steps[i],
                          style: context.body.copyWith(
                            color: i <= _step ? context.cs.onSurface : context.cs.onSurfaceVariant,
                            fontWeight: i == _step ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
