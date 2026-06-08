// integration_test — STORY-063 (E2E browser real: cronômetro bilateral, CA-3).
//
// Same-origin (proxy + --web-launch-url, IDR-021) contra o BACKEND REAL, com o par
// exclusivo `*.cronometro.seed` (turno `ativo` há ~35min — LEITURA PURA, o seed só
// renova o check_in_at entre execuções).
//
// VERIFICAÇÃO DA SINCRONIA (CA-3, janela ajustada com o PO em 2026-06-05): cada lado
// (profissional e depois contratante) abre o detalhe do MESMO turno e o teste amostra,
// por ~30s por lado (≥ 6 amostras em vários ciclos de polling de ~5s), o display
// exibido contra a verdade do servidor (`GET /turnos/{id}/cronometro`, mesma sessão
// do browser). Tolerância por amostra: ≤ 1s inteiro — por transitividade, os DOIS
// lados ficam ≤ 2s entre si (o display deriva da MESMA âncora `iniciado_em`; ADR-017
// faz a sincronia ser estrutural, não corrida de latência). Total: ≥ 12 amostras em
// ≥ 60s de janela contínua.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turni_webapp/features/turnos/cronometro_service.dart';

import '../helpers/login_helper.dart';
import '../helpers/pump_app.dart';
import '../helpers/route_helper.dart';

const _profissionalSeed = 'profissional.cronometro.seed@turni.local';
const _contratanteSeed = 'contratante.cronometro.seed@turni.local';
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

/// Espera TEMPO REAL (o app segue ticando) mantendo o tester bombeado.
Future<void> _esperaReal(WidgetTester tester, Duration d) async {
  final deadline = DateTime.now().add(d);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Segundos inteiros do display (`HH:MM:SS` ou `MM:SS`).
int _displaySegundos(WidgetTester tester) {
  final texto = tester
      .widget<Text>(find.byKey(const Key('cronometro-display')))
      .data!;
  final m = RegExp(r'^(?:(\d+):)?(\d{2}):(\d{2})$').firstMatch(texto);
  expect(
    m,
    isNotNull,
    reason: 'display fora do formato HH:MM:SS/MM:SS: $texto',
  );
  final h = int.parse(m!.group(1) ?? '0');
  return h * 3600 + int.parse(m.group(2)!) * 60 + int.parse(m.group(3)!);
}

/// Amostra o display contra a verdade do servidor [vezes] vezes, com ~[entre] entre
/// amostras (cobre vários ciclos do polling de ~5s). Cada amostra: diferença ≤ 1s
/// inteiro contra o servidor → os dois lados ficam ≤ 2s entre si por transitividade.
Future<void> _amostraSincronia(
  WidgetTester tester, {
  required String turnoId,
  required String lado,
  int vezes = 6,
  Duration entre = const Duration(seconds: 5),
}) async {
  final service = CronometroService();

  for (var i = 0; i < vezes; i++) {
    await _esperaReal(tester, entre);

    final snap = await service.fetch(turnoId);
    expect(
      snap,
      isNotNull,
      reason: '[$lado] âncora indisponível na amostra $i',
    );
    expect(snap!.estado, 'ativo');

    await tester.pump();
    final display = _displaySegundos(tester);
    final servidor = snap.servidorAgora.difference(snap.iniciadoEm!).inSeconds;

    expect(
      (display - servidor).abs(),
      lessThanOrEqualTo(1),
      reason:
          '[$lado] amostra $i: display ${display}s × servidor ${servidor}s — '
          'cada lado ≤ 1s da âncora ⇒ sincronia bilateral ≤ 2s (CA-3)',
    );
  }
}

/// Navega até o detalhe do turno `ativo` do papel logado e espera o cronômetro
/// sincronizar (display sai do placeholder). Devolve o turnoId da rota.
Future<String> _ateOCronometro(WidgetTester tester) async {
  await tester.tap(_cardComEstado('Em andamento'));
  await tester.pumpAndSettle();
  await pumpUntilFound(tester, find.byKey(const Key('turno-detalhe-screen')));
  await pumpUntilFound(tester, find.byKey(const Key('cronometro-card')));

  // Display sincronizado (sai de --:--:--) + microcopy do CA-2 presente.
  final deadline = DateTime.now().add(const Duration(seconds: 10));
  while (tester
      .widget<Text>(find.byKey(const Key('cronometro-display')))
      .data!
      .contains('-')) {
    if (DateTime.now().isAfter(deadline)) {
      fail('cronômetro não sincronizou em 10s');
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(find.textContaining('Início previsto:'), findsOneWidget);
  expect(find.textContaining('Duração prevista:'), findsOneWidget);

  final rota = currentRoute();
  expect(rota, startsWith('/turnos/'));
  return rota.split('/').last;
}

void main() {
  testWidgets(
    'cronômetro bilateral vivo: profissional e contratante veem o MESMO tempo '
    '(≤ 2s, ≥ 12 amostras em ≥ 60s — CA-2/3/4)',
    (tester) async {
      // ── Lado 1: PROFISSIONAL ──
      await pumpApp(tester);
      assertOnRoute(tester, '/login');
      await loginAs(tester, email: _profissionalSeed, password: _senha);
      await awaitRouteChange(tester, '/');
      await tester.pumpAndSettle();
      await pumpUntilFound(tester, find.byKey(const Key('feed-screen')));

      await goToTurnos(tester, profissional: true);
      await tester.pumpAndSettle();
      await pumpUntilFound(tester, find.byKey(const Key('meus-turnos-screen')));

      final turnoIdPro = await _ateOCronometro(tester);
      await _amostraSincronia(
        tester,
        turnoId: turnoIdPro,
        lado: 'profissional',
      );

      // ── Lado 2: CONTRATANTE (mesmo turno) ──
      await pumpApp(tester);
      assertOnRoute(tester, '/login');
      await loginAs(tester, email: _contratanteSeed, password: _senha);
      await awaitRouteChange(tester, '/');
      await tester.pumpAndSettle();
      await pumpUntilFound(
        tester,
        find.byKey(const Key('minhas-vagas-screen')),
      );

      await goToTurnos(tester, profissional: false);
      await awaitRouteChange(tester, '/contratante/turnos');
      await pumpUntilFound(
        tester,
        find.byKey(const Key('contratante-turnos-screen')),
      );

      final turnoIdContr = await _ateOCronometro(tester);
      expect(
        turnoIdContr,
        turnoIdPro,
        reason: 'os dois lados precisam olhar o MESMO turno (CA-3)',
      );
      await _amostraSincronia(
        tester,
        turnoId: turnoIdContr,
        lado: 'contratante',
      );
    },
  );
}
