import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/task.dart';
import 'task_provider.dart';

enum FocusState { stopped, running, paused, finished }

class FocusProvider with ChangeNotifier {
  FocusState _state = FocusState.stopped;
  Task? _currentTask;
  
  int _elapsedSeconds = 0;
  int _totalSeconds = 0;
  Timer? _timer;
  
  TaskProvider? _taskProvider;
  
  FocusState get state => _state;
  Task? get currentTask => _currentTask;
  
  int get remainingSeconds => max(0, _totalSeconds - _elapsedSeconds);
  int get totalSeconds => _totalSeconds;
  int get elapsedSeconds => _elapsedSeconds;
  
  double get progress => _totalSeconds > 0 ? min(1.0, _elapsedSeconds / _totalSeconds) : 0;
  
  FocusProvider() {
    _loadState();
  }
  
  void updateTaskProvider(TaskProvider taskProvider) {
    _taskProvider = taskProvider;
  }

  void _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final taskId = prefs.getString('focus_task_id');
    if (taskId != null) {
      final endTimeMs = prefs.getInt('focus_last_tick_ms');
      final stateStr = prefs.getString('focus_state');
      final totalSecs = prefs.getInt('focus_total_seconds') ?? 0;
      final savedElapsed = prefs.getInt('focus_elapsed_seconds') ?? 0;
      
      _totalSeconds = totalSecs;
      _elapsedSeconds = savedElapsed;
      
      if (stateStr == 'running' && endTimeMs != null) {
        final lastTick = DateTime.fromMillisecondsSinceEpoch(endTimeMs);
        final now = DateTime.now();
        if (now.isAfter(lastTick)) {
          final diff = now.difference(lastTick).inSeconds;
          _elapsedSeconds += diff;
        }
        _state = FocusState.paused; // Set to paused on load, so user manually resumes
      } else if (stateStr == 'paused') {
        _state = FocusState.paused;
      }
      
      // Load task if possible, we'll need a way to get it
      // Wait for startFocus to be called by UI, or we can just leave currentTask null
      // until UI provides it. Usually UI will navigate to FocusScreen with task.
    }
  }

  void syncTask(Task task) {
    if (_currentTask?.id == task.id && _state != FocusState.stopped) {
       // Just update reference
       _currentTask = task;
    }
  }

  void startFocus(Task task) async {
    if (_state == FocusState.running && _currentTask?.id != task.id) {
      stopFocus();
    }
    
    _currentTask = task;
    _totalSeconds = task.estimatedMinutes * 60;
    
    // If starting fresh, load elapsed seconds from task
    // If we already have local state for THIS task, keep local elapsedSeconds
    final prefs = await SharedPreferences.getInstance();
    final savedTaskId = prefs.getString('focus_task_id');
    
    if (savedTaskId == task.id && _elapsedSeconds > 0) {
      // Keep local
    } else {
      _elapsedSeconds = task.elapsedSeconds;
    }
    
    _state = FocusState.running;
    
    await _saveState();
    _startTimer();
    notifyListeners();
  }
  
  void resumeFocus(Task task) async {
    if (_state == FocusState.paused && _currentTask?.id == task.id) {
      _state = FocusState.running;
      await _saveState();
      _startTimer();
      notifyListeners();
    } else if (_state == FocusState.stopped || _currentTask?.id != task.id) {
      startFocus(task);
    }
  }

  void pauseFocus() async {
    _timer?.cancel();
    _state = FocusState.paused;
    await _saveState();
    _syncToTaskProvider();
    notifyListeners();
  }

  void stopFocus() async {
    _timer?.cancel();
    _state = FocusState.stopped;
    _syncToTaskProvider(); // Save final time
    
    _currentTask = null;
    _elapsedSeconds = 0;
    _totalSeconds = 0;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('focus_task_id');
    await prefs.remove('focus_last_tick_ms');
    await prefs.remove('focus_state');
    await prefs.remove('focus_total_seconds');
    await prefs.remove('focus_elapsed_seconds');
    
    notifyListeners();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _elapsedSeconds++;
      
      // Auto-complete if it hits total? 
      // User requested: "Prevent accidental task completion when stopping unless the user explicitly marks it complete."
      // So we just keep ticking or stop at 100%. Let's just keep ticking (progress maxes at 1.0).
      
      if (_elapsedSeconds % 10 == 0) {
         // Periodically save state in case of crash
         _saveState();
      }
      
      if (_elapsedSeconds % 60 == 0) {
        // Sync to cloud every minute
        _syncToTaskProvider();
      }
      
      notifyListeners();
    });
  }
  
  void _syncToTaskProvider() {
    if (_currentTask != null && _taskProvider != null) {
      final updatedTask = _currentTask!.copyWith(elapsedSeconds: _elapsedSeconds);
      _currentTask = updatedTask;
      _taskProvider!.updateTask(updatedTask);
    }
  }
  
  Future<void> _saveState() async {
    if (_currentTask == null) return;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('focus_task_id', _currentTask!.id);
    await prefs.setString('focus_state', _state.toString().split('.').last);
    await prefs.setInt('focus_total_seconds', _totalSeconds);
    await prefs.setInt('focus_elapsed_seconds', _elapsedSeconds);
    
    if (_state == FocusState.running) {
      await prefs.setInt('focus_last_tick_ms', DateTime.now().millisecondsSinceEpoch);
    } else {
      await prefs.remove('focus_last_tick_ms');
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
