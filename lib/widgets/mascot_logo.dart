import 'package:flutter/material.dart';

class MascotLogo extends StatelessWidget {
  final double size;
  final double opacity;
  
  const MascotLogo({super.key, this.size = 48, this.opacity = 1.0});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _MascotPainter(opacity: opacity),
      ),
    );
  }
}

class _MascotPainter extends CustomPainter {
  final double opacity;
  _MascotPainter({this.opacity = 1.0});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: opacity)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Scale canvas to match the 48x48 viewBox
    canvas.scale(size.width / 48, size.height / 48);

    // <circle cx="24" cy="24" r="16" stroke="white" strokeWidth="2.5" strokeOpacity="0.6" />
    final circlePaint = Paint()
      ..color = Colors.white.withValues(alpha: opacity * 0.6)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(const Offset(24, 24), 16, circlePaint);

    // <path d="M24 14v10l7 4" stroke="white" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round" />
    final path = Path()
      ..moveTo(24, 14)
      ..lineTo(24, 24)
      ..lineTo(31, 28);
    canvas.drawPath(path, paint);

    // <path d="M34 10l2.5 2.5" stroke="white" strokeWidth="2" strokeLinecap="round" strokeOpacity="0.7" />
    final smallPath = Path()
      ..moveTo(34, 10)
      ..lineTo(36.5, 12.5);
    final smallPaint = Paint()
      ..color = Colors.white.withValues(alpha: opacity * 0.7)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(smallPath, smallPaint);

    // <circle cx="36.5" cy="10" r="2" fill="white" fillOpacity="0.8" />
    final smallCirclePaint = Paint()
      ..color = Colors.white.withValues(alpha: opacity * 0.8)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(36.5, 10), 2, smallCirclePaint);
  }

  @override
  bool shouldRepaint(covariant _MascotPainter oldDelegate) {
    return oldDelegate.opacity != opacity;
  }
}
