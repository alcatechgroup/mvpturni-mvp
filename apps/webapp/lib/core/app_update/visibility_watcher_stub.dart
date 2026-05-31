import 'package:flutter/foundation.dart';

import 'visibility_watcher.dart';

/// Stub para plataformas sem `dart:js_interop` (a VM dos testes unitários).
/// Fora do browser não há `document.visibilityState` — considera-se sempre visível
/// e nenhum evento de mudança é emitido.
class _StubVisibilityWatcher implements VisibilityWatcher {
  @override
  bool get isVisible => true;

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}

  @override
  void dispose() {}
}

VisibilityWatcher createVisibilityWatcher() => _StubVisibilityWatcher();
