// integration_test — STORY-052 CA-10/CA-13 (E2E edição material, padrão IDR-021).
//
// Área LOGADA do contratante same-origin (proxy + --web-launch-url): login → home
// (= "Minhas vagas") → publica uma vaga real (POST /api/vagas) para ter um alvo `aberto`
// determinístico → abre "Editar" (GET /api/vagas/{id}/editar real) → muda o valor → "Revisar
// alteração" abre o preview do diff → "Confirmar alteração" (PATCH /api/vagas/{id} real) →
// volta para "Minhas vagas" com o toast de sucesso. O backend REAL detecta a edição material,
// snapshota a nova versão e (sem candidatos nesta vaga recém-criada) atualiza in-place — o
// ciclo com candidatos/cron é exercido nos testes Feature do back (CA-13).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../helpers/login_helper.dart';
import '../helpers/pump_app.dart';
import '../helpers/route_helper.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('contratante edita uma vaga e vê o diff antes de salvar (CA-10)', (
    tester,
  ) async {
    await pumpApp(tester);
    assertOnRoute(tester, '/login');

    await loginAsContratante(tester);
    await awaitRouteChange(tester, '/');
    await tester.pumpAndSettle();

    // 1) Publica uma vaga `aberta` determinística pela UI (POST real).
    await pumpUntilFound(
      tester,
      find.byKey(const Key('minhas-vagas-publicar-btn')),
    );
    await tester.tap(find.byKey(const Key('minhas-vagas-publicar-btn')));
    await awaitRouteChange(tester, '/contratante/vagas/nova');

    await pumpUntilFound(
      tester,
      find.byKey(const Key('publicar-vaga-funcao-dropdown')),
    );
    await tester.tap(find.byKey(const Key('publicar-vaga-funcao-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bartender').last);
    await tester.pumpAndSettle();
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
      '18000',
    );
    await tester.pumpAndSettle();
    final submit = find.byKey(const Key('publicar-vaga-submit-btn'));
    await tester.ensureVisible(submit);
    await tester.pumpAndSettle();
    await tester.tap(submit);

    // 2) De volta à lista — filtra "Todas" e abre "Editar" da vaga recém-criada.
    await awaitRouteChange(tester, '/contratante/vagas');
    await pumpUntilFound(
      tester,
      find.byKey(const Key('minhas-vagas-filtro-todas')),
    );
    await tester.tap(find.byKey(const Key('minhas-vagas-filtro-todas')));
    await tester.pumpAndSettle();
    await pumpUntilFound(tester, find.text('Editar'));
    await tester.tap(find.text('Editar').first);

    // 3) Form de edição carrega (GET /editar real). Muda o valor e revisa.
    await pumpUntilFound(
      tester,
      find.byKey(const Key('editar-vaga-revisar-btn')),
    );
    await tester.enterText(find.byKey(const Key('editar-vaga-valor')), '20000');
    await tester.pumpAndSettle();
    final revisar = find.byKey(const Key('editar-vaga-revisar-btn'));
    await tester.ensureVisible(revisar);
    await tester.pumpAndSettle();
    await tester.tap(revisar);

    // 4) Preview do diff aparece com a mudança de valor.
    await pumpUntilFound(
      tester,
      find.byKey(const Key('editar-vaga-confirmar-sheet')),
    );
    expect(find.byKey(const Key('editar-vaga-diff-valor')), findsOneWidget);

    // 5) Confirma (PATCH real) → volta para "Minhas vagas".
    await tester.tap(find.byKey(const Key('editar-vaga-confirmar-btn')));
    await awaitRouteChange(tester, '/contratante/vagas');
    await tester.pumpAndSettle();
    expect(find.text('Minhas vagas'), findsWidgets);
  });
}
