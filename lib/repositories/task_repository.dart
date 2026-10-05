import '../models/task.dart';

/// Contract for task persistence. Code that needs task data depends only on
/// this interface, making it trivially swappable and unit-testable with a
/// fake repository that requires no live Firebase connection.
abstract interface class TaskRepository {
  /// Live stream of ALL tasks for [userId], ordered by deadline.
  Stream<List<Task>> watchAll(String userId);

  /// Reserves a new unique document id.
  String newId();

  Future<void> add(Task task);
  Future<void> addBatch(List<Task> tasks);

  /// Replaces the whole document (used by the edit form).
  Future<void> update(Task task);

  /// Partial updates: only the named fields are written, so a stale copy of
  /// a task can never overwrite edits made elsewhere.
  Future<void> setCompletion(String taskId, {required bool completed, DateTime? completedAt});
  Future<void> setElapsed(String taskId, int seconds);
  Future<void> setSubtasks(String taskId, List<Subtask> subtasks);

  Future<void> delete(String taskId);

  /// Deletes every task of [userId] in the series and returns the deleted ids
  /// so callers can cancel their local notifications. The user id is part of
  /// the query because the security rules only allow queries that are
  /// restricted to the signed-in user's own documents.
  Future<List<String>> deleteSeries(String userId, String recurrenceId);
}
