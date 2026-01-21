import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/storage_service.dart';
import '../controllers/settings_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsProvider);
    return settingsAsync.when(
      data: (settings) {
        return Scaffold(
          appBar: AppBar(title: const Text('Settings')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SwitchListTile(
                title: const Text('Enable OCR'),
                subtitle: const Text('Extract text for search and copy.'),
                value: settings.ocrEnabled,
                onChanged: (value) =>
                    ref.read(settingsProvider.notifier).updateOcr(value),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: settings.defaultExportFormat,
                decoration: const InputDecoration(
                  labelText: 'Default export format',
                ),
                items: const [
                  DropdownMenuItem(value: 'PDF', child: Text('PDF')),
                  DropdownMenuItem(value: 'Images', child: Text('Images')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    ref.read(settingsProvider.notifier).updateExportFormat(value);
                  }
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: settings.defaultPageSize,
                decoration: const InputDecoration(
                  labelText: 'Default PDF page size',
                ),
                items: const [
                  DropdownMenuItem(value: 'A4', child: Text('A4')),
                  DropdownMenuItem(value: 'Letter', child: Text('Letter')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    ref.read(settingsProvider.notifier).updatePageSize(value);
                  }
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: settings.defaultColorMode,
                decoration: const InputDecoration(
                  labelText: 'Default color mode',
                ),
                items: const [
                  DropdownMenuItem(value: 'Color', child: Text('Color')),
                  DropdownMenuItem(value: 'Grayscale', child: Text('Grayscale')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    ref.read(settingsProvider.notifier).updateColorMode(value);
                  }
                },
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                title: const Text('Encrypt PDFs locally'),
                subtitle: const Text('Optional protection for exported PDFs.'),
                value: settings.encryptPdf,
                onChanged: (value) =>
                    ref.read(settingsProvider.notifier).updateEncryptPdf(value),
              ),
              const SizedBox(height: 12),
              FutureBuilder<int>(
                future: StorageService().getStorageSize(),
                builder: (context, snapshot) {
                  final size = snapshot.data ?? 0;
                  final sizeMb = (size / (1024 * 1024)).toStringAsFixed(2);
                  return ListTile(
                    title: const Text('Storage used'),
                    subtitle: Text('$sizeMb MB'),
                    trailing: TextButton(
                      onPressed: () async {
                        await StorageService().clearCache();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Cache cleared.'),
                            ),
                          );
                        }
                      },
                      child: const Text('Clear cache'),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        body: Center(child: Text('Failed to load settings: $error')),
      ),
    );
  }
}
