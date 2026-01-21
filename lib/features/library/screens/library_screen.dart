import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/debouncer.dart';
import '../../../shared/widgets/empty_state.dart';
import '../controllers/library_controller.dart';
import '../widgets/document_card.dart';
import '../widgets/document_list_tile.dart';
import 'folder_management_screen.dart';
import 'document_detail_screen.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  final _searchController = TextEditingController();
  final _debouncer = Debouncer();

  @override
  void dispose() {
    _searchController.dispose();
    _debouncer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(libraryControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Library'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _openFilters(context),
          ),
          IconButton(
            icon: const Icon(Icons.sort),
            onPressed: () => _openSort(context),
          ),
          IconButton(
            icon: const Icon(Icons.grid_view),
            onPressed: () =>
                ref.read(libraryControllerProvider.notifier).toggleView(),
          ),
          IconButton(
            icon: const Icon(Icons.folder),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const FolderManagementScreen()),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Search documents, tags, OCR text',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) {
                _debouncer.run(() {
                  ref.read(libraryControllerProvider.notifier).setQuery(value);
                });
              },
            ),
            const SizedBox(height: 16),
            Expanded(
              child: state.when(
                data: (data) {
                  if (data.documents.isEmpty) {
                    return const EmptyState(
                      title: 'No documents yet',
                      subtitle: 'Scan your first document to build your library.',
                      icon: Icons.description_outlined,
                    );
                  }
                  if (data.isGrid) {
                    return GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 0.72,
                      ),
                      itemCount: data.documents.length,
                      itemBuilder: (context, index) {
                        final doc = data.documents[index];
                        return DocumentCard(
                          document: doc,
                          onTap: () => _openDetail(context, doc.id),
                          onFavorite: () => ref
                              .read(libraryControllerProvider.notifier)
                              .toggleFavorite(doc),
                        );
                      },
                    );
                  }
                  return ListView.builder(
                    itemCount: data.documents.length,
                    itemBuilder: (context, index) {
                      final doc = data.documents[index];
                      return DocumentListTile(
                        document: doc,
                        onTap: () => _openDetail(context, doc.id),
                        onFavorite: () => ref
                            .read(libraryControllerProvider.notifier)
                            .toggleFavorite(doc),
                      );
                    },
                  );
                },
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(
                  child: Text('Failed to load library: $error'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openDetail(BuildContext context, String id) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DocumentDetailScreen(documentId: id),
      ),
    );
  }

  Future<void> _openSort(BuildContext context) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (context) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Sort by', style: TextStyle(fontSize: 18)),
            ListTile(
              title: const Text('Newest'),
              onTap: () => Navigator.pop(context, 'updated_at DESC'),
            ),
            ListTile(
              title: const Text('Oldest'),
              onTap: () => Navigator.pop(context, 'updated_at ASC'),
            ),
            ListTile(
              title: const Text('Title A-Z'),
              onTap: () => Navigator.pop(context, 'title ASC'),
            ),
          ],
        );
      },
    );
    if (selected != null && context.mounted) {
      await ref.read(libraryControllerProvider.notifier).setSort(selected);
    }
  }

  Future<void> _openFilters(BuildContext context) async {
    final controller = ref.read(libraryControllerProvider.notifier);
    final folders = await controller.loadFolders();
    final tags = await controller.loadTags();
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Filters', style: TextStyle(fontSize: 18)),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Folder'),
                items: [
                  const DropdownMenuItem(value: '', child: Text('All folders')),
                  ...folders.map(
                    (folder) => DropdownMenuItem(
                      value: folder.id,
                      child: Text(folder.name),
                    ),
                  )
                ],
                onChanged: (value) {
                  controller.setFolderFilter(value?.isEmpty ?? true ? null : value);
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Tag'),
                items: [
                  const DropdownMenuItem(value: '', child: Text('All tags')),
                  ...tags.map(
                    (tag) => DropdownMenuItem(
                      value: tag.id,
                      child: Text(tag.name),
                    ),
                  )
                ],
                onChanged: (value) {
                  controller.setTagFilter(value?.isEmpty ?? true ? null : value);
                },
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Done'),
                ),
              )
            ],
          ),
        );
      },
    );
  }
}
