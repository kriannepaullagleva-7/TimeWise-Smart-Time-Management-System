import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import '../../providers/theme_provider.dart';
import '../../theme/app_colors.dart';

class AppearanceScreen extends StatefulWidget {
  const AppearanceScreen({super.key});

  @override
  State<AppearanceScreen> createState() => _AppearanceScreenState();
}

class _AppearanceScreenState extends State<AppearanceScreen> {
  String _selectedMode = 'system';
  String _activePreset = 'Default (Indigo)';
  Color _localAccent = AppColors.primary;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final themeProvider = context.read<ThemeProvider>();
      setState(() {
        _localAccent = themeProvider.accentColor;
        switch (themeProvider.themeMode) {
          case ThemeMode.light:
            _selectedMode = 'light';
            break;
          case ThemeMode.dark:
            _selectedMode = 'dark';
            break;
          default:
            _selectedMode = 'system';
        }
        
        bool foundPreset = false;
        for (var preset in _presets) {
          if (preset['primary'] == _localAccent) {
            _activePreset = preset['name'];
            foundPreset = true;
            break;
          }
        }
        if (!foundPreset) {
          _activePreset = 'Custom';
        }
      });
    });
  }

  void _updateThemeMode(String value) {
    setState(() {
      _selectedMode = value;
    });
    ThemeMode mode;
    if (value == 'light') {
      mode = ThemeMode.light;
    } else if (value == 'dark') {
      mode = ThemeMode.dark;
    } else {
      mode = ThemeMode.system;
    }
    context.read<ThemeProvider>().setThemeMode(mode);
  }

  void _updateAccentColor(Color color, String presetName) {
    setState(() {
      _localAccent = color;
      _activePreset = presetName;
    });
    context.read<ThemeProvider>().setAccentColor(color);
  }
  
  final List<Map<String, dynamic>> _modes = [
    {'value': 'system', 'label': 'System', 'icon': Icons.settings},
    {'value': 'light', 'label': 'Light', 'icon': Icons.light_mode},
    {'value': 'dark', 'label': 'Dark', 'icon': Icons.dark_mode},
  ];

  final List<Map<String, dynamic>> _presets = [
    {'name': 'Default (Indigo)', 'primary': AppColors.primary, 'secondary': AppColors.secondary},
    {'name': 'Midnight', 'primary': const Color(0xFF818CF8), 'secondary': const Color(0xFFC084FC)},
    {'name': 'Forest', 'primary': const Color(0xFF10B981), 'secondary': const Color(0xFF059669)},
    {'name': 'Sunset', 'primary': const Color(0xFFF59E0B), 'secondary': const Color(0xFFEF4444)},
  ];

  final List<Color> _swatches = [
    AppColors.primary,
    const Color(0xFF3B82F6), // Blue
    const Color(0xFF10B981), // Emerald
    const Color(0xFFF43F5E), // Rose
    const Color(0xFFF59E0B), // Amber
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: theme.colorScheme.outline),
                      ),
                      child: Icon(Icons.arrow_back, color: theme.colorScheme.onSurface, size: 20),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'Appearance',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 140),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Mode Switcher
                    _buildSectionLabel('COLOR MODE'),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: theme.colorScheme.outline),
                      ),
                      child: Row(
                        children: _modes.map((m) {
                          final isSelected = _selectedMode == m['value'];
                          return Expanded(
                            child: GestureDetector(
                              onTap: () => _updateThemeMode(m['value'] as String),
                              child: Container(
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : theme.colorScheme.surface,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isSelected ? AppColors.primary : theme.colorScheme.outline,
                                    width: isSelected ? 1.5 : 1,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      m['icon'] as IconData,
                                      color: isSelected ? AppColors.primary : theme.colorScheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      m['label'] as String,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: isSelected ? AppColors.primary : theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Preset Themes
                    _buildSectionLabel('PRESET THEMES'),
                    const SizedBox(height: 8),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 2.5,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: _presets.length,
                      itemBuilder: (context, index) {
                        final preset = _presets[index];
                        final isSelected = _activePreset == preset['name'];
                        return GestureDetector(
                          onTap: () => _updateAccentColor(preset['primary'] as Color, preset['name'] as String),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainer,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected ? preset['primary'] as Color : theme.colorScheme.outline,
                                width: isSelected ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 16,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    color: preset['primary'] as Color,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: -6),
                                Container(
                                  width: 16,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    color: preset['secondary'] as Color,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    preset['name'] as String,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isSelected)
                                  Icon(Icons.check_circle, size: 16, color: preset['primary'] as Color),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),

                    // Accent Swatches
                    _buildSectionLabel('ACCENT COLOR'),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: theme.colorScheme.outline),
                      ),
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: _swatches.map((color) {
                          final isSelected = _localAccent == color;
                          return GestureDetector(
                            onTap: () => _updateAccentColor(color, 'Custom'),
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: isSelected ? Border.all(color: theme.colorScheme.surface, width: 2) : null,
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: color.withValues(alpha: 0.5),
                                          blurRadius: 8,
                                          spreadRadius: 2,
                                        )
                                      ]
                                    : null,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(top: BorderSide(color: theme.colorScheme.outline)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _localAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Done', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: OutlinedButton(
                onPressed: () {
                  setState(() {
                    _selectedMode = 'system';
                    _activePreset = 'Default (Indigo)';
                    _localAccent = AppColors.primary;
                  });
                  context.read<ThemeProvider>().reset();
                },
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  side: BorderSide(color: Colors.red.withValues(alpha: 0.3)),
                  backgroundColor: Colors.red.withValues(alpha: 0.05),
                ),
                child: const Text('Reset to Default', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.5,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}
