import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import '../models/annotations.dart';
import '../services/edit_service.dart';
import '../widgets/signature_pad.dart';

class AnnotatePage extends StatefulWidget {
  final String docId;
  final String pagePath; // original page jpg path
  const AnnotatePage({super.key, required this.docId, required this.pagePath});

  @override
  State<AnnotatePage> createState() => _AnnotatePageState();
}

class _AnnotatePageState extends State<AnnotatePage> {
  PageAnnotations ann = const PageAnnotations();
  bool loading = true;

  Offset? dragStart;
  Offset? dragCurrent;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String get pageName => Uri.file(widget.pagePath).pathSegments.last;

  Future<void> _load() async {
    final meta = await EditService.instance.loadMeta(widget.docId);
    setState(() {
      ann = meta.forPageName(pageName);
      loading = false;
    });
  }

  Future<void> _save() async {
    await EditService.instance.setPageAnnotations(widget.docId, pageName, ann);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Annotations saved')),
    );
  }

  void _addStamp(String text) {
    setState(() {
      ann = ann.copyWith(
        stamps: [...ann.stamps, Stamp(text: text, x: 0.5, y: 0.15, scale: 1.0)],
      );
    });
  }

  Future<void> _addSignature() async {
    final bytes = await showDialog<Uint8List?>(
      context: context,
      builder: (_) => const _SignatureDialog(),
    );
    if (bytes == null) return;

    // Save under doc folder signatures/
    final docDir = Directory(File(widget.pagePath).parent.path);
    final sigDir = Directory('${docDir.path}/signatures');
    if (!await sigDir.exists()) await sigDir.create(recursive: true);
    final file = File('${sigDir.path}/sig_${DateTime.now().microsecondsSinceEpoch}.png');
    await file.writeAsBytes(bytes, flush: true);

    setState(() {
      ann = ann.copyWith(
        signatures: [...ann.signatures, SignatureOverlay(filePath: file.path, x: 0.78, y: 0.85, scale: 0.75)],
      );
    });
  }

  void _undoLast() {
    setState(() {
      if (ann.redactions.isNotEmpty) {
        ann = ann.copyWith(redactions: ann.redactions.sublist(0, ann.redactions.length - 1));
        return;
      }
      if (ann.stamps.isNotEmpty) {
        ann = ann.copyWith(stamps: ann.stamps.sublist(0, ann.stamps.length - 1));
        return;
      }
      if (ann.signatures.isNotEmpty) {
        ann = ann.copyWith(signatures: ann.signatures.sublist(0, ann.signatures.length - 1));
        return;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final imgFile = File(widget.pagePath);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Annotate'),
        actions: [
          IconButton(tooltip: 'Undo', onPressed: _undoLast, icon: const Icon(Icons.undo)),
          IconButton(tooltip: 'Save', onPressed: _save, icon: const Icon(Icons.save)),
          const SizedBox(width: 6),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                  child: Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _addStamp('PAID'),
                        icon: const Icon(Icons.approval_outlined),
                        label: const Text('Stamp'),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        onPressed: _addSignature,
                        icon: const Icon(Icons.draw_outlined),
                        label: const Text('Signature'),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Drag to add redaction rectangles',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.outline),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                    child: Container(
                      decoration: BoxDecoration(
                        color: cs.surfaceVariant,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: cs.outline),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: LayoutBuilder(
                          builder: (context, box) {
                            return GestureDetector(
                              onPanStart: (d) {
                                setState(() {
                                  dragStart = d.localPosition;
                                  dragCurrent = d.localPosition;
                                });
                              },
                              onPanUpdate: (d) => setState(() => dragCurrent = d.localPosition),
                              onPanEnd: (_) {
                                final s = dragStart;
                                final c = dragCurrent;
                                setState(() {
                                  dragStart = null;
                                  dragCurrent = null;
                                });
                                if (s == null || c == null) return;

                                final rect = Rect.fromPoints(s, c);
                                if (rect.width.abs() < 8 || rect.height.abs() < 8) return;

                                // Convert rect in widget space to normalized coords.
                                final w = box.maxWidth;
                                final h = box.maxHeight;
                                final left = (rect.left / w).clamp(0.0, 1.0);
                                final top = (rect.top / h).clamp(0.0, 1.0);
                                final right = (rect.right / w).clamp(0.0, 1.0);
                                final bottom = (rect.bottom / h).clamp(0.0, 1.0);

                                setState(() {
                                  ann = ann.copyWith(
                                    redactions: [
                                      ...ann.redactions,
                                      RedactionRect(
                                        left: left < right ? left : right,
                                        top: top < bottom ? top : bottom,
                                        right: left < right ? right : left,
                                        bottom: top < bottom ? bottom : top,
                                      ),
                                    ],
                                  );
                                });
                              },
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  if (imgFile.existsSync())
                                    Image.file(imgFile, fit: BoxFit.contain)
                                  else
                                    Center(child: Text('Image not found', style: TextStyle(color: cs.outline))),
                                  CustomPaint(
                                    painter: _AnnPainter(ann, dragStart: dragStart, dragCurrent: dragCurrent),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _AnnPainter extends CustomPainter {
  final PageAnnotations ann;
  final Offset? dragStart;
  final Offset? dragCurrent;

  _AnnPainter(this.ann, {this.dragStart, this.dragCurrent});

  @override
  void paint(Canvas canvas, Size size) {
    final red = Paint()..color = Colors.black.withOpacity(0.85);
    for (final r in ann.redactions) {
      canvas.drawRect(r.toRect(size), red);
    }

    if (dragStart != null && dragCurrent != null) {
      final rect = Rect.fromPoints(dragStart!, dragCurrent!);
      canvas.drawRect(rect, Paint()..color = Colors.black.withOpacity(0.35));
      canvas.drawRect(
        rect,
        Paint()
          ..color = Colors.black.withOpacity(0.8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }

    for (final s in ann.stamps) {
      final tp = TextPainter(
        text: TextSpan(
          text: s.text,
          style: TextStyle(
            color: const Color(0xFFB00020),
            fontSize: 28 * s.scale,
            fontWeight: FontWeight.w800,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(s.x * size.width - tp.width / 2, s.y * size.height - tp.height / 2));
    }

    for (final sig in ann.signatures) {
      final center = Offset(sig.x * size.width, sig.y * size.height);
      final r = Rect.fromCenter(center: center, width: 140 * sig.scale, height: 60 * sig.scale);
      canvas.drawRect(r, Paint()..color = Colors.black.withOpacity(0.08));
      canvas.drawRect(
        r,
        Paint()
          ..color = Colors.black.withOpacity(0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      final tp = TextPainter(
        text: TextSpan(
          text: 'Signature',
          style: TextStyle(color: Colors.black.withOpacity(0.5), fontSize: 12),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(r.left + 8, r.top + 8));
    }
  }

  @override
  bool shouldRepaint(covariant _AnnPainter oldDelegate) =>
      oldDelegate.ann != ann || oldDelegate.dragStart != dragStart || oldDelegate.dragCurrent != dragCurrent;
}

class _SignatureDialog extends StatefulWidget {
  const _SignatureDialog();

  @override
  State<_SignatureDialog> createState() => _SignatureDialogState();
}

class _SignatureDialogState extends State<_SignatureDialog> {
  final SignatureController controller = SignatureController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Signature'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SignaturePad(controller: controller),
          const SizedBox(height: 8),
          Text('Draw your signature', style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
      actions: [
        TextButton(onPressed: controller.clear, child: const Text('Clear')),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () async {
            final png = await controller.exportPng();
            Navigator.pop(context, png);
          },
          child: const Text('Use'),
        ),
      ],
    );
  }
}
