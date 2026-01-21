import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../../../core/database/dao/folder_dao.dart';
import '../../../core/database/models.dart';
import '../../../core/utils/date_formatters.dart';
import '../controllers/document_detail_controller.dart';

class DocumentDetailScreen extends ConsumerWidget {
  const DocumentDetailScreen({super.key, required this.documentId});

  final String documentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(documentDetailProvider(documentId));
    return state.when(
      data: (data) {
        return Scaffold(
          appBar: AppBar(
            title: Text(data.document.title),
            actions: [
              IconButton(
                icon: Icon(
                  data.document.isFavorite ? Icons.star : Icons.star_border,
                ),
                onPressed: () => ref
                    .read(documentDetailProvider(documentId).notifier)
                    .toggleFavorite(),
              ),
              PopupMenuButton<String>(
                onSelected: (value) async {
                  if (value == 'rename') {
                    _rename(context, ref);
                  }
                  if (value == 'ocr') {
                    ref
                        .read(documentDetailProvider(documentId).notifier)
                        .rerunOcr();
                  }
                  if (value == 'delete') {
                    await ref
                        .read(documentDetailProvider(documentId).notifier)
                        .deleteDocument();
                    if (context.mounted) {
                      Navigator.pop(context);
                    }
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'rename', child: Text('Rename')),
                  PopupMenuItem(value: 'ocr', child: Text('Re-run OCR')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ],
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${data.pages.length} pages • ${DateFormatters.shortDate.format(data.document.updatedAt)}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _showShareSheet(context, ref),
                      icon: const Icon(Icons.share),
                      label: const Text('Share'),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _TagsSection(
                  tags: data.tags,
                  onAdd: () => _addTag(context, ref),
                  onRemove: (tag) => ref
                      .read(documentDetailProvider(documentId).notifier)
                      .removeTag(tag),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: FutureBuilder<List<FolderModel>>(
                  future: FolderDao().list(),
                  builder: (context, snapshot) {
                    final folders = snapshot.data ?? [];
                    return DropdownButtonFormField<String>(
                      value: data.document.folderId ?? '',
                      decoration: const InputDecoration(labelText: 'Folder'),
                      items: [
                        const DropdownMenuItem(
                          value: '',
                          child: Text('No folder'),
                        ),
                        ...folders.map(
                          (folder) => DropdownMenuItem(
                            value: folder.id,
                            child: Text(folder.name),
                          ),
                        )
                      ],
                      onChanged: (value) {
                        ref
                            .read(documentDetailProvider(documentId).notifier)
                            .updateFolder(
                                value?.isEmpty ?? true ? null : value);
                      },
                    );
                  },
                ),
              ),
              if (data.isLoading) const LinearProgressIndicator(),
              Expanded(
                child: ReorderableListView.builder(
                  itemCount: data.pages.length,
                  onReorder: (oldIndex, newIndex) async {
                    if (newIndex > oldIndex) {
                      newIndex -= 1;
                    }
                    final updated = [...data.pages];
                    final item = updated.removeAt(oldIndex);
                    updated.insert(newIndex, item);
                    await ref
                        .read(documentDetailProvider(documentId).notifier)
                        .reorderPages(updated);
                  },
                  itemBuilder: (context, index) {
                    final page = data.pages[index];
                    return ListTile(
                      key: ValueKey(page.id),
                      leading: Image.file(
                        File(page.imagePath),
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                      ),
                      title: Text('Page ${index + 1}'),
                      subtitle: Text(
                        page.ocrText?.isNotEmpty == true
                            ? 'OCR text available'
                            : 'No OCR text',
                      ),
                      trailing: const Icon(Icons.drag_handle),
                    );
                  },
                ),
              ),
            ],
          ),
          bottomNavigationBar: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => ref
                        .read(documentDetailProvider(documentId).notifier)
                        .regeneratePdf(),
                    icon: const Icon(Icons.picture_as_pdf),
                    label: const Text('Regenerate PDF'),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  onPressed: () => ref
                      .read(documentDetailProvider(documentId).notifier)
                      .openPdf(),
                  icon: const Icon(Icons.open_in_new),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        body: Center(child: Text('Failed to load document: $error')),
      ),
    );
  }

  Future<void> _showShareSheet(BuildContext context, WidgetRef ref) async {
    final controller = ref.read(documentDetailProvider(documentId).notifier);
    final option = await showModalBottomSheet<String>(
      context: context,
      builder: (context) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Export / Share', style: TextStyle(fontSize: 18)),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf),
              title: const Text('Share PDF'),
              onTap: () => Navigator.pop(context, 'pdf'),
            ),
            ListTile(
              leading: const Icon(Icons.image),
              title: const Text('Share images'),
              onTap: () => Navigator.pop(context, 'images'),
            ),
            ListTile(
              leading: const Icon(Icons.preview),
              title: const Text('Preview PDF'),
              onTap: () => Navigator.pop(context, 'preview'),
            ),
          ],
        );
      },
    );

    if (option == 'pdf') {
      await controller.sharePdf();
    }
    if (option == 'images') {
      await controller.shareImages();
    }
    if (option == 'preview') {
      final state = ref.read(documentDetailProvider(documentId)).value;
      final pdfPath = state?.document.pdfPath;
      if (pdfPath == null) return;
      await Printing.layoutPdf(onLayout: (_) async {
        final file = File(pdfPath);
        return file.readAsBytes();
      });
    }
  }

  Future<void> _rename(BuildContext context, WidgetRef ref) async {
    final controller = ref.read(documentDetailProvider(documentId).notifier);
    final titleController = TextEditingController();
    final newTitle = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Rename document'),
          content: TextField(
            controller: titleController,
            decoration: const InputDecoration(labelText: 'Title'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, titleController.text),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    if (newTitle != null && newTitle.isNotEmpty) {
      await controller.rename(newTitle);
    }
  }

  Future<void> _addTag(BuildContext context, WidgetRef ref) async {
    final controller = ref.read(documentDetailProvider(documentId).notifier);
    final tagController = TextEditingController();
    final tagName = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add tag'),
          content: TextField(
            controller: tagController,
            decoration: const InputDecoration(labelText: 'Tag name'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, tagController.text),
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
    if (tagName != null && tagName.isNotEmpty) {
      await controller.addTag(tagName);
    }
  }
}

class _TagsSection extends StatelessWidget {
  const _TagsSection({
    required this.tags,
    required this.onAdd,
    required this.onRemove,
  });

  final List<TagModel> tags;
  final VoidCallback onAdd;
  final void Function(TagModel) onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final tag in tags)
                    Chip(
                      label: Text(tag.name),
                      onDeleted: () => onRemove(tag),
                    ),
                  if (tags.isEmpty)
                    Text(
                      'No tags yet',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: onAdd,
            ),
          ],
        ),
      ),
    );
  }
}
