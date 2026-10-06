// No screen may overflow on a small phone or with enlarged text.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:timewise/screens/appearance_screen.dart';
import 'package:timewise/screens/auth/login_screen.dart';
import 'package:timewise/screens/dashboard_screen.dart';
import 'package:timewise/screens/home_screen.dart';
import 'package:timewise/screens/onboarding/quiz_screen.dart';
import 'package:timewise/screens/onboarding/welcome_screen.dart';
import 'package:timewise/screens/profile_screen.dart';
import 'package:timewise/screens/schedule/add_fixed_event_screen.dart';
import 'package:timewise/screens/schedule/schedule_screen.dart';
import 'package:timewise/screens/tasks/add_task_screen.dart';
import 'package:timewise/screens/tasks/focus_screen.dart';
import 'package:timewise/screens/tasks/task_detail_screen.dart';
import 'package:timewise/screens/tasks/tasks_screen.dart';

import 'support/test_support.dart';

void main() {
  setUpAll(loadTestFonts);

  for (final size in [(360.0, 640.0, 1.0), (320.0, 568.0, 1.0), (390.0, 844.0, 1.5), (412.0, 915.0, 2.0)]) {
    final label = '${size.$1.toInt()}x${size.$2.toInt()} text x${size.$3}';
    final screens = <String, Widget Function()>{
      'Welcome': () => const WelcomeScreen(),
      'Quiz': () => const QuizScreen(),
      'Login': () => const LoginScreen(),
      'Dashboard': () => DashboardScreen(onNavigateToTab: (_) {}),
      'Tasks': () => const TasksScreen(),
      'Calendar': () => const ScheduleScreen(),
      'Profile': () => const ProfileScreen(),
      'Appearance': () => const AppearanceScreen(),
      'Add Task': () => const AddTaskScreen(),
      'Add Event': () => AddFixedEventScreen(date: DateTime.now()),
      'Task Detail': () => TaskDetailScreen(task: seedTasks().first),
      'Focus Mode': () => const FocusScreen(),
      'Home + add sheet': () => const HomeScreen(),
    };
    screens.forEach((name, build) {
      testWidgets('$name has no overflow at $label', (tester) async {
        setDevice(tester, size.$1, size.$2, textScale: size.$3);
        final c = await makeCtx();
        final errors = ErrorSink()..install();

        if (name == 'Home + add sheet') {
          await tester.pumpWidget(harness(c, build()));
          await settle(tester, 500);
          await tester.tap(find.byIcon(Icons.add).last);
          await settle(tester, 600);
        } else {
          if (name == 'Focus Mode') await c.focus.startFocus(c.tasks.byId('t1')!);
          await pumpScreen(tester, c, build(), settleMs: 600);
        }
        if (name == 'Focus Mode') {
          await c.focus.stopFocus();
          await tester.pump(const Duration(milliseconds: 50));
        }
        errors.restore();
        final overflow = errors.errors.where((e) => e.contains('overflowed')).toList();
        expect(overflow, isEmpty, reason: overflow.join('\n'));
      });
    });
  }

  testWidgets('dark theme: the main screens build without errors', (tester) async {
    setDevice(tester, 390, 844);
    final c = await makeCtx();
    final errors = ErrorSink()..install();
    await tester.pumpWidget(harness(c, const HomeScreen()));
    await settle(tester, 500);
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await settle(tester, 500);
    for (final tab in ['Tasks', 'Calendar', 'Profile', 'Home']) {
      await tester.tap(find.text(tab).last);
      await settle(tester, 400);
    }
    errors.restore();
    expect(errors.errors, isEmpty);
  });
}
