import 'stub.dart' if (dart.library.html) 'web.dart' as impl;

enum WebSensorStatus {
  supported,
  notSupported,
  requiresHttps,
  requiresPermission,
  permissionDenied,
}

class WebSensorSupport {
  static Future<WebSensorStatus> checkAccelerometerSupport() =>
      impl.checkAccelerometerSupport();

  static bool get isSecureContext => impl.isSecureContext;
}
