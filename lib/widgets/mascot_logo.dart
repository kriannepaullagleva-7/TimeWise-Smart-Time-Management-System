import 'package:flutter/material.dart';

class MascotLogo extends StatelessWidget {
  final double size;
  final double opacity;
  
  const MascotLogo({super.key, this.size = 48, this.opacity = 1.0});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Image.asset(
        'assets/images/icon.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
      ),
    );
  }
}
