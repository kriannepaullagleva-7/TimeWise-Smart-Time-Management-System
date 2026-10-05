import 'package:flutter/material.dart';

import '../theme/app_styles.dart';

/// Shared empty / error placeholder used across Tasks, Calendar and the AI
/// review so "nothing here" and "something failed" look the same everywhere.
class EmptyState extends StatelessWidget {
  final IconData? icon;
  final String title;
  final String? subtitle;
  final Widget? action;
  final bool compact;

  const EmptyState({
    this.icon,
    required this.title,
    this.subtitle,
    this.action,
    this.compact = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final size = compact ? 56.0 : 80.0;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon == null)
              Image.asset('assets/images/timewise_pet.png', width: size, height: size, excludeFromSemantics: true)
            else
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: context.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: size * 0.45, color: context.primary),
              ),
            const SizedBox(height: 16),
            Text(title, style: context.h3, textAlign: TextAlign.center),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(subtitle!, style: context.bodyMuted, textAlign: TextAlign.center),
            ],
            if (action != null) ...[
              const SizedBox(height: 16),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
