import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:blueguava/screens/home_screen.dart';
import 'package:blueguava/services/tremor_service.dart';
import 'package:blueguava/models/measurement.dart';

// Fake TremorService to control behavior in Widget Tests
class FakeTremorService implements TremorService {
  final _scoreController = StreamController<double>.broadcast();
  final _countdownController = StreamController<int>.broadcast();
  final _isRunningController = StreamController<bool>.broadcast();
  final _messageController = StreamController<String>.broadcast();

  bool _isRunning = false;
  double _currentReference = 15.0;

  @override
  Stream<double> get scoreStream => _scoreController.stream;
  @override
  Stream<int> get countdownStream => _countdownController.stream;
  @override
  Stream<bool> get isRunningStream => _isRunningController.stream;
  @override
  Stream<String> get messageStream => _messageController.stream;
  @override
  double get currentReference => _currentReference;
  @override
  bool get isRunning => _isRunning;

  // Manual trigger for tests
  void emitScore(double score) => _scoreController.add(score);
  void emitCountdown(int count) => _countdownController.add(count);
  void emitIsRunning(bool running) {
    _isRunning = running;
    _isRunningController.add(running);
  }

  void emitMessage(String msg) => _messageController.add(msg);

  @override
  void startMeasurement() {
    emitIsRunning(true);
    emitCountdown(5);
  }

  @override
  void stopMeasurement() {
    emitIsRunning(false);
  }

  @override
  Future<void> refreshReference() async {} // simplificado

  @override
  Future<List<Measurement>> loadMeasurements() async => [];

  @override
  Future<void> clearHistory() async {}

  @override
  void dispose() {
    _scoreController.close();
    _countdownController.close();
    _isRunningController.close();
    _messageController.close();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('HomeScreen exibe título e botão iniciar', (
    WidgetTester tester,
  ) async {
    final fakeService = FakeTremorService();

    await tester.pumpWidget(
      MaterialApp(home: HomeScreen(tremorServiceOverride: fakeService)),
    );

    // Verify Title
    expect(find.text('Tremedômetro'), findsOneWidget);
    expect(find.text('Iniciar Medição'), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
  });

  testWidgets('HomeScreen inicia medição e exibe countdown', (
    WidgetTester tester,
  ) async {
    final fakeService = FakeTremorService();

    await tester.pumpWidget(
      MaterialApp(home: HomeScreen(tremorServiceOverride: fakeService)),
    );

    // Act
    await tester.tap(find.text('Iniciar Medição'));
    await tester.pump(); // Rebuild after tap

    // Assert service was called (implied by state change if linked,
    // but here FakeService updates state immediately in startMeasurement)
    // We need to wait for stream emission processing?
    // FakeService.startMeasurement adds to stream synchronously.
    // We need pump(Duration) maybe?
    await tester.pump(const Duration(milliseconds: 100));

    // Verify UI changed to Stop/Countdown
    expect(find.text('Parar'), findsOneWidget);
    expect(find.text('5'), findsOneWidget); // Countdown inicial
  });

  testWidgets('HomeScreen atualiza score e exibe resultado', (
    WidgetTester tester,
  ) async {
    // Definir tamanho de tela de dispositivo para evitar overflow
    // Usando 800x1200 lógico (dpr 1.0) para garantir espaço horizontal
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final fakeService = FakeTremorService();

    await tester.pumpWidget(
      MaterialApp(home: HomeScreen(tremorServiceOverride: fakeService)),
    );

    // Verify initial state
    expect(find.text('Toque para medir'), findsOneWidget);

    // Simulate receiving a score
    fakeService.emitScore(2.5);
    // Aguarda o microtask do stream e o rebuild
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle(); // Garantir animações

    // Verify displayed score
    expect(find.text('Toque para medir'), findsNothing);
    expect(find.text('2.5'), findsOneWidget);
    // 2.5 is "Tremor Extremo" based on labels?
    // < 2.5 is "Tremor Alto", >= 2.5 is "Extremo"
    expect(find.text('Tremor Extremo'), findsOneWidget);
  });
}
