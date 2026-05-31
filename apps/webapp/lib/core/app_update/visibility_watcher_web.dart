import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

import 'visibility_watcher.dart';

/// Implementação web: escuta `visibilitychange` no `document` e expõe o estado
/// atual via `document.visibilityState` (STORY-037 CA-2).
class _WebVisibilityWatcher implements VisibilityWatcher {
  _WebVisibilityWatcher() {
    web.document.addEventListener('visibilitychange', _jsListener);
  }

  final _listeners = <VoidCallback>[];
  late final JSFunction _jsListener = ((web.Event _) => _notify()).toJS;

  @override
  bool get isVisible => web.document.visibilityState == 'visible';

  void _notify() {
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
    web.document.removeEventListener('visibilitychange', _jsListener);
    _listeners.clear();
  }
}

VisibilityWatcher createVisibilityWatcher() => _WebVisibilityWatcher();
