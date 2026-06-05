import 'dart:convert';

import 'package:http/http.dart' as http;

import '../cadastro/shared/cadastro_types.dart' show cadastroApiBase;
import 'validar_checkin_service.dart'
    show
        PinExpirado,
        PinInvalido,
        PinValidado,
        RecusaErro,
        RecusaEstadoInvalido,
        RecusaOk,
        RecusaResult,
        ValidarErro,
        ValidarEstadoInvalido,
        ValidarPinResult,
        ValidarRateLimit;

/// STORY-064 — validação do PIN de check-out pelo contratante e recusa (espelho da
/// ValidarCheckinService/062; reusa os resultados sealed — mesmos contratos).
///
/// `validar` (CA-3): 200 → `finalizado` (cronômetro para na duração final); 422
/// `pin_invalido` (erro inline) / `pin_expirado` (3 erros — o turno JÁ voltou a
/// `ativo` no servidor e o cronômetro retoma, CA-4) / `estado_invalido`; 429 rate
/// limit. `recusar` (CA-5) leva motivo OPCIONAL e devolve o turno a `ativo` —
/// NUNCA `em_disputa` (EPIC-005). Sessão Sanctum same-origin (IDR-019).
class ValidarCheckoutService {
  ValidarCheckoutService({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  /// POST /api/turnos/{id}/validar-checkout com `{ pin }` (CA-3).
  Future<ValidarPinResult> validar(String turnoId, String pin) async {
    http.Response res;
    try {
      res = await _client.post(
        Uri.parse('$cadastroApiBase/api/turnos/$turnoId/validar-checkout'),
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

  /// POST /api/turnos/{id}/recusar-checkout com motivo opcional (CA-5).
  Future<RecusaResult> recusar(String turnoId, {String? motivo}) async {
    http.Response res;
    try {
      res = await _client.post(
        Uri.parse('$cadastroApiBase/api/turnos/$turnoId/recusar-checkout'),
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
