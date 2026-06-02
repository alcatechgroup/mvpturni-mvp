import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turni_webapp/core/install/install_bridge.dart';
import 'package:turni_webapp/core/install/install_controller.dart';
import 'package:turni_webapp/core/install/widgets/install_action_card.dart';
import 'package:turni_webapp/core/install/widgets/install_action_slot.dart';
import 'package:turni_webapp/core/install/widgets/ios_install_instructions_dialog.dart';

class _FakeBridge implements InstallBridge {
  _FakeBridge({
    this.isInstallable = false,
    this.isStandalone = false,
    this.isIOS = false,
  });
  @override
  bool isInstallable;
  @override
  bool isStandalone;
  @override
  bool isIOS;
  @override
  Future<String> promptNative() async => 'unavailable';

  @override
  void addListener(VoidCallback listener) {}
  @override
  void removeListener(VoidCallback listener) {}
  @override
  void dispose() {}
}

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
);

void main() {
  group('InstallActionCard (CA-10 / CA-12 / CA-13)', () {
    testWidgets('mostra microcopy e CTA "Instalar" no Chromium', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          InstallActionCard(isIOS: false, onInstall: () {}, onDismiss: () {}),
        ),
      );
      expect(find.text('Instalar app na tela inicial'), findsOneWidget);
      expect(find.text('Instalar'), findsOneWidget);
      expect(find.text('Agora não'), findsOneWidget);
      expect(find.text('Como instalar'), findsNothing);
    });

    testWidgets('CTA vira "Como instalar" no iOS', (tester) async {
      await tester.pumpWidget(
        _wrap(
          InstallActionCard(isIOS: true, onInstall: () {}, onDismiss: () {}),
        ),
      );
      expect(find.text('Como instalar'), findsOneWidget);
      expect(find.text('Instalar'), findsNothing);
    });

    testWidgets('CTA e "Agora não" disparam callbacks', (tester) async {
      var install = 0;
      var dismiss = 0;
      await tester.pumpWidget(
        _wrap(
          InstallActionCard(
            isIOS: false,
            onInstall: () => install++,
            onDismiss: () => dismiss++,
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('btn-install-cta')));
      await tester.tap(find.byKey(const Key('btn-install-dismiss')));
      expect(install, 1);
      expect(dismiss, 1);
    });

    testWidgets('em tela estreita (iPhone) o texto não é espremido', (
      tester,
    ) async {
      // Regressão: num Row [texto + 2 botões] numa largura de iPhone, o Expanded
      // do texto encolhia e quebrava 1 caractere por linha. O texto deve ocupar
      // largura útil (layout empilhado).
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 360,
                child: InstallActionCard(
                  isIOS: true,
                  onInstall: () {},
                  onDismiss: () {},
                ),
              ),
            ),
          ),
        ),
      );
      final textSize = tester.getSize(
        find.text('Instalar app na tela inicial'),
      );
      expect(
        textSize.width,
        greaterThan(150),
        reason: 'texto espremido (char-por-linha) indica layout quebrado',
      );
    });

    testWidgets('expõe Semantics(button:true) no CTA (CA-12)', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrap(
          InstallActionCard(isIOS: false, onInstall: () {}, onDismiss: () {}),
        ),
      );
      expect(
        find.bySemanticsLabel('Instalar app na tela inicial'),
        findsOneWidget,
      );
      handle.dispose();
    });
  });

  group('IosInstallInstructionsDialog (CA-11)', () {
    testWidgets('mostra os 2 passos e "Entendi"', (tester) async {
      await tester.pumpWidget(
        _wrap(IosInstallInstructionsDialog(onClose: () {})),
      );
      expect(find.byKey(const Key('ios-install-dialog')), findsOneWidget);
      expect(find.textContaining('Compartilhar'), findsOneWidget);
      expect(find.textContaining('Adicionar à Tela de Início'), findsOneWidget);
      expect(find.text('Entendi'), findsOneWidget);
    });

    testWidgets('"Entendi" dispara onClose', (tester) async {
      var closed = 0;
      await tester.pumpWidget(
        _wrap(IosInstallInstructionsDialog(onClose: () => closed++)),
      );
      await tester.tap(find.byKey(const Key('btn-ios-understood')));
      expect(closed, 1);
    });
  });

  group('InstallActionSlot (CA-10 / CA-11)', () {
    testWidgets('aparece quando showAction=true e some quando dispensa', (
      tester,
    ) async {
      final controller = InstallController(
        bridge: _FakeBridge(isInstallable: true),
      )..start();
      await tester.pumpWidget(
        _wrap(
          InstallActionSlot(
            key: const Key('install-action-test'),
            controller: controller,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Instalar app na tela inicial'), findsOneWidget);

      // "Agora não" → some no ciclo.
      await tester.tap(find.byKey(const Key('btn-install-dismiss')));
      await tester.pumpAndSettle();
      expect(find.text('Instalar app na tela inicial'), findsNothing);
      controller.dispose();
    });

    testWidgets('não aparece quando showAction=false', (tester) async {
      final controller = InstallController(bridge: _FakeBridge())..start();
      await tester.pumpWidget(_wrap(InstallActionSlot(controller: controller)));
      await tester.pumpAndSettle();
      expect(find.text('Instalar app na tela inicial'), findsNothing);
      controller.dispose();
    });

    testWidgets('não aparece em modo standalone — já instalado (CA-21)', (
      tester,
    ) async {
      // Instalável, mas rodando em standalone → não oferece instalar.
      final controller = InstallController(
        bridge: _FakeBridge(isInstallable: true, isStandalone: true),
      )..start();
      await tester.pumpWidget(_wrap(InstallActionSlot(controller: controller)));
      await tester.pumpAndSettle();
      expect(find.text('Instalar app na tela inicial'), findsNothing);
      controller.dispose();
    });

    testWidgets('clique no card iOS abre o modal e "Entendi" fecha (CA-11)', (
      tester,
    ) async {
      final controller = InstallController(bridge: _FakeBridge(isIOS: true))
        ..start();
      await tester.pumpWidget(_wrap(InstallActionSlot(controller: controller)));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('btn-install-cta')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('ios-install-dialog')), findsOneWidget);

      await tester.tap(find.byKey(const Key('btn-ios-understood')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('ios-install-dialog')), findsNothing);
      expect(controller.showIosInstructions, isFalse);
      controller.dispose();
    });
  });
}
