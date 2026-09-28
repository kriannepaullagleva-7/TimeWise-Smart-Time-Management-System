import '../models/schedule.dart';

/// Contract for schedule-item persistence.
abstract interface class ScheduleRepository {
  /// Live stream for [userId] on a specific [date].
  Stream<List<ScheduleItem>> watchDay(String userId, DateTime date);

  /// One-shot fetch for [userId] on [date].
  Future<List<ScheduleItem>> fetchDay(String userId, DateTime date);

  String newId();

  Future<void> add(ScheduleItem item);
  Future<void> addBatch(List<ScheduleItem> items);
  Future<void> update(ScheduleItem item);
  Future<void> delete(String scheduleId);
  Future<void> deleteSeries(String recurrenceId);

  /// Deletes only the non-fixed items on [date] (previous AI suggestions /
  /// task blocks) while keeping user-created fixed events.
  Future<void> clearFlexible(String userId, DateTime date);
}
