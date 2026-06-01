// Helper de boot do WebApp para integration_test (STORY-038 / IDR-011 §c).
import 'package:flutter_test/flutter_test.dart';
import 'package:turni_webapp/features/auth/auth_service.dart';
import 'package:turni_webapp/main.dart';
import 'package:turni_webapp/router.dart';

/// Sobe o WebApp completo ([TurniApp]) no [tester] e espera o boot estabilizar.
///
/// Reseta a sessão do [AuthService] (singleton) antes de montar, para que cada
/// cenário comece deslogado de forma determinística mesmo quando a suíte roda
/// vários testes no mesmo processo do `flutter drive`. Se [initialRoute] for
/// informado, navega até ela via go_router antes de devolver o controle.
///
/// Exemplo:
/// ```dart
/// await pumpApp(tester);                        // sem sessão → cai em /login
/// await pumpApp(tester, initialRoute: '/welcome');
/// ```
Future<void> pumpApp(WidgetTester tester, {String? initialRoute}) async {
  // Estado limpo entre cenários — o AuthService e o `router` são singletons globais
  // que sobrevivem entre testes do mesmo processo (flutter drive roda tudo num
  // browser só). Reseta a sessão e reposiciona a rota em `/` para que cada cenário
  // comece de forma determinística (sem sessão → o guard manda para /login).
  AuthService().debugSetSession(null);
  router.go('/');

  await tester.pumpWidget(const TurniApp());
  await tester.pumpAndSettle();

  if (initialRoute != null) {
    router.go(initialRoute);
    await tester.pumpAndSettle();
  }
}

/// Faz `pump` curto repetido até [finder] casar (ou estourar [timeout]).
///
/// Necessário quando a tela está com uma animação contínua (ex.: o
/// `CircularProgressIndicator` do botão durante o login em voo), caso em que
/// `pumpAndSettle()` nunca quiesce. Use para esperar um banner/resultado:
/// ```dart
/// await loginAsAdmin(tester);
/// await pumpUntilFound(tester, find.byKey(const ValueKey('login:admin-banner')));
/// ```
Future<void> pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (finder.evaluate().isEmpty) {
    if (DateTime.now().isAfter(deadline)) {
      fail('widget não apareceu em ${timeout.inSeconds}s: $finder');
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
}
