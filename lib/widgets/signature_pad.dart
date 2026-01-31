import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class SignatureController extends ChangeNotifier {
  final List<Offset?> _points = [];

  List<Offset?> get points => List.unmodifiable(_points);

  void addPoint(Offset p) {
    _points.add(p);
    notifyListeners();
  }

  void addBreak() {
    _points.add(null);
    notifyListeners();
  }

  void clear() {
    _points.clear();
    notifyListeners();
  }

  Future<Uint8List?> exportPng({
    int width = 900,
    int height = 300,
  }) async {
    if (_points.whereType<Offset>().length < 2) return null;

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(
      recorder,
      ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    );

    final paint = ui.Paint()
      ..color = const ui.Color(0xFF000000)
      ..strokeWidth = 6
      ..strokeCap = ui.StrokeCap.round;

    final pts = _points.whereType<Offset>().toList();
    final minX = pts.map((p) => p.dx).reduce((a, b) => a < b ? a : b);
    final minY = pts.map((p) => p.dy).reduce((a, b) => a < b ? a : b);
    final maxX = pts.map((p) => p.dx).reduce((a, b) => a > b ? a : b);
    final maxY = pts.map((p) => p.dy).reduce((a, b) => a > b ? a : b);

    final srcW = (maxX - minX).clamp(1.0, double.infinity);
    final srcH = (maxY - minY).clamp(1.0, double.infinity);

    final scale = (width / srcW).clamp(0.5, 4.0);
    const xPad = 24.0;
    const yPad = 24.0;

    ui.Offset mapPoint(ui.Offset p) {
      final x = (p.dx - minX) * scale + xPad;
      final y = (p.dy - minY) * scale + yPad;
      return ui.Offset(x, y);
    }

    for (int i = 0; i < _points.length - 1; i++) {
      final p1 = _points[i];
      final p2 = _points[i + 1];
      if (p1 != null && p2 != null) {
        canvas.drawLine(mapPoint(p1), mapPoint(p2), paint);
      }
    }

    final pic = recorder.endRecording();
    final img = await pic.toImage(width, height);
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return data?.buffer.asUint8List();
  }
}

class SignaturePad extends StatelessWidget {
  final SignatureController controller;
  final double height;

  const SignaturePad({
    super.key,
    required this.controller,
    this.height = 220,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Container(
          height: height,
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cs.outline),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: GestureDetector(
              onPanStart: (d) => controller.addPoint(d.localPosition),
              onPanUpdate: (d) => controller.addPoint(d.localPosition),
              onPanEnd: (_) => controller.addBreak(),
              child: CustomPaint(
                painter: _SignaturePainter(controller.points),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SignaturePainter extends CustomPainter {
  final List<Offset?> points;
  _SignaturePainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0xFF000000)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < points.length - 1; i++) {
      final p1 = points[i];
      final p2 = points[i + 1];
      if (p1 != null && p2 != null) {
        canvas.drawLine(p1, p2, p);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) => oldDelegate.points != points;
}
