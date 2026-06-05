// STORY-058 — passos compartilhados dos E2E de aprovação (caminho feliz, bloqueio PF,
// override PJ). Cada cenário do AprovacaoCandidaturaSeeder usa uma FUNÇÃO exclusiva; é por
// ela que se acha o card da vaga em "Minhas vagas" — nunca `.first` global (a vaga do
// painel/051 é dona do 1º "Ver candidatos"; publicar/editar dependem dos próprios cards).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/login_helper.dart';
import '../helpers/pump_app.dart';
import '../helpers/route_helper.dart';

/// Loga como contratante.teste, acha a vaga do cenário pela [funcao] exclusiva e abre o
/// painel de candidatos dela. Deixa o tester no painel carregado (lista visível).
Future<void> abrirPainelDoCenario(WidgetTester tester, String funcao) async {
  await pumpApp(tester);
  assertOnRoute(tester, '/login');

  await loginAsContratante(tester);
  await awaitRouteChange(tester, '/');
  await tester.pumpAndSettle();

  await pumpUntilFound(tester, find.byKey(const Key('minhas-vagas-screen')));

  // Card raiz: `vaga-card-{uuid}` (36 chars de uuid, sem sufixo).
  final cardRaiz = find.byWidgetPredicate((w) {
    final k = w.key;
    return k is ValueKey<String> &&
        k.value.startsWith('vaga-card-') &&
        k.value.length == 'vaga-card-'.length + 36;
  }, description: 'card raiz da vaga');

  // O card do CENÁRIO é o que tem a função exclusiva E candidato aguardando. Não basta o
  // `.first` da função: vagas FECHADAS também mostram "Ver candidatos" (histórico) e as
  // fechadas de ciclos consumidos/turnos pré-existentes (2027) vêm ANTES da aberta na
  // ordenação por data — o tap abriria o painel de uma vaga sem pendentes (vazio).
  final funcaoNoCardComPendentes = find.descendant(
    of: find.ancestor(
      of: find.textContaining('candidato aguardando'),
      matching: cardRaiz,
    ),
    matching: find.text(funcao),
  );
  await pumpUntilFound(tester, funcaoNoCardComPendentes);

  final cardDaVaga = find.ancestor(
    of: funcaoNoCardComPendentes.first,
    matching: cardRaiz,
  );
  final verCandidatos = find.descendant(
    of: cardDaVaga.first,
    matching: find.text('Ver candidatos'),
  );
  await pumpUntilFound(tester, verCandidatos);
  await tester.ensureVisible(verCandidatos.first);
  await tester.pumpAndSettle();
  await tester.tap(verCandidatos.first);
  await tester.pumpAndSettle();

  await pumpUntilFound(
    tester,
    find.byKey(const Key('painel-candidatos-lista')),
  );
}

/// No painel, toca "Aceitar candidatura" do único card e confirma o D1.
Future<void> aceitarEConfirmar(WidgetTester tester) async {
  final aceitar = find.byWidgetPredicate((w) {
    final k = w.key;
    return k is ValueKey<String> && k.value.endsWith('-aceitar-btn');
  }, description: 'botão Aceitar candidatura');
  await tester.ensureVisible(aceitar.first);
  await tester.pumpAndSettle();
  await tester.tap(aceitar.first);
  await tester.pumpAndSettle();

  await pumpUntilFound(
    tester,
    find.byKey(const Key('aprovar-dialog-confirmar')),
  );
  await tester.tap(find.byKey(const Key('aprovar-dialog-confirmar-btn')));
  await tester.pumpAndSettle();
}
