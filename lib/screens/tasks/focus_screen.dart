import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/focus_provider.dart';
import '../../providers/task_provider.dart';
import '../../theme/app_colors.dart';

class FocusScreen extends StatefulWidget {
  const FocusScreen({super.key});

  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen> {
  String _formatTime(int seconds) {
    final m = (seconds / 60).floor();
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _confirmStop(BuildContext context, FocusProvider focusProvider, TaskProvider taskProvider) {
    final task = focusProvider.currentTask;
    if (task == null) return;
    
    // Pause before showing dialog
    if (focusProvider.state == FocusState.running) {
      focusProvider.pauseFocus();
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End Focus Session'),
        content: const Text('Did you complete this task?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              focusProvider.stopFocus();
              Navigator.pop(context); // Go back to previous screen
            },
            child: const Text('No, just stop'),
          ),
          FilledButton(
            onPressed: () {
              taskProvider.completeTask(task);
              focusProvider.stopFocus();
              Navigator.pop(context);
              Navigator.pop(context);
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Yes, completed!'),
          ),
        ],
      ),
    ).then((value) {
      // If dialog was dismissed without choosing, and we were running, we should perhaps remain paused
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final focusProvider = context.watch<FocusProvider>();
    final taskProvider = context.read<TaskProvider>();
    
    final task = focusProvider.currentTask;
    if (task == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Focus')),
        body: const Center(child: Text('No active focus session.')),
      );
    }

    final isFinished = focusProvider.state == FocusState.finished;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () {
                      // Just go back, keep running in background
                      Navigator.pop(context);
                    },
                  ),
                  Text(
                    'Focus Mode',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(width: 48), // Balance
                ],
              ),
            ),
            
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/images/timewise_pet.png',
                      width: 140,
                      height: 140,
                    ),
                    const SizedBox(height: 32),
                    Text(
                      task.title,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      task.category,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 48),
                    
                    // Timer display
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 240,
                          height: 240,
                          child: TweenAnimationBuilder<double>(
                            tween: Tween<double>(begin: 0, end: focusProvider.progress),
                            duration: const Duration(milliseconds: 500),
                            builder: (context, value, child) {
                              return CircularProgressIndicator(
                                value: value,
                                strokeWidth: 12,
                                backgroundColor: theme.colorScheme.outline,
                                color: AppColors.primary,
                                strokeCap: StrokeCap.round,
                              );
                            },
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _formatTime(focusProvider.remainingSeconds),
                              style: TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.w900,
                                color: theme.colorScheme.onSurface,
                                fontFeatures: const [FontFeature.tabularFigures()],
                              ),
                            ),
                            if (focusProvider.state == FocusState.paused)
                              Text(
                                'PAUSED',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onSurfaceVariant,
                                  letterSpacing: 2,
                                ),
                              ),
                            if (isFinished)
                              Text(
                                'TIME IS UP',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                  letterSpacing: 2,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            // Controls
            Padding(
              padding: const EdgeInsets.all(32),
              child: isFinished 
                ? Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () {
                            taskProvider.completeTask(task);
                            focusProvider.stopFocus();
                            Navigator.pop(context);
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF22C55E),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: const Text('Mark Completed', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () {
                          focusProvider.stopFocus();
                          Navigator.pop(context);
                        },
                        child: Text(
                          'Keep uncompleted and exit',
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: () {
                          if (focusProvider.state == FocusState.running) {
                            focusProvider.pauseFocus();
                          } else {
                            focusProvider.resumeFocus(task);
                          }
                        },
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.3),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Icon(
                            focusProvider.state == FocusState.running ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 36,
                          ),
                        ),
                      ),
                      const SizedBox(width: 32),
                      GestureDetector(
                        onTap: () => _confirmStop(context, focusProvider, taskProvider),
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainer,
                            shape: BoxShape.circle,
                            border: Border.all(color: theme.colorScheme.outline),
                          ),
                          child: const Icon(
                            Icons.stop_rounded,
                            color: Color(0xFFEF4444),
                            size: 28,
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
