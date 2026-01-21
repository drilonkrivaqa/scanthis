import 'dart:io';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class PdfService {
  Future<File> generatePdf({
    required List<File> images,
    required File outputFile,
    PdfPageFormat format = PdfPageFormat.a4,
    bool grayscale = false,
    double quality = 1,
  }) async {
    final doc = pw.Document();
    for (final imageFile in images) {
      final bytes = await imageFile.readAsBytes();
      final image = pw.MemoryImage(bytes);
      doc.addPage(
        pw.Page(
          pageFormat: format,
          build: (context) => pw.Center(
            child: pw.Image(
              image,
              fit: pw.BoxFit.contain,
            ),
          ),
        ),
      );
    }

    await outputFile.parent.create(recursive: true);
    await outputFile.writeAsBytes(await doc.save());
    return outputFile;
  }
}
