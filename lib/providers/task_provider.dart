import 'package:flutter/material.dart';

import '../models/recurrence.dart';
import '../models/task.dart';
import '../repositories/task_repository.dart';
import '../repositories/impl/firestore_task_repository.dart';
import '../services/notification_service.dart';
import '../utils/app_logger.dart';

class TaskProvider extends ChangeNotifier {
  static const _module = 'TaskProvider';

  final TaskRepository _repo;
  final NotificationService _notificationService;

  TaskProvider({
    TaskRepository? taskRepository,
    NotificationService? notificationService,
  })  : _repo = taskRepository ?? FirestoreTaskRepository(),
        _notificationService = notificationService ?? NotificationService();

  bool _isLoading = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // ── Streams ──────────────────────────────────────────────────────────────

  Stream<List<Task>> getUserTasksStream(String userId) =>
      _repo.watchAll(userId);

  Stream<List<Task>> getActiveTasksStream(String userId) =>
      _repo.watchActive(userId);

  // ── Helpers ───────────────────────────────────────────────────────────────

  String newTaskId() => _repo.newId();

  int _notificationIdFor(String taskId) => taskId.hashCode & 0x7fffffff;

  Future<void> _syncReminder(Task task) async {
    final notifId = _notificationIdFor(task.id);
    await _notificationService.cancelNotification(notifId);

    final reminderTime = task.reminderTime;
    if (task.isCompleted || reminderTime == null) return;
    if (reminderTime.isBefore(DateTime.now())) return;

    await _notificationService.scheduleTaskReminder(
      notifId,
      task.title,
      reminderTime,
    );
  }

  // ── Mutations ─────────────────────────────────────────────────────────────

  Future<void> addTask(Task task) async {
    _begin();
    try {
      await _repo.add(task);
      await _syncReminder(task);
      AppLogger.info(_module, 'addTask succeeded: ${task.id}');
    } catch (e, st) {
      _setError('Could not add task. Please try again.', e, st);
      rethrow;
    } finally {
      _end();
    }
  }

  /// Number of upcoming occurrences to auto-schedule a local reminder for.
  /// Kept well under iOS's 64-pending-notification ceiling.
  static const _maxRemindersPerSeries = 20;

  Future<void> addRecurringTask(Task base, RecurrenceRule rule) async {
    _begin();
    try {
      final dates = rule.occurrencesFrom(base.deadline);
      final timeOfDay = TimeOfDay.fromDateTime(base.deadline);

      final occurrences = dates.map((date) {
        final deadline = DateTime(
          date.year,
          date.month,
          date.day,
          timeOfDay.hour,
          timeOfDay.minute,
        );
        return Task(
          id: date == dates.first ? base.id : _repo.newId(),
          userId: base.userId,
          title: base.title,
          description: base.description,
          deadline: deadline,
          priority: base.priority,
          category: base.category,
          estimatedMinutes: base.estimatedMinutes,
          createdAt: base.createdAt,
          reminderMinutesBefore: base.reminderMinutesBefore,
          recurrenceId: base.id,
          recurrence: rule,
        );
      }).toList();

      await _repo.addBatch(occurrences);
      for (final task in occurrences.take(_maxRemindersPerSeries)) {
        await _syncReminder(task);
      }
      AppLogger.info(_module, 'addRecurringTask: ${occurrences.length} occurrences');
    } catch (e, st) {
      _setError('Could not create recurring task. Please try again.', e, st);
      rethrow;
    } finally {
      _end();
    }
  }

  Future<void> updateTask(Task task) async {
    _begin();
    try {
      await _repo.update(task);
      await _syncReminder(task);
      AppLogger.info(_module, 'updateTask: ${task.id}');
    } catch (e, st) {
      _setError('Could not update task. Please try again.', e, st);
      rethrow;
    } finally {
      _end();
    }
  }

  Future<void> deleteTask(String taskId) async {
    _begin();
    try {
      await _notificationService.cancelNotification(_notificationIdFor(taskId));
      await _repo.delete(taskId);
      AppLogger.info(_module, 'deleteTask: $taskId');
    } catch (e, st) {
      _setError('Could not delete task. Please try again.', e, st);
      rethrow;
    } finally {
      _end();
    }
  }

  Future<void> deleteTaskSeries(String recurrenceId) async {
    _begin();
    try {
      final deletedIds = await _repo.deleteSeries(recurrenceId);
      for (final id in deletedIds) {
        await _notificationService.cancelNotification(_notificationIdFor(id));
      }
      AppLogger.info(_module, 'deleteTaskSeries: $recurrenceId');
    } catch (e, st) {
      _setError('Could not delete task series. Please try again.', e, st);
      rethrow;
    } finally {
      _end();
    }
  }

  Future<void> completeTask(Task task) => updateTask(task.copyWith(isCompleted: true, completedAt: DateTime.now()));
  Future<void> reopenTask(Task task) => updateTask(task.copyWith(isCompleted: false, clearCompletedAt: true));

  // ── State helpers ─────────────────────────────────────────────────────────

  int calculateStreak(List<Task> tasks) {
    final today = DateTime.now();
    final completedDates = tasks
        .where((t) => t.isCompleted)
        .map((t) {
          final date = t.completedAt ?? t.deadline;
          return DateTime(date.year, date.month, date.day);
        })
        .toSet()
        .toList();
    completedDates.sort((a, b) => b.compareTo(a));

    int streak = 0;
    final todayDate = DateTime(today.year, today.month, today.day);
    final yesterdayDate = todayDate.subtract(const Duration(days: 1));
    
    if (completedDates.isNotEmpty) {
      DateTime currentCheck = todayDate;
      if (completedDates.contains(todayDate)) {
        streak = 1;
        currentCheck = yesterdayDate;
      } else if (completedDates.contains(yesterdayDate)) {
        currentCheck = yesterdayDate;
      }

      while (streak > 0 || currentCheck == yesterdayDate) {
        if (completedDates.contains(currentCheck)) {
          if (currentCheck != todayDate) streak++;
          currentCheck = currentCheck.subtract(const Duration(days: 1));
        } else {
          break;
        }
      }
    }
    return streak;
  }

  void _begin() {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
  }

  void _end() {
    _isLoading = false;
    notifyListeners();
  }

  void _setError(String userMessage, Object error, StackTrace stackTrace) {
    _errorMessage = userMessage;
    AppLogger.error(_module, userMessage, error, stackTrace);
  }
}
