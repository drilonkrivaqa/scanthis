import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/document_models.dart';
import 'image_processing_service.dart';

class ExportService {
  ExportService._();
  static final ExportService instance = ExportService._();

  Future<File> exportDocumentToPdf(DocumentModel doc, {String quality = 'high'}) async {
    final pdfDoc = pw.Document();
    final totalPages = doc.pages.length;

    for (var i = 0; i < totalPages; i++) {
      final page = doc.pages[i];
      final bytes = await File(page.originalImagePath).readAsBytes();
      final edited = await ImageProcessingService.instance.applyEdits(
        bytes: bytes,
        edits: page.edits,
        quality: quality,
      );
      final withAnnotations = await ImageProcessingService.instance.applyAnnotations(
        bytes: edited,
        annotations: page.annotations,
        watermark: doc.watermark,
        pageNumbers: doc.pageNumbers,
        pageIndex: i + 1,
        totalPages: totalPages,
        quality: quality,
      );

      final img = pw.MemoryImage(withAnnotations);
      pdfDoc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.zero,
          build: (_) => pw.Center(
            child: pw.Image(img, fit: pw.BoxFit.contain),
          ),
        ),
      );
    }

    final dir = await _exportsDir(doc.id);
    await dir.create(recursive: true);
    final outFile = File('${dir.path}/${doc.title.replaceAll(' ', '_')}.pdf');
    final bytes = await pdfDoc.save();
    await outFile.writeAsBytes(bytes, flush: true);
    return outFile;
  }

  Future<Uint8List> renderPagePreview(PageModel page) async {
    final bytes = await File(page.originalImagePath).readAsBytes();
    final edited = await ImageProcessingService.instance.applyEdits(
      bytes: bytes,
      edits: page.edits,
      quality: 'medium',
    );
    return edited;
  }

  Future<Directory> _exportsDir(String docId) async {
    final docs = await getApplicationDocumentsDirectory();
    return Directory('${docs.path}/scans/$docId/exports');
  }
}
