import 'package:flutter_test/flutter_test.dart';
import 'package:blueguava/utils/web_sensor_support/web_sensor_support.dart';

void main() {
  group('WebSensorSupport Tests', () {
    test('checkAccelerometerSupport retorna supported em plataformas não-web',
        () async {
      // Em plataformas não-web (mobile), o stub deve retornar supported
      final status = await WebSensorSupport.checkAccelerometerSupport();
      expect(status, WebSensorStatus.supported);
    });

    test('isSecureContext retorna true em plataformas não-web', () {
      // Em plataformas não-web (mobile), o stub deve retornar true
      expect(WebSensorSupport.isSecureContext, isTrue);
    });
  });
}
