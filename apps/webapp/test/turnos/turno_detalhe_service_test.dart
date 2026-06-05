import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:turni_webapp/features/turnos/turno_detalhe_service.dart';
import 'package:turni_webapp/features/turnos/turnos_service.dart'
    show TurnoEstadoResumo;

// STORY-060 — TurnoDetalheService: parse do payload por papel (CA-2), timeline (CA-3) com
// fail-soft de evento desconhecido, aceite inline (CA-5), 403/404 → não-encontrado
// fail-secure (SCREEN-060 §4.5) e erro de rede/5xx.

Map<String, dynamic> _payload({Map<String, dynamic>? extra}) => {
  'id': 'u1',
  'funcao': 'Garçom',
  'data_inicio': '2026-06-12T18:00:00-03:00',
  'data_fim': '2026-06-12T23:00:00-03:00',
  'estado': 'confirmado',
  'valor': 200.0,
  'estabelecimento': {'nome': 'Bar do Zé'},
  'aceite': {
    'emitido_em': '2026-06-03T15:47:00-03:00',
    'conteudo_renderizado': 'Contrato eventual de turno.',
  },
  'timeline': [
    {
      'id': 'ev2',
      'evento': 'pagamento_pre_autorizado',
      'ocorrido_em': '2026-06-03T15:47:00-03:00',
    },
    {
      'id': 'ev1',
      'evento': 'turno_criado',
      'ocorrido_em': '2026-06-03T15:46:00-03:00',
    },
  ],
  ...?extra,
};

TurnoDetalheService _svc(int status, [Object? body]) => TurnoDetalheService(
  client: MockClient((req) async {
    expect(req.url.path, '/api/turnos/u1');
    return http.Response(body == null ? '' : jsonEncode(body), status);
  }),
);

