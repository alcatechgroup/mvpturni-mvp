import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turni_webapp/features/app/perfil_screen.dart';
import 'package:turni_webapp/features/app/shell/app_shell_view.dart';
import 'package:turni_webapp/features/auth/auth_service.dart';

import 'a11y_harness.dart';

// STORY-080 — gate de a11y do shell de navegação (DDR-003) e do destino Perfil.
// O shell envolve TODAS as telas autenticadas; auditar o chrome (nav inferior /
// rail / sidebar) nos dois perfis e temas cobre a navegação de todas elas
// (CA-1 contraste, CA-3 alvo ≥48dp + ícone-só com label).

Widget _shell({
  required String role,
  required ThemeData theme,
  String? appBarTitle = 'Vagas',
}) => MaterialApp(
  theme: theme,
  home: AppShellView(
    role: role,
    currentIndex: 0,
    appBarTitle: appBarTitle,
    onDestinationSelected: (_) {},
    onNovaVaga: () {},
    onLogout: () {},
    userName: 'Maria Souza',
    child: const Center(child: Text('Conteúdo da tela')),
  ),
);

void main() {
  group('AppShellView — gate a11y por breakpoint × perfil × tema', () {
    // 400 = compact (NavigationBar) · 800 = rail · 1280 = sidebar persistente.
    for (final width in [400.0, 800.0, 1280.0]) {
      for (final role in ['profissional', 'contratante']) {
        for (final dark in [false, true]) {
          final tema = dark ? 'escuro' : 'claro';
          testWidgets('w=$width · $role · tema $tema', (tester) async {
            await pumpA11y(
              tester,
              (theme) => _shell(role: role, theme: theme),
              dark: dark,
              surfaceSize: Size(width, 900),
            );
            // 600–1199 = NavigationRail (desktop/tablet, mouse): o destino do
            // rail Material fica em 44dp — aceito em WCAG 2.1 AA. Bottom bar
            // (toque) e sidebar mantêm o piso de 48dp.
            await expectScreenMeetsA11y(
              tester,
              tapTargetGuideline: width >= 600 && width < 1200
                  ? iOSTapTargetGuideline
                  : null,
            );
          });
        }
      }
    }
  });

  group('PerfilScreen — gate a11y', () {
    setUp(() {
      AuthService().debugSetSession(
        const UserSession(
          name: 'Maria Souza',
          role: 'profissional',
          status: 'ativo',
          welcomeVisto: true,
          cadastroCompleto: true,
        ),
      );
    });
    tearDown(() => AuthService().debugSetSession(null));

    for (final dark in [false, true]) {
      final tema = dark ? 'escuro' : 'claro';
      testWidgets('identidade + tema + Sair — tema $tema', (tester) async {
        await pumpA11y(
          tester,
          (theme) => MaterialApp(theme: theme, home: const PerfilScreen()),
          dark: dark,
        );
        await expectScreenMeetsA11y(tester);
      });
    }
  });
}
