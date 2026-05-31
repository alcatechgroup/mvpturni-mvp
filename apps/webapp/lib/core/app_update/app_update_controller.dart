import 'dart:async';

import 'package:flutter/foundation.dart';

import 'app_version.dart';
import 'app_version_service.dart';
import 'service_worker_bridge.dart';
import 'visibility_watcher.dart';

/// Orquestra a auto-atualização do WebApp (STORY-037 / IDR-017).
///
/// Faz polling do `version.json` e mantém o estado `updateAvailable`. Os triggers
/// de checagem (CA-2) são: (i) bootstrap, (ii) retorno ao foreground, (iii) sucesso
/// de login, (iv) timer de [pollInterval] enquanto a aba está visível.
///
/// Em `dev` (build local sem `--dart-define=APP_VERSION`) a checagem é desabilitada
/// para não gerar ruído (IDR-017). Toda falha de rede é silenciosa — não-bloqueante.
class AppUpdateController extends ChangeNotifier {
  AppUpdateController({
    AppVersionService? service,
    ServiceWorkerBridge? bridge,
    VisibilityWatcher? visibility,
    this.pollInterval = const Duration(minutes: 5),
  }) : _service = service ?? AppVersionService(),
       _bridge = bridge ?? createServiceWorkerBridge(),
       _visibility = visibility ?? createVisibilityWatcher();

  final AppVersionService _service;
  final ServiceWorkerBridge _bridge;
  final VisibilityWatcher _visibility;
  final Duration pollInterval;

  Timer? _timer;
  bool _started = false;
  bool _updateAvailable = false;
  bool _dismissed = false;
  AppVersion? _serverVersion;

  /// Versão rodando agora no dispositivo.
  AppVersion get currentVersion => _service.currentVersion;

  /// Última versão vista no servidor (`null` antes da primeira checagem bem-sucedida).
  AppVersion? get serverVersion => _serverVersion;

  /// Há uma versão nova publicada (independe de o banner estar dispensado).
  bool get updateAvailable => _updateAvailable;

  /// O banner deve aparecer: há update E o usuário não clicou "Depois" neste ciclo.
  bool get showBanner => _updateAvailable && !_dismissed;

  /// Liga os triggers: bootstrap imediato + listener de visibilidade + timer
  /// periódico (só corre enquanto visível). No-op em `dev` ou se já iniciado.
  void start() {
    if (_started) return;
    _started = true;
    if (currentVersion.isDev) return;
    _visibility.addListener(_onVisibilityChanged);
    if (_visibility.isVisible) _startTimer();
    unawaited(checkForUpdate()); // (i) bootstrap
  }

  /// Hook chamado pelo sucesso de login (iii).
  void onLoginSuccess() => unawaited(checkForUpdate());

  void _onVisibilityChanged() {
    if (_visibility.isVisible) {
      unawaited(checkForUpdate()); // (ii) foreground
      _startTimer();
    } else {
      _stopTimer();
    }
  }

  void _startTimer() {
    _timer ??= Timer.periodic(pollInterval, (_) => checkForUpdate()); // (iv)
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  /// Busca a versão do servidor e atualiza o estado. Não-bloqueante: qualquer
  /// falha é ignorada (CA-1). `updateAvailable=true` sse e somente se a versão do
  /// servidor difere da rodando E a rodando não é `dev` (CA-3).
  Future<void> checkForUpdate() async {
    if (currentVersion.isDev) return;

    final AppVersion server;
    try {
      server = await _service.fetchServerVersion();
    } catch (_) {
      return; // não muda estado
    }

    _serverVersion = server;

    if (server.isDifferentFrom(currentVersion)) {
      // Reabre o banner mesmo que o usuário tenha dispensado num ciclo anterior:
      // "Depois" não persiste (IDR-017).
      if (!_updateAvailable || _dismissed) {
        if (!_updateAvailable) {
          debugPrint(
            'appUpdate.detected serverVersion=$server currentVersion=$currentVersion',
          );
        }
        _updateAvailable = true;
        _dismissed = false;
        notifyListeners();
      }
    } else if (_updateAvailable) {
      _updateAvailable = false;
      _dismissed = false;
      notifyListeners();
    }
  }

  /// "Depois" — esconde o banner neste ciclo (não persiste; reabre na próxima
  /// checagem que ainda veja versão nova — CA-7).
  void dismiss() {
    if (!_dismissed) {
      _dismissed = true;
      notifyListeners();
    }
  }

  /// "Atualizar agora" — registra o aceite e dispara `skipWaiting` + reload (CA-5).
  Future<void> applyUpdate() async {
    debugPrint('appUpdate.userAccepted');
    await _bridge.activateNewVersionAndReload();
  }

  @override
  void dispose() {
    _stopTimer();
    _visibility.removeListener(_onVisibilityChanged);
    _visibility.dispose();
    super.dispose();
  }
}
