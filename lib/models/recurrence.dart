import 'package:cloud_firestore/cloud_firestore.dart';

enum RecurrenceFrequency { none, daily, weekly, monthly }

/// Describes how a task/fixed-event repeats. Instances are materialized as
/// individual Firestore docs (see FirestoreService.addTasksBatch /
/// addScheduleItemsBatch) rather than expanded on the fly, so completion
/// state, edits and reminders can be tracked per-occurrence like any other
/// task/event. All docs in a series share [RecurrenceRule] and a
/// `recurrenceId` (the first occurrence's own id).
class RecurrenceRule {
  final RecurrenceFrequency frequency;
  final int interval;

  /// ISO weekday numbers (1=Mon..7=Sun). Only used when [frequency] is
  /// weekly; empty means "the same weekday as the first occurrence".
  final Set<int> daysOfWeek;

  /// Inclusive cutoff date. Null means no date cutoff (see [count]).
  final DateTime? endDate;

  /// Total number of occurrences to generate. Null means "until [endDate],
  /// or a default rolling cap if neither is set".
  final int? count;

  const RecurrenceRule({
    this.frequency = RecurrenceFrequency.none,
    this.interval = 1,
    this.daysOfWeek = const {},
    this.endDate,
    this.count,
  });

  static const none = RecurrenceRule();

  bool get isRecurring => frequency != RecurrenceFrequency.none;

  static const _hardCap = 200;
  static const _defaultRollingCap = 60;

  /// Generates the occurrence dates for this rule, starting from and
  /// including [first]. Always returns at least `[first]`.
  List<DateTime> occurrencesFrom(DateTime first) {
    if (!isRecurring) return [first];

    final maxCount =
        (count ?? (endDate == null ? _defaultRollingCap : _hardCap))
            .clamp(1, _hardCap);
    final firstDate = DateTime(first.year, first.month, first.day);
    final result = <DateTime>[];

    switch (frequency) {
      case RecurrenceFrequency.none:
        break;
      case RecurrenceFrequency.daily:
        var i = 0;
        while (result.length < maxCount) {
          final d = firstDate.add(Duration(days: i * interval));
          if (endDate != null && d.isAfter(endDate!)) break;
          result.add(d);
          i++;
        }
        break;
      case RecurrenceFrequency.weekly:
        final days = daysOfWeek.isEmpty ? {firstDate.weekday} : daysOfWeek;
        final sortedDays = days.toList()..sort();
        final firstWeekStart =
            firstDate.subtract(Duration(days: firstDate.weekday - 1));
        var weekOffset = 0;
        outer:
        while (result.length < maxCount) {
          final weekStart =
              firstWeekStart.add(Duration(days: weekOffset * 7 * interval));
          for (final wd in sortedDays) {
            final d = weekStart.add(Duration(days: wd - 1));
            if (d.isBefore(firstDate)) continue;
            if (endDate != null && d.isAfter(endDate!)) break outer;
            result.add(d);
            if (result.length >= maxCount) break;
          }
          weekOffset++;
          if (weekOffset > 520) break; // ~10 years of weeks, safety valve
        }
        break;
      case RecurrenceFrequency.monthly:
        var i = 0;
        while (result.length < maxCount) {
          final d = _addMonths(firstDate, i * interval);
          if (endDate != null && d.isAfter(endDate!)) break;
          result.add(d);
          i++;
          if (i > 1200) break; // safety valve
        }
        break;
    }

    return result.isEmpty ? [firstDate] : result;
  }

  static DateTime _addMonths(DateTime date, int months) {
    final totalMonths = date.month - 1 + months;
    final year = date.year + totalMonths ~/ 12;
    final month = totalMonths % 12 + 1;
    final daysInTargetMonth = DateTime(year, month + 1, 0).day;
    final day = date.day > daysInTargetMonth ? daysInTargetMonth : date.day;
    return DateTime(year, month, day);
  }

  static const _weekdayAbbrev = {
    1: 'Mon',
    2: 'Tue',
    3: 'Wed',
    4: 'Thu',
    5: 'Fri',
    6: 'Sat',
    7: 'Sun',
  };

  /// Short human-readable description, e.g. "Every 2 weeks on Mon, Wed".
  String get summary {
    if (!isRecurring) return 'Does not repeat';

    final unit = switch (frequency) {
      RecurrenceFrequency.daily => 'day',
      RecurrenceFrequency.weekly => 'week',
      RecurrenceFrequency.monthly => 'month',
      RecurrenceFrequency.none => '',
    };
    final base = interval == 1 ? 'Every $unit' : 'Every $interval ${unit}s';

    if (frequency == RecurrenceFrequency.weekly && daysOfWeek.isNotEmpty) {
      final names = (daysOfWeek.toList()..sort())
          .map((d) => _weekdayAbbrev[d])
          .join(', ');
      return '$base on $names';
    }
    return base;
  }

  RecurrenceRule copyWith({
    RecurrenceFrequency? frequency,
    int? interval,
    Set<int>? daysOfWeek,
    DateTime? endDate,
    bool clearEndDate = false,
    int? count,
    bool clearCount = false,
  }) {
    return RecurrenceRule(
      frequency: frequency ?? this.frequency,
      interval: interval ?? this.interval,
      daysOfWeek: daysOfWeek ?? this.daysOfWeek,
      endDate: clearEndDate ? null : (endDate ?? this.endDate),
      count: clearCount ? null : (count ?? this.count),
    );
  }

  Map<String, dynamic>? toMap() {
    if (!isRecurring) return null;
    return {
      'frequency': frequency.name,
      'interval': interval,
      'daysOfWeek': daysOfWeek.toList(),
      'endDate': endDate == null ? null : Timestamp.fromDate(endDate!),
      'count': count,
    };
  }

  factory RecurrenceRule.fromMap(Map<String, dynamic>? map) {
    if (map == null) return RecurrenceRule.none;
    return RecurrenceRule(
      frequency: RecurrenceFrequency.values.firstWhere(
        (f) => f.name == map['frequency'],
        orElse: () => RecurrenceFrequency.none,
      ),
      interval: (map['interval'] as int?) ?? 1,
      daysOfWeek: Set<int>.from(map['daysOfWeek'] ?? const []),
      endDate: (map['endDate'] as Timestamp?)?.toDate(),
      count: map['count'] as int?,
    );
  }
}
