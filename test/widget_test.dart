// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:blueguava/main.dart';

void main() {
  testWidgets('BlueGuava smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const BlueGuavaApp());

    // Verify that the title is present
    expect(find.text('BlueGuava'), findsOneWidget);
    expect(find.text('Medidor de Tremor'), findsOneWidget);

    // Verify that the start button is present
    expect(find.text('Iniciar Medição'), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);

    // Verify history empty state
    expect(find.text('Nenhuma medição ainda'), findsOneWidget);
  });
}
