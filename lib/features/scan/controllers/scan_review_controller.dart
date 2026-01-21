import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/dao/document_dao.dart';
import '../../../core/database/dao/page_dao.dart';
import '../../../core/database/models.dart';
import '../../../core/services/image_processing_service.dart';
import '../../../core/services/ocr_service.dart';
import '../../../core/services/pdf_service.dart';
import '../../../core/services/storage_service.dart';
import '../../settings/controllers/settings_controller.dart';

class ScanReviewState {
  const ScanReviewState({
    required this.images,
    required this.isProcessing,
    required this.progressMessage,
  });

  final List<File> images;
  final bool isProcessing;
  final String progressMessage;

  ScanReviewState copyWith({
    List<File>? images,
    bool? isProcessing,
    String? progressMessage,
  }) {
    return ScanReviewState(
      images: images ?? this.images,
      isProcessing: isProcessing ?? this.isProcessing,
      progressMessage: progressMessage ?? this.progressMessage,
    );
  }
}

class ScanReviewController extends StateNotifier<ScanReviewState> {
  ScanReviewController({
    required List<File> images,
    required this.storageService,
    required this.imageProcessingService,
    required this.ocrService,
    required this.pdfService,
    required this.documentDao,
    required this.pageDao,
    required this.settings,
  }) : super(
          ScanReviewState(
            images: images,
            isProcessing: false,
            progressMessage: '',
          ),
        );

  final StorageService storageService;
  final ImageProcessingService imageProcessingService;
  final OcrService ocrService;
  final PdfService pdfService;
  final DocumentDao documentDao;
  final PageDao pageDao;
  final SettingsState settings;

  Future<void> updateImage(int index, File newImage) async {
    final updated = [...state.images];
    updated[index] = newImage;
    state = state.copyWith(images: updated);
  }

  Future<String> saveDocument({String? title}) async {
    state = state.copyWith(isProcessing: true, progressMessage: 'Saving pages');
    final id = const Uuid().v4();
    final now = DateTime.now();
    final docTitle =
        title?.isNotEmpty == true ? title! : 'Scan ${now.toIso8601String()}';
    final pagesDir = await storageService.ensurePagesDir(id);

    final pageModels = <PageModel>[];
    final savedFiles = <File>[];
    final ocrBuffer = StringBuffer();

    try {
      for (var i = 0; i < state.images.length; i++) {
        final image = state.images[i];
        final target = File(
            '${pagesDir.path}/page_${(i + 1).toString().padLeft(3, '0')}.jpg');
        await image.copy(target.path);
        savedFiles.add(target);
        String? ocrText;
        if (settings.ocrEnabled) {
          state = state.copyWith(
              progressMessage:
                  'Running OCR (${i + 1}/${state.images.length})');
          try {
            ocrText = await ocrService.extractText(target);
            ocrBuffer.writeln(ocrText);
          } catch (_) {
            ocrText = null;
          }
        }
        pageModels.add(PageModel(
          id: const Uuid().v4(),
          documentId: id,
          index: i,
          imagePath: target.path,
          ocrText: ocrText,
        ));
      }
    } finally {
      await ocrService.dispose();
    }

    state = state.copyWith(progressMessage: 'Generating PDF');
    File? pdfFile;
    try {
      pdfFile = await storageService.buildPdfPath(id, docTitle);
      await pdfService.generatePdf(
        images: savedFiles,
        outputFile: pdfFile,
        format: settings.defaultPageSize == 'Letter'
            ? const PdfPageFormat(612, 792)
            : PdfPageFormat.a4,
        grayscale: settings.defaultColorMode == 'Grayscale',
      );
    } catch (_) {
      pdfFile = null;
    }

    final thumbFile = await storageService.buildThumbnailPath(id);
    final firstImage = await imageProcessingService.loadImage(savedFiles.first);
    if (firstImage != null) {
      final thumbnail = imageProcessingService.resize(firstImage, width: 400);
      await imageProcessingService.saveImage(thumbnail, thumbFile, quality: 70);
    }

    final document = DocumentModel(
      id: id,
      title: docTitle,
      description: '',
      folderId: null,
      createdAt: now,
      updatedAt: now,
      isFavorite: false,
      pageCount: pageModels.length,
      pdfPath: pdfFile?.path,
      thumbnailPath: thumbFile.path,
      ocrText: ocrBuffer.toString(),
      sizeBytes: pdfFile == null ? null : await pdfFile.length(),
    );

    await documentDao.insert(document);
    await pageDao.insertAll(pageModels);

    state = state.copyWith(isProcessing: false, progressMessage: '');
    return id;
  }
}

final scanReviewControllerProvider = StateNotifierProvider.family<
    ScanReviewController, ScanReviewState, List<File>>((ref, images) {
  final settings = ref.watch(settingsProvider).value ??
      const SettingsState(
        ocrEnabled: true,
        defaultExportFormat: 'PDF',
        defaultPageSize: 'A4',
        defaultColorMode: 'Color',
        encryptPdf: false,
      );
  return ScanReviewController(
    images: images,
    storageService: StorageService(),
    imageProcessingService: ImageProcessingService(),
    ocrService: OcrService(),
    pdfService: PdfService(),
    documentDao: DocumentDao(),
    pageDao: PageDao(),
    settings: settings,
  );
});
