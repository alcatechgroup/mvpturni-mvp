import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

import 'service_worker_bridge.dart';

/// Implementação web da ponte com o service worker (STORY-037 CA-5).
///
/// O service worker padrão do Flutter (STORY-008 CA-12) ativa-se ao receber a
/// mensagem `'skipWaiting'`; enviamos também `{type:'SKIP_WAITING'}` por robustez
/// (mensagem ignorada se o SW não a reconhecer). Depois aguardamos `controllerchange`
/// por até 2 s e recarregamos para puxar o novo bundle. Qualquer ausência de SW ou
/// erro de plataforma cai no reload direto — não-bloqueante.
class _WebServiceWorkerBridge implements ServiceWorkerBridge {
  @override
  Future<void> activateNewVersionAndReload() async {
    final container = web.window.navigator.serviceWorker;

    web.ServiceWorkerRegistration? registration;
    try {
      registration = await container.getRegistration().toDart;
    } catch (_) {
      // Navegador sem suporte a SW, ou falha ao consultar — reload direto resolve.
      _reload();
      return;
    }

    final waiting = registration?.waiting;
    if (waiting == null) {
      // Sem SW em waiting: o index.html no-cache já busca o bundle novo no reload.
      _reload();
      return;
    }

    debugPrint('appUpdate.skipWaiting');
    waiting.postMessage('skipWaiting'.toJS);
    waiting.postMessage({'type': 'SKIP_WAITING'}.jsify());

    // Aguarda o novo SW assumir o controle; em qualquer caso (até 2 s) recarrega.
    final controllerChanged = Completer<void>();
    void onChange(web.Event _) {
      if (!controllerChanged.isCompleted) controllerChanged.complete();
    }

    final listener = onChange.toJS;
    container.addEventListener('controllerchange', listener);
    try {
      await controllerChanged.future.timeout(
        const Duration(seconds: 2),
        onTimeout: () {},
      );
    } finally {
      container.removeEventListener('controllerchange', listener);
    }
    _reload();
  }

  void _reload() => web.window.location.reload();
}

ServiceWorkerBridge createServiceWorkerBridge() => _WebServiceWorkerBridge();
