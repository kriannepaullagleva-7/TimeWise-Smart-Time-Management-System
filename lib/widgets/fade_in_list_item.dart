import 'package:flutter/material.dart';

/// Wraps a list item with a lightweight fade + rise-in, staggered by
/// [index], so lists feel less abrupt when they first populate.
class FadeInListItem extends StatelessWidget {
  final int index;
  final Widget child;

  const FadeInListItem({required this.index, required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    final delay = (index.clamp(0, 10) * 30);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 250 + delay),
      curve: Curves.easeOut,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, (1 - value) * 14),
          child: child,
        ),
      ),
      child: child,
    );
  }
}
