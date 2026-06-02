import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:turni_webapp/features/feed/feed_service.dart';

// STORY-048 — FeedService: parsing do contrato do feed (CA-1), filtros no querystring,
// e mapeamento de status (200/403/5xx/rede) para FeedSuccess/Forbidden/Error.

Map<String, dynamic> _vagaJson({
  int id = 1,
  int score = 97,
  double? dist = 3.0,
  bool podeCand = true,
}) => {
  'id': id,
  'funcao': 'Garçom',
  'data_inicio': '2026-06-12T18:00:00-03:00',
  'data_fim': '2026-06-12T23:00:00-03:00',
  'valor': 150.0,
  'distancia_km': dist,
  'score': {
    'total': score,
    'componentes': {
      'funcao': 40,
      'distancia': 20,
      'historico': 27,
      'nivel': 10,
    },
  },
  'ja_candidatou': false,
  'pode_candidatar': podeCand,
};

void main() {
  test('200 → FeedSuccess parseia vagas, page e has_next (CA-1)', () async {
    late Uri capturada;
    final svc = FeedService(
      client: MockClient((req) async {
        capturada = req.url;
        return http.Response(
          jsonEncode({
            'vagas': [_vagaJson(score: 94)],
            'page': 1,
            'has_next': true,
          }),
          200,
        );
      }),
    );

    final res = await svc.fetch(filtro: FeedFiltro.altoMatch, page: 1);

    expect(res, isA<FeedSuccess>());
    final ok = res as FeedSuccess;
    expect(ok.vagas, hasLength(1));
    expect(ok.vagas.first.score.total, 94);
    expect(ok.vagas.first.distanciaKm, 3.0);
    expect(ok.hasNext, isTrue);
    // O filtro vai no querystring.
    expect(capturada.query, contains('filtro=alto_match'));
    expect(capturada.query, contains('page=1'));
  });

  test('distancia_km null é preservada como null', () async {
    final svc = FeedService(
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'vagas': [_vagaJson(dist: null)],
            'page': 1,
            'has_next': false,
          }),
          200,
        ),
      ),
    );
    final res = await svc.fetch() as FeedSuccess;
    expect(res.vagas.first.distanciaKm, isNull);
  });

  test('403 → FeedForbidden (RBAC)', () async {
    final svc = FeedService(
      client: MockClient((_) async => http.Response('', 403)),
    );
    expect(await svc.fetch(), isA<FeedForbidden>());
  });

  test('5xx → FeedError', () async {
    final svc = FeedService(
      client: MockClient((_) async => http.Response('erro', 500)),
    );
    expect(await svc.fetch(), isA<FeedError>());
  });

  test('exceção de rede → FeedError', () async {
    final svc = FeedService(
      client: MockClient((_) async => throw Exception('sem rede')),
    );
    expect(await svc.fetch(), isA<FeedError>());
  });

  test('FeedFiltro.fromSlug mapeia slug e cai em todas no desconhecido', () {
    expect(FeedFiltro.fromSlug('minha_funcao'), FeedFiltro.minhaFuncao);
    expect(FeedFiltro.fromSlug('xpto'), FeedFiltro.todas);
    expect(FeedFiltro.fromSlug(null), FeedFiltro.todas);
  });
}
