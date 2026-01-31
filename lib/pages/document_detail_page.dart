import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';

import '../models/document_models.dart';
import '../services/document_store.dart';
import '../services/export_service.dart';
import '../services/scan_service.dart';
import '../utils/format.dart';
import '../utils/ids.dart';
import 'editor_page.dart';

class DocumentDetailPage extends StatefulWidget {
  final String docId;
  const DocumentDetailPage({super.key, required this.docId});

  @override
  State<DocumentDetailPage> createState() => _DocumentDetailPageState();
}

class _DocumentDetailPageState extends State<DocumentDetailPage> {
  DocumentModel? doc;
  List<FolderModel> folders = [];
  bool loading = true;
  final Set<String> selectedPages = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = await DocumentStore.instance.loadDocuments();
    final folderData = await DocumentStore.instance.loadFolders();
    final found = all.where((d) => d.id == widget.docId).toList();
    setState(() {
      doc = found.isEmpty ? null : found.first;
      folders = folderData;
      loading = false;
    });
  }

  Future<void> _rename() async {
    final d = doc;
    if (d == null) return;

    final controller = TextEditingController(text: d.title);

    final newTitle = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Rename'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Document name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newTitle == null || newTitle.isEmpty) return;

    final updated = d.copyWith(title: newTitle, updatedAt: DateTime.now());
    await DocumentStore.instance.updateDocument(updated);
    await _load();
  }

  Future<void> _editTags() async {
    final d = doc;
    if (d == null) return;
    final controller = TextEditingController(text: d.tags.join(', '));
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Tags'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Comma-separated tags'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == null) return;
    final tags = result
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
    final updated = d.copyWith(tags: tags, updatedAt: DateTime.now());
    await DocumentStore.instance.updateDocument(updated);
    await _load();
  }

  Future<void> _updateFolder(String? folderId) async {
    final d = doc;
    if (d == null) return;
    final updated = d.copyWith(folderId: folderId, updatedAt: DateTime.now());
    await DocumentStore.instance.updateDocument(updated);
    await _load();
  }

  Future<void> _exportPdf() async {
    final d = doc;
    if (d == null) return;

    String quality = 'high';
    bool watermarkEnabled = d.watermark.enabled;
    bool pageNumbersEnabled = d.pageNumbers.enabled;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Export settings'),
        content: StatefulBuilder(
          builder: (context, setLocalState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: quality,
                  decoration: const InputDecoration(labelText: 'Quality'),
                  items: const [
                    DropdownMenuItem(value: 'small', child: Text('Small')),
                    DropdownMenuItem(value: 'medium', child: Text('Medium')),
                    DropdownMenuItem(value: 'high', child: Text('High')),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setLocalState(() => quality = value);
                  },
                ),
                SwitchListTile(
                  title: const Text('Watermark'),
                  value: watermarkEnabled,
                  onChanged: (value) => setLocalState(() => watermarkEnabled = value),
                ),
                SwitchListTile(
                  title: const Text('Page numbers'),
                  value: pageNumbersEnabled,
                  onChanged: (value) => setLocalState(() => pageNumbersEnabled = value),
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Export')),
        ],
      ),
    );

    if (confirmed != true) return;

    final updated = d.copyWith(
      watermark: d.watermark.copyWith(enabled: watermarkEnabled),
      pageNumbers: d.pageNumbers.copyWith(enabled: pageNumbersEnabled),
      updatedAt: DateTime.now(),
    );
    await DocumentStore.instance.updateDocument(updated);
    final file = await ExportService.instance.exportDocumentToPdf(updated, quality: quality);
    if (!mounted) return;
    await OpenFilex.open(file.path);
  }

  Future<void> _sharePdf() async {
    final d = doc;
    if (d == null) return;
    final file = await ExportService.instance.exportDocumentToPdf(d);
    await Share.shareXFiles([XFile(file.path)], text: d.title);
  }

  Future<void> _splitSelectedPages() async {
    final d = doc;
    if (d == null || selectedPages.isEmpty) return;
    final newPages = d.pages.where((p) => selectedPages.contains(p.id)).toList();
    final remaining = d.pages.where((p) => !selectedPages.contains(p.id)).toList();

    final newDocId = newId();
    final baseDir = await ScanService.instance.ensureScanDir(newDocId);
    final copiedPages = <PageModel>[];
    for (var i = 0; i < newPages.length; i++) {
      final page = newPages[i];
      final newPath = '${baseDir.path}/page_${(i + 1).toString().padLeft(3, '0')}.jpg';
      await File(page.originalImagePath).copy(newPath);
      copiedPages.add(
        page.copyWith(
          id: newId(),
          documentId: newDocId,
          orderIndex: i,
          originalImagePath: newPath,
        ),
      );
    }
    final splitDoc = DocumentModel(
      id: newDocId,
      title: '${d.title} (Split)',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      folderId: d.folderId,
      tags: List.of(d.tags),
      pages: copiedPages,
      metadata: const {},
      watermark: d.watermark,
      pageNumbers: d.pageNumbers,
    );

    final updatedDoc = d.copyWith(
      pages: remaining
          .asMap()
          .entries
          .map((entry) => entry.value.copyWith(orderIndex: entry.key))
          .toList(),
      updatedAt: DateTime.now(),
    );

    await DocumentStore.instance.updateDocument(updatedDoc);
    await DocumentStore.instance.addDocument(splitDoc);
    if (!mounted) return;
    setState(() => selectedPages.clear());
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final d = doc;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Document'),
        actions: [
          if (selectedPages.isNotEmpty)
            IconButton(
              tooltip: 'Split selected',
              onPressed: _splitSelectedPages,
              icon: const Icon(Icons.call_split),
            ),
          IconButton(onPressed: _rename, icon: const Icon(Icons.edit)),
          IconButton(onPressed: _sharePdf, icon: const Icon(Icons.share)),
          IconButton(onPressed: _exportPdf, icon: const Icon(Icons.picture_as_pdf)),
          const SizedBox(width: 6),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : d == null
              ? const Center(child: Text('Document not found'))
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: cs.outlineVariant),
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                width: 64,
                                height: 84,
                                color: cs.surface,
                                child: d.pages.isNotEmpty && File(d.pages.first.originalImagePath).existsSync()
                                    ? Image.file(File(d.pages.first.originalImagePath), fit: BoxFit.cover)
                                    : Icon(Icons.description, color: cs.outline),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    d.title,
                                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                          fontWeight: FontWeight.w900,
                                        ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '${d.pages.length} page(s) • ${formatDate(d.createdAt)}',
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.outline),
                                  ),
                                  const SizedBox(height: 6),
                                  if (folders.isNotEmpty)
                                    DropdownButton<String>(
                                      value: d.folderId ?? 'unsorted',
                                      items: folders
                                          .map((f) => DropdownMenuItem(
                                                value: f.id,
                                                child: Text(f.name),
                                              ))
                                          .toList(),
                                      onChanged: _updateFolder,
                                    )
                                  else
                                    const Text('No folders'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            for (final tag in d.tags) Chip(label: Text(tag)),
                            ActionChip(
                              label: const Text('Edit tags'),
                              onPressed: _editTags,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: ReorderableListView.builder(
                          itemCount: d.pages.length,
                          onReorder: (oldIndex, newIndex) async {
                            if (newIndex > oldIndex) newIndex -= 1;
                            final updatedPages = List<PageModel>.from(d.pages);
                            final item = updatedPages.removeAt(oldIndex);
                            updatedPages.insert(newIndex, item);
                            final normalized = updatedPages
                                .asMap()
                                .entries
                                .map((entry) => entry.value.copyWith(orderIndex: entry.key))
                                .toList();
                            final updatedDoc = d.copyWith(pages: normalized, updatedAt: DateTime.now());
                            await DocumentStore.instance.updateDocument(updatedDoc);
                            await _load();
                          },
                          itemBuilder: (context, index) {
                            final page = d.pages[index];
                            final thumb = File(page.originalImagePath);
                            final selected = selectedPages.contains(page.id);

                            return Container(
                              key: ValueKey(page.id),
                              margin: const EdgeInsets.only(bottom: 10),
                              decoration: BoxDecoration(
                                color: selected ? cs.primaryContainer.withOpacity(0.4) : cs.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: cs.outlineVariant),
                              ),
                              child: ListTile(
                                leading: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    width: 54,
                                    height: 72,
                                    color: cs.surface,
                                    child: thumb.existsSync()
                                        ? Image.file(thumb, fit: BoxFit.cover)
                                        : Icon(Icons.image, color: cs.outline),
                                  ),
                                ),
                                title: Text('Page ${index + 1}'),
                                subtitle: Text(page.edits.preset),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Checkbox(
                                      value: selected,
                                      onChanged: (value) {
                                        setState(() {
                                          if (value == true) {
                                            selectedPages.add(page.id);
                                          } else {
                                            selectedPages.remove(page.id);
                                          }
                                        });
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.edit),
                                      onPressed: () async {
                                        await Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => EditorPage(docId: d.id, pageId: page.id),
                                          ),
                                        );
                                        await _load();
                                      },
                                    ),
                                    const Icon(Icons.drag_handle),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}
