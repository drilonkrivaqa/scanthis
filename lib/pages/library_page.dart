import 'dart:io';
import 'package:flutter/material.dart';
import '../models/folder.dart';
import '../models/scan_doc.dart';
import '../services/library_store.dart';
import '../services/scan_service.dart';
import '../utils/format.dart';
import 'folders_page.dart';
import 'view_doc_page.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  bool loading = true;
  List<ScanDoc> docs = [];
  List<Folder> folders = [LibraryStore.unsortedFolder];

  String query = '';
  String? folderIdFilter; // null => all, 'unsorted' => unsorted, otherwise folder id

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    final data = await LibraryStore.instance.load();
    final f = await LibraryStore.instance.loadFolders();
    if (!mounted) return;
    setState(() {
      docs = data;
      folders = f;
      loading = false;
    });
  }

  Future<void> _delete(ScanDoc d) async {
    await LibraryStore.instance.removeById(d.id);
    await ScanService.instance.deleteDocFiles(d.id);
    await _load();
  }

  List<ScanDoc> get _filtered {
    final q = query.trim().toLowerCase();
    return docs.where((d) {
      final inFolder = folderIdFilter == null
          ? true
          : folderIdFilter == 'unsorted'
          ? (d.folderId == null || d.folderId!.isEmpty)
          : d.folderId == folderIdFilter;
      if (!inFolder) return false;
      if (q.isEmpty) return true;

      final inTitle = d.title.toLowerCase().contains(q);
      final inTags = d.tags.any((t) => t.toLowerCase().contains(q));
      return inTitle || inTags;
    }).toList();
  }

  String _folderLabel(String? id) {
    if (id == null) return 'All';
    if (id == LibraryStore.unsortedFolder.id) return 'Unsorted';
    final f = folders.where((e) => e.id == id).toList();
    return f.isEmpty ? 'Folder' : f.first.name;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final filtered = _filtered;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Library'),
        actions: [
          IconButton(
            tooltip: 'Folders',
            onPressed: () async {
              await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FoldersPage()));
              await _load();
            },
            icon: const Icon(Icons.folder_copy_outlined),
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
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          onChanged: (v) => setState(() => query = v),
                          decoration: InputDecoration(
                            hintText: 'Search title or tags',
                            prefixIcon: const Icon(Icons.search),
                            filled: true,
                            fillColor: cs.surfaceVariant,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: cs.outline),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: cs.outline),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: cs.surfaceVariant,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: cs.outline),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String?>(
                            value: folderIdFilter,
                            hint: const Text('All'),
                            items: [
                              const DropdownMenuItem<String?>(value: null, child: Text('All')),
                              const DropdownMenuItem<String?>(
                                value: 'unsorted',
                                child: Text('Unsorted'),
                              ),
                              ...folders
                                  .where((f) => f.id != LibraryStore.unsortedFolder.id)
                                  .map((f) => DropdownMenuItem<String?>(value: f.id, child: Text(f.name))),
                            ],
                            onChanged: (v) => setState(() => folderIdFilter = v),
                          ),
                        ),
                      ),
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
                                  docs.isEmpty ? 'No documents yet' : 'No matches',
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),
                                const SizedBox(height: 6),
                                Text(docs.isEmpty ? 'Scan a document and it will appear here.' : 'Try another search or folder.'),
                              ],
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, i) {
                            final d = filtered[i];
                            final thumb = File(d.thumbPath);
                            final folderLabel = _folderLabel(d.folderId);

                            return InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => ViewDocPage(docId: d.id)),
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(12),
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
                                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.outline),
                                          ),
                                          const SizedBox(height: 6),
                                          Wrap(
                                            spacing: 6,
                                            runSpacing: 6,
                                            children: [
                                              _MiniChip(icon: Icons.folder, text: folderLabel),
                                              for (final t in d.tags.take(4)) _MiniChip(icon: Icons.tag, text: t),
                                              if (d.tags.length > 4)
                                                _MiniChip(icon: Icons.more_horiz, text: '+${d.tags.length - 4}'),
                                            ],
                                          ),
                                          const SizedBox(height: 10),
                                          Row(
                                            children: [
                                              ElevatedButton(
                                                onPressed: () => Navigator.of(context).push(
                                                  MaterialPageRoute(builder: (_) => ViewDocPage(docId: d.id)),
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
                ),
              ],
            ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  final IconData icon;
  final String text;
  const _MiniChip({required this.icon, required this.text});

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
