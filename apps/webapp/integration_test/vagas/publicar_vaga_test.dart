// integration_test — STORY-046 CA-9 (E2E publicar vaga, mesmo padrão IDR-010/011/021).
//
// Cobre a ÁREA LOGADA do contratante: login → home → "Publicar vaga" →
// /contratante/vagas/nova → gate PDR-005 (stub pending:0 → form) → preenche os 6 campos →
// submete (POST /api/vagas AUTENTICADO) → 201 real → navega para "Minhas vagas" com toast.
//
// Same-origin (proxy reverso + --web-launch-url, IDR-021): o cookie de sessão Sanctum
// precisa trafegar no POST. A confirmação de sucesso (toast/placeholder) é dirigida pelo
// 201 do backend REAL — que criou a vaga `aberta` + versão 1 + audit `vaga.criada`
// (provados nos testes Feature). Não há ainda endpoint de leitura (STORY-047) para
// consultar a linha pela UI; a evidência de DB é o 201 real ponta a ponta.
//
// Determinismo: o gate stub sempre devolve pending:0 e publicar não tem unicidade — cada
// run cria uma vaga nova, sem depender de estado anterior (só do contratante seed).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../helpers/login_helper.dart';
import '../helpers/pump_app.dart';
import '../helpers/route_helper.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('contratante publica vaga ponta a ponta → Minhas vagas + toast (CA-9)', (
    tester,
  ) async {
    await pumpApp(tester);
    assertOnRoute(tester, '/login');

    // Login do contratante ativo do seed → funnel guard → home `/`.
    await loginAsContratante(tester);
    await awaitRouteChange(tester, '/');

    // Porta de entrada: CTA "Publicar vaga" na home do contratante (CA-1).
    await pumpUntilFound(
      tester,
      find.byKey(const Key('contratante-home-publicar-vaga-btn')),
    );
    await tester.tap(find.byKey(const Key('contratante-home-publicar-vaga-btn')));
    await awaitRouteChange(tester, '/contratante/vagas/nova');

    // Gate stub (pending:0) → o formulário renderiza. Espera o dropdown montar.
    await pumpUntilFound(
      tester,
      find.byKey(const Key('publicar-vaga-funcao-dropdown')),
    );

    // Seleciona a função (lista canônica real de GET /api/funcoes).
    await tester.tap(find.byKey(const Key('publicar-vaga-funcao-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bartender').last);
    await tester.pumpAndSettle();

    // Datas/horas (campos de texto deterministas) + valor (máscara R$) + posições=1.
    await tester.enterText(
      find.byKey(const Key('publicar-vaga-data-inicio')),
      '31/12/2026',
    );
    await tester.enterText(
      find.byKey(const Key('publicar-vaga-hora-inicio')),
      '18:00',
    );
    await tester.enterText(
      find.byKey(const Key('publicar-vaga-data-fim')),
      '31/12/2026',
    );
    await tester.enterText(
      find.byKey(const Key('publicar-vaga-hora-fim')),
      '23:00',
    );
    await tester.enterText(
      find.byKey(const Key('publicar-vaga-valor')),
      '18000', // máscara → R$ 180,00
    );
    await tester.pumpAndSettle();

    // Submete (POST autenticado real).
    final submit = find.byKey(const Key('publicar-vaga-submit-btn'));
    await tester.ensureVisible(submit);
    await tester.pumpAndSettle();
    await tester.tap(submit);

    // Sucesso → navega para Minhas vagas (placeholder STORY-047) com toast (CA-7).
    await awaitRouteChange(tester, '/contratante/vagas');
    await pumpUntilFound(
      tester,
      find.byKey(const Key('publicar-vaga-sucesso-toast')),
    );
    expect(find.text('Vaga publicada'), findsWidgets);
  });
}
