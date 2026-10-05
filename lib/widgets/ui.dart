import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_styles.dart';

/// 44 px square back / action button used in every screen header.
class AppBackButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final IconData icon;
  final String tooltip;

  const AppBackButton({
    super.key,
    this.onPressed,
    this.icon = Icons.arrow_back,
    this.tooltip = 'Back',
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: context.cs.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          side: BorderSide(color: context.cs.outline),
        ),
        child: InkWell(
          customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
          onTap: onPressed ?? () => Navigator.maybePop(context),
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(icon, size: 20, color: context.cs.onSurface, semanticLabel: tooltip),
          ),
        ),
      ),
    );
  }
}

/// Header row used by pushed screens: back button, title (+ subtitle), trailing action.
class ScreenHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onBack;
  final bool showBack;

  const ScreenHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onBack,
    this.showBack = true,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.page, 16, AppSpacing.page, 12),
      child: Row(
        children: [
          if (showBack) ...[
            AppBackButton(onPressed: onBack),
            const SizedBox(width: 14),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.h2, maxLines: 1, overflow: TextOverflow.ellipsis),
                if (subtitle != null)
                  Text(subtitle!, style: context.label, maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 12), trailing!],
        ],
      ),
    );
  }
}

/// Small upper-case label above a group of fields or rows.
class SectionLabel extends StatelessWidget {
  final String text;
  const SectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: context.caption.copyWith(letterSpacing: 1.2),
      ),
    );
  }
}

/// Full-width primary button with the accent gradient.
class GradientButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;
  final Gradient? gradient;
  final double height;

  const GradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon,
    this.gradient,
    this.height = 52,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    final radius = BorderRadius.circular(AppRadius.md);
    final fg = enabled ? Colors.white : context.cs.onSurfaceVariant;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      // The shadow belongs to this outer box. Painted inside a Material it was
      // clipped to a visible light band under the button.
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: enabled ? (gradient ?? context.primaryGradient) : null,
          color: enabled ? null : context.cs.surfaceContainerHighest,
          borderRadius: radius,
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: context.primary.withValues(alpha: 0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Material(
          type: MaterialType.transparency,
          borderRadius: radius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: enabled ? onPressed : null,
            child: SizedBox(
              height: height,
              child: Center(
                child: loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (icon != null) ...[Icon(icon, size: 20, color: fg), const SizedBox(width: 8)],
                          Flexible(
                            child: Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: fg),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bottom area of a form or detail screen that holds its main action(s). A top
/// rule and a solid background keep scrolled content from showing through.
class BottomActionBar extends StatelessWidget {
  final Widget child;
  const BottomActionBar({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.cs.surface,
        border: Border(top: BorderSide(color: context.cs.outline)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.page, 12, AppSpacing.page, 16),
        child: child,
      ),
    );
  }
}

/// Small colored label (priority, category, status). The text color is
/// derived from [color] so it always meets 4.5:1 contrast on the tint.
class TintBadge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const TintBadge({super.key, required this.label, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    final tint = color.withValues(alpha: 0.14);
    final background = Color.alphaBlend(tint, context.cs.surfaceContainer);
    final fg = readableOn(color, background);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 12, color: fg), const SizedBox(width: 4)],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg),
            ),
          ),
        ],
      ),
    );
  }
}

/// Rounded surface used for grouped content.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final double radius;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.color,
    this.radius = AppRadius.lg,
  });

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: BorderSide(color: context.cs.outline),
    );
    return Material(
      color: color ?? context.cs.surfaceContainer,
      shape: shape,
      child: InkWell(
        customBorder: shape,
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Selectable pill (filters, categories, priorities) with a 44 px minimum height.
class PillChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int? count;
  final Color? color;

  const PillChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final accent = color ?? context.primary;
    return Semantics(
      button: true,
      selected: selected,
      label: count == null ? label : '$label, $count',
      child: Material(
        color: selected ? accent : context.cs.surfaceContainer,
        shape: StadiumBorder(side: BorderSide(color: selected ? accent : context.cs.outline, width: 1.5)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: selected ? Colors.white : context.cs.onSurfaceVariant,
                    ),
                  ),
                  if (count != null && count! > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: selected ? Colors.white.withValues(alpha: 0.25) : accent.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$count',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: selected ? Colors.white : readableOn(accent, context.cs.surfaceContainer),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Labelled text input with one consistent look (no nested filled boxes).
class LabeledField extends StatefulWidget {
  final String label;
  final String hint;
  final TextEditingController? controller;
  final IconData? icon;
  final int maxLines;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final String? errorText;
  final String? helperText;
  final List<TextInputFormatter>? inputFormatters;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final int? maxLength;
  final bool obscureText;
  final Widget? suffix;
  final Iterable<String>? autofillHints;
  final bool autofocus;

  const LabeledField({
    super.key,
    required this.label,
    required this.hint,
    this.controller,
    this.icon,
    this.maxLines = 1,
    this.keyboardType,
    this.onChanged,
    this.onSubmitted,
    this.errorText,
    this.helperText,
    this.inputFormatters,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.maxLength,
    this.obscureText = false,
    this.suffix,
    this.autofillHints,
    this.autofocus = false,
  });

  @override
  State<LabeledField> createState() => _LabeledFieldState();
}

class _LabeledFieldState extends State<LabeledField> {
  final _focus = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() => _focused = _focus.hasFocus));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasError = widget.errorText != null;
    final borderColor = hasError ? context.cs.error : (_focused ? context.primary : context.cs.outline);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(widget.label),
        AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: context.cs.surfaceContainer,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: borderColor, width: _focused || hasError ? 1.8 : 1.2),
          ),
          child: Row(
            crossAxisAlignment: widget.maxLines > 1 ? CrossAxisAlignment.start : CrossAxisAlignment.center,
            children: [
              if (widget.icon != null)
                Padding(
                  padding: EdgeInsets.only(left: 16, top: widget.maxLines > 1 ? 16 : 0),
                  child: Icon(widget.icon, size: 20, color: context.cs.onSurfaceVariant),
                ),
              Expanded(
                child: TextField(
                  focusNode: _focus,
                  controller: widget.controller,
                  maxLines: widget.obscureText ? 1 : widget.maxLines,
                  minLines: widget.maxLines > 1 ? 3 : 1,
                  keyboardType: widget.keyboardType,
                  onChanged: widget.onChanged,
                  onSubmitted: widget.onSubmitted,
                  inputFormatters: widget.inputFormatters,
                  textInputAction: widget.textInputAction,
                  textCapitalization: widget.textCapitalization,
                  maxLength: widget.maxLength,
                  obscureText: widget.obscureText,
                  autofillHints: widget.autofillHints,
                  autofocus: widget.autofocus,
                  style: context.body.copyWith(fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    hintText: widget.hint,
                    hintStyle: context.bodyMuted.copyWith(color: context.cs.onSurfaceVariant.withValues(alpha: 0.75)),
                    filled: false,
                    counterText: '',
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: widget.maxLines > 1 ? 14 : 15),
                  ),
                ),
              ),
              if (widget.suffix != null) widget.suffix!,
            ],
          ),
        ),
        if (hasError || widget.helperText != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(
              widget.errorText ?? widget.helperText!,
              style: context.label.copyWith(color: hasError ? context.cs.error : context.cs.onSurfaceVariant),
            ),
          ),
      ],
    );
  }
}

