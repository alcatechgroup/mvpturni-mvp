import 'dart:convert';

import 'package:http/http.dart' as http;

import '../cadastro/shared/cadastro_types.dart' show cadastroApiBase;

/// STORY-087 / ADR-019 (CA-3) — captura da avaliação recíproca do turno.
///
/// POST /api/turnos/{id}/avaliar com estrelas obrigatórias (1–5) + comentário opcional. A
/// direção/avaliado derivam do papel do autor no SERVIDOR (RBAC fail-secure — STORY-085); o
/// front não escolhe sentido. Respostas traduzidas: 201 enviada / 409 já avaliado (UNIQUE
/// direção/turno) / 422 estado não-avaliável / 403 não-participante / rede → erro recuperável.
/// Sessão Sanctum same-origin (IDR-019) — sem CSRF mid-sessão (memória do projeto).

sealed class AvaliarResult {}

/// 201 — avaliação registrada; o motor de reputação já recomputou na transação.
class AvaliacaoEnviada extends AvaliarResult {
  AvaliacaoEnviada(this.estrelas);

  final int estrelas;
}

/// 409 `ja_avaliado` — a direção deste usuário já tem avaliação (reenvio). Estado
/// informativo, não erro: "Você já avaliou este turno." (SCREEN-084 §4.4).
class AvaliacaoJaRegistrada extends AvaliarResult {}

/// 422 — o turno saiu de um estado avaliável (mudou debaixo do usuário).
class AvaliacaoEstadoInvalido extends AvaliarResult {}

/// 403 — quem não participou do turno não avalia (RBAC fail-secure).
class AvaliacaoNaoAutorizada extends AvaliarResult {}

/// Rede/indisponibilidade ou status inesperado — recuperável (a tela mantém o
/// estado preenchido e oferece "tentar de novo" — SCREEN-084 §4.4).
class AvaliacaoErro extends AvaliarResult {}

class AvaliarTurnoService {
  AvaliarTurnoService({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  Future<AvaliarResult> enviar(
    String turnoId, {
    required int estrelas,
    String? comentario,
  }) async {
    http.Response res;
    try {
      res = await _client.post(
        Uri.parse('$cadastroApiBase/api/turnos/$turnoId/avaliar'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'estrelas': estrelas, 'comentario': ?comentario}),
      );
    } catch (_) {
      return AvaliacaoErro();
    }

    switch (res.statusCode) {
      case 201:
        return AvaliacaoEnviada(estrelas);
      case 409:
        return AvaliacaoJaRegistrada();
      case 422:
        return AvaliacaoEstadoInvalido();
      case 403:
        return AvaliacaoNaoAutorizada();
      default:
        return AvaliacaoErro();
    }
  }
}
