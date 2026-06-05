import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:turni_webapp/features/turno/geolocalizacao.dart';
import 'package:turni_webapp/features/turnos/pin_checkin_service.dart';

// STORY-061 — PinCheckinService: captura a posição (injetável; PDR-008 nunca bloqueia),
// POST gerar-pin-checkin com o contrato do CA-2 e traduz as respostas do backend
// (200 pin plaintext / 422 fora_da_janela / 422 estado_invalido / erro). Cancelamento idem.

void main() {
  Map<String, dynamic>? corpoEnviado;

  PinCheckinService service({
    required http.Response Function() resposta,
    PosicaoGeo posicao = const PosicaoGeo(
      lat: -23.55,
      lng: -46.63,
      accuracyM: 12.5,
    ),
  }) {
    corpoEnviado = null;
    return PinCheckinService(
      client: MockClient((req) async {
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
      'pin': '4702',
      'estado': 'aguardando_checkin',
      'geofencing_check_in': {
        'ok': true,
        'distancia_metros': 23.4,
        'razao': null,
        'capturado_em': '2026-06-05T18:00:00Z',
      },
    }),
    200,
    headers: {'content-type': 'application/json'},
  );

  group('gerar', () {
    test(
      'geo concedida → POST com lat/lng/accuracy e PinGerado com plaintext',
      () async {
        final svc = service(resposta: ok200);

        final r = await svc.gerar('t1');

        expect(r, isA<PinGerado>());
        final gerado = r as PinGerado;
        expect(gerado.pin, '4702');
        expect(gerado.geofencing.ok, isTrue);
        expect(gerado.geofencing.distanciaMetros, 23.4);

        expect(corpoEnviado!['pin_solicitado'], isTrue);
        expect(corpoEnviado!['lat'], -23.55);
        expect(corpoEnviado!['lng'], -46.63);
        expect(corpoEnviado!['accuracy_m'], 12.5);
        expect(corpoEnviado!.containsKey('razao'), isFalse);
      },
    );

    test(
      'geo negada → POST com geo nulo + razão; PIN gerado mesmo assim (PDR-008)',
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

    test('422 fora_da_janela → PinForaDaJanela com horários', () async {
      final svc = service(
        resposta: () => http.Response(
          jsonEncode({
            'motivo': 'fora_da_janela',
            'janela': {
              'abre_em': '2026-06-12T17:30:00-03:00',
              'fecha_em': '2026-06-12T20:00:00-03:00',
            },
          }),
          422,
          headers: {'content-type': 'application/json'},
        ),
      );

      final r = await svc.gerar('t1');

      expect(r, isA<PinForaDaJanela>());
      expect((r as PinForaDaJanela).abreEm, isNotNull);
    });

    test('422 estado_invalido → PinGeracaoEstadoInvalido', () async {
      final svc = service(
        resposta: () => http.Response(
          jsonEncode({'motivo': 'estado_invalido', 'estado': 'ativo'}),
          422,
          headers: {'content-type': 'application/json'},
        ),
      );

      expect(await svc.gerar('t1'), isA<PinGeracaoEstadoInvalido>());
    });

    test('500 → PinGeracaoErro; exceção de rede → PinGeracaoErro', () async {
      expect(
        await service(resposta: () => http.Response('erro', 500)).gerar('t1'),
        isA<PinGeracaoErro>(),
      );

      final svcRede = PinCheckinService(
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
    test('200 → PinCancelado', () async {
      final svc = service(
        resposta: () =>
            http.Response(jsonEncode({'estado': 'confirmado'}), 200),
      );

      expect(await svc.cancelar('t1'), isA<PinCancelado>());
    });

    test(
      '422 estado_invalido → PinCancelEstadoInvalido (alguém validou antes)',
      () async {
        final svc = service(
          resposta: () => http.Response(
            jsonEncode({'motivo': 'estado_invalido', 'estado': 'ativo'}),
            422,
          ),
        );

        expect(await svc.cancelar('t1'), isA<PinCancelEstadoInvalido>());
      },
    );

    test('erro de rede → PinCancelErro', () async {
      final svc = PinCheckinService(
        client: MockClient((_) async => throw Exception('sem rede')),
        capturar: () async => const PosicaoGeo(razao: 'timeout'),
      );

      expect(await svc.cancelar('t1'), isA<PinCancelErro>());
    });
  });
}
