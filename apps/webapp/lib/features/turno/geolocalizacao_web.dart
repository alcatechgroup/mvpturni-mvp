import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'geolocalizacao.dart';

/// Implementação web da captura de posição (STORY-057 / ADR-017 decisão b). Usa
/// `navigator.geolocation.getCurrentPosition` via `package:web` + `dart:js_interop`.
///
/// Os códigos de erro do W3C: 1 = PERMISSION_DENIED, 2 = POSITION_UNAVAILABLE, 3 = TIMEOUT
/// → razões que o backend registra (PDR-008). Resolve uma única vez (Completer) e nunca lança.
Future<PosicaoGeo> capturarPosicao() {
  final completer = Completer<PosicaoGeo>();

  void sucesso(web.GeolocationPosition pos) {
    if (completer.isCompleted) return;
    completer.complete(
      PosicaoGeo(
        lat: pos.coords.latitude.toDouble(),
        lng: pos.coords.longitude.toDouble(),
      ),
    );
  }

  void erro(web.GeolocationPositionError e) {
    if (completer.isCompleted) return;
    final razao = switch (e.code) {
      1 => 'permissao_negada',
      3 => 'timeout',
      _ => 'indisponivel',
    };
    completer.complete(PosicaoGeo(razao: razao));
  }

  try {
    web.window.navigator.geolocation.getCurrentPosition(
      sucesso.toJS,
      erro.toJS,
      web.PositionOptions(enableHighAccuracy: true, timeout: 10000),
    );
  } catch (_) {
    if (!completer.isCompleted) {
      completer.complete(const PosicaoGeo(razao: 'indisponivel'));
    }
  }

  return completer.future;
}
