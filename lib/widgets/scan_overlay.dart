import 'package:flutter/material.dart';

class ScanOverlay extends StatelessWidget {
  final Rect window;
  const ScanOverlay({super.key, required this.window});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return IgnorePointer(
      child: CustomPaint(
        painter: _OverlayPainter(
          window: window,
          scrimColor: Colors.black.withOpacity(0.55),
          strokeColor: cs.primary,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _OverlayPainter extends CustomPainter {
  final Rect window;
  final Color scrimColor;
  final Color strokeColor;

  _OverlayPainter({
    required this.window,
    required this.scrimColor,
    required this.strokeColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Scrim with hole
    final full = Path()..addRect(Offset.zero & size);
    final hole = Path()
      ..addRRect(RRect.fromRectAndRadius(window, const Radius.circular(18)));
    final overlay = Path.combine(PathOperation.difference, full, hole);

    canvas.drawPath(overlay, Paint()..color = scrimColor);

    // Border
    final borderPaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    canvas.drawRRect(
      RRect.fromRectAndRadius(window, const Radius.circular(18)),
      borderPaint,
    );

    // Corner accents
    final cornerPaint = Paint()
      ..color = strokeColor.withOpacity(0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    const c = 22.0; // corner length
    final r = window;

    // top-left
    canvas.drawLine(r.topLeft + const Offset(8, 0), r.topLeft + const Offset(8 + c, 0), cornerPaint);
    canvas.drawLine(r.topLeft + const Offset(0, 8), r.topLeft + const Offset(0, 8 + c), cornerPaint);

    // top-right
    canvas.drawLine(r.topRight + const Offset(-8, 0), r.topRight + const Offset(-8 - c, 0), cornerPaint);
    canvas.drawLine(r.topRight + const Offset(0, 8), r.topRight + const Offset(0, 8 + c), cornerPaint);

    // bottom-left
    canvas.drawLine(r.bottomLeft + const Offset(8, 0), r.bottomLeft + const Offset(8 + c, 0), cornerPaint);
    canvas.drawLine(r.bottomLeft + const Offset(0, -8), r.bottomLeft + const Offset(0, -8 - c), cornerPaint);

    // bottom-right
    canvas.drawLine(r.bottomRight + const Offset(-8, 0), r.bottomRight + const Offset(-8 - c, 0), cornerPaint);
    canvas.drawLine(r.bottomRight + const Offset(0, -8), r.bottomRight + const Offset(0, -8 - c), cornerPaint);
  }

  @override
  bool shouldRepaint(covariant _OverlayPainter oldDelegate) {
    return oldDelegate.window != window ||
        oldDelegate.scrimColor != scrimColor ||
        oldDelegate.strokeColor != strokeColor;
  }
}
