import 'service_worker_bridge_stub.dart'
    if (dart.library.js_interop) 'service_worker_bridge_web.dart'
    as impl;

/// Ponte fina para o service worker do Flutter Web (STORY-037 CA-5).
///
/// A implementação real ([service_worker_bridge_web.dart]) usa `package:web` +
/// `dart:js_interop` e só compila/roda no browser. Em VM (testes unitários) o
/// `dart.library.js_interop` resolve para o stub no-op, então o módulo é testável
/// sem `package:web`.
abstract interface class ServiceWorkerBridge {
  /// Ativa a nova versão e recarrega. A implementação web desregistra os service
  /// workers + limpa o Cache Storage e dá `window.location.reload()` — abordagem
  /// determinística que não depende de eventos de SW (instáveis no iOS/WKWebView).
  /// Ver [service_worker_bridge_web.dart] para o porquê.
  Future<void> activateNewVersionAndReload();
}

/// Constrói a ponte adequada à plataforma (web real ou stub no-op).
ServiceWorkerBridge createServiceWorkerBridge() =>
    impl.createServiceWorkerBridge();
