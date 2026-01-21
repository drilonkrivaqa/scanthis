import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/services/permissions_service.dart';

class ScanState {
  const ScanState({
    required this.isReady,
    required this.isPermissionDenied,
    required this.captured,
  });

  final bool isReady;
  final bool isPermissionDenied;
  final List<File> captured;

  ScanState copyWith({
    bool? isReady,
    bool? isPermissionDenied,
    List<File>? captured,
  }) {
    return ScanState(
      isReady: isReady ?? this.isReady,
      isPermissionDenied: isPermissionDenied ?? this.isPermissionDenied,
      captured: captured ?? this.captured,
    );
  }
}

class ScanController extends StateNotifier<AsyncValue<ScanState>> {
  ScanController({required PermissionsService permissionsService})
      : _permissionsService = permissionsService,
        super(
          const AsyncValue.data(
            ScanState(isReady: false, isPermissionDenied: false, captured: []),
          ),
        );

  final PermissionsService _permissionsService;
  CameraController? _cameraController;

  CameraController? get cameraController => _cameraController;

  Future<void> initCamera() async {
    try {
      final allowed = await _permissionsService.requestCamera();
      if (!allowed) {
        state = AsyncValue.data(
          state.value!.copyWith(isPermissionDenied: true),
        );
        return;
      }
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        state = AsyncValue.data(
          state.value!.copyWith(isPermissionDenied: true),
        );
        return;
      }
      _cameraController = CameraController(
        cameras.first,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await _cameraController!.initialize();
      state = AsyncValue.data(
        state.value!.copyWith(isReady: true, isPermissionDenied: false),
      );
    } catch (error, stack) {
      state = AsyncValue.error(error, stack);
    }
  }

  Future<void> capture() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }
    final file = await _cameraController!.takePicture();
    final current = state.value!;
    state = AsyncValue.data(
      current.copyWith(captured: [...current.captured, File(file.path)]),
    );
  }

  Future<void> importFromGallery() async {
    final allowed = await _permissionsService.requestPhotos();
    if (!allowed) {
      return;
    }
    final picker = ImagePicker();
    final result = await picker.pickImage(source: ImageSource.gallery);
    if (result == null) return;
    final current = state.value!;
    state = AsyncValue.data(
      current.copyWith(captured: [...current.captured, File(result.path)]),
    );
  }

  void resetSession() {
    final current = state.value!;
    state = AsyncValue.data(current.copyWith(captured: []));
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }
}

final scanControllerProvider =
    StateNotifierProvider<ScanController, AsyncValue<ScanState>>((ref) {
  final controller =
      ScanController(permissionsService: PermissionsService());
  controller.initCamera();
  return controller;
});
