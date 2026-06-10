import 'dart:convert';

import 'package:http/http.dart' as http;

import '../cadastro/shared/cadastro_types.dart' show cadastroApiBase;

/// STORY-094 / ADR-020 (Decisão 2) — abertura de disputa pelo CONTRATANTE: o ramo
/// "contestar por mérito" do check-out, DISTINTO de `recusar-checkout` (que devolve a
/// `ativo`). `POST /api/turnos/{id}/abrir-disputa { justificativa }` transita
/// `aguardando_checkout → em_disputa` com justificativa OBRIGATÓRIA e mantém a
/// pré-autorização. Sessão Sanctum same-origin: o cookie trafega sozinho — não refazemos
/// `/sanctum/csrf-cookie` no meio da sessão (IDR-019).
///
/// Contrato (STORY-092): 200 `{ estado: 'em_disputa' }`; 422 `justificativa_obrigatoria`
/// (o diálogo já bloqueia o envio vazio — defesa em profundidade) / `estado_invalido`
/// (o turno já saiu de `aguardando_checkout` em outra aba — a UI recarrega a verdade);
/// 403 (RBAC: só o contratante dono); rede/5xx → erro recuperável.
sealed class AbrirDisputaResult {}

/// 200 — disputa aberta; o turno está em `em_disputa` (a UI recarrega para refletir).
class AbrirDisputaOk extends AbrirDisputaResult {
  AbrirDisputaOk(this.estado);

  final String estado;
}

/// 422 `justificativa_obrigatoria` — o servidor recusou por justificativa vazia (o
/// diálogo já impede isso; mantido por defesa em profundidade → erro no campo).
class AbrirDisputaJustificativaObrigatoria extends AbrirDisputaResult {}

/// 422 `estado_invalido` — o turno já não está em `aguardando_checkout` (mudou em outra
/// aba); a UI recarrega silenciosamente a verdade do servidor.
class AbrirDisputaEstadoInvalido extends AbrirDisputaResult {}

/// 403 — papel/dono errado (RBAC fail-secure no servidor); erro claro, sem expor detalhe.
class AbrirDisputaForbidden extends AbrirDisputaResult {}

/// Rede/5xx/payload malformado — erro recuperável; o diálogo mantém o texto digitado.
class AbrirDisputaErro extends AbrirDisputaResult {}

class AbrirDisputaService {
  AbrirDisputaService({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  /// POST /api/turnos/{id}/abrir-disputa com `{ justificativa }` (CA-3).
  Future<AbrirDisputaResult> abrir(String turnoId, String justificativa) async {
    http.Response res;
    try {
      res = await _client.post(
        Uri.parse('$cadastroApiBase/api/turnos/$turnoId/abrir-disputa'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'justificativa': justificativa}),
      );
    } catch (_) {
      return AbrirDisputaErro();
    }

    switch (res.statusCode) {
      case 200:
        try {
          final json = jsonDecode(res.body) as Map<String, dynamic>;
          return AbrirDisputaOk(json['estado'] as String? ?? 'em_disputa');
        } catch (_) {
          return AbrirDisputaOk('em_disputa');
        }
      case 403:
        return AbrirDisputaForbidden();
      case 422:
        try {
          final json = jsonDecode(res.body) as Map<String, dynamic>;
          return switch (json['motivo']) {
            'justificativa_obrigatoria' =>
              AbrirDisputaJustificativaObrigatoria(),
            'estado_invalido' => AbrirDisputaEstadoInvalido(),
            _ => AbrirDisputaErro(),
          };
        } catch (_) {
          return AbrirDisputaErro();
        }
      default:
        return AbrirDisputaErro();
    }
  }
}
