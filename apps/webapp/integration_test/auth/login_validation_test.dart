// integration_test — STORY-038 CA-5 (validação client-side) + CA-6 (credencial inválida).
// Migra os cenários "submeter vazio" e "credencial inválida" de rbac-login.spec.ts.
//
// CA-5 é puramente client-side (validators do Form) — não toca a API.
// CA-6 bate na API real: credencial inexistente → erro → permanece em /login.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../helpers/login_helper.dart';
import '../helpers/pump_app.dart';
import '../helpers/route_helper.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'submeter o formulário vazio exibe erro de campo obrigatório (CA-5)',
    (tester) async {
      await pumpApp(tester);
      assertOnRoute(tester, '/login');

      // Submete sem preencher — os validators do Form disparam antes de qualquer
      // chamada de rede; nenhuma API é tocada neste cenário.
      await tester.tap(find.byKey(const ValueKey('login:submit')));
      await tester.pumpAndSettle();

      expect(find.text('Este campo é obrigatório.'), findsOneWidget);
      // Continua na tela de login (não navegou).
      assertOnRoute(tester, '/login');
    },
  );

  testWidgets(
    'credencial inválida não autentica — permanece em /login (CA-6)',
    (tester) async {
      await pumpApp(tester);

      await loginAs(
        tester,
        email: 'nao-existe@turni.local',
        password: 'senha-errada',
      );

      // A API responde erro; o app exibe banner de erro e não navega.
      await pumpUntilFound(
        tester,
        find.byKey(const ValueKey('login:error-banner')),
      );
      assertOnRoute(tester, '/login');
    },
  );
}
