import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/services/image_processing_service.dart';

class ScanEditScreen extends StatefulWidget {
  const ScanEditScreen({super.key, required this.image});

  final File image;

  @override
  State<ScanEditScreen> createState() => _ScanEditScreenState();
}

class _ScanEditScreenState extends State<ScanEditScreen> {
  final _imageProcessingService = ImageProcessingService();
  double _brightness = 0;
  double _contrast = 1;
  int _rotation = 0;
  Rect? _cropRect;
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit page')),
      body: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  children: [
                    Positioned.fill(
                      child: Image.file(widget.image, fit: BoxFit.contain),
                    ),
                    if (_cropRect != null)
                      Positioned.fromRect(
                        rect: _cropRect!,
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Theme.of(context).colorScheme.primary,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      left: 16,
                      bottom: 16,
                      child: FilledButton.tonal(
                        onPressed: () => _setDefaultCrop(constraints.biggest),
                        child: const Text('Manual crop'),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: _autoCrop,
                      icon: const Icon(Icons.crop),
                      label: const Text('Auto crop'),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.rotate_left),
                      onPressed: () => setState(() => _rotation--),
                    ),
                    IconButton(
                      icon: const Icon(Icons.rotate_right),
                      onPressed: () => setState(() => _rotation++),
                    ),
                  ],
                ),
                Slider(
                  value: _brightness,
                  min: -0.5,
                  max: 0.5,
                  divisions: 10,
                  label: 'Brightness',
                  onChanged: (value) => setState(() => _brightness = value),
                ),
                Slider(
                  value: _contrast,
                  min: 0.5,
                  max: 1.5,
                  divisions: 10,
                  label: 'Contrast',
                  onChanged: (value) => setState(() => _contrast = value),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: FilledButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const CircularProgressIndicator()
              : const Text('Apply changes'),
        ),
      ),
    );
  }

  void _setDefaultCrop(Size size) {
    setState(() {
      _cropRect = Rect.fromLTWH(
        size.width * 0.1,
        size.height * 0.1,
        size.width * 0.8,
        size.height * 0.6,
      );
    });
  }

  Future<void> _autoCrop() async {
    setState(() => _isSaving = true);
    final image = await _imageProcessingService.loadImage(widget.image);
    if (image != null) {
      final cropped = _imageProcessingService.autoCrop(image);
      final tempDir = await getTemporaryDirectory();
      final output = File('${tempDir.path}/auto_crop_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await _imageProcessingService.saveImage(cropped, output);
      if (mounted) {
        Navigator.pop(context, output);
      }
    }
    if (mounted) {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    final image = await _imageProcessingService.loadImage(widget.image);
    if (image == null) return;

    var processed = _imageProcessingService.applyRotate(image, _rotation % 4);
    processed = _imageProcessingService.applyBrightnessContrast(
      processed,
      brightness: _brightness,
      contrast: _contrast,
    );

    if (_cropRect != null) {
      final width = processed.width;
      final height = processed.height;
      final rect = _cropRect!;
      final screenSize = MediaQuery.of(context).size;
      final crop = _imageProcessingService.crop(
        processed,
        (rect.left / screenSize.width * width).toInt(),
        (rect.top / screenSize.height * height).toInt(),
        (rect.width / screenSize.width * width).toInt(),
        (rect.height / screenSize.height * height).toInt(),
      );
      processed = crop;
    }

    final tempDir = await getTemporaryDirectory();
    final output = File('${tempDir.path}/edit_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await _imageProcessingService.saveImage(processed, output);
    if (mounted) {
      Navigator.pop(context, output);
    }
    if (mounted) {
      setState(() => _isSaving = false);
    }
  }
}
