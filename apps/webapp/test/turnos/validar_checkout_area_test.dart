import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:turni_webapp/ds/theme.dart';
import 'package:turni_webapp/features/turnos/cronometro_service.dart';
import 'package:turni_webapp/features/turnos/turno_detalhe_screen.dart';
import 'package:turni_webapp/features/turnos/turno_detalhe_service.dart';
import 'package:turni_webapp/features/turnos/turnos_service.dart'
    show TurnoEstadoResumo;
import 'package:turni_webapp/features/turnos/validar_checkin_service.dart';
import 'package:turni_webapp/features/turnos/validar_checkout_service.dart';

// STORY-064 / SCREEN-064 §3.3/3.4 — área de validação do check-out pelo CONTRATANTE
// no detalhe (`aguardando_checkout`): input de 4 dígitos + Validar (CA-3), SEM card
// de aviso de geofencing (diferença intencional da 062 — estória), erro inline do PIN
// errado, expirado por 3 tentativas DEVOLVE A `ativo` (CA-4 — cronômetro retoma),
// rate limit, erro de rede com retry, recusa com dialog + motivo opcional (CA-5 —
// volta a `ativo`, NUNCA em_disputa). RBAC visual: profissional segue com a geração.
//
// SEM pumpAndSettle: o detalhe em aguardando_checkout monta o CronometroCard
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
  @override
  Future<CronometroSnap?> fetch(String turnoId) async => CronometroSnap(
    estado: 'aguardando_checkout',
    iniciadoEm: DateTime.now().toUtc().subtract(const Duration(hours: 5)),
    encerradoEm: DateTime.now().toUtc(),
    servidorAgora: DateTime.now().toUtc(),
    pollingSegundos: 5,
  );
}

class _FakeValidarCheckoutService extends ValidarCheckoutService {
  ValidarPinResult Function(String pin)? aoValidar;
  RecusaResult Function(String? motivo)? aoRecusar;
  final pinsValidados = <String>[];
  final motivosRecusados = <String?>[];

  @override
  Future<ValidarPinResult> validar(String turnoId, String pin) async {
    pinsValidados.add(pin);
    return aoValidar!(pin);
  }

  @override
  Future<RecusaResult> recusar(String turnoId, {String? motivo}) async {
    motivosRecusados.add(motivo);
    return aoRecusar!(motivo);
  }
}

TurnoDetalhe _turnoContratante({String estadoRaw = 'aguardando_checkout'}) =>
    TurnoDetalhe(
      id: 'u1',
      funcao: 'Garçom',
      dataInicio: DateTime(2026, 6, 12, 18),
      dataFim: DateTime(2026, 6, 12, 23),
      estado: TurnoEstadoResumo.aguardandoCheckout,
      estadoRaw: estadoRaw,
      valor: 200.0,
      estabelecimento: 'Bar do Zé',
      taxaTurni: 30.0,
      totalContratante: 230.0, // payload do CONTRATANTE
      profissional: 'Júlia Santos',
      aceite: null,
      timeline: const [],
    );

TurnoDetalhe _turnoProfissionalAguardando() => TurnoDetalhe(
  id: 'u1',
  funcao: 'Garçom',
  dataInicio: DateTime(2026, 6, 12, 18),
  dataFim: DateTime(2026, 6, 12, 23),
  estado: TurnoEstadoResumo.aguardandoCheckout,
  estadoRaw: 'aguardando_checkout',
  valor: 200.0,
  estabelecimento: 'Bar do Zé',
  taxaTurni: null,
  totalContratante: null,
  profissional: null,
  aceite: null,
  timeline: const [],
);

