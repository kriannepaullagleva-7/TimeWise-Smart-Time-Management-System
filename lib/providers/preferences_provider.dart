import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App-level switches stored on the device (Profile → Notifications).
class PreferencesProvider extends ChangeNotifier {
  static const _kReminders = 'pref_task_reminders';
  static const _kAi = 'pref_ai_suggestions';

  bool _taskReminders = true;
  bool _aiSuggestions = true;
  bool _ready = false;

  PreferencesProvider() {
    _load();
  }

  /// When off, no task reminder notification is scheduled and pending ones are cancelled.
  bool get taskReminders => _taskReminders;

  /// When off, the AI planner card and the AI Schedule button are hidden.
  bool get aiSuggestions => _aiSuggestions;

  bool get isReady => _ready;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _taskReminders = prefs.getBool(_kReminders) ?? true;
    _aiSuggestions = prefs.getBool(_kAi) ?? true;
    _ready = true;
    notifyListeners();
  }

  Future<void> setTaskReminders(bool value) async {
    _taskReminders = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kReminders, value);
  }

  Future<void> setAiSuggestions(bool value) async {
    _aiSuggestions = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAi, value);
  }
}
