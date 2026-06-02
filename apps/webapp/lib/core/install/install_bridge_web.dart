import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

import 'install_bridge.dart';

/// View tipada do objeto global `window.turniInstall` montado pelo script
/// pré-Flutter no `index.html` (IDR-020 §6). Os campos são propriedades vivas:
/// quando o JS atualiza `isInstallable` ao receber `beforeinstallprompt`, a leitura
/// do getter reflete o valor novo.
@JS('turniInstall')
external _TurniInstall? get _turniInstall;

extension type _TurniInstall._(JSObject _) implements JSObject {
  external bool get isInstallable;
  external bool get isStandalone;
  external bool get isIOS;

  /// Resolve com `'accepted' | 'dismissed' | 'unavailable'`.
  external JSPromise<JSString> promptNative();
}

/// Implementação web da ponte de instalação (STORY-042 / IDR-020).
///
/// Lê o estado de `window.turniInstall` e escuta os `CustomEvent`s
/// `turni:installable` (beforeinstallprompt capturado / instalado) e
/// `turni:appinstalled` para notificar o controller. **Não toca** o service worker,
/// o Cache Storage nem intercepta `fetch` — IDR-017.
class _WebInstallBridge implements InstallBridge {
  _WebInstallBridge() {
    web.window.addEventListener('turni:installable', _jsListener);
    web.window.addEventListener('turni:appinstalled', _jsListener);
  }

  final _listeners = <VoidCallback>[];
  late final JSFunction _jsListener = ((web.Event _) => _notify()).toJS;

  @override
  bool get isInstallable => _turniInstall?.isInstallable ?? false;

  @override
  bool get isStandalone => _turniInstall?.isStandalone ?? false;

  @override
  bool get isIOS => _turniInstall?.isIOS ?? false;

  @override
  Future<String> promptNative() async {
    final api = _turniInstall;
    if (api == null) return 'unavailable';
    try {
      final result = await api.promptNative().toDart;
      final choice = result.toDart;
      debugPrint('install.choice=$choice');
      return choice;
    } catch (_) {
      return 'unavailable';
    }
  }

  void _notify() {
    debugPrint('install.detected isInstallable=$isInstallable');
    for (final listener in List<VoidCallback>.of(_listeners)) {
      listener();
    }
  }

  @override
  void addListener(VoidCallback listener) => _listeners.add(listener);

  @override
  void removeListener(VoidCallback listener) => _listeners.remove(listener);

  @override
  void dispose() {
    web.window.removeEventListener('turni:installable', _jsListener);
    web.window.removeEventListener('turni:appinstalled', _jsListener);
    _listeners.clear();
  }
}

InstallBridge createInstallBridge() => _WebInstallBridge();
