import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/task.dart';
import '../services/notification_service.dart';
import '../utils/app_logger.dart';
import 'task_provider.dart';

enum FocusState { stopped, running, paused, finished }

/// Focus-session timer for one task.
///
/// Elapsed time is derived from timestamps (not by counting timer ticks), so
/// it stays correct when the app is in the background or the phone is busy.
/// The session survives leaving the screen and an app restart, and the focus
/// time is written to the task with a partial update every minute.
class FocusProvider with ChangeNotifier {
  static const _module = 'FocusProvider';
  static const _kTaskId = 'focus_task_id';
  static const _kState = 'focus_state';
  static const _kTotal = 'focus_total_seconds';
  static const _kBase = 'focus_base_elapsed';
  static const _kStarted = 'focus_run_started_ms';
  static const _kTick = 'focus_last_tick_ms';

  final NotificationService _notifications;
  final DateTime Function() _clock;

  FocusProvider({NotificationService? notifications, DateTime Function()? clock})
      : _notifications = notifications ?? NotificationService(),
        _clock = clock ?? DateTime.now {
    _loadState();
  }

  FocusState _state = FocusState.stopped;
  Task? _currentTask;
  String? _restoredTaskId;

  int _totalSeconds = 0;
  int _baseElapsed = 0; // seconds accumulated before the current run
  DateTime? _runStartedAt;
  int _lastSyncedSeconds = 0;
  int _lastPersistedSeconds = -10;
  Timer? _timer;

  TaskProvider? _taskProvider;

  FocusState get state => _state;
  Task? get currentTask => _currentTask;

  /// A session exists (running, paused or finished) and its task is known.
  bool get hasSession => _currentTask != null && _state != FocusState.stopped;

  int get totalSeconds => _totalSeconds;

  int get elapsedSeconds {
    var run = 0;
    if (_state == FocusState.running && _runStartedAt != null) {
      run = _clock().difference(_runStartedAt!).inSeconds;
      if (run < 0) run = 0;
    }
    return _baseElapsed + run;
  }

  int get remainingSeconds => max(0, _totalSeconds - elapsedSeconds);

  double get progress => _totalSeconds > 0 ? min(1.0, elapsedSeconds / _totalSeconds) : 0;

  void updateTaskProvider(TaskProvider taskProvider) {
    _taskProvider = taskProvider;
    _tryRestoreTask();
  }

  // ── Persistence ──────────────────────────────────────────────────────────

  Future<void> _loadState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // A session started while the saved one was still loading wins.
      if (_state != FocusState.stopped) return;
      final taskId = prefs.getString(_kTaskId);
      if (taskId == null) return;

      _restoredTaskId = taskId;
      _totalSeconds = prefs.getInt(_kTotal) ?? 0;
      _baseElapsed = prefs.getInt(_kBase) ?? 0;

