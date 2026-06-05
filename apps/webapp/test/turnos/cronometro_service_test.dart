import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:turni_webapp/features/turnos/cronometro_service.dart';

// STORY-063 — CronometroService: parse da âncora (CA-4), janela de polling do servidor
// (CA-1 "configurável") e falhas (rede/RBAC/payload inválido) → null, que o componente
// trata como "não reconciliado" (CA-6: o tick local segue valendo).

Map<String, dynamic> _payload({Map<String, dynamic>? extra}) => {
  'estado': 'ativo',
  'iniciado_em': '2026-06-12T18:02:00Z',
  'encerrado_em': null,
  'servidor_agora': '2026-06-12T20:37:34Z',
  'polling_segundos': 5,
  'sou_profissional': true,
  ...?extra,
};

CronometroService _svc(int status, [Object? body]) => CronometroService(
  client: MockClient((req) async {
    expect(req.url.path, '/api/turnos/u1/cronometro');
    return http.Response(body == null ? '' : jsonEncode(body), status);
  }),
);

void main() {
  test('parse da âncora: instantes UTC + janela de polling', () async {
    final snap = await _svc(200, _payload()).fetch('u1');

    expect(snap, isNotNull);
    expect(snap!.estado, 'ativo');
    expect(snap.iniciadoEm, DateTime.parse('2026-06-12T18:02:00Z'));
    expect(snap.encerradoEm, isNull);
    expect(snap.servidorAgora, DateTime.parse('2026-06-12T20:37:34Z'));
    expect(snap.pollingSegundos, 5);
  });

  test(
    'encerrado_em presente (aguardando_checkout/finalizado) é parseado',
    () async {
      final snap = await _svc(
        200,
        _payload(
          extra: {
            'estado': 'aguardando_checkout',
            'encerrado_em': '2026-06-12T23:04:13Z',
          },
        ),
      ).fetch('u1');

      expect(snap!.estado, 'aguardando_checkout');
      expect(snap.encerradoEm, DateTime.parse('2026-06-12T23:04:13Z'));
    },
  );

  test('polling_segundos ausente degrada para o default 5', () async {
    final payload = _payload()..remove('polling_segundos');
    final snap = await _svc(200, payload).fetch('u1');

    expect(snap!.pollingSegundos, 5);
  });

  test(
    'falhas → null: RBAC (404), sessão (401), 5xx e payload inválido',
    () async {
      expect(await _svc(404, {'message': 'nope'}).fetch('u1'), isNull);
      expect(await _svc(401).fetch('u1'), isNull);
      expect(await _svc(500).fetch('u1'), isNull);
      expect(await _svc(200, 'não é json').fetch('u1'), isNull);
    },
  );

  test('erro de rede (client lança) → null', () async {
    final svc = CronometroService(
      client: MockClient((_) async => throw http.ClientException('offline')),
    );
    expect(await svc.fetch('u1'), isNull);
  });
}
