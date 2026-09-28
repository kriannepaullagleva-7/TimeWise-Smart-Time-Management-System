import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timewise/models/schedule.dart';
import 'package:timewise/models/recurrence.dart';

void main() {
  group('ScheduleItem.fromMap — defensive parsing', () {
    test('parses a complete well-formed map', () {
      final start = DateTime(2026, 6, 15, 9, 0);
      final end = DateTime(2026, 6, 15, 10, 0);
      final map = {
        'id': 's-1',
        'userId': 'u-1',
        'title': 'Morning class',
        'startTime': Timestamp.fromDate(start),
        'endTime': Timestamp.fromDate(end),
        'type': ScheduleTypes.class_,
        'taskId': null,
        'isAISuggested': false,
        'isFixed': true,
        'note': 'Rm 101',
        'recurrenceId': null,
        'recurrence': null,
      };

      final item = ScheduleItem.fromMap(map);
      expect(item.id, 's-1');
      expect(item.title, 'Morning class');
      expect(item.type, ScheduleTypes.class_);
      expect(item.isFixed, true);
      expect(item.note, 'Rm 101');
      expect(item.recurrence, RecurrenceRule.none);
    });

    test('falls back safely when every field is null / missing', () {
      final item = ScheduleItem.fromMap({});
      expect(item.id, '');
      expect(item.userId, '');
      expect(item.title, '');
      expect(item.type, 'task');
      expect(item.isAISuggested, false);
      expect(item.note, isNull);
      expect(item.recurrenceId, isNull);
    });

    test('isFixed defaults to true for a fixedType when field is missing', () {
      final map = {'type': ScheduleTypes.class_}; // no 'isFixed' key
      final item = ScheduleItem.fromMap(map);
      expect(item.isFixed, true);
    });

    test('isFixed defaults to false for a non-fixed type when field is missing', () {
      final map = {'type': ScheduleTypes.task}; // no 'isFixed' key
      final item = ScheduleItem.fromMap(map);
      expect(item.isFixed, false);
    });

    test('toMap → fromMap round-trip preserves all fields', () {
      final start = DateTime(2026, 9, 1, 8, 0);
      final end = DateTime(2026, 9, 1, 9, 0);
      final original = ScheduleItem(
        id: 'rt-1',
        userId: 'u-1',
        title: 'RT event',
        startTime: start,
        endTime: end,
        type: ScheduleTypes.work,
        taskId: 'task-42',
        isAISuggested: false,
        isFixed: true,
        note: 'important',
        recurrenceId: 'series-1',
        recurrence: const RecurrenceRule(
          frequency: RecurrenceFrequency.daily,
          count: 5,
        ),
      );

      final restored = ScheduleItem.fromMap(original.toMap());
      expect(restored.id, original.id);
      expect(restored.title, original.title);
      expect(restored.type, original.type);
      expect(restored.isFixed, original.isFixed);
      expect(restored.note, original.note);
      expect(restored.recurrenceId, original.recurrenceId);
      expect(restored.recurrence.frequency, original.recurrence.frequency);
      expect(restored.recurrence.count, original.recurrence.count);
    });

    test('duration returns correct difference', () {
      final item = ScheduleItem(
        id: 'x',
        userId: 'u',
        title: 'T',
        startTime: DateTime(2026, 1, 1, 9, 0),
        endTime: DateTime(2026, 1, 1, 10, 30),
        type: ScheduleTypes.personal,
      );
      expect(item.duration, const Duration(hours: 1, minutes: 30));
    });

    test('overlapsWith returns true for overlapping items', () {
      final a = ScheduleItem(
        id: 'a',
        userId: 'u',
        title: 'A',
        startTime: DateTime(2026, 1, 1, 9, 0),
        endTime: DateTime(2026, 1, 1, 10, 0),
        type: ScheduleTypes.personal,
      );
      final b = ScheduleItem(
        id: 'b',
        userId: 'u',
        title: 'B',
        startTime: DateTime(2026, 1, 1, 9, 30),
        endTime: DateTime(2026, 1, 1, 11, 0),
        type: ScheduleTypes.personal,
      );
      expect(a.overlapsWith(b), true);
      expect(b.overlapsWith(a), true);
    });

    test('overlapsWith returns false for back-to-back items', () {
      final a = ScheduleItem(
        id: 'a',
        userId: 'u',
        title: 'A',
        startTime: DateTime(2026, 1, 1, 9, 0),
        endTime: DateTime(2026, 1, 1, 10, 0),
        type: ScheduleTypes.personal,
      );
      final b = ScheduleItem(
        id: 'b',
        userId: 'u',
        title: 'B',
        startTime: DateTime(2026, 1, 1, 10, 0),
        endTime: DateTime(2026, 1, 1, 11, 0),
        type: ScheduleTypes.personal,
      );
      expect(a.overlapsWith(b), false);
    });
  });
}
