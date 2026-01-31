import 'dart:io';

import 'package:flutter/material.dart';

import '../models/document_models.dart';
import '../services/document_store.dart';
import '../services/scan_service.dart';
import '../utils/format.dart';
import '../utils/ids.dart';
import 'document_detail_page.dart';
import 'folders_page.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  bool loading = true;
  List<DocumentModel> docs = [];
  List<FolderModel> folders = [];
  String query = '';
  String selectedFolder = 'all';
  String selectedTag = 'all';
  final Set<String> selectedDocs = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    final data = await DocumentStore.instance.loadDocuments();
    final folderData = await DocumentStore.instance.loadFolders();
    if (!mounted) return;
    setState(() {
      docs = data;
      folders = folderData;
      loading = false;
    });
  }

  Future<void> _delete(DocumentModel d) async {
    await DocumentStore.instance.removeDocument(d.id);
    await ScanService.instance.deleteDocFiles(d.id);
    if (!mounted) return;
    await _load();
  }

  Future<void> _mergeSelected() async {
    if (selectedDocs.length < 2) return;
    final selected = docs.where((d) => selectedDocs.contains(d.id)).toList();
    final mergedId = DateTime.now().microsecondsSinceEpoch.toString();
    final baseDir = await ScanService.instance.ensureScanDir(mergedId);
    final mergedPages = <PageModel>[];
    for (final doc in selected) {
      for (final page in doc.pages) {
        final newPath =
            '${baseDir.path}/page_${(mergedPages.length + 1).toString().padLeft(3, '0')}.jpg';
        await File(page.originalImagePath).copy(newPath);
        mergedPages.add(
          page.copyWith(
            id: newId(),
            documentId: mergedId,
            orderIndex: mergedPages.length,
            originalImagePath: newPath,
          ),
        );
      }
    }
    final mergedDoc = DocumentModel(
      id: mergedId,
      title: 'Merged ${formatDate(DateTime.now())}',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      folderId: 'unsorted',
      tags: selected.expand((d) => d.tags).toSet().toList(),
      pages: mergedPages.map((p) => p.copyWith()).toList(),
      metadata: const {},
      watermark: WatermarkSettings.defaults(),
      pageNumbers: PageNumberSettings.defaults(),
    );

    await DocumentStore.instance.addDocument(mergedDoc);
    for (final doc in selected) {
      await DocumentStore.instance.removeDocument(doc.id);
      await ScanService.instance.deleteDocFiles(doc.id);
    }
    if (!mounted) return;
    setState(() => selectedDocs.clear());
    await _load();
  }

  List<String> _allTags() {
    final set = <String>{};
    for (final doc in docs) {
      set.addAll(doc.tags);
    }
    return set.toList()..sort();
  }

  List<DocumentModel> _filteredDocs() {
    return docs.where((doc) {
      final matchesQuery = query.isEmpty || doc.title.toLowerCase().contains(query.toLowerCase());
      final matchesFolder = selectedFolder == 'all' || doc.folderId == selectedFolder;
      final matchesTag = selectedTag == 'all' || doc.tags.contains(selectedTag);
      return matchesQuery && matchesFolder && matchesTag;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tags = _allTags();
    final filtered = _filteredDocs();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Documents'),
        actions: [
          if (selectedDocs.length > 1)
            IconButton(
              tooltip: 'Merge',
              onPressed: _mergeSelected,
              icon: const Icon(Icons.merge_type),
            ),
          IconButton(
            tooltip: 'Folders',
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const FoldersPage()),
              );
              await _load();
            },
            icon: const Icon(Icons.folder),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search documents',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: cs.surfaceContainerHighest,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (value) => setState(() => query = value),
                  ),
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    children: [
                      _FilterChip(
                        label: 'All folders',
                        selected: selectedFolder == 'all',
                        onTap: () => setState(() => selectedFolder = 'all'),
                      ),
                      const SizedBox(width: 8),
                      ...folders.map((folder) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: _FilterChip(
                              label: folder.name,
                              selected: selectedFolder == folder.id,
                              onTap: () => setState(() => selectedFolder = folder.id),
                            ),
                          )),
                    ],
                  ),
                ),
                if (tags.isNotEmpty)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
                    child: Row(
                      children: [
                        _FilterChip(
                          label: 'All tags',
                          selected: selectedTag == 'all',
                          onTap: () => setState(() => selectedTag = 'all'),
                        ),
                        const SizedBox(width: 8),
                        ...tags.map((tag) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: _FilterChip(
                                label: tag,
                                selected: selectedTag == tag,
                                onTap: () => setState(() => selectedTag = tag),
                              ),
                            )),
                      ],
                    ),
                  ),
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.folder_open, size: 64, color: cs.outline),
                                const SizedBox(height: 10),
                                Text(
                                  'No documents yet',
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),
                                const SizedBox(height: 6),
                                const Text('Scan a document and it will appear here.'),
                              ],
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(14),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, i) {
                            final d = filtered[i];
                            final thumbPath = d.pages.isNotEmpty
                                ? d.pages.first.originalImagePath
                                : (d.metadata['thumbPath'] ?? '').toString();
                            final thumb = File(thumbPath);
                            final isSelected = selectedDocs.contains(d.id);
                            final folderName = folders
                                .firstWhere(
                                  (f) => f.id == d.folderId,
                                  orElse: () => FolderModel(
                                    id: 'unsorted',
                                    name: 'Unsorted',
                                    createdAt: DateTime.now(),
                                  ),
                                )
                                .name;

                            return InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onLongPress: () {
                                setState(() {
                                  if (isSelected) {
                                    selectedDocs.remove(d.id);
                                  } else {
                                    selectedDocs.add(d.id);
                                  }
                                });
                              },
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => DocumentDetailPage(docId: d.id),
                                ),
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? cs.primaryContainer.withOpacity(0.4)
                                      : cs.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: cs.outlineVariant),
                                ),
                                child: Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(14),
                                      child: Container(
                                        width: 70,
                                        height: 90,
                                        color: cs.surface,
                                        child: thumb.existsSync()
                                            ? Image.file(thumb, fit: BoxFit.cover)
                                            : Icon(Icons.description, color: cs.outline),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  d.title,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                                        fontWeight: FontWeight.w800,
                                                      ),
                                                ),
                                              ),
                                              if (isSelected)
                                                const Icon(Icons.check_circle, color: Colors.green),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            '${d.pages.length} page(s) • $folderName',
                                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                  color: cs.outline,
                                                ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            formatDate(d.updatedAt),
                                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                  color: cs.outline,
                                                ),
                                          ),
                                          const SizedBox(height: 10),
                                          Row(
                                            children: [
                                              FilledButton.tonal(
                                                onPressed: () => Navigator.of(context).push(
                                                  MaterialPageRoute(
                                                    builder: (_) => DocumentDetailPage(docId: d.id),
                                                  ),
                                                ),
                                                child: const Text('Open'),
                                              ),
                                              const SizedBox(width: 10),
                                              OutlinedButton(
                                                onPressed: () => _delete(d),
                                                child: const Text('Delete'),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? cs.primaryContainer : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? cs.onPrimaryContainer : cs.onSurface,
          ),
        ),
      ),
    );
  }
}