void main() {
  test(
    'parse do payload do profissional: sem taxa/total → souContratante false',
    () async {
      final result = await _svc(200, _payload()).fetch('u1');

      final turno = (result as TurnoDetalheSuccess).turno;
      expect(turno.id, 'u1');
      expect(turno.funcao, 'Garçom');
      expect(turno.estado, TurnoEstadoResumo.confirmado);
      expect(turno.estadoRaw, 'confirmado');
      expect(turno.valor, 200.0);
      expect(turno.estabelecimento, 'Bar do Zé');
      expect(turno.souContratante, isFalse);
      expect(turno.estadoTerminal, isFalse);
      expect(turno.aceite!.conteudoRenderizado, 'Contrato eventual de turno.');
      expect(turno.timeline, hasLength(2));
      expect(
        turno.timeline.first.tipo,
        TimelineEventoTipo.pagamentoPreAutorizado,
      );
    },
  );

  test('payload do contratante carrega taxa/total/profissional', () async {
    final result = await _svc(
      200,
      _payload(
        extra: {
          'taxa_turni': 30.0,
          'total_contratante': 230.0,
          'profissional': {'nome': 'Júlia Santos'},
        },
      ),
    ).fetch('u1');

    final turno = (result as TurnoDetalheSuccess).turno;
    expect(turno.souContratante, isTrue);
    expect(turno.taxaTurni, 30.0);
    expect(turno.totalContratante, 230.0);
    expect(turno.profissional, 'Júlia Santos');
  });

  test(
    'evento desconhecido vira fail-soft; valor/lado opcionais chegam',
    () async {
      final result = await _svc(
        200,
        _payload(
          extra: {
            'estado': 'cancelado_emp',
            'timeline': [
              {
                'id': 'ev9',
                'evento': 'evento_novo_do_futuro',
                'ocorrido_em': '2026-06-04T09:00:00-03:00',
              },
              {
                'id': 'ev8',
                'evento': 'cancelado',
                'ocorrido_em': '2026-06-04T09:18:00-03:00',
                'lado': 'emp',
              },
              {
                'id': 'ev7',
                'evento': 'pix_enviado',
                'ocorrido_em': '2026-05-31T02:14:00-03:00',
                'valor': 200.0,
              },
            ],
          },
        ),
      ).fetch('u1');

      final timeline = (result as TurnoDetalheSuccess).turno.timeline;
      expect(timeline[0].tipo, TimelineEventoTipo.desconhecido);
      expect(timeline[1].tipo, TimelineEventoTipo.cancelado);
      expect(timeline[1].lado, 'emp');
      expect(timeline[2].tipo, TimelineEventoTipo.pixEnviado);
      expect(timeline[2].valor, 200.0);
      expect(result.turno.estadoTerminal, isTrue);
    },
  );

  test(
    'aceite null e timeline ausente: degradado sem quebrar (§4.6)',
    () async {
      final result = await _svc(
        200,
        _payload(extra: {'aceite': null, 'timeline': null}),
      ).fetch('u1');

      final turno = (result as TurnoDetalheSuccess).turno;
      expect(turno.aceite, isNull);
      expect(turno.timeline, isEmpty);
    },
  );

  test('403 e 404 → TurnoDetalheNaoEncontrado (fail-secure §4.5)', () async {
    expect(await _svc(403).fetch('u1'), isA<TurnoDetalheNaoEncontrado>());
    expect(await _svc(404).fetch('u1'), isA<TurnoDetalheNaoEncontrado>());
  });

  test('500 e body inválido → TurnoDetalheError', () async {
    expect(await _svc(500).fetch('u1'), isA<TurnoDetalheError>());
    final invalido = TurnoDetalheService(
      client: MockClient((req) async => http.Response('not-json', 200)),
    );
    expect(await invalido.fetch('u1'), isA<TurnoDetalheError>());
  });

  // ───────────────────── STORY-061 — aditivos do PIN ─────────────────────

  test('STORY-061: parse de checkin_janela (profissional) e ausência (contratante)', () async {
    final comJanela = await _svc(
      200,
      _payload(
        extra: {
          'checkin_janela': {
            'abre_em': '2026-06-12T17:30:00-03:00',
            'fecha_em': '2026-06-12T20:00:00-03:00',
          },
        },
      ),
    ).fetch('u1');

    final turno = (comJanela as TurnoDetalheSuccess).turno;
    expect(turno.checkinJanela, isNotNull);
    expect(
      turno.checkinJanela!.fechaEm.difference(turno.checkinJanela!.abreEm),
      const Duration(minutes: 150),
    );

    final sem = await _svc(200, _payload()).fetch('u1');
    expect((sem as TurnoDetalheSuccess).turno.checkinJanela, isNull);
  });

  test('STORY-061: timeline parseia geofencing do checkin_solicitado e tolera ausência', () async {
    final result = await _svc(
      200,
      _payload(
        extra: {
          'timeline': [
            {
              'id': 'ev3',
              'evento': 'checkin_solicitado',
              'ocorrido_em': '2026-06-12T17:58:00-03:00',
              'geofencing': {
                'ok': false,
                'distancia_metros': 230.4,
                'razao': 'fora_do_raio',
              },
            },
            {
              'id': 'ev4',
              'evento': 'checkin_cancelado',
              'ocorrido_em': '2026-06-12T18:02:00-03:00',
            },
            {
              'id': 'ev5',
              'evento': 'checkin_solicitado', // seed antigo, sem geofencing
              'ocorrido_em': '2026-06-12T18:10:00-03:00',
            },
          ],
        },
      ),
    ).fetch('u1');

    final timeline = (result as TurnoDetalheSuccess).turno.timeline;
    expect(timeline[0].tipo, TimelineEventoTipo.checkinSolicitado);
    expect(timeline[0].geofencing!.ok, isFalse);
    expect(timeline[0].geofencing!.distanciaMetros, 230.4);
    expect(timeline[0].geofencing!.razao, 'fora_do_raio');
    expect(timeline[1].tipo, TimelineEventoTipo.checkinCancelado);
    expect(timeline[2].geofencing, isNull);
  });
}
