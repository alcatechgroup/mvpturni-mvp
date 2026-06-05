import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:turni_webapp/ds/theme.dart';
import 'package:turni_webapp/features/turnos/pin_checkin_service.dart';
import 'package:turni_webapp/features/turnos/turno_detalhe_screen.dart';
import 'package:turni_webapp/features/turnos/turno_detalhe_service.dart';
import 'package:turni_webapp/features/turnos/turnos_service.dart'
    show TurnoEstadoResumo;

// STORY-061 / SCREEN-061 — widget tests da área de ações do check-in (CA-1: janela
// aberta/antes/depois com microcopy; CA-8 visual: contratante sem botão), do gesto de
// geração (CA-2: loading "um gesto só"; erro com retry) e da tela do PIN (CA-5: PIN
// ≥64pt, microcopy fixa, nota de geofencing nas 3 variantes, cancelar volta a confirmado).

class _FakeDetalheService extends TurnoDetalheService {
  _FakeDetalheService(this.result);

  TurnoDetalheResult Function() result;
  int calls = 0;

  @override
  Future<TurnoDetalheResult> fetch(String id) async {
    calls++;
    return result();
  }
}

class _FakePinService extends PinCheckinService {
  _FakePinService({this.onGerar, this.onCancelar});

  Future<PinGeracaoResult> Function()? onGerar;
  Future<PinCancelResult> Function()? onCancelar;
  int geracoes = 0;
  int cancelamentos = 0;

  @override
  Future<PinGeracaoResult> gerar(String turnoId) async {
    geracoes++;
    return onGerar!();
  }

  @override
  Future<PinCancelResult> cancelar(String turnoId) async {
    cancelamentos++;
    return onCancelar!();
  }
}

GeofencingCheckin _geoOk() =>
    const GeofencingCheckin(ok: true, distanciaMetros: 23.0, razao: null);

TurnoDetalhe _turno({
  String estadoRaw = 'confirmado',
  TurnoEstadoResumo estado = TurnoEstadoResumo.confirmado,
  DateTime? janelaAbre,
  DateTime? janelaFecha,
  double? totalContratante,
  List<TimelineEvento>? timeline,
}) => TurnoDetalhe(
  id: 'u1',
  funcao: 'Garçom',
  dataInicio: DateTime(2026, 6, 12, 18),
  dataFim: DateTime(2026, 6, 12, 23),
  estado: estado,
  estadoRaw: estadoRaw,
  valor: 200.0,
  estabelecimento: 'Bar do Zé',
  taxaTurni: totalContratante == null ? null : 30.0,
  totalContratante: totalContratante,
  profissional: totalContratante == null ? null : 'Júlia Santos',
  aceite: null,
  timeline: timeline ?? const [],
  checkinJanela: janelaAbre == null
      ? null
      : CheckinJanela(abreEm: janelaAbre, fechaEm: janelaFecha!),
);

/// Turno confirmado com a janela ABERTA agora (abriu há 5min, fecha em 2h).
TurnoDetalhe _turnoNaJanela() => _turno(
  janelaAbre: DateTime.now().subtract(const Duration(minutes: 5)),
  janelaFecha: DateTime.now().add(const Duration(hours: 2)),
);

Widget _app(_FakeDetalheService svc, {_FakePinService? pin}) {
  final router = GoRouter(
    initialLocation: '/turnos/u1',
    routes: [
      GoRoute(
        path: '/turnos/:id',
        builder: (_, _) =>
            TurnoDetalheScreen(turnoId: 'u1', service: svc, pinService: pin),
      ),
      GoRoute(
        path: '/profissional/turnos',
        builder: (_, _) => const Scaffold(body: Text('LISTA PRO')),
      ),
      GoRoute(
        path: '/contratante/turnos',
        builder: (_, _) => const Scaffold(body: Text('LISTA CONTR')),
      ),
    ],
  );
  return MaterialApp.router(theme: buildLightTheme(), routerConfig: router);
}

