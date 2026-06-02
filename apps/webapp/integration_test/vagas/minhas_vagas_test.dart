// integration_test — STORY-047 CA-8 (E2E Minhas vagas + cancelar, padrão IDR-021).
//
// Cobre a ÁREA LOGADA do contratante same-origin (proxy + --web-launch-url): login →
// home (= "Minhas vagas") → publica uma vaga real (POST /api/vagas autenticado) para
// garantir uma vaga `aberta` determinística → volta para a lista → cancela essa vaga
// (DELETE /api/vagas/{id} autenticado) → o backend REAL transiciona `aberta → cancelada`
// e a UI reflete o selo "Cancelada" + toast.
//
// Por que publicar antes: o contratante de seed do login (contratante.teste) não tem
// vagas determinísticas (o VagasSeeder popula outro contratante). Publicar dentro do
// teste cria a vaga `aberta` que será cancelada — provando o caminho ponta a ponta
// contra o banco real (a transição de estado é exercida nos testes Feature do back).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../helpers/login_helper.dart';
import '../helpers/pump_app.dart';
import '../helpers/route_helper.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'contratante vê suas vagas e cancela uma → vira "Cancelada" no banco (CA-8)',
    (tester) async {
      await pumpApp(tester);
      assertOnRoute(tester, '/login');

      await loginAsContratante(tester);
      await awaitRouteChange(tester, '/');
      await tester.pumpAndSettle();

      // 1) Garante uma vaga `aberta` determinística publicando pela UI (POST real).
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

      // 2) De volta à lista (GET /api/vagas/minhas real) — a vaga aberta aparece.
      await awaitRouteChange(tester, '/contratante/vagas');
      // Filtra por "Todas" para que o card permaneça visível após virar cancelada
      // (o filtro padrão "Ativas" esconderia a vaga cancelada).
      await pumpUntilFound(
        tester,
        find.byKey(const Key('minhas-vagas-filtro-todas')),
      );
      await tester.tap(find.byKey(const Key('minhas-vagas-filtro-todas')));
      await tester.pumpAndSettle();
      await pumpUntilFound(tester, find.text('Cancelar vaga'));

      // 3) Cancela a vaga aberta (DELETE real) via diálogo de confirmação.
      await tester.tap(find.text('Cancelar vaga').first);
      await pumpUntilFound(
        tester,
        find.byKey(const Key('vaga-cancelar-dialog')),
      );
      await tester.tap(find.byKey(const Key('vaga-cancelar-confirmar-btn')));

      // 4) Backend real transicionou aberta→cancelada; a UI confirma com toast + selo.
      await pumpUntilFound(
        tester,
        find.byKey(const Key('vaga-cancelada-toast')),
      );
      expect(find.text('Cancelada'), findsWidgets);
    },
  );
}
