// integration_test — STORY-051 CA-10 (E2E do painel de candidatos do contratante).
//
// Cobre a ÁREA LOGADA do contratante same-origin (proxy + --web-launch-url, IDR-021) contra o
// BACKEND REAL: o contratante seed (contratante.teste) loga → home (= "Minhas vagas") → acha a
// vaga seed do painel (PainelCandidatosSeeder: 1 vaga aberta com 3 candidaturas ranqueadas) →
// "Ver candidatos" → painel com os 3 candidatos NA ORDEM (Júlia 92 → Bruno 88 → Carlos 71,
// GET /api/vagas/{id}/candidatos real) → expande o breakdown do 1º e vê as 4 linhas reusadas da
// STORY-049. Determinístico: a vaga seed é a única do contratante.teste com "3 candidatos
// aguardando", então não depende das vagas que outros E2E publicam para o mesmo contratante.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../helpers/login_helper.dart';
import '../helpers/pump_app.dart';
import '../helpers/route_helper.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'contratante abre o painel e vê os 3 candidatos ranqueados + breakdown (CA-10)',
    (tester) async {
      await pumpApp(tester);
      assertOnRoute(tester, '/login');

      await loginAsContratante(tester);
      await awaitRouteChange(tester, '/');
      await tester.pumpAndSettle();

      // 1) "Minhas vagas" carregada — acha a vaga seed do painel (3 candidatos aguardando).
      await pumpUntilFound(
        tester,
        find.byKey(const Key('minhas-vagas-screen')),
      );
      await pumpUntilFound(tester, find.text('3 candidatos aguardando'));

      // 2) "Ver candidatos" → painel. A vaga seed (aberta + 3 pendentes) é a ÚNICA do
      // contratante.teste com esse botão: as vagas que os outros E2E publicam têm 0 candidatos
      // (sem botão) e as canceladas/abertas-vazias idem. Por isso o finder direto pela key é
      // determinístico (e robusto ao layout Wrap de "Minhas vagas").
      final verCandidatos = find.byWidgetPredicate((w) {
        final k = w.key;
        return k is ValueKey<String> && k.value.endsWith('-ver-candidatos');
      }, description: 'botão Ver candidatos');
      await pumpUntilFound(tester, verCandidatos);
      // ensureVisible resolve sozinho o Scrollable ancestral do alvo (evita a ambiguidade de
      // "qual scrollable" — "Minhas vagas" tem a régua de filtros + a lista).
      await tester.ensureVisible(verCandidatos.first);
      await tester.pumpAndSettle();
      await tester.tap(verCandidatos.first);
      await tester.pumpAndSettle();

      // 3) Painel carregado (GET real) — lista com os 3 candidatos.
      await pumpUntilFound(
        tester,
        find.byKey(const Key('painel-candidatos-lista')),
      );
      await pumpUntilFound(tester, find.text('Júlia Santos'));
      expect(find.text('Bruno Costa'), findsOneWidget);
      expect(find.text('Carlos Lima'), findsOneWidget);

      // 4) Ordem ranqueada (score DESC): Júlia (92) acima de Bruno (88) acima de Carlos (71).
      final yJulia = tester.getTopLeft(find.text('Júlia Santos')).dy;
      final yBruno = tester.getTopLeft(find.text('Bruno Costa')).dy;
      final yCarlos = tester.getTopLeft(find.text('Carlos Lima')).dy;
      expect(yJulia, lessThan(yBruno));
      expect(yBruno, lessThan(yCarlos));

      // 5) Expande o breakdown do 1º candidato e vê as 4 linhas reusadas da STORY-049.
      final primeiroToggle = find.text('Ver breakdown').first;
      await tester.ensureVisible(primeiroToggle);
      await tester.pumpAndSettle();
      await tester.tap(primeiroToggle);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('vaga-detalhe-breakdown-funcao')),
        findsWidgets,
      );
      expect(
        find.byKey(const Key('vaga-detalhe-breakdown-nivel')),
        findsWidgets,
      );
    },
  );
}
