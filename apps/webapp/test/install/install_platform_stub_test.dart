import 'package:flutter_test/flutter_test.dart';
import 'package:turni_webapp/core/install/install_bridge.dart';

// Em VM (testes) o factory resolve para o stub no-op. Garante que o stub é inerte
// e seguro fora do browser (sem `package:web`) — CA-9.

void main() {
  test('InstallBridge stub é no-op e seguro (CA-9)', () async {
    final bridge = createInstallBridge();
    expect(bridge.isInstallable, isFalse);
    expect(bridge.isStandalone, isFalse);
    expect(bridge.isIOS, isFalse);
    expect(await bridge.promptNative(), 'unavailable');
    void noop() {}
    bridge.addListener(noop);
    bridge.removeListener(noop);
    bridge.dispose();
  });
}
