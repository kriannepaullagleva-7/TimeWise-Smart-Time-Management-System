import '../models/task.dart';

/// Contract for task persistence. Code that needs task data depends only on
/// this interface, making it trivially swappable and unit-testable with a
/// [FakeTaskRepository] that requires no live Firebase connection.
abstract interface class TaskRepository {
  /// Returns a live Firestore stream of ALL tasks for [userId].
  Stream<List<Task>> watchAll(String userId);

  /// Returns a live stream of incomplete tasks for [userId].
  Stream<List<Task>> watchActive(String userId);

  /// Reserves a new unique Firestore document id.
  String newId();

  Future<void> add(Task task);
  Future<void> addBatch(List<Task> tasks);
  Future<void> update(Task task);
  Future<void> delete(String taskId);

  /// Deletes every task in the series and returns the deleted ids so
  /// callers can cancel their local notifications.
  Future<List<String>> deleteSeries(String recurrenceId);
}
