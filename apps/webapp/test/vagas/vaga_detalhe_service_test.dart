import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:turni_webapp/features/vagas/vaga_detalhe_service.dart';

// STORY-049 — VagaDetalheService: parsing do contrato unificado (CA-1), ordem fixa do
// breakdown (CA-2/CA-3) e mapeamento de status (200/403/404/5xx/rede).

// A API real responde em UTF-8 (descrições têm '★'); sem o charset o http.Response do mock
// usa latin1 e quebraria ao codificar o corpo.
const _utf8 = {'content-type': 'application/json; charset=utf-8'};

Map<String, dynamic> _detalheJson({
  int total = 97,
  bool podeCand = true,
  bool jaCand = false,
  Map<String, dynamic>? candidatura,
  String? motivo,
  double? dist = 3.0,
}) => {
  'id': 7,
  'funcao': 'Garçom',
  'estabelecimento': 'Bar do Zé',
  'cidade': 'São Paulo',
  'data_inicio': '2026-06-12T18:00:00-03:00',
  'data_fim': '2026-06-12T23:00:00-03:00',
  'valor': 150.0,
  'distancia_km': dist,
  'score_breakdown': {
    'total': total,
    'componentes': {
      'funcao': 40,
      'distancia': 20,
      'historico': 27,
      'nivel': 10,
    },
    'breakdown': {
      'funcao': {
        'pontos': 40,
        'pontos_max': 40,
        'estado': 'ok',
        'descricao': 'Sua função primária bate',
      },
      'distancia': {
        'pontos': 20,
        'pontos_max': 20,
        'estado': 'ok',
        'descricao': 'Dentro do seu raio de 8km',
      },
      'historico': {
        'pontos': 27,
        'pontos_max': 30,
        'estado': 'partial',
        'descricao': 'Sua média 4.9★ em 127 turnos',
      },
      'nivel': {
        'pontos': 10,
        'pontos_max': 10,
        'estado': 'ok',
        'descricao': 'Elite na trilha',
      },
    },
  },
  'pode_candidatar': podeCand,
  'ja_candidatou': jaCand,
  'candidatura': candidatura,
  'motivo_bloqueio': motivo,
};

VagaDetalheService _svc(Map<String, dynamic> body) => VagaDetalheService(
  client: MockClient(
    (_) async => http.Response(jsonEncode(body), 200, headers: _utf8),
  ),
);

void main() {
  test('200 → DetalheSuccess parseia o contrato unificado (CA-1)', () async {
    late Uri capturada;
    final svc = VagaDetalheService(
      client: MockClient((req) async {
        capturada = req.url;
        return http.Response(jsonEncode(_detalheJson()), 200, headers: _utf8);
      }),
    );

    final res = await svc.fetch(7);

    expect(capturada.path, endsWith('/api/vagas/7/detalhe'));
    expect(res, isA<DetalheSuccess>());
    final v = (res as DetalheSuccess).vaga;
    expect(v.funcao, 'Garçom');
    expect(v.estabelecimento, 'Bar do Zé');
    expect(v.cidade, 'São Paulo');
    expect(v.valor, 150.0);
    expect(v.distanciaKm, 3.0);
    expect(v.score.total, 97);
    expect(v.podeCandidatar, isTrue);
    expect(v.jaCandidatou, isFalse);
    expect(v.candidatura, isNull);
    expect(v.motivoBloqueio, isNull);
  });

  test(
    'breakdown vem na ordem canônica função→distância→histórico→nível (CA-2/CA-3)',
    () async {
      final v = (await _svc(_detalheJson()).fetch(7) as DetalheSuccess).vaga;

      expect(v.score.linhas.map((l) => l.componente).toList(), [
        ComponenteMatch.funcao,
        ComponenteMatch.distancia,
        ComponenteMatch.historico,
        ComponenteMatch.nivel,
      ]);
      final hist = v.score.linhas[2];
      expect(hist.estado, EstadoComponente.partial);
      expect(hist.pontos, 27);
      expect(hist.pontosMax, 30);
      expect(hist.descricao, 'Sua média 4.9★ em 127 turnos');
    },
  );

  test('candidatura pendente parseia estado + criada_em (CA-6)', () async {
    final v =
        (await _svc(
                  _detalheJson(
                    jaCand: true,
                    candidatura: {
                      'estado': 'pendente',
                      'criada_em': '2026-06-02T14:20:00-03:00',
                    },
                  ),
                ).fetch(7)
                as DetalheSuccess)
            .vaga;

    expect(v.jaCandidatou, isTrue);
    expect(v.candidatura!.estado, 'pendente');
    expect(v.candidatura!.pendente, isTrue);
    expect(v.candidatura!.criadaEm, isNotNull);
  });

  test('gate: pode_candidatar false + motivo_bloqueio (CA-5)', () async {
    final v =
        (await _svc(
                  _detalheJson(
                    podeCand: false,
                    motivo: 'Avalie seu último turno para se candidatar.',
                  ),
                ).fetch(7)
                as DetalheSuccess)
            .vaga;

    expect(v.podeCandidatar, isFalse);
    expect(v.motivoBloqueio, 'Avalie seu último turno para se candidatar.');
  });

  test('distancia_km null é preservada (§4.8)', () async {
    final v =
        (await _svc(_detalheJson(dist: null)).fetch(7) as DetalheSuccess).vaga;
    expect(v.distanciaKm, isNull);
  });

  test('403 → DetalheForbidden (CA-7)', () async {
    final svc = VagaDetalheService(
      client: MockClient((_) async => http.Response('', 403)),
    );
    expect(await svc.fetch(7), isA<DetalheForbidden>());
  });

  test('404 → DetalheNotFound (§4.7)', () async {
    final svc = VagaDetalheService(
      client: MockClient((_) async => http.Response('', 404)),
    );
    expect(await svc.fetch(7), isA<DetalheNotFound>());
  });

  test('5xx → DetalheError', () async {
    final svc = VagaDetalheService(
      client: MockClient((_) async => http.Response('', 500)),
    );
    expect(await svc.fetch(7), isA<DetalheError>());
  });

  test('corpo inválido em 200 → DetalheError (defensivo)', () async {
    final svc = VagaDetalheService(
      client: MockClient((_) async => http.Response('isto nao e json', 200)),
    );
    expect(await svc.fetch(7), isA<DetalheError>());
  });

  test('falha de rede → DetalheError', () async {
    final svc = VagaDetalheService(
      client: MockClient((_) async => throw Exception('sem rede')),
    );
    expect(await svc.fetch(7), isA<DetalheError>());
  });
}
