import 'package:flutter_test/flutter_test.dart';
import 'package:turni_webapp/core/app_update/service_worker_bridge.dart';
import 'package:turni_webapp/core/app_update/visibility_watcher.dart';

// Em VM (testes) os factories resolvem para os stubs no-op. Estes testes apenas
// exercitam os stubs para garantir que são inertes e seguros (sem browser).

void main() {
  test('ServiceWorkerBridge stub é no-op e não lança', () async {
    final bridge = createServiceWorkerBridge();
    await bridge.activateNewVersionAndReload();
  });

  test('VisibilityWatcher stub é sempre visível e inerte', () {
    final watcher = createVisibilityWatcher();
    expect(watcher.isVisible, isTrue);
    void noop() {}
    watcher.addListener(noop);
    watcher.removeListener(noop);
    watcher.dispose();
  });
}
