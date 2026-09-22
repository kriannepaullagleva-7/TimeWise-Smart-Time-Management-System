import 'package:flutter/material.dart';

import '../models/recurrence.dart';
import '../models/task.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';

class TaskProvider extends ChangeNotifier {
  final FirestoreService _firestoreService;
  final NotificationService _notificationService;

  TaskProvider({
    FirestoreService? firestoreService,
    NotificationService? notificationService,
  })  : _firestoreService = firestoreService ?? FirestoreService(),
        _notificationService = notificationService ?? NotificationService();

  bool _isLoading = false;

  bool get isLoading => _isLoading;

  Stream<List<Task>> getUserTasksStream(String userId) {
    return _firestoreService.getUserTasks(userId);
  }

  Stream<List<Task>> getActiveTasksStream(String userId) {
    return _firestoreService.getActiveTasks(userId);
  }

  String newTaskId() => _firestoreService.newTaskId();

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

  Future<void> addTask(Task task) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _firestoreService.addTask(task);
      await _syncReminder(task);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Number of upcoming occurrences to auto-schedule a local reminder for.
  /// Kept well under iOS's 64-pending-notification ceiling, which also has
  /// to leave room for the user's other tasks.
  static const _maxRemindersPerSeries = 20;

  /// Creates every occurrence of a repeating task in one batch, using
  /// [base]'s own id as the series' `recurrenceId`. Only the nearest
  /// occurrences get a local reminder scheduled (see
  /// [_maxRemindersPerSeries]); the rest still show up and can be reminded
  /// once notifications are re-synced closer to their date.
  Future<void> addRecurringTask(Task base, RecurrenceRule rule) async {
    _isLoading = true;
    notifyListeners();

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
          id: date == dates.first ? base.id : _firestoreService.newTaskId(),
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

      await _firestoreService.addTasksBatch(occurrences);

      for (final task in occurrences.take(_maxRemindersPerSeries)) {
        await _syncReminder(task);
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateTask(Task task) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _firestoreService.updateTask(task);
      await _syncReminder(task);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteTask(String taskId) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _notificationService.cancelNotification(_notificationIdFor(taskId));
      await _firestoreService.deleteTask(taskId);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Deletes every occurrence of the repeating series [recurrenceId] belongs
  /// to, cancelling any reminders that were scheduled for them.
  Future<void> deleteTaskSeries(String recurrenceId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final deletedIds = await _firestoreService.deleteTaskSeries(recurrenceId);
      for (final id in deletedIds) {
        await _notificationService.cancelNotification(_notificationIdFor(id));
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> completeTask(Task task) async {
    await updateTask(task.copyWith(isCompleted: true));
  }

  Future<void> reopenTask(Task task) async {
    await updateTask(task.copyWith(isCompleted: false));
  }
}
