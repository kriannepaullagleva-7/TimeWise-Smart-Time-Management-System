import 'package:flutter/material.dart';

/// Shortcuts so screens style themselves from the live theme (and therefore
/// from the accent color chosen on the Appearance screen).
extension AppThemeContext on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get cs => Theme.of(this).colorScheme;
  Color get primary => Theme.of(this).colorScheme.primary;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  LinearGradient get primaryGradient => AppGradients.fromColor(primary);

  /// Headline of a screen.
  TextStyle get h1 => TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: cs.onSurface);

  /// Title in a header bar or card.
  TextStyle get h2 => TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: cs.onSurface);

  /// Section title above a list.
  TextStyle get h3 => TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: cs.onSurface);

  /// Default reading text.
  TextStyle get body => TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: cs.onSurface);

  /// Secondary text.
  TextStyle get bodyMuted =>
      TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: cs.onSurfaceVariant);

  /// Small label / metadata (never below 12).
  TextStyle get label =>
      TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant);

  /// Smallest text allowed in the app (badges, captions).
  TextStyle get caption => TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: cs.onSurfaceVariant);
}

class AppRadius {
  AppRadius._();
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
}

class AppSpacing {
  AppSpacing._();
  static const double page = 20;
  static const double gap = 12;
  static const double section = 24;
}

class AppGradients {
  AppGradients._();

  static LinearGradient fromColor(Color c) => LinearGradient(
        colors: [c, Color.lerp(c, Colors.black, 0.18)!],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
}

/// Priority color: 3 = High, 2 = Medium, 1 = Low.
Color priorityColor(int priority) {
  switch (priority) {
    case 3:
      return const Color(0xFFEF4444);
    case 2:
      return const Color(0xFFF59E0B);
    default:
      return const Color(0xFF10B981);
  }
}

const List<Color> _categoryPalette = [
  Color(0xFF6366F1),
  Color(0xFF0EA5E9),
  Color(0xFF10B981),
  Color(0xFFF97316),
  Color(0xFF8B5CF6),
  Color(0xFFEC4899),
  Color(0xFF14B8A6),
  Color(0xFFA855F7),
];

/// One color per category name, identical on every screen. Well-known names
/// keep a fixed color; custom categories get a stable color from their name.
Color categoryColor(String category) {
  switch (category.trim().toLowerCase()) {
    case 'school':
    case 'study':
      return _categoryPalette[0];
    case 'work':
      return _categoryPalette[1];
    case 'personal':
      return _categoryPalette[2];
    case 'fitness':
    case 'health':
      return _categoryPalette[3];
    case 'other':
    case 'general':
      return _categoryPalette[4];
  }
  var hash = 0;
  for (final unit in category.codeUnits) {
    hash = (hash * 31 + unit) & 0x7fffffff;
  }
  return _categoryPalette[hash % _categoryPalette.length];
}

double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

/// Returns [base], darkened (on light backgrounds) or lightened (on dark
/// backgrounds) until it reaches [minRatio] contrast against [background].
/// Bright status colors (green, amber, sky) fail WCAG AA as small text on
/// their own tint; this keeps their hue but makes the text readable.
Color readableOn(Color base, Color background, {double minRatio = 4.6}) {
  var hsl = HSLColor.fromColor(base);
  var color = base;
  final makeDarker = background.computeLuminance() > 0.4;
  var guard = 0;
  while (contrastRatio(color, background) < minRatio && guard++ < 50) {
    final next = hsl.lightness + (makeDarker ? -0.02 : 0.02);
    if (next < 0.04 || next > 0.96) break;
    hsl = hsl.withLightness(next);
    color = hsl.toColor();
  }
  return color;
}
