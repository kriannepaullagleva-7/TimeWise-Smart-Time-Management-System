import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:timewise/models/task.dart';
import 'package:timewise/models/recurrence.dart';

void main() {
  group('Task.fromMap — defensive parsing', () {
    test('parses a complete, well-formed map', () {
      final now = DateTime(2026, 6, 15, 10, 0);
      final map = {
        'id': 'task-1',
        'userId': 'user-1',
        'title': 'Write report',
        'description': 'Use APA format',
        'deadline': Timestamp.fromDate(now),
        'priority': 3,
        'category': 'Work',
        'estimatedMinutes': 90,
        'isCompleted': false,
        'createdAt': Timestamp.fromDate(now),
        'reminderMinutesBefore': 15,
        'recurrenceId': null,
        'recurrence': null,
      };

      final task = Task.fromMap(map);
      expect(task.id, 'task-1');
      expect(task.title, 'Write report');
      expect(task.priority, 3);
      expect(task.estimatedMinutes, 90);
      expect(task.reminderMinutesBefore, 15);
      expect(task.recurrence, RecurrenceRule.none);
    });

    test('falls back safely when every field is null / missing', () {
      final task = Task.fromMap({});
      expect(task.id, '');
      expect(task.userId, '');
      expect(task.title, '');
      expect(task.description, '');
      expect(task.priority, 2);
      expect(task.category, 'General');
      expect(task.estimatedMinutes, 60);
      expect(task.isCompleted, false);
      expect(task.reminderMinutesBefore, isNull);
      expect(task.recurrenceId, isNull);
      expect(task.recurrence, RecurrenceRule.none);
    });

    test('falls back safely when deadline Timestamp is null', () {
      final task = Task.fromMap({'deadline': null});
      // Should not throw; deadline defaults to approximately now.
      expect(task.deadline, isNotNull);
    });

    test('toMap → fromMap round-trip preserves all non-null fields', () {
      final original = Task(
        id: 'rt-1',
        userId: 'u-1',
        title: 'Round trip',
        description: 'desc',
        deadline: DateTime(2026, 9, 1, 8, 0),
        priority: 1,
        category: 'Personal',
        estimatedMinutes: 30,
        isCompleted: true,
        createdAt: DateTime(2026, 8, 1),
        reminderMinutesBefore: 5,
        recurrenceId: 'series-1',
        recurrence: const RecurrenceRule(
          frequency: RecurrenceFrequency.weekly,
          interval: 1,
          daysOfWeek: {1, 3},
          count: 10,
        ),
      );

      final restored = Task.fromMap(original.toMap());
      expect(restored.id, original.id);
      expect(restored.title, original.title);
      expect(restored.priority, original.priority);
      expect(restored.isCompleted, original.isCompleted);
      expect(restored.reminderMinutesBefore, original.reminderMinutesBefore);
      expect(restored.recurrenceId, original.recurrenceId);
      expect(restored.recurrence.frequency, original.recurrence.frequency);
      expect(restored.recurrence.daysOfWeek, original.recurrence.daysOfWeek);
      expect(restored.recurrence.count, original.recurrence.count);
    });

    test('copyWith overrides only specified fields', () {
      final base = Task(
        id: 'x',
        userId: 'u',
        title: 'Original',
        deadline: DateTime(2026, 1, 1),
        priority: 2,
        category: 'Work',
        estimatedMinutes: 60,
        createdAt: DateTime(2026, 1, 1),
      );

      final modified = base.copyWith(title: 'Updated', isCompleted: true);
      expect(modified.title, 'Updated');
      expect(modified.isCompleted, true);
      expect(modified.priority, 2);         // unchanged
      expect(modified.category, 'Work');    // unchanged
    });

    test('copyWith(clearReminder: true) removes reminderMinutesBefore', () {
      final base = Task(
        id: 'x',
        userId: 'u',
        title: 'T',
        deadline: DateTime(2026, 1, 1),
        priority: 2,
        category: 'Work',
        estimatedMinutes: 60,
        createdAt: DateTime(2026, 1, 1),
        reminderMinutesBefore: 30,
      );

      final cleared = base.copyWith(clearReminder: true);
      expect(cleared.reminderMinutesBefore, isNull);
    });

    test('status returns overdue for past incomplete task', () {
      final task = Task(
        id: 'x',
        userId: 'u',
        title: 'T',
        deadline: DateTime(2020, 1, 1), // well in the past
        priority: 2,
        category: 'Work',
        estimatedMinutes: 60,
        createdAt: DateTime(2020, 1, 1),
      );
      expect(task.status, TaskStatus.overdue);
    });

    test('status returns completed when isCompleted is true', () {
      final task = Task(
        id: 'x',
        userId: 'u',
        title: 'T',
        deadline: DateTime(2020, 1, 1),
        priority: 2,
        category: 'Work',
        estimatedMinutes: 60,
        isCompleted: true,
        createdAt: DateTime(2020, 1, 1),
      );
      expect(task.status, TaskStatus.completed);
    });
  });
}
