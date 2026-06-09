// integration_test — STORY-088 (E2E browser real: reputação no Perfil + UX do gate, CA-6).
//
// Same-origin (proxy + --web-launch-url, IDR-021) contra o BACKEND REAL. Usa o usuário de
// reputação do AvaliacaoSeeder (`profissional.avaliacao@turni.local`, senha = ADMIN_SEED_PASSWORD):
// tem 3 turnos avaliados (score/nível/3 depoimentos) E ≥1 turno finalizado PENDENTE — então
// serve aos dois cenários ao mesmo tempo, e os testes só LEEM/NAVEGAM (não enviam avaliação),
// preservando a pendência para a próxima execução.
//   1. Perfil: /perfil exibe score + nível + XP (dono) + depoimentos (CA-1).
//   2. Gate:   no feed, o banner do gate leva ao destino Turnos via "Avaliar agora" (CA-4).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../helpers/login_helper.dart';
import '../helpers/pump_app.dart';
import '../helpers/route_helper.dart';

const _reputadoEmail = 'profissional.avaliacao@turni.local';

/// Card de depoimento: `depoimento-item-{index}`.
final _depoimento = find.byWidgetPredicate((w) {
  final k = w.key;
  return k is ValueKey<String> && k.value.startsWith('depoimento-item-');
}, description: 'card de depoimento');

void main() {
  // Binding de INTEGRAÇÃO (real async) — sem isto, rodar standalone cai no FakeAsync e o
  // HTTP real do login nunca completa (mesma disciplina dos demais leaves; IDR-021).
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('STORY-088 CA-1: Perfil exibe score, nível, XP e depoimentos', (
    tester,
  ) async {
    await pumpApp(tester);
    assertOnRoute(tester, '/login');

    await loginAs(tester, email: _reputadoEmail, password: seedPassword);
    await awaitRouteChange(tester, '/');
    await tester.pumpAndSettle();

    await goTo(tester, '/perfil');
    await pumpUntilFound(tester, find.byKey(const Key('perfil-screen')));

    // Reputação carregada (não ficou no skeleton/erro).
    await pumpUntilFound(tester, find.byKey(const Key('perfil-score')));
    expect(find.byKey(const Key('perfil-nivel-badge')), findsOneWidget);
    expect(find.byKey(const Key('perfil-xp-meter')), findsOneWidget);
    expect(find.byKey(const Key('perfil-depoimentos')), findsOneWidget);
    // O seed tem 3 depoimentos nominais → ao menos 1 card visível.
    expect(_depoimento, findsWidgets);
  });

  testWidgets('STORY-088 CA-4: banner do gate no feed leva aos Turnos', (
    tester,
  ) async {
    await pumpApp(tester);
    assertOnRoute(tester, '/login');

    await loginAs(tester, email: _reputadoEmail, password: seedPassword);
    await awaitRouteChange(tester, '/');
    await tester.pumpAndSettle();

    // O profissional com avaliação pendente vê o gate no feed (PDR-005).
    await goTo(tester, '/feed');
    await pumpUntilFound(tester, find.byKey(const Key('feed-gate-banner')));

    // "Avaliar agora" → destino Turnos (onde cada pendência tem seu próprio "Avaliar").
    await tester.tap(find.byKey(const Key('gate-avaliar-btn')));
    await awaitRouteChange(tester, '/turnos');
    await tester.pumpAndSettle();
    await pumpUntilFound(tester, find.byKey(const Key('turnos-lista')));
  });
}
