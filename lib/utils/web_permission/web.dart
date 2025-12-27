// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:js_util' as js_util;

Future<bool> requestSensorPermission() async {
  try {
    if (needsPermissionRequest) {
      final deviceMotionEvent = js_util.getProperty(
        html.window,
        'DeviceMotionEvent',
      );

      // requestPermission é um método estático em DeviceMotionEvent
      final permission = await js_util.promiseToFuture(
        js_util.callMethod(deviceMotionEvent, 'requestPermission', []),
      );
      return permission == 'granted';
    }
    return true;
  } catch (e) {
    return false;
  }
}

bool get needsPermissionRequest {
  try {
    final deviceMotionEvent = js_util.getProperty(
      html.window,
      'DeviceMotionEvent',
    );
    if (deviceMotionEvent == null) return false;

    // requestPermission é um método estático em DeviceMotionEvent
    return js_util.hasProperty(deviceMotionEvent, 'requestPermission');
  } catch (e) {
    return false;
  }
}
