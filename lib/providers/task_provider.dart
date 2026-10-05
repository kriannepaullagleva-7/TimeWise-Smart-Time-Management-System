import 'dart:async';

import 'package:flutter/material.dart';

import '../models/recurrence.dart';
import '../models/task.dart';
import '../repositories/impl/firestore_task_repository.dart';
import '../repositories/task_repository.dart';
import '../services/notification_service.dart';
import '../utils/app_logger.dart';

/// Owns the signed-in user's tasks: ONE live Firestore subscription shared by
/// every screen (Dashboard, Tasks, Calendar, Profile) instead of one per
/// widget, plus all task mutations and reminder scheduling.
class TaskProvider extends ChangeNotifier {
  static const _module = 'TaskProvider';

  final TaskRepository _repo;
  final NotificationService _notifications;

  TaskProvider({
    TaskRepository? taskRepository,
    NotificationService? notificationService,
  })  : _repo = taskRepository ?? FirestoreTaskRepository(),
        _notifications = notificationService ?? NotificationService();

  StreamSubscription<List<Task>>? _sub;
  String? _uid;
  List<Task> _tasks = const [];
  bool _loaded = false;
  Object? _streamError;
  bool _remindersEnabled = true;
  bool _remindersSynced = false;
  bool _disposed = false;

  bool _isLoading = false;
  String? _errorMessage;

  // ── Live data ────────────────────────────────────────────────────────────

  /// Every task of the signed-in user, ordered by deadline.
  List<Task> get tasks => _tasks;

  /// False until the first snapshot (or error) has arrived.
  bool get isLoaded => _loaded;

  /// Set when the live query failed (for example a missing index or rules).
  Object? get streamError => _streamError;

  String? get userId => _uid;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  List<Task> get pending => _tasks.where((t) => !t.isCompleted).toList();

  Task? byId(String id) {
    for (final t in _tasks) {
      if (t.id == id) return t;
    }
    return null;
  }

  /// Starts (or stops, with null) the shared subscription for [uid]. Safe to
  /// call repeatedly with the same uid.
  void attachUser(String? uid) {
    final normalised = (uid == null || uid.isEmpty) ? null : uid;
    if (normalised == _uid) return;

    _sub?.cancel();
    _sub = null;
    _uid = normalised;
    _tasks = const [];
    _loaded = false;
    _streamError = null;
    _remindersSynced = false;

    if (normalised != null) {
      _sub = _repo.watchAll(normalised).listen(
        (list) {
          _tasks = list;
          _loaded = true;
          _streamError = null;
          _notify();
          if (!_remindersSynced) {
            _remindersSynced = true;
            _rescheduleUpcomingReminders();
          }
        },
        onError: (Object e, StackTrace st) {
          AppLogger.error(_module, 'task stream error', e, st);
          _streamError = e;
          _loaded = true;
          _notify();
        },
      );
    }
    // attachUser runs while the widget tree builds (ProxyProvider.update);
    // notify after the current frame.
    scheduleMicrotask(_notify);
  }

