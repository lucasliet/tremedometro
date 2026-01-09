import 'package:blueguava/services/auto_update_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auto_update_service_test.mocks.dart';

@GenerateMocks([Dio])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AutoUpdateService', () {
    late MockDio mockDio;
    late AutoUpdateService service;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      mockDio = MockDio();
      service = AutoUpdateService(dio: mockDio);
    });

    tearDown(() {
      service.dispose();
    });

    group('isWanderboy flag', () {
      test('Deve ser false por padrão', () {
        // Given & When
        final isWanderboy = AutoUpdateService.isWanderboy;

        // Then
        expect(isWanderboy, isFalse);
      });
    });

    group('AppUpdateInfo', () {
      test('Deve criar instância com todos os campos', () {
        // Given
        final now = DateTime.now();

        // When
        final info = AppUpdateInfo(
          version: '1.2.3',
          changelog: 'New features',
          downloadUrl: 'https://example.com/app.apk',
          publishedAt: now,
        );

        // Then
        expect(info.version, equals('1.2.3'));
        expect(info.changelog, equals('New features'));
        expect(info.downloadUrl, equals('https://example.com/app.apk'));
        expect(info.publishedAt, equals(now));
      });
    });

    group('UpdateStatus', () {
      test('Deve ter todos os status esperados', () {
        // Given & When & Then
        expect(UpdateStatus.values, contains(UpdateStatus.idle));
        expect(UpdateStatus.values, contains(UpdateStatus.checking));
        expect(UpdateStatus.values, contains(UpdateStatus.available));
        expect(UpdateStatus.values, contains(UpdateStatus.downloading));
        expect(UpdateStatus.values, contains(UpdateStatus.installing));
        expect(UpdateStatus.values, contains(UpdateStatus.error));
        expect(UpdateStatus.values, contains(UpdateStatus.upToDate));
      });
    });

    group('checkForUpdate', () {
      test('Deve retornar null quando check foi feito recentemente', () async {
        // Given
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(
          'last_update_check',
          DateTime.now().millisecondsSinceEpoch,
        );

        // When
        final result = await service.checkForUpdate();

        // Then
        expect(result, isNull);
        verifyNever(mockDio.get(any));
      });

      test('Deve forçar verificação quando force=true', () async {
        // Given
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(
          'last_update_check',
          DateTime.now().millisecondsSinceEpoch,
        );

        when(mockDio.get(any, options: anyNamed('options'))).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(),
            statusCode: 200,
            data: {
              'tag_name': 'v1.0.0',
              'body': 'changelog',
              'published_at': '2024-01-01T00:00:00Z',
              'assets': [],
            },
          ),
        );

        // When
        await service.checkForUpdate(force: true);

        // Then
        verify(mockDio.get(any, options: anyNamed('options'))).called(1);
      });

      test('Deve retornar null quando não há APK na release', () async {
        // Given
        when(mockDio.get(any, options: anyNamed('options'))).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(),
            statusCode: 200,
            data: {
              'tag_name': 'v2.0.0',
              'body': 'New version',
              'published_at': '2024-01-01T00:00:00Z',
              'assets': [],
            },
          ),
        );

        // When
        final result = await service.checkForUpdate(force: true);

        // Then
        expect(result, isNull);
      });

      test('Deve retornar null quando API retorna erro', () async {
        // Given
        when(mockDio.get(any, options: anyNamed('options'))).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(),
            statusCode: 500,
            data: null,
          ),
        );

        // When
        final result = await service.checkForUpdate(force: true);

        // Then
        expect(result, isNull);
      });

      test('Deve retornar null quando ocorre exceção', () async {
        // Given
        when(
          mockDio.get(any, options: anyNamed('options')),
        ).thenThrow(DioException(requestOptions: RequestOptions()));

        // When
        final result = await service.checkForUpdate(force: true);

        // Then
        expect(result, isNull);
        expect(service.status, equals(UpdateStatus.error));
      });
    });

    group('startUpdate', () {
      test('Deve não fazer nada se updateInfo for null', () {
        // Given - service sem updateInfo

        // When
        service.startUpdate();

        // Then
        expect(service.status, isNot(equals(UpdateStatus.downloading)));
      });
    });

    group('dispose', () {
      test('Deve poder ser chamado sem erros', () {
        // Given
        final serviceToDispose = AutoUpdateService(dio: mockDio);

        // When & Then
        expect(() => serviceToDispose.dispose(), returnsNormally);
      });
    });
  });
}
