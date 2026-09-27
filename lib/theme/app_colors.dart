import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Primary brand colors
  static const Color primary = Color(0xFF0070F0);
  static const Color secondary = Color(0xFF6BBDDD);
  
  // Additional semantic colors
  static const Color success = Color(0xFF16A34A);
  static const Color warning = Color(0xFFD97706);
  static const Color error = Color(0xFFDC2626);

  // Gradient definitions from TimeWise_UI
  static const LinearGradient btnGradient = LinearGradient(
    colors: [Color(0xFF0070F0), Color(0xFF0055CC)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient aiGradient = LinearGradient(
    colors: [Color(0xFF003DA5), Color(0xFF0070F0), Color(0xFF6BBDDD)],
    stops: [0.0, 0.55, 1.0],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const ColorScheme lightColorScheme = ColorScheme.light(
    primary: primary,
    secondary: secondary,
    surface: Color(0xFFFFFFFF),
    surfaceContainer: Color(0xFFF0F4FA),
    surfaceContainerHighest: Color(0xFFE4EAF3),
    onPrimary: Colors.white,
    onSecondary: Colors.white,
    onSurface: Color(0xFF0E0E0E),
    onSurfaceVariant: Color(0xFF4B4B4B),
    outline: Color(0xFFE4EAF3),
    outlineVariant: Color(0xFFC8D4E6),
    error: error,
    onError: Colors.white,
  );

  static const ColorScheme darkColorScheme = ColorScheme.dark(
    primary: primary,
    secondary: secondary,
    surface: Color(0xFF181818),
    surfaceContainer: Color(0xFF222222),
    surfaceContainerHighest: Color(0xFF2C2C2C),
    onPrimary: Colors.white,
    onSecondary: Colors.black,
    onSurface: Color(0xFFFFFFFF),
    onSurfaceVariant: Color(0xFFA0A0A0),
    outline: Color(0xFF2C2C2C),
    outlineVariant: Color(0xFF383838),
    error: Color(0xFFEF4444),
    onError: Colors.black,
  );
}
