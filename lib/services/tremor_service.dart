import 'dart:async';
import 'dart:math';

import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/measurement.dart';

const _kMeasurementsKey = 'measurements';
const _kMeasurementDuration = Duration(seconds: 5);
const _kSampleInterval = Duration(milliseconds: 20);

const _kMaxExpectedMagnitude = 15.0;

class TremorService {
  StreamSubscription<AccelerometerEvent>? _subscription;
  Timer? _timer;

  final List<double> _magnitudes = [];

  double _lastX = 0;
  double _lastY = 0;
  double _lastZ = 0;

  final _alpha = 0.8;

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
    _isRunningController.add(true);
    _magnitudes.clear();
    _lastX = 0;
    _lastY = 0;
    _lastZ = 0;

    int remainingSeconds = _kMeasurementDuration.inSeconds;
    _countdownController.add(remainingSeconds);

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      remainingSeconds--;
      _countdownController.add(remainingSeconds);

      if (remainingSeconds <= 0) {
        _finishMeasurement();
      }
    });

    _subscription = accelerometerEventStream(
      samplingPeriod: _kSampleInterval,
    ).listen(_processAccelerometerEvent);
  }

  void _processAccelerometerEvent(AccelerometerEvent event) {
    _lastX = _alpha * _lastX + (1 - _alpha) * event.x;
    _lastY = _alpha * _lastY + (1 - _alpha) * event.y;
    _lastZ = _alpha * _lastZ + (1 - _alpha) * event.z;

    final highPassX = event.x - _lastX;
    final highPassY = event.y - _lastY;
    final highPassZ = event.z - _lastZ;

    final magnitude = sqrt(
      highPassX * highPassX + highPassY * highPassY + highPassZ * highPassZ,
    );

    _magnitudes.add(magnitude);
  }

  void _finishMeasurement() {
    _timer?.cancel();
    _subscription?.cancel();
    _isRunning = false;
    _isRunningController.add(false);

    if (_magnitudes.isEmpty) {
      _scoreController.add(0);
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
