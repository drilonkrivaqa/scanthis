import 'package:flutter/material.dart';

import '../models/document_models.dart';
import '../services/document_store.dart';
import '../utils/ids.dart';

class FoldersPage extends StatefulWidget {
  const FoldersPage({super.key});

  @override
  State<FoldersPage> createState() => _FoldersPageState();
}

class _FoldersPageState extends State<FoldersPage> {
  List<FolderModel> folders = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await DocumentStore.instance.loadFolders();
    if (!mounted) return;
    setState(() {
      folders = data;
      loading = false;
    });
  }

  Future<void> _addFolder() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('New Folder'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Folder name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (name == null || name.isEmpty) return;
    final folder = FolderModel(
      id: newId(),
      name: name,
      createdAt: DateTime.now(),
      color: 0xFF6366F1,
    );
    await DocumentStore.instance.addFolder(folder);
    await _load();
  }

  Future<void> _renameFolder(FolderModel folder) async {
    final controller = TextEditingController(text: folder.name);
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Rename Folder'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Folder name'),
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

    if (name == null || name.isEmpty) return;
    await DocumentStore.instance.updateFolder(folder.copyWith(name: name));
    await _load();
  }

  Future<void> _deleteFolder(FolderModel folder) async {
    await DocumentStore.instance.deleteFolder(folder.id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Folders'),
        actions: [
          IconButton(onPressed: _addFolder, icon: const Icon(Icons.add)),
          const SizedBox(width: 6),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: folders.length,
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (context, index) {
                final folder = folders[index];
                return ListTile(
                  leading: const Icon(Icons.folder),
                  title: Text(folder.name),
                  subtitle: Text(folder.id == 'unsorted' ? 'Default' : 'Custom folder'),
                  trailing: folder.id == 'unsorted'
                      ? null
                      : PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'rename') {
                              _renameFolder(folder);
                            } else if (value == 'delete') {
                              _deleteFolder(folder);
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'rename', child: Text('Rename')),
                            PopupMenuItem(value: 'delete', child: Text('Delete')),
                          ],
                        ),
                );
              },
            ),
    );
  }
}
