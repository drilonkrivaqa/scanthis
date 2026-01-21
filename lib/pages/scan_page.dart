import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../models/scan_entry.dart';
import '../services/history_store.dart';
import '../widgets/result_sheet.dart';
import '../widgets/scan_overlay.dart';

class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> with WidgetsBindingObserver {
  final MobileScannerController controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  bool isHandling = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // MobileScanner widget auto-starts by default in v6, so no need to call start() here.
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    controller.dispose();
    super.dispose();
  }

  // Recommended lifecycle handling for start/stop on app resume/inactive :contentReference[oaicite:2]{index=2}
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // If permission not granted yet, do nothing.
    if (!controller.value.hasCameraPermission) return;

    switch (state) {
      case AppLifecycleState.resumed:
      // Restart the camera/scanner
        controller.start();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        controller.stop();
        break;
    }
  }

  Rect _scanWindowFor(Size size) {
    final w = size.width * 0.74;
    final h = w;
    final left = (size.width - w) / 2;
    final top = size.height * 0.20;
    return Rect.fromLTWH(left, top, w, h);
  }

  Future<void> _showResult(BuildContext context, String value, String format) async {
    if (isHandling) return;
    isHandling = true;

    // In v6 use stop()/start() instead of pause()/resume() :contentReference[oaicite:3]{index=3}
    await controller.stop();

    if (!context.mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      builder: (_) {
        return ResultSheet(
          value: value,
          format: format,
          onSave: () async {
            await HistoryStore.instance.add(
              ScanEntry(value: value, format: format, createdAt: DateTime.now()),
            );
          },
        );
      },
    );

    isHandling = false;
    await controller.start();
  }

  Future<void> _pickAndAnalyze() async {
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(source: ImageSource.gallery);
      if (file == null) return;

      // analyzeImage returns BarcodeCapture? in v5+ :contentReference[oaicite:4]{index=4}
      final capture = await controller.analyzeImage(file.path);

      final barcodes = capture?.barcodes ?? [];
      if (!mounted) return;

      if (barcodes.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No barcode/QR found in that image')),
        );
        return;
      }

      final best = barcodes.first;
      final value = best.rawValue ?? '';
      final format = best.format.name;

      if (value.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Detected, but value was empty')),
        );
        return;
      }

      await _showResult(context, value, format);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gallery scan failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final scanWindow = _scanWindowFor(size);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Scan'),
            actions: [
              IconButton(
                tooltip: 'Pick image',
                onPressed: _pickAndAnalyze,
                icon: const Icon(Icons.photo_library_outlined),
              ),

              // In v5+ the old torchState notifier is removed.
              // Use controller.value.torchState via ValueListenableBuilder on the controller itself. :contentReference[oaicite:5]{index=5}
              ValueListenableBuilder(
                valueListenable: controller,
                builder: (context, value, _) {
                  final torch = value.torchState; // TorchState.on/off/unavailable
                  final isUnavailable = torch == TorchState.unavailable;

                  return IconButton(
                    tooltip: isUnavailable ? 'Flash unavailable' : 'Flash',
                    onPressed: isUnavailable ? null : () => controller.toggleTorch(),
                    icon: Icon(
                      torch == TorchState.on ? Icons.flash_on : Icons.flash_off,
                    ),
                  );
                },
              ),

              IconButton(
                tooltip: 'Switch camera',
                onPressed: () => controller.switchCamera(),
                icon: const Icon(Icons.cameraswitch),
              ),
              const SizedBox(width: 6),
            ],
          ),
          body: Stack(
            children: [
              MobileScanner(
                controller: controller,
                scanWindow: scanWindow,
                onDetect: (capture) async {
                  final barcodes = capture.barcodes;
                  if (barcodes.isEmpty) return;

                  final best = barcodes.first;
                  final value = best.rawValue ?? '';
                  if (value.trim().isEmpty) return;

                  final format = best.format.name;
                  await _showResult(context, value, format);
                },
                errorBuilder: (context, error, child) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.error_outline, size: 44, color: cs.error),
                          const SizedBox(height: 10),
                          Text(
                            'Camera error',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            error.toString(),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

              // Overlay
              ScanOverlay(window: scanWindow),

              // Bottom hint card
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: cs.outlineVariant),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.center_focus_strong),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Align the QR/barcode inside the frame. It will scan automatically.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                        const SizedBox(width: 10),
                        FilledButton(
                          onPressed: _pickAndAnalyze,
                          child: const Text('Gallery'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
