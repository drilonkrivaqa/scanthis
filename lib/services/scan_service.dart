import 'dart:io';
import 'dart:typed_data';

import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/scan_doc.dart';
import '../utils/ids.dart';

class ScanService {
  ScanService._();
  static final ScanService instance = ScanService._();

  /// Starts the native document scanner UI flow (auto edge detect, crop, filters),
  /// returns a saved ScanDoc (PDF + thumbnail) or null if canceled.
  Future<ScanDoc?> scanToPdf({int pageLimit = 50}) async {
    // Configure ML Kit scanner. It returns images if DocumentFormat.jpeg is set. :contentReference[oaicite:7]{index=7}
    final options = DocumentScannerOptions(
      documentFormat: DocumentFormat.jpeg,
      mode: ScannerMode.full,
      pageLimit: pageLimit,
      isGalleryImport: true,
    );

    final scanner = DocumentScanner(options: options);

    try {
      final result = await scanner.scanDocument(); // :contentReference[oaicite:8]{index=8}
      final images = result.images;

      if (images.isEmpty) return null;

      final id = newId();
      final baseDir = await _scanDir(id);
      await baseDir.create(recursive: true);

      // Copy pages into our own storage (so we own the files).
      final List<String> pagePaths = [];
      for (var i = 0; i < images.length; i++) {
        final srcPath = images[i];
        final src = File(srcPath);

        final dst = File('${baseDir.path}/page_${(i + 1).toString().padLeft(3, '0')}.jpg');
        await src.copy(dst.path);
        pagePaths.add(dst.path);
      }

      final thumbPath = pagePaths.first;

      // Build PDF from images using pdf package :contentReference[oaicite:9]{index=9}
      final pdfFile = File('${baseDir.path}/scan.pdf');
      final pdfBytes = await _buildPdfFromJpegs(pagePaths);
      await pdfFile.writeAsBytes(pdfBytes, flush: true);

      return ScanDoc(
        id: id,
        title: 'Scan ${DateTime.now().toLocal().toIso8601String().substring(0, 10)}',
        createdAt: DateTime.now(),
        pageCount: pagePaths.length,
        pdfPath: pdfFile.path,
        thumbPath: thumbPath,
      );
    } finally {
      await scanner.close();
    }
  }

  Future<void> deleteDocFiles(String id) async {
    final dir = await _scanDir(id);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  Future<Directory> _scanDir(String id) async {
    final docs = await getApplicationDocumentsDirectory(); // :contentReference[oaicite:10]{index=10}
    return Directory('${docs.path}/scans/$id');
  }

  Future<Uint8List> _buildPdfFromJpegs(List<String> paths) async {
    final doc = pw.Document();

    for (final p in paths) {
      final bytes = await File(p).readAsBytes();
      final img = pw.MemoryImage(bytes);

      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.zero,
          build: (_) {
            return pw.Center(
              child: pw.Image(
                img,
                fit: pw.BoxFit.contain,
              ),
            );
          },
        ),
      );
    }

    return doc.save();
  }
}
