// integration_test — STORY-038 CA-4 (migra cenário CA-5 da STORY-016/IDR-006).
// Cobre: estrutura da tela de login (campos e-mail/senha, link de recuperação,
// botão Entrar). integration_test puro — não toca a API.
//
// Rodar (Web): chromedriver --port=4444 & flutter drive \
//   --driver=test_driver/integration_test.dart \
//   --target=integration_test/auth/login_structure_test.dart \
//   -d web-server --browser-name=chrome --headless
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../helpers/pump_app.dart';
import '../helpers/route_helper.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'exibe campos e-mail, senha, link de recuperação e botão Entrar (CA-4)',
    (tester) async {
      await pumpApp(tester);

      // Sem sessão, o root `/` é redirecionado para /login pelo funnel guard.
      assertOnRoute(tester, '/login');

      expect(find.byKey(const ValueKey('login:email')), findsOneWidget);
      expect(find.byKey(const ValueKey('login:password')), findsOneWidget);
      expect(find.byKey(const ValueKey('login:submit')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('login:forgot-password')),
        findsOneWidget,
      );
      expect(find.text('Esqueci minha senha'), findsOneWidget);
    },
  );
}
