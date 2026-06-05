import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:turni_webapp/features/turnos/turnos_service.dart';

// STORY-059 — TurnosService: parse dos grupos (CA-1/CA-2), fail-soft de estado/grupo
// desconhecido (SCREEN-059 §4.6), 403 fail-secure (CA-5) e erro de rede/5xx.

Map<String, dynamic> _item({
  String id = 'u1',
  String estado = 'confirmado',
  Map<String, dynamic>? extra,
}) => {
  'id': id,
  'funcao': 'Garçom',
  'data_inicio': '2026-06-12T18:00:00-03:00',
  'data_fim': '2026-06-12T23:00:00-03:00',
  'estado': estado,
  ...?extra,
};

void main() {
  group('fetchDoProfissional (CA-1)', () {
    test(
      'parse dos grupos na ordem do servidor + item do profissional',
      () async {
        final body = jsonEncode({
          'grupos': [
            {
              'grupo': 'confirmado',
              'turnos': [
                _item(
                  extra: {
                    'valor': 200.0,
                    'estabelecimento': {'nome': 'Bar do Zé'},
                  },
                ),
              ],
            },
            {
              'grupo': 'finalizado',
              'turnos': [
                _item(
                  id: 'u2',
                  estado: 'finalizado_ajustado',
                  extra: {'valor': 150.0},
                ),
              ],
            },
          ],
        });
        final svc = TurnosService(
          client: MockClient((req) async {
            expect(req.url.path, '/api/profissional/turnos');
            return http.Response(body, 200);
          }),
        );

        final result = await svc.fetchDoProfissional();
        expect(result, isA<TurnosSuccess>());
        final grupos = (result as TurnosSuccess).grupos;
        expect(grupos.map((g) => g.grupo).toList(), [
          TurnoGrupo.confirmado,
          TurnoGrupo.finalizado,
        ]);

        final t = grupos.first.turnos.single;
        expect(t.id, 'u1');
        expect(t.funcao, 'Garçom');
        expect(t.estado, TurnoEstadoResumo.confirmado);
        expect(t.valor, 200.0);
        expect(t.quem, 'Bar do Zé');

        // finalizado_ajustado tem selo próprio dentro do grupo "Finalizados".
        expect(
          grupos.last.turnos.single.estado,
          TurnoEstadoResumo.finalizadoAjustado,
        );
      },
    );

    test(
      'grupo/estado desconhecidos são fail-soft (§4.6) — nunca quebram',
      () async {
        final body = jsonEncode({
          'grupos': [
            {
              'grupo': 'estado_novo_do_futuro',
              'turnos': [_item(estado: 'outro_estado_novo')],
            },
          ],
        });
        final svc = TurnosService(
          client: MockClient((_) async => http.Response(body, 200)),
        );

        final result = await svc.fetchDoProfissional() as TurnosSuccess;
        final grupo = result.grupos.single;
        // Cai em "Encerrados" (visível), com selo neutro.
        expect(grupo.grupo, TurnoGrupo.desconhecido);
        expect(grupo.grupo.titulo, 'Encerrados');
        expect(grupo.turnos.single.estado, TurnoEstadoResumo.desconhecido);
      },
    );

    test('403 → TurnosForbidden (CA-5)', () async {
      final svc = TurnosService(
        client: MockClient((_) async => http.Response('{}', 403)),
      );
      expect(await svc.fetchDoProfissional(), isA<TurnosForbidden>());
    });

    test('rede/5xx → TurnosError', () async {
      final svc = TurnosService(
        client: MockClient((_) async => http.Response('erro', 500)),
      );
      expect(await svc.fetchDoProfissional(), isA<TurnosError>());

      final svcRede = TurnosService(
        client: MockClient((_) async => throw Exception('offline')),
      );
      expect(await svcRede.fetchDoProfissional(), isA<TurnosError>());
    });
  });

  group('fetchDoContratante (CA-2)', () {
    test(
      'item do contratante usa total_contratante e nome do profissional',
      () async {
        final body = jsonEncode({
          'grupos': [
            {
              'grupo': 'confirmado',
              'turnos': [
                _item(
                  extra: {
                    'total_contratante': 230.0,
                    'profissional': {'nome': 'Júlia Santos'},
                  },
                ),
              ],
            },
          ],
        });
        final svc = TurnosService(
          client: MockClient((req) async {
            expect(req.url.path, '/api/contratante/turnos');
            return http.Response(body, 200);
          }),
        );

        final result = await svc.fetchDoContratante() as TurnosSuccess;
        final t = result.grupos.single.turnos.single;
        expect(t.valor, 230.0); // total a pagar (PDR-004)
        expect(t.quem, 'Júlia Santos');
      },
    );

    test('estados de turno mapeiam para os selos da SCREEN-059 §4.1', () {
      expect(TurnoEstadoResumo.fromApi('ativo').label, 'Em andamento');
      expect(
        TurnoEstadoResumo.fromApi('aguardando_checkin').label,
        'Aguardando check-in',
      );
      expect(
        TurnoEstadoResumo.fromApi('aguardando_checkout').label,
        'Aguardando check-out',
      );
      expect(TurnoEstadoResumo.fromApi('em_disputa').label, 'Em disputa');
      expect(TurnoEstadoResumo.fromApi('cancelado_pro').label, 'Cancelado');
      expect(TurnoEstadoResumo.fromApi('cancelado_emp').label, 'Cancelado');
      expect(TurnoEstadoResumo.fromApi('no_show_pro').label, 'Não realizado');
      expect(
        TurnoEstadoResumo.fromApi('disputa_resolvida_sem_pagamento').label,
        'Encerrado sem pagamento',
      );
    });
  });
}
