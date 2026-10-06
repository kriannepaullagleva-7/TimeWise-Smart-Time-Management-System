import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/theme_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_styles.dart';
import '../widgets/ui.dart';

/// Color mode (system / light / dark) and accent color. Changes apply to the
/// whole app immediately and are remembered on the device.
class AppearanceScreen extends StatelessWidget {
  const AppearanceScreen({super.key});

  static const _modes = [
    (ThemeMode.system, 'System', Icons.brightness_auto_outlined),
    (ThemeMode.light, 'Light', Icons.light_mode_outlined),
    (ThemeMode.dark, 'Dark', Icons.dark_mode_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();

    return Scaffold(
      bottomNavigationBar: BottomActionBar(
              child: OutlinedButton.icon(
                onPressed: theme.reset,
                icon: const Icon(Icons.restart_alt),
                label: const Text('Reset to default'),
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              ),
            ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const ScreenHeader(title: 'Appearance'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(AppSpacing.page, 4, AppSpacing.page, 24),
                children: [
                  const SectionLabel('Color mode'),
                  Row(
                    children: [
                      for (final (mode, label, icon) in _modes) ...[
                        Expanded(
                          child: _ModeOption(
                            label: label,
                            icon: icon,
                            selected: theme.themeMode == mode,
                            onTap: () => theme.setThemeMode(mode),
                          ),
                        ),
                        if (mode != ThemeMode.dark) const SizedBox(width: 8),
                      ],
                    ],
                  ),
                  const SizedBox(height: 24),
                  const SectionLabel('Accent color'),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 3.2,
                    children: [
                      for (final preset in AppColors.accentPresets)
                        _AccentOption(
                          preset: preset,
                          selected: theme.accentColor.toARGB32() == preset.color.toARGB32(),
                          onTap: () => theme.setAccentColor(preset.color),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const SectionLabel('Preview'),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            IconTile(icon: Icons.task_alt),
                            const SizedBox(width: 12),
                            Expanded(child: Text('Write the project report', style: context.body.copyWith(fontWeight: FontWeight.w800))),
                            const TintBadge(label: 'High', color: Color(0xFFEF4444)),
                          ],
                        ),
                        const SizedBox(height: 14),
                        GradientButton(label: 'Primary button', onPressed: () {}),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ModeOption({required this.label, required this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      side: BorderSide(color: selected ? context.primary : context.cs.outline, width: selected ? 2 : 1.2),
    );
    final color = selected ? readableOn(context.primary, context.cs.surfaceContainer) : context.cs.onSurfaceVariant;
    return Semantics(
      button: true,
      selected: selected,
      label: '$label mode',
      child: Material(
        color: selected ? context.primary.withValues(alpha: 0.10) : context.cs.surfaceContainer,
        shape: shape,
        child: InkWell(
          customBorder: shape,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              children: [
                Icon(icon, color: color),
                const SizedBox(height: 6),
                Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AccentOption extends StatelessWidget {
  final AccentPreset preset;
  final bool selected;
  final VoidCallback onTap;

  const _AccentOption({required this.preset, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      side: BorderSide(color: selected ? preset.color : context.cs.outline, width: selected ? 2 : 1.2),
    );
    return Semantics(
      button: true,
      selected: selected,
      label: '${preset.name} accent',
      child: Material(
        color: context.cs.surfaceContainer,
        shape: shape,
        child: InkWell(
          customBorder: shape,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Container(width: 22, height: 22, decoration: BoxDecoration(color: preset.color, shape: BoxShape.circle)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(preset.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.body.copyWith(fontWeight: FontWeight.w700)),
                ),
                if (selected) Icon(Icons.check_circle, size: 20, color: preset.color),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
