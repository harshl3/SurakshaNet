import 'package:flutter/material.dart';

/// Custom Target Reticle Marker matching Web App Interactive Picker Pin
class PickerTargetPinWidget extends StatelessWidget {
  const PickerTargetPinWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 48,
      height: 48,
      child: CustomPaint(
        painter: _PickerPinPainter(),
      ),
    );
  }
}

class _PickerPinPainter extends CustomPainter {
  const _PickerPinPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // 1. Outer translucent radar area
    final outerFill = Paint()
      ..color = const Color(0xFFCF4500).withValues(alpha: 0.22)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 18, outerFill);

    final outerRing = Paint()
      ..color = const Color(0xFFCF4500).withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, 18, outerRing);

    // 2. Crosshairs pointing outward in 4 cardinal directions
    final crosshairPaint = Paint()
      ..color = const Color(0xFFCF4500)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    // Top
    canvas.drawLine(Offset(center.dx, 2), Offset(center.dx, 9), crosshairPaint);
    // Bottom
    canvas.drawLine(Offset(center.dx, size.height - 9), Offset(center.dx, size.height - 2), crosshairPaint);
    // Left
    canvas.drawLine(Offset(2, center.dy), Offset(9, center.dy), crosshairPaint);
    // Right
    canvas.drawLine(Offset(size.width - 9, center.dy), Offset(size.width - 2, center.dy), crosshairPaint);

    // 3. Black circle with crisp white outline
    final whiteOutline = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 11, whiteOutline);

    final blackCircle = Paint()
      ..color = const Color(0xFF141413)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 8.5, blackCircle);

    // 4. Center signal orange dot
    final centerDot = Paint()
      ..color = const Color(0xFFCF4500)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 3.8, centerDot);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
