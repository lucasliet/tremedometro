import 'web_sensor_support.dart';

Future<WebSensorStatus> checkAccelerometerSupport() async {
  return WebSensorStatus.supported;
}

bool get isSecureContext => true;
