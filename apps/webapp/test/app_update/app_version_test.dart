import 'package:flutter_test/flutter_test.dart';
import 'package:turni_webapp/core/app_update/app_version.dart';

void main() {
  group('AppVersion', () {
    test('igualdade é por valor', () {
      expect(
        const AppVersion('v1.0.0-rc.1'),
        equals(const AppVersion('v1.0.0-rc.1')),
      );
      expect(
        const AppVersion('v1.0.0-rc.1').hashCode,
        const AppVersion('v1.0.0-rc.1').hashCode,
      );
      expect(
        const AppVersion('v1.0.0-rc.1'),
        isNot(equals(const AppVersion('v1.0.0-rc.2'))),
      );
    });

    test('isDifferentFrom compara por valor', () {
      const a = AppVersion('v1.0.0-rc.1');
      expect(a.isDifferentFrom(const AppVersion('v1.0.0-rc.2')), isTrue);
      expect(a.isDifferentFrom(const AppVersion('v1.0.0-rc.1')), isFalse);
    });

    test('isDev é true para "dev" e para vazio, false para tag de release', () {
      expect(const AppVersion('dev').isDev, isTrue);
      expect(const AppVersion('').isDev, isTrue);
      expect(const AppVersion('v0.1.0-rc.24').isDev, isFalse);
    });

    test('toString retorna a tag bruta', () {
      expect(const AppVersion('v0.1.0-rc.24').toString(), 'v0.1.0-rc.24');
    });

    test('AppVersion.current lê o default "dev" sem dart-define', () {
      // A suíte roda sem --dart-define=APP_VERSION, então o default é "dev".
      expect(AppVersion.current().value, 'dev');
      expect(AppVersion.current().isDev, isTrue);
    });
  });
}
