import 'dart:convert';

import 'package:http/http.dart' as http;

import '../cadastro/shared/cadastro_types.dart' show cadastroApiBase;

/// STORY-066 (CA-1/CA-2) — cancelamento do turno antes do check-in (PDR-007).
///
/// POST /api/turnos/{id}/cancelar com motivo OPCIONAL (≤280). O servidor decide o
/// lado pelo RBAC (`cancelado_pro` | `cancelado_emp`); 422 `estado_invalido` quando
/// o turno mudou debaixo do usuário (o dialog mostra o erro e a tela recarrega a
/// verdade ao fechar — SCREEN-066 §A.6). Sessão Sanctum same-origin (IDR-019).

sealed class CancelarTurnoResult {}

class CancelamentoOk extends CancelarTurnoResult {
  CancelamentoOk(this.estado);

  /// `cancelado_pro` | `cancelado_emp` — devolvido pelo servidor.
  final String estado;
}

/// 422 `estado_invalido` — corrida: o outro lado cancelou antes, ou o check-in
/// aconteceu. "Este turno não pode mais ser cancelado." + recarregar ao fechar.
class CancelamentoEstadoInvalido extends CancelarTurnoResult {}

class CancelamentoErro extends CancelarTurnoResult {}

class CancelarTurnoService {
  CancelarTurnoService({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  Future<CancelarTurnoResult> cancelar(String turnoId, {String? motivo}) async {
    http.Response res;
    try {
      res = await _client.post(
        Uri.parse('$cadastroApiBase/api/turnos/$turnoId/cancelar'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'motivo': ?motivo}),
      );
    } catch (_) {
      return CancelamentoErro();
    }

    switch (res.statusCode) {
      case 200:
        try {
          final json = jsonDecode(res.body) as Map<String, dynamic>;
          return CancelamentoOk(json['estado'] as String? ?? '');
        } catch (_) {
          return CancelamentoErro();
        }
      case 422:
        try {
          final json = jsonDecode(res.body) as Map<String, dynamic>;
          return json['motivo'] == 'estado_invalido'
              ? CancelamentoEstadoInvalido()
              : CancelamentoErro();
        } catch (_) {
          return CancelamentoErro();
        }
      default:
        return CancelamentoErro();
    }
  }
}
