import 'package:permission_handler/permission_handler.dart';

class PermissionsService {
  Future<bool> requestCamera() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  Future<bool> requestPhotos() async {
    final status = await Permission.photos.request();
    return status.isGranted;
  }

  Future<bool> requestStorage() async {
    final status = await Permission.storage.request();
    return status.isGranted;
  }
}
