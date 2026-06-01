// Helper de asserção de rota para integration_test (STORY-038 / IDR-011 §c).
import 'package:flutter_test/flutter_test.dart';
import 'package:turni_webapp/router.dart';

/// Caminho da rota corrente segundo o go_router (ex.: `/login`, `/welcome`).
String currentRoute() => router.routerDelegate.currentConfiguration.uri.path;

/// Asseria que a rota corrente do go_router é exatamente [path].
///
/// Exemplo:
/// ```dart
/// await pumpApp(tester);
/// assertOnRoute(tester, '/login');
/// ```
void assertOnRoute(WidgetTester tester, String path) {
  expect(
    currentRoute(),
    path,
    reason: 'esperava estar em "$path", mas está em "${currentRoute()}"',
  );
}

/// Espera (fazendo `pump` curto até [timeout]) o go_router transicionar para
/// [path]. Útil quando há um redirect assíncrono (ex.: pós-login bate na API e
/// só então o guard reposiciona). Lança via [fail] se estourar o tempo.
///
/// Exemplo:
/// ```dart
/// await loginAsProfissional(tester);
/// await awaitRouteChange(tester, '/');
/// ```
Future<void> awaitRouteChange(
  WidgetTester tester,
  String path, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (currentRoute() != path) {
    if (DateTime.now().isAfter(deadline)) {
      fail(
        'rota não mudou para "$path" em ${timeout.inSeconds}s '
        '(atual: "${currentRoute()}")',
      );
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
}
