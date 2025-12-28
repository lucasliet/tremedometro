import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/measurement.dart';
import 'calibration_service.dart';

const _kMeasurementsKey = 'measurements';
const _kMeasurementDuration = Duration(seconds: 5);
const _kSampleInterval = Duration(milliseconds: 20);

class TremorService {
  final CalibrationService _calibrationService = CalibrationService();
  StreamSubscription<dynamic>? _subscription;
  Timer? _timer;

  final List<double> _magnitudes = [];
  bool _hasReceivedData = false;
  double _currentReference = CalibrationService.kDefaultReference;

  final _scoreController =
      StreamController<double>.broadcast(); // Agora double para BlueGuava
  final _countdownController = StreamController<int>.broadcast();
  final _isRunningController = StreamController<bool>.broadcast();

  Stream<double> get scoreStream => _scoreController.stream;
  Stream<int> get countdownStream => _countdownController.stream;
  Stream<bool> get isRunningStream => _isRunningController.stream;
  double get currentReference => _currentReference;
  Stream<String> get messageStream => _calibrationService.messageStream;

  bool _isRunning = false;
  bool get isRunning => _isRunning;

  // Flag estática para admin, definida em tempo de compilação
  static const bool isWanderboy = bool.fromEnvironment(
    'WANDERBOY',
    defaultValue: false,
  );

  TremorService() {
    refreshReference();
  }

  Future<void> refreshReference() async {
    _currentReference = await _calibrationService.fetchWandersonReference();
    debugPrint(
      'Referência atualizada: $_currentReference (Wanderboy Mode: $isWanderboy)',
    );

    // Ouve atualizações futuras que podem vir do background fetch
    _calibrationService.referenceUpdateStream.listen((newRef) {
      debugPrint(
        'TremorService: Recebido update silencioso de referência: $newRef',
      );
      _currentReference = newRef;
    });
  }

