import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_colors.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  Color _accentColor = AppColors.primary;
  bool _isReady = false;

  ThemeMode get themeMode => _themeMode;
  Color get accentColor => _accentColor;
  bool get isReady => _isReady;

  ThemeProvider() {
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    
    final modeStr = prefs.getString('theme_mode');
    if (modeStr == 'light') {
      _themeMode = ThemeMode.light;
    } else if (modeStr == 'dark') {
      _themeMode = ThemeMode.dark;
    } else {
      _themeMode = ThemeMode.system;
    }

    final accentVal = prefs.getInt('accent_color');
    if (accentVal != null) {
      _accentColor = Color(accentVal);
    }
    
    _isReady = true;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    String modeStr = 'system';
    if (mode == ThemeMode.light) {
      modeStr = 'light';
    } else if (mode == ThemeMode.dark) {
      modeStr = 'dark';
    }
    await prefs.setString('theme_mode', modeStr);
  }

  Future<void> setAccentColor(Color color) async {
    _accentColor = color;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('accent_color', color.toARGB32());
  }

  Future<void> reset() async {
    _themeMode = ThemeMode.system;
    _accentColor = AppColors.primary;
    notifyListeners();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('theme_mode');
    await prefs.remove('accent_color');
  }
}
