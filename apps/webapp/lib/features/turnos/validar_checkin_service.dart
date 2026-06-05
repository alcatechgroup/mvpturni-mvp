import 'dart:convert';

import 'package:http/http.dart' as http;

import '../cadastro/shared/cadastro_types.dart' show cadastroApiBase;

/// STORY-062 — validação do PIN de check-in pelo contratante e recusa.
///
/// `validar` envia o PIN digitado (CA-1) e traduz: 200 → ativo; 422 `pin_invalido`
/// (erro inline — CA-2) / `pin_expirado` (3 erros — CA-3) / `estado_invalido` (mudou
/// em outra aba); 429 rate limit. `recusar` (CA-6) leva motivo OPCIONAL.
/// Sessão Sanctum same-origin (IDR-019).

sealed class ValidarPinResult {}

class PinValidado extends ValidarPinResult {}

/// 422 `pin_invalido` — microcopy fixa da estória, erro inline no campo (§4.4).
class PinInvalido extends ValidarPinResult {}

/// 422 `pin_expirado` — 3 erros; o turno já voltou a `confirmado` no servidor (§4.5).
class PinExpirado extends ValidarPinResult {}

/// 422 `estado_invalido` — validado/cancelado em outra aba; recarregar silencioso (§4.10).
class ValidarEstadoInvalido extends ValidarPinResult {}

/// 429 — rate limit por turno (CA-2); banner sem retry (§4.6).
class ValidarRateLimit extends ValidarPinResult {}

class ValidarErro extends ValidarPinResult {}

sealed class RecusaResult {}

class RecusaOk extends RecusaResult {}

class RecusaEstadoInvalido extends RecusaResult {}

class RecusaErro extends RecusaResult {}

class ValidarCheckinService {
  ValidarCheckinService({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  /// POST /api/turnos/{id}/validar-checkin com `{ pin }` (CA-1).
  Future<ValidarPinResult> validar(String turnoId, String pin) async {
    http.Response res;
    try {
      res = await _client.post(
        Uri.parse('$cadastroApiBase/api/turnos/$turnoId/validar-checkin'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'pin': pin}),
      );
    } catch (_) {
      return ValidarErro();
    }

    switch (res.statusCode) {
      case 200:
        return PinValidado();
      case 429:
        return ValidarRateLimit();
      case 422:
        try {
          final json = jsonDecode(res.body) as Map<String, dynamic>;
          return switch (json['motivo']) {
            'pin_invalido' => PinInvalido(),
            'pin_expirado' => PinExpirado(),
            'estado_invalido' => ValidarEstadoInvalido(),
            _ => ValidarErro(),
          };
        } catch (_) {
          return ValidarErro();
        }
      default:
        return ValidarErro();
    }
  }

  /// POST /api/turnos/{id}/recusar-checkin com motivo opcional (CA-6).
  Future<RecusaResult> recusar(String turnoId, {String? motivo}) async {
    http.Response res;
    try {
      res = await _client.post(
        Uri.parse('$cadastroApiBase/api/turnos/$turnoId/recusar-checkin'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'motivo': ?motivo}),
      );
    } catch (_) {
      return RecusaErro();
    }

    return switch (res.statusCode) {
      200 => RecusaOk(),
      422 => RecusaEstadoInvalido(),
      _ => RecusaErro(),
    };
  }
}
