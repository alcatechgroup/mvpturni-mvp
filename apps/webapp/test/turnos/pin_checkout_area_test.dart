import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:turni_webapp/ds/theme.dart';
import 'package:turni_webapp/features/turnos/cronometro_service.dart';
import 'package:turni_webapp/features/turnos/pin_checkin_service.dart';
import 'package:turni_webapp/features/turnos/pin_checkout_service.dart';
import 'package:turni_webapp/features/turnos/turno_detalhe_screen.dart';
import 'package:turni_webapp/features/turnos/turno_detalhe_service.dart';
import 'package:turni_webapp/features/turnos/turnos_service.dart'
    show TurnoEstadoResumo;

// STORY-064 / SCREEN-064 §3.1/3.2 — área de geração do PIN de check-out pelo
// PROFISSIONAL no detalhe do turno: em `ativo` o botão é SEMPRE habilitado (CA-1 —
// sem janela horária); gerar navega para a tela do PIN SEM nota de geofencing
// (CA-2 — captura silenciosa); em `aguardando_checkout` Gerar novo PIN + Cancelar
// (§4.4/4.6 — cancelar volta a `ativo` e recarrega). RBAC visual: contratante em
// `ativo` segue com o placeholder.
//
// SEM pumpAndSettle: o detalhe em ativo/aguardando_checkout monta o CronometroCard
// (Timer.periodic de 1s) — os testes usam pump() explícito e desmontam no final.

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

class _FakeCronoService extends CronometroService {
  _FakeCronoService(this.estado);

  String estado;

  @override
  Future<CronometroSnap?> fetch(String turnoId) async => CronometroSnap(
    estado: estado,
    iniciadoEm: DateTime.now().toUtc().subtract(const Duration(hours: 5)),
    encerradoEm: estado == 'ativo' ? null : DateTime.now().toUtc(),
    servidorAgora: DateTime.now().toUtc(),
    pollingSegundos: 5,
  );
}

class _FakePinCheckoutService extends PinCheckoutService {
  PinGeracaoResult Function()? aoGerar;
  PinCancelResult Function()? aoCancelar;
  int geracoes = 0;
  int cancelamentos = 0;

  @override
  Future<PinGeracaoResult> gerar(String turnoId) async {
    geracoes++;
    return aoGerar!();
  }

  @override
  Future<PinCancelResult> cancelar(String turnoId) async {
    cancelamentos++;
    return aoCancelar!();
  }
}

TurnoDetalhe _turnoProfissional({String estadoRaw = 'ativo'}) => TurnoDetalhe(
  id: 'u1',
  funcao: 'Garçom',
  dataInicio: DateTime(2026, 6, 12, 18),
  dataFim: DateTime(2026, 6, 12, 23),
  estado: estadoRaw == 'ativo'
      ? TurnoEstadoResumo.ativo
      : TurnoEstadoResumo.aguardandoCheckout,
  estadoRaw: estadoRaw,
  valor: 200.0,
  estabelecimento: 'Bar do Zé',
  taxaTurni: null,
  totalContratante: null, // payload do PROFISSIONAL
  profissional: null,
  aceite: null,
  timeline: const [],
);

TurnoDetalhe _turnoContratanteAtivo() => TurnoDetalhe(
  id: 'u1',
  funcao: 'Garçom',
  dataInicio: DateTime(2026, 6, 12, 18),
  dataFim: DateTime(2026, 6, 12, 23),
  estado: TurnoEstadoResumo.ativo,
  estadoRaw: 'ativo',
  valor: 200.0,
  estabelecimento: 'Bar do Zé',
  taxaTurni: 30.0,
  totalContratante: 230.0,
  profissional: 'Júlia Santos',
  aceite: null,
  timeline: const [],
);

Widget _app(
  _FakeDetalheService svc,
  _FakePinCheckoutService pin, {
  String estadoCrono = 'ativo',
}) {
  final router = GoRouter(
    initialLocation: '/turnos/u1',
    routes: [
      GoRoute(
        path: '/turnos/:id',
        builder: (_, _) => TurnoDetalheScreen(
          turnoId: 'u1',
          service: svc,
          pinCheckoutService: pin,
          cronometroService: _FakeCronoService(estadoCrono),
        ),
      ),
      GoRoute(
        path: '/profissional/turnos',
        builder: (_, _) => const Scaffold(body: Text('LISTA PROF')),
      ),
    ],
  );
  return MaterialApp.router(theme: buildLightTheme(), routerConfig: router);
}

Future<void> _monta(WidgetTester tester, Widget app) async {
  await tester.pumpWidget(app);
  await tester.pump(); // fetch do detalhe
  await tester.pump(); // fetch do cronômetro
}

Future<void> _desmonta(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
}

