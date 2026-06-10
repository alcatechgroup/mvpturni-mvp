// integration_test — STORY-063 (E2E browser real: cronômetro bilateral, CA-3);
// medição re-especificada na STORY-082 / IDR-031 (deflake do F-B-1).
//
// Same-origin (proxy + --web-launch-url, IDR-021) contra o BACKEND REAL, com o par
// exclusivo `*.cronometro.seed` (turno `ativo` há ~35min — LEITURA PURA, o seed só
// renova o check_in_at entre execuções).
//
// POR QUE A MEDIÇÃO MUDOU (IDR-031): a forma antiga comparava o display do app contra
// um `servidor_agora` buscado FRESCO a cada amostra, com tolerância ≤ 1s. O display do
// app carrega o erro de offset da ÚLTIMA sincronização do próprio app (ADR-017:
// `offset = agoraCliente − servidorAgora`), que sob carga embute a latência do poll. Um
// pico de latência em build debug (flutter drive/DDC) estourava a tolerância de 1s e
// flakeava o gate de release (F-B-1) — sem que a sincronia funcional tivesse falhado.
//
// FORMA NOVA (faithful + robusta a carga): o tempo decorrido EXIBIDO por um lado é
// `display = (agoraCliente − offset) − iniciadoEm`, logo o erro do lado contra o relógio
// LOCAL é `skew = display − (agoraCliente − iniciadoEm) = −offset`. A sincronia bilateral
// que o produto promete (ADR-017) é a DIFERENÇA dos dois lados:
//   median(skew_pro) − median(skew_contr) = offset_contr − offset_pro
//                                         = (skew de relógio + latência)_contr − (…)_pro.
// Como os dois lados rodam na MESMA máquina contra o MESMO servidor e ancoram no MESMO
// `iniciadoEm`, o skew de relógio cliente↔servidor é IDÊNTICO nos dois e CANCELA na
// diferença; resta só a diferença de latência entre as duas fases — sub-segundo em
// ambiente saudável e, sob carga uniforme, ambas as medianas deslocam juntas (a lentidão
// do ambiente é modo-comum). A mediana sobre ≥ 6 amostras/lado rejeita o pico transitório
// que flakeava. A âncora é lida UMA vez por lado (imutável enquanto `ativo`) — o laço de
// amostragem não faz rede, então não há SLA de fetch por amostra. Janela preservada:
// ≥ 12 amostras em ≥ 60s.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:turni_webapp/features/turnos/cronometro_service.dart';

import '../helpers/login_helper.dart';
import '../helpers/pump_app.dart';
import '../helpers/route_helper.dart';

const _profissionalSeed = 'profissional.cronometro.seed@turni.local';
const _contratanteSeed = 'contratante.cronometro.seed@turni.local';
const _senha = 'password';

/// Bilateral ≤ 2s (CA-3): diferença das medianas de skew entre os dois lados.
const _toleranciaBilateralS = 2;

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

/// Mediana inteira (arredonda para baixo no par — basta para a comparação ≤ 2s).
int _mediana(List<int> xs) {
  final ord = [...xs]..sort();
  return ord[ord.length ~/ 2];
}

/// Amostra o display [vezes] vezes com ~[entre] entre amostras (≥ 30s/lado cobrindo
/// vários ciclos do polling de ~5s). Para cada amostra calcula o skew do lado contra o
/// relógio LOCAL — `skew = display − (agoraCliente − iniciadoEm)` (= −offset do app) —
/// e devolve a lista. Sem rede no laço: a âncora [iniciadoEm] é fixa (imutável enquanto
/// `ativo`). Sanidade funcional aqui: display nunca regride (o relógio anda pra frente).
Future<List<int>> _amostraSkew(
  WidgetTester tester, {
  required String lado,
  required DateTime iniciadoEm,
  int vezes = 6,
  Duration entre = const Duration(seconds: 5),
}) async {
  final skews = <int>[];
  var anterior = -1;

  for (var i = 0; i < vezes; i++) {
    await _esperaReal(tester, entre);
    await tester.pump();

    final display = _displaySegundos(tester);
    final agoraCliente = DateTime.now().toUtc();
    final decorridoLocal = agoraCliente.difference(iniciadoEm).inSeconds;
    final skew = display - decorridoLocal;

    expect(
      display,
      greaterThanOrEqualTo(anterior),
      reason:
          '[$lado] amostra $i: display regrediu ($anterior → $display)s — '
          'o cronômetro tem de andar pra frente',
    );
    anterior = display;
    skews.add(skew);
    // ignore: avoid_print
    print(
      '[cronometro][$lado] amostra $i: display=${display}s '
      'decorridoLocal=${decorridoLocal}s skew=${skew}s',
    );
  }

  return skews;
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

/// Lê a âncora do turno UMA vez (imutável enquanto `ativo`) e confirma o estado.
Future<DateTime> _ancora(String turnoId, {required String lado}) async {
  final snap = await CronometroService().fetch(turnoId);
  expect(snap, isNotNull, reason: '[$lado] âncora indisponível');
  expect(snap!.estado, 'ativo', reason: '[$lado] turno precisa estar ativo');
  expect(
    snap.iniciadoEm,
    isNotNull,
    reason: '[$lado] turno ativo sem iniciado_em (âncora)',
  );
  return snap.iniciadoEm!;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('cronômetro bilateral vivo: profissional e contratante veem o MESMO tempo '
      '(≤ 2s, ≥ 12 amostras em ≥ 60s — CA-2/3/4)', (tester) async {
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
    final ancoraPro = await _ancora(turnoIdPro, lado: 'profissional');
    final skewPro = await _amostraSkew(
      tester,
      lado: 'profissional',
      iniciadoEm: ancoraPro,
    );

    // ── Lado 2: CONTRATANTE (mesmo turno) ──
    await pumpApp(tester);
    assertOnRoute(tester, '/login');
    await loginAs(tester, email: _contratanteSeed, password: _senha);
    await awaitRouteChange(tester, '/');
    await tester.pumpAndSettle();
    await pumpUntilFound(tester, find.byKey(const Key('minhas-vagas-screen')));

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
    final ancoraContr = await _ancora(turnoIdContr, lado: 'contratante');
    final skewContr = await _amostraSkew(
      tester,
      lado: 'contratante',
      iniciadoEm: ancoraContr,
    );

    // ── Veredito bilateral (CA-3) ──
    // skew = −offset do app; a sincronia entre os lados é a diferença das medianas.
    // O skew de relógio cliente↔servidor é idêntico nos dois (mesma máquina, mesma
    // âncora) e CANCELA; resta a diferença de latência, que a mediana estabiliza. A
    // lentidão do ambiente é modo-comum (CA-2) — não entra no veredito.
    final medPro = _mediana(skewPro);
    final medContr = _mediana(skewContr);
    final desvioBilateral = (medPro - medContr).abs();

    // ignore: avoid_print
    print(
      '[cronometro] median(skew_pro)=${medPro}s '
      'median(skew_contr)=${medContr}s '
      'desvio_bilateral=${desvioBilateral}s (limite ${_toleranciaBilateralS}s)',
    );

    expect(
      desvioBilateral,
      lessThanOrEqualTo(_toleranciaBilateralS),
      reason:
          'sincronia bilateral acima de ${_toleranciaBilateralS}s: '
          'median(skew_pro)=${medPro}s × median(skew_contr)=${medContr}s — '
          'os dois lados derivam da MESMA âncora (ADR-017); um desvio assim indica '
          'desync funcional, não lentidão de ambiente (que é modo-comum e cancela)',
    );
  });
}
