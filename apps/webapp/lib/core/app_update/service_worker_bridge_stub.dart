import 'service_worker_bridge.dart';

/// Stub para plataformas sem `dart:js_interop` (a VM dos testes unitários).
/// Não há service worker fora do browser — as operações são no-op.
class _NoopServiceWorkerBridge implements ServiceWorkerBridge {
  @override
  Future<void> activateNewVersionAndReload() async {}
}

ServiceWorkerBridge createServiceWorkerBridge() => _NoopServiceWorkerBridge();
