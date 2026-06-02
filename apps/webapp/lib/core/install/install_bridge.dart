import 'package:flutter/foundation.dart';

import 'install_bridge_stub.dart'
    if (dart.library.js_interop) 'install_bridge_web.dart'
    as impl;

/// Ponte fina para a API de instalação PWA do navegador (STORY-042 / IDR-020).
///
/// A implementação real ([install_bridge_web.dart]) lê o objeto global
/// `window.turniInstall` (montado pelo script pré-Flutter do `index.html`) via
/// `package:web` + `dart:js_interop`, e escuta os `CustomEvent`s
/// `turni:installable` / `turni:appinstalled`. Em VM (testes unitários) o
/// `dart.library.js_interop` resolve para o stub no-op, então o módulo é testável
/// sem `package:web`.
///
/// **Invariante (IDR-017):** nem a ponte nem o script tocam `navigator.serviceWorker`,
/// `caches` ou `fetch` — para não brigar com o SW padrão do Flutter nem com o ciclo
/// de auto-atualização do `lib/core/app_update/`.
abstract interface class InstallBridge {
  /// `beforeinstallprompt` já disparou e o evento está guardado (Android/Chromium).
  bool get isInstallable;

  /// O app roda em modo standalone (já instalado): `display-mode: standalone`
  /// **ou** `navigator.standalone === true` (iOS).
  bool get isStandalone;

  /// Plataforma é iOS (Safari/Chrome no WebKit) — detecção por user-agent.
  bool get isIOS;

  /// Dispara o prompt nativo guardado e resolve com a escolha do usuário:
  /// `'accepted'`, `'dismissed'` ou `'unavailable'` (sem prompt guardado). O prompt
  /// é single-use: o navegador não dispara `beforeinstallprompt` de novo no ciclo.
  Future<String> promptNative();

  /// Registra um callback chamado quando o estado de instalabilidade muda
  /// (`turni:installable` / `turni:appinstalled`).
  void addListener(VoidCallback listener);

  /// Remove um callback previamente registrado.
  void removeListener(VoidCallback listener);

  /// Libera os listeners de plataforma.
  void dispose();
}

/// Constrói a ponte adequada à plataforma (web real ou stub no-op).
InstallBridge createInstallBridge() => impl.createInstallBridge();