  void startMeasurement() {
    if (_isRunning) return;

    _isRunning = true;
    _hasReceivedData = false;
    _isRunningController.add(true);
    _magnitudes.clear();

    int remainingSeconds = _kMeasurementDuration.inSeconds;
    _countdownController.add(remainingSeconds);

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      remainingSeconds--;
      _countdownController.add(remainingSeconds);

      if (remainingSeconds <= 0) {
        _finishMeasurement();
      }
    });

    try {
      if (kIsWeb) {
        // [WEB FIXED] UserAccelerometer é instável na web.
        // Usamos Acelerômetro bruto + Filtro Passa-Alta manual.
        _subscription =
            accelerometerEventStream(samplingPeriod: _kSampleInterval).listen(
              _processWebAccelerometerEvent,
              onError: (e) {
                debugPrint('Erro no acelerômetro Web: $e');
                _finishMeasurement();
              },
              cancelOnError: true,
            );
      } else {
        // [NATIVE] UserAccelerometer funciona bem (hardware/OS driven)
        _subscription =
            userAccelerometerEventStream(
              samplingPeriod: _kSampleInterval,
            ).listen(
              _processAccelerometerEvent,
              onError: (e) {
                debugPrint('Erro no acelerômetro: $e');
                _finishMeasurement();
              },
              cancelOnError: true,
            );
      }
    } catch (e) {
      debugPrint('Erro ao iniciar stream: $e');
      _finishMeasurement();
    }
  }

  // Filtro Passa-Alta para remover gravidade (Alpha ~0.8 para 20ms sample)
  // gravity = alpha * gravity + (1 - alpha) * event
  // linear_accel = event - gravity
  double _gravityX = 0;
  double _gravityY = 0;
  double _gravityZ = 0;
  static const double _alpha = 0.8;

  void _processWebAccelerometerEvent(AccelerometerEvent event) {
    _hasReceivedData = true;

    // Isola a gravidade
    _gravityX = _alpha * _gravityX + (1 - _alpha) * event.x;
    _gravityY = _alpha * _gravityY + (1 - _alpha) * event.y;
    _gravityZ = _alpha * _gravityZ + (1 - _alpha) * event.z;

    // Remove a gravidade para obter a aceleração linear (movimento do usuário)
    final linearX = event.x - _gravityX;
    final linearY = event.y - _gravityY;
    final linearZ = event.z - _gravityZ;

    final magnitude = sqrt(
      linearX * linearX + linearY * linearY + linearZ * linearZ,
    );

    _magnitudes.add(magnitude);
  }

  void _processAccelerometerEvent(UserAccelerometerEvent event) {
    _hasReceivedData = true;

    // Cálculo da magnitude instântanea (m/s²)
    final magnitude = sqrt(
      event.x * event.x + event.y * event.y + event.z * event.z,
    );

    _magnitudes.add(magnitude);
  }

  Future<void> _finishMeasurement() async {
    _timer?.cancel();
    _subscription?.cancel();
    _isRunning = false;
    _isRunningController.add(false);

    if (_magnitudes.isEmpty) {
      if (!_hasReceivedData) {
        _scoreController.add(-1);
      } else {
        _scoreController.add(0);
      }
      return;
    }

    // 1. Calcula GuavaPrime (Média da magnitude bruta * 1000 para escala legível)
    // Ex: 0.2 m/s² * 1000 = 200 GuavaPrime
    // Ex: 15.0 m/s² * 1000 = 15000 GuavaPrime
    final avgMagnitude =
        _magnitudes.reduce((a, b) => a + b) / _magnitudes.length;
    final double guavaPrime = avgMagnitude * 1000;

    // 2. Lógica Admin (Wanderboy)
    if (isWanderboy) {
      await _handleWanderboyLogic(guavaPrime);
    }

    // 3. Calcula e exibe BlueGuava imediato
    // Mas ATENÇÃO: saveMeasurement agora salvará o GuavaPrime

    // O controller ainda emite o BlueGuava para o "Live View" (Gauge)
    final double blueGuavaScore = guavaPrime / _currentReference;
    _scoreController.add(blueGuavaScore);

    // Salva o GuavaPrime cru no histórico
    saveMeasurement(guavaPrime);
  }

  Future<void> _handleWanderboyLogic(double newGuavaPrime) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> last4 = prefs.getStringList('wanderson_last_4') ?? [];

    last4.add(newGuavaPrime.toString());
    if (last4.length > 4) {
      last4 = last4.sublist(last4.length - 4);
    }

    await prefs.setStringList('wanderson_last_4', last4);

    // Calcula nova referência (média das 4 últimas)
    double sum = 0;
    for (var s in last4) {
      sum += double.parse(s);
    }
    double newReference = sum / last4.length;

    // Atualiza localmente e na API
    _currentReference = newReference;
    await _calibrationService.updateWandersonReference(newReference);
  }

  void stopMeasurement() {
    _timer?.cancel();
    _subscription?.cancel();
    _isRunning = false;
    _isRunningController.add(false);
    _magnitudes.clear();
  }

  Future<List<Measurement>> loadMeasurements() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_kMeasurementsKey);
    if (jsonString == null || jsonString.isEmpty) {
      return [];
    }
    return Measurement.decodeList(jsonString);
  }

  Future<void> saveMeasurement(double score) async {
    final prefs = await SharedPreferences.getInstance();
    final measurements = await loadMeasurements();

    final newMeasurement = Measurement(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      score: score,
      timestamp: DateTime.now(),
    );

    measurements.insert(0, newMeasurement);

    if (measurements.length > 50) {
      measurements.removeRange(50, measurements.length);
    }

    await prefs.setString(
      _kMeasurementsKey,
      Measurement.encodeList(measurements),
    );
  }

  Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kMeasurementsKey);
  }

  void dispose() {
    _timer?.cancel();
    _subscription?.cancel();
    _scoreController.close();
    _countdownController.close();
    _isRunningController.close();
  }
}
