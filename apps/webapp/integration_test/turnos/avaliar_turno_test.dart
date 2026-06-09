// integration_test — STORY-087 (E2E browser real: captura da avaliação recíproca, CA-6).
//
// Same-origin (proxy + --web-launch-url, IDR-021) contra o BACKEND REAL, com o par EXCLUSIVO
// do AvaliacaoSeeder (`*.aval087.seed`) — exatamente UM turno finalizado entre eles, resetado
// para totalmente pendente a cada `_e2e-seed` (E2E repetível apesar da mutação). Por papel:
//   1. loga → /turnos → toca o (único) card finalizado → /turnos/{id} com o CTA "Avaliar turno"
//   2. abre a tela de avaliação → "Enviar avaliação" começa DESABILITADO (sem estrela — bloqueado)
//   3. escolhe estrela → envia → volta ao detalhe e o CTA SOME (pendência resolvida — CA-4).
// Profissional e contratante avaliam direções distintas do MESMO turno — não colidem na execução.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/login_helper.dart';
import '../helpers/pump_app.dart';
import '../helpers/route_helper.dart';

const _profissionalSeed = 'profissional.aval087.seed@turni.local';
const _contratanteSeed = 'contratante.aval087.seed@turni.local';
const _seedPassword = 'password';

/// Card raiz de turno: `turno-card-{uuid}` (36 chars de uuid, sem sufixo).
final _cardDeTurno = find.byWidgetPredicate((w) {
  final k = w.key;
  return k is ValueKey<String> &&
      k.value.startsWith('turno-card-') &&
      k.value.length == 'turno-card-'.length + 36;
}, description: 'card raiz de turno');

/// Faz `pump` curto até [finder] DESaparecer (ou estoura [timeout]).
Future<void> pumpUntilGone(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (finder.evaluate().isNotEmpty) {
    if (DateTime.now().isAfter(deadline)) {
      fail('widget não sumiu em ${timeout.inSeconds}s: $finder');
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _avaliarFluxo(
  WidgetTester tester, {
  required String email,
  required bool profissional,
}) async {
  await pumpApp(tester);
  assertOnRoute(tester, '/login');

  await loginAs(tester, email: email, password: _seedPassword);
  await awaitRouteChange(tester, '/');
  await tester.pumpAndSettle();

  // Lista de turnos do papel → o (único) card finalizado pendente.
  await goToTurnos(tester, profissional: profissional);
  await tester.pumpAndSettle();
  expect(_cardDeTurno, findsWidgets);
  await tester.tap(_cardDeTurno.first);
  await tester.pumpAndSettle();
  await pumpUntilFound(tester, find.byKey(const Key('turno-detalhe-screen')));

  // CTA "Avaliar turno" presente (turno finalizado pendente — CA-3).
  await pumpUntilFound(
    tester,
    find.byKey(const Key('turno-detalhe-avaliar-btn')),
  );
  await tester.tap(find.byKey(const Key('turno-detalhe-avaliar-btn')));
  await tester.pumpAndSettle();
  await pumpUntilFound(tester, find.byKey(const Key('avaliar-turno-screen')));

  // Sem estrela: "Enviar avaliação" está DESABILITADO (bloqueado — CA-1/CA-2).
  final btnAntes = tester.widget<FilledButton>(
    find.byKey(const Key('avaliacao-enviar-btn')),
  );
  expect(btnAntes.onPressed, isNull, reason: 'CTA deve começar bloqueado');

  // Escolhe 5 estrelas → CTA habilita → envia (sucesso).
  await tester.tap(find.byKey(const Key('avaliacao-estrela-5')));
  await tester.pumpAndSettle();
  final btnDepois = tester.widget<FilledButton>(
    find.byKey(const Key('avaliacao-enviar-btn')),
  );
  expect(btnDepois.onPressed, isNotNull, reason: 'CTA habilita com ≥1 estrela');

  await tester.tap(find.byKey(const Key('avaliacao-enviar-btn')));
  await tester.pumpAndSettle();

  // Sucesso: volta ao detalhe e o CTA SOME (pendência resolvida — CA-4).
  await pumpUntilFound(tester, find.byKey(const Key('turno-detalhe-screen')));
  await pumpUntilGone(
    tester,
    find.byKey(const Key('turno-detalhe-avaliar-btn')),
  );
}

void main() {
  testWidgets(
    'profissional avalia o turno: bloqueio sem estrela → sucesso (CA-6)',
    (tester) async {
      await _avaliarFluxo(tester, email: _profissionalSeed, profissional: true);
    },
  );

  testWidgets(
    'contratante avalia o turno: bloqueio sem estrela → sucesso (CA-6)',
    (tester) async {
      await _avaliarFluxo(tester, email: _contratanteSeed, profissional: false);
    },
  );
}
