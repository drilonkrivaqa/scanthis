import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/annotations.dart';
import '../models/doc_meta.dart';
import 'enhance_presets.dart';

class EditService {
  EditService._();
  static final EditService instance = EditService._();

  Future<Directory> _scanDir(String docId) async {
    final docs = await getApplicationDocumentsDirectory();
    return Directory('${docs.path}/scans/$docId');
  }

  Future<File> _metaFile(String docId) async {
    final dir = await _scanDir(docId);
    return File('${dir.path}/meta.json');
  }

  Future<DocMeta> loadMeta(String docId) async {
    final f = await _metaFile(docId);
    if (!await f.exists()) return const DocMeta();
    try {
      final raw = await f.readAsString();
      return DocMeta.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const DocMeta();
    }
  }

  Future<void> saveMeta(String docId, DocMeta meta) async {
    final f = await _metaFile(docId);
    await f.writeAsString(jsonEncode(meta.toJson()), flush: true);
  }

  Future<List<File>> listOriginalPages(String docId) async {
    final dir = await _scanDir(docId);
    if (!await dir.exists()) return [];
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.toLowerCase().endsWith('.jpg'))
        .where((f) => RegExp(r'page_\d{3}\.jpg$', caseSensitive: false).hasMatch(f.path))
        .toList();
    files.sort((a, b) => a.path.compareTo(b.path));
    return files;
  }

  Future<Directory> _renderDir(String docId) async {
    final dir = await _scanDir(docId);
    final r = Directory('${dir.path}/render');
    if (!await r.exists()) await r.create(recursive: true);
    return r;
  }

  Future<void> setPreset(String docId, EnhancePreset preset) async {
    final meta = await loadMeta(docId);
    await saveMeta(docId, meta.copyWith(preset: presetKey(preset)));
  }

  Future<void> setPageAnnotations(String docId, String pageName, PageAnnotations ann) async {
    final meta = await loadMeta(docId);
    await saveMeta(docId, meta.setAnnotationsForPage(pageName, ann));
  }

  /// Renders final page images (preset + annotations baked) into /render and regenerates scan.pdf.
  /// Returns the new PDF file.
  Future<File> renderAndRebuildPdf(String docId) async {
    final meta = await loadMeta(docId);
    final preset = presetFromKey(meta.preset);

    final pages = await listOriginalPages(docId);
    if (pages.isEmpty) throw Exception('No pages found for this document');

    final renderDir = await _renderDir(docId);
    final renderedPaths = <String>[];

    for (final p in pages) {
      final pageName = p.uri.pathSegments.last;
      final outFile = File('${renderDir.path}/$pageName');

      final bytes = await p.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) continue;

      // Apply preset via package:image (fast).
      final presetImg = applyPreset(decoded, preset);
      final presetBytes = Uint8List.fromList(img.encodeJpg(presetImg, quality: 90));

      // Bake annotations using dart:ui so we can draw text/rectangles/signatures.
      final ann = meta.forPageName(pageName);
      final bakedBytes = await _bakeAnnotations(presetBytes, ann);

      await outFile.writeAsBytes(bakedBytes, flush: true);
      renderedPaths.add(outFile.path);
    }

    // Build PDF from rendered images
    final scanDir = await _scanDir(docId);
    final pdfFile = File('${scanDir.path}/scan.pdf');
    final pdfBytes = await _buildPdfFromJpegs(renderedPaths);
    await pdfFile.writeAsBytes(pdfBytes, flush: true);

    return pdfFile;
  }

  Future<Uint8List> _bakeAnnotations(Uint8List baseJpgBytes, PageAnnotations ann) async {
    final codec = await ui.instantiateImageCodec(baseJpgBytes);
    final frame = await codec.getNextFrame();
    final base = frame.image;

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);

    final size = ui.Size(base.width.toDouble(), base.height.toDouble());

    // Draw base
    final paint = ui.Paint();
    canvas.drawImage(base, ui.Offset.zero, paint);

    // Redactions
    final redPaint = ui.Paint()..color = const ui.Color(0xFF000000);
    for (final r in ann.redactions) {
      canvas.drawRect(r.toRect(size), redPaint);
    }

    // Stamps (simple text)
    for (final s in ann.stamps) {
      final paragraphBuilder = ui.ParagraphBuilder(
        ui.ParagraphStyle(
          fontSize: 34 * s.scale,
          fontWeight: ui.FontWeight.w800,
        ),
      )..pushStyle(ui.TextStyle(color: const ui.Color(0xFFB00020)));
      paragraphBuilder.addText(s.text);
      final paragraph = paragraphBuilder.build()
        ..layout(ui.ParagraphConstraints(width: size.width));
      final offset = ui.Offset(
        (s.x * size.width) - paragraph.maxIntrinsicWidth / 2,
        (s.y * size.height) - paragraph.height / 2,
      );
      canvas.drawParagraph(paragraph, offset);
    }

    // Signatures (PNG bitmap overlays)
    for (final sig in ann.signatures) {
      final f = File(sig.filePath);
      if (!await f.exists()) continue;
      final sigBytes = await f.readAsBytes();
      final sigCodec = await ui.instantiateImageCodec(sigBytes);
      final sigFrame = await sigCodec.getNextFrame();
      final sigImg = sigFrame.image;

      final targetW = sigImg.width.toDouble() * sig.scale;
      final targetH = sigImg.height.toDouble() * sig.scale;
      final left = (sig.x * size.width) - targetW / 2;
      final top = (sig.y * size.height) - targetH / 2;

      final src = ui.Rect.fromLTWH(0, 0, sigImg.width.toDouble(), sigImg.height.toDouble());
      final dst = ui.Rect.fromLTWH(left, top, targetW, targetH);

      canvas.drawImageRect(sigImg, src, dst, ui.Paint());
    }

    final picture = recorder.endRecording();
    final imgOut = await picture.toImage(base.width, base.height);
    final byteData = await imgOut.toByteData(format: ui.ImageByteFormat.png);
    final pngBytes = byteData!.buffer.asUint8List();

    // Convert to JPG for smaller storage
    final decoded = img.decodePng(pngBytes);
    if (decoded == null) return baseJpgBytes;
    return Uint8List.fromList(img.encodeJpg(decoded, quality: 90));
  }

  Future<Uint8List> _buildPdfFromJpegs(List<String> paths) async {
    final doc = pw.Document();

    for (final p in paths) {
      final bytes = await File(p).readAsBytes();
      final imgMem = pw.MemoryImage(bytes);

      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.zero,
          build: (_) => pw.Center(child: pw.Image(imgMem, fit: pw.BoxFit.contain)),
        ),
      );
    }
    return doc.save();
  }
}
