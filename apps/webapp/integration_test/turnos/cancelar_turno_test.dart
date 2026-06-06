// integration_test — STORY-066 (E2E browser real: cancelamento dos 2 lados + no-show).
//
// Same-origin (proxy + --web-launch-url, IDR-021) contra o BACKEND REAL, com três
// pares exclusivos de seed:
//
//   1. `*.cancelarpro.seed` — o PROFISSIONAL cancela: gatilho no detalhe (confirmado),
//      dialog com motivo, snackbar, badge ⊘ Cancelado, trilha "Você cancelou este
//      turno." + motivo entre aspas (visível aos 2 lados — decisão do PO);
//   2. `*.cancelaremp.seed` — o CONTRATANTE cancela (sem motivo): mesmo fluxo, trilha
//      "Você cancelou este turno." sem linha de motivo;
//   3. `*.noshow.seed` — turno VENCIDO no seed (início há 3h > X=2h); o cron
//      `turnos:detectar-no-show` rodou no `_e2e-seed` (Makefile) e o worker liberou a
//      pré-autorização via fake: o profissional encontra badge "Não realizado", trilha
//      "Turno não realizado" (copy com as 2 horas) e "Reserva de pagamento liberada".
//
// Os cenários CONSOMEM os turnos (terminais); o TurnosSeeder recria os pares no
// próximo `_e2e-seed` (recriaConsumido).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/login_helper.dart';
import '../helpers/pump_app.dart';
import '../helpers/route_helper.dart';

const _senha = 'password';

/// Card raiz de turno: `turno-card-{uuid}` (36 chars de uuid, sem sufixo).
final _cardDeTurno = find.byWidgetPredicate((w) {
  final k = w.key;
  return k is ValueKey<String> &&
      k.value.startsWith('turno-card-') &&
      k.value.length == 'turno-card-'.length + 36;
}, description: 'card raiz de turno');

Finder _cardComEstado(String estadoLabel) =>
    find.ancestor(of: find.text(estadoLabel), matching: _cardDeTurno).first;

/// Loga o PROFISSIONAL [email] e abre o detalhe do card com [estadoLabel].
Future<void> _proAteODetalhe(
  WidgetTester tester,
  String email,
  String estadoLabel,
) async {
  await pumpApp(tester);
  assertOnRoute(tester, '/login');
  await loginAs(tester, email: email, password: _senha);
  await awaitRouteChange(tester, '/');
  await tester.pumpAndSettle();
  await pumpUntilFound(tester, find.byKey(const Key('feed-screen')));

  await tester.tap(find.byKey(const Key('feed-meus-turnos-btn')));
  await tester.pumpAndSettle();
  await pumpUntilFound(tester, find.byKey(const Key('meus-turnos-screen')));

  await tester.tap(_cardComEstado(estadoLabel));
  await tester.pumpAndSettle();
  await pumpUntilFound(tester, find.byKey(const Key('turno-detalhe-screen')));
}

/// Loga o CONTRATANTE [email] e abre o detalhe do card com [estadoLabel].
Future<void> _contratanteAteODetalhe(
  WidgetTester tester,
  String email,
  String estadoLabel,
) async {
  await pumpApp(tester);
  assertOnRoute(tester, '/login');
  await loginAs(tester, email: email, password: _senha);
  await awaitRouteChange(tester, '/');
  await tester.pumpAndSettle();
  await pumpUntilFound(tester, find.byKey(const Key('minhas-vagas-screen')));

  await tester.tap(find.byKey(const Key('minhas-vagas-turnos-btn')));
  await awaitRouteChange(tester, '/contratante/turnos');
  await pumpUntilFound(
    tester,
    find.byKey(const Key('contratante-turnos-screen')),
  );

  await tester.tap(_cardComEstado(estadoLabel));
  await tester.pumpAndSettle();
  await pumpUntilFound(tester, find.byKey(const Key('turno-detalhe-screen')));
}

