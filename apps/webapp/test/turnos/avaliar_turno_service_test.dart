import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:turni_webapp/features/turnos/avaliar_turno_service.dart';

// STORY-087 — AvaliarTurnoService: POST /api/turnos/{id}/avaliar com estrelas (1–5) +
// comentário opcional, traduzindo as respostas do backend (STORY-085): 201 enviada /
// 409 ja_avaliado / 422 estado_invalido / 403 não autorizado / rede → erro.

void main() {
  Map<String, dynamic>? corpoEnviado;
  String? pathChamado;
  String? metodo;

  AvaliarTurnoService service(http.Response Function() resposta) {
    corpoEnviado = null;
    pathChamado = null;
    metodo = null;
    return AvaliarTurnoService(
      client: MockClient((req) async {
        pathChamado = req.url.path;
        metodo = req.method;
        if (req.body.isNotEmpty) {
          corpoEnviado = jsonDecode(req.body) as Map<String, dynamic>;
        }
        return resposta();
      }),
    );
  }

  // (a) feliz — 201: avaliação registrada; POST leva estrelas + comentário.
  test('201 → AvaliacaoEnviada; POST leva estrelas e comentário', () async {
    final svc = service(
      () => http.Response(
        jsonEncode({
          'id': 'a1',
          'direcao': 'profissional_para_contratante',
          'estrelas': 5,
          'comentario': 'Tudo certo',
        }),
        201,
        headers: {'content-type': 'application/json'},
      ),
    );

    final r = await svc.enviar('t1', estrelas: 5, comentario: 'Tudo certo');

    expect(r, isA<AvaliacaoEnviada>());
    expect(metodo, 'POST');
    expect(pathChamado, '/api/turnos/t1/avaliar');
    expect(corpoEnviado!['estrelas'], 5);
    expect(corpoEnviado!['comentario'], 'Tudo certo');
  });

  // (a) feliz — comentário ausente não vai no corpo (campo opcional).
  test('comentário nulo não viaja no corpo', () async {
    final svc = service(
      () => http.Response(jsonEncode({'id': 'a1', 'estrelas': 4}), 201),
    );

    await svc.enviar('t1', estrelas: 4);

    expect(corpoEnviado!['estrelas'], 4);
    expect(corpoEnviado!.containsKey('comentario'), isFalse);
  });

  // (c) exceção esperada — 409 ja_avaliado (UNIQUE direção/turno — ADR-019).
  test('409 → AvaliacaoJaRegistrada', () async {
    final svc = service(
      () => http.Response(jsonEncode({'motivo': 'ja_avaliado'}), 409),
    );

    expect(await svc.enviar('t1', estrelas: 3), isA<AvaliacaoJaRegistrada>());
  });

  // (b) inválido — 422 estado_invalido (turno saiu de finalizável).
  test('422 → AvaliacaoEstadoInvalido', () async {
    final svc = service(
      () => http.Response(
        jsonEncode({'motivo': 'estado_invalido', 'estado': 'ativo'}),
        422,
      ),
    );

    expect(await svc.enviar('t1', estrelas: 3), isA<AvaliacaoEstadoInvalido>());
  });

  // (b) RBAC — 403 (não participou do turno) → fail-secure no front.
  test('403 → AvaliacaoNaoAutorizada', () async {
    final svc = service(() => http.Response('', 403));

    expect(await svc.enviar('t1', estrelas: 3), isA<AvaliacaoNaoAutorizada>());
  });

  // (c) exceção — rede caiu: erro recuperável (a tela mantém o estado e oferece retry).
  test('exceção de rede → AvaliacaoErro', () async {
    final svc = AvaliarTurnoService(
      client: MockClient((_) async => throw Exception('sem rede')),
    );

    expect(await svc.enviar('t1', estrelas: 5), isA<AvaliacaoErro>());
  });

  // (d) borda — status inesperado (500) cai em erro genérico recuperável.
  test('500 → AvaliacaoErro', () async {
    final svc = service(() => http.Response('boom', 500));

    expect(await svc.enviar('t1', estrelas: 5), isA<AvaliacaoErro>());
  });
}
