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
  /// Ativa o SW em waiting (envia `{type: 'SKIP_WAITING'}`), aguarda
  /// `controllerchange` por até 2 s e dá `window.location.reload()`. Se não houver
  /// SW em waiting ou o navegador não suportar, faz reload direto.
  Future<void> activateNewVersionAndReload();
}

/// Constrói a ponte adequada à plataforma (web real ou stub no-op).
ServiceWorkerBridge createServiceWorkerBridge() =>
    impl.createServiceWorkerBridge();
