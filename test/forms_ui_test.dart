import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:timewise/models/recurrence.dart';
import 'package:timewise/models/schedule.dart';
import 'package:timewise/models/task.dart';
import 'package:timewise/models/user.dart';
import 'package:timewise/screens/schedule/add_fixed_event_screen.dart';
import 'package:timewise/screens/tasks/add_task_screen.dart';

import 'support/test_support.dart';

void main() {
  setUpAll(loadTestFonts);

  group('Add / edit task', () {
    testWidgets('an empty name is refused with a message and nothing is saved', (tester) async {
      setDevice(tester, 390, 844);
      final c = await makeCtx(tasks: []);
      await pumpScreen(tester, c, const AddTaskScreen());

      await tester.tap(find.text('Add task'));
      await tester.pump();
      expect(find.text('Give the task a name.'), findsOneWidget);
      expect(c.taskRepo.store, isEmpty);
    });

    testWidgets('saves a new task with the chosen options and closes with a confirmation', (tester) async {
      setDevice(tester, 390, 844);
      final c = await makeCtx(tasks: []);
      await pumpScreen(tester, c, const AddTaskScreen());

      await tester.enterText(find.byType(TextField).first, 'Read chapter 4');
      await tester.tap(find.text('High'));
      await tester.tap(find.text('2 h'));
      await tester.ensureVisible(find.text('15 min before'));
      await tester.tap(find.text('15 min before'));
      await tester.pump();
      await tester.tap(find.text('Add task'));
      await settle(tester, 600);

      final saved = c.taskRepo.store.single;
      expect(saved.title, 'Read chapter 4');
      expect(saved.priority, 3);
      expect(saved.estimatedMinutes, 120);
      expect(saved.reminderMinutesBefore, 15);
      expect(saved.userId, 'u1');
      expect(find.byType(AddTaskScreen), findsNothing);
      expect(find.text('Task added'), findsOneWidget);
    });

    testWidgets('the category list is the user\'s own and the first one is preselected', (tester) async {
      setDevice(tester, 390, 844);
      final c = await makeCtx(tasks: []);
      final profile = testUser.copyWith(categories: ['Thesis', 'Gym']);
      await c.auth.updateProfile(profile);
      await pumpScreen(tester, c, const AddTaskScreen());

      expect(find.text('Thesis'), findsOneWidget);
      expect(find.text('Gym'), findsOneWidget);
      expect(find.text('School'), findsNothing);

      await tester.enterText(find.byType(TextField).first, 'Draft');
      await tester.tap(find.text('Add task'));
      await settle(tester, 600);
      expect(c.taskRepo.store.single.category, 'Thesis');
    });

    testWidgets('Custom… estimate: validates the range and adds a chip (controller regression)', (tester) async {
      setDevice(tester, 390, 844);
      final errors = ErrorSink()..install();
      final c = await makeCtx(tasks: []);
      await pumpScreen(tester, c, const AddTaskScreen());

      await tester.tap(find.text('Custom…'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, '500');
      await tester.tap(find.text('Set'));
      await tester.pump();
      expect(find.text('Enter 5 to 720 minutes.'), findsOneWidget);

      await tester.enterText(find.byType(TextField).last, '50');
      await tester.tap(find.text('Set'));
      await tester.pumpAndSettle();
      expect(find.text('50 min'), findsOneWidget);
      errors.restore();
      expect(errors.errors, isEmpty, reason: 'closing the dialog must not use a disposed controller');
    });

    testWidgets('a subtask typed but not yet added is not lost on save', (tester) async {
      setDevice(tester, 390, 844);
      final c = await makeCtx(tasks: []);
      await pumpScreen(tester, c, const AddTaskScreen());

      await tester.enterText(find.byType(TextField).first, 'With steps');
      await tester.ensureVisible(find.text('Add a step…'));
      await tester.enterText(find.widgetWithText(TextField, '').last, 'Outline');
      await tester.tap(find.text('Add task'));
      await settle(tester, 600);
      expect(c.taskRepo.store.single.subtasks.map((s) => s.title), ['Outline']);
    });

    testWidgets('a deadline in the past is called out', (tester) async {
      setDevice(tester, 390, 844);
      final c = await makeCtx(tasks: [makeTask('old', deadline: day(-3, 9))]);
      await pumpScreen(tester, c, AddTaskScreen(task: c.taskRepo.store.single));
      expect(find.textContaining('deadline has passed'), findsOneWidget);
    });

    testWidgets('editing keeps the series link, focus time and completion time', (tester) async {
      setDevice(tester, 390, 844);
      final original = Task(
        id: 'e1',
        userId: 'u1',
        title: 'Gym session',
        deadline: day(2, 18),
        priority: 1,
        category: 'Fitness',
        estimatedMinutes: 45,
        createdAt: DateTime.now(),
        recurrenceId: 'series-1',
        recurrence: const RecurrenceRule(frequency: RecurrenceFrequency.weekly),
        elapsedSeconds: 900,
        isCompleted: true,
        completedAt: DateTime(2026, 10, 5, 9),
      );
      final c = await makeCtx(tasks: [original]);
      await pumpScreen(tester, c, AddTaskScreen(task: original));

      expect(find.text('Edit Task'), findsOneWidget);
      expect(find.textContaining('Changes here only affect this occurrence'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, 'Gym session (edited)');
      await tester.pump();
      await tester.tap(find.text('Save changes'));
      await settle(tester, 600);

      final saved = c.taskRepo.store.first;
      expect(saved.title, 'Gym session (edited)');
      expect(saved.recurrenceId, 'series-1');
      expect(saved.elapsedSeconds, 900);
      expect(saved.completedAt, DateTime(2026, 10, 5, 9));
      expect(saved.isCompleted, isTrue);
    });

    testWidgets('editing uses the live copy, so focus time logged meanwhile is kept', (tester) async {
      setDevice(tester, 390, 844);
      final stale = makeTask('e', title: 'Original');
      final c = await makeCtx(tasks: [stale]);
      await pumpScreen(tester, c, AddTaskScreen(task: stale));
      await c.tasks.setElapsed('e', 1200); // focus session wrote 20 minutes while the form was open
      await tester.pump();

      await tester.enterText(find.byType(TextField).first, 'Renamed');
      await tester.tap(find.text('Save changes'));
      await settle(tester, 600);
      expect(c.taskRepo.store.single.elapsedSeconds, 1200);
      expect(c.taskRepo.store.single.title, 'Renamed');
    });

    testWidgets('a failed save shows a message and unlocks the form', (tester) async {
      setDevice(tester, 390, 844);
      final c = await makeCtx(tasks: []);
      c.taskRepo.failWrites = true;
      await pumpScreen(tester, c, const AddTaskScreen());

      await tester.enterText(find.byType(TextField).first, 'Will fail');
      await tester.tap(find.text('Add task'));
      await settle(tester, 600);

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing, reason: 'the button must not stay locked');
      expect(find.byType(AddTaskScreen), findsOneWidget);

      c.taskRepo.failWrites = false;
      await tester.tap(find.text('Add task'));
      await settle(tester, 600);
      expect(c.taskRepo.store, hasLength(1));
    });

    testWidgets('Repeat: a daily rule creates one task per day', (tester) async {
      setDevice(tester, 390, 844);
      final c = await makeCtx(tasks: []);
      await pumpScreen(tester, c, const AddTaskScreen());

      await tester.enterText(find.byType(TextField).first, 'Daily review');
      await tester.ensureVisible(find.text('Repeat'));
      await tester.tap(find.text('Repeat'));
      await tester.pump();
      await tester.ensureVisible(find.text('Daily'));
      await tester.tap(find.text('Daily'));
      await tester.pump();
      await tester.ensureVisible(find.text('After'));
      await tester.tap(find.text('After'));
      await tester.pump();
      expect(find.text('occurrences'), findsWidgets);

      await tester.tap(find.text('Add task'));
      await settle(tester, 600);
      expect(c.taskRepo.store.length, 10);
      expect(c.taskRepo.store.every((t) => t.recurrenceId == c.taskRepo.store.first.id), isTrue);
    });
  });

  group('Add / edit event', () {
    testWidgets('saves the note and the Fixed switch', (tester) async {
      setDevice(tester, 390, 844);
      final c = await makeCtx(schedule: []);
      await pumpScreen(tester, c, AddFixedEventScreen(date: day(1, 0)));

      await tester.enterText(find.byType(TextField).first, 'Study group');
      await tester.enterText(find.byType(TextField).last, 'Library, level 2');
      await tester.tap(find.text('Fixed schedule'));
      await tester.pump();
      await tester.tap(find.text('Save event'));
      await settle(tester, 600);

      final saved = c.scheduleRepo.store.single;
      expect(saved.title, 'Study group');
      expect(saved.note, 'Library, level 2');
      expect(saved.isFixed, isFalse);
      expect(find.text('Event saved'), findsOneWidget);
    });

    testWidgets('an overlap is explained next to the times and nothing is saved', (tester) async {
      setDevice(tester, 390, 844);
      final d = day(1, 0);
      final c = await makeCtx(schedule: [
        ScheduleItem(id: 'x', userId: 'u1', title: 'Existing class', startTime: day(1, 9, 30), endTime: day(1, 10, 30), type: 'class', isFixed: true),
      ]);
      await pumpScreen(tester, c, AddFixedEventScreen(date: d));

      await tester.enterText(find.byType(TextField).first, 'Clash');
      await tester.tap(find.text('Save event'));
      await settle(tester, 600);

      expect(find.textContaining('overlaps with "Existing class"'), findsOneWidget);
      expect(c.scheduleRepo.store, hasLength(1));
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('an end time before the start time is flagged and the form stays usable', (tester) async {
      setDevice(tester, 390, 844);
      final c = await makeCtx(schedule: []);
      await pumpScreen(tester, c, AddFixedEventScreen(date: day(1, 0)));

      await tester.enterText(find.byType(TextField).first, 'Backwards');
      await tester.tap(find.text('10:00 AM'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.keyboard_outlined));
      await tester.pumpAndSettle();
      await tester.enterText(find.descendant(of: find.byType(Dialog), matching: find.byType(TextField)).first, '8');
      await tester.pump();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(find.text('End time must be after the start time.'), findsOneWidget);
      await tester.tap(find.text('Save event'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(c.scheduleRepo.store, isEmpty);
      expect(find.byType(CircularProgressIndicator), findsNothing, reason: 'the button must not stay locked');
      expect(find.text('Save event'), findsOneWidget);
    });

    testWidgets('Repeat creates the series and the repeat options appear', (tester) async {
      setDevice(tester, 390, 844);
      final c = await makeCtx(schedule: []);
      await pumpScreen(tester, c, AddFixedEventScreen(date: day(1, 0)));

      await tester.enterText(find.byType(TextField).first, 'Weekly lab');
      await tester.ensureVisible(find.text('Repeat'));
      await tester.tap(find.text('Repeat'));
      await tester.pump();
      expect(find.text('Weekly'), findsOneWidget);
      await tester.ensureVisible(find.text('After'));
      await tester.tap(find.text('After'));
      await tester.pump();
      await tester.tap(find.text('Save event'));
      await settle(tester, 600);

      expect(c.scheduleRepo.store.length, 10);
      expect(find.text('Repeating event saved'), findsOneWidget);
    });

    testWidgets('editing changes only that occurrence and hides the repeat switch', (tester) async {
      setDevice(tester, 390, 844);
      final item = ScheduleItem(
        id: 'occ',
        userId: 'u1',
        title: 'Lab',
        startTime: day(1, 14),
        endTime: day(1, 16),
        type: ScheduleTypes.class_,
        isFixed: true,
        recurrenceId: 'series',
      );
      final c = await makeCtx(schedule: [item]);
      await pumpScreen(tester, c, AddFixedEventScreen(date: item.startTime, item: item));

      expect(find.text('Edit Event'), findsOneWidget);
      expect(find.text('Repeat'), findsNothing);
      expect(find.text('Editing changes only this occurrence.'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'Lab (moved)');
      await tester.tap(find.text('Save changes'));
      await settle(tester, 600);
      expect(c.scheduleRepo.store.single.title, 'Lab (moved)');
      expect(c.scheduleRepo.store.single.recurrenceId, 'series');
    });

    testWidgets('an empty name is refused', (tester) async {
      setDevice(tester, 390, 844);
      final c = await makeCtx(schedule: []);
      await pumpScreen(tester, c, AddFixedEventScreen(date: day(1, 0)));
      await tester.tap(find.text('Save event'));
      await tester.pump();
      expect(find.text('Give the event a name.'), findsOneWidget);
      expect(c.scheduleRepo.store, isEmpty);
    });
  });

  test('UserModel default categories feed the form', () {
    expect(kDefaultCategories, contains('School'));
  });
}
