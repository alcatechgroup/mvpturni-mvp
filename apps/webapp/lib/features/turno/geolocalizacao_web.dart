import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'geolocalizacao.dart';

/// Implementação web da captura de posição (STORY-057 / ADR-017 decisão b). Usa
/// `navigator.geolocation.getCurrentPosition` via `package:web` + `dart:js_interop`.
///
/// Robustez (iOS/Safari PWA standalone é historicamente mais frágil que Chrome): além do `timeout`
/// passado ao navegador, há uma GUARDA própria (Timer) — se nenhum callback voltar, resolvemos com
/// `razao: 'timeout'` em vez de travar a UI. `enableHighAccuracy: false` resolve mais rápido e
/// funciona indoor (wifi/cell); `maximumAge` aceita uma posição recente em cache. Códigos W3C:
/// 1 = PERMISSION_DENIED, 2 = POSITION_UNAVAILABLE, 3 = TIMEOUT (PDR-008 — nunca bloqueia).
Future<PosicaoGeo> capturarPosicao() {
  final completer = Completer<PosicaoGeo>();

  // Guarda: garante que SEMPRE resolvemos (alguns navegadores não chamam nenhum callback).
  final guarda = Timer(const Duration(seconds: 15), () {
    if (!completer.isCompleted) {
      completer.complete(const PosicaoGeo(razao: 'timeout'));
    }
  });

  void resolver(PosicaoGeo p) {
    guarda.cancel();
    if (!completer.isCompleted) completer.complete(p);
  }

  void sucesso(web.GeolocationPosition pos) {
    resolver(
      PosicaoGeo(
        lat: pos.coords.latitude.toDouble(),
        lng: pos.coords.longitude.toDouble(),
        accuracyM: pos.coords.accuracy.toDouble(),
      ),
    );
  }

  void erro(web.GeolocationPositionError e) {
    resolver(
      PosicaoGeo(
        razao: switch (e.code) {
          1 => 'permissao_negada',
          3 => 'timeout',
          _ => 'indisponivel',
        },
      ),
    );
  }

  try {
    web.window.navigator.geolocation.getCurrentPosition(
      sucesso.toJS,
      erro.toJS,
      web.PositionOptions(
        enableHighAccuracy: false,
        timeout: 12000,
        maximumAge: 60000,
      ),
    );
  } catch (_) {
    resolver(const PosicaoGeo(razao: 'indisponivel'));
  }

  return completer.future;
}
