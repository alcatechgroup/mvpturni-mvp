import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:turni_webapp/features/vagas/vaga_service.dart';

// STORY-046 — VagaService: gate PDR-005 (CA-5), funções (CA-4) e publicar (CA-6/CA-1).

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
  });

  group('fetchFuncoes (CA-4)', () {
    test('parseia data[] em Funcao', () async {
      final svc = VagaService(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'data': [
                {'id': 1, 'slug': 'bartender', 'nome': 'Bartender'},
                {'id': 2, 'slug': 'garcom', 'nome': 'Garçom'},
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
      final svc = svcResponding(201, {'id': 42, 'estado': 'aberta'});
      final r = await svc.publicar(
        funcaoId: 1,
        dataInicio: DateTime(2026, 6, 12, 18),
        dataFim: DateTime(2026, 6, 12, 23),
        valor: 150,
        posicoes: 2,
        observacoes: 'x',
      );
      expect(r, isA<PublicarSuccess>());
      expect((r as PublicarSuccess).vagaId, 42);
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
        funcaoId: 1,
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
        funcaoId: 1,
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
        funcaoId: 1,
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
        funcaoId: 1,
        dataInicio: DateTime(2026, 6, 12, 18),
        dataFim: DateTime(2026, 6, 12, 23),
        valor: 150,
        posicoes: 1,
      );
      expect(r, isA<PublicarServerError>());
    });
  });
}
