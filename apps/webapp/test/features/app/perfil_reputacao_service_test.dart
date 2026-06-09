import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:turni_webapp/features/app/perfil_reputacao_service.dart';

// STORY-088 — PerfilReputacaoService: GET /api/perfil/{id} (reputação consultável, STORY-085).
// Traduz o contrato: profissional (score/nível/XP-do-dono/depoimentos) × contratante (score +
// depoimentos anônimos). 404 → não encontrado; rede/5xx → erro recuperável.

void main() {
  String? pathChamado;

  PerfilReputacaoService service(http.Response Function() resposta) {
    pathChamado = null;
    return PerfilReputacaoService(
      client: MockClient((req) async {
        pathChamado = req.url.path;
        return resposta();
      }),
    );
  }

  http.Response ok(Map<String, dynamic> body) => http.Response(
    jsonEncode(body),
    200,
    headers: {'content-type': 'application/json'},
  );

  // (a) feliz — profissional (dono): score/nível/XP/turnos + depoimentos com função.
  test('200 profissional (dono): parse de score/nível/XP/depoimentos', () async {
    final svc = service(
      () => ok({
        'papel': 'profissional',
        'score': 4.9,
        'nivel': 'Confiavel',
        'turnos_realizados': 17,
        'total_avaliacoes': 27,
        'selo_novo': false,
        'xp': 680,
        'xp_proximo_nivel': 320,
        'depoimentos': [
          {
            'estrelas': 5,
            'comentario': 'Pontual',
            'funcao': 'Garçom',
            'autor_nome': 'Bar do Porto',
            'data': '2026-06-06T18:00:00Z',
          },
        ],
      }),
    );

    final r = await svc.fetch('u1');
    expect(pathChamado, '/api/perfil/u1');
    expect(r, isA<ReputacaoCarregada>());
    final p = (r as ReputacaoCarregada).perfil;
    expect(p.isProfissional, isTrue);
    expect(p.score, 4.9);
    expect(p.nivel, 'Confiavel');
    expect(p.turnosRealizados, 17);
    expect(p.totalAvaliacoes, 27);
    expect(p.seloNovo, isFalse);
    expect(p.temXp, isTrue);
    expect(p.xp, 680);
    expect(p.xpProximoNivel, 320);
    expect(p.depoimentos, hasLength(1));
    expect(p.depoimentos.first.funcao, 'Garçom');
    expect(p.depoimentos.first.autorNome, 'Bar do Porto');
    expect(p.depoimentos.first.data, isNotNull);
  });

  // (a) feliz — contratante: score + depoimentos anônimos, SEM nível/XP.
  test('200 contratante: papel contratante, sem nível/XP, autor anônimo', () async {
    final svc = service(
      () => ok({
        'papel': 'contratante',
        'score': 4.5,
        'total_avaliacoes': 8,
        'selo_novo': false,
        'depoimentos': [
          {
            'estrelas': 4,
            'comentario': 'Ambiente ótimo',
            'funcao': 'Cozinheiro',
            'autor_nome': null,
            'data': '2026-06-01T18:00:00Z',
          },
        ],
      }),
    );

    final p = (await svc.fetch('c1') as ReputacaoCarregada).perfil;
    expect(p.isProfissional, isFalse);
    expect(p.score, 4.5);
    expect(p.nivel, isNull);
    expect(p.temXp, isFalse);
    expect(p.depoimentos.first.autorNome, isNull);
    expect(p.depoimentos.first.funcao, 'Cozinheiro');
  });

  // (b/borda) vazio — selo "Novo", sem depoimentos.
  test('200 vazio: selo_novo true e depoimentos []', () async {
    final svc = service(
      () => ok({
        'papel': 'profissional',
        'score': 0,
        'nivel': 'Iniciante',
        'turnos_realizados': 0,
        'total_avaliacoes': 0,
        'selo_novo': true,
        'xp': 0,
        'xp_proximo_nivel': 500,
        'depoimentos': [],
      }),
    );

    final p = (await svc.fetch('u1') as ReputacaoCarregada).perfil;
    expect(p.seloNovo, isTrue);
    expect(p.depoimentos, isEmpty);
  });

  // (borda) Elite — dono sem próximo nível: temXp true, xpProximoNivel null.
  test('200 Elite (dono): xp presente, xp_proximo_nivel null', () async {
    final svc = service(
      () => ok({
        'papel': 'profissional',
        'score': 5.0,
        'nivel': 'Elite',
        'turnos_realizados': 120,
        'total_avaliacoes': 90,
        'selo_novo': false,
        'xp': 3200,
        'xp_proximo_nivel': null,
        'depoimentos': [],
      }),
    );

    final p = (await svc.fetch('u1') as ReputacaoCarregada).perfil;
    expect(p.temXp, isTrue);
    expect(p.xpProximoNivel, isNull);
  });

  // (borda) terceiro vê profissional sem XP — chaves xp ausentes.
  test('200 profissional visto por terceiro: sem chave xp → temXp false', () async {
    final svc = service(
      () => ok({
        'papel': 'profissional',
        'score': 4.7,
        'nivel': 'Confiavel',
        'turnos_realizados': 17,
        'total_avaliacoes': 27,
        'selo_novo': false,
        'depoimentos': [],
      }),
    );

    final p = (await svc.fetch('u1') as ReputacaoCarregada).perfil;
    expect(p.temXp, isFalse);
    expect(p.xp, isNull);
  });

  // (c) exceção — 404 → não encontrado.
  test('404 → ReputacaoNaoEncontrada', () async {
    final svc = service(() => http.Response('{}', 404));
    expect(await svc.fetch('x'), isA<ReputacaoNaoEncontrada>());
  });

  // (c) exceção — rede → erro recuperável.
  test('falha de rede → ReputacaoErro', () async {
    final svc = PerfilReputacaoService(
      client: MockClient((_) async => throw http.ClientException('offline')),
    );
    expect(await svc.fetch('x'), isA<ReputacaoErro>());
  });

  // (c) exceção — 500 → erro recuperável.
  test('500 → ReputacaoErro', () async {
    final svc = service(() => http.Response('erro', 500));
    expect(await svc.fetch('x'), isA<ReputacaoErro>());
  });
}
