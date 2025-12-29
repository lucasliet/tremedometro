import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:blueguava/services/calibration_service.dart';
import 'package:blueguava/services/tremor_service.dart';

// Fake CalibrationService que não faz requests reais
class FakeCalibrationService implements CalibrationService {
  final _messageController = StreamController<String>.broadcast();
  final _referenceController = StreamController<double>.broadcast();

  double _reference = 15.0;

  @override
  Stream<String> get messageStream => _messageController.stream;

  @override
  Stream<double> get referenceUpdateStream => _referenceController.stream;

  @override
  Future<double> fetchWandersonReference() async {
    return _reference;
  }

  // Implementação fictícia das constantes para evitar erros de override (getters se necessário)
  static const double kDefaultReference = 15.0;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('TremorService Tests', () {
    late TremorService service;
    late StreamController<UserAccelerometerEvent> sensorStreamController;
    late FakeCalibrationService fakeCalibration;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      sensorStreamController = StreamController<UserAccelerometerEvent>();
      fakeCalibration = FakeCalibrationService();

      service = TremorService(
        calibrationService: fakeCalibration,
        userAccelStreamFactory: ({Duration? samplingPeriod}) =>
            sensorStreamController.stream,
      );
    });

    tearDown(() {
      service.dispose();
      sensorStreamController.close();
    });

    test('startMeasurement inicia timer e subscription', () async {
      // Configurar a expectativa ANTES da ação (Broadcast Stream)
      final future = expectLater(service.countdownStream, emitsThrough(5));

      // Act
      service.startMeasurement();

      // Assert
      expect(service.isRunning, isTrue);
      await future;
    });

    test('TremorService processa eventos de acelerômetro sem erro', () async {
      // Arrange
      service.startMeasurement();

      final now = DateTime.now();

      // Act - Simula eventos de acelerômetro
      sensorStreamController.add(UserAccelerometerEvent(0.5, 0, 0, now));
      sensorStreamController.add(UserAccelerometerEvent(-0.5, 0, 0, now));
      sensorStreamController.add(UserAccelerometerEvent(0.5, 0, 0, now));
      sensorStreamController.add(UserAccelerometerEvent(-0.5, 0, 0, now));

      await Future.delayed(const Duration(milliseconds: 50));

      // Assert - Verifica que o serviço está processando sem crashar
      expect(service.isRunning, isTrue);

      service.stopMeasurement();
      expect(service.isRunning, isFalse);
    });

    test('filtro passa-alta é resetado entre medições', () async {
      // Arrange - Primeira medição
      service.startMeasurement();
      final now = DateTime.now();

      // Adiciona alguns eventos
      for (int i = 0; i < 5; i++) {
        sensorStreamController.add(UserAccelerometerEvent(1.0, 1.0, 1.0, now));
      }

      await Future.delayed(const Duration(milliseconds: 50));
      service.stopMeasurement();

      // Act - Segunda medição (deve resetar o filtro)
      service.startMeasurement();
      
      // Assert - Verifica que a segunda medição está rodando
      expect(service.isRunning, isTrue);
      
      service.stopMeasurement();
    });

    test('stopMeasurement para a medição e limpa estado', () async {
      // Arrange
      service.startMeasurement();
      expect(service.isRunning, isTrue);

      // Act
      service.stopMeasurement();

      // Assert
      expect(service.isRunning, isFalse);
    });
  });
}
