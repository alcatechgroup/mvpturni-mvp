import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:turni_webapp/features/turno/turno_poc_service.dart';

// STORY-057 / ADR-017 — TurnoPocService: parsing da âncora do cronômetro e do snapshot de
// geofencing; mapeamento de status (200 → objeto; RBAC/erro/rede → null); body do POST.

void main() {
  group('cronometro (GET)', () {
    test('200 → snapshot com instantes UTC e estado', () async {
      late Uri url;
      final svc = TurnoPocService(
        client: MockClient((req) async {
          url = req.url;
          return http.Response(
            jsonEncode({
              'estado': 'ativo',
              'iniciado_em': '2026-06-04T12:00:00Z',
              'encerrado_em': null,
              'servidor_agora': '2026-06-04T13:00:00Z',
            }),
            200,
          );
        }),
      );

      final snap = await svc.cronometro('abc-123');

      expect(url.path, contains('/api/turnos/abc-123/cronometro'));
      expect(snap, isNotNull);
      expect(snap!.estado, 'ativo');
      expect(snap.iniciadoEm!.toUtc(), DateTime.utc(2026, 6, 4, 12));
      expect(snap.encerradoEm, isNull);
      expect(snap.servidorAgora.toUtc(), DateTime.utc(2026, 6, 4, 13));
    });

    test('iniciado_em null (antes do check-in) é preservado', () async {
      final svc = TurnoPocService(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'estado': 'confirmado',
              'iniciado_em': null,
              'encerrado_em': null,
              'servidor_agora': '2026-06-04T13:00:00Z',
            }),
            200,
          ),
        ),
      );

      final snap = await svc.cronometro('x');
      expect(snap!.iniciadoEm, isNull);
      expect(snap.estado, 'confirmado');
    });

    test('404 (RBAC) → null', () async {
      final svc = TurnoPocService(
        client: MockClient((_) async => http.Response('', 404)),
      );
      expect(await svc.cronometro('x'), isNull);
    });

    test('erro de rede → null', () async {
      final svc = TurnoPocService(
        client: MockClient((_) async => throw http.ClientException('sem rede')),
      );
      expect(await svc.cronometro('x'), isNull);
    });
  });

  group('checkinGeo (POST)', () {
    test(
      '200 dentro do raio → ok:true + distância; body carrega lat/lng',
      () async {
        late String body;
        final svc = TurnoPocService(
          client: MockClient((req) async {
            body = req.body;
            return http.Response(
              jsonEncode({
                'ok': true,
                'distancia_metros': 15.0,
                'razao': null,
                'capturado_em': '2026-06-04T13:00:00Z',
              }),
              200,
            );
          }),
        );

        final res = await svc.checkinGeo('t-1', lat: -23.55, lng: -46.63);

        final enviado = jsonDecode(body) as Map<String, dynamic>;
        expect(enviado['lat'], -23.55);
        expect(enviado['lng'], -46.63);
        expect(res!.ok, isTrue);
        expect(res.distanciaMetros, 15.0);
        expect(res.razao, isNull);
      },
    );

    test('200 sem coordenada → distância null + razão', () async {
      final svc = TurnoPocService(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'ok': false,
              'distancia_metros': null,
              'razao': 'permissao_negada',
              'capturado_em': '2026-06-04T13:00:00Z',
            }),
            200,
          ),
        ),
      );

      final res = await svc.checkinGeo('t-1', razao: 'permissao_negada');
      expect(res!.ok, isFalse);
      expect(res.distanciaMetros, isNull);
      expect(res.razao, 'permissao_negada');
    });

    test('422/erro → null', () async {
      final svc = TurnoPocService(
        client: MockClient((_) async => http.Response('', 422)),
      );
      expect(await svc.checkinGeo('t-1', lat: -200, lng: 0), isNull);
    });
  });
}
