import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turni_webapp/core/install/install_bridge.dart';
import 'package:turni_webapp/core/install/install_controller.dart';

/// Bridge falso controlável — substitui a leitura de `window.turniInstall`.
class _FakeBridge implements InstallBridge {
  _FakeBridge({
    this.isInstallable = false,
    this.isStandalone = false,
    this.isIOS = false,
    this.promptResult = 'unavailable',
  });

  @override
  bool isInstallable;
  @override
  bool isStandalone;
  @override
  bool isIOS;

  String promptResult;
  int promptCalls = 0;

  final _listeners = <VoidCallback>[];

  @override
  Future<String> promptNative() async {
    promptCalls++;
    return promptResult;
  }

  /// Simula o `CustomEvent('turni:installable')` chegando do JS.
  void fireInstallable({bool installable = true}) {
    isInstallable = installable;
    for (final l in List<VoidCallback>.of(_listeners)) {
      l();
    }
  }

  @override
  void addListener(VoidCallback listener) => _listeners.add(listener);
  @override
  void removeListener(VoidCallback listener) => _listeners.remove(listener);
  @override
  void dispose() => _listeners.clear();
}

InstallController _controller(_FakeBridge bridge) {
  final c = InstallController(bridge: bridge);
  c.start();
  return c;
}

void main() {
  group('InstallController.showAction (CA-5)', () {
    test('(a) Android instalável e não standalone → true', () {
      final c = _controller(_FakeBridge(isInstallable: true));
      expect(c.showAction, isTrue);
      c.dispose();
    });

    test('(b) Android standalone → false', () {
      final c = _controller(
        _FakeBridge(isInstallable: true, isStandalone: true),
      );
      expect(c.showAction, isFalse);
      c.dispose();
    });

    test('(c) iOS Safari não standalone → true', () {
      final c = _controller(_FakeBridge(isIOS: true));
      expect(c.showAction, isTrue);
      c.dispose();
    });

    test('(d) iOS standalone → false', () {
      final c = _controller(_FakeBridge(isIOS: true, isStandalone: true));
      expect(c.showAction, isFalse);
      c.dispose();
    });

    test('(e) sem beforeinstallprompt e não iOS → false', () {
      final c = _controller(_FakeBridge());
      expect(c.showAction, isFalse);
      c.dispose();
    });

    test('(f) dispensado neste ciclo → false', () {
      final c = _controller(_FakeBridge(isInstallable: true));
      c.dismiss();
      expect(c.showAction, isFalse);
      c.dispose();
    });
  });

  group('InstallController — dispensa não persiste (CA-6)', () {
    test('dismiss esconde; resetDismiss (troca de rota) reabre', () {
      final c = _controller(_FakeBridge(isInstallable: true));
      c.dismiss();
      expect(c.showAction, isFalse);
      // Simula remontar o slot ao entrar de novo na rota.
      c.resetDismiss();
      expect(c.showAction, isTrue, reason: 'dispensa não persiste (IDR-017)');
      c.dispose();
    });

    test('resetDismiss não reabre se a instalabilidade sumiu', () {
      final bridge = _FakeBridge(isInstallable: true);
      final c = _controller(bridge);
      c.dismiss();
      bridge.isInstallable = false;
      c.resetDismiss();
      expect(c.showAction, isFalse);
      c.dispose();
    });

    test('novo evento installable do JS reabre a ação', () {
      final bridge = _FakeBridge();
      final c = _controller(bridge);
      c.dismiss();
      bridge.fireInstallable();
      expect(c.showAction, isTrue);
      c.dispose();
    });

    test('dismiss notifica os listeners', () {
      final c = _controller(_FakeBridge(isInstallable: true));
      var notified = 0;
      c.addListener(() => notified++);
      c.dismiss();
      expect(notified, 1);
      // segundo dismiss não re-notifica (idempotente)
      c.dismiss();
      expect(notified, 1);
      c.dispose();
    });
  });

  group('InstallController — iOS abre/fecha modal (CA-7)', () {
    test('requestInstall em iOS liga showIosInstructions', () async {
      final c = _controller(_FakeBridge(isIOS: true));
      expect(c.showIosInstructions, isFalse);
      await c.requestInstall();
      expect(c.showIosInstructions, isTrue);
      c.dispose();
    });

    test('dismissIosInstructions desliga', () async {
      final c = _controller(_FakeBridge(isIOS: true));
      await c.requestInstall();
      c.dismissIosInstructions();
      expect(c.showIosInstructions, isFalse);
      c.dispose();
    });

    test('iOS não chama o prompt nativo', () async {
      final bridge = _FakeBridge(isIOS: true);
      final c = _controller(bridge);
      await c.requestInstall();
      expect(bridge.promptCalls, 0);
      c.dispose();
    });
  });

  group('InstallController — Chromium chama bridge (CA-8)', () {
    test('requestInstall não-iOS instalável chama promptNative 1×', () async {
      final bridge = _FakeBridge(isInstallable: true, promptResult: 'accepted');
      final c = _controller(bridge);
      await c.requestInstall();
      expect(bridge.promptCalls, 1);
      c.dispose();
    });

    test('accepted marca dispensado neste ciclo', () async {
      final bridge = _FakeBridge(isInstallable: true, promptResult: 'accepted');
      final c = _controller(bridge);
      await c.requestInstall();
      expect(c.showAction, isFalse, reason: 'instalado → some no ciclo');
      c.dispose();
    });

    test('dismissed marca dispensado neste ciclo', () async {
      final bridge = _FakeBridge(
        isInstallable: true,
        promptResult: 'dismissed',
      );
      final c = _controller(bridge);
      await c.requestInstall();
      expect(c.showAction, isFalse);
      c.dispose();
    });

    test('unavailable não dispensa (borda)', () async {
      final bridge = _FakeBridge(
        isInstallable: true,
        promptResult: 'unavailable',
      );
      final c = _controller(bridge);
      await c.requestInstall();
      expect(c.showAction, isTrue);
      c.dispose();
    });

    test('não abre modal iOS no caminho Chromium', () async {
      final bridge = _FakeBridge(isInstallable: true, promptResult: 'accepted');
      final c = _controller(bridge);
      await c.requestInstall();
      expect(c.showIosInstructions, isFalse);
      c.dispose();
    });
  });

  group('InstallController — start idempotente e isIOS', () {
    test('start dobrado não duplica listener no bridge', () {
      final bridge = _FakeBridge();
      final c = InstallController(bridge: bridge)
        ..start()
        ..start();
      var notified = 0;
      c.addListener(() => notified++);
      bridge.fireInstallable();
      expect(notified, 1, reason: '_onBridgeChanged roda uma vez só');
      c.dispose();
    });

    test('isIOS delega ao bridge', () {
      final c = _controller(_FakeBridge(isIOS: true));
      expect(c.isIOS, isTrue);
      c.dispose();
    });
  });
}
