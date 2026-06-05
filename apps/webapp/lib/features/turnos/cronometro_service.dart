import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/time/turni_datetime.dart';
import '../cadastro/shared/cadastro_types.dart' show cadastroApiBase;

/// STORY-063 / ADR-017 — serviço do cronômetro bilateral de produção (a PoC da 057 vive em
/// `features/turno/turno_poc_service.dart`). Sessão Sanctum same-origin: o cookie trafega
/// sozinho (não refazemos `/sanctum/csrf-cookie` no meio da sessão — IDR-019).

/// Resposta de `GET /api/turnos/{id}/cronometro` — a âncora (CA-4). Instantes em ISO-8601 UTC;
/// a fronteira UTC↔local é do `TurniDateTime` (IDR-026). `iniciadoEm`/`encerradoEm` podem ser
/// nulos (antes do check-in / enquanto `ativo` / degrade pré-064 em `aguardando_checkout`).
class CronometroSnap {
  const CronometroSnap({
    required this.estado,
    required this.iniciadoEm,
    required this.encerradoEm,
    required this.servidorAgora,
    required this.pollingSegundos,
  });

  final String estado;
  final DateTime? iniciadoEm;
  final DateTime? encerradoEm;
  final DateTime servidorAgora;

  /// Janela de reconciliação mandada pelo SERVIDOR (CA-1 "configurável" — ajuste de carga
  /// sem deploy do front). Piso de 1s garantido no backend; o default é ~5s.
  final int pollingSegundos;

  factory CronometroSnap.fromJson(Map<String, dynamic> json) => CronometroSnap(
    estado: json['estado'] as String? ?? '',
    iniciadoEm: TurniDateTime.parse(json['iniciado_em'] as String?),
    encerradoEm: TurniDateTime.parse(json['encerrado_em'] as String?),
    servidorAgora:
        TurniDateTime.parse(json['servidor_agora'] as String?) ??
        DateTime.now().toUtc(),
    pollingSegundos: (json['polling_segundos'] as num?)?.toInt() ?? 5,
  );
}

/// Serviço do cronômetro (STORY-063). `null` em qualquer falha (rede, sessão, RBAC) — o
/// componente trata falha como "não reconciliado" (CA-6): o tick local segue valendo.
class CronometroService {
  CronometroService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// GET /api/turnos/{id}/cronometro — a âncora + a hora do servidor.
  Future<CronometroSnap?> fetch(String turnoId) async {
    http.Response res;
    try {
      res = await _client.get(
        Uri.parse('$cadastroApiBase/api/turnos/$turnoId/cronometro'),
        headers: {'Accept': 'application/json'},
      );
    } catch (_) {
      return null;
    }
    if (res.statusCode != 200) return null;

    try {
      return CronometroSnap.fromJson(
        jsonDecode(res.body) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }
}
