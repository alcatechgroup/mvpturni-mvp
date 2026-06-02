import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:turni_webapp/features/vagas/candidatos_service.dart';
import 'package:turni_webapp/features/vagas/vaga_detalhe_service.dart'
    show ComponenteMatch, EstadoComponente;

// STORY-051 — CandidatosService: parsing do contrato do painel (CA-1), snapshot do breakdown
// (CA-4), alerta de habitualidade (CA-5), mapeamento de status (200/403/404/5xx/rede) e bordas
// (lista vazia, snapshot nulo).

const _utf8 = {'content-type': 'application/json; charset=utf-8'};

Map<String, dynamic> _candidatoJson({
  int id = 1,
  int profId = 10,
  String nome = 'Júlia Santos',
  String? foto,
  String? funcao = 'Garçom',
  String? nivel = 'Elite',
  double? scoreHist = 4.9,
  String? plano,
  int? score = 92,
  bool comBreakdown = true,
  bool alerta = false,
}) => {
  'id': id,
  'profissional': {
    'id': profId,
    'nome': nome,
    'foto_url': foto,
    'funcao_primaria': funcao,
    'nivel': nivel,
    'score_historico': scoreHist,
    'plano': plano,
  },
  'score_no_momento': score,
  'score_breakdown': comBreakdown
      ? {
          'total': score,
          'componentes': {
            'funcao': 40,
            'distancia': 20,
            'historico': 22,
            'nivel': 10,
          },
          'breakdown': {
            'funcao': {
              'pontos': 40,
              'pontos_max': 40,
              'estado': 'ok',
              'descricao': 'Função primária bate',
            },
            'distancia': {
              'pontos': 20,
              'pontos_max': 20,
              'estado': 'ok',
              'descricao': 'A 2 km',
            },
            'historico': {
              'pontos': 22,
              'pontos_max': 30,
              'estado': 'partial',
              'descricao': 'Média 4,9★ em 127 turnos',
            },
            'nivel': {
              'pontos': 10,
              'pontos_max': 10,
              'estado': 'ok',
              'descricao': 'Elite na trilha',
            },
          },
        }
      : null,
  'candidatou_em': '2026-06-12T14:20:00-03:00',
  'alerta_habitualidade': alerta,
};

CandidatosService _svc(Map<String, dynamic> body, {int status = 200}) =>
    CandidatosService(
      client: MockClient(
        (_) async => http.Response(jsonEncode(body), status, headers: _utf8),
      ),
    );

void main() {
  test(
    '200 → CandidatosSuccess parseia o contrato + chama a URL certa (CA-1)',
    () async {
      late Uri capturada;
      final svc = CandidatosService(
        client: MockClient((req) async {
          capturada = req.url;
          return http.Response(
            jsonEncode({
              'candidatos': [_candidatoJson()],
              'total': 1,
            }),
            200,
            headers: _utf8,
          );
        }),
      );

      final res = await svc.fetch(7);

      expect(capturada.path, endsWith('/api/vagas/7/candidatos'));
      expect(res, isA<CandidatosSuccess>());
      final s = res as CandidatosSuccess;
      expect(s.total, 1);
      final c = s.candidatos.single;
      expect(c.id, 1);
      expect(c.profissional.nome, 'Júlia Santos');
      expect(c.profissional.funcaoPrimaria, 'Garçom');
      expect(c.profissional.nivel, 'Elite');
      expect(c.profissional.scoreHistorico, 4.9);
      expect(c.profissional.plano, isNull);
      expect(c.scoreNoMomento, 92);
      expect(c.alertaHabitualidade, isFalse);
      expect(c.candidatouEm, isNotNull);
    },
  );

  test('breakdown vem na ordem canônica e estados corretos (CA-4)', () async {
    final res =
        await _svc({
              'candidatos': [_candidatoJson()],
              'total': 1,
            }).fetch(7)
            as CandidatosSuccess;

    final score = res.candidatos.single.score!;
    expect(score.total, 92);
    expect(score.linhas.map((l) => l.componente).toList(), [
      ComponenteMatch.funcao,
      ComponenteMatch.distancia,
      ComponenteMatch.historico,
      ComponenteMatch.nivel,
    ]);
    expect(score.linhas[2].estado, EstadoComponente.partial);
    expect(score.linhas[2].pontos, 22);
  });

  test('alerta_habitualidade true é parseado (CA-5)', () async {
    final res =
        await _svc({
              'candidatos': [_candidatoJson(alerta: true)],
              'total': 1,
            }).fetch(7)
            as CandidatosSuccess;

    expect(res.candidatos.single.alertaHabitualidade, isTrue);
  });

  test('lista vazia → total 0 e sem candidatos (CA-7 / borda)', () async {
    final res =
        await _svc({'candidatos': <dynamic>[], 'total': 0}).fetch(7)
            as CandidatosSuccess;

    expect(res.total, 0);
    expect(res.candidatos, isEmpty);
  });

  test(
    'score_breakdown nulo → score nulo sem quebrar (borda fail-soft)',
    () async {
      final res =
          await _svc({
                'candidatos': [
                  _candidatoJson(comBreakdown: false, score: null),
                ],
                'total': 1,
              }).fetch(7)
              as CandidatosSuccess;

      final c = res.candidatos.single;
      expect(c.score, isNull);
      expect(c.scoreNoMomento, isNull);
    },
  );

  test('iniciais do avatar saem do nome (1 e 2 palavras)', () async {
    final res =
        await _svc({
              'candidatos': [
                _candidatoJson(id: 1, nome: 'Júlia Santos'),
                _candidatoJson(id: 2, nome: 'Madonna'),
              ],
              'total': 2,
            }).fetch(7)
            as CandidatosSuccess;

    expect(res.candidatos[0].profissional.iniciais, 'JS');
    expect(res.candidatos[1].profissional.iniciais, 'M');
  });

  test('403 → CandidatosForbidden (RBAC — CA-1)', () async {
    final res = await _svc(const {}, status: 403).fetch(7);
    expect(res, isA<CandidatosForbidden>());
  });

  test('404 → CandidatosNotFound', () async {
    final res = await _svc(const {}, status: 404).fetch(7);
    expect(res, isA<CandidatosNotFound>());
  });

  test('500 → CandidatosError', () async {
    final res = await _svc(const {}, status: 500).fetch(7);
    expect(res, isA<CandidatosError>());
  });

  test('exceção de rede → CandidatosError', () async {
    final svc = CandidatosService(
      client: MockClient((_) async => throw http.ClientException('sem rede')),
    );
    expect(await svc.fetch(7), isA<CandidatosError>());
  });

  test('JSON inválido no 200 → CandidatosError', () async {
    final svc = CandidatosService(
      client: MockClient(
        (_) async => http.Response('not json', 200, headers: _utf8),
      ),
    );
    expect(await svc.fetch(7), isA<CandidatosError>());
  });
}
