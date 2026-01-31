import 'dart:io';
import 'package:flutter/material.dart';
import '../models/scan_doc.dart';
import '../services/library_store.dart';
import '../services/scan_service.dart';
import '../utils/format.dart';
import 'view_doc_page.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  bool loading = true;
  List<ScanDoc> docs = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    final data = await LibraryStore.instance.load();
    if (!mounted) return;
    setState(() {
      docs = data;
      loading = false;
    });
  }

  Future<void> _delete(ScanDoc d) async {
    await LibraryStore.instance.removeById(d.id);
    await ScanService.instance.deleteDocFiles(d.id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Library'),
        actions: [
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
          : docs.isEmpty
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
        itemCount: docs.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final d = docs[i];
          final thumb = File(d.thumbPath);

          return InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => ViewDocPage(docId: d.id)),
            ),
            child: Container(
              padding: const EdgeInsets.all(12),
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
                        Text(
                          d.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${d.pageCount} page(s) • ${formatDate(d.createdAt)}',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: cs.outline),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            FilledButton.tonal(
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => ViewDocPage(docId: d.id),
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
                  )
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