void main() {
  // ───────────────── CA-1 — estados da janela na área de ações ─────────────────

  testWidgets('janela aberta: título, apoio e botão HABILITADO', (
    tester,
  ) async {
    final svc = _FakeDetalheService(
      () => TurnoDetalheSuccess(_turnoNaJanela()),
    );
    await tester.pumpWidget(_app(svc));
    await tester.pumpAndSettle();

    expect(find.text('Chegou ao local?'), findsOneWidget);
    expect(
      find.text(
        'Gere o PIN de check-in e mostre ao contratante para confirmar sua chegada.',
      ),
      findsOneWidget,
    );
    final btn = tester.widget<FilledButton>(
      find.byKey(const Key('turno-pin-gerar-btn')),
    );
    expect(btn.onPressed, isNotNull);
    // O placeholder da 060 saiu de cena para o profissional em confirmado.
    expect(find.text('Nenhuma ação disponível no momento'), findsNothing);
  });

  testWidgets(
    'antes da janela: botão desabilitado + microcopy com horário e minutos',
    (tester) async {
      // Janela abre daqui a 1h (17:30 não — usamos horário derivado do payload).
      final abre = DateTime.now().add(const Duration(hours: 1));
      final svc = _FakeDetalheService(
        () => TurnoDetalheSuccess(
          _turno(
            janelaAbre: abre,
            janelaFecha: abre.add(const Duration(minutes: 150)),
          ),
        ),
      );
      await tester.pumpWidget(_app(svc));
      await tester.pumpAndSettle();

      expect(find.text('Ainda não dá para fazer o check-in'), findsOneWidget);
      final msg = tester
          .widget<Text>(find.byKey(const Key('turno-pin-janela-msg')))
          .data!;
      expect(msg, contains('O PIN pode ser gerado a partir das'));
      expect(msg, contains('min antes do início'));

      final btn = tester.widget<FilledButton>(
        find.byKey(const Key('turno-pin-gerar-btn')),
      );
      expect(btn.onPressed, isNull);
    },
  );

  testWidgets(
    'depois da janela: botão desabilitado + microcopy de encerramento',
    (tester) async {
      final abre = DateTime.now().subtract(const Duration(hours: 3));
      final svc = _FakeDetalheService(
        () => TurnoDetalheSuccess(
          _turno(
            janelaAbre: abre,
            janelaFecha: DateTime.now().subtract(const Duration(minutes: 30)),
          ),
        ),
      );
      await tester.pumpWidget(_app(svc));
      await tester.pumpAndSettle();

      expect(find.text('O período de check-in encerrou'), findsOneWidget);
      final msg = tester
          .widget<Text>(find.byKey(const Key('turno-pin-janela-msg')))
          .data!;
      expect(msg, contains('O PIN podia ser gerado até as'));
      expect(msg, contains('Fale com o contratante'));

      final btn = tester.widget<FilledButton>(
        find.byKey(const Key('turno-pin-gerar-btn')),
      );
      expect(btn.onPressed, isNull);
    },
  );

  testWidgets(
    'aguardando_checkin: Gerar novo PIN + Cancelar PIN (pós-refresh §4.7)',
    (tester) async {
      final svc = _FakeDetalheService(
        () => TurnoDetalheSuccess(
          _turno(
            estadoRaw: 'aguardando_checkin',
            estado: TurnoEstadoResumo.aguardandoCheckin,
            janelaAbre: DateTime.now().subtract(const Duration(minutes: 5)),
            janelaFecha: DateTime.now().add(const Duration(hours: 2)),
          ),
        ),
      );
      await tester.pumpWidget(_app(svc));
      await tester.pumpAndSettle();

      expect(find.text('Aguardando validação do contratante'), findsOneWidget);
      expect(
        find.text(
          'Perdeu o PIN de vista? Gere um novo — o anterior deixa de valer.',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('turno-pin-regen-btn')), findsOneWidget);
      expect(find.text('Gerar novo PIN'), findsOneWidget);
      expect(find.byKey(const Key('turno-pin-cancelar-btn')), findsOneWidget);
      expect(find.text('Não chegou ainda? Cancelar PIN'), findsOneWidget);
    },
  );

  testWidgets(
    'CA-8 visual: contratante segue com o placeholder (sem botão de PIN)',
    (tester) async {
      final svc = _FakeDetalheService(
        () => TurnoDetalheSuccess(_turno(totalContratante: 230.0)),
      );
      await tester.pumpWidget(_app(svc));
      await tester.pumpAndSettle();

      expect(find.text('Nenhuma ação disponível no momento'), findsOneWidget);
      expect(find.byKey(const Key('turno-pin-gerar-btn')), findsNothing);
    },
  );

  // ───────────────── CA-2 — gesto de geração ─────────────────

  testWidgets(
    'toque em gerar: loading "Confirmando sua localização…" e push da tela do PIN',
    (tester) async {
      final completer = Completer<PinGeracaoResult>();
      final pin = _FakePinService(onGerar: () => completer.future);
      final svc = _FakeDetalheService(
        () => TurnoDetalheSuccess(_turnoNaJanela()),
      );
      await tester.pumpWidget(_app(svc, pin: pin));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('turno-pin-gerar-btn')));
      await tester.pump();

      expect(find.text('Confirmando sua localização…'), findsOneWidget);

      completer.complete(PinGerado(pin: '4702', geofencing: _geoOk()));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('pin-checkin-screen')), findsOneWidget);
      expect(find.text('4702'), findsOneWidget);
      expect(pin.geracoes, 1);
    },
  );

  testWidgets('erro na geração: banner + retry refaz o gesto completo', (
    tester,
  ) async {
    var tentativa = 0;
    final pin = _FakePinService(
      onGerar: () async => ++tentativa == 1
          ? PinGeracaoErro()
          : PinGerado(pin: '7031', geofencing: _geoOk()),
    );
    final svc = _FakeDetalheService(
      () => TurnoDetalheSuccess(_turnoNaJanela()),
    );
    await tester.pumpWidget(_app(svc, pin: pin));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('turno-pin-gerar-btn')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('turno-pin-erro-banner')), findsOneWidget);
    expect(
      find.text('Não foi possível gerar o PIN. Verifique sua conexão.'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('turno-pin-retry-btn')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('pin-checkin-screen')), findsOneWidget);
    expect(pin.geracoes, 2);
  });

  testWidgets(
    'fora da janela no servidor (422): recarrega o detalhe — sem banner de erro',
    (tester) async {
      final pin = _FakePinService(
        onGerar: () async => PinForaDaJanela(abreEm: null, fechaEm: null),
      );
      final svc = _FakeDetalheService(
        () => TurnoDetalheSuccess(_turnoNaJanela()),
      );
      await tester.pumpWidget(_app(svc, pin: pin));
      await tester.pumpAndSettle();
      final fetchesAntes = svc.calls;

      await tester.tap(find.byKey(const Key('turno-pin-gerar-btn')));
      await tester.pumpAndSettle();

      // Servidor é a fonte de verdade (relógio do device pode estar errado):
      // recarrega para reapresentar a janela real; não é erro de rede.
      expect(svc.calls, greaterThan(fetchesAntes));
      expect(find.byKey(const Key('turno-pin-erro-banner')), findsNothing);
    },
  );

  // ───────────────── CA-5 — tela do PIN ─────────────────

  Future<void> abrirTelaDoPin(
    WidgetTester tester, {
    required GeofencingCheckin geo,
    _FakePinService? pinSvc,
  }) async {
    final pin =
        pinSvc ??
        _FakePinService(
          onGerar: () async => PinGerado(pin: '4702', geofencing: geo),
        );
    pin.onGerar ??= () async => PinGerado(pin: '4702', geofencing: geo);
    final svc = _FakeDetalheService(
      () => TurnoDetalheSuccess(_turnoNaJanela()),
    );
    await tester.pumpWidget(_app(svc, pin: pin));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('turno-pin-gerar-btn')));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'PIN em tipografia ≥64pt, instrução fixa do CA-5 e aviso de efemeridade',
    (tester) async {
      await abrirTelaDoPin(tester, geo: _geoOk());

      expect(find.byKey(const Key('pin-checkin-screen')), findsOneWidget);
      expect(find.text('PIN de check-in'), findsWidgets); // AppBar
      expect(find.text('Garçom · Bar do Zé'), findsOneWidget);
      expect(
        find.text('Mostre este PIN ao contratante para validar a chegada'),
        findsOneWidget,
      );

      final codigo = tester.widget<Text>(
        find.byKey(const Key('pin-checkin-codigo')),
      );
      expect(codigo.data, '4702');
      expect(codigo.style!.fontSize, greaterThanOrEqualTo(64));

      expect(
        find.text('Se sair desta tela, será preciso gerar um novo PIN.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('nota de geofencing — ok: localização confirmada', (
    tester,
  ) async {
    await abrirTelaDoPin(tester, geo: _geoOk());

    expect(find.byKey(const Key('pin-checkin-geo-nota')), findsOneWidget);
    expect(
      find.textContaining('Localização confirmada — você está no local.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'nota de geofencing — fora do raio: distância + aviso ao contratante',
    (tester) async {
      await abrirTelaDoPin(
        tester,
        geo: const GeofencingCheckin(
          ok: false,
          distanciaMetros: 230.4,
          razao: 'fora_do_raio',
        ),
      );

      expect(
        find.textContaining('Você está a cerca de 230 m do estabelecimento.'),
        findsOneWidget,
      );
      expect(
        find.textContaining('O contratante verá esse aviso ao validar.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('nota de geofencing — sem captura: razão humana', (tester) async {
    await abrirTelaDoPin(
      tester,
      geo: const GeofencingCheckin(
        ok: false,
        distanciaMetros: null,
        razao: 'permissao_negada',
      ),
    );

    expect(
      find.textContaining(
        'Sua localização não pôde ser confirmada (permissão negada).',
      ),
      findsOneWidget,
    );
  });

  testWidgets('cancelar na tela do PIN: sucesso volta ao detalhe e recarrega', (
    tester,
  ) async {
    final pin = _FakePinService(onCancelar: () async => PinCancelado());
    await abrirTelaDoPin(tester, geo: _geoOk(), pinSvc: pin);

    await tester.tap(find.byKey(const Key('pin-checkin-cancelar-btn')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('pin-checkin-screen')), findsNothing);
    expect(find.byKey(const Key('turno-detalhe-screen')), findsOneWidget);
    expect(pin.cancelamentos, 1);
  });

  testWidgets('cancelar com erro: banner na tela do PIN, permanece nela', (
    tester,
  ) async {
    final pin = _FakePinService(onCancelar: () async => PinCancelErro());
    await abrirTelaDoPin(tester, geo: _geoOk(), pinSvc: pin);

    await tester.tap(find.byKey(const Key('pin-checkin-cancelar-btn')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('pin-checkin-screen')), findsOneWidget);
    expect(find.text('Não foi possível cancelar o PIN.'), findsOneWidget);
  });

  testWidgets('voltar da tela do PIN cai no detalhe (PIN efêmero §4.7)', (
    tester,
  ) async {
    await abrirTelaDoPin(tester, geo: _geoOk());

    await tester.tap(find.byKey(const Key('pin-checkin-voltar')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('pin-checkin-screen')), findsNothing);
    expect(find.byKey(const Key('turno-detalhe-screen')), findsOneWidget);
  });

  // ───────────────── timeline (§4.10) ─────────────────

  testWidgets(
    'timeline: checkin_solicitado com nota de geofencing e checkin_cancelado',
    (tester) async {
      final svc = _FakeDetalheService(
        () => TurnoDetalheSuccess(
          _turno(
            janelaAbre: DateTime.now().subtract(const Duration(minutes: 5)),
            janelaFecha: DateTime.now().add(const Duration(hours: 2)),
            timeline: [
              TimelineEvento(
                id: 'e2',
                tipo: TimelineEventoTipo.checkinCancelado,
                ocorridoEm: DateTime(2026, 6, 12, 18, 2),
              ),
              TimelineEvento(
                id: 'e1',
                tipo: TimelineEventoTipo.checkinSolicitado,
                ocorridoEm: DateTime(2026, 6, 12, 17, 58),
                geofencing: const GeofencingCheckin(
                  ok: false,
                  distanciaMetros: 230.0,
                  razao: 'fora_do_raio',
                ),
              ),
            ],
          ),
        ),
      );
      await tester.pumpWidget(_app(svc));
      await tester.pumpAndSettle();

      expect(find.text('PIN de check-in gerado'), findsOneWidget);
      expect(
        find.text('Fora do raio do estabelecimento (a 230 m).'),
        findsOneWidget,
      );
      expect(find.text('PIN de check-in cancelado'), findsOneWidget);
      expect(
        find.text('Cancelado pelo profissional antes da validação.'),
        findsOneWidget,
      );
    },
  );
}