void main() {
  testWidgets(
    'CA-1: profissional em ativo vê "Terminou o turno?" com o botão SEMPRE habilitado',
    (tester) async {
      final svc = _FakeDetalheService(
        () => TurnoDetalheSuccess(_turnoProfissional()),
      );
      await _monta(tester, _app(svc, _FakePinCheckoutService()));

      expect(find.text('Terminou o turno?'), findsOneWidget);
      expect(
        find.text(
          'Gere o PIN de check-out e mostre ao contratante para confirmar o '
          'fim do turno.',
        ),
        findsOneWidget,
      );
      final botao = tester.widget<FilledButton>(
        find.byKey(const Key('turno-checkout-gerar-btn')),
      );
      expect(botao.enabled, isTrue);
      expect(find.text('Nenhuma ação disponível no momento'), findsNothing);

      await _desmonta(tester);
    },
  );

  testWidgets(
    'CA-2: gerar → tela do PIN com o código e SEM nota de geofencing (silencioso)',
    (tester) async {
      final svc = _FakeDetalheService(
        () => TurnoDetalheSuccess(_turnoProfissional()),
      );
      final pin = _FakePinCheckoutService()
        ..aoGerar = () => PinGerado(
          pin: '8341',
          geofencing: const GeofencingCheckin(
            ok: false,
            distanciaMetros: 350.0,
            razao: 'fora_do_raio',
          ),
        );
      await _monta(tester, _app(svc, pin));

      await tester.ensureVisible(
        find.byKey(const Key('turno-checkout-gerar-btn')),
      );
      await tester.tap(find.byKey(const Key('turno-checkout-gerar-btn')));
      await tester.pump(); // resolve o POST
      await tester.pump(const Duration(milliseconds: 400)); // navegação

      expect(find.byKey(const Key('pin-checkout-screen')), findsOneWidget);
      expect(find.text('8341'), findsOneWidget);
      expect(
        find.text('Mostre este PIN ao contratante para validar o fim do turno'),
        findsOneWidget,
      );
      // Mesmo com geofencing fora do raio, NENHUMA nota aparece (§4.3 — o
      // registro vai para a timeline, não para a tela).
      expect(find.byKey(const Key('pin-checkin-geo-nota')), findsNothing);
      expect(find.textContaining('Localização'), findsNothing);

      await _desmonta(tester);
    },
  );

  testWidgets('erro na geração → banner com retry; estado não muda', (
    tester,
  ) async {
    final svc = _FakeDetalheService(
      () => TurnoDetalheSuccess(_turnoProfissional()),
    );
    final pin = _FakePinCheckoutService()..aoGerar = () => PinGeracaoErro();
    await _monta(tester, _app(svc, pin));

    await tester.ensureVisible(
      find.byKey(const Key('turno-checkout-gerar-btn')),
    );
    await tester.tap(find.byKey(const Key('turno-checkout-gerar-btn')));
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('turno-checkout-erro-banner')), findsOneWidget);
    expect(
      find.text('Não foi possível gerar o PIN. Verifique sua conexão.'),
      findsOneWidget,
    );

    // Retry refaz o gesto completo.
    pin.aoGerar = () => PinGerado(
      pin: '8341',
      geofencing: const GeofencingCheckin(
        ok: true,
        distanciaMetros: 18.0,
        razao: null,
      ),
    );
    await tester.tap(find.byKey(const Key('turno-checkout-retry-btn')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(pin.geracoes, 2);
    expect(find.byKey(const Key('pin-checkout-screen')), findsOneWidget);

    await _desmonta(tester);
  });

  testWidgets(
    '§4.4: aguardando_checkout mostra Gerar novo PIN + Cancelar; cancelar recarrega',
    (tester) async {
      final svc = _FakeDetalheService(
        () => TurnoDetalheSuccess(
          _turnoProfissional(estadoRaw: 'aguardando_checkout'),
        ),
      );
      final pin = _FakePinCheckoutService()..aoCancelar = () => PinCancelado();
      await _monta(tester, _app(svc, pin, estadoCrono: 'aguardando_checkout'));

      expect(find.text('Aguardando validação do contratante'), findsOneWidget);
      expect(find.byKey(const Key('turno-checkout-regen-btn')), findsOneWidget);

      final fetchesAntes = svc.calls;
      await tester.ensureVisible(
        find.byKey(const Key('turno-checkout-cancelar-btn')),
      );
      await tester.tap(find.byKey(const Key('turno-checkout-cancelar-btn')));
      await tester.pump();
      await tester.pump();

      expect(pin.cancelamentos, 1);
      expect(svc.calls, greaterThan(fetchesAntes)); // recarregou a verdade

      await _desmonta(tester);
    },
  );

  testWidgets(
    '§4.6: cancelar na tela do PIN volta ao detalhe (cronômetro retoma via reload)',
    (tester) async {
      final svc = _FakeDetalheService(
        () => TurnoDetalheSuccess(_turnoProfissional()),
      );
      final pin = _FakePinCheckoutService();
      pin.aoGerar = () => PinGerado(
        pin: '8341',
        geofencing: const GeofencingCheckin(
          ok: true,
          distanciaMetros: 18.0,
          razao: null,
        ),
      );
      pin.aoCancelar = () => PinCancelado();
      await _monta(tester, _app(svc, pin));

      await tester.ensureVisible(
        find.byKey(const Key('turno-checkout-gerar-btn')),
      );
      await tester.tap(find.byKey(const Key('turno-checkout-gerar-btn')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const Key('pin-checkout-screen')), findsOneWidget);

      await tester.tap(find.byKey(const Key('pin-checkout-cancelar-btn')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400)); // pop conclui

      expect(find.byKey(const Key('pin-checkout-screen')), findsNothing);
      expect(pin.cancelamentos, 1);

      await _desmonta(tester);
    },
  );

  testWidgets('RBAC visual: contratante em ativo vê o placeholder da 060', (
    tester,
  ) async {
    final svc = _FakeDetalheService(
      () => TurnoDetalheSuccess(_turnoContratanteAtivo()),
    );
    await _monta(tester, _app(svc, _FakePinCheckoutService()));

    expect(find.byKey(const Key('turno-checkout-gerar-btn')), findsNothing);
    expect(find.text('Nenhuma ação disponível no momento'), findsOneWidget);

    await _desmonta(tester);
  });
}
