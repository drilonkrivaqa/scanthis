import 'dart:io';

import 'package:flutter/material.dart';
import '../services/edit_service.dart';
import '../services/enhance_presets.dart';
import '../services/library_store.dart';
import '../models/scan_doc.dart';
import 'annotate_page.dart';

class EditDocPage extends StatefulWidget {
  final String docId;
  const EditDocPage({super.key, required this.docId});

  @override
  State<EditDocPage> createState() => _EditDocPageState();
}

class _EditDocPageState extends State<EditDocPage> {
  bool loading = true;
  ScanDoc? doc;
  List<File> pages = [];
  EnhancePreset preset = EnhancePreset.original;
  bool rebuilding = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);

    final all = await LibraryStore.instance.load();
    doc = all.where((d) => d.id == widget.docId).toList().firstOrNull;

    final meta = await EditService.instance.loadMeta(widget.docId);
    preset = presetFromKey(meta.preset);

    pages = await EditService.instance.listOriginalPages(widget.docId);

    if (!mounted) return;
    setState(() => loading = false);
  }

  Future<void> _setPreset(EnhancePreset p) async {
    setState(() => preset = p);
    await EditService.instance.setPreset(widget.docId, p);
  }

  Future<void> _rebuild() async {
    if (rebuilding) return;
    setState(() => rebuilding = true);
    try {
      await EditService.instance.renderAndRebuildPdf(widget.docId);
      // update thumb path to rendered first page if exists
      final scanDir = Directory(File(pages.first.path).parent.path);
      final renderedThumb = File('${scanDir.path}/render/${pages.first.uri.pathSegments.last}');
      if (doc != null && await renderedThumb.exists()) {
        final updated = doc!.copyWith();
        // thumbPath in ScanDoc is final and copyWith doesn't include thumbPath; keep simple: do nothing.
        // View page uses thumbPath; original is okay. Rendered thumb used inside PDF anyway.
        await LibraryStore.instance.update(updated);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PDF rebuilt with enhancements')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Rebuild failed: $e')),
      );
    } finally {
      if (mounted) setState(() => rebuilding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit'),
        actions: [
          IconButton(
            tooltip: 'Rebuild PDF',
            onPressed: rebuilding ? null : _rebuild,
            icon: rebuilding
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.picture_as_pdf_outlined),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : pages.isEmpty
              ? const Center(child: Text('No pages found'))
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: cs.surfaceVariant,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: cs.outline),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<EnhancePreset>(
                                  value: preset,
                                  isExpanded: true,
                                  items: EnhancePreset.values
                                      .map(
                                        (p) => DropdownMenuItem(
                                          value: p,
                                          child: Text(presetName(p)),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (v) => v == null ? null : _setPreset(v),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton.icon(
                            onPressed: rebuilding ? null : _rebuild,
                            icon: const Icon(Icons.auto_fix_high_outlined),
                            label: const Text('Apply & Rebuild'),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                        itemCount: pages.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final f = pages[i];
                          return Container(
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
                                    child: Image.file(f, fit: BoxFit.cover),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Page ${i + 1}',
                                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                              fontWeight: FontWeight.w900,
                                            ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Tap annotate to add redaction, stamp, signature',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(color: cs.outline),
                                      ),
                                      const SizedBox(height: 10),
                                      Row(
                                        children: [
                                          ElevatedButton(
                                            onPressed: () => Navigator.of(context).push(
                                              MaterialPageRoute(
                                                builder: (_) => AnnotatePage(docId: widget.docId, pagePath: f.path),
                                              ),
                                            ),
                                            child: const Text('Annotate'),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
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

// Small extension without importing collection package.
extension _FirstOrNullExt<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
