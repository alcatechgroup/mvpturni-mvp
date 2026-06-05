import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turni_webapp/ds/theme.dart';
import 'package:turni_webapp/ds/tokens.dart';
import 'package:turni_webapp/features/turnos/cronometro_card.dart';
import 'package:turni_webapp/features/turnos/cronometro_service.dart';
import 'package:turni_webapp/features/turnos/turno_detalhe_screen.dart';
import 'package:turni_webapp/features/turnos/turno_detalhe_service.dart';
import 'package:turni_webapp/features/turnos/turnos_service.dart'
    show TurnoEstadoResumo;

// STORY-063 — widget tests do CronometroCard (SCREEN-063).
// CA-2 (display HH:MM:SS/MM:SS + microcopy "Início previsto"/"Duração prevista"),
// CA-4 (tick LOCAL: o display avança sem nenhuma chamada de rede entre pollings),
// CA-5 (aguardando_checkout congela com a duração final), CA-6 (reconexão: silêncio
// < 30s; linha "Reconectando…" ≥ 30s; o display nunca congela), erro da 1ª
// sincronização com retry e saída do ciclo (onEstadoMudou).
//
// SEM pumpAndSettle: o card tem Timer.periodic de 1s — os testes avançam o tempo com
// pump(Duration) e o relógio do card via _Clock injetado (o DateTime.now() real não
// avança no tempo fake do tester).

class _Clock {
  _Clock(this.base);

  final DateTime base;
  Duration avancado = Duration.zero;

  DateTime call() => base.add(avancado);

  void avanca(Duration d) => avancado += d;
}

class _FakeCronoService extends CronometroService {
  _FakeCronoService(this.resposta);

  CronometroSnap? Function() resposta;
  int calls = 0;

  @override
  Future<CronometroSnap?> fetch(String turnoId) async {
    calls++;
    return resposta();
  }
}

