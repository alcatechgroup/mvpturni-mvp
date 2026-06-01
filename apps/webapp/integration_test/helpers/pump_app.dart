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
  // Estado limpo entre cenários — evita vazamento de sessão de um teste para o outro.
  AuthService().debugSetSession(null);

  await tester.pumpWidget(const TurniApp());
  await tester.pumpAndSettle();

  if (initialRoute != null) {
    router.go(initialRoute);
    await tester.pumpAndSettle();
  }
}
