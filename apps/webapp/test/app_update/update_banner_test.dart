import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turni_webapp/core/app_update/app_update_controller.dart';
import 'package:turni_webapp/core/app_update/app_version.dart';
import 'package:turni_webapp/core/app_update/app_version_service.dart';
import 'package:turni_webapp/core/app_update/service_worker_bridge.dart';
import 'package:turni_webapp/core/app_update/visibility_watcher.dart';
import 'package:turni_webapp/core/app_update/widgets/update_banner.dart';

class _FakeService extends AppVersionService {
  _FakeService(this._current, this._server);
  final AppVersion _current;
  final AppVersion _server;
  @override
  AppVersion get currentVersion => _current;
  @override
  Future<AppVersion> fetchServerVersion() async => _server;
}

class _FakeBridge implements ServiceWorkerBridge {
  int calls = 0;
  @override
  Future<void> activateNewVersionAndReload() async => calls++;
}

class _FakeVisibility implements VisibilityWatcher {
  @override
  bool get isVisible => true;
  @override
  void addListener(VoidCallback listener) {}
  @override
  void removeListener(VoidCallback listener) {}
  @override
  void dispose() {}
}

void main() {
  group('UpdateBanner (CA-4)', () {
    testWidgets('mostra microcopy fixo e os dois CTAs', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UpdateBanner(onUpdateNow: () {}, onLater: () {}),
          ),
        ),
      );
      expect(find.byKey(const Key('update-banner')), findsOneWidget);
      expect(find.text('Nova versão disponível'), findsOneWidget);
      expect(find.text('Atualizar agora'), findsOneWidget);
      expect(find.text('Depois'), findsOneWidget);
    });

    testWidgets('"Atualizar agora" e "Depois" disparam os callbacks', (
      tester,
    ) async {
      var now = 0;
      var later = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UpdateBanner(
              onUpdateNow: () => now++,
              onLater: () => later++,
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('btn-update-now')));
      await tester.tap(find.byKey(const Key('btn-update-later')));
      expect(now, 1);
      expect(later, 1);
    });

    testWidgets('expõe Semantics de status (liveRegion, não-modal)', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UpdateBanner(onUpdateNow: () {}, onLater: () {}),
          ),
        ),
      );
      final semantics = tester.widget<Semantics>(
        find.descendant(
          of: find.byType(UpdateBanner),
          matching: find.byWidgetPredicate(
            (w) =>
                w is Semantics &&
                w.properties.label == 'Status: Nova versão disponível',
          ),
        ),
      );
      expect(semantics.properties.liveRegion, isTrue);
    });
  });

  group('UpdateBannerHost (CA-4 / CA-7)', () {
    testWidgets('aparece quando há update; "Depois" o esconde', (tester) async {
      final controller = AppUpdateController(
        service: _FakeService(const AppVersion('v1'), const AppVersion('v2')),
        bridge: _FakeBridge(),
        visibility: _FakeVisibility(),
      );
      await controller.checkForUpdate();

      await tester.pumpWidget(
        MaterialApp(
          home: UpdateBannerHost(
            controller: controller,
            child: const Scaffold(body: Center(child: Text('conteúdo'))),
          ),
        ),
      );
      await tester.pump();

      // Banner visível e conteúdo abaixo permanece presente (não-bloqueante).
      expect(find.byKey(const Key('update-banner')), findsOneWidget);
      expect(find.text('conteúdo'), findsOneWidget);

      // "Depois" esconde.
      await tester.tap(find.byKey(const Key('btn-update-later')));
      await tester.pump();
      expect(find.byKey(const Key('update-banner')), findsNothing);

      controller.dispose();
    });

    testWidgets('"Atualizar agora" chama o bridge (CA-5)', (tester) async {
      final bridge = _FakeBridge();
      final controller = AppUpdateController(
        service: _FakeService(const AppVersion('v1'), const AppVersion('v2')),
        bridge: bridge,
        visibility: _FakeVisibility(),
      );
      await controller.checkForUpdate();

      await tester.pumpWidget(
        MaterialApp(
          home: UpdateBannerHost(
            controller: controller,
            child: const Scaffold(body: SizedBox.expand()),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('btn-update-now')));
      await tester.pump();
      expect(bridge.calls, 1);

      controller.dispose();
    });

    testWidgets('sem update, nada é mostrado', (tester) async {
      final controller = AppUpdateController(
        service: _FakeService(const AppVersion('v1'), const AppVersion('v1')),
        bridge: _FakeBridge(),
        visibility: _FakeVisibility(),
      );
      await controller.checkForUpdate();

      await tester.pumpWidget(
        MaterialApp(
          home: UpdateBannerHost(
            controller: controller,
            child: const Scaffold(body: SizedBox.expand()),
          ),
        ),
      );
      await tester.pump();
      expect(find.byKey(const Key('update-banner')), findsNothing);

      controller.dispose();
    });
  });
}
