// integration_test — STORY-043 CA-6 (migra as validações de pre-cadastro-contratante.spec.ts).
//
// Cobre os cenários DETERMINÍSTICOS do pré-cadastro de contratante: carga da tela
// pública, validação client-side de campos obrigatórios e navegação. Roda same-origin
// sob o harness. O happy-path com upload de foto fica fora (IDR-009/STORY-039 — Patrol);
// o `test.fixme` correspondente em Playwright permanece.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../helpers/pump_app.dart';
import '../helpers/route_helper.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('pré-cadastro de contratante (CA-6)', () {
    testWidgets('tela pública carrega sem auth', (tester) async {
      await pumpApp(tester, initialRoute: '/cadastro/contratante');

      assertOnRoute(tester, '/cadastro/contratante');
      expect(
        find.byKey(const Key('screen-cadastro-contratante')),
        findsOneWidget,
      );
      expect(find.text('Criar conta de estabelecimento'), findsOneWidget);
    });

    testWidgets('submeter vazio exibe erros de campo obrigatório', (
      tester,
    ) async {
      await pumpApp(tester, initialRoute: '/cadastro/contratante');

      // O botão fica no fim de um SingleChildScrollView — garante visível antes de tocar.
      await tester.ensureVisible(find.byKey(const Key('btn-submit-cadastro')));
      await tester.tap(find.byKey(const Key('btn-submit-cadastro')));
      await tester.pumpAndSettle();

      expect(find.text('Informe o nome do responsável.'), findsOneWidget);
      expect(find.text('Informe seu e-mail.'), findsOneWidget);
      expect(find.text('Informe o nome do estabelecimento.'), findsOneWidget);
    });

    testWidgets('link "Já tem conta? Entrar" volta para /login', (
      tester,
    ) async {
      await pumpApp(tester, initialRoute: '/cadastro/contratante');

      await tester.tap(find.byKey(const Key('link-entrar')));
      await awaitRouteChange(tester, '/login');
    });
  });
}
