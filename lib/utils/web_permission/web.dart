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
      final prototype = js_util.getProperty(deviceMotionEvent, 'prototype');

      final permission = await js_util.promiseToFuture(
        js_util.callMethod(prototype, 'requestPermission', []),
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

    // ignore: unnecessary_non_null_assertion
    final prototype = js_util.getProperty(deviceMotionEvent, 'prototype');

    return js_util.hasProperty(prototype, 'requestPermission');
  } catch (e) {
    return false;
  }
}
