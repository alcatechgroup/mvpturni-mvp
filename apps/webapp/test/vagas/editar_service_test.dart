import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:turni_webapp/features/vagas/candidatura_service.dart';
import 'package:turni_webapp/features/vagas/vaga_service.dart';

// STORY-052 — VagaService.fetchEditar/editar (CA-10/CA-1..CA-5) e
// CandidaturaService.manter/retirarAposEdicao (CA-7/CA-8) contra um http client falso.

void main() {
  group('VagaService.fetchEditar (CA-10)', () {
    test('200 → VagaEditar com candidatos a notificar', () async {
      final svc = VagaService(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'id': 7,
              'editavel': true,
              'funcao_id': 1,
              'data_inicio': '2026-06-12T18:00:00-03:00',
              'data_fim': '2026-06-12T23:00:00-03:00',
              'valor': 120.0,
              'posicoes': 2,
              'observacoes': 'Avental.',
              'candidatos_em_revisao': 3,
            }),
            200,
          ),
        ),
      );
      final r = await svc.fetchEditar(7);
      expect(r, isA<CarregarEdicaoSuccess>());
      final vaga = (r as CarregarEdicaoSuccess).vaga;
      expect(vaga.valor, 120.0);
      expect(vaga.candidatosEmRevisao, 3);
      expect(vaga.editavel, isTrue);
    });

    test('403 → Forbidden, 404 → NotFound, 500 → Error', () async {
      Future<CarregarEdicaoResult> withStatus(int s) => VagaService(
        client: MockClient((_) async => http.Response('{}', s)),
      ).fetchEditar(7);

      expect(await withStatus(403), isA<CarregarEdicaoForbidden>());
      expect(await withStatus(404), isA<CarregarEdicaoNotFound>());
      expect(await withStatus(500), isA<CarregarEdicaoError>());
    });
  });

  group('VagaService.editar (CA-1..CA-5)', () {
    test('200 → EditarSuccess com diff e nº de notificados', () async {
      final svc = VagaService(
        client: MockClient((req) async {
          expect(req.method, 'PATCH');
          // Datas vão em UTC (sufixo Z) — round-trip de fuso correto (regressão tz STORY-052).
          final body = jsonDecode(req.body) as Map<String, dynamic>;
          expect(body['data_inicio'] as String, endsWith('Z'));
          expect(body['data_fim'] as String, endsWith('Z'));
          return http.Response(
            jsonEncode({
              'id': 7,
              'estado': 'aberta',
              'material': true,
              'candidatos_notificados': 2,
              'diff': [
                {
                  'campo': 'valor',
                  'label': 'Valor',
                  'tipo': 'valor',
                  'antes': 120.0,
                  'depois': 150.0,
                },
              ],
            }),
            200,
          );
        }),
      );
      final r = await svc.editar(
        7,
        funcaoId: 1,
        dataInicio: DateTime(2026, 6, 12, 18),
        dataFim: DateTime(2026, 6, 12, 23),
        valor: 150,
        posicoes: 2,
      );
      expect(r, isA<EditarSuccess>());
      final s = r as EditarSuccess;
      expect(s.material, isTrue);
      expect(s.candidatosNotificados, 2);
      expect(s.diff.single.campo, 'valor');
    });

    test(
      '422 → ValidationError; 409 → Conflict; 403 → Forbidden; 500 → ServerError',
      () async {
        Future<EditarResult> withStatus(int s, [String body = '{}']) =>
            VagaService(
              client: MockClient((_) async => http.Response(body, s)),
            ).editar(
              7,
              funcaoId: 1,
              dataInicio: DateTime(2026, 6, 12, 18),
              dataFim: DateTime(2026, 6, 12, 23),
              valor: 150,
              posicoes: 2,
            );

        expect(
          await withStatus(
            422,
            jsonEncode({
              'errors': {
                'data_fim': ['O fim precisa ser depois do início.'],
              },
            }),
          ),
          isA<EditarValidationError>(),
        );
        expect(await withStatus(409), isA<EditarConflict>());
        expect(await withStatus(403), isA<EditarForbidden>());
        expect(await withStatus(500), isA<EditarServerError>());
      },
    );
  });

  group('CandidaturaService.manter/retirarAposEdicao (CA-7/CA-8)', () {
    test('manter 200 → Success(pendente)', () async {
      final svc = CandidaturaService(
        client: MockClient((req) async {
          expect(req.url.path, contains('confirmar-apos-edicao'));
          return http.Response(jsonEncode({'estado': 'pendente'}), 200);
        }),
      );
      final r = await svc.manterAposEdicao(33);
      expect(r, isA<RevisaoSuccess>());
      expect((r as RevisaoSuccess).estado, 'pendente');
    });

    test('retirar 200 → Success(retirada_por_edicao)', () async {
      final svc = CandidaturaService(
        client: MockClient((req) async {
          expect(req.url.path, contains('retirar-apos-edicao'));
          return http.Response(
            jsonEncode({'estado': 'retirada_por_edicao'}),
            200,
          );
        }),
      );
      final r = await svc.retirarAposEdicao(33);
      expect((r as RevisaoSuccess).estado, 'retirada_por_edicao');
    });

    test('409 → Conflict; 500 → Erro', () async {
      Future<RevisaoResult> manter(int s) => CandidaturaService(
        client: MockClient((_) async => http.Response('{}', s)),
      ).manterAposEdicao(33);

      expect(await manter(409), isA<RevisaoConflict>());
      expect(await manter(500), isA<RevisaoErro>());
    });
  });
}
