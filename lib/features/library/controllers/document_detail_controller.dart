import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:pdf/pdf.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/dao/document_dao.dart';
import '../../../core/database/dao/page_dao.dart';
import '../../../core/database/dao/tag_dao.dart';
import '../../../core/database/models.dart';
import '../../../core/services/ocr_service.dart';
import '../../../core/services/pdf_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../features/settings/controllers/settings_controller.dart';

class DocumentDetailState {
  const DocumentDetailState({
    required this.document,
    required this.pages,
    required this.tags,
    required this.isLoading,
  });

  final DocumentModel document;
  final List<PageModel> pages;
  final List<TagModel> tags;
  final bool isLoading;

  DocumentDetailState copyWith({
    DocumentModel? document,
    List<PageModel>? pages,
    List<TagModel>? tags,
    bool? isLoading,
  }) {
    return DocumentDetailState(
      document: document ?? this.document,
      pages: pages ?? this.pages,
      tags: tags ?? this.tags,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class DocumentDetailController
    extends StateNotifier<AsyncValue<DocumentDetailState>> {
  DocumentDetailController({
    required this.documentId,
    required this.documentDao,
    required this.pageDao,
    required this.tagDao,
    required this.pdfService,
    required this.storageService,
    required this.settings,
  }) : super(const AsyncValue.loading());

  final String documentId;
  final DocumentDao documentDao;
  final PageDao pageDao;
  final TagDao tagDao;
  final PdfService pdfService;
  final StorageService storageService;
  final SettingsState settings;

  Future<void> load() async {
    try {
      final document = await documentDao.getById(documentId);
      if (document == null) {
        state = AsyncValue.error('Document not found', StackTrace.current);
        return;
      }
      final pages = await pageDao.listForDocument(documentId);
      final tags = await tagDao.listForDocument(documentId);
      state = AsyncValue.data(
        DocumentDetailState(
          document: document,
          pages: pages,
          tags: tags,
          isLoading: false,
        ),
      );
    } catch (error, stack) {
      state = AsyncValue.error(error, stack);
    }
  }

  Future<void> rename(String title) async {
    final current = state.value!;
    final updated = current.document.copyWith(title: title);
    await documentDao.update(updated);
    state = AsyncValue.data(current.copyWith(document: updated));
  }

  Future<void> toggleFavorite() async {
    final current = state.value!;
    final updated = current.document
        .copyWith(isFavorite: !current.document.isFavorite);
    await documentDao.update(updated);
    state = AsyncValue.data(current.copyWith(document: updated));
  }

  Future<void> updateFolder(String? folderId) async {
    final current = state.value!;
    final updated = current.document.copyWith(folderId: folderId);
    await documentDao.update(updated);
    state = AsyncValue.data(current.copyWith(document: updated));
  }

  Future<void> addTag(String name) async {
    final id = const Uuid().v4();
    final tag = TagModel(id: id, name: name);
    await tagDao.insert(tag);
    await tagDao.linkTag(documentId, id);
    await load();
  }

  Future<void> removeTag(TagModel tag) async {
    await tagDao.unlinkTag(documentId, tag.id);
    await load();
  }

  Future<void> regeneratePdf() async {
    final current = state.value!;
    state = AsyncValue.data(current.copyWith(isLoading: true));
    final pdfFile = await storageService.buildPdfPath(
        documentId, current.document.title);
    final imageFiles =
        current.pages.map((page) => File(page.imagePath)).toList();
    await pdfService.generatePdf(
      images: imageFiles,
      outputFile: pdfFile,
      format: settings.defaultPageSize == 'Letter'
          ? PdfPageFormat.letter
          : PdfPageFormat.a4,
      grayscale: settings.defaultColorMode == 'Grayscale',
    );
    final updated = current.document.copyWith(pdfPath: pdfFile.path);
    await documentDao.update(updated);
    state = AsyncValue.data(current.copyWith(document: updated, isLoading: false));
  }

  Future<void> openPdf() async {
    final current = state.value!;
    if (current.document.pdfPath == null) return;
    await OpenFilex.open(current.document.pdfPath!);
  }

  Future<void> sharePdf() async {
    final current = state.value!;
    final pdfPath = current.document.pdfPath;
    if (pdfPath == null) return;
    await Share.shareXFiles([XFile(pdfPath)], text: current.document.title);
  }

  Future<void> shareImages() async {
    final current = state.value!;
    final files = current.pages.map((page) => XFile(page.imagePath)).toList();
    await Share.shareXFiles(files, text: current.document.title);
  }

  Future<void> deleteDocument() async {
    final current = state.value!;
    await documentDao.delete(documentId);
    for (final page in current.pages) {
      final file = File(page.imagePath);
      if (await file.exists()) {
        await file.delete();
      }
    }
    if (current.document.pdfPath != null) {
      final file = File(current.document.pdfPath!);
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  Future<void> reorderPages(List<PageModel> pages) async {
    final updated = <PageModel>[];
    for (var i = 0; i < pages.length; i++) {
      updated.add(PageModel(
        id: pages[i].id,
        documentId: pages[i].documentId,
        index: i,
        imagePath: pages[i].imagePath,
        ocrText: pages[i].ocrText,
      ));
    }
    await pageDao.replacePages(documentId, updated);
    await load();
  }

  Future<void> rerunOcr() async {
    final current = state.value!;
    final ocrService = OcrService();
    var fullText = StringBuffer();
    final updatedPages = <PageModel>[];
    for (final page in current.pages) {
      try {
        final text = await ocrService.extractText(File(page.imagePath));
        updatedPages.add(page.copyWith(ocrText: text));
        fullText.writeln(text);
      } catch (_) {
        updatedPages.add(page);
      }
    }
    await ocrService.dispose();
    await pageDao.replacePages(documentId, updatedPages);
    final updatedDocument = current.document.copyWith(ocrText: fullText.toString());
    await documentDao.update(updatedDocument);
    await load();
  }
}

extension on DocumentModel {
  DocumentModel copyWith({
    String? title,
    String? description,
    String? folderId,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isFavorite,
    int? pageCount,
    String? pdfPath,
    String? thumbnailPath,
    String? ocrText,
    int? sizeBytes,
  }) {
    return DocumentModel(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      folderId: folderId ?? this.folderId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isFavorite: isFavorite ?? this.isFavorite,
      pageCount: pageCount ?? this.pageCount,
      pdfPath: pdfPath ?? this.pdfPath,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      ocrText: ocrText ?? this.ocrText,
      sizeBytes: sizeBytes ?? this.sizeBytes,
    );
  }
}

extension on PageModel {
  PageModel copyWith({
    int? index,
    String? imagePath,
    String? ocrText,
  }) {
    return PageModel(
      id: id,
      documentId: documentId,
      index: index ?? this.index,
      imagePath: imagePath ?? this.imagePath,
      ocrText: ocrText ?? this.ocrText,
    );
  }
}

final documentDetailProvider = StateNotifierProvider.family<
    DocumentDetailController, AsyncValue<DocumentDetailState>, String>((ref, id) {
  final settings = ref.watch(settingsProvider).value ??
      const SettingsState(
        ocrEnabled: true,
        defaultExportFormat: 'PDF',
        defaultPageSize: 'A4',
        defaultColorMode: 'Color',
        encryptPdf: false,
      );
  final controller = DocumentDetailController(
    documentId: id,
    documentDao: DocumentDao(),
    pageDao: PageDao(),
    tagDao: TagDao(),
    pdfService: PdfService(),
    storageService: StorageService(),
    settings: settings,
  );
  controller.load();
  return controller;
});
