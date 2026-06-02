// integration_test — STORY-048 CA-11 (E2E do feed do profissional, padrão IDR-021).
//
// Cobre a ÁREA LOGADA do profissional same-origin (proxy + --web-launch-url): login →
// home (= feed `/feed`) → o backend REAL ranqueia as vagas abertas do seed (GET /api/feed
// autenticado, score on-demand) → a UI lista ≥3 cards ranqueados → troca o filtro para
// "Alto match" → re-busca real (GET /api/feed?filtro=alto_match) → a lista encolhe.
//
// O FeedSeeder prepara o profissional.teste com função primária + 2 secundárias alinhadas
// às 3 vagas abertas do VagasSeeder e geo dentro do raio, de modo que "Todas" traga as 3
// (a primária com score ≥80, as secundárias <80) e "Alto match" filtre para a de maior fit.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../helpers/login_helper.dart';
import '../helpers/pump_app.dart';
import '../helpers/route_helper.dart';

/// Conta os cards do feed pelo número de match "{n}/100" (um por card).
int _contaCards(WidgetTester tester) =>
    find.textContaining('/100').evaluate().length;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'profissional vê feed ranqueado e o filtro "Alto match" atualiza a lista (CA-11)',
    (tester) async {
      await pumpApp(tester);
      assertOnRoute(tester, '/login');

      await loginAsProfissional(tester);
      await awaitRouteChange(tester, '/');
      await tester.pumpAndSettle();

      // 1) Home do profissional é o feed (GET /api/feed real). Espera a lista carregar.
      await pumpUntilFound(tester, find.byKey(const Key('feed-lista')));
      await pumpUntilFound(tester, find.textContaining('/100'));

      // ≥3 vagas ranqueadas do seed (3 abertas casando função primária/secundária).
      final totalTodas = _contaCards(tester);
      expect(totalTodas, greaterThanOrEqualTo(3));

      // 2) Troca para "Alto match" → re-busca sem reload (GET /api/feed?filtro=alto_match).
      await tester.tap(find.byKey(const Key('feed-filtro-alto_match')));
      await tester
          .pump(); // dispara o re-fetch (skeleton); não settla durante o voo

      // A lista atualiza: o filtro de alto match traz menos vagas que "Todas".
      await pumpUntilFound(tester, find.byKey(const Key('feed-lista')));
      await pumpUntilFound(tester, find.textContaining('/100'));
      final totalAlto = _contaCards(tester);

      expect(totalAlto, greaterThanOrEqualTo(1));
      expect(totalAlto, lessThan(totalTodas));
    },
  );
}
