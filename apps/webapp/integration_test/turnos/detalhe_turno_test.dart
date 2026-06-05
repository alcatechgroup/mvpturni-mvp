// integration_test — STORY-060 (E2E browser real: lista → detalhe nos 2 papéis, CA-6).
//
// Same-origin (proxy + --web-launch-url, IDR-021) contra o BACKEND REAL, com os usuários
// exclusivos do TurnosSeeder (que agora também grava a trilha de auditoria por estado):
//   1. profissional.turnos.seed loga → /profissional/turnos → toca um card → /turnos/{id}
//      com badge de estado, "Você recebe" (sem taxa/total — PDR-004), aceite e histórico.
//   2. contratante.turnos.seed loga → /contratante/turnos → toca um card → /turnos/{id}
//      com valor + taxa + total separados (CA-2) e histórico.
// RBAC cruzado (CA-1, 403) é provado por testes de API + widget tests; não repete em
// browser real (mesma estratégia da 059).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/login_helper.dart';
import '../helpers/pump_app.dart';
import '../helpers/route_helper.dart';

/// Usuários exclusivos do TurnosSeeder (nunca tocados pelas outras suítes).
const _profissionalTurnosSeed = 'profissional.turnos.seed@turni.local';
const _contratanteTurnosSeed = 'contratante.turnos.seed@turni.local';
const _turnosSeedPassword = 'password';

/// Card raiz de turno: `turno-card-{uuid}` (36 chars de uuid, sem sufixo).
final _cardDeTurno = find.byWidgetPredicate((w) {
  final k = w.key;
  return k is ValueKey<String> &&
      k.value.startsWith('turno-card-') &&
      k.value.length == 'turno-card-'.length + 36;
}, description: 'card raiz de turno');

void main() {
  testWidgets(
    'profissional: lista → detalhe com valor próprio e histórico (CA-6)',
    (tester) async {
      await pumpApp(tester);
      assertOnRoute(tester, '/login');

      await loginAs(
        tester,
        email: _profissionalTurnosSeed,
        password: _turnosSeedPassword,
      );
      await awaitRouteChange(tester, '/');
      await tester.pumpAndSettle();
      await pumpUntilFound(tester, find.byKey(const Key('feed-screen')));

      // Lista (porta de entrada da 059) → toque no primeiro card (alvo da 060).
      await tester.tap(find.byKey(const Key('feed-meus-turnos-btn')));
      await tester.pumpAndSettle();
      await pumpUntilFound(tester, find.byKey(const Key('meus-turnos-screen')));
      expect(_cardDeTurno, findsWidgets);

      await tester.tap(_cardDeTurno.first);
      await tester.pumpAndSettle();
      await pumpUntilFound(
        tester,
        find.byKey(const Key('turno-detalhe-screen')),
      );

      // Header (CA-2): badge + função + onde + quando.
      expect(find.byKey(const Key('turno-detalhe-estado')), findsOneWidget);
      expect(find.byKey(const Key('turno-detalhe-funcao')), findsOneWidget);
      expect(find.text('Estabelecimento Turnos Seed'), findsOneWidget);
      expect(find.byKey(const Key('turno-detalhe-quando')), findsOneWidget);

      // Valor do profissional (PDR-004): o que recebe, NUNCA taxa/total.
      expect(find.text('VOCÊ RECEBE'), findsOneWidget);
      expect(find.text('R\$ 200,00'), findsWidgets);
      expect(find.text('Taxa Turni'), findsNothing);
      expect(find.byKey(const Key('turno-detalhe-valor-total')), findsNothing);

      // Aceite (CA-5) + timeline com trilha do seed (CA-3).
      expect(find.byKey(const Key('turno-detalhe-aceite-btn')), findsOneWidget);
      expect(find.text('Histórico'), findsOneWidget);
      expect(find.byKey(const Key('turno-detalhe-timeline')), findsOneWidget);
      expect(find.text('Turno confirmado'), findsOneWidget);
      expect(find.text('Aceite eletrônico emitido'), findsOneWidget);

      // Modal do aceite somente-leitura (CA-5).
      await tester.tap(find.byKey(const Key('turno-detalhe-aceite-btn')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('aceite-modal')), findsOneWidget);
      expect(find.textContaining('Contrato eventual de turno'), findsOneWidget);
      await tester.tap(find.byKey(const Key('aceite-modal-fechar')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('aceite-modal')), findsNothing);
    },
  );

  testWidgets('contratante: lista → detalhe com valor+taxa+total (CA-2/CA-6)', (
    tester,
  ) async {
    await pumpApp(tester);
    assertOnRoute(tester, '/login');

    await loginAs(
      tester,
      email: _contratanteTurnosSeed,
      password: _turnosSeedPassword,
    );
    await awaitRouteChange(tester, '/');
    await tester.pumpAndSettle();
    await pumpUntilFound(tester, find.byKey(const Key('minhas-vagas-screen')));

    await tester.tap(find.byKey(const Key('minhas-vagas-turnos-btn')));
    await tester.pumpAndSettle();
    await pumpUntilFound(
      tester,
      find.byKey(const Key('contratante-turnos-screen')),
    );
    expect(_cardDeTurno, findsWidgets);

    await tester.tap(_cardDeTurno.first);
    await tester.pumpAndSettle();
    await pumpUntilFound(tester, find.byKey(const Key('turno-detalhe-screen')));

    // Quem vem + visibilidade financeira do contratante (CA-2 / domain/pagamento.md).
    expect(find.text('Profissional Turnos Seed'), findsOneWidget);
    expect(find.text('PAGAMENTO DESTE TURNO'), findsOneWidget);
    expect(find.text('Valor do profissional'), findsOneWidget);
    expect(find.text('Taxa Turni'), findsOneWidget);
    expect(find.text('R\$ 30,00'), findsOneWidget);
    final total = tester.widget<Text>(
      find.byKey(const Key('turno-detalhe-valor-total')),
    );
    expect(total.data, 'R\$ 230,00');

    // Histórico presente também para o contratante.
    expect(find.text('Histórico'), findsOneWidget);
    expect(find.byKey(const Key('turno-detalhe-timeline')), findsOneWidget);
  });
}
