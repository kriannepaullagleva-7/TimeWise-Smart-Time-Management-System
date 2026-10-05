import 'package:shared_preferences/shared_preferences.dart';

/// Keeps the onboarding quiz answers on the device until the user signs in,
/// then hands them to the profile (see AuthProvider).
class OnboardingStore {
  OnboardingStore._();

  static const _keys = ['wake', 'sleep', 'usage', 'scheduleStyle', 'aiHelp'];
  static String _k(String name) => 'onboarding_$name';

  static Future<void> save(Map<String, String> answers) async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in _keys) {
      final value = answers[key];
      if (value == null || value.isEmpty) {
        await prefs.remove(_k(key));
      } else {
        await prefs.setString(_k(key), value);
      }
    }
  }

  /// Returns the saved answers (or null) and removes them.
  static Future<Map<String, String>?> consume() async {
    final prefs = await SharedPreferences.getInstance();
    final result = <String, String>{};
    for (final key in _keys) {
      final value = prefs.getString(_k(key));
      if (value != null && value.isNotEmpty) result[key] = value;
      await prefs.remove(_k(key));
    }
    return result.isEmpty ? null : result;
  }
}
