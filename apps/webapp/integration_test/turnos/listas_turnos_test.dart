// integration_test — STORY-059 (E2E browser real: os 2 caminhos do CA-7).
//
// Same-origin (proxy + --web-launch-url, IDR-021) contra o BACKEND REAL, com os usuários
// exclusivos do TurnosSeeder (STORY-055 — 11 turnos, um por estado da máquina):
//   1. profissional.turnos.seed loga → feed → ícone "Meus turnos" → /profissional/turnos
//      com as seções do ciclo de vida (CA-1/CA-3) e o estabelecimento no card.
//   2. contratante.turnos.seed loga → minhas vagas → ícone "Turnos" → /contratante/turnos
//      com o espelho: nome do profissional e valor "· total" (CA-2/CA-4, PDR-004).
// RBAC cruzado (CA-5) é provado por testes de API + widget tests (403 → sem permissão);
// não repete em browser real (mesma estratégia das listas da 047/048).
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
    'profissional: feed → "Meus turnos" com seções do ciclo de vida (CA-1/CA-3)',
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

      // Porta de entrada: ícone na AppBar do feed (SCREEN-059 §2).
      await tester.tap(find.byKey(const Key('feed-meus-turnos-btn')));
      await tester.pumpAndSettle();
      await awaitRouteChange(tester, '/profissional/turnos');
      await pumpUntilFound(tester, find.byKey(const Key('meus-turnos-screen')));

      // Seções na ordem do ciclo de vida — o seeder cobre os 11 estados, logo os 7
      // grupos existem (em_disputa como seção própria — decisão PO 2026-06-05).
      for (final slug in [
        'confirmado',
        'aguardando-checkin',
        'ativo',
        'aguardando-checkout',
        'em-disputa',
        'finalizado',
        'encerrado',
      ]) {
        expect(
          find.byKey(Key('turnos-grupo-$slug')),
          findsOneWidget,
          reason: 'seção $slug ausente',
        );
      }

      // Card do profissional: estabelecimento na linha "quem" (CA-3).
      expect(_cardDeTurno, findsWidgets);
      expect(find.text('Estabelecimento Turnos Seed'), findsWidgets);
    },
  );

  testWidgets(
    'contratante: minhas vagas → "Turnos" com total e profissional (CA-2/CA-4)',
    (tester) async {
      await pumpApp(tester);
      assertOnRoute(tester, '/login');

      await loginAs(
        tester,
        email: _contratanteTurnosSeed,
        password: _turnosSeedPassword,
      );
      await awaitRouteChange(tester, '/');
      await tester.pumpAndSettle();
      await pumpUntilFound(
        tester,
        find.byKey(const Key('minhas-vagas-screen')),
      );

      // Porta de entrada: ícone na AppBar de Minhas vagas (SCREEN-059 §2).
      await tester.tap(find.byKey(const Key('minhas-vagas-turnos-btn')));
      await tester.pumpAndSettle();
      await awaitRouteChange(tester, '/contratante/turnos');
      await pumpUntilFound(
        tester,
        find.byKey(const Key('contratante-turnos-screen')),
      );

      // Espelho (CA-4): nome do profissional na linha "quem" e valor com "· total"
      // (PDR-004 — o contratante vê o que PAGA, não o valor cru do profissional).
      expect(_cardDeTurno, findsWidgets);
      expect(find.text('Profissional Turnos Seed'), findsWidgets);

      final valores = find.byWidgetPredicate((w) {
        final k = w.key;
        return w is Text &&
            k is ValueKey<String> &&
            k.value.startsWith('turno-card-') &&
            k.value.endsWith('-valor');
      }, description: 'valor do card de turno');
      expect(valores, findsWidgets);
      final primeiro = tester.widget<Text>(valores.first);
      expect(primeiro.textSpan!.toPlainText(), contains('· total'));
    },
  );
}
