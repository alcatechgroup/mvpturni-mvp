import 'dart:convert';

import 'package:http/http.dart' as http;

import '../cadastro/shared/cadastro_types.dart' show cadastroApiBase;
import '../turno/geolocalizacao.dart' as geo;
import 'pin_checkin_service.dart'
    show
        PinCancelEstadoInvalido,
        PinCancelErro,
        PinCancelResult,
        PinCancelado,
        PinGeracaoErro,
        PinGeracaoEstadoInvalido,
        PinGeracaoResult,
        PinGerado;
import 'turno_detalhe_service.dart' show GeofencingCheckin;

/// STORY-064 — geração e cancelamento do PIN de check-out (espelho da PinCheckinService).
///
/// Diferenças intencionais (SCREEN-064 §4.2/§4.6): SEM janela horária (CA-1 — o 422
/// `fora_da_janela` não existe no check-out) e captura de geolocalização SILENCIOSA
/// (mesma API, mas a UI não promete nem destaca — o snapshot vai para a trilha, CA-7).
/// O cancelamento devolve o turno a `ativo` (o cronômetro retoma). Reusa os resultados
/// sealed da 061 — mesmos contratos, endpoints próprios. Sessão Sanctum (IDR-019).
class PinCheckoutService {
  PinCheckoutService({
    http.Client? client,
    Future<geo.PosicaoGeo> Function()? capturar,
  }) : _client = client ?? http.Client(),
       _capturar = capturar ?? geo.capturarPosicao;

  final http.Client _client;
  final Future<geo.PosicaoGeo> Function() _capturar;

  /// Captura a posição (silenciosa — PDR-008, nunca bloqueia) e
  /// POST /api/turnos/{id}/gerar-pin-checkout (CA-2).
  Future<PinGeracaoResult> gerar(String turnoId) async {
    final posicao = await _capturar(); // nunca lança (guarda própria da ponte)

    final body = <String, dynamic>{
      'pin_solicitado': true,
      'lat': posicao.lat,
      'lng': posicao.lng,
      if (posicao.accuracyM != null) 'accuracy_m': posicao.accuracyM,
      if (!posicao.ok && posicao.razao != null) 'razao': posicao.razao,
    };

    http.Response res;
    try {
      res = await _client.post(
        Uri.parse('$cadastroApiBase/api/turnos/$turnoId/gerar-pin-checkout'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );
    } catch (_) {
      return PinGeracaoErro();
    }

    switch (res.statusCode) {
      case 200:
        try {
          final json = jsonDecode(res.body) as Map<String, dynamic>;
          return PinGerado(
            pin: json['pin'] as String,
            geofencing: GeofencingCheckin.fromJson(
              json['geofencing_check_out'] as Map<String, dynamic>,
            ),
          );
        } catch (_) {
          return PinGeracaoErro();
        }
      case 422:
        // Sem janela no check-out: todo 422 de negócio é estado_invalido (mudou
        // em outra aba) — a UI recarrega a verdade.
        return PinGeracaoEstadoInvalido();
      default:
        return PinGeracaoErro();
    }
  }

  /// POST /api/turnos/{id}/cancelar-pin-checkout (§4.6 — volta a `ativo`).
  Future<PinCancelResult> cancelar(String turnoId) async {
    http.Response res;
    try {
      res = await _client.post(
        Uri.parse('$cadastroApiBase/api/turnos/$turnoId/cancelar-pin-checkout'),
        headers: {'Accept': 'application/json'},
      );
    } catch (_) {
      return PinCancelErro();
    }

    return switch (res.statusCode) {
      200 => PinCancelado(),
      422 => PinCancelEstadoInvalido(),
      _ => PinCancelErro(),
    };
  }
}
