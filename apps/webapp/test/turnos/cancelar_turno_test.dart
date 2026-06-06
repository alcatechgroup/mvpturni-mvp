import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:turni_webapp/ds/theme.dart';
import 'package:turni_webapp/features/turnos/cancelar_turno_service.dart';
import 'package:turni_webapp/features/turnos/turno_detalhe_screen.dart';
import 'package:turni_webapp/features/turnos/turno_detalhe_service.dart';
import 'package:turni_webapp/features/turnos/turnos_service.dart'
    show TurnoEstadoResumo;

// STORY-066 (CA-1/CA-7 / SCREEN-066 §A) — cancelamento do turno no detalhe:
// gatilho de baixa ênfase só em `confirmado` (PDR-007), dialog.confirm com motivo
// opcional, erro inline (rede e 422-corrida), sucesso recarrega + snackbar; timeline
// dos terminais com `cancelado` (lado/motivo visíveis aos 2 lados), `no_show_pro`
// (com X horas) e `pagamento_liberado` por papel.

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

class _FakeCancelarService extends CancelarTurnoService {
  _FakeCancelarService(this.result);

  CancelarTurnoResult Function() result;
  int calls = 0;
  String? motivoEnviado;

  @override
  Future<CancelarTurnoResult> cancelar(String turnoId, {String? motivo}) async {
    calls++;
    motivoEnviado = motivo;
    return result();
  }
}

TimelineEvento _evento(
  TimelineEventoTipo tipo, {
  double? valor,
  String? lado,
  String? motivo,
  int? limiteHoras,
}) => TimelineEvento(
  id: 'ev-${tipo.slug}',
  tipo: tipo,
  ocorridoEm: DateTime(2026, 6, 4, 9, 18),
  valor: valor,
  lado: lado,
  motivo: motivo,
  limiteHoras: limiteHoras,
);

TurnoDetalhe _turno({
  String estadoRaw = 'confirmado',
  TurnoEstadoResumo estado = TurnoEstadoResumo.confirmado,
  bool contratante = false,
  List<TimelineEvento>? timeline,
}) => TurnoDetalhe(
  id: 'u1',
  funcao: 'Garçom',
  dataInicio: DateTime(2026, 6, 8, 11),
  dataFim: DateTime(2026, 6, 8, 17),
  estado: estado,
  estadoRaw: estadoRaw,
  valor: 240.0,
  estabelecimento: 'Restaurante Vela',
  taxaTurni: contratante ? 36.0 : null,
  totalContratante: contratante ? 276.0 : null,
  profissional: contratante ? 'Pedro Alves' : null,
  aceite: null,
  timeline: timeline ?? [_evento(TimelineEventoTipo.turnoCriado)],
);

