// Helper de asserção de rota para integration_test (STORY-038 / IDR-011 §c).
import 'package:flutter_test/flutter_test.dart';
import 'package:turni_webapp/router.dart';

/// Caminho da rota corrente segundo o go_router (ex.: `/login`, `/welcome`).
String currentRoute() => router.routerDelegate.currentConfiguration.uri.path;

/// Navega para a lista de turnos do papel via go_router (STORY-078: a porta de
/// entrada deixou de ser o ícone ad-hoc na AppBar e virou o destino "Turnos" do
/// shell). Estes E2E de detalhe/ciclo do turno só precisam *chegar* na lista —
/// a navegação por UI (tocar o destino) é coberta por `app_shell/navegacao`.
/// Usar o router torna o setup determinístico e independente do breakpoint.
Future<void> goToTurnos(
  WidgetTester tester, {
  required bool profissional,
}) async {
  router.go(profissional ? '/profissional/turnos' : '/contratante/turnos');
  await tester.pumpAndSettle();
}

/// Abre uma rota por URL via go_router (simula deep-link / atalho de
/// notificação / bookmark — STORY-078 CA-4).
Future<void> goTo(WidgetTester tester, String location) async {
  router.go(location);
  await tester.pumpAndSettle();
}

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

/// Espera (fazendo `pump` curto até [timeout]) o go_router **sair** de [path].
/// Útil pós-login bem-sucedido, quando o destino depende do estado do funil do
/// usuário (ativo → `/`, demais → rotas de funil) — o que importa é não ficar
/// preso em `/login`. Lança via [fail] se continuar em [path] ao estourar.
Future<void> awaitRouteLeaves(
  WidgetTester tester,
  String path, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (currentRoute() == path) {
    if (DateTime.now().isAfter(deadline)) {
      fail('rota continuou em "$path" após ${timeout.inSeconds}s');
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
}
