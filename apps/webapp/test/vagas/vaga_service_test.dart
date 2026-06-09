import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:turni_webapp/features/vagas/vaga_service.dart';

// STORY-046 — VagaService: gate PDR-005 (CA-5), funções (CA-4) e publicar (CA-6/CA-1).
// STORY-047 — fetchMinhas (CA-1/CA-2) e cancelar (CA-4/CA-5).

void main() {
  group('fetchGate (CA-5)', () {
    test('pending > 0 → bloqueado', () async {
      final svc = VagaService(
        client: MockClient(
          (_) async =>
              http.Response(jsonEncode({'pending': 2, 'turnos': []}), 200),
        ),
      );
      final gate = await svc.fetchGate();
      expect(gate, isNotNull);
      expect(gate!.pending, 2);
      expect(gate.bloqueado, isTrue);
    });

    test('pending == 0 → não bloqueado', () async {
      final svc = VagaService(
        client: MockClient(
          (_) async =>
              http.Response(jsonEncode({'pending': 0, 'turnos': []}), 200),
        ),
      );
      final gate = await svc.fetchGate();
      expect(gate!.bloqueado, isFalse);
    });

    test('erro de rede/servidor → null', () async {
      final svc = VagaService(
        client: MockClient((_) async => http.Response('erro', 500)),
      );
      expect(await svc.fetchGate(), isNull);
    });

    test('STORY-088: turnoId vem do turno pendente mais antigo (turnos[0])', () async {
      final svc = VagaService(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'pending': 2,
              'turnos': [
                {'turno_id': 'turno-7', 'data_fim': '2026-06-01T23:00:00Z'},
                {'turno_id': 'turno-9', 'data_fim': '2026-06-05T23:00:00Z'},
              ],
            }),
            200,
          ),
        ),
      );
      final gate = await svc.fetchGate();
      expect(gate!.turnoId, 'turno-7');
    });

    test('STORY-088: sem turnos → turnoId null (fail-secure)', () async {
      final svc = VagaService(
        client: MockClient(
          (_) async =>
              http.Response(jsonEncode({'pending': 0, 'turnos': []}), 200),
        ),
      );
      final gate = await svc.fetchGate();
      expect(gate!.turnoId, isNull);
    });
  });

  group('fetchFuncoes (CA-4)', () {
    test('parseia data[] em Funcao', () async {
      final svc = VagaService(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'data': [
                {'id': '1', 'slug': 'bartender', 'nome': 'Bartender'},
                {'id': '2', 'slug': 'garcom', 'nome': 'Garçom'},
              ],
            }),
            200,
          ),
        ),
      );
      final funcoes = await svc.fetchFuncoes();
      expect(funcoes, hasLength(2));
      expect(funcoes.first.nome, 'Bartender');
    });

    test('erro → lista vazia', () async {
      final svc = VagaService(
        client: MockClient((_) async => http.Response('x', 500)),
      );
      expect(await svc.fetchFuncoes(), isEmpty);
    });
  });

  group('publicar (CA-6/CA-1)', () {
    VagaService svcResponding(int status, Object body) => VagaService(
      client: MockClient((req) async {
        expect(req.method, 'POST');
        expect(req.url.path, endsWith('/api/vagas'));
        return http.Response(jsonEncode(body), status);
      }),
    );

    test('201 → PublicarSuccess com id e estado (CA-6)', () async {
      final svc = svcResponding(201, {'id': '42', 'estado': 'aberta'});
      final r = await svc.publicar(
        funcaoId: '1',
        dataInicio: DateTime(2026, 6, 12, 18),
        dataFim: DateTime(2026, 6, 12, 23),
        valor: 150,
        posicoes: 2,
        observacoes: 'x',
      );
      expect(r, isA<PublicarSuccess>());
      expect((r as PublicarSuccess).vagaId, '42');
      expect(r.estado, 'aberta');
    });

    test('422 → PublicarValidationError com erros por campo (CA-2)', () async {
      final svc = svcResponding(422, {
        'message': 'inválido',
        'errors': {
          'data_fim': ['O fim precisa ser depois do início.'],
        },
      });
      final r = await svc.publicar(
        funcaoId: '1',
        dataInicio: DateTime(2026, 6, 12, 20),
        dataFim: DateTime(2026, 6, 12, 19),
        valor: 150,
        posicoes: 1,
      );
      expect(r, isA<PublicarValidationError>());
      expect(
        (r as PublicarValidationError).errors['data_fim'],
        contains('depois'),
      );
    });

    test('403 → PublicarForbidden (CA-1)', () async {
      final svc = svcResponding(403, {'message': 'restrito'});
      final r = await svc.publicar(
        funcaoId: '1',
        dataInicio: DateTime(2026, 6, 12, 18),
        dataFim: DateTime(2026, 6, 12, 23),
        valor: 150,
        posicoes: 1,
      );
      expect(r, isA<PublicarForbidden>());
    });

    test('5xx → PublicarServerError', () async {
      final svc = svcResponding(500, {'message': 'erro'});
      final r = await svc.publicar(
        funcaoId: '1',
        dataInicio: DateTime(2026, 6, 12, 18),
        dataFim: DateTime(2026, 6, 12, 23),
        valor: 150,
        posicoes: 1,
      );
      expect(r, isA<PublicarServerError>());
    });

    test('falha de rede → PublicarServerError (exceção)', () async {
      final svc = VagaService(
        client: MockClient((_) async => throw Exception('sem rede')),
      );
      final r = await svc.publicar(
        funcaoId: '1',
        dataInicio: DateTime(2026, 6, 12, 18),
        dataFim: DateTime(2026, 6, 12, 23),
        valor: 150,
        posicoes: 1,
      );
      expect(r, isA<PublicarServerError>());
    });
  });

  group('fetchMinhas (STORY-047 CA-1/CA-2)', () {
    String body(List<Map<String, dynamic>> data) => jsonEncode({'data': data});

    Map<String, dynamic> vagaJson({
      String estado = 'aberta',
      int pendentes = 0,
    }) => {
      'id': '7',
      'funcao': 'Garçom',
      'funcao_id': '3',
      'data_inicio': '2026-06-12T18:00:00-03:00',
      'data_fim': '2026-06-12T23:00:00-03:00',
      'valor': 150.0,
      'posicoes': 3,
      'posicoes_preenchidas': 1,
      'estado': estado,
      'candidatos_pendentes': pendentes,
    };

    test('200 → MinhasVagasSuccess parseando o card (CA-2)', () async {
      final svc = VagaService(
        client: MockClient((req) async {
          expect(req.method, 'GET');
          expect(req.url.path, endsWith('/api/vagas/minhas'));
          return http.Response(body([vagaJson(pendentes: 2)]), 200);
        }),
      );
      final r = await svc.fetchMinhas();
      expect(r, isA<MinhasVagasSuccess>());
      final vagas = (r as MinhasVagasSuccess).vagas;
      expect(vagas, hasLength(1));
      expect(vagas.first.funcao, 'Garçom');
      expect(vagas.first.estado, VagaEstadoResumo.aberta);
      expect(vagas.first.posicoes, 3);
      expect(vagas.first.posicoesPreenchidas, 1);
      expect(vagas.first.candidatosPendentes, 2);
      // Instante preservado (independe do fuso da máquina de teste — a UI formata com toLocal).
      expect(
        vagas.first.dataInicio.isAtSameMomentAs(
          DateTime.parse('2026-06-12T18:00:00-03:00'),
        ),
        isTrue,
      );
    });

    test('200 com data vazia → lista vazia (CA-7 borda)', () async {
      final svc = VagaService(
        client: MockClient((_) async => http.Response(body([]), 200)),
      );
      final r = await svc.fetchMinhas();
      expect(r, isA<MinhasVagasSuccess>());
      expect((r as MinhasVagasSuccess).vagas, isEmpty);
    });

    test('estados desconhecidos não quebram o parse (borda)', () async {
      final svc = VagaService(
        client: MockClient(
          (_) async => http.Response(
            body([
              vagaJson(estado: 'aberta'),
              vagaJson(estado: 'fechada'),
              vagaJson(estado: 'cancelada'),
            ]),
            200,
          ),
        ),
      );
      final r = await svc.fetchMinhas() as MinhasVagasSuccess;
      expect(r.vagas.map((v) => v.estado).toList(), [
        VagaEstadoResumo.aberta,
        VagaEstadoResumo.fechada,
        VagaEstadoResumo.cancelada,
      ]);
    });

    test('403 → MinhasVagasForbidden (CA-1 profissional)', () async {
      final svc = VagaService(
        client: MockClient((_) async => http.Response('x', 403)),
      );
      expect(await svc.fetchMinhas(), isA<MinhasVagasForbidden>());
    });

    test('5xx → MinhasVagasError', () async {
      final svc = VagaService(
        client: MockClient((_) async => http.Response('x', 500)),
      );
      expect(await svc.fetchMinhas(), isA<MinhasVagasError>());
    });

    test('falha de rede → MinhasVagasError (exceção)', () async {
      final svc = VagaService(
        client: MockClient((_) async => throw Exception('sem rede')),
      );
      expect(await svc.fetchMinhas(), isA<MinhasVagasError>());
    });
  });

  group('cancelar (STORY-047 CA-4/CA-5)', () {
    VagaService svc(int status, [Object body = const {}]) => VagaService(
      client: MockClient((req) async {
        expect(req.method, 'DELETE');
        expect(req.url.path, endsWith('/api/vagas/42'));
        return http.Response(jsonEncode(body), status);
      }),
    );

    test('200 → CancelarSuccess (CA-4)', () async {
      expect(
        await svc(200, {'id': 42, 'estado': 'cancelada'}).cancelar('42'),
        isA<CancelarSuccess>(),
      );
    });

    test('409 → CancelarConflict (transição inválida)', () async {
      expect(
        await svc(409, {'message': 'x'}).cancelar('42'),
        isA<CancelarConflict>(),
      );
    });

    test('403 → CancelarForbidden (não-dono / profissional)', () async {
      expect(await svc(403).cancelar('42'), isA<CancelarForbidden>());
    });

    test('5xx → CancelarServerError', () async {
      expect(await svc(500).cancelar('42'), isA<CancelarServerError>());
    });

    test('falha de rede → CancelarServerError (exceção)', () async {
      final s = VagaService(
        client: MockClient((_) async => throw Exception('sem rede')),
      );
      expect(await s.cancelar('42'), isA<CancelarServerError>());
    });
  });
}
