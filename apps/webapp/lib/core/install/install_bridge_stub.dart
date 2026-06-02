import 'package:flutter/foundation.dart';

import 'install_bridge.dart';

/// Stub para plataformas sem `dart:js_interop` (a VM dos testes unitários).
/// Não há instalação PWA fora do browser — tudo é inerte.
class _NoopInstallBridge implements InstallBridge {
  @override
  bool get isInstallable => false;
  @override
  bool get isStandalone => false;
  @override
  bool get isIOS => false;
  @override
  Future<String> promptNative() async => 'unavailable';
  @override
  void addListener(VoidCallback listener) {}
  @override
  void removeListener(VoidCallback listener) {}
  @override
  void dispose() {}
}

InstallBridge createInstallBridge() => _NoopInstallBridge();
