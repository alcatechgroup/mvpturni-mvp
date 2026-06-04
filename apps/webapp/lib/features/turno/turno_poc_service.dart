import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/time/turni_datetime.dart';
import '../cadastro/shared/cadastro_types.dart' show cadastroApiBase;

/// STORY-057 / ADR-017 — serviço da PoC do cronômetro + geofencing. Sessão Sanctum same-origin: o
/// cookie trafega sozinho (não refazemos `/sanctum/csrf-cookie` no meio da sessão — IDR-019).

/// Resposta de `GET /api/turnos/{id}/cronometro` — a âncora (CA-4). Os instantes vêm em ISO-8601
/// UTC; a fronteira UTC↔local é do `TurniDateTime` (IDR-026). `iniciadoEm`/`encerradoEm` podem ser
/// nulos (antes do check-in / enquanto ativo).
class CronometroSnapshot {
  const CronometroSnapshot({
    required this.estado,
    required this.iniciadoEm,
    required this.encerradoEm,
    required this.servidorAgora,
  });

  final String estado;
  final DateTime? iniciadoEm;
  final DateTime? encerradoEm;
  final DateTime servidorAgora;

  factory CronometroSnapshot.fromJson(Map<String, dynamic> json) {
    return CronometroSnapshot(
      estado: json['estado'] as String? ?? '',
      iniciadoEm: TurniDateTime.parse(json['iniciado_em'] as String?),
      encerradoEm: TurniDateTime.parse(json['encerrado_em'] as String?),
      servidorAgora:
          TurniDateTime.parse(json['servidor_agora'] as String?) ??
          DateTime.now().toUtc(),
    );
  }
}

/// Resposta de `POST /api/turnos/{id}/checkin-geo` — o snapshot de geofencing (PDR-008).
class GeoResultado {
  const GeoResultado({
    required this.ok,
    required this.distanciaMetros,
    required this.razao,
  });

  final bool ok;
  final double? distanciaMetros;
  final String? razao;

  factory GeoResultado.fromJson(Map<String, dynamic> json) {
    return GeoResultado(
      ok: json['ok'] as bool? ?? false,
      distanciaMetros: (json['distancia_metros'] as num?)?.toDouble(),
      razao: json['razao'] as String?,
    );
  }
}

class TurnoPocService {
  TurnoPocService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  String get _base => '$cadastroApiBase/api';

  /// GET /api/turnos/meu-ativo — id do turno em andamento do usuário (qualquer lado), p/ navegar
  /// até o cronômetro sem digitar URL. `null` quando não há turno ativo ou em erro.
  Future<String?> meuTurnoAtivo() async {
    http.Response res;
    try {
      res = await _client.get(
        Uri.parse('$_base/turnos/meu-ativo'),
        headers: {'Accept': 'application/json'},
      );
    } catch (_) {
      return null;
    }
    if (res.statusCode != 200) return null;

    return _json(res.body)['turno_id'] as String?;
  }

  /// GET /api/turnos/{id}/cronometro — a âncora do cronômetro. `null` em erro de rede/RBAC.
  Future<CronometroSnapshot?> cronometro(String turnoId) async {
    http.Response res;
    try {
      res = await _client.get(
        Uri.parse('$_base/turnos/$turnoId/cronometro'),
        headers: {'Accept': 'application/json'},
      );
    } catch (_) {
      return null;
    }
    if (res.statusCode != 200) return null;

    return CronometroSnapshot.fromJson(_json(res.body));
  }

  /// POST /api/turnos/{id}/checkin-geo — envia a posição do navegador e recebe a distância em
  /// metros calculada via Haversine. `null` em erro de rede/RBAC.
  Future<GeoResultado?> checkinGeo(
    String turnoId, {
    double? lat,
    double? lng,
    String? razao,
  }) async {
    http.Response res;
    try {
      res = await _client.post(
        Uri.parse('$_base/turnos/$turnoId/checkin-geo'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'lat': lat, 'lng': lng, 'razao': razao}),
      );
    } catch (_) {
      return null;
    }
    if (res.statusCode != 200) return null;

    return GeoResultado.fromJson(_json(res.body));
  }

  Map<String, dynamic> _json(String body) {
    try {
      final decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> ? decoded : {};
    } catch (_) {
      return {};
    }
  }
}
