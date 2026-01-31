import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';

import '../models/scan_doc.dart';
import '../services/library_store.dart';
import '../utils/format.dart';

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
          FilledButton(
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Document'),
        actions: [
          IconButton(onPressed: _rename, icon: const Icon(Icons.edit)),
          IconButton(onPressed: _share, icon: const Icon(Icons.share)),
          IconButton(onPressed: _open, icon: const Icon(Icons.open_in_new)),
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
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: cs.outline),
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
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: cs.outlineVariant),
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
                        FilledButton.icon(
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
                          onPressed: _rename,
                          icon: const Icon(Icons.edit),
                          label: const Text('Rename'),
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
