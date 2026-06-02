import 'package:flutter/foundation.dart';

import 'install_bridge.dart';

/// Orquestra a ação "Instalar app" do WebApp (STORY-042 / IDR-020).
///
/// Lê a instalabilidade do [InstallBridge] (que reflete `window.turniInstall`) e
/// mantém o estado da ação e do modal de instruções iOS. Não faz polling — reage
/// aos eventos `turni:installable` / `turni:appinstalled` que o bridge repassa.
///
/// **Política de dispensa (IDR-017 / IDR-020 §4):** não persiste. [dismiss] esconde
/// no ciclo atual; [resetDismiss] (chamado pelo `InstallActionSlot` ao remontar numa
/// nova rota) reabre se ainda houver instalabilidade; um novo evento `installable`
/// do JS também reabre.
class InstallController extends ChangeNotifier {
  InstallController({InstallBridge? bridge})
    : _bridge = bridge ?? createInstallBridge();

  final InstallBridge _bridge;

  bool _started = false;
  bool _dismissed = false;
  bool _showIosInstructions = false;

  /// Plataforma é iOS (o CTA vira "Como instalar" e o clique abre o modal).
  bool get isIOS => _bridge.isIOS;

  /// Base de visibilidade: instalável no Chromium **ou** iOS, e não standalone.
  bool get _installable =>
      (_bridge.isInstallable && !_bridge.isStandalone) ||
      (_bridge.isIOS && !_bridge.isStandalone);

  /// O card "Instalar app" deve aparecer: há instalabilidade e não foi dispensado
  /// neste ciclo (CA-5).
  bool get showAction => _installable && !_dismissed;

  /// O modal de instruções iOS deve estar aberto (CA-7).
  bool get showIosInstructions => _showIosInstructions;

  /// Liga a escuta dos eventos de instalabilidade do bridge. Idempotente.
  /// Chamado no `main()` ao lado de `appUpdate.start()`.
  void start() {
    if (_started) return;
    _started = true;
    _bridge.addListener(_onBridgeChanged);
  }

  void _onBridgeChanged() {
    // Novo sinal de instalabilidade do JS reabre a ação dispensada (IDR-020 §4).
    _dismissed = false;
    notifyListeners();
  }

  /// Clique no CTA do card (CA-7 / CA-8). Em iOS, abre o modal de instruções; no
  /// Chromium, dispara o prompt nativo e — em `accepted`/`dismissed` — esconde a
  /// ação no ciclo (o navegador não reoferece `beforeinstallprompt` na sessão).
  Future<void> requestInstall() async {
    debugPrint('install.requested isIOS=${_bridge.isIOS}');
    if (_bridge.isIOS) {
      _showIosInstructions = true;
      debugPrint('install.iosInstructionsOpened');
      notifyListeners();
      return;
    }
    final choice = await _bridge.promptNative();
    debugPrint('install.choice=$choice');
    if (choice == 'accepted' || choice == 'dismissed') {
      _dismissed = true;
      notifyListeners();
    }
  }

  /// "Agora não" — esconde a ação no ciclo atual (não persiste — CA-6).
  void dismiss() {
    if (!_dismissed) {
      _dismissed = true;
      notifyListeners();
    }
  }

  /// Reabre a ação ao entrar de novo numa rota (chamado pelo slot no remount).
  /// Coerente com "dispensa não persiste" (IDR-017) — CA-6.
  void resetDismiss() {
    if (_dismissed) {
      _dismissed = false;
      notifyListeners();
    }
  }

  /// "Entendi" — fecha o modal de instruções iOS (CA-7).
  void dismissIosInstructions() {
    if (_showIosInstructions) {
      _showIosInstructions = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _bridge.removeListener(_onBridgeChanged);
    _bridge.dispose();
    super.dispose();
  }
}
