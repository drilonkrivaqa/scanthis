import 'package:flutter/material.dart';
import '../models/folder.dart';
import '../services/library_store.dart';
import '../utils/ids.dart';

class FoldersPage extends StatefulWidget {
  const FoldersPage({super.key});

  @override
  State<FoldersPage> createState() => _FoldersPageState();
}

class _FoldersPageState extends State<FoldersPage> {
  bool loading = true;
  List<Folder> folders = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    final data = await LibraryStore.instance.loadFolders();
    if (!mounted) return;
    setState(() {
      folders = data;
      loading = false;
    });
  }

  Future<void> _create() async {
    final name = await _promptName(title: 'New folder', hint: 'Folder name');
    if (name == null || name.isEmpty) return;
    final f = Folder(id: newId(), name: name);
    await LibraryStore.instance.addFolder(f);
    await _load();
  }

  Future<void> _rename(Folder f) async {
    if (f.id == LibraryStore.unsortedFolder.id) return;
    final name = await _promptName(title: 'Rename folder', hint: 'Folder name', initial: f.name);
    if (name == null || name.isEmpty) return;
    await LibraryStore.instance.renameFolder(f.id, name);
    await _load();
  }

  Future<void> _delete(Folder f) async {
    if (f.id == LibraryStore.unsortedFolder.id) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete folder?'),
        content: const Text('Documents in this folder will be moved to Unsorted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (ok != true) return;
    await LibraryStore.instance.deleteFolder(f.id);
    await _load();
  }

  Future<String?> _promptName({
    required String title,
    required String hint,
    String? initial,
  }) async {
    final c = TextEditingController(text: initial ?? '');
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: c,
          autofocus: true,
          decoration: InputDecoration(hintText: hint),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, c.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Folders'),
        actions: [
          IconButton(onPressed: _create, icon: const Icon(Icons.create_new_folder_outlined)),
          const SizedBox(width: 6),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              padding: const EdgeInsets.all(14),
              itemCount: folders.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final f = folders[i];
                final locked = f.id == LibraryStore.unsortedFolder.id;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: cs.surfaceVariant,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: cs.outline),
                  ),
                  child: Row(
                    children: [
                      Icon(locked ? Icons.lock_outline : Icons.folder, color: locked ? cs.outline : cs.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          f.name,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      if (!locked) ...[
                        IconButton(onPressed: () => _rename(f), icon: const Icon(Icons.edit)),
                        IconButton(onPressed: () => _delete(f), icon: const Icon(Icons.delete_outline)),
                      ],
                    ],
                  ),
                );
              },
            ),
    );
  }
}
