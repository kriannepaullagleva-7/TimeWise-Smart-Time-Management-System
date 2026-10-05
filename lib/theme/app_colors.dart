import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Brand colors. [primary] is the default accent; the user can pick another
  // one on the Appearance screen, so widgets must read the live accent from
  // `Theme.of(context).colorScheme.primary` (see `context.primary`).
  static const Color primary = Color(0xFF0070F0);
  static const Color secondary = Color(0xFF6BBDDD);

  // Additional semantic colors (fills and icons; use `readableOn` for text).
  static const Color success = Color(0xFF16A34A);
  static const Color warning = Color(0xFFD97706);
  static const Color error = Color(0xFFDC2626);

  /// Splash/welcome gradient (fixed brand colors).
  static const LinearGradient btnGradient = LinearGradient(
    colors: [Color(0xFF0070F0), Color(0xFF0055CC)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Used only by AI features so they stand out from the rest of the UI.
  /// Both ends keep at least 4.5:1 contrast with the white text placed on it.
  static const LinearGradient aiGradient = LinearGradient(
    colors: [Color(0xFF002F87), Color(0xFF0070F0)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Accent presets shown on the Appearance screen. Every color keeps at
  /// least 4.5:1 contrast with the white text placed on it.
  static const List<AccentPreset> accentPresets = [
    AccentPreset('TimeWise Blue', Color(0xFF0070F0)),
    AccentPreset('Indigo', Color(0xFF4F46E5)),
    AccentPreset('Forest', Color(0xFF047857)),
    AccentPreset('Sunset', Color(0xFFC2410C)),
    AccentPreset('Rose', Color(0xFFBE185D)),
    AccentPreset('Teal', Color(0xFF0F766E)),
  ];

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

class AccentPreset {
  final String name;
  final Color color;
  const AccentPreset(this.name, this.color);
}
