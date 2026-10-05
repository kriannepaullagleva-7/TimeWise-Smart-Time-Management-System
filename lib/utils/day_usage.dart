import '../models/schedule.dart';

/// How a day's waking hours are used, for the Dashboard's "Available today"
/// bar. Each minute is counted once even when items overlap, so the segments
/// always add up to the waking window.
class DayUsage {
  final int awakeMinutes;
  final int fixedMinutes;
  final int aiMinutes;
  final int breakMinutes;
  final int otherMinutes;

  const DayUsage({
    required this.awakeMinutes,
    required this.fixedMinutes,
    required this.aiMinutes,
    required this.breakMinutes,
    required this.otherMinutes,
  });

  int get busyMinutes => fixedMinutes + aiMinutes + breakMinutes + otherMinutes;
  int get freeMinutes => awakeMinutes - busyMinutes;

  /// [wakeMinutes] / [sleepMinutes] are minutes after midnight. A sleep time
  /// earlier than (or equal to) the wake time means the day runs past midnight.
  static DayUsage compute(
    List<ScheduleItem> items,
    DateTime day, {
    required int wakeMinutes,
    required int sleepMinutes,
  }) {
    final windowStart = wakeMinutes;
    var windowEnd = sleepMinutes;
    if (windowEnd <= windowStart) windowEnd += 24 * 60;

    // 0 = free, 1 = other, 2 = break, 3 = AI, 4 = fixed (higher paints over lower).
    final slots = List<int>.filled(windowEnd - windowStart, 0);
    final dayStart = DateTime(day.year, day.month, day.day);

    int rank(ScheduleItem item) {
      if (item.isFixed) return 4;
      if (item.type == ScheduleTypes.breakTime) return 2;
      if (item.isAISuggested) return 3;
      return 1;
    }

    for (final item in items) {
      if (item.isTaskRow) continue;
      final from = item.startTime.difference(dayStart).inMinutes;
      final to = item.endTime.difference(dayStart).inMinutes;
      final r = rank(item);
      for (var m = from; m < to; m++) {
        final slot = m - windowStart;
        if (slot >= 0 && slot < slots.length && slots[slot] < r) slots[slot] = r;
      }
    }

    int count(int r) => slots.where((s) => s == r).length;
    return DayUsage(
      awakeMinutes: slots.length,
      fixedMinutes: count(4),
      aiMinutes: count(3),
      breakMinutes: count(2),
      otherMinutes: count(1),
    );
  }
}