/// Tappable field that opens a picker and shows the chosen value as real text.
class PickerField extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;
  final String? helperText;
  final bool warn;

  const PickerField({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
    this.helperText,
    this.warn = false,
  });

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      side: BorderSide(color: warn ? context.cs.error : context.cs.outline, width: 1.2),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(label),
        Semantics(
          button: true,
          label: '$label: $value',
          child: Material(
            color: context.cs.surfaceContainer,
            shape: shape,
            child: InkWell(
              customBorder: shape,
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
                child: Row(
                  children: [
                    Icon(icon, size: 20, color: context.cs.onSurfaceVariant),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.body.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (helperText != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(helperText!, style: context.label.copyWith(color: warn ? context.cs.error : null)),
          ),
      ],
    );
  }
}

/// Icon in a tinted rounded square (replaces emoji used as icons).
class IconTile extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final double size;

  const IconTile({super.key, required this.icon, this.color, this.size = 44});

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.primary;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(size / 3),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: size * 0.5, color: readableOn(c, Color.alphaBlend(c.withValues(alpha: 0.14), context.cs.surface), minRatio: 3.0)),
    );
  }
}

/// Bottom sheet with the app's card look. Scrolls on small screens, so its
/// content can never overflow, and rises above the keyboard.
Future<T?> showAppSheet<T>(BuildContext context, {required WidgetBuilder builder}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.viewInsetsOf(ctx).bottom),
      child: Material(
        color: ctx.cs.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: ctx.cs.outline),
        ),
        child: SingleChildScrollView(child: builder(ctx)),
      ),
    ),
  );
}

/// One tappable row inside [showAppSheet] (icon tile, title, optional description).
class SheetAction extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? description;
  final Color? color;
  final VoidCallback onTap;

  const SheetAction({
    super.key,
    required this.icon,
    required this.title,
    this.description,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tint = color ?? context.primary;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              IconTile(icon: icon, color: tint),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, style: context.body.copyWith(fontWeight: FontWeight.w700, color: color == null ? null : readableOn(color!, context.cs.surface))),
                    if (description != null) Text(description!, style: context.label),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Title row at the top of a bottom sheet.
class SheetHeader extends StatelessWidget {
  final String title;
  const SheetHeader(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 6),
      child: Text(title.toUpperCase(), style: context.caption.copyWith(letterSpacing: 1.4)),
    );
  }
}

/// Confirmation dialog with a destructive primary action. Returns true when confirmed.
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Delete',
  bool destructive = true,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(
          style: destructive ? FilledButton.styleFrom(backgroundColor: ctx.cs.error, foregroundColor: Colors.white) : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Title of a list section with an optional "View all" style action.
class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const SectionHeader(this.title, {super.key, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(child: Text(title, style: context.h3)),
          if (actionLabel != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(minimumSize: const Size(48, 44)),
              child: Text(actionLabel!, style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
        ],
      ),
    );
  }
}

/// Card row with a title, a one-line explanation and a Material switch.
class SwitchRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final IconData? icon;

  const SwitchRow({
    super.key,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      toggled: value,
      label: title,
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        radius: AppRadius.md,
        onTap: onChanged == null ? null : () => onChanged!(!value),
        child: Row(
          children: [
            if (icon != null) ...[IconTile(icon: icon!, size: 40), const SizedBox(width: 14)],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: context.body.copyWith(fontWeight: FontWeight.w700)),
                  if (subtitle != null) Text(subtitle!, style: context.label),
                ],
              ),
            ),
            ExcludeSemantics(child: Switch(value: value, onChanged: onChanged)),
          ],
        ),
      ),
    );
  }
}
