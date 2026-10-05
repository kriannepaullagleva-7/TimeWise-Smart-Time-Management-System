import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:timewise/models/task.dart';
import 'package:timewise/screens/tasks/focus_screen.dart';
import 'package:timewise/screens/tasks/task_detail_screen.dart';
import 'package:timewise/screens/tasks/tasks_screen.dart';

import 'support/test_support.dart';

void main() {
  setUpAll(loadTestFonts);

  testWidgets('lists tasks most urgent first with counts', (tester) async {
    setDevice(tester, 390, 844);
    final c = await makeCtx();
    await pumpScreen(tester, c, const TasksScreen());

    expect(find.text('My Tasks'), findsOneWidget);
    expect(find.text('3 pending · 0 done'), findsOneWidget);
    final titles = tester.widgetList<Text>(find.byType(Text)).map((t) => t.data).whereType<String>().toList();
    expect(titles.indexOf('Research Paper'), lessThan(titles.indexOf('Flutter Project')));
    expect(titles.indexOf('Flutter Project'), lessThan(titles.indexOf('Math Problem Set')));
  });

  testWidgets('typing in the search box keeps the field and filters the list', (tester) async {
    setDevice(tester, 390, 844);
    final c = await makeCtx(latency: const Duration(milliseconds: 40));
    await pumpScreen(tester, c, const TasksScreen());

    await tester.enterText(find.byType(TextField), 'math');
    await tester.pump();
    expect(find.byType(TextField), findsOneWidget, reason: 'the field must not be rebuilt as a spinner');
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Math Problem Set'), findsOneWidget);
    expect(find.text('Research Paper'), findsNothing);

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pump();
    expect(find.text('No matching tasks'), findsOneWidget);
  });

  testWidgets('the Completed filter shows only finished tasks', (tester) async {
    setDevice(tester, 390, 844);
    final c = await makeCtx(tasks: [makeTask('a', title: 'Open one'), makeTask('b', title: 'Done one', completed: true)]);
    await pumpScreen(tester, c, const TasksScreen());

    await tester.tap(find.text('Completed'));
    await tester.pump();
    expect(find.text('Done one'), findsOneWidget);
    expect(find.text('Open one'), findsNothing);
  });

  testWidgets('empty list invites the user to add the first task', (tester) async {
    setDevice(tester, 390, 844);
    final c = await makeCtx(tasks: []);
    await pumpScreen(tester, c, const TasksScreen());
    expect(find.text('No tasks yet'), findsOneWidget);
    expect(find.text('Add task'), findsOneWidget);
  });

  testWidgets('a failed query shows an error with Retry, and Retry recovers', (tester) async {
    setDevice(tester, 390, 844);
    final c = await makeCtx(tasks: [makeTask('a', title: 'Recovered')], failStream: true);
    await pumpScreen(tester, c, const TasksScreen());

    expect(find.text('Could not load tasks'), findsOneWidget);
    c.taskRepo.failStream = false;
    await tester.tap(find.text('Retry'));
    await settle(tester, 300);
    expect(find.text('Recovered'), findsOneWidget);
  });

  testWidgets('a repeating task shows only its NEXT occurrence', (tester) async {
    setDevice(tester, 390, 844);
    final c = await makeCtx(tasks: [
      for (var i = 1; i <= 4; i++) makeTask('s$i', title: 'Daily review', deadline: day(i, 18), recurrenceId: 's1'),
    ]);
    await pumpScreen(tester, c, const TasksScreen());
    expect(find.text('Daily review'), findsOneWidget);
  });

  testWidgets('delete asks first; cancel keeps the task, confirm removes it', (tester) async {
    setDevice(tester, 390, 844);
    final c = await makeCtx();
    await pumpScreen(tester, c, const TasksScreen());

    await tester.tap(find.byTooltip('More actions').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Delete task?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(c.taskRepo.store.any((t) => t.id == 't1'), isTrue);

    await tester.tap(find.byTooltip('More actions').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await settle(tester, 400);
    expect(c.taskRepo.store.any((t) => t.id == 't1'), isFalse);
    expect(find.text('Task deleted'), findsOneWidget);
  });

  testWidgets('deleting a repeating task offers this occurrence or the whole series', (tester) async {
    setDevice(tester, 390, 844);
    final c = await makeCtx(tasks: [
      for (var i = 1; i <= 3; i++) makeTask('s$i', title: 'Daily review', deadline: day(i, 18), recurrenceId: 's1'),
      makeTask('other', title: 'Keep me', deadline: day(5, 10)),
    ]);
    await pumpScreen(tester, c, const TasksScreen());

    await tester.tap(find.byTooltip('More actions').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Delete repeating task'), findsOneWidget);
    await tester.tap(find.text('Entire series'));
    await settle(tester, 400);

    expect(c.taskRepo.store.map((t) => t.id), ['other']);
  });

  testWidgets('completing a task from the list marks it done', (tester) async {
    setDevice(tester, 390, 844);
    final handle = tester.ensureSemantics();
    final c = await makeCtx();
    await pumpScreen(tester, c, const TasksScreen());

    await tester.tap(find.bySemanticsLabel('Mark Research Paper as done'));
    await settle(tester, 300);
    expect(c.taskRepo.store.firstWhere((t) => t.id == 't1').isCompleted, isTrue);
    expect(find.text('2 pending · 1 done'), findsOneWidget);
    handle.dispose();
  });

  group('task detail', () {
    testWidgets('shows real subtask progress and toggles a subtask', (tester) async {
      setDevice(tester, 390, 844);
      final c = await makeCtx();
      await pumpScreen(tester, c, TaskDetailScreen(task: c.taskRepo.store.first));

      expect(find.text('1 of 2 done'), findsOneWidget);
      await tester.tap(find.text('Draft'));
      await settle(tester, 300);
      expect(c.taskRepo.store.first.subtasks.every((s) => s.isCompleted), isTrue);
      expect(find.text('2 of 2 done'), findsOneWidget);
    });

    testWidgets('mark complete / mark incomplete', (tester) async {
      setDevice(tester, 390, 844);
      final c = await makeCtx();
      await pumpScreen(tester, c, TaskDetailScreen(task: c.taskRepo.store.first));

      await tester.tap(find.text('Mark complete'));
      await settle(tester, 300);
      expect(c.taskRepo.store.first.isCompleted, isTrue);
      expect(find.text('Mark incomplete'), findsOneWidget);
      expect(find.text('Focus'), findsNothing);
    });

    testWidgets('deleting closes the screen', (tester) async {
      setDevice(tester, 390, 844);
      final c = await makeCtx();
      await pumpScreen(tester, c, TaskDetailScreen(task: c.taskRepo.store.first));

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await settle(tester, 600);
      expect(find.byType(TaskDetailScreen), findsNothing);
      expect(c.taskRepo.store.any((t) => t.id == 't1'), isFalse);
    });

    testWidgets('the screen closes itself when the task is deleted elsewhere', (tester) async {
      setDevice(tester, 390, 844);
      final c = await makeCtx();
      await pumpScreen(tester, c, TaskDetailScreen(task: c.taskRepo.store.first));
      await c.tasks.deleteTask('t1');
      await tester.pumpAndSettle();
      expect(find.byType(TaskDetailScreen), findsNothing);
    });

    testWidgets('shows reminder, repeat and description when present', (tester) async {
      setDevice(tester, 390, 844);
      final t = Task(
        id: 'x',
        userId: 'u1',
        title: 'Gym',
        description: 'Leg day',
        deadline: day(2, 18),
        priority: 1,
        category: 'Fitness',
        estimatedMinutes: 45,
        createdAt: DateTime.now(),
        reminderMinutesBefore: 60,
      );
      final c = await makeCtx(tasks: [t]);
      await pumpScreen(tester, c, TaskDetailScreen(task: t));
      expect(find.text('Leg day'), findsOneWidget);
      expect(find.textContaining('1 h before'), findsOneWidget);
      expect(find.text('Low priority'), findsOneWidget);
    });
  });

  group('focus mode', () {
    testWidgets('with no session it explains how to start one', (tester) async {
      setDevice(tester, 390, 844);
      final c = await makeCtx();
      await pumpScreen(tester, c, const FocusScreen());
      expect(find.text('No active focus session'), findsOneWidget);
    });

    testWidgets('shows the countdown, pauses and resumes', (tester) async {
      setDevice(tester, 390, 844);
      final c = await makeCtx(tasks: [makeTask('t', title: 'Study', minutes: 25)]);
      await c.focus.startFocus(c.tasks.byId('t')!);
      await pumpScreen(tester, c, const FocusScreen());

      expect(find.text('Study'), findsOneWidget);
      expect(find.text('FOCUSING'), findsOneWidget);
      await tester.tap(find.byTooltip('Pause'));
      await settle(tester, 300);
      expect(find.text('PAUSED'), findsOneWidget);
      await tester.tap(find.byTooltip('Resume'));
      await settle(tester, 300);
      expect(find.text('FOCUSING'), findsOneWidget);
      await c.focus.stopFocus();
      await tester.pump(const Duration(milliseconds: 50));
    });

    testWidgets('ending the session as finished completes the task', (tester) async {
      setDevice(tester, 390, 844);
      final c = await makeCtx(tasks: [makeTask('t', title: 'Study', minutes: 25)]);
      await c.focus.startFocus(c.tasks.byId('t')!);
      await pumpScreen(tester, c, const FocusScreen());

      await tester.tap(find.byTooltip('End session'));
      await tester.pumpAndSettle();
      expect(find.text('End focus session?'), findsOneWidget);
      await tester.tap(find.text('Finished'));
      await settle(tester, 600);

      expect(c.taskRepo.store.single.isCompleted, isTrue);
      expect(c.focus.hasSession, isFalse);
    });

    testWidgets('"Keep going" resumes a session that was paused for the dialog', (tester) async {
      setDevice(tester, 390, 844);
      final c = await makeCtx(tasks: [makeTask('t', title: 'Study', minutes: 25)]);
      await c.focus.startFocus(c.tasks.byId('t')!);
      await pumpScreen(tester, c, const FocusScreen());

      await tester.tap(find.byTooltip('End session'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keep going'));
      await settle(tester, 300);
      expect(c.focus.state.name, 'running');
      await c.focus.stopFocus();
      await tester.pump(const Duration(milliseconds: 50));
    });
  });
}
