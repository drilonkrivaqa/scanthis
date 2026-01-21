import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/empty_state.dart';
import '../controllers/scan_controller.dart';
import 'scan_review_screen.dart';

class ScanScreen extends ConsumerWidget {
  const ScanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(scanControllerProvider);
    final controller = ref.read(scanControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Scan')),
      body: state.when(
        data: (data) {
          if (data.isPermissionDenied) {
            return EmptyState(
              title: 'Camera permission needed',
              subtitle:
                  'Allow camera access to scan documents, or import from gallery.',
              icon: Icons.camera_alt,
              action: FilledButton(
                onPressed: controller.importFromGallery,
                child: const Text('Import from gallery'),
              ),
            );
          }
          if (!data.isReady || controller.cameraController == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return Column(
            children: [
              Expanded(
                child: CameraPreview(controller.cameraController!),
              ),
              if (data.captured.isNotEmpty)
                SizedBox(
                  height: 100,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    scrollDirection: Axis.horizontal,
                    itemBuilder: (context, index) {
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          data.captured[index],
                          width: 72,
                          height: 72,
                          fit: BoxFit.cover,
                        ),
                      );
                    },
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemCount: data.captured.length,
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.photo_library),
                      onPressed: controller.importFromGallery,
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: controller.capture,
                      child: const Icon(Icons.camera_alt),
                    ),
                    const Spacer(),
                    FilledButton.tonal(
                      onPressed: data.captured.isEmpty
                          ? null
                          : () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => ScanReviewScreen(
                                    images: data.captured,
                                  ),
                                ),
                              );
                              controller.resetSession();
                            },
                      child: const Text('Finish'),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Camera error: $error')),
      ),
    );
  }
}
