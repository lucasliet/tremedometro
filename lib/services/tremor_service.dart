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
  static const double kSensorError = -1;

  final CalibrationService _calibrationService;

  StreamSubscription<dynamic>? _subscription;
  Timer? _timer;

  final List<double> _magnitudes = [];
  bool _hasReceivedData = false;
  double _currentReference = CalibrationService.kDefaultReference;

  final _scoreController =
      StreamController<double>.broadcast();
  final _countdownController = StreamController<int>.broadcast();
  final _isRunningController = StreamController<bool>.broadcast();

  StreamSubscription<double>? _referenceUpdateSubscription;

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

  // Factory injetável para stream de acelerômetro do usuário
  final Stream<UserAccelerometerEvent> Function({Duration samplingPeriod})
  _userAccelStreamFactory;

  TremorService({
    CalibrationService? calibrationService,
    Stream<UserAccelerometerEvent> Function({Duration? samplingPeriod})?
    userAccelStreamFactory,
  }) : _calibrationService = calibrationService ?? CalibrationService(),
       _userAccelStreamFactory =
           userAccelStreamFactory ??
           (({Duration? samplingPeriod}) => userAccelerometerEventStream(
             samplingPeriod: samplingPeriod ?? _kSampleInterval,
           )) {
    refreshReference();
  }

  Future<void> refreshReference() async {
    _currentReference = await _calibrationService.fetchWandersonReference();
    debugPrint(
      'Referência atualizada: $_currentReference (Wanderboy Mode: $isWanderboy)',
    );

    await _referenceUpdateSubscription?.cancel();
    _referenceUpdateSubscription = _calibrationService.referenceUpdateStream.listen((newRef) {
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
    _webErrorCount = 0;

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
        _subscription =
            accelerometerEventStream(samplingPeriod: _kSampleInterval).listen(
              _processWebAccelerometerEvent,
              onError: (e) {
                debugPrint('Erro no acelerômetro Web: $e');
                _webErrorCount++;
                if (_webErrorCount >= _kMaxWebErrors) {
                  debugPrint(
                    'Limite de erros atingido ($_kMaxWebErrors), finalizando medição',
                  );
                  _finishMeasurement();
                }
              },
              cancelOnError: false,
            );
      } else {
        _subscription =
            _userAccelStreamFactory(samplingPeriod: _kSampleInterval).listen(
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

  // Calibração empírica web vs mobile
  // PWA retorna valores ~7 pontos acima do mobile devido a limitações
  // da API web (sem acesso a giroscópio para fusão de sensores)
  static const double _kWebCalibrationOffset = 7.0;

  // Contador de erros web para tratamento resiliente
  int _webErrorCount = 0;
  static const int _kMaxWebErrors = 5;

  void _processWebAccelerometerEvent(AccelerometerEvent event) {
    _hasReceivedData = true;

    final magnitude = sqrt(
      event.x * event.x + event.y * event.y + event.z * event.z,
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
        _scoreController.add(kSensorError);
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
    double guavaPrime = avgMagnitude * 1000;

    // Aplica calibração empírica para web (não-iOS)
    if (kIsWeb) {
      guavaPrime = (guavaPrime - _kWebCalibrationOffset).clamp(0, double.infinity);
      debugPrint('WEB_CALIBRATION: Raw=$avgMagnitude, GuavaPrime=$guavaPrime (offset: -$_kWebCalibrationOffset)');
    }

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
    _referenceUpdateSubscription?.cancel();
    _scoreController.close();
    _countdownController.close();
    _isRunningController.close();
  }
}
