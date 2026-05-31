import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:turni_webapp/core/app_update/app_version_service.dart';

void main() {
  group('AppVersionService.fetchServerVersion', () {
    test('parseia {"version":"..."} e retorna AppVersion (CA-1)', () async {
      late http.Request captured;
      final service = AppVersionService(
        client: MockClient((req) async {
          captured = req;
          return http.Response('{"version":"v0.1.0-rc.25"}', 200);
        }),
      );

      final version = await service.fetchServerVersion();

      expect(version.value, 'v0.1.0-rc.25');
      // Path de /version.json na mesma origem.
      expect(captured.url.path, '/version.json');
      // Cache-buster ?t=<epochMs> defensivo (IDR-017).
      expect(captured.url.queryParameters.containsKey('t'), isTrue);
      expect(int.tryParse(captured.url.queryParameters['t']!), isNotNull);
      // Header Cache-Control: no-cache na request.
      expect(captured.headers['Cache-Control'], 'no-cache');
    });

    test('propaga falha em status != 200 (CA-1)', () async {
      final service = AppVersionService(
        client: MockClient((_) async => http.Response('nope', 503)),
      );
      expect(
        service.fetchServerVersion(),
        throwsA(isA<http.ClientException>()),
      );
    });

    test('propaga falha em JSON inválido (CA-1)', () async {
      final service = AppVersionService(
        client: MockClient((_) async => http.Response('not-json', 200)),
      );
      expect(service.fetchServerVersion(), throwsA(isA<FormatException>()));
    });

    test('propaga falha quando falta o campo "version" (CA-1)', () async {
      final service = AppVersionService(
        client: MockClient((_) async => http.Response('{"v":"x"}', 200)),
      );
      expect(service.fetchServerVersion(), throwsA(isA<FormatException>()));
    });

    test('propaga erro de rede (CA-1)', () async {
      final service = AppVersionService(
        client: MockClient((_) async => throw http.ClientException('offline')),
      );
      expect(
        service.fetchServerVersion(),
        throwsA(isA<http.ClientException>()),
      );
    });

    test('currentVersion lê o default "dev" sem dart-define', () {
      // A suíte roda sem --dart-define=APP_VERSION.
      expect(AppVersionService().currentVersion.value, 'dev');
    });

    test('respeita o timeout configurado (CA-1)', () async {
      final service = AppVersionService(
        timeout: const Duration(milliseconds: 50),
        client: MockClient((_) async {
          await Future<void>.delayed(const Duration(seconds: 2));
          return http.Response('{"version":"v1"}', 200);
        }),
      );
      expect(service.fetchServerVersion(), throwsA(isA<Exception>()));
    });
  });
}
