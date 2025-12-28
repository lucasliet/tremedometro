// ignore: avoid_web_libraries_in_flutter
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

Future<bool> requestSensorPermission() async {
  try {
    if (!needsPermissionRequest) return true;

    final JSAny? deviceMotionEvent = web.window['DeviceMotionEvent'];
    // Linter claims checking null here is dead code in some contexts, but it is necessary for safety.
    // We suppress the warning if needed, or rely on flow.
    // ignore: unnecessary_cast
    if (deviceMotionEvent == null) return true;

    final JSObject deviceMotionObj = deviceMotionEvent as JSObject;

    if (!deviceMotionObj.has('requestPermission')) return true;

    final JSAny? requestPermission = deviceMotionObj['requestPermission'];
    if (requestPermission == null) return true;

    final promise = (requestPermission as JSFunction).callAsFunction(
      deviceMotionObj,
    );
    final result = await (promise as JSPromise).toDart;

    return (result as JSString).toDart == 'granted';
  } catch (e) {
    debugPrint('WEB_PERMISSION: Erro ao solicitar permissão: $e');
    return false;
  }
}

bool get needsPermissionRequest {
  final JSAny? deviceMotionEvent = web.window['DeviceMotionEvent'];
  if (deviceMotionEvent == null) return false;

  // ignore: unnecessary_cast
  return (deviceMotionEvent as JSObject).has('requestPermission');
}
