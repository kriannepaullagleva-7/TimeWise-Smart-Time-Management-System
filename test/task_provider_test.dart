import 'package:flutter_test/flutter_test.dart';
import 'package:timewise/models/recurrence.dart';
import 'package:timewise/models/task.dart';
import 'package:timewise/providers/task_provider.dart';

import 'support/test_support.dart';

Future<void> _flush() => Future<void>.delayed(Duration.zero);

void main() {
  late FakeTaskRepo repo;
  late FakeNotifs notifications;
  late TaskProvider provider;

  setUp(() {
    repo = FakeTaskRepo();
    notifications = FakeNotifs();
    provider = TaskProvider(taskRepository: repo, notificationService: notifications);
  });

  group('live data', () {
    test('is not loaded until the first snapshot, then exposes the tasks', () async {
      repo.store.add(makeTask('a'));
      expect(provider.isLoaded, false);
      provider.attachUser('u1');
      await _flush();
      await _flush();
      expect(provider.isLoaded, true);
      expect(provider.tasks.map((t) => t.id), ['a']);
    });

    test('opens ONE query for the signed-in user, however often attachUser is called', () async {
      provider.attachUser('u1');
      provider.attachUser('u1');
      provider.attachUser('u1');
      await _flush();
      expect(repo.watchAllCalls, 1);
    });

    test('a write shows up in the list without re-querying', () async {
      provider.attachUser('u1');
      await _flush();
      await provider.addTask(makeTask('new'));
      await _flush();
      expect(provider.tasks.map((t) => t.id), ['new']);
      expect(repo.watchAllCalls, 1);
    });

    test('signing out clears the list', () async {
      repo.store.add(makeTask('a'));
      provider.attachUser('u1');
      await _flush();
      await _flush();
      provider.attachUser(null);
      expect(provider.tasks, isEmpty);
      expect(provider.isLoaded, false);
    });
  });

  group('addTask', () {
    test('persists the task', () async {
      final task = makeTask('t-1');
      await provider.addTask(task);
      expect(repo.store, contains(task));
      expect(provider.isLoading, false);
      expect(provider.errorMessage, isNull);
    });

    test('schedules a reminder when reminderMinutesBefore is set', () async {
      final task = Task(
        id: 't-r',
        userId: 'u1',
        title: 'Remind me',
        deadline: DateTime.now().add(const Duration(hours: 2)),
        priority: 2,
        category: 'Work',
        estimatedMinutes: 30,
        createdAt: DateTime.now(),
        reminderMinutesBefore: 30,
      );
      await provider.addTask(task);
      expect(notifications.scheduled, ['Remind me']);
    });

    test('asks for the notification permission and schedules nothing when it is refused', () async {
      notifications.permissionGranted = false;
      await provider.addTask(Task(
        id: 'r',
        userId: 'u1',
        title: 'x',
        deadline: DateTime.now().add(const Duration(hours: 2)),
        priority: 2,
        category: 'Work',
        estimatedMinutes: 30,
        createdAt: DateTime.now(),
        reminderMinutesBefore: 15,
      ));
      expect(notifications.permissionRequests, 1);
      expect(notifications.scheduled, isEmpty);
    });

    test('asks for the permission only once per session', () async {
      notifications.permissionGranted = false;
      for (final id in ['a', 'b', 'c']) {
        await provider.addTask(Task(
          id: id,
          userId: 'u1',
          title: id,
          deadline: DateTime.now().add(const Duration(hours: 2)),
          priority: 2,
          category: 'Work',
          estimatedMinutes: 30,
          createdAt: DateTime.now(),
          reminderMinutesBefore: 15,
        ));
      }
      expect(notifications.permissionRequests, 1);
    });

    test('no reminder is scheduled when reminders are switched off', () async {
      provider.setRemindersEnabled(false);
      await provider.addTask(Task(
        id: 'r',
        userId: 'u1',
        title: 'x',
        deadline: DateTime.now().add(const Duration(hours: 2)),
        priority: 2,
        category: 'Work',
        estimatedMinutes: 30,
        createdAt: DateTime.now(),
        reminderMinutesBefore: 15,
      ));
      expect(notifications.scheduled, isEmpty);
      expect(notifications.cancelAllCalls, 1);
    });

    test('a failed write sets a message and rethrows', () async {
      repo.failWrites = true;
      await expectLater(provider.addTask(makeTask('t-1')), throwsException);
      expect(provider.errorMessage, isNotNull);
      expect(provider.isLoading, false);
    });
  });

  group('recurring tasks', () {
    test('creates one task per occurrence, all linked to the first', () async {
      final base = makeTask('base', deadline: day(1, 18));
      await provider.addRecurringTask(base, const RecurrenceRule(frequency: RecurrenceFrequency.daily, count: 4));
      expect(repo.store.length, 4);
      expect(repo.store.every((t) => t.recurrenceId == 'base'), isTrue);
      expect(repo.store.map((t) => t.id).toSet().length, 4);
    });

    test('every occurrence keeps the subtasks', () async {
      final base = Task(
        id: 'b1',
        userId: 'u1',
        title: 'Weekly review',
        deadline: day(1, 18),
        priority: 2,
        category: 'School',
        estimatedMinutes: 30,
        createdAt: DateTime.now(),
        subtasks: [Subtask(id: '1', title: 'Step one'), Subtask(id: '2', title: 'Step two')],
      );
      await provider.addRecurringTask(base, const RecurrenceRule(frequency: RecurrenceFrequency.daily, count: 5));
      expect(repo.store.length, 5);
      expect(repo.store.every((t) => t.subtasks.length == 2), isTrue);
    });

    test('deleteTaskSeries removes the whole series of that user and cancels its reminders', () async {
      for (final id in ['s-1', 's-2', 's-3']) {
        repo.store.add(makeTask(id, recurrenceId: 'series-A'));
      }
      repo.store.add(makeTask('other'));
      await provider.deleteTaskSeries('u1', 'series-A');
      expect(repo.store.map((t) => t.id), ['other']);
      expect(notifications.cancelled.length, 3);
    });
  });

  group('update, complete, delete', () {
    test('updateTask replaces the stored task', () async {
      final task = makeTask('t-1');
      await provider.addTask(task);
      await provider.updateTask(task.copyWith(title: 'Renamed'));
      expect(repo.store.single.title, 'Renamed');
    });

    test('completeTask writes only the completion fields', () async {
      final task = makeTask('t-1').copyWith(elapsedSeconds: 900);
      repo.store.add(task);
      // A stale copy (older elapsedSeconds) must not overwrite the focus time.
      await provider.completeTask(makeTask('t-1'));
      expect(repo.store.single.isCompleted, true);
      expect(repo.store.single.completedAt, isNotNull);
      expect(repo.store.single.elapsedSeconds, 900);
    });

    test('reopenTask clears completion', () async {
      final done = makeTask('t-1', completed: true);
      repo.store.add(done);
      await provider.reopenTask(done);
      expect(repo.store.single.isCompleted, false);
      expect(repo.store.single.completedAt, isNull);
    });

    test('deleteTask removes the task and cancels its reminder', () async {
      await provider.addTask(makeTask('t-1'));
      await provider.deleteTask('t-1');
      expect(repo.store, isEmpty);
      expect(notifications.cancelled, contains(TaskProvider.notificationIdFor('t-1')));
    });

    test('notificationIdFor is stable and non-negative', () {
      expect(TaskProvider.notificationIdFor('abc'), TaskProvider.notificationIdFor('abc'));
      expect(TaskProvider.notificationIdFor('abc'), isNot(TaskProvider.notificationIdFor('abd')));
      expect(TaskProvider.notificationIdFor('some-long-document-id'), greaterThanOrEqualTo(0));
    });
  });

  group('derived values', () {
    final now = DateTime(2026, 10, 5, 12);

    test('collapseSeries keeps one-offs, overdue and completed, and only the NEXT upcoming repeat', () {
      Task t(String id, DateTime d, {String? series, bool done = false}) => makeTask(id, deadline: d, recurrenceId: series, completed: done);
      final tasks = [
        t('oneoff', DateTime(2026, 10, 20)),
        t('late', DateTime(2026, 10, 1), series: 'S'),
        t('done', DateTime(2026, 10, 9), series: 'S', done: true),
        t('next', DateTime(2026, 10, 6), series: 'S'),
        t('later1', DateTime(2026, 10, 7), series: 'S'),
        t('later2', DateTime(2026, 10, 8), series: 'S'),
      ];
      final ids = TaskProvider.collapseSeries(tasks, now: now).map((x) => x.id).toList();
      expect(ids, ['late', 'next', 'done', 'oneoff']);
    });

    test('planningCandidates: pending only, within a week, urgent first, capped', () {
      final tasks = [
        makeTask('far', deadline: DateTime(2026, 11, 30)),
        makeTask('done', deadline: DateTime(2026, 10, 6), completed: true),
        makeTask('low', deadline: DateTime(2026, 10, 6), priority: 1),
        makeTask('high-late', deadline: DateTime(2026, 10, 7), priority: 3),
        makeTask('high-soon', deadline: DateTime(2026, 10, 6), priority: 3),
      ];
      final ids = TaskProvider.planningCandidates(tasks, DateTime(2026, 10, 5)).map((x) => x.id).toList();
      expect(ids, ['high-soon', 'high-late', 'low']);

      final many = [for (var i = 0; i < 30; i++) makeTask('t$i', deadline: DateTime(2026, 10, 6))];
      expect(TaskProvider.planningCandidates(many, DateTime(2026, 10, 5)).length, 15);
    });

    test('completionRate ignores future occurrences', () {
      final tasks = [
        makeTask('done', deadline: DateTime(2026, 10, 1), completed: true),
        makeTask('missed', deadline: DateTime(2026, 10, 2)),
        makeTask('future1', deadline: DateTime(2026, 10, 20)),
        makeTask('future2', deadline: DateTime(2026, 10, 21)),
      ];
      expect(TaskProvider.completionRate(tasks, now: now), 50);
      expect(TaskProvider.completionRate(const [], now: now), 0);
    });

    test('focusSeconds adds up the logged focus time', () {
      expect(
        TaskProvider.focusSeconds([makeTask('a').copyWith(elapsedSeconds: 600), makeTask('b').copyWith(elapsedSeconds: 90)]),
        690,
      );
    });

    test('streak counts consecutive days ending today or yesterday', () {
      Task doneOn(String id, DateTime d) => makeTask(id, completed: true).copyWith(completedAt: d);
      final tasks = [
        doneOn('a', DateTime(2026, 10, 5, 9)),
        doneOn('b', DateTime(2026, 10, 4, 22)),
        doneOn('c', DateTime(2026, 10, 3, 8)),
        doneOn('d', DateTime(2026, 10, 1, 8)), // gap on the 2nd
      ];
      expect(provider.calculateStreak(tasks, now: now), 3);
      // Nothing done today yet: the streak through yesterday still counts.
      expect(provider.calculateStreak(tasks.skip(1).toList(), now: now), 2);
      expect(provider.calculateStreak(const [], now: now), 0);
    });
  });
}