Widget _app(_FakeDetalheService svc, _FakeValidarCheckoutService validar) {
  final router = GoRouter(
    initialLocation: '/turnos/u1',
    routes: [
      GoRoute(
        path: '/turnos/:id',
        builder: (_, _) => TurnoDetalheScreen(
          turnoId: 'u1',
          service: svc,
          validarCheckoutService: validar,
          cronometroService: _FakeCronoService(),
        ),
      ),
      GoRoute(
        path: '/contratante/turnos',
        builder: (_, _) => const Scaffold(body: Text('LISTA CONTR')),
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

Future<void> _digitarPin(WidgetTester tester, String pin) async {
  await tester.ensureVisible(
    find.byKey(const Key('validar-checkout-pin-input')),
  );
  await tester.enterText(
    find.byKey(const Key('validar-checkout-pin-input')),
    pin,
  );
  await tester.pump();
}

Future<void> _validar(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(const Key('validar-checkout-btn')));
  await tester.tap(find.byKey(const Key('validar-checkout-btn')));
  await tester.pump(); // resolve o POST
  await tester.pump();
}

void main() {
  testWidgets(
    'contratante em aguardando_checkout vê a validação SEM aviso de geofencing (§4.7)',
    (tester) async {
      final svc = _FakeDetalheService(
        () => TurnoDetalheSuccess(_turnoContratante()),
      );
      await _monta(tester, _app(svc, _FakeValidarCheckoutService()));

      expect(find.byKey(const Key('validar-checkout-area')), findsOneWidget);
      expect(find.text('Turno concluído?'), findsOneWidget);
      // Diferença intencional da 062: NUNCA há card de aviso de geofencing aqui.
      expect(find.byKey(const Key('validar-checkin-geo-aviso')), findsNothing);
      expect(find.text('Nenhuma ação disponível no momento'), findsNothing);
      // Cronômetro congelado acima (CA-6 — microcopy aprovada da 064).
      expect(
        find.byKey(const Key('cronometro-aguardando-checkout')),
        findsOneWidget,
      );

      await _desmonta(tester);
    },
  );

  testWidgets(
    'CA-3: PIN correto → snackbar "turno finalizado" e recarrega a verdade',
    (tester) async {
      var estadoRaw = 'aguardando_checkout';
      final svc = _FakeDetalheService(
        () => TurnoDetalheSuccess(_turnoContratante(estadoRaw: estadoRaw)),
      );
      final validar = _FakeValidarCheckoutService()
        ..aoValidar = (pin) {
          estadoRaw = 'finalizado';
          return PinValidado();
        };
      await _monta(tester, _app(svc, validar));

      await _digitarPin(tester, '8341');
      await _validar(tester);

      expect(validar.pinsValidados, ['8341']);
      expect(
        find.text('Check-out validado — turno finalizado.'),
        findsOneWidget,
      );
      // Recarregou: a área de validação saiu (estado terminal).
      await tester.pump();
      expect(find.byKey(const Key('validar-checkout-area')), findsNothing);

      await _desmonta(tester);
    },
  );

  testWidgets('CA-4: PIN errado → erro inline no campo; estado preservado', (
    tester,
  ) async {
    final svc = _FakeDetalheService(
      () => TurnoDetalheSuccess(_turnoContratante()),
    );
    final validar = _FakeValidarCheckoutService()
      ..aoValidar = (_) => PinInvalido();
    await _monta(tester, _app(svc, validar));

    await _digitarPin(tester, '0000');
    await _validar(tester);

    expect(find.byKey(const Key('validar-checkout-pin-erro')), findsOneWidget);
    expect(
      find.text('PIN inválido. Confira com o profissional.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('validar-checkout-area')), findsOneWidget);

    await _desmonta(tester);
  });

  testWidgets(
    'CA-4: 3º erro (pin_expirado) → banner persistente e recarrega (volta a ativo)',
    (tester) async {
      var estadoRaw = 'aguardando_checkout';
      final svc = _FakeDetalheService(
        () => TurnoDetalheSuccess(_turnoContratante(estadoRaw: estadoRaw)),
      );
      final validar = _FakeValidarCheckoutService()
        ..aoValidar = (_) {
          estadoRaw = 'ativo'; // o servidor já devolveu o turno a ativo
          return PinExpirado();
        };
      await _monta(tester, _app(svc, validar));

      await _digitarPin(tester, '9999');
      await _validar(tester);
      await tester.pump();

      expect(
        find.text(
          'PIN expirado por excesso de tentativas. '
          'Peça ao profissional para gerar um novo.',
        ),
        findsOneWidget,
      );
      // Área de validação saiu (turno voltou a ativo; contratante vê placeholder).
      expect(find.byKey(const Key('validar-checkout-area')), findsNothing);

      await _desmonta(tester);
    },
  );

  testWidgets('429 → banner de muitas tentativas, sem retry', (tester) async {
    final svc = _FakeDetalheService(
      () => TurnoDetalheSuccess(_turnoContratante()),
    );
    final validar = _FakeValidarCheckoutService()
      ..aoValidar = (_) => ValidarRateLimit();
    await _monta(tester, _app(svc, validar));

    await _digitarPin(tester, '8341');
    await _validar(tester);

    expect(find.byKey(const Key('validar-checkout-banner')), findsOneWidget);
    expect(
      find.text(
        'Muitas tentativas em pouco tempo. Aguarde um minuto e tente de novo.',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('validar-checkout-retry-btn')), findsNothing);

    await _desmonta(tester);
  });

  testWidgets('erro de rede → banner com retry que reenvia o MESMO PIN', (
    tester,
  ) async {
    final svc = _FakeDetalheService(
      () => TurnoDetalheSuccess(_turnoContratante()),
    );
    final validar = _FakeValidarCheckoutService()
      ..aoValidar = (_) => ValidarErro();
    await _monta(tester, _app(svc, validar));

    await _digitarPin(tester, '8341');
    await _validar(tester);

    expect(find.byKey(const Key('validar-checkout-banner')), findsOneWidget);
    expect(find.byKey(const Key('validar-checkout-retry-btn')), findsOneWidget);

    await tester.tap(find.byKey(const Key('validar-checkout-retry-btn')));
    await tester.pump();
    await tester.pump();

    expect(validar.pinsValidados, ['8341', '8341']);

    await _desmonta(tester);
  });

  testWidgets(
    'CA-5: recusa abre dialog; confirmar com motivo → service recebe e recarrega',
    (tester) async {
      var estadoRaw = 'aguardando_checkout';
      final svc = _FakeDetalheService(
        () => TurnoDetalheSuccess(_turnoContratante(estadoRaw: estadoRaw)),
      );
      final validar = _FakeValidarCheckoutService()
        ..aoRecusar = (_) {
          estadoRaw = 'ativo';
          return RecusaOk();
        };
      await _monta(tester, _app(svc, validar));

      await tester.ensureVisible(find.byKey(const Key('recusar-checkout-btn')));
      await tester.tap(find.byKey(const Key('recusar-checkout-btn')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(const Key('recusar-checkout-dialog')), findsOneWidget);
      expect(find.text('Recusar check-out?'), findsOneWidget);
      expect(
        find.text(
          'O PIN atual deixa de valer e o turno volta para "Ativo" — o tempo '
          'continua contando. O profissional poderá gerar um novo PIN.',
        ),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(const Key('recusar-checkout-motivo-input')),
        'O turno ainda não terminou',
      );
      await tester.tap(find.byKey(const Key('recusar-checkout-confirmar-btn')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(validar.motivosRecusados, ['O turno ainda não terminou']);
      // Recarregou: validação saiu (turno voltou a ativo).
      await tester.pump();
      expect(find.byKey(const Key('validar-checkout-area')), findsNothing);

      await _desmonta(tester);
    },
  );

  testWidgets('erro na recusa → erro inline no dialog; dialog não fecha', (
    tester,
  ) async {
    final svc = _FakeDetalheService(
      () => TurnoDetalheSuccess(_turnoContratante()),
    );
    final validar = _FakeValidarCheckoutService()
      ..aoRecusar = (_) => RecusaErro();
    await _monta(tester, _app(svc, validar));

    await tester.ensureVisible(find.byKey(const Key('recusar-checkout-btn')));
    await tester.tap(find.byKey(const Key('recusar-checkout-btn')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byKey(const Key('recusar-checkout-confirmar-btn')));
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('recusar-checkout-erro')), findsOneWidget);
    expect(find.byKey(const Key('recusar-checkout-dialog')), findsOneWidget);

    await _desmonta(tester);
  });

  testWidgets(
    'RBAC visual: profissional em aguardando_checkout vê a geração (não a validação)',
    (tester) async {
      final svc = _FakeDetalheService(
        () => TurnoDetalheSuccess(_turnoProfissionalAguardando()),
      );
      await _monta(tester, _app(svc, _FakeValidarCheckoutService()));

      expect(find.byKey(const Key('validar-checkout-area')), findsNothing);
      expect(find.byKey(const Key('turno-checkout-regen-btn')), findsOneWidget);

      await _desmonta(tester);
    },
  );
}
