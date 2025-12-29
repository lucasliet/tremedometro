// ignore: avoid_web_libraries_in_flutter
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

import 'web_sensor_support.dart';

Future<WebSensorStatus> checkAccelerometerSupport() async {
  try {
    // Verifica se está em contexto seguro (HTTPS ou localhost)
    if (!isSecureContext) {
      return WebSensorStatus.requiresHttps;
    }

    // Verifica se DeviceMotionEvent existe
    final JSAny? deviceMotionEvent = web.window['DeviceMotionEvent'];
    if (deviceMotionEvent == null) {
      return WebSensorStatus.notSupported;
    }

    final JSObject deviceMotionObj = deviceMotionEvent as JSObject;

    // iOS Safari requer permissão explícita
    if (deviceMotionObj.has('requestPermission')) {
      return WebSensorStatus.requiresPermission;
    }

    // Navegadores modernos em HTTPS
    return WebSensorStatus.supported;
  } catch (e) {
    debugPrint('WEB_SENSOR_SUPPORT: Erro ao verificar suporte: $e');
    return WebSensorStatus.notSupported;
  }
}

bool get isSecureContext {
  try {
    return web.window.isSecureContext;
  } catch (e) {
    debugPrint('WEB_SENSOR_SUPPORT: Erro ao verificar contexto seguro: $e');
    return false;
  }
}
