import 'package:fake_async/fake_async.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turni_webapp/core/app_update/app_update_controller.dart';
import 'package:turni_webapp/core/app_update/app_version.dart';
import 'package:turni_webapp/core/app_update/app_version_service.dart';
import 'package:turni_webapp/core/app_update/service_worker_bridge.dart';
import 'package:turni_webapp/core/app_update/visibility_watcher.dart';

class _FakeVersionService extends AppVersionService {
  _FakeVersionService(this._current);

  final AppVersion _current;
  AppVersion? next;
  Object? error;
  int fetchCount = 0;

  @override
  AppVersion get currentVersion => _current;

  @override
  Future<AppVersion> fetchServerVersion() async {
    fetchCount++;
    if (error != null) throw error!;
    return next ?? _current;
  }
}

class _FakeBridge implements ServiceWorkerBridge {
  int calls = 0;

  @override
  Future<void> activateNewVersionAndReload() async => calls++;
}

class _FakeVisibility implements VisibilityWatcher {
  _FakeVisibility({bool visible = true}) : _visible = visible;

  bool _visible;
  final _listeners = <VoidCallback>[];

  @override
  bool get isVisible => _visible;

  void setVisible(bool value) {
    _visible = value;
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

AppUpdateController _controller({
  required AppVersion current,
  AppVersion? server,
  _FakeVersionService? service,
  _FakeBridge? bridge,
  _FakeVisibility? visibility,
  Duration pollInterval = const Duration(minutes: 5),
}) {
  final svc = service ?? (_FakeVersionService(current)..next = server);
  return AppUpdateController(
    service: svc,
    bridge: bridge ?? _FakeBridge(),
    visibility: visibility ?? _FakeVisibility(),
    pollInterval: pollInterval,
  );
}

void main() {
  group('AppUpdateController — estado updateAvailable (CA-3)', () {
    test('versão diferente + release → updateAvailable true', () async {
      final c = _controller(
        current: const AppVersion('v1'),
        server: const AppVersion('v2'),
      );
      await c.checkForUpdate();
      expect(c.updateAvailable, isTrue);
      expect(c.showBanner, isTrue);
      expect(c.serverVersion, const AppVersion('v2'));
      c.dispose();
    });

    test('versão igual + release → updateAvailable false', () async {
      final c = _controller(
        current: const AppVersion('v1'),
        server: const AppVersion('v1'),
      );
      await c.checkForUpdate();
      expect(c.updateAvailable, isFalse);
      expect(c.showBanner, isFalse);
      c.dispose();
    });

    test(
      'versão diferente + dev → checagem desabilitada, false (IDR-017)',
      () async {
        final svc = _FakeVersionService(const AppVersion('dev'))
          ..next = const AppVersion('v2');
        final c = _controller(current: const AppVersion('dev'), service: svc);
        await c.checkForUpdate();
        expect(c.updateAvailable, isFalse);
        expect(
          svc.fetchCount,
          0,
          reason: 'em dev não chega a buscar o servidor',
        );
        c.dispose();
      },
    );

    test('versão igual + dev → false', () async {
      final c = _controller(
        current: const AppVersion('dev'),
        server: const AppVersion('dev'),
      );
      await c.checkForUpdate();
      expect(c.updateAvailable, isFalse);
      c.dispose();
    });
  });

  group('AppUpdateController — update some quando o servidor volta (CA-3)', () {
    test(
      'updateAvailable volta a false se o servidor reverte para a corrente',
      () async {
        final svc = _FakeVersionService(const AppVersion('v1'))
          ..next = const AppVersion('v2');
        final c = _controller(current: const AppVersion('v1'), service: svc);
        await c.checkForUpdate();
        expect(c.updateAvailable, isTrue);

        // Servidor volta a publicar a versão que já está rodando (rollback).
        svc.next = const AppVersion('v1');
        await c.checkForUpdate();
        expect(c.updateAvailable, isFalse);
        expect(c.showBanner, isFalse);
        c.dispose();
      },
    );
  });

  group('AppUpdateController — defaults de plataforma', () {
    test(
      'construtor sem injeção usa serviço/bridge/watcher reais; dev é inerte',
      () {
        // Sem dart-define, currentVersion=dev → start() é no-op (IDR-017).
        final c = AppUpdateController();
        expect(c.currentVersion.isDev, isTrue);
        c.start();
        expect(c.showBanner, isFalse);
        c.dispose();
      },
    );
  });

  group('AppUpdateController — não-bloqueante (CA-1)', () {
    test('falha de rede não muda estado', () async {
      final svc = _FakeVersionService(const AppVersion('v1'))
        ..error = Exception('offline');
      final c = _controller(current: const AppVersion('v1'), service: svc);
      await c.checkForUpdate();
      expect(c.updateAvailable, isFalse);
      expect(c.serverVersion, isNull);
      c.dispose();
    });
  });

  group('AppUpdateController — triggers (CA-2)', () {
    test('start() faz a checagem de bootstrap (i)', () {
      fakeAsync((async) {
        final svc = _FakeVersionService(const AppVersion('v1'))
          ..next = const AppVersion('v1');
        final c = _controller(current: const AppVersion('v1'), service: svc);
        c.start();
        async.flushMicrotasks();
        expect(svc.fetchCount, 1);
        c.dispose();
      });
    });

    test('start() em dev não liga nada (i)', () {
      fakeAsync((async) {
        final svc = _FakeVersionService(const AppVersion('dev'));
        final c = _controller(current: const AppVersion('dev'), service: svc);
        c.start();
        async.elapse(const Duration(minutes: 15));
        expect(svc.fetchCount, 0);
        c.dispose();
      });
    });

    test('voltar ao foreground dispara checagem (ii)', () {
      fakeAsync((async) {
        final svc = _FakeVersionService(const AppVersion('v1'))
          ..next = const AppVersion('v1');
        final vis = _FakeVisibility(visible: true);
        final c = _controller(
          current: const AppVersion('v1'),
          service: svc,
          visibility: vis,
        );
        c.start();
        async.flushMicrotasks();
        final afterBootstrap = svc.fetchCount;
        vis.setVisible(false);
        vis.setVisible(true);
        async.flushMicrotasks();
        expect(svc.fetchCount, greaterThan(afterBootstrap));
        c.dispose();
      });
    });

    test('onLoginSuccess dispara checagem (iii)', () {
      fakeAsync((async) {
        final svc = _FakeVersionService(const AppVersion('v1'))
          ..next = const AppVersion('v1');
        final c = _controller(current: const AppVersion('v1'), service: svc);
        c.onLoginSuccess();
        async.flushMicrotasks();
        expect(svc.fetchCount, 1);
        c.dispose();
      });
    });

    test('timer periódico checa a cada pollInterval enquanto visível (iv)', () {
      fakeAsync((async) {
        final svc = _FakeVersionService(const AppVersion('v1'))
          ..next = const AppVersion('v1');
        final c = _controller(
          current: const AppVersion('v1'),
          service: svc,
          pollInterval: const Duration(minutes: 5),
        );
        c.start();
        async.flushMicrotasks();
        expect(svc.fetchCount, 1); // bootstrap
        async.elapse(const Duration(minutes: 5));
        expect(svc.fetchCount, 2);
        async.elapse(const Duration(minutes: 5));
        expect(svc.fetchCount, 3);
        c.dispose();
      });
    });

    test('timer pausa enquanto hidden e retoma ao voltar (iv)', () {
      fakeAsync((async) {
        final svc = _FakeVersionService(const AppVersion('v1'))
          ..next = const AppVersion('v1');
        final vis = _FakeVisibility(visible: true);
        final c = _controller(
          current: const AppVersion('v1'),
          service: svc,
          visibility: vis,
          pollInterval: const Duration(minutes: 5),
        );
        c.start();
        async.flushMicrotasks();
        vis.setVisible(false); // esconde → para o timer
        final atHide = svc.fetchCount;
        async.elapse(const Duration(minutes: 15));
        expect(svc.fetchCount, atHide, reason: 'sem checagens enquanto hidden');
        vis.setVisible(true); // volta → checa na hora e religa o timer
        async.flushMicrotasks();
        expect(svc.fetchCount, atHide + 1);
        async.elapse(const Duration(minutes: 5));
        expect(svc.fetchCount, atHide + 2);
        c.dispose();
      });
    });
  });

  group('AppUpdateController — "Depois" (CA-7)', () {
    test('dismiss esconde o banner mas mantém updateAvailable', () async {
      final c = _controller(
        current: const AppVersion('v1'),
        server: const AppVersion('v2'),
      );
      await c.checkForUpdate();
      expect(c.showBanner, isTrue);
      c.dismiss();
      expect(c.showBanner, isFalse);
      expect(c.updateAvailable, isTrue);
      c.dispose();
    });

    test(
      'próxima checagem reabre o banner se ainda houver versão nova',
      () async {
        final svc = _FakeVersionService(const AppVersion('v1'))
          ..next = const AppVersion('v2');
        final c = _controller(current: const AppVersion('v1'), service: svc);
        await c.checkForUpdate();
        c.dismiss();
        expect(c.showBanner, isFalse);
        await c.checkForUpdate(); // ainda v2 no servidor
        expect(c.showBanner, isTrue, reason: '"Depois" não persiste (IDR-017)');
        c.dispose();
      },
    );
  });

  group('AppUpdateController — "Atualizar agora" (CA-5)', () {
    test('applyUpdate chama o bridge', () async {
      final bridge = _FakeBridge();
      final c = _controller(
        current: const AppVersion('v1'),
        server: const AppVersion('v2'),
        bridge: bridge,
      );
      await c.applyUpdate();
      expect(bridge.calls, 1);
      c.dispose();
    });
  });
}
