import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:blueguava/services/calibration_service.dart';

void main() {
  group('CalibrationService Tests', () {
    late CalibrationService service;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test(
      'fetchWandersonReference usa valor padrão se API falhar e cache vazio',
      () async {
        // Arrange
        final mockClient = MockClient((request) async {
          return http.Response('Server Error', 500);
        });
        service = CalibrationService(client: mockClient);

        // Act
        final result = await service.fetchWandersonReference();

        // Assert
        expect(result, equals(CalibrationService.kDefaultReference)); // 15.0
      },
    );

    test(
      'fetchWandersonReference retorna valor da API se sucesso (200)',
      () async {
        // Arrange
        final mockClient = MockClient((request) async {
          return http.Response(jsonEncode({'found': '25.5'}), 200);
        });
        service = CalibrationService(client: mockClient);

        // Act
        final result = await service.fetchWandersonReference();

        // Assert
        expect(result, equals(25.5));
      },
    );

    test(
      'fetchWandersonReference retorna cache quando disponível',
      () async {
        // Arrange
        SharedPreferences.setMockInitialValues({
          'blueguava_v1_ref_cache': 42.0,
        });

        final mockClient = MockClient((request) async {
          return http.Response(jsonEncode({'found': '42.0'}), 200);
        });
        service = CalibrationService(client: mockClient);

        // Act
        final result = await service.fetchWandersonReference();

        // Assert
        expect(result, equals(42.0));
      },
    );
  });
}
