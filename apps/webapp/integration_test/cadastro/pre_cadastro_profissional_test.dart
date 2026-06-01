// integration_test — STORY-043 CA-6 (migra as validações de pre-cadastro.spec.ts).
//
// Cobre os cenários DETERMINÍSTICOS do pré-cadastro de profissional: carga da tela
// pública, validação client-side de campos obrigatórios e navegação. Roda same-origin
// sob o harness (a tela faz fetch de funções ao montar — GET /api/funcoes via proxy).
//
// FORA DE ESCOPO (IDR-009 / STORY-039): o happy-path com upload de foto (file picker
// do browser) NÃO migra para integration_test — fica em Patrol no nativo. Não há
// cenário de envio aqui; o `test.fixme` correspondente em Playwright permanece.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../helpers/pump_app.dart';
import '../helpers/route_helper.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('pré-cadastro de profissional (CA-6)', () {
    testWidgets('tela pública carrega sem auth', (tester) async {
      await pumpApp(tester, initialRoute: '/cadastro/profissional');

      assertOnRoute(tester, '/cadastro/profissional');
      expect(find.byKey(const Key('screen-cadastro-profissional')), findsOneWidget);
      expect(find.text('Criar conta de profissional'), findsOneWidget);
    });

    testWidgets('submeter vazio exibe erros de campo obrigatório', (tester) async {
      await pumpApp(tester, initialRoute: '/cadastro/profissional');

      // Validação é client-side (sem rede): tocar Enviar mostra os erros inline.
      // O botão fica no fim de um SingleChildScrollView — garante visível antes de tocar.
      await tester.ensureVisible(find.byKey(const Key('btn-submit-cadastro')));
      await tester.tap(find.byKey(const Key('btn-submit-cadastro')));
      await tester.pumpAndSettle();

      expect(find.text('Informe seu nome completo.'), findsOneWidget);
      expect(find.text('Informe seu e-mail.'), findsOneWidget);
      // Erro não-TextFormField (tipo de cadastro) também aparece.
      expect(
        find.text('Selecione o tipo de cadastro: PF, MEI ou PJ.'),
        findsOneWidget,
      );
    });

    testWidgets('link "Já tem conta? Entrar" volta para /login', (tester) async {
      await pumpApp(tester, initialRoute: '/cadastro/profissional');

      await tester.tap(find.byKey(const Key('link-entrar')));
      await awaitRouteChange(tester, '/login');
    });
  });
}
