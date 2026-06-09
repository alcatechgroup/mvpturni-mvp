import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:turni_webapp/features/vagas/candidatura_service.dart';

// STORY-088 (CA-4) — o bloqueio do gate de avaliação carrega o turno_id pendente para o
// deep-link "Avaliar agora". STORY-050 já cobre o resto dos desfechos (201/409/403/conflito);
// aqui foco no contrato detalhe.turno_id que destrava a UX do gate (T4).

CandidaturaService _svc(http.Response Function() resposta) =>
    CandidaturaService(client: MockClient((_) async => resposta()));

void main() {
  test('422 gate_avaliacao → CandidaturaBloqueada carrega turnoId do detalhe', () async {
    final svc = _svc(
      () => http.Response(
        jsonEncode({
          'erro': 'gate_avaliacao',
          'mensagem': 'Avalie seu último turno para se candidatar.',
          'detalhe': {'turno_id': 'turno-9'},
        }),
        422,
        headers: {'content-type': 'application/json'},
      ),
    );

    final r = await svc.candidatar('v1');
    expect(r, isA<CandidaturaBloqueada>());
    final b = r as CandidaturaBloqueada;
    expect(b.erro, 'gate_avaliacao');
    expect(b.turnoId, 'turno-9');
  });

  test('fail-secure: gate sem turno_id (detalhe null) → turnoId null', () async {
    final svc = _svc(
      () => http.Response(
        jsonEncode({
          'erro': 'gate_avaliacao',
          'mensagem': 'Avalie seu último turno para se candidatar.',
          'detalhe': {'turno_id': null},
        }),
        422,
        headers: {'content-type': 'application/json'},
      ),
    );

    final b = await svc.candidatar('v1') as CandidaturaBloqueada;
    expect(b.turnoId, isNull);
  });

  test('outro gate (conflito) não tem turnoId', () async {
    final svc = _svc(
      () => http.Response(
        jsonEncode({
          'erro': 'conflito_horario',
          'mensagem': 'Conflito de horário.',
          'detalhe': {
            'conflito_com': {'vaga_id': 'v2'},
          },
        }),
        422,
        headers: {'content-type': 'application/json'},
      ),
    );

    final b = await svc.candidatar('v1') as CandidaturaBloqueada;
    expect(b.turnoId, isNull);
    expect(b.conflito?.vagaId, 'v2');
  });
}
