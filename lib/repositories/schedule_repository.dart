import '../models/schedule.dart';

/// Contract for schedule-item persistence.
abstract interface class ScheduleRepository {
  /// Live stream for [userId] on a specific [date].
  Stream<List<ScheduleItem>> watchDay(String userId, DateTime date);

  /// Live stream of every item that starts in `[start, end)`.
  Stream<List<ScheduleItem>> watchRange(String userId, DateTime start, DateTime end);

  /// One-shot fetch of every item that starts in `[start, end)`.
  Future<List<ScheduleItem>> fetchRange(String userId, DateTime start, DateTime end);

  /// One-shot fetch for [userId] on [date].
  Future<List<ScheduleItem>> fetchDay(String userId, DateTime date);

  String newId();

  Future<void> add(ScheduleItem item);
  Future<void> addBatch(List<ScheduleItem> items);
  Future<void> update(ScheduleItem item);
  Future<void> delete(String scheduleId);

  /// Deletes every item of [userId] in the series (the user id is required by
  /// the owner-only security rules).
  Future<void> deleteSeries(String userId, String recurrenceId);

  /// Replaces the AI-suggested items of [date] with [items] in ONE atomic
  /// batch: either the old plan is replaced by the new one, or nothing
  /// changes. Fixed events and the user's own events are never touched.
  Future<void> replaceAiSuggestions(String userId, DateTime date, List<ScheduleItem> items);
}
