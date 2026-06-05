import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:turni_webapp/features/turnos/validar_checkin_service.dart';

// STORY-062 — ValidarCheckinService: POST validar-checkin com o PIN digitado e traduz
// as respostas do backend (200 ativo / 422 pin_invalido / 422 pin_expirado /
// 422 estado_invalido / 429 rate limit / erro). Recusa com motivo opcional idem.

void main() {
  Map<String, dynamic>? corpoEnviado;
  String? pathChamado;

  ValidarCheckinService service(http.Response Function() resposta) {
    corpoEnviado = null;
    pathChamado = null;
    return ValidarCheckinService(
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

  group('validar', () {
    test('200 → PinValidado; POST leva o PIN digitado', () async {
      final svc = service(
        () => http.Response(jsonEncode({'estado': 'ativo'}), 200),
      );

      final r = await svc.validar('t1', '4702');

      expect(r, isA<PinValidado>());
      expect(pathChamado, '/api/turnos/t1/validar-checkin');
      expect(corpoEnviado!['pin'], '4702');
    });

    test('422 pin_invalido → PinInvalido (CA-2)', () async {
      expect(
        await service(() => json422('pin_invalido')).validar('t1', '0000'),
        isA<PinInvalido>(),
      );
    });

    test('422 pin_expirado → PinExpirado (CA-3)', () async {
      expect(
        await service(() => json422('pin_expirado')).validar('t1', '0000'),
        isA<PinExpirado>(),
      );
    });

    test(
      '422 estado_invalido → ValidarEstadoInvalido (mudou em outra aba)',
      () async {
        expect(
          await service(() => json422('estado_invalido')).validar('t1', '4702'),
          isA<ValidarEstadoInvalido>(),
        );
      },
    );

    test('429 → ValidarRateLimit (CA-2)', () async {
      expect(
        await service(
          () => http.Response(jsonEncode({'motivo': 'rate_limit'}), 429),
        ).validar('t1', '4702'),
        isA<ValidarRateLimit>(),
      );
    });

    test(
      '500 → ValidarErro; rede → ValidarErro; 422 malformado → ValidarErro',
      () async {
        expect(
          await service(() => http.Response('erro', 500)).validar('t1', '4702'),
          isA<ValidarErro>(),
        );

        final svcRede = ValidarCheckinService(
          client: MockClient((_) async => throw Exception('sem rede')),
        );
        expect(await svcRede.validar('t1', '4702'), isA<ValidarErro>());

        expect(
          await service(
            () => http.Response('não-json', 422),
          ).validar('t1', '4702'),
          isA<ValidarErro>(),
        );
      },
    );
  });

  group('recusar', () {
    test(
      '200 → RecusaOk; motivo vai no corpo quando presente (CA-6)',
      () async {
        final svc = service(
          () => http.Response(jsonEncode({'estado': 'confirmado'}), 200),
        );

        final r = await svc.recusar('t1', motivo: 'não chegou');

        expect(r, isA<RecusaOk>());
        expect(pathChamado, '/api/turnos/t1/recusar-checkin');
        expect(corpoEnviado!['motivo'], 'não chegou');
      },
    );

    test('sem motivo → corpo sem a chave (opcional de verdade)', () async {
      final svc = service(
        () => http.Response(jsonEncode({'estado': 'confirmado'}), 200),
      );

      await svc.recusar('t1');

      expect(corpoEnviado ?? const {}, isNot(contains('motivo')));
    });

    test('422 estado_invalido → RecusaEstadoInvalido', () async {
      expect(
        await service(() => json422('estado_invalido')).recusar('t1'),
        isA<RecusaEstadoInvalido>(),
      );
    });

    test('erro de rede/500 → RecusaErro', () async {
      expect(
        await service(() => http.Response('erro', 500)).recusar('t1'),
        isA<RecusaErro>(),
      );

      final svcRede = ValidarCheckinService(
        client: MockClient((_) async => throw Exception('sem rede')),
      );
      expect(await svcRede.recusar('t1'), isA<RecusaErro>());
    });
  });
}
