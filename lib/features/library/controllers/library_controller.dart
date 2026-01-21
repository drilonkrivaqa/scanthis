import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/dao/document_dao.dart';
import '../../../core/database/dao/folder_dao.dart';
import '../../../core/database/dao/tag_dao.dart';
import '../../../core/database/models.dart';

class LibraryState {
  const LibraryState({
    required this.documents,
    required this.query,
    required this.isGrid,
    required this.sort,
    required this.selectedFolderId,
    required this.selectedTagId,
  });

  final List<DocumentModel> documents;
  final String query;
  final bool isGrid;
  final String sort;
  final String? selectedFolderId;
  final String? selectedTagId;

  LibraryState copyWith({
    List<DocumentModel>? documents,
    String? query,
    bool? isGrid,
    String? sort,
    String? selectedFolderId,
    String? selectedTagId,
  }) {
    return LibraryState(
      documents: documents ?? this.documents,
      query: query ?? this.query,
      isGrid: isGrid ?? this.isGrid,
      sort: sort ?? this.sort,
      selectedFolderId: selectedFolderId ?? this.selectedFolderId,
      selectedTagId: selectedTagId ?? this.selectedTagId,
    );
  }
}

class LibraryController extends StateNotifier<AsyncValue<LibraryState>> {
  LibraryController({
    required DocumentDao documentDao,
    required FolderDao folderDao,
    required TagDao tagDao,
  })  : _documentDao = documentDao,
        _folderDao = folderDao,
        _tagDao = tagDao,
        super(
          const AsyncValue.data(
            LibraryState(
              documents: [],
              query: '',
              isGrid: false,
              sort: 'updated_at DESC',
              selectedFolderId: null,
              selectedTagId: null,
            ),
          ),
        );

  final DocumentDao _documentDao;
  final FolderDao _folderDao;
  final TagDao _tagDao;

  Future<void> refresh() async {
    final current = state.value!;
    state = const AsyncValue.loading();
    try {
      final docs = await _documentDao.list(
        searchQuery: current.query,
        folderId: current.selectedFolderId,
        tagId: current.selectedTagId,
        sort: current.sort,
      );
      state = AsyncValue.data(current.copyWith(documents: docs));
    } catch (error, stack) {
      state = AsyncValue.error(error, stack);
    }
  }

  Future<void> setQuery(String query) async {
    final current = state.value!;
    state = AsyncValue.data(current.copyWith(query: query));
    await refresh();
  }

  Future<void> toggleView() async {
    final current = state.value!;
    state = AsyncValue.data(current.copyWith(isGrid: !current.isGrid));
  }

  Future<void> setSort(String sort) async {
    final current = state.value!;
    state = AsyncValue.data(current.copyWith(sort: sort));
    await refresh();
  }

  Future<void> setFolderFilter(String? folderId) async {
    final current = state.value!;
    state = AsyncValue.data(current.copyWith(selectedFolderId: folderId));
    await refresh();
  }

  Future<void> setTagFilter(String? tagId) async {
    final current = state.value!;
    state = AsyncValue.data(current.copyWith(selectedTagId: tagId));
    await refresh();
  }

  Future<void> toggleFavorite(DocumentModel document) async {
    final updated = document.copyWith(isFavorite: !document.isFavorite);
    await _documentDao.update(updated);
    await refresh();
  }

  Future<List<FolderModel>> loadFolders() => _folderDao.list();

  Future<List<TagModel>> loadTags() => _tagDao.list();
}

final libraryControllerProvider =
    StateNotifierProvider<LibraryController, AsyncValue<LibraryState>>((ref) {
  return LibraryController(
    documentDao: DocumentDao(),
    folderDao: FolderDao(),
    tagDao: TagDao(),
  )..refresh();
});

extension on DocumentModel {
  DocumentModel copyWith({bool? isFavorite}) {
    return DocumentModel(
      id: id,
      title: title,
      description: description,
      folderId: folderId,
      createdAt: createdAt,
      updatedAt: updatedAt,
      isFavorite: isFavorite ?? this.isFavorite,
      pageCount: pageCount,
      pdfPath: pdfPath,
      thumbnailPath: thumbnailPath,
      ocrText: ocrText,
      sizeBytes: sizeBytes,
    );
  }
}
