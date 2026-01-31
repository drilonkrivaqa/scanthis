import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';

import '../models/folder.dart';
import '../models/scan_doc.dart';
import '../services/edit_service.dart';
import '../services/library_store.dart';
import '../utils/format.dart';
import 'edit_doc_page.dart';

class ViewDocPage extends StatefulWidget {
  final String docId;
  const ViewDocPage({super.key, required this.docId});

  @override
  State<ViewDocPage> createState() => _ViewDocPageState();
}

class _ViewDocPageState extends State<ViewDocPage> {
  ScanDoc? doc;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = await LibraryStore.instance.load();
    final found = all.where((d) => d.id == widget.docId).toList();
    setState(() {
      doc = found.isEmpty ? null : found.first;
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
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newTitle == null || newTitle.isEmpty) return;

    final updated = d.copyWith(title: newTitle);
    await LibraryStore.instance.update(updated);
    await _load();
  }

  Future<void> _setFolderAndTags() async {
    final d = doc;
    if (d == null) return;

    final folders = await LibraryStore.instance.loadFolders();
    final res = await showDialog<_FolderTagsResult>(
      context: context,
      builder: (_) => _FolderTagsDialog(
        currentFolderId: d.folderId,
        currentTags: d.tags,
        folders: folders,
      ),
    );

    if (res == null) return;
    final updated = d.copyWith(folderId: res.folderId, tags: res.tags);
    await LibraryStore.instance.update(updated);
    await _load();
  }

  Future<void> _open() async {
    final d = doc;
    if (d == null) return;
    await OpenFilex.open(d.pdfPath);
  }

  Future<void> _share() async {
    final d = doc;
    if (d == null) return;
    final file = File(d.pdfPath);
    if (!file.existsSync()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PDF file not found')),
      );
      return;
    }
    await Share.shareXFiles([XFile(d.pdfPath)], text: d.title);
  }

  Future<void> _edit() async {
    final d = doc;
    if (d == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => EditDocPage(docId: d.id)),
    );
    // after edit, rebuild may change PDF so refresh
    await _load();
  }

  Future<void> _rebuild() async {
    final d = doc;
    if (d == null) return;
    try {
      await EditService.instance.renderAndRebuildPdf(d.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PDF rebuilt with enhancements/annotations')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Rebuild failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Document'),
        actions: [
          IconButton(tooltip: 'Edit', onPressed: _edit, icon: const Icon(Icons.tune)),
          IconButton(tooltip: 'Folder & tags', onPressed: _setFolderAndTags, icon: const Icon(Icons.label_outline)),
          IconButton(tooltip: 'Rebuild PDF', onPressed: _rebuild, icon: const Icon(Icons.picture_as_pdf_outlined)),
          IconButton(tooltip: 'Share', onPressed: _share, icon: const Icon(Icons.share)),
          IconButton(tooltip: 'Open', onPressed: _open, icon: const Icon(Icons.open_in_new)),
          const SizedBox(width: 6),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : doc == null
              ? const Center(child: Text('Document not found'))
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: cs.surfaceVariant,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: cs.outline),
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                width: 64,
                                height: 84,
                                color: cs.surface,
                                child: File(doc!.thumbPath).existsSync()
                                    ? Image.file(File(doc!.thumbPath), fit: BoxFit.cover)
                                    : Icon(Icons.description, color: cs.outline),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    doc!.title,
                                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                          fontWeight: FontWeight.w900,
                                        ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '${doc!.pageCount} page(s) • ${formatDate(doc!.createdAt)}',
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.outline),
                                  ),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: [
                                      if ((doc!.folderId ?? '').isNotEmpty)
                                        _Chip(text: 'Folder: ${doc!.folderId!}', icon: Icons.folder),
                                      for (final t in doc!.tags.take(6))
                                        _Chip(text: t, icon: Icons.tag),
                                      if (doc!.tags.length > 6) _Chip(text: '+${doc!.tags.length - 6}', icon: Icons.more_horiz),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: cs.surfaceVariant,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: cs.outline),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.picture_as_pdf, size: 54, color: cs.primary),
                              const SizedBox(height: 10),
                              const Text('PDF ready'),
                              const SizedBox(height: 14),
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: _open,
                                    icon: const Icon(Icons.open_in_new),
                                    label: const Text('Open PDF'),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: _share,
                                    icon: const Icon(Icons.share),
                                    label: const Text('Share'),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: _edit,
                                    icon: const Icon(Icons.tune),
                                    label: const Text('Edit pages'),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: _setFolderAndTags,
                                    icon: const Icon(Icons.label_outline),
                                    label: const Text('Folder & tags'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;
  final IconData icon;
  const _Chip({required this.text, required this.icon});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: cs.outline),
          const SizedBox(width: 6),
          Text(text, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _FolderTagsResult {
  final String? folderId;
  final List<String> tags;
  _FolderTagsResult({required this.folderId, required this.tags});
}

class _FolderTagsDialog extends StatefulWidget {
  final String? currentFolderId;
  final List<String> currentTags;
  final List<Folder> folders;

  const _FolderTagsDialog({
    required this.currentFolderId,
    required this.currentTags,
    required this.folders,
  });

  @override
  State<_FolderTagsDialog> createState() => _FolderTagsDialogState();
}

class _FolderTagsDialogState extends State<_FolderTagsDialog> {
  String? folderId;
  late TextEditingController tagsCtrl;

  @override
  void initState() {
    super.initState();
    folderId = widget.currentFolderId;
    tagsCtrl = TextEditingController(text: widget.currentTags.join(', '));
  }

  @override
  void dispose() {
    tagsCtrl.dispose();
    super.dispose();
  }

  List<String> _parseTags(String raw) {
    return raw
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Folder & tags'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String?>(
            value: folderId,
            decoration: const InputDecoration(labelText: 'Folder'),
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('Unsorted')),
              ...widget.folders
                  .where((f) => f.id != LibraryStore.unsortedFolder.id)
                  .map((f) => DropdownMenuItem<String?>(value: f.id, child: Text(f.name))),
            ],
            onChanged: (v) => setState(() => folderId = v),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: tagsCtrl,
            decoration: const InputDecoration(
              labelText: 'Tags',
              hintText: 'comma separated (e.g. invoice, 2026, client)',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () => Navigator.pop(
            context,
            _FolderTagsResult(folderId: folderId, tags: _parseTags(tagsCtrl.text)),
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