  /// Re-opens the live query after a failure (used by the error state's Retry).
  void retry() {
    final uid = _uid;
    _uid = null;
    attachUser(uid);
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  // ── Reminders ────────────────────────────────────────────────────────────

  /// Number of upcoming reminders kept scheduled with the OS (well under
  /// Android's alarm limits and iOS's 64-notification ceiling).
  static const _maxScheduledReminders = 40;

  bool get remindersEnabled => _remindersEnabled;

  void setRemindersEnabled(bool enabled) {
    if (enabled == _remindersEnabled) return;
    _remindersEnabled = enabled;
    if (enabled) {
      _rescheduleUpcomingReminders();
    } else {
      _notifications.cancelAllNotifications();
    }
  }

  /// Stable across app launches and Dart versions (FNV-1a), unlike String.hashCode.
  static int notificationIdFor(String taskId) {
    var hash = 0x811c9dc5;
    for (final unit in taskId.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash & 0x7fffffff;
  }

  bool _notificationsAllowed = false;
  bool _permissionAsked = false;

  /// Asks for the notification permission once per session; remembers a yes.
  Future<bool> _canNotify() async {
    if (_notificationsAllowed) return true;
    if (_permissionAsked) return false;
    _permissionAsked = true;
    _notificationsAllowed = await _notifications.ensurePermission();
    return _notificationsAllowed;
  }

  Future<void> _syncReminder(Task task) async {
    final notifId = notificationIdFor(task.id);
    await _notifications.cancelNotification(notifId);

    final reminderTime = task.reminderTime;
    if (!_remindersEnabled || task.isCompleted || reminderTime == null) return;
    if (reminderTime.isBefore(DateTime.now())) return;

    // Android 13+ needs the user's permission before any notification shows.
    // Asked here, the first time a reminder is actually scheduled.
    if (!await _canNotify()) return;
    await _notifications.scheduleTaskReminder(notifId, task.title, reminderTime);
  }

  /// Re-registers the next reminders after the tasks load, so occurrences of a
  /// long repeating series beyond the first few still get their reminder.
  Future<void> _rescheduleUpcomingReminders() async {
    if (!_remindersEnabled) return;
    final now = DateTime.now();
    final upcoming = _tasks
        .where((t) => !t.isCompleted && t.reminderTime != null && t.reminderTime!.isAfter(now))
        .toList()
      ..sort((a, b) => a.reminderTime!.compareTo(b.reminderTime!));
    for (final task in upcoming.take(_maxScheduledReminders)) {
      await _syncReminder(task);
    }
  }

  /// Cancels every reminder (used when signing out).
  Future<void> cancelAllReminders() => _notifications.cancelAllNotifications();

  // ── Mutations ─────────────────────────────────────────────────────────────

  String newTaskId() => _repo.newId();

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

  Future<void> addRecurringTask(Task base, RecurrenceRule rule) async {
    _begin();
    try {
      final dates = rule.occurrencesFrom(base.deadline);
      final timeOfDay = TimeOfDay.fromDateTime(base.deadline);

      final occurrences = dates.map((date) {
        final deadline = DateTime(date.year, date.month, date.day, timeOfDay.hour, timeOfDay.minute);
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
          // Every occurrence gets its own copy of the subtask checklist.
          subtasks: base.subtasks.map((s) => Subtask(id: s.id, title: s.title)).toList(),
          recurrenceId: base.id,
          recurrence: rule,
        );
      }).toList();

      await _repo.addBatch(occurrences);
      for (final task in occurrences.take(_maxScheduledReminders)) {
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
      await _notifications.cancelNotification(notificationIdFor(taskId));
      await _repo.delete(taskId);
      AppLogger.info(_module, 'deleteTask: $taskId');
    } catch (e, st) {
      _setError('Could not delete task. Please try again.', e, st);
      rethrow;
    } finally {
      _end();
    }
  }

  Future<void> deleteTaskSeries(String userId, String recurrenceId) async {
    _begin();
    try {
      final deletedIds = await _repo.deleteSeries(userId, recurrenceId);
      for (final id in deletedIds) {
        await _notifications.cancelNotification(notificationIdFor(id));
      }
      AppLogger.info(_module, 'deleteTaskSeries: $recurrenceId');
    } catch (e, st) {
      _setError('Could not delete task series. Please try again.', e, st);
      rethrow;
    } finally {
      _end();
    }
  }

  /// Marks a task done. Only the completion fields are written, so a stale
  /// copy of the task cannot overwrite other edits.
  Future<void> completeTask(Task task) async {
    await _repo.setCompletion(task.id, completed: true, completedAt: DateTime.now());
    await _notifications.cancelNotification(notificationIdFor(task.id));
  }

  Future<void> reopenTask(Task task) async {
    await _repo.setCompletion(task.id, completed: false, completedAt: null);
    await _syncReminder(task.copyWith(isCompleted: false, clearCompletedAt: true));
  }

  Future<void> setSubtasks(Task task, List<Subtask> subtasks) => _repo.setSubtasks(task.id, subtasks);

  /// Writes the focus time of a task (called by FocusProvider).
  Future<void> setElapsed(String taskId, int seconds) async {
    try {
      await _repo.setElapsed(taskId, seconds);
    } catch (e, st) {
      AppLogger.error(_module, 'setElapsed failed for $taskId', e, st);
    }
  }

  // ── Derived values ───────────────────────────────────────────────────────

  /// Hides the future occurrences of a repeating task so a daily task does not
  /// bury the list: keeps every one-off task, every completed task, every
  /// overdue occurrence and only the NEXT upcoming occurrence of each series.
  static List<Task> collapseSeries(List<Task> tasks, {DateTime? now}) {
    final reference = now ?? DateTime.now();
    final sorted = [...tasks]..sort((a, b) => a.deadline.compareTo(b.deadline));
    final seenSeries = <String>{};
    final result = <Task>[];
    for (final task in sorted) {
      final series = task.recurrenceId;
      if (series == null || task.isCompleted || !task.deadline.isAfter(reference)) {
        result.add(task);
      } else if (seenSeries.add(series)) {
        result.add(task);
      }
    }
    return result;
  }

  /// Pending tasks worth planning on [date]: overdue ones and those due within
  /// [horizonDays], the next occurrence of repeating tasks only, most urgent
  /// first, capped at [limit] so the AI prompt stays small.
  static List<Task> planningCandidates(
    List<Task> tasks,
    DateTime date, {
    int horizonDays = 7,
    int limit = 15,
  }) {
    final dayStart = DateTime(date.year, date.month, date.day);
    final horizon = DateTime(date.year, date.month, date.day + horizonDays + 1);
    final pending = tasks.where((t) => !t.isCompleted && t.deadline.isBefore(horizon)).toList();
    final collapsed = collapseSeries(pending, now: dayStart);
    collapsed.sort((a, b) {
      if (a.priority != b.priority) return b.priority.compareTo(a.priority);
      return a.deadline.compareTo(b.deadline);
    });
    return collapsed.take(limit).toList();
  }

  /// Share of finished tasks among those that are due or done (future
  /// occurrences of repeating tasks do not dilute the rate).
  static int completionRate(List<Task> tasks, {DateTime? now}) {
    final reference = now ?? DateTime.now();
    final considered = tasks.where((t) => t.isCompleted || !t.deadline.isAfter(reference)).toList();
    if (considered.isEmpty) return 0;
    final done = considered.where((t) => t.isCompleted).length;
    return ((done / considered.length) * 100).round();
  }

  /// Total logged focus time in seconds.
  static int focusSeconds(List<Task> tasks) => tasks.fold(0, (sum, t) => sum + t.elapsedSeconds);

  /// Calendar days (midnight) on which at least one task was completed.
  static Set<DateTime> completionDays(List<Task> tasks) => tasks
      .where((t) => t.isCompleted)
      .map((t) {
        final date = t.completedAt ?? t.deadline;
        return DateTime(date.year, date.month, date.day);
      })
      .toSet();

  int calculateStreak(List<Task> tasks, {DateTime? now}) {
    final today = now ?? DateTime.now();
    final completedDates = completionDays(tasks);

    final todayDate = DateTime(today.year, today.month, today.day);
    // Calendar arithmetic (not Duration) so daylight-saving changes cannot skip a day.
    DateTime previous(DateTime d) => DateTime(d.year, d.month, d.day - 1);

    var check = completedDates.contains(todayDate) ? todayDate : previous(todayDate);
    var streak = 0;
    while (completedDates.contains(check)) {
      streak++;
      check = previous(check);
    }
    return streak;
  }

  // ── State helpers ─────────────────────────────────────────────────────────

  void _begin() {
    _isLoading = true;
    _errorMessage = null;
    _notify();
  }

  void _end() {
    _isLoading = false;
    _notify();
  }

  void _setError(String userMessage, Object error, StackTrace stackTrace) {
    _errorMessage = userMessage;
    AppLogger.error(_module, userMessage, error, stackTrace);
  }

  @override
  void dispose() {
    _disposed = true;
    _sub?.cancel();
    super.dispose();
  }
}