/// Abre o dialog pelo gatilho, opcionalmente preenche o motivo e confirma;
/// retorna quando a tela recarregou no estado terminal (badge ⊘ Cancelado).
Future<void> _cancelarPeloDialog(WidgetTester tester, {String? motivo}) async {
  final gatilho = find.byKey(const Key('turno-detalhe-cancelar-btn'));
  await pumpUntilFound(tester, gatilho);
  await tester.ensureVisible(gatilho);
  await tester.tap(gatilho);
  await tester.pumpAndSettle();
  await pumpUntilFound(tester, find.byKey(const Key('cancelar-dialog')));

  if (motivo != null) {
    await tester.enterText(
      find.byKey(const Key('cancelar-dialog-motivo')),
      motivo,
    );
    await tester.pump();
  }

  await tester.tap(find.byKey(const Key('cancelar-dialog-confirmar')));
  await tester.pumpAndSettle();

  // Recarregou a verdade: dialog fechado, snackbar e badge terminal.
  await pumpUntilFound(
    tester,
    find.byKey(const Key('turno-cancelado-snackbar')),
    timeout: const Duration(seconds: 20),
  );
  await pumpUntilFound(
    tester,
    find.descendant(
      of: find.byKey(const Key('turno-detalhe-estado')),
      matching: find.text('Cancelado'),
    ),
    timeout: const Duration(seconds: 20),
  );
}

void main() {
  testWidgets(
    'profissional cancela turno confirmado: dialog com motivo, badge terminal e trilha (CA-1/CA-2)',
    (tester) async {
      await _proAteODetalhe(
        tester,
        'profissional.cancelarpro.seed@turni.local',
        'Confirmado',
      );

      // Gatilho com a pergunta do papel (SCREEN-066 §A.3).
      expect(
        find.text('Não vai poder comparecer? Cancelar turno'),
        findsOneWidget,
      );

      await _cancelarPeloDialog(tester, motivo: 'Tive um imprevisto de saúde.');

      // Trilha: evento + voz de quem lê + motivo (decisão do PO — §A.5).
      expect(find.text('Turno cancelado'), findsOneWidget);
      expect(find.text('Você cancelou este turno.'), findsOneWidget);
      expect(find.text('“Tive um imprevisto de saúde.”'), findsOneWidget);
      // Terminal: gatilho e área de ações somem.
      expect(find.byKey(const Key('turno-detalhe-cancelar-btn')), findsNothing);
    },
  );

  testWidgets(
    'contratante cancela turno confirmado SEM motivo: badge terminal e trilha (CA-1/CA-2)',
    (tester) async {
      await _contratanteAteODetalhe(
        tester,
        'contratante.cancelaremp.seed@turni.local',
        'Confirmado',
      );

      expect(
        find.text('Não precisa mais deste turno? Cancelar turno'),
        findsOneWidget,
      );

      await _cancelarPeloDialog(tester);

      expect(find.text('Turno cancelado'), findsOneWidget);
      expect(find.text('Você cancelou este turno.'), findsOneWidget);
      expect(find.byKey(const Key('turno-detalhe-cancelar-btn')), findsNothing);
    },
  );

  testWidgets(
    'no-show automático (cron + travel do seed): badge Não realizado, trilha com X horas '
    'e reserva liberada (CA-5/CA-6/CA-7)',
    (tester) async {
      // O turno noshow.seed nasceu vencido e o cron rodou no _e2e-seed; o worker já
      // teve a suíte inteira de tempo para liberar a pré-autorização via fake.
      await _proAteODetalhe(
        tester,
        'profissional.noshow.seed@turni.local',
        'Não realizado',
      );

      expect(
        find.descendant(
          of: find.byKey(const Key('turno-detalhe-estado')),
          matching: find.text('Não realizado'),
        ),
        findsOneWidget,
      );
      expect(find.text('Turno não realizado'), findsOneWidget);
      expect(
        find.text(
          'O check-in não aconteceu em até 2 horas após o início previsto.',
        ),
        findsOneWidget,
      );
      // CA-6 — liberação igual cancelamento (audit pagamento.liberado → timeline).
      expect(find.text('Reserva de pagamento liberada'), findsOneWidget);
      expect(find.text('O contratante não foi cobrado.'), findsOneWidget);
      // Terminal: sem gatilho de cancelar, sem área de ações.
      expect(find.byKey(const Key('turno-detalhe-cancelar-btn')), findsNothing);
    },
  );
}
