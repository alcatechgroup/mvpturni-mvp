import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

import 'service_worker_bridge.dart';

/// Implementação web da ativação da nova versão (STORY-037 CA-5 / IDR-017).
///
/// **Por que não usamos `skipWaiting` + `controllerchange`:** o sinal de "tem versão
/// nova" vem do polling do `version.json`, que é independente do ciclo de vida do
/// service worker — no clique quase nunca há um SW em `waiting`, e no iOS (WKWebView,
/// motor de Safari/Chrome) os eventos de SW (`controllerchange`) são notoriamente
/// instáveis. Resultado observado em homolog: o reload reabria a MESMA versão.
///
/// Estratégia determinística: **desregistra todos os service workers + limpa todo o
/// Cache Storage e então recarrega.** Sem SW controlando a navegação, o reload busca
/// `index.html` (no-cache) → `flutter_bootstrap.js`/`main.dart.js` (agora no-cache no
/// `firebase.json`) da rede, pegando a versão nova. A página recarregada registra um
/// SW novo para o próximo ciclo. Não depende de evento de SW algum — funciona em
/// desktop e em iOS.
class _WebServiceWorkerBridge implements ServiceWorkerBridge {
  @override
  Future<void> activateNewVersionAndReload() async {
    debugPrint('appUpdate.forceReload — desregistrando SW + limpando caches');
    await _unregisterServiceWorkers();
    await _clearCaches();
    web.window.location.reload();
  }

  Future<void> _unregisterServiceWorkers() async {
    try {
      final registrations = await web.window.navigator.serviceWorker
          .getRegistrations()
          .toDart;
      for (final registration in registrations.toDart) {
        await registration.unregister().toDart;
      }
    } catch (_) {
      // Navegador sem SW ou falha ao desregistrar — o reload abaixo resolve.
    }
  }

  Future<void> _clearCaches() async {
    try {
      final caches = web.window.caches;
      final keys = await caches.keys().toDart;
      for (final key in keys.toDart) {
        await caches.delete(key.toDart).toDart;
      }
    } catch (_) {
      // CacheStorage indisponível — ignorado.
    }
  }
}

ServiceWorkerBridge createServiceWorkerBridge() => _WebServiceWorkerBridge();
