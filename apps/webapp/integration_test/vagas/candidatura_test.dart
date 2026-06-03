// integration_test — STORY-050 CA-11 (E2E da candidatura em 1 toque + gate de conflito).
//
// Cobre a ÁREA LOGADA do profissional same-origin (proxy + --web-launch-url, IDR-021) contra o
// BACKEND REAL, em dois cenários independentes (cada um abre UMA vaga — primeira visita ao
// detalhe — para não depender de navegar entre duas telas de detalhe no mesmo teste):
//
//   1. Sucesso + retirada — abre a vaga R$ 120 (vaga seed aberta, função primária, candidatável),
//      confirma a candidatura (POST 201 real, ou 409→badge/reativação se uma execução anterior
//      deixou estado — idempotência CA-6), vê o badge "Você já se candidatou" e então RETIRA
//      (DELETE real, CA-8), devolvendo o estado ao início → "0 flake em 3 runs".
//   2. Conflito de horário — o CandidaturaConflitoSeeder já deixou o profissional com candidatura
//      PENDENTE na vaga R$ 991 (janela 18–23h, +30d). O teste abre a vaga R$ 992 (mesma janela,
//      sobreposta), confirma e vê o modal de bloqueio `conflito_horario` (gate server-side CA-3)
//      com o card da vaga em conflito. Nenhuma candidatura é criada na 992 → idempotente.
//
// O gate de AVALIAÇÃO (PDR-005) NÃO é exercitado aqui: é stub-honesto até o EPIC-003 (sem turnos
// no schema, nunca dispara no backend real). É coberto por widget test com gate forçado em
// test/vagas/candidatura_flow_test.dart — ver Notas do agente da STORY-050.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../helpers/login_helper.dart';
import '../helpers/pump_app.dart';
import '../helpers/route_helper.dart';

/// Card do feed (key `feed-card-{id}`) que contém o valor [valor] (ex.: "120").
Finder _cardComValor(String valor) => find.ancestor(
  of: find.textContaining('R\$ $valor'),
  matching: find.byWidgetPredicate((w) {
    final k = w.key;
    return k is ValueKey<String> &&
        RegExp(
          r'^feed-card-[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
        ).hasMatch(k.value);
  }),
);

/// Loga, espera o feed e abre a vaga cujo card mostra [valor], esperando o detalhe DAQUELA vaga.
Future<void> _abrirVagaDoFeed(WidgetTester tester, String valor) async {
  await pumpApp(tester);
  assertOnRoute(tester, '/login');
  await loginAsProfissional(tester);
  await awaitRouteChange(tester, '/');
  await tester.pumpAndSettle();

  await pumpUntilFound(tester, find.byKey(const Key('feed-lista')));
  await pumpUntilFound(tester, find.textContaining('/100'));

  await tester.scrollUntilVisible(
    find.textContaining('R\$ $valor'),
    200,
    scrollable: find.descendant(
      of: find.byKey(const Key('feed-lista')),
      matching: find.byType(Scrollable),
    ),
  );
  await tester.tap(_cardComValor(valor).first);
  await tester.pump();
  await pumpUntilFound(
    tester,
    find.descendant(
      of: find.byKey(const Key('vaga-detalhe-cabecalho')),
      matching: find.textContaining('R\$ $valor'),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('candidatura: sucesso em 1 toque e retirada (CA-1/CA-8/CA-11)', (
    tester,
  ) async {
    // Vaga seed R$ 120 (função primária, candidatável, sem conflito com a 991 de +30d).
    await _abrirVagaDoFeed(tester, '120');

    // Candidatar → confirmar → badge "Você já se candidatou" (201, ou 409/reativação).
    await tester.tap(find.byKey(const Key('vaga-detalhe-candidatar-btn')));
    await pumpUntilFound(
      tester,
      find.byKey(const Key('candidatura-confirmar-btn')),
    );
    await tester.tap(find.byKey(const Key('candidatura-confirmar-btn')));
    await pumpUntilFound(
      tester,
      find.byKey(const Key('vaga-detalhe-ja-candidatou')),
    );

    // Retirar → confirmar → CTA "Candidatar-se" volta (estado limpo p/ a próxima execução).
    await tester.tap(find.byKey(const Key('vaga-detalhe-retirar-btn')));
    await pumpUntilFound(
      tester,
      find.byKey(const Key('candidatura-retirar-confirmar-btn')),
    );
    await tester.tap(
      find.byKey(const Key('candidatura-retirar-confirmar-btn')),
    );
    await pumpUntilFound(
      tester,
      find.byKey(const Key('vaga-detalhe-candidatar-btn')),
    );
  });

  testWidgets('candidatura: gate de conflito de horário bloqueia (CA-3/CA-11)', (
    tester,
  ) async {
    // O seeder deixou candidatura pendente na 991; a 992 sobrepõe → conflito.
    await _abrirVagaDoFeed(tester, '992');

    await tester.tap(find.byKey(const Key('vaga-detalhe-candidatar-btn')));
    await pumpUntilFound(
      tester,
      find.byKey(const Key('candidatura-confirmar-btn')),
    );
    await tester.tap(find.byKey(const Key('candidatura-confirmar-btn')));

    // Modal de bloqueio `conflito_horario` + card da vaga em conflito (gate server-side).
    await pumpUntilFound(
      tester,
      find.byKey(const Key('candidatura-bloqueio-conflito_horario')),
    );
    expect(find.byKey(const Key('candidatura-conflito-card')), findsOneWidget);

    // Fecha o modal (Entendi) — nenhuma candidatura foi criada na 992 (idempotente).
    await tester.tap(find.byKey(const Key('candidatura-bloqueio-acao-btn')));
    await tester.pumpAndSettle();
  });
}
