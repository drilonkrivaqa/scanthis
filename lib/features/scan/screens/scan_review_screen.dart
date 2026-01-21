import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../library/screens/document_detail_screen.dart';
import '../controllers/scan_review_controller.dart';
import 'scan_edit_screen.dart';

class ScanReviewScreen extends ConsumerWidget {
  const ScanReviewScreen({super.key, required this.images});

  final List<File> images;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(scanReviewControllerProvider(images));
    final controller =
        ref.read(scanReviewControllerProvider(images).notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Review scans')),
      body: Column(
        children: [
          if (state.isProcessing) const LinearProgressIndicator(),
          if (state.progressMessage.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(state.progressMessage),
            ),
          Expanded(
            child: ListView.builder(
              itemCount: state.images.length,
              itemBuilder: (context, index) {
                final image = state.images[index];
                return Card(
                  margin: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Image.file(image, height: 200, fit: BoxFit.cover),
                      ButtonBar(
                        children: [
                          TextButton.icon(
                            onPressed: () async {
                              final edited = await Navigator.of(context).push<File>(
                                MaterialPageRoute(
                                  builder: (_) => ScanEditScreen(image: image),
                                ),
                              );
                              if (edited != null) {
                                await controller.updateImage(index, edited);
                              }
                            },
                            icon: const Icon(Icons.edit),
                            label: const Text('Edit'),
                          ),
                        ],
                      )
                    ],
                  ),
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
              child: FilledButton(
                onPressed: state.isProcessing
                    ? null
                    : () async {
                        final docId = await controller.saveDocument();
                        if (context.mounted) {
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                              builder: (_) => DocumentDetailScreen(
                                documentId: docId,
                              ),
                            ),
                            (route) => route.isFirst,
                          );
                        }
                      },
                child: const Text('Save document'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
