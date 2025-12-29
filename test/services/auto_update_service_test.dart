import 'dart:convert';

import 'package:blueguava/services/auto_update_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auto_update_service_test.mocks.dart';

@GenerateMocks([http.Client])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppVersion', () {
    test('isNewerThan deve retornar true para versão maior', () {
      final v1 = AppVersion('1.0.0', 1);
      final v2 = AppVersion('1.0.1', 1);

      expect(v2.isNewerThan(v1), true);
    });

    test('isNewerThan deve retornar true para build number maior', () {
      final v1 = AppVersion('1.0.0', 1);
      final v2 = AppVersion('1.0.0', 2);

      expect(v2.isNewerThan(v1), true);
    });

    test('isNewerThan deve retornar false para versão menor', () {
      final v1 = AppVersion('1.1.0', 1);
      final v2 = AppVersion('1.0.0', 1);

      expect(v2.isNewerThan(v1), false);
    });

    test('isNewerThan deve retornar false para mesma versão', () {
      final v1 = AppVersion('1.0.0', 1);
      final v2 = AppVersion('1.0.0', 1);

      expect(v2.isNewerThan(v1), false);
    });

    test('toString deve formatar versão corretamente', () {
      final version = AppVersion('1.2.3', 42);

      expect(version.toString(), '1.2.3+42');
    });

    test('isNewerThan deve lidar com versões de 2 partes', () {
      final v1 = AppVersion('1.0', 1);
      final v2 = AppVersion('1.1', 1);

      expect(v2.isNewerThan(v1), true);
      expect(v1.isNewerThan(v2), false);
    });

    test('isNewerThan deve lidar com versões de 1 parte', () {
      final v1 = AppVersion('1', 1);
      final v2 = AppVersion('2', 1);

      expect(v2.isNewerThan(v1), true);
      expect(v1.isNewerThan(v2), false);
    });

    test('isNewerThan deve normalizar versões com diferentes números de partes', () {
      final v1 = AppVersion('1.0', 1);
      final v2 = AppVersion('1.0.0', 1);

      expect(v2.isNewerThan(v1), false);
      expect(v1.isNewerThan(v2), false);
    });

    test('isNewerThan deve tratar partes não-numéricas como 0', () {
      final v1 = AppVersion('1.0.0', 1);
      final v2 = AppVersion('1.0.x', 1);

      expect(v1.isNewerThan(v2), false);
      expect(v2.isNewerThan(v1), false);
    });

    test('isNewerThan deve comparar corretamente versões complexas', () {
      final v1 = AppVersion('2.1', 5);
      final v2 = AppVersion('2.1.0', 3);

      expect(v1.isNewerThan(v2), true);
    });
  });

  group('AutoUpdateService', () {
    late MockClient mockClient;
    late AutoUpdateService service;

    setUp(() async {
      mockClient = MockClient();
      SharedPreferences.setMockInitialValues({});
      service = AutoUpdateService(
        httpClient: mockClient,
        currentVersion: AppVersion('1.0.0', 1),
      );
    });

    tearDown(() {
      service.dispose();
    });

    test('checkForUpdate deve retornar null quando não há nova versão', () async {
      final responseBody = json.encode({
        'tag_name': 'v1.0.0+1',
        'html_url': 'https://github.com/lucasliet/tremedometro/releases/tag/v1.0.0+1',
        'body': 'Release notes',
        'assets': [],
      });

      when(mockClient.get(any)).thenAnswer(
        (_) async => http.Response(responseBody, 200),
      );

      final result = await service.checkForUpdate();

      expect(result, null);
      verify(mockClient.get(any)).called(1);
    });

    test('checkForUpdate deve retornar ReleaseInfo quando há nova versão', () async {
      final responseBody = json.encode({
        'tag_name': 'v2.0.0+1',
        'html_url': 'https://github.com/lucasliet/tremedometro/releases/tag/v2.0.0+1',
        'body': 'Nova versão com melhorias',
        'assets': [
          {
            'name': 'app-release.apk',
            'browser_download_url': 'https://github.com/lucasliet/tremedometro/releases/download/v2.0.0+1/app-release.apk',
          },
        ],
      });

      when(mockClient.get(any)).thenAnswer(
        (_) async => http.Response(responseBody, 200),
      );

      final result = await service.checkForUpdate();

      expect(result, isNotNull);
      expect(result!.version.version, '2.0.0');
      expect(result.version.buildNumber, 1);
      expect(result.downloadUrl, contains('.apk'));
      expect(result.changelog, 'Nova versão com melhorias');
      verify(mockClient.get(any)).called(1);
    });

    test('checkForUpdate deve usar releaseUrl se não houver APK', () async {
      final responseBody = json.encode({
        'tag_name': 'v2.0.0+1',
        'html_url': 'https://github.com/lucasliet/tremedometro/releases/tag/v2.0.0+1',
        'body': 'Release sem APK',
        'assets': [],
      });

      when(mockClient.get(any)).thenAnswer(
        (_) async => http.Response(responseBody, 200),
      );

      final result = await service.checkForUpdate();

      expect(result, isNotNull);
      expect(result!.downloadUrl, equals(result.releaseUrl));
      verify(mockClient.get(any)).called(1);
    });

    test('checkForUpdate deve retornar null em caso de erro HTTP', () async {
      when(mockClient.get(any)).thenAnswer(
        (_) async => http.Response('Not Found', 404),
      );

      final result = await service.checkForUpdate();

      expect(result, null);
      verify(mockClient.get(any)).called(1);
    });

    test('checkForUpdate deve retornar null em caso de exceção', () async {
      when(mockClient.get(any)).thenThrow(Exception('Network error'));

      final result = await service.checkForUpdate();

      expect(result, null);
      verify(mockClient.get(any)).called(1);
    });

    test('checkForUpdate deve respeitar intervalo de verificação', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'last_update_check',
        DateTime.now().subtract(const Duration(hours: 1)).toIso8601String(),
      );

      final result = await service.checkForUpdate();

      expect(result, null);
      verifyNever(mockClient.get(any));
    });

    test('checkForUpdate deve verificar após intervalo expirado', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'last_update_check',
        DateTime.now().subtract(const Duration(hours: 25)).toIso8601String(),
      );

      final responseBody = json.encode({
        'tag_name': 'v2.0.0+1',
        'html_url': 'https://github.com/lucasliet/tremedometro/releases/tag/v2.0.0+1',
        'body': 'Nova versão',
        'assets': [],
      });

      when(mockClient.get(any)).thenAnswer(
        (_) async => http.Response(responseBody, 200),
      );

      final result = await service.checkForUpdate();

      expect(result, isNotNull);
      verify(mockClient.get(any)).called(1);
    });

    test('checkForUpdate deve parsear tag sem prefixo v', () async {
      final responseBody = json.encode({
        'tag_name': '2.0.0+1',
        'html_url': 'https://github.com/lucasliet/tremedometro/releases/tag/2.0.0+1',
        'body': 'Release',
        'assets': [],
      });

      when(mockClient.get(any)).thenAnswer(
        (_) async => http.Response(responseBody, 200),
      );

      final result = await service.checkForUpdate();

      expect(result, isNotNull);
      expect(result!.version.version, '2.0.0');
      verify(mockClient.get(any)).called(1);
    });

    test('checkForUpdate deve usar buildNumber 1 como padrão', () async {
      final responseBody = json.encode({
        'tag_name': 'v2.0.0',
        'html_url': 'https://github.com/lucasliet/tremedometro/releases/tag/v2.0.0',
        'body': 'Release',
        'assets': [],
      });

      when(mockClient.get(any)).thenAnswer(
        (_) async => http.Response(responseBody, 200),
      );

      final result = await service.checkForUpdate();

      expect(result, isNotNull);
      expect(result!.version.buildNumber, 1);
      verify(mockClient.get(any)).called(1);
    });

    test('checkForUpdate deve encontrar APK entre múltiplos assets', () async {
      final responseBody = json.encode({
        'tag_name': 'v2.0.0+1',
        'html_url': 'https://github.com/lucasliet/tremedometro/releases/tag/v2.0.0+1',
        'body': 'Release',
        'assets': [
          {
            'name': 'checksums.txt',
            'browser_download_url': 'https://example.com/checksums.txt',
          },
          {
            'name': 'app-release.apk',
            'browser_download_url': 'https://example.com/app-release.apk',
          },
          {
            'name': 'source.zip',
            'browser_download_url': 'https://example.com/source.zip',
          },
        ],
      });

      when(mockClient.get(any)).thenAnswer(
        (_) async => http.Response(responseBody, 200),
      );

      final result = await service.checkForUpdate();

      expect(result, isNotNull);
      expect(result!.downloadUrl, contains('app-release.apk'));
      verify(mockClient.get(any)).called(1);
    });
  });
}