Widget _app(_FakeDetalheService svc, _FakeCancelarService cancelar) {
  final router = GoRouter(
    initialLocation: '/turnos/u1',
    routes: [
      GoRoute(
        path: '/turnos/:id',
        builder: (_, _) => TurnoDetalheScreen(
          turnoId: 'u1',
          service: svc,
          cancelarService: cancelar,
        ),
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
  // ───────────── Gatilho (CA-1 / §A.3) ─────────────

  testWidgets('profissional em confirmado vê o gatilho com a pergunta dele', (
    tester,
  ) async {
    final svc = _FakeDetalheService(() => TurnoDetalheSuccess(_turno()));
    await tester.pumpWidget(
      _app(svc, _FakeCancelarService(CancelamentoErro.new)),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('turno-detalhe-cancelar-btn')), findsOneWidget);
    expect(
      find.text('Não vai poder comparecer? Cancelar turno'),
      findsOneWidget,
    );
  });

  testWidgets('contratante em confirmado vê o gatilho com a pergunta dele', (
    tester,
  ) async {
    final svc = _FakeDetalheService(
      () => TurnoDetalheSuccess(_turno(contratante: true)),
    );
    await tester.pumpWidget(
      _app(svc, _FakeCancelarService(CancelamentoErro.new)),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Não precisa mais deste turno? Cancelar turno'),
      findsOneWidget,
    );
  });

  testWidgets('fora de confirmado o gatilho NÃO aparece (PDR-007)', (
    tester,
  ) async {
    for (final estadoRaw in ['aguardando_checkin', 'ativo', 'cancelado_pro']) {
      final svc = _FakeDetalheService(
        () => TurnoDetalheSuccess(
          _turno(
            estadoRaw: estadoRaw,
            estado: TurnoEstadoResumo.fromApi(estadoRaw),
            contratante: true,
          ),
        ),
      );
      await tester.pumpWidget(
        _app(svc, _FakeCancelarService(CancelamentoErro.new)),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('turno-detalhe-cancelar-btn')),
        findsNothing,
        reason: 'gatilho não deveria existir em $estadoRaw',
      );
    }
  });

  // ───────────── Dialog (CA-1 / §A.4) ─────────────

  testWidgets(
    'fluxo feliz: dialog → motivo → confirmar → recarrega com snackbar',
    (tester) async {
      var cancelado = false;
      final svc = _FakeDetalheService(
        () => TurnoDetalheSuccess(
          cancelado
              ? _turno(
                  estadoRaw: 'cancelado_pro',
                  estado: TurnoEstadoResumo.fromApi('cancelado_pro'),
                  timeline: [
                    _evento(
                      TimelineEventoTipo.cancelado,
                      lado: 'pro',
                      motivo: 'Tive um imprevisto de saúde.',
                    ),
                    _evento(TimelineEventoTipo.turnoCriado),
                  ],
                )
              : _turno(),
        ),
      );
      final cancelar = _FakeCancelarService(() {
        cancelado = true;
        return CancelamentoOk('cancelado_pro');
      });

      await tester.pumpWidget(_app(svc, cancelar));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('turno-detalhe-cancelar-btn')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('cancelar-dialog')), findsOneWidget);
      expect(find.text('Cancelar este turno?'), findsOneWidget);
      expect(find.textContaining('o contratante será avisado'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('cancelar-dialog-motivo')),
        'Tive um imprevisto de saúde.',
      );
      await tester.tap(find.byKey(const Key('cancelar-dialog-confirmar')));
      await tester.pumpAndSettle();

      expect(cancelar.calls, 1);
      expect(cancelar.motivoEnviado, 'Tive um imprevisto de saúde.');
      expect(find.byKey(const Key('cancelar-dialog')), findsNothing);
      expect(find.byKey(const Key('turno-cancelado-snackbar')), findsOneWidget);
      expect(find.text('Cancelado'), findsOneWidget); // badge terminal
      // motivo visível na timeline (decisão do PO — §A.5)
      expect(find.text('“Tive um imprevisto de saúde.”'), findsOneWidget);
      // gatilho some no terminal
      expect(find.byKey(const Key('turno-detalhe-cancelar-btn')), findsNothing);
    },
  );

  testWidgets('motivo vazio vira null (opcional)', (tester) async {
    final svc = _FakeDetalheService(() => TurnoDetalheSuccess(_turno()));
    final cancelar = _FakeCancelarService(
      () => CancelamentoOk('cancelado_pro'),
    );

    await tester.pumpWidget(_app(svc, cancelar));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('turno-detalhe-cancelar-btn')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('cancelar-dialog-confirmar')));
    await tester.pumpAndSettle();

    expect(cancelar.calls, 1);
    expect(cancelar.motivoEnviado, isNull);
  });

  testWidgets('erro de rede: inline, dialog NÃO fecha, retry possível', (
    tester,
  ) async {
    final svc = _FakeDetalheService(() => TurnoDetalheSuccess(_turno()));
    final cancelar = _FakeCancelarService(CancelamentoErro.new);

    await tester.pumpWidget(_app(svc, cancelar));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('turno-detalhe-cancelar-btn')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('cancelar-dialog-confirmar')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('cancelar-dialog')), findsOneWidget);
    expect(
      find.text('Não foi possível cancelar. Tente de novo.'),
      findsOneWidget,
    );

    // retry funciona (o botão segue habilitado)
    await tester.tap(find.byKey(const Key('cancelar-dialog-confirmar')));
    await tester.pumpAndSettle();
    expect(cancelar.calls, 2);
  });

  testWidgets(
    '422 (corrida): erro inline, confirmar trava, Voltar recarrega a verdade',
    (tester) async {
      final svc = _FakeDetalheService(() => TurnoDetalheSuccess(_turno()));
      final cancelar = _FakeCancelarService(CancelamentoEstadoInvalido.new);

      await tester.pumpWidget(_app(svc, cancelar));
      await tester.pumpAndSettle();
      final fetchesAntes = svc.calls;

      await tester.tap(find.byKey(const Key('turno-detalhe-cancelar-btn')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('cancelar-dialog-confirmar')));
      await tester.pumpAndSettle();

      expect(
        find.text('Este turno não pode mais ser cancelado.'),
        findsOneWidget,
      );
      final confirmar = tester.widget<FilledButton>(
        find.byKey(const Key('cancelar-dialog-confirmar')),
      );
      expect(confirmar.onPressed, isNull); // não adianta insistir

      await tester.tap(find.byKey(const Key('cancelar-dialog-voltar')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('cancelar-dialog')), findsNothing);
      expect(svc.calls, greaterThan(fetchesAntes)); // recarregou a verdade
      // SEM snackbar de sucesso — nada foi cancelado por este usuário
      expect(find.byKey(const Key('turno-cancelado-snackbar')), findsNothing);
    },
  );

  testWidgets('Voltar sem confirmar fecha sem efeito', (tester) async {
    final svc = _FakeDetalheService(() => TurnoDetalheSuccess(_turno()));
    final cancelar = _FakeCancelarService(CancelamentoErro.new);

    await tester.pumpWidget(_app(svc, cancelar));
    await tester.pumpAndSettle();
    final fetchesAntes = svc.calls;

    await tester.tap(find.byKey(const Key('turno-detalhe-cancelar-btn')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('cancelar-dialog-voltar')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('cancelar-dialog')), findsNothing);
    expect(cancelar.calls, 0);
    expect(svc.calls, fetchesAntes); // sem reload desnecessário
  });

  // ───────────── Timeline dos terminais (CA-7 / §A.5) ─────────────

  testWidgets(
    'timeline do cancelado: voz de quem lê + motivo + liberação por papel (contratante)',
    (tester) async {
      final svc = _FakeDetalheService(
        () => TurnoDetalheSuccess(
          _turno(
            estadoRaw: 'cancelado_pro',
            estado: TurnoEstadoResumo.fromApi('cancelado_pro'),
            contratante: true,
            timeline: [
              _evento(TimelineEventoTipo.pagamentoLiberado, valor: 276.0),
              _evento(
                TimelineEventoTipo.cancelado,
                lado: 'pro',
                motivo: 'Tive um imprevisto de saúde.',
              ),
              _evento(TimelineEventoTipo.turnoCriado),
            ],
          ),
        ),
      );
      await tester.pumpWidget(
        _app(svc, _FakeCancelarService(CancelamentoErro.new)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Reserva de pagamento liberada'), findsOneWidget);
      expect(
        find.textContaining('liberados no seu meio de pagamento'),
        findsOneWidget,
      );
      expect(find.text('Cancelado pelo profissional.'), findsOneWidget);
      expect(find.text('“Tive um imprevisto de saúde.”'), findsOneWidget);
    },
  );

  testWidgets(
    'timeline do cancelado_emp na visão do profissional: "Cancelado pelo contratante." + liberação sem valor',
    (tester) async {
      final svc = _FakeDetalheService(
        () => TurnoDetalheSuccess(
          _turno(
            estadoRaw: 'cancelado_emp',
            estado: TurnoEstadoResumo.fromApi('cancelado_emp'),
            timeline: [
              _evento(TimelineEventoTipo.pagamentoLiberado),
              _evento(TimelineEventoTipo.cancelado, lado: 'emp'),
              _evento(TimelineEventoTipo.turnoCriado),
            ],
          ),
        ),
      );
      await tester.pumpWidget(
        _app(svc, _FakeCancelarService(CancelamentoErro.new)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Cancelado pelo contratante.'), findsOneWidget);
      expect(find.text('O contratante não foi cobrado.'), findsOneWidget);
    },
  );

  testWidgets('no_show_pro: badge "Não realizado" + copy com X horas', (
    tester,
  ) async {
    final svc = _FakeDetalheService(
      () => TurnoDetalheSuccess(
        _turno(
          estadoRaw: 'no_show_pro',
          estado: TurnoEstadoResumo.fromApi('no_show_pro'),
          timeline: [
            _evento(TimelineEventoTipo.pagamentoLiberado),
            _evento(TimelineEventoTipo.noShowPro, limiteHoras: 2),
            _evento(TimelineEventoTipo.turnoCriado),
          ],
        ),
      ),
    );
    await tester.pumpWidget(
      _app(svc, _FakeCancelarService(CancelamentoErro.new)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Não realizado'), findsOneWidget);
    expect(find.text('Turno não realizado'), findsOneWidget);
    expect(
      find.text(
        'O check-in não aconteceu em até 2 horas após o início previsto.',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('turno-detalhe-cancelar-btn')), findsNothing);
  });

  testWidgets('no_show_pro sem limite_horas degrada para copy genérica', (
    tester,
  ) async {
    final svc = _FakeDetalheService(
      () => TurnoDetalheSuccess(
        _turno(
          estadoRaw: 'no_show_pro',
          estado: TurnoEstadoResumo.fromApi('no_show_pro'),
          timeline: [_evento(TimelineEventoTipo.noShowPro)],
        ),
      ),
    );
    await tester.pumpWidget(
      _app(svc, _FakeCancelarService(CancelamentoErro.new)),
    );
    await tester.pumpAndSettle();

    expect(find.text('O check-in não aconteceu até o limite.'), findsOneWidget);
  });

  // ───────────── Service (CA-2 — contrato HTTP) ─────────────

  group('CancelarTurnoService', () {
    Map<String, dynamic>? corpo;
    String? path;

    CancelarTurnoService service(http.Response Function() resposta) {
      corpo = null;
      path = null;
      return CancelarTurnoService(
        client: MockClient((req) async {
          path = req.url.path;
          if (req.body.isNotEmpty) {
            corpo = jsonDecode(req.body) as Map<String, dynamic>;
          }
          return resposta();
        }),
      );
    }

    test('200 → CancelamentoOk com estado; POST leva o motivo', () async {
      final svc = service(
        () => http.Response(jsonEncode({'estado': 'cancelado_emp'}), 200),
      );

      final r = await svc.cancelar('t1', motivo: 'O evento foi cancelado.');

      expect(r, isA<CancelamentoOk>());
      expect((r as CancelamentoOk).estado, 'cancelado_emp');
      expect(path, '/api/turnos/t1/cancelar');
      expect(corpo!['motivo'], 'O evento foi cancelado.');
    });

    test('motivo null não entra no corpo', () async {
      final svc = service(
        () => http.Response(jsonEncode({'estado': 'cancelado_pro'}), 200),
      );

      await svc.cancelar('t1');

      expect(corpo, isNot(contains('motivo')));
    });

    test('422 estado_invalido → CancelamentoEstadoInvalido', () async {
      final svc = service(
        () => http.Response(jsonEncode({'motivo': 'estado_invalido'}), 422),
      );

      expect(await svc.cancelar('t1'), isA<CancelamentoEstadoInvalido>());
    });

    test('422 de validação (motivo longo) → CancelamentoErro', () async {
      final svc = service(() => http.Response(jsonEncode({'errors': {}}), 422));

      expect(await svc.cancelar('t1'), isA<CancelamentoErro>());
    });

    test('500 e exceção de rede → CancelamentoErro', () async {
      expect(
        await service(() => http.Response('erro', 500)).cancelar('t1'),
        isA<CancelamentoErro>(),
      );
      final svc = CancelarTurnoService(
        client: MockClient((_) async => throw http.ClientException('down')),
      );
      expect(await svc.cancelar('t1'), isA<CancelamentoErro>());
    });
  });
}
