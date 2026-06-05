import 'package:flutter/foundation.dart' show visibleForTesting;

import 'geolocalizacao_stub.dart'
    if (dart.library.js_interop) 'geolocalizacao_web.dart'
    as impl;

/// STORY-057 / ADR-017 (decisão b). Ponte fina para a Geolocation API do navegador
/// (`navigator.geolocation`), no padrão de import condicional do repo (stub no-op em VM de teste;
/// `package:web` + `dart:js_interop` no browser — espelha `core/install/install_bridge`).
///
/// PDR-008 é alerta-e-registra: a captura NUNCA lança. Falha (permissão negada, GPS off, timeout)
/// volta como [PosicaoGeo] sem coordenadas + uma `razao` — que o backend (`Support\Geo\Geofencing`)
/// registra como `geofencing_ok:false`/`distancia_metros:null`.

/// Posição capturada (ou a razão da falha). `razao ∈ {permissao_negada, timeout, indisponivel}`.
class PosicaoGeo {
  const PosicaoGeo({this.lat, this.lng, this.accuracyM, this.razao});

  final double? lat;
  final double? lng;

  /// Precisão reportada pelo navegador em metros (STORY-061 CA-2) — registrada na trilha.
  final double? accuracyM;

  final String? razao;

  bool get ok => lat != null && lng != null;
}

/// Override de teste (E2E/integration_test): o browser real do harness não tem como
/// conceder permissão de geolocalização programaticamente (prompt nativo), então os
/// cenários determinísticos injetam a posição aqui — mesmo padrão do
/// `AuthService.debugSetSession`. Produção nunca seta isso.
@visibleForTesting
Future<PosicaoGeo> Function()? debugCapturarPosicaoOverride;

/// Pede a posição atual ao navegador. Em VM/sem suporte resolve com `razao: 'indisponivel'`.
Future<PosicaoGeo> capturarPosicao() =>
    (debugCapturarPosicaoOverride ?? impl.capturarPosicao)();