void main() {
  // Relógio base dos testes (UTC, instante arbitrário estável).
  final base = DateTime.utc(2026, 6, 12, 20, 37, 34);

  CronometroSnap snap(
    _Clock clock, {
    String estado = 'ativo',
    Duration decorrido = const Duration(hours: 2, minutes: 35, seconds: 34),
    DateTime? encerradoEm,
  }) => CronometroSnap(
    estado: estado,
    iniciadoEm: clock().subtract(decorrido),
    encerradoEm: encerradoEm,
    servidorAgora: clock(),
    pollingSegundos: 5,
  );

  Widget app(Widget card) => MaterialApp(
    theme: buildLightTheme(),
    home: Scaffold(body: SingleChildScrollView(child: card)),
  );

  CronometroCard card(
    _Clock clock,
    _FakeCronoService svc, {
    String estadoRaw = 'ativo',
    Duration duracaoPrevista = const Duration(hours: 5),
    Future<void> Function()? onEstadoMudou,
  }) => CronometroCard(
    turnoId: 'u1',
    estadoRaw: estadoRaw,
    dataInicio: DateTime(2026, 6, 12, 18),
    dataFim: DateTime(2026, 6, 12, 18).add(duracaoPrevista),
    isDark: false,
    accent: TurniColors.accentLight,
    onEstadoMudou: onEstadoMudou ?? () async {},
    service: svc,
    now: clock.call,
  );

  String display(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const Key('cronometro-display'))).data!;

  Future<void> desmonta(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
  }

  testWidgets(
    'CA-2: sincroniza, mostra HH:MM:SS e a microcopy de início/duração previstos',
    (tester) async {
      final clock = _Clock(base);
      final svc = _FakeCronoService(() => snap(clock));

      await tester.pumpWidget(app(card(clock, svc)));
      expect(display(tester), '--:--:--'); // sincronizando (§4.1)

      await tester.pump(); // resolve o fetch
      expect(display(tester), '02:35:34');
      expect(
        tester.widget<Text>(find.byKey(const Key('cronometro-previsto'))).data,
        'Início previsto: 18:00\nDuração prevista: 5h',
      );
      expect(find.text('TURNO EM ANDAMENTO'), findsOneWidget);
      expect(find.byKey(const Key('cronometro-reconectando')), findsNothing);

      await desmonta(tester);
    },
  );

  testWidgets(
    'CA-4: tick LOCAL — o display avança a cada 1s sem nova chamada de rede',
    (tester) async {
      final clock = _Clock(base);
      final svc = _FakeCronoService(() => snap(clock));

      await tester.pumpWidget(app(card(clock, svc)));
      await tester.pump();
      expect(svc.calls, 1);

      clock.avanca(const Duration(seconds: 2));
      await tester.pump(const Duration(seconds: 2));
      expect(display(tester), '02:35:36');
      expect(svc.calls, 1, reason: 'nenhuma rede por tique (ADR-017)');

      // Na janela de 5s o polling reconcilia (1 chamada, não 5).
      clock.avanca(const Duration(seconds: 3));
      await tester.pump(const Duration(seconds: 3));
      expect(svc.calls, 2);

      await desmonta(tester);
    },
  );

  testWidgets('CA-2: turno curto usa MM:SS e promove ao cruzar 1h', (
    tester,
  ) async {
    final clock = _Clock(base);
    final svc = _FakeCronoService(
      () => snap(clock, decorrido: const Duration(minutes: 59, seconds: 58)),
    );

    await tester.pumpWidget(
      app(card(clock, svc, duracaoPrevista: const Duration(minutes: 45))),
    );
    await tester.pump();
    expect(display(tester), '59:58');

    // Cruza 1h → promove para HH:MM:SS (nunca "60:02").
    clock.avanca(const Duration(seconds: 4));
    await tester.pump(const Duration(seconds: 4));
    expect(display(tester), '01:00:02');

    await desmonta(tester);
  });

  testWidgets(
    'CA-5: aguardando_checkout congela na duração final e para o polling',
    (tester) async {
      final clock = _Clock(base);
      final svc = _FakeCronoService(
        () => snap(
          clock,
          estado: 'aguardando_checkout',
          decorrido: const Duration(hours: 5, minutes: 2, seconds: 13),
          encerradoEm: clock(), // solicitação do check-out = agora
        ),
      );

      await tester.pumpWidget(
        app(card(clock, svc, estadoRaw: 'aguardando_checkout')),
      );
      await tester.pump();

      expect(display(tester), '05:02:13');
      expect(
        find.text('Aguardando check-out — duração final: 05:02:13'),
        findsOneWidget,
      );
      expect(find.text('AGUARDANDO CHECK-OUT'), findsOneWidget);
      expect(find.byKey(const Key('cronometro-previsto')), findsNothing);

      // Congelado: o tempo passa e o display NÃO avança; o polling parou.
      final chamadas = svc.calls;
      clock.avanca(const Duration(seconds: 12));
      await tester.pump(const Duration(seconds: 12));
      expect(display(tester), '05:02:13');
      expect(svc.calls, chamadas);

      await desmonta(tester);
    },
  );

  testWidgets(
    'CA-5 (degrade pré-064): sem encerrado_em congela no último decorrido conhecido',
    (tester) async {
      final clock = _Clock(base);
      final svc = _FakeCronoService(
        () => snap(
          clock,
          estado: 'aguardando_checkout',
          decorrido: const Duration(hours: 3),
        ),
      );

      await tester.pumpWidget(
        app(card(clock, svc, estadoRaw: 'aguardando_checkout')),
      );
      await tester.pump();

      expect(display(tester), '03:00:00');
      clock.avanca(const Duration(seconds: 9));
      await tester.pump(const Duration(seconds: 9));
      expect(display(tester), '03:00:00', reason: 'congelado, não tica');

      await desmonta(tester);
    },
  );

  testWidgets(
    'CA-6: falha de polling < 30s é silêncio; ≥ 30s mostra "Reconectando…" '
    'com o display SEMPRE ticando; sucesso esconde a linha',
    (tester) async {
      final clock = _Clock(base);
      var offline = false;
      final svc = _FakeCronoService(() => offline ? null : snap(clock));

      await tester.pumpWidget(app(card(clock, svc)));
      await tester.pump();
      expect(display(tester), '02:35:34');

      // Cai a rede: 20s sem reconciliar → silêncio absoluto (§4.3).
      offline = true;
      clock.avanca(const Duration(seconds: 20));
      await tester.pump(const Duration(seconds: 20));
      expect(find.byKey(const Key('cronometro-reconectando')), findsNothing);
      expect(display(tester), '02:35:54', reason: 'tick local segue');

      // 31s+ sem sucesso → linha de reconexão; display continua avançando.
      clock.avanca(const Duration(seconds: 15));
      await tester.pump(const Duration(seconds: 15));
      expect(find.byKey(const Key('cronometro-reconectando')), findsOneWidget);
      expect(
        find.text('Reconectando… O tempo continua valendo.'),
        findsOneWidget,
      );
      expect(display(tester), '02:36:09');

      // Rede volta: próximo polling reconcilia e a linha some.
      offline = false;
      clock.avanca(const Duration(seconds: 5));
      await tester.pump(const Duration(seconds: 5));
      expect(find.byKey(const Key('cronometro-reconectando')), findsNothing);

      await desmonta(tester);
    },
  );

  testWidgets('erro da 1ª sincronização: card mostra o erro com retry (§4.5)', (
    tester,
  ) async {
    final clock = _Clock(base);
    var offline = true;
    final svc = _FakeCronoService(() => offline ? null : snap(clock));

    await tester.pumpWidget(app(card(clock, svc)));
    await tester.pump();

    expect(find.byKey(const Key('cronometro-erro')), findsOneWidget);
    expect(
      find.text(
        'Não foi possível carregar o cronômetro. Verifique sua conexão.',
      ),
      findsOneWidget,
    );

    offline = false;
    await tester.tap(find.byKey(const Key('cronometro-retry-btn')));
    await tester.pump();

    expect(find.byKey(const Key('cronometro-erro')), findsNothing);
    expect(display(tester), '02:35:34');

    await desmonta(tester);
  });

  testWidgets(
    'saída do ciclo (ex.: finalizado): timers param e onEstadoMudou dispara 1x',
    (tester) async {
      final clock = _Clock(base);
      var estado = 'ativo';
      var avisos = 0;
      final svc = _FakeCronoService(() => snap(clock, estado: estado));

      await tester.pumpWidget(
        app(card(clock, svc, onEstadoMudou: () async => avisos++)),
      );
      await tester.pump();
      expect(avisos, 0);

      estado = 'finalizado';
      clock.avanca(const Duration(seconds: 5));
      await tester.pump(const Duration(seconds: 5));
      expect(avisos, 1);

      // Mais 10s: nenhum polling novo, nenhum aviso repetido.
      final chamadas = svc.calls;
      clock.avanca(const Duration(seconds: 10));
      await tester.pump(const Duration(seconds: 10));
      expect(svc.calls, chamadas);
      expect(avisos, 1);

      await desmonta(tester);
    },
  );

  // ───────────── Integração com a tela do detalhe (SCREEN-063 §3.1) ─────────────

  group('TurnoDetalheScreen', () {
    TurnoDetalhe turno(String estadoRaw, TurnoEstadoResumo estado) =>
        TurnoDetalhe(
          id: 'u1',
          funcao: 'Garçom',
          dataInicio: DateTime(2026, 6, 12, 18),
          dataFim: DateTime(2026, 6, 12, 23),
          estado: estado,
          estadoRaw: estadoRaw,
          valor: 200.0,
          estabelecimento: 'Bar do Zé',
          taxaTurni: null,
          totalContratante: null,
          profissional: null,
          aceite: null,
          timeline: const [],
        );

    Widget tela(TurnoDetalhe t, _FakeCronoService crono) => MaterialApp(
      theme: buildLightTheme(),
      home: TurnoDetalheScreen(
        turnoId: 'u1',
        service: _FakeDetalheService(t),
        cronometroService: crono,
      ),
    );

    testWidgets('estado ativo monta o card logo abaixo do header', (
      tester,
    ) async {
      final clock = _Clock(base);
      final crono = _FakeCronoService(() => snap(clock));

      await tester.pumpWidget(
        tela(turno('ativo', TurnoEstadoResumo.ativo), crono),
      );
      await tester.pump(); // fetch do detalhe
      await tester.pump(); // fetch do cronômetro

      expect(find.byKey(const Key('cronometro-card')), findsOneWidget);
      expect(find.byKey(const Key('cronometro-display')), findsOneWidget);
      // A área de ações segue com o placeholder da 060 (o check-out é a 064).
      expect(find.byKey(const Key('turno-detalhe-acoes')), findsOneWidget);

      await desmonta(tester);
    });

    testWidgets('aguardando_checkout monta o card congelado', (tester) async {
      final clock = _Clock(base);
      final crono = _FakeCronoService(
        () => snap(
          clock,
          estado: 'aguardando_checkout',
          decorrido: const Duration(hours: 5),
          encerradoEm: clock(),
        ),
      );

      await tester.pumpWidget(
        tela(
          turno('aguardando_checkout', TurnoEstadoResumo.aguardandoCheckout),
          crono,
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const Key('cronometro-card')), findsOneWidget);
      expect(
        find.byKey(const Key('cronometro-aguardando-checkout')),
        findsOneWidget,
      );

      await desmonta(tester);
    });

    testWidgets('demais estados NÃO montam o card (ex.: confirmado)', (
      tester,
    ) async {
      final clock = _Clock(base);
      final crono = _FakeCronoService(() => snap(clock));

      await tester.pumpWidget(
        tela(turno('confirmado', TurnoEstadoResumo.confirmado), crono),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const Key('cronometro-card')), findsNothing);
      expect(crono.calls, 0);

      await desmonta(tester);
    });
  });
}

class _FakeDetalheService extends TurnoDetalheService {
  _FakeDetalheService(this.turno);

  final TurnoDetalhe turno;

  @override
  Future<TurnoDetalheResult> fetch(String id) async =>
      TurnoDetalheSuccess(turno);
}
