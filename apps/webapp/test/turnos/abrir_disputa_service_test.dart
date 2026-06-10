import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:turni_webapp/features/turnos/abrir_disputa_service.dart';

// STORY-094 / ADR-020 (Decisão 2) — AbrirDisputaService: POST abrir-disputa com a
// justificativa e traduz as respostas (200 em_disputa / 422 justificativa_obrigatoria /
// 422 estado_invalido / 403 / rede-5xx). Espelha o teste da ValidarCheckoutService (064).

void main() {
  Map<String, dynamic>? corpoEnviado;
  String? pathChamado;

  AbrirDisputaService service(http.Response Function() resposta) {
    corpoEnviado = null;
    pathChamado = null;
    return AbrirDisputaService(
      client: MockClient((req) async {
        pathChamado = req.url.path;
        if (req.body.isNotEmpty) {
          corpoEnviado = jsonDecode(req.body) as Map<String, dynamic>;
        }
        return resposta();
      }),
    );
  }

  http.Response json422(String motivo) => http.Response(
    jsonEncode({'motivo': motivo}),
    422,
    headers: {'content-type': 'application/json'},
  );

  test('200 → AbrirDisputaOk(em_disputa); POST leva a justificativa', () async {
    final svc = service(
      () => http.Response(jsonEncode({'estado': 'em_disputa'}), 200),
    );

    final r = await svc.abrir('t1', 'saiu 40 min antes do fim');

    expect(r, isA<AbrirDisputaOk>());
    expect((r as AbrirDisputaOk).estado, 'em_disputa');
    expect(pathChamado, '/api/turnos/t1/abrir-disputa');
    expect(corpoEnviado!['justificativa'], 'saiu 40 min antes do fim');
  });

  test(
    '200 sem estado no corpo → AbrirDisputaOk(em_disputa) por padrão',
    () async {
      final svc = service(() => http.Response(jsonEncode({}), 200));

      final r = await svc.abrir('t1', 'problema');

      expect((r as AbrirDisputaOk).estado, 'em_disputa');
    },
  );

  test(
    '422 justificativa_obrigatoria → AbrirDisputaJustificativaObrigatoria',
    () async {
      expect(
        await service(
          () => json422('justificativa_obrigatoria'),
        ).abrir('t1', ''),
        isA<AbrirDisputaJustificativaObrigatoria>(),
      );
    },
  );

  test(
    '422 estado_invalido → AbrirDisputaEstadoInvalido (mudou em outra aba)',
    () async {
      expect(
        await service(() => json422('estado_invalido')).abrir('t1', 'x'),
        isA<AbrirDisputaEstadoInvalido>(),
      );
    },
  );

  test('403 → AbrirDisputaForbidden (RBAC fail-secure)', () async {
    expect(
      await service(() => http.Response('', 403)).abrir('t1', 'x'),
      isA<AbrirDisputaForbidden>(),
    );
  });

  test(
    '500 / rede / 422 malformado / motivo desconhecido → AbrirDisputaErro',
    () async {
      expect(
        await service(() => http.Response('erro', 500)).abrir('t1', 'x'),
        isA<AbrirDisputaErro>(),
      );

      final svcRede = AbrirDisputaService(
        client: MockClient((_) async => throw Exception('sem rede')),
      );
      expect(await svcRede.abrir('t1', 'x'), isA<AbrirDisputaErro>());

      expect(
        await service(() => http.Response('nao-json', 422)).abrir('t1', 'x'),
        isA<AbrirDisputaErro>(),
      );

      expect(
        await service(() => json422('motivo_novo')).abrir('t1', 'x'),
        isA<AbrirDisputaErro>(),
      );
    },
  );
}
