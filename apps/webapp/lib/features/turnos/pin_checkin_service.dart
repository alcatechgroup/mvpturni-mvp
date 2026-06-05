import 'dart:convert';

import 'package:http/http.dart' as http;

import '../cadastro/shared/cadastro_types.dart' show cadastroApiBase;
import '../turno/geolocalizacao.dart' as geo;
import 'turno_detalhe_service.dart' show GeofencingCheckin;

/// STORY-061 — geração e cancelamento do PIN de check-in.
///
/// `gerar` é "um gesto só" (SCREEN-061 §4.4): captura a posição do navegador
/// (PDR-008 — a captura NUNCA bloqueia; falha vira `geo: null` + razão) e faz o POST
/// com o contrato do CA-2. O PIN volta em plaintext UMA única vez (CA-4) — este service
/// não o persiste nem loga. Sessão Sanctum same-origin (IDR-019).

sealed class PinGeracaoResult {}

class PinGerado extends PinGeracaoResult {
  PinGerado({required this.pin, required this.geofencing});

  final String pin;
  final GeofencingCheckin geofencing;
}

/// 422 `fora_da_janela` — o relógio do device pode discordar do servidor; a UI
/// recarrega o detalhe para reapresentar a janela real (SCREEN-061 §4.2/4.3).
class PinForaDaJanela extends PinGeracaoResult {
  PinForaDaJanela({required this.abreEm, required this.fechaEm});

  final DateTime? abreEm;
  final DateTime? fechaEm;
}

/// 422 `estado_invalido` — o turno mudou por baixo (validado/cancelado em outra aba).
class PinGeracaoEstadoInvalido extends PinGeracaoResult {}

class PinGeracaoErro extends PinGeracaoResult {}

sealed class PinCancelResult {}

class PinCancelado extends PinCancelResult {}

class PinCancelEstadoInvalido extends PinCancelResult {}

class PinCancelErro extends PinCancelResult {}

class PinCheckinService {
  PinCheckinService({
    http.Client? client,
    Future<geo.PosicaoGeo> Function()? capturar,
  }) : _client = client ?? http.Client(),
       _capturar = capturar ?? geo.capturarPosicao;

  final http.Client _client;
  final Future<geo.PosicaoGeo> Function() _capturar;

  /// Captura a posição e POST /api/turnos/{id}/gerar-pin-checkin (CA-2).
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
        Uri.parse('$cadastroApiBase/api/turnos/$turnoId/gerar-pin-checkin'),
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
              json['geofencing_check_in'] as Map<String, dynamic>,
            ),
          );
        } catch (_) {
          return PinGeracaoErro();
        }
      case 422:
        return _geracao422(res.body);
      default:
        return PinGeracaoErro();
    }
  }

  /// POST /api/turnos/{id}/cancelar-pin-checkin (CA-5 — volta a `confirmado`).
  Future<PinCancelResult> cancelar(String turnoId) async {
    http.Response res;
    try {
      res = await _client.post(
        Uri.parse('$cadastroApiBase/api/turnos/$turnoId/cancelar-pin-checkin'),
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

  PinGeracaoResult _geracao422(String body) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      if (json['motivo'] == 'fora_da_janela') {
        final janela = json['janela'] as Map<String, dynamic>?;
        return PinForaDaJanela(
          abreEm: DateTime.tryParse(janela?['abre_em'] as String? ?? ''),
          fechaEm: DateTime.tryParse(janela?['fecha_em'] as String? ?? ''),
        );
      }
      if (json['motivo'] == 'estado_invalido') {
        return PinGeracaoEstadoInvalido();
      }
    } catch (_) {
      // cai no erro genérico abaixo
    }
    return PinGeracaoErro();
  }
}
