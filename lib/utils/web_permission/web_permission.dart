import 'stub.dart' if (dart.library.html) 'web.dart' as impl;

class WebPermissionUtils {
  static Future<bool> requestSensorPermission() =>
      impl.requestSensorPermission();
  static bool get needsPermissionRequest => impl.needsPermissionRequest;
}