      // If the app was closed while running, count the time up to the last
      // saved tick and restore the session as paused: the user resumes it.
      final started = prefs.getInt(_kStarted);
      final lastTick = prefs.getInt(_kTick);
      if (prefs.getString(_kState) == 'running' && started != null && lastTick != null && lastTick > started) {
        _baseElapsed += (lastTick - started) ~/ 1000;
      }
      _state = _baseElapsed >= _totalSeconds && _totalSeconds > 0 ? FocusState.finished : FocusState.paused;
      _lastSyncedSeconds = _baseElapsed;
      _tryRestoreTask();
      notifyListeners();
    } catch (e, st) {
      AppLogger.error(_module, 'could not restore focus session', e, st);
    }
  }

  /// Connects a restored session to its task once the tasks have loaded.
  void _tryRestoreTask() {
    final tp = _taskProvider;
    final id = _restoredTaskId;
    if (tp == null || id == null || _currentTask != null || !tp.isLoaded) return;
    final task = tp.byId(id);
    if (task == null) {
      // The task was deleted while the session was saved.
      _restoredTaskId = null;
      _clearSession();
      scheduleMicrotask(notifyListeners);
      return;
    }
    _currentTask = task;
    _restoredTaskId = null;
    scheduleMicrotask(notifyListeners);
  }

  Future<void> _persist() async {
    final task = _currentTask;
    if (task == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kTaskId, task.id);
      await prefs.setString(_kState, _state.name);
      await prefs.setInt(_kTotal, _totalSeconds);
      await prefs.setInt(_kBase, _baseElapsed);
      if (_state == FocusState.running && _runStartedAt != null) {
        await prefs.setInt(_kStarted, _runStartedAt!.millisecondsSinceEpoch);
        await prefs.setInt(_kTick, _clock().millisecondsSinceEpoch);
      } else {
        await prefs.remove(_kStarted);
        await prefs.remove(_kTick);
      }
      _lastPersistedSeconds = elapsedSeconds;
    } catch (e) {
      AppLogger.warning(_module, 'could not save focus session', e);
    }
  }

  Future<void> _clearSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final key in [_kTaskId, _kState, _kTotal, _kBase, _kStarted, _kTick]) {
        await prefs.remove(key);
      }
    } catch (_) {}
  }

  // ── Controls ─────────────────────────────────────────────────────────────

  /// Starts a session for [task], or continues the current one for the same task.
  Future<void> startFocus(Task task) async {
    final sameTask = _currentTask?.id == task.id && _state != FocusState.stopped;
    if (sameTask) {
      if (_state == FocusState.paused) resumeFocus();
      return;
    }

    if (_currentTask != null && _state != FocusState.stopped) {
      await _stopCurrent(); // a session for another task was open: save and close it
    }

    _currentTask = task;
    _restoredTaskId = null;
    _totalSeconds = max(1, task.estimatedMinutes) * 60;
    _baseElapsed = task.elapsedSeconds;
    _lastSyncedSeconds = _baseElapsed;

    if (_baseElapsed >= _totalSeconds) {
      _state = FocusState.finished; // estimate already used up: offer more time
      await _persist();
      notifyListeners();
      return;
    }
    _beginRun();
  }

  void resumeFocus() {
    if (_currentTask == null || _state == FocusState.running) return;
    if (_baseElapsed >= _totalSeconds) {
      _state = FocusState.finished;
      notifyListeners();
      return;
    }
    _beginRun();
  }

  void _beginRun() {
    _state = FocusState.running;
    _runStartedAt = _clock();
    _startTimer();
    _scheduleEndNotification();
    _persist();
    notifyListeners();
  }

  Future<void> pauseFocus() async {
    if (_state != FocusState.running) return;
    _baseElapsed = elapsedSeconds;
    _runStartedAt = null;
    _state = FocusState.paused;
    _timer?.cancel();
    _notifications.cancelFocusEnd();
    await _persist();
    await _syncElapsed();
    notifyListeners();
  }

  /// Adds time to a finished session and continues.
  void extendFocus(int minutes) {
    if (_currentTask == null) return;
    _totalSeconds += minutes * 60;
    _beginRun();
  }

  /// Ends the session, saving the focus time.
  Future<void> stopFocus() async {
    await _stopCurrent();
    notifyListeners();
  }

  Future<void> _stopCurrent() async {
    _baseElapsed = elapsedSeconds;
    _runStartedAt = null;
    _timer?.cancel();
    _notifications.cancelFocusEnd();
    await _syncElapsed();
    _state = FocusState.stopped;
    _currentTask = null;
    _restoredTaskId = null;
    _totalSeconds = 0;
    _baseElapsed = 0;
    _lastSyncedSeconds = 0;
    await _clearSession();
  }

  // ── Ticking ──────────────────────────────────────────────────────────────

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    if (_state != FocusState.running) return;
    final elapsed = elapsedSeconds;
    if (elapsed >= _totalSeconds) {
      _finish();
      return;
    }
    if (elapsed - _lastPersistedSeconds >= 10) _persist();
    if (elapsed - _lastSyncedSeconds >= 60) _syncElapsed();
    notifyListeners();
  }

  void _finish() {
    _baseElapsed = elapsedSeconds;
    _runStartedAt = null;
    _state = FocusState.finished;
    _timer?.cancel();
    _persist();
    _syncElapsed();
    notifyListeners();
  }

  /// Writes the focus time to the task (partial update, no stale overwrite).
  Future<void> _syncElapsed() async {
    final task = _currentTask;
    if (task == null || _taskProvider == null) return;
    final seconds = elapsedSeconds;
    _lastSyncedSeconds = seconds;
    _currentTask = task.copyWith(elapsedSeconds: seconds);
    await _taskProvider!.setElapsed(task.id, seconds);
  }

  void _scheduleEndNotification() {
    final task = _currentTask;
    if (task == null) return;
    final endsAt = _clock().add(Duration(seconds: remainingSeconds));
    _notifications.ensurePermission().then((granted) {
      if (granted) _notifications.scheduleFocusEnd(endsAt, task.title);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
