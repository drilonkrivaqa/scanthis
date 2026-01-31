import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/document_models.dart';
import '../services/document_store.dart';
import '../services/export_service.dart';
import '../services/image_processing_service.dart';

class EditorPage extends StatefulWidget {
  final String docId;
  final String pageId;
  const EditorPage({super.key, required this.docId, required this.pageId});

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  DocumentModel? doc;
  PageModel? page;
  bool loading = true;
  Uint8List? previewBytes;
  AnnotationItem? activeAnnotation;
  Offset? dragStart;
  Offset? redactionStart;
  Rect? redactionRect;
  bool redactionMode = false;
  String? selectedAnnotationId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final docs = await DocumentStore.instance.loadDocuments();
    final foundDoc = docs.firstWhere((d) => d.id == widget.docId);
    final foundPage = foundDoc.pages.firstWhere((p) => p.id == widget.pageId);
    final preview = await ExportService.instance.renderPagePreview(foundPage);
    if (!mounted) return;
    setState(() {
      doc = foundDoc;
      page = foundPage;
      previewBytes = preview;
      loading = false;
    });
  }

  Future<void> _applyPreset(String preset) async {
    final current = page;
    if (current == null) return;
    final presetEdits = ImageProcessingService.instance.presetFor(preset);
    final updated = current.copyWith(edits: presetEdits);
    await _savePage(updated);
  }

  Future<void> _savePage(PageModel updated) async {
    final currentDoc = doc;
    if (currentDoc == null) return;
    final updatedPages = currentDoc.pages.map((p) => p.id == updated.id ? updated : p).toList();
    final updatedDoc = currentDoc.copyWith(pages: updatedPages, updatedAt: DateTime.now());
    await DocumentStore.instance.updateDocument(updatedDoc);
    final preview = await ExportService.instance.renderPagePreview(updated);
    if (!mounted) return;
    setState(() {
      doc = updatedDoc;
      page = updated;
      previewBytes = preview;
    });
  }

  Future<void> _addSignature() async {
    final points = await showDialog<List<Offset>>(
      context: context,
      builder: (_) => const _SignatureDialog(),
    );
    if (points == null || points.isEmpty) return;
    final current = page;
    if (current == null) return;

    final annotation = AnnotationItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      type: AnnotationType.signaturePath,
      x: 0.2,
      y: 0.7,
      width: 0.5,
      height: 0.2,
      rotation: 0,
      opacity: 1,
      scale: 1,
      text: null,
      color: null,
      points: points,
    );
    final updated = current.copyWith(annotations: [...current.annotations, annotation]);
    await _savePage(updated);
  }

  Future<void> _addStamp() async {
    final result = await showDialog<_StampResult>(
      context: context,
      builder: (_) => const _StampDialog(),
    );
    if (result == null) return;
    final current = page;
    if (current == null) return;

    final annotation = AnnotationItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      type: AnnotationType.stampText,
      x: 0.2,
      y: 0.2,
      width: 0.4,
      height: 0.2,
      rotation: 0,
      opacity: 0.9,
      scale: 1,
      text: result.text,
      color: result.color,
      points: const [],
    );
    final updated = current.copyWith(annotations: [...current.annotations, annotation]);
    await _savePage(updated);
  }

  Future<void> _editWatermark() async {
    final currentDoc = doc;
    if (currentDoc == null) return;
    final controller = TextEditingController(text: currentDoc.watermark.text);
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Watermark text'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Watermark text'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    if (result == null) return;
    final updatedDoc = currentDoc.copyWith(
      watermark: currentDoc.watermark.copyWith(text: result, enabled: true),
      updatedAt: DateTime.now(),
    );
    await DocumentStore.instance.updateDocument(updatedDoc);
    await _load();
  }

  Future<void> _deskew() async {
    final current = page;
    if (current == null) return;
    final bytes = await File(current.originalImagePath).readAsBytes();
    final angle = ImageProcessingService.instance.estimateDeskewAngle(bytes);
    final updated = current.copyWith(edits: current.edits.copyWith(deskewAngle: angle));
    await _savePage(updated);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Deskew applied (beta).')),
    );
  }

  void _onPanStart(DragStartDetails details, Size size) {
    final current = page;
    if (current == null) return;
    final local = details.localPosition;
    final normalized = Offset(local.dx / size.width, local.dy / size.height);

    if (redactionMode) {
      setState(() {
        redactionStart = normalized;
        redactionRect = Rect.fromPoints(normalized, normalized);
      });
      return;
    }

    for (final annotation in current.annotations.reversed) {
      if (_hitTest(annotation, normalized)) {
        setState(() {
          activeAnnotation = annotation;
          dragStart = normalized;
          selectedAnnotationId = annotation.id;
        });
        return;
      }
    }
  }

  void _onTapDown(TapDownDetails details, Size size) {
    final current = page;
    if (current == null) return;
    final local = details.localPosition;
    final normalized = Offset(local.dx / size.width, local.dy / size.height);
    for (final annotation in current.annotations.reversed) {
      if (_hitTest(annotation, normalized)) {
        setState(() => selectedAnnotationId = annotation.id);
        return;
      }
    }
    setState(() => selectedAnnotationId = null);
  }

  void _onPanUpdate(DragUpdateDetails details, Size size) {
    final current = page;
    if (current == null) return;

    final local = details.localPosition;
    final normalized = Offset(local.dx / size.width, local.dy / size.height);

    if (redactionStart != null) {
      setState(() {
        final start = redactionStart!;
        redactionRect = Rect.fromPoints(start, normalized);
      });
      return;
    }

    if (activeAnnotation == null || dragStart == null) return;
    final delta = normalized - dragStart!;
    final updated = activeAnnotation!.copyWith(
      x: (activeAnnotation!.x + delta.dx).clamp(0.0, 1.0 - activeAnnotation!.width),
      y: (activeAnnotation!.y + delta.dy).clamp(0.0, 1.0 - activeAnnotation!.height),
    );

    final updatedAnnotations = current.annotations
        .map((a) => a.id == updated.id ? updated : a)
        .toList();
    setState(() {
      dragStart = normalized;
      activeAnnotation = updated;
      page = current.copyWith(annotations: updatedAnnotations);
    });
  }

  Future<void> _onPanEnd() async {
    if (redactionRect != null && page != null) {
      final rect = redactionRect!;
      final annotation = AnnotationItem(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        type: AnnotationType.rectRedaction,
        x: rect.left.clamp(0.0, 1.0),
        y: rect.top.clamp(0.0, 1.0),
        width: rect.width.clamp(0.0, 1.0),
        height: rect.height.clamp(0.0, 1.0),
        rotation: 0,
        opacity: 1,
        scale: 1,
        text: null,
        color: null,
        points: const [],
      );
      final current = page!;
      final updated = current.copyWith(annotations: [...current.annotations, annotation]);
      setState(() {
        redactionRect = null;
        redactionStart = null;
        redactionMode = false;
      });
      await _savePage(updated);
    }

    if (activeAnnotation != null && page != null) {
      await _savePage(page!);
      setState(() {
        activeAnnotation = null;
        dragStart = null;
      });
    }
  }

  Future<void> _deleteSelectedAnnotation() async {
    final current = page;
    if (current == null || selectedAnnotationId == null) return;
    final updated = current.copyWith(
      annotations: current.annotations.where((a) => a.id != selectedAnnotationId).toList(),
    );
    setState(() => selectedAnnotationId = null);
    await _savePage(updated);
  }

  bool _hitTest(AnnotationItem annotation, Offset normalized) {
    final rect = Rect.fromLTWH(annotation.x, annotation.y, annotation.width, annotation.height);
    return rect.contains(normalized);
  }

  @override
  Widget build(BuildContext context) {
    final currentPage = page;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editor'),
        actions: [
          IconButton(onPressed: _deskew, icon: const Icon(Icons.rotate_90_degrees_ccw)),
          IconButton(onPressed: _editWatermark, icon: const Icon(Icons.opacity)),
          if (selectedAnnotationId != null)
            IconButton(onPressed: _deleteSelectedAnnotation, icon: const Icon(Icons.delete)),
          const SizedBox(width: 6),
        ],
      ),
      body: loading || currentPage == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final size = Size(constraints.maxWidth, constraints.maxHeight);
                      return GestureDetector(
                        onTapDown: (details) => _onTapDown(details, size),
                        onPanStart: (details) => _onPanStart(details, size),
                        onPanUpdate: (details) => _onPanUpdate(details, size),
                        onPanEnd: (_) => _onPanEnd(),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (previewBytes != null)
                              Image.memory(previewBytes!, fit: BoxFit.contain)
                            else
                              Image.file(File(currentPage.originalImagePath), fit: BoxFit.contain),
                            CustomPaint(
                              painter: _AnnotationPainter(
                                annotations: currentPage.annotations,
                                redactionRect: redactionRect,
                                selectedId: selectedAnnotationId,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Enhance',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _PresetChip(label: 'Original', onTap: () => _applyPreset('Original')),
                            _PresetChip(label: 'Document', onTap: () => _applyPreset('Document')),
                            _PresetChip(label: 'Receipt', onTap: () => _applyPreset('Receipt')),
                            _PresetChip(label: 'Whiteboard', onTap: () => _applyPreset('Whiteboard')),
                            _PresetChip(label: 'B/W', onTap: () => _applyPreset('B/W')),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _addSignature,
                            icon: const Icon(Icons.draw),
                            label: const Text('Signature'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _addStamp,
                            icon: const Icon(Icons.stamp),
                            label: const Text('Stamp'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => setState(() => redactionMode = true),
                            icon: const Icon(Icons.block),
                            label: const Text('Redaction'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _PresetChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Text(label),
        ),
      ),
    );
  }
}

class _AnnotationPainter extends CustomPainter {
  final List<AnnotationItem> annotations;
  final Rect? redactionRect;
  final String? selectedId;

  _AnnotationPainter({required this.annotations, this.redactionRect, this.selectedId});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.redAccent;

    for (final annotation in annotations) {
      final rect = Rect.fromLTWH(
        annotation.x * size.width,
        annotation.y * size.height,
        annotation.width * size.width,
        annotation.height * size.height,
      );

      if (annotation.type == AnnotationType.rectRedaction) {
        final fill = Paint()
          ..style = PaintingStyle.fill
          ..color = Colors.black;
        canvas.drawRect(rect, fill);
      } else if (annotation.type == AnnotationType.signaturePath) {
        final path = Path();
        if (annotation.points.isNotEmpty) {
          final first = annotation.points.first;
          path.moveTo(rect.left + first.dx * rect.width, rect.top + first.dy * rect.height);
          for (final point in annotation.points.skip(1)) {
            path.lineTo(rect.left + point.dx * rect.width, rect.top + point.dy * rect.height);
          }
          canvas.drawPath(
            path,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2
              ..color = Colors.black,
          );
        }
      } else {
        canvas.drawRect(rect, paint);
        final textPainter = TextPainter(
          text: TextSpan(
            text: annotation.text ?? '',
            style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
          ),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: rect.width);
        textPainter.paint(canvas, rect.topLeft + const Offset(8, 8));
      }

      if (selectedId == annotation.id) {
        final highlight = Paint()
          ..style = PaintingStyle.stroke
          ..color = Colors.blueAccent
          ..strokeWidth = 2;
        canvas.drawRect(rect.inflate(4), highlight);
      }
    }

    if (redactionRect != null) {
      final rect = Rect.fromPoints(
        Offset(redactionRect!.left * size.width, redactionRect!.top * size.height),
        Offset(redactionRect!.right * size.width, redactionRect!.bottom * size.height),
      );
      canvas.drawRect(
        rect,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = Colors.black
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _AnnotationPainter oldDelegate) {
    return oldDelegate.annotations != annotations || oldDelegate.redactionRect != redactionRect;
  }
}

class _SignatureDialog extends StatefulWidget {
  const _SignatureDialog();

  @override
  State<_SignatureDialog> createState() => _SignatureDialogState();
}

class _SignatureDialogState extends State<_SignatureDialog> {
  final List<Offset> points = [];
  Size? canvasSize;

  void _handlePan(DragUpdateDetails details) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    canvasSize = box.size;
    final local = box.globalToLocal(details.globalPosition);
    if (local.dx < 0 || local.dy < 0 || local.dx > box.size.width || local.dy > box.size.height) {
      return;
    }
    setState(() => points.add(local));
  }

  List<Offset> _normalizedPoints() {
    final size = canvasSize;
    if (size == null || size.width == 0 || size.height == 0) return [];
    return points
        .map((p) => Offset(p.dx / size.width, p.dy / size.height))
        .where((p) => p.dx >= 0 && p.dy >= 0)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Draw signature'),
      content: SizedBox(
        width: 320,
        height: 180,
        child: GestureDetector(
          onPanUpdate: _handlePan,
          child: CustomPaint(
            painter: _SignaturePainter(points: points),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.pop(context, _normalizedPoints()),
          child: const Text('Use'),
        ),
      ],
    );
  }
}

class _SignaturePainter extends CustomPainter {
  final List<Offset> points;
  const _SignaturePainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    for (var i = 0; i < points.length - 1; i++) {
      canvas.drawLine(points[i], points[i + 1], paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) {
    return oldDelegate.points != points;
  }
}

class _StampDialog extends StatefulWidget {
  const _StampDialog();

  @override
  State<_StampDialog> createState() => _StampDialogState();
}

class _StampDialogState extends State<_StampDialog> {
  String text = 'PAID';
  int color = 0xFFE11D48;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Stamp'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            value: text,
            items: const [
              DropdownMenuItem(value: 'PAID', child: Text('PAID')),
              DropdownMenuItem(value: 'APPROVED', child: Text('APPROVED')),
              DropdownMenuItem(value: 'COPY', child: Text('COPY')),
              DropdownMenuItem(value: 'RECEIVED', child: Text('RECEIVED')),
              DropdownMenuItem(value: 'CUSTOM', child: Text('Custom')),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() => text = value);
            },
            decoration: const InputDecoration(labelText: 'Preset'),
          ),
          const SizedBox(height: 8),
          TextField(
            decoration: const InputDecoration(labelText: 'Text'),
            onChanged: (value) => setState(() => text = value),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            value: color,
            decoration: const InputDecoration(labelText: 'Color'),
            items: const [
              DropdownMenuItem(value: 0xFFE11D48, child: Text('Red')),
              DropdownMenuItem(value: 0xFF2563EB, child: Text('Blue')),
              DropdownMenuItem(value: 0xFF16A34A, child: Text('Green')),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() => color = value);
            },
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.pop(context, _StampResult(text: text, color: color)),
          child: const Text('Add'),
        ),
      ],
    );
  }
}

class _StampResult {
  final String text;
  final int color;
  const _StampResult({required this.text, required this.color});
}
