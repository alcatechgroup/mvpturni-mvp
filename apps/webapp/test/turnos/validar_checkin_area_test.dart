import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:turni_webapp/ds/theme.dart';
import 'package:turni_webapp/features/turnos/turno_detalhe_screen.dart';
import 'package:turni_webapp/features/turnos/turno_detalhe_service.dart';
import 'package:turni_webapp/features/turnos/turnos_service.dart'
    show TurnoEstadoResumo;
import 'package:turni_webapp/features/turnos/validar_checkin_service.dart';

// STORY-062 / SCREEN-062 — área de validação do PIN pelo CONTRATANTE no detalhe do
// turno (`aguardando_checkin`): input de 4 dígitos + Validar (CA-1), card de aviso de
// geofencing antes do input (CA-5 — nunca bloqueia), erro inline do PIN errado (CA-2),
// banner de expirado por 3 tentativas (CA-3), rate limit, erro de rede com retry,
// recusa com dialog de confirmação + motivo opcional (CA-6). RBAC visual: profissional
// segue vendo a área da 061; contratante fora de aguardando_checkin vê placeholder.

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

class _FakeValidarService extends ValidarCheckinService {
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

TurnoDetalhe _turnoContratante({
  String estadoRaw = 'aguardando_checkin',
  TurnoEstadoResumo estado = TurnoEstadoResumo.aguardandoCheckin,
  GeofencingCheckin? geofencing,
}) => TurnoDetalhe(
  id: 'u1',
  funcao: 'Garçom',
  dataInicio: DateTime(2026, 6, 12, 18),
  dataFim: DateTime(2026, 6, 12, 23),
  estado: estado,
  estadoRaw: estadoRaw,
  valor: 200.0,
  estabelecimento: 'Bar do Zé',
  taxaTurni: 30.0,
  totalContratante: 230.0,
  profissional: 'Júlia Santos',
  aceite: null,
  timeline: const [],
  geofencingCheckin: geofencing,
);

Widget _app(_FakeDetalheService svc, _FakeValidarService validar) {
  final router = GoRouter(
    initialLocation: '/turnos/u1',
    routes: [
      GoRoute(
        path: '/turnos/:id',
        builder: (_, _) => TurnoDetalheScreen(
          turnoId: 'u1',
          service: svc,
          validarService: validar,
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

Future<void> _tap(WidgetTester tester, Key key) async {
  await tester.ensureVisible(find.byKey(key));
  await tester.tap(find.byKey(key));
}

Future<void> _digitarPin(WidgetTester tester, String pin) async {
  await tester.enterText(
    find.byKey(const Key('validar-checkin-pin-input')),
    pin,
  );
  await tester.pump();
}

void main() {
  testWidgets(
    'contratante em aguardando_checkin vê a área de validação (não o placeholder)',
    (tester) async {
      final svc = _FakeDetalheService(
        () => TurnoDetalheSuccess(_turnoContratante()),
      );
      await tester.pumpWidget(_app(svc, _FakeValidarService()));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('validar-checkin-area')), findsOneWidget);
      expect(find.text('Profissional chegou?'), findsOneWidget);
      expect(
        find.text(
          'Peça o PIN de 4 dígitos que aparece no celular do profissional e digite abaixo.',
        ),
        findsOneWidget,
      );
      expect(find.text('Nenhuma ação disponível no momento'), findsNothing);
    },
  );

  testWidgets('botão desabilitado sem 4 dígitos; habilita com 4 (§4.1)', (
    tester,
  ) async {
    final svc = _FakeDetalheService(
      () => TurnoDetalheSuccess(_turnoContratante()),
    );
    await tester.pumpWidget(_app(svc, _FakeValidarService()));
    await tester.pumpAndSettle();

    FilledButton botao() => tester.widget<FilledButton>(
      find.byKey(const Key('validar-checkin-btn')),
    );
    expect(botao().enabled, isFalse);

    await _digitarPin(tester, '47');
    expect(botao().enabled, isFalse);

    await _digitarPin(tester, '4702');
    expect(botao().enabled, isTrue);
  });

  // ───────────────── CA-5 — card de aviso de geofencing ─────────────────

  testWidgets('geofencing ok → SEM card de aviso', (tester) async {
    final svc = _FakeDetalheService(
      () => TurnoDetalheSuccess(
        _turnoContratante(
          geofencing: const GeofencingCheckin(
            ok: true,
            distanciaMetros: 23.0,
            razao: null,
          ),
        ),
      ),
    );
    await tester.pumpWidget(_app(svc, _FakeValidarService()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('validar-checkin-geo-aviso')), findsNothing);
  });

  testWidgets(
    'fora do raio → card de aviso com distância ANTES do input; validação segue possível',
    (tester) async {
      final svc = _FakeDetalheService(
        () => TurnoDetalheSuccess(
          _turnoContratante(
            geofencing: const GeofencingCheckin(
              ok: false,
              distanciaMetros: 350.0,
              razao: 'fora_do_raio',
            ),
          ),
        ),
      );
      await tester.pumpWidget(_app(svc, _FakeValidarService()));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('validar-checkin-geo-aviso')),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'O profissional está a cerca de 350 m do estabelecimento.',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('você pode validar mesmo assim'),
        findsOneWidget,
      );
      // PDR-008: o aviso não bloqueia — o input continua lá.
      expect(
        find.byKey(const Key('validar-checkin-pin-input')),
        findsOneWidget,
      );
    },
  );

  testWidgets('sem captura → card com a razão humana', (tester) async {
    final svc = _FakeDetalheService(
      () => TurnoDetalheSuccess(
        _turnoContratante(
          geofencing: const GeofencingCheckin(
            ok: false,
            distanciaMetros: null,
            razao: 'permissao_negada',
          ),
        ),
      ),
    );
    await tester.pumpWidget(_app(svc, _FakeValidarService()));
    await tester.pumpAndSettle();

    expect(
      find.textContaining(
        'Localização do profissional não disponível (permissão negada).',
      ),
      findsOneWidget,
    );
  });

  // ───────────────── CA-1 — sucesso ─────────────────

  testWidgets('PIN correto → snackbar de sucesso e recarrega para ativo', (
    tester,
  ) async {
    var turno = _turnoContratante();
    final svc = _FakeDetalheService(() => TurnoDetalheSuccess(turno));
    final validar = _FakeValidarService()
      ..aoValidar = (pin) {
        turno = _turnoContratante(
          estadoRaw: 'ativo',
          estado: TurnoEstadoResumo.ativo,
        );
        return PinValidado();
      };
    await tester.pumpWidget(_app(svc, validar));
    await tester.pumpAndSettle();

    await _digitarPin(tester, '4702');
    await _tap(tester, const Key('validar-checkin-btn'));
    await tester.pumpAndSettle();

    expect(validar.pinsValidados, ['4702']);
    expect(find.byKey(const Key('validar-checkin-sucesso')), findsOneWidget);
    expect(find.text('Check-in validado — turno iniciado.'), findsOneWidget);
    // Recarregou a verdade: área de validação saiu (ativo → placeholder da 060).
    expect(svc.calls, 2);
    expect(find.byKey(const Key('validar-checkin-area')), findsNothing);
  });

  // ───────────────── CA-2 — PIN errado (inline) ─────────────────

  testWidgets(
    'PIN errado → erro inline no campo, sem banner; estado preservado',
    (tester) async {
      final svc = _FakeDetalheService(
        () => TurnoDetalheSuccess(_turnoContratante()),
      );
      final validar = _FakeValidarService()..aoValidar = (_) => PinInvalido();
      await tester.pumpWidget(_app(svc, validar));
      await tester.pumpAndSettle();

      await _digitarPin(tester, '0000');
      await _tap(tester, const Key('validar-checkin-btn'));
      await tester.pumpAndSettle();

      expect(
        find.text('PIN inválido. Confira com o profissional.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('validar-checkin-banner')), findsNothing);
      expect(svc.calls, 1); // não recarregou — o contratante re-digita
    },
  );

  // ───────────────── CA-3 — PIN expirado ─────────────────

  testWidgets(
    '3º erro (pin_expirado) → banner warning e recarrega (confirmado → placeholder)',
    (tester) async {
      var turno = _turnoContratante();
      final svc = _FakeDetalheService(() => TurnoDetalheSuccess(turno));
      final validar = _FakeValidarService()
        ..aoValidar = (_) {
          turno = _turnoContratante(
            estadoRaw: 'confirmado',
            estado: TurnoEstadoResumo.confirmado,
          );
          return PinExpirado();
        };
      await tester.pumpWidget(_app(svc, validar));
      await tester.pumpAndSettle();

      await _digitarPin(tester, '2222');
      await _tap(tester, const Key('validar-checkin-btn'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('validar-checkin-banner')), findsOneWidget);
      expect(
        find.text(
          'PIN expirado por excesso de tentativas. Peça ao profissional para gerar um novo.',
        ),
        findsOneWidget,
      );
      expect(svc.calls, 2);
      expect(find.text('Nenhuma ação disponível no momento'), findsOneWidget);
    },
  );

  // ───────────────── rate limit e erro de rede ─────────────────

  testWidgets('429 → banner de muitas tentativas, sem retry', (tester) async {
    final svc = _FakeDetalheService(
      () => TurnoDetalheSuccess(_turnoContratante()),
    );
    final validar = _FakeValidarService()
      ..aoValidar = (_) => ValidarRateLimit();
    await tester.pumpWidget(_app(svc, validar));
    await tester.pumpAndSettle();

    await _digitarPin(tester, '4702');
    await _tap(tester, const Key('validar-checkin-btn'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Muitas tentativas em pouco tempo. Aguarde um minuto e tente de novo.',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('validar-checkin-retry-btn')), findsNothing);
  });

  testWidgets(
    'erro de rede → banner com retry que reenvia o MESMO PIN (§4.7)',
    (tester) async {
      final svc = _FakeDetalheService(
        () => TurnoDetalheSuccess(_turnoContratante()),
      );
      var falha = true;
      final validar = _FakeValidarService()
        ..aoValidar = (_) => falha ? ValidarErro() : PinValidado();
      await tester.pumpWidget(_app(svc, validar));
      await tester.pumpAndSettle();

      await _digitarPin(tester, '4702');
      await _tap(tester, const Key('validar-checkin-btn'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Não foi possível validar o check-in. Verifique sua conexão.',
        ),
        findsOneWidget,
      );

      falha = false;
      await _tap(tester, const Key('validar-checkin-retry-btn'));
      await tester.pumpAndSettle();

      expect(validar.pinsValidados, ['4702', '4702']);
    },
  );

  testWidgets('estado_invalido → recarrega silenciosamente (sem banner)', (
    tester,
  ) async {
    var turno = _turnoContratante();
    final svc = _FakeDetalheService(() => TurnoDetalheSuccess(turno));
    final validar = _FakeValidarService()
      ..aoValidar = (_) {
        turno = _turnoContratante(
          estadoRaw: 'ativo',
          estado: TurnoEstadoResumo.ativo,
        );
        return ValidarEstadoInvalido();
      };
    await tester.pumpWidget(_app(svc, validar));
    await tester.pumpAndSettle();

    await _digitarPin(tester, '4702');
    await _tap(tester, const Key('validar-checkin-btn'));
    await tester.pumpAndSettle();

    expect(svc.calls, 2);
    expect(find.byKey(const Key('validar-checkin-banner')), findsNothing);
  });

  // ───────────────── CA-6 — recusa ─────────────────

  testWidgets('recusar abre dialog; Voltar fecha sem efeito', (tester) async {
    final svc = _FakeDetalheService(
      () => TurnoDetalheSuccess(_turnoContratante()),
    );
    final validar = _FakeValidarService();
    await tester.pumpWidget(_app(svc, validar));
    await tester.pumpAndSettle();

    await _tap(tester, const Key('recusar-checkin-btn'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('recusar-checkin-dialog')), findsOneWidget);
    expect(find.text('Recusar check-in?'), findsOneWidget);

    await tester.tap(find.byKey(const Key('recusar-checkin-voltar-btn')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('recusar-checkin-dialog')), findsNothing);
    expect(validar.motivosRecusados, isEmpty);
  });

  testWidgets(
    'confirmar recusa com motivo → service recebe o motivo e recarrega',
    (tester) async {
      var turno = _turnoContratante();
      final svc = _FakeDetalheService(() => TurnoDetalheSuccess(turno));
      final validar = _FakeValidarService()
        ..aoRecusar = (_) {
          turno = _turnoContratante(
            estadoRaw: 'confirmado',
            estado: TurnoEstadoResumo.confirmado,
          );
          return RecusaOk();
        };
      await tester.pumpWidget(_app(svc, validar));
      await tester.pumpAndSettle();

      await _tap(tester, const Key('recusar-checkin-btn'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('recusar-checkin-motivo-input')),
        'o profissional ainda não chegou',
      );
      await tester.tap(find.byKey(const Key('recusar-checkin-confirmar-btn')));
      await tester.pumpAndSettle();

      expect(validar.motivosRecusados, ['o profissional ainda não chegou']);
      expect(find.byKey(const Key('recusar-checkin-dialog')), findsNothing);
      expect(svc.calls, 2);
      expect(find.text('Nenhuma ação disponível no momento'), findsOneWidget);
    },
  );

  testWidgets('recusa sem motivo → service recebe null', (tester) async {
    var turno = _turnoContratante();
    final svc = _FakeDetalheService(() => TurnoDetalheSuccess(turno));
    final validar = _FakeValidarService()
      ..aoRecusar = (_) {
        turno = _turnoContratante(
          estadoRaw: 'confirmado',
          estado: TurnoEstadoResumo.confirmado,
        );
        return RecusaOk();
      };
    await tester.pumpWidget(_app(svc, validar));
    await tester.pumpAndSettle();

    await _tap(tester, const Key('recusar-checkin-btn'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('recusar-checkin-confirmar-btn')));
    await tester.pumpAndSettle();

    expect(validar.motivosRecusados, [null]);
  });

  testWidgets('erro na recusa → erro inline no dialog; dialog não fecha', (
    tester,
  ) async {
    final svc = _FakeDetalheService(
      () => TurnoDetalheSuccess(_turnoContratante()),
    );
    final validar = _FakeValidarService()..aoRecusar = (_) => RecusaErro();
    await tester.pumpWidget(_app(svc, validar));
    await tester.pumpAndSettle();

    await _tap(tester, const Key('recusar-checkin-btn'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('recusar-checkin-confirmar-btn')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('recusar-checkin-dialog')), findsOneWidget);
    expect(
      find.text('Não foi possível recusar. Tente de novo.'),
      findsOneWidget,
    );
    expect(svc.calls, 1);
  });

  // ───────────────── RBAC visual ─────────────────

  testWidgets(
    'profissional em aguardando_checkin segue vendo a área da 061 (não a validação)',
    (tester) async {
      final svc = _FakeDetalheService(
        () => TurnoDetalheSuccess(
          TurnoDetalhe(
            id: 'u1',
            funcao: 'Garçom',
            dataInicio: DateTime(2026, 6, 12, 18),
            dataFim: DateTime(2026, 6, 12, 23),
            estado: TurnoEstadoResumo.aguardandoCheckin,
            estadoRaw: 'aguardando_checkin',
            valor: 200.0,
            estabelecimento: 'Bar do Zé',
            taxaTurni: null,
            totalContratante: null,
            profissional: null,
            aceite: null,
            timeline: const [],
            checkinJanela: CheckinJanela(
              abreEm: DateTime(2026, 6, 12, 17, 30),
              fechaEm: DateTime(2026, 6, 12, 20),
            ),
          ),
        ),
      );
      await tester.pumpWidget(_app(svc, _FakeValidarService()));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('validar-checkin-area')), findsNothing);
      expect(find.byKey(const Key('turno-pin-regen-btn')), findsOneWidget);
    },
  );

  testWidgets(
    'contratante em confirmado vê o placeholder (validação só em aguardando_checkin)',
    (tester) async {
      final svc = _FakeDetalheService(
        () => TurnoDetalheSuccess(
          _turnoContratante(
            estadoRaw: 'confirmado',
            estado: TurnoEstadoResumo.confirmado,
          ),
        ),
      );
      await tester.pumpWidget(_app(svc, _FakeValidarService()));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('validar-checkin-area')), findsNothing);
      expect(find.text('Nenhuma ação disponível no momento'), findsOneWidget);
    },
  );
}
