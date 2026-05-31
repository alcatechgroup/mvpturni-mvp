import 'package:flutter/foundation.dart';

import 'visibility_watcher_stub.dart'
    if (dart.library.js_interop) 'visibility_watcher_web.dart'
    as impl;

/// Observa a visibilidade da aba (`document.visibilityState`) — STORY-037 CA-2.
///
/// A implementação real ([visibility_watcher_web.dart]) escuta `visibilitychange`
/// via `package:web`. Em VM (testes) o factory resolve para o stub (sempre visível,
/// sem eventos), e os testes injetam um fake controlável.
abstract interface class VisibilityWatcher {
  /// `true` quando a aba está visível (`visibilityState === 'visible'`).
  bool get isVisible;

  /// Registra um callback chamado a cada mudança de visibilidade.
  void addListener(VoidCallback listener);

  /// Remove um callback previamente registrado.
  void removeListener(VoidCallback listener);

  /// Libera o listener de plataforma.
  void dispose();
}

/// Constrói o watcher adequado à plataforma (web real ou stub).
VisibilityWatcher createVisibilityWatcher() => impl.createVisibilityWatcher();
