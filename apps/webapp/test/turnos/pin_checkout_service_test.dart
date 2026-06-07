import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:turni_webapp/features/turno/geolocalizacao.dart';
import 'package:turni_webapp/features/turnos/pin_checkin_service.dart'
    show
        PinCancelEstadoInvalido,
        PinCancelErro,
        PinCancelado,
        PinGeracaoErro,
        PinGeracaoEstadoInvalido,
        PinGerado;
import 'package:turni_webapp/features/turnos/pin_checkout_service.dart';

// STORY-064 (F-NB-5 da validação do EPIC-003) — PinCheckoutService: captura a posição
// em SILÊNCIO (PDR-008 nunca bloqueia; sem janela horária — CA-1), POST
// gerar-pin-checkout e traduz as respostas do backend (200 pin plaintext /
// 422 estado_invalido / erro). Cancelamento volta a `ativo` (§4.6). Espelha o
// teste da PinCheckinService (061) — mesmos contratos, endpoints próprios.

void main() {
  Map<String, dynamic>? corpoEnviado;
  String? pathChamado;

  PinCheckoutService service({
    required http.Response Function() resposta,
    PosicaoGeo posicao = const PosicaoGeo(
      lat: -23.55,
      lng: -46.63,
      accuracyM: 12.5,
    ),
  }) {
    corpoEnviado = null;
    pathChamado = null;
    return PinCheckoutService(
      client: MockClient((req) async {
        pathChamado = req.url.path;
        if (req.method == 'POST' && req.body.isNotEmpty) {
          corpoEnviado = jsonDecode(req.body) as Map<String, dynamic>;
        }
        return resposta();
      }),
      capturar: () async => posicao,
    );
  }

  http.Response ok200() => http.Response(
    jsonEncode({
      'pin': '8315',
      'estado': 'aguardando_checkout',
      'geofencing_check_out': {
        'ok': true,
        'distancia_metros': 18.7,
        'razao': null,
        'capturado_em': '2026-06-06T22:00:00Z',
      },
    }),
    200,
    headers: {'content-type': 'application/json'},
  );

  group('gerar', () {
    test(
      'geo concedida → POST gerar-pin-checkout com lat/lng/accuracy e PinGerado',
      () async {
        final svc = service(resposta: ok200);

        final r = await svc.gerar('t1');

        expect(r, isA<PinGerado>());
        final gerado = r as PinGerado;
        expect(gerado.pin, '8315');
        expect(gerado.geofencing.ok, isTrue);
        expect(gerado.geofencing.distanciaMetros, 18.7);

        expect(pathChamado, '/api/turnos/t1/gerar-pin-checkout');
        expect(corpoEnviado!['pin_solicitado'], isTrue);
        expect(corpoEnviado!['lat'], -23.55);
        expect(corpoEnviado!['lng'], -46.63);
        expect(corpoEnviado!['accuracy_m'], 12.5);
        expect(corpoEnviado!.containsKey('razao'), isFalse);
      },
    );

    test(
      'geo negada → POST com geo nulo + razão; PIN gerado mesmo assim (PDR-008, silencioso)',
      () async {
        final svc = service(
          resposta: ok200,
          posicao: const PosicaoGeo(razao: 'permissao_negada'),
        );

        final r = await svc.gerar('t1');

        expect(r, isA<PinGerado>());
        expect(corpoEnviado!['pin_solicitado'], isTrue);
        expect(corpoEnviado!['lat'], isNull);
        expect(corpoEnviado!['lng'], isNull);
        expect(corpoEnviado!['razao'], 'permissao_negada');
      },
    );

    test(
      '422 → PinGeracaoEstadoInvalido (sem janela no check-out — todo 422 de negócio é estado)',
      () async {
        final svc = service(
          resposta: () => http.Response(
            jsonEncode({'motivo': 'estado_invalido', 'estado': 'finalizado'}),
            422,
            headers: {'content-type': 'application/json'},
          ),
        );

        expect(await svc.gerar('t1'), isA<PinGeracaoEstadoInvalido>());
      },
    );

    test('500 → PinGeracaoErro; exceção de rede → PinGeracaoErro', () async {
      expect(
        await service(resposta: () => http.Response('erro', 500)).gerar('t1'),
        isA<PinGeracaoErro>(),
      );

      final svcRede = PinCheckoutService(
        client: MockClient((_) async => throw Exception('sem rede')),
        capturar: () async => const PosicaoGeo(razao: 'timeout'),
      );
      expect(await svcRede.gerar('t1'), isA<PinGeracaoErro>());
    });

    test(
      '200 com payload malformado → PinGeracaoErro (parse nunca explode)',
      () async {
        final svc = service(
          resposta: () => http.Response('{"pin": null}', 200),
        );

        expect(await svc.gerar('t1'), isA<PinGeracaoErro>());
      },
    );
  });

  group('cancelar', () {
    test('200 → PinCancelado (turno volta a ativo — §4.6)', () async {
      final svc = service(
        resposta: () => http.Response(jsonEncode({'estado': 'ativo'}), 200),
      );

      final r = await svc.cancelar('t1');

      expect(r, isA<PinCancelado>());
      expect(pathChamado, '/api/turnos/t1/cancelar-pin-checkout');
    });

    test(
      '422 estado_invalido → PinCancelEstadoInvalido (alguém validou antes)',
      () async {
        final svc = service(
          resposta: () => http.Response(
            jsonEncode({'motivo': 'estado_invalido', 'estado': 'finalizado'}),
            422,
          ),
        );

        expect(await svc.cancelar('t1'), isA<PinCancelEstadoInvalido>());
      },
    );

    test('500 → PinCancelErro; erro de rede → PinCancelErro', () async {
      expect(
        await service(
          resposta: () => http.Response('erro', 500),
        ).cancelar('t1'),
        isA<PinCancelErro>(),
      );

      final svcRede = PinCheckoutService(
        client: MockClient((_) async => throw Exception('sem rede')),
        capturar: () async => const PosicaoGeo(razao: 'timeout'),
      );
      expect(await svcRede.cancelar('t1'), isA<PinCancelErro>());
    });
  });
}
