import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/measurement.dart';

const _kMeasurementsKey = 'measurements';
const _kMeasurementDuration = Duration(seconds: 5);
const _kSampleInterval = Duration(milliseconds: 20);

const _kMaxExpectedMagnitude = 15.0;

class TremorService {
  StreamSubscription<UserAccelerometerEvent>? _subscription;
  Timer? _timer;

  final List<double> _magnitudes = [];
  bool _hasReceivedData = false;

  final _scoreController = StreamController<int>.broadcast();
  final _countdownController = StreamController<int>.broadcast();
  final _isRunningController = StreamController<bool>.broadcast();

  Stream<int> get scoreStream => _scoreController.stream;
  Stream<int> get countdownStream => _countdownController.stream;
  Stream<bool> get isRunningStream => _isRunningController.stream;

  bool _isRunning = false;
  bool get isRunning => _isRunning;

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
      // Usamos userAccelerometerEventStream que já remove a gravidade (filtro de hardware/fusão)
      // É mais preciso e performático que o filtro manual anterior.
      _subscription =
          userAccelerometerEventStream(samplingPeriod: _kSampleInterval).listen(
            _processAccelerometerEvent,
            onError: (e) {
              debugPrint('Erro no acelerômetro: $e');
              _finishMeasurement(); // Encerra se houver erro no stream
            },
            cancelOnError: true,
          );
    } catch (e) {
      debugPrint('Erro ao iniciar stream: $e');
      _finishMeasurement();
    }
  }

  void _processAccelerometerEvent(UserAccelerometerEvent event) {
    _hasReceivedData = true;

    // Como já é UserAccelerometer (sem gravidade), calculamos a magnitude direta
    final magnitude = sqrt(
      event.x * event.x + event.y * event.y + event.z * event.z,
    );

    _magnitudes.add(magnitude);
  }

  void _finishMeasurement() {
    _timer?.cancel();
    _subscription?.cancel();
    _isRunning = false;
    _isRunningController.add(false);

    if (_magnitudes.isEmpty) {
      // Se não recebeu dados, retorna -1 para indicar erro de sensor
      if (!_hasReceivedData) {
        _scoreController.add(-1);
      } else {
        _scoreController.add(0);
      }
      return;
    }

    final avgMagnitude =
        _magnitudes.reduce((a, b) => a + b) / _magnitudes.length;

    int score = ((avgMagnitude / _kMaxExpectedMagnitude) * 1000).round();
    score = score.clamp(0, 1000);

    _scoreController.add(score);
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

  Future<void> saveMeasurement(int score) async {
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
