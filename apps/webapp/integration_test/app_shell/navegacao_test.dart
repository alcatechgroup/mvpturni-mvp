// integration_test — STORY-077 CA-7 (E2E browser real do shell de navegação).
//
// Same-origin (proxy + --web-launch-url, IDR-021) contra o BACKEND REAL, com os
// usuários genéricos do seed (profissional.teste / contratante.teste). Cobre os
// dois papéis nos dois extremos de viewport:
//   1. profissional · MOBILE (compact): NavigationBar inferior com Vagas/Turnos/
//      Perfil; sem ação "Nova vaga" (RBAC); navega Vagas → Perfil → Vagas com o
//      estado ativo correto e o shell persistente.
//   2. contratante · DESKTOP (large): sidebar persistente com os 3 destinos + ação
//      "Nova vaga" (RBAC); navega Vagas → Perfil → Turnos com ativo correto.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/login_helper.dart';
import '../helpers/pump_app.dart';
import '../helpers/route_helper.dart';

/// Define a viewport (largura × 900) e garante o reset ao fim do cenário, para
/// não vazar tamanho para as outras suítes do mesmo `flutter drive`.
void _setViewport(WidgetTester tester, double width) {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = Size(width, 900);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

int _selectedBottom(WidgetTester tester) =>
    tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex;

/// Texto [t] dentro da barra superior do shell.
Finder _naBarra(String t) => find.descendant(
  of: find.byKey(const Key('shell-app-bar')),
  matching: find.text(t),
);

void main() {
  testWidgets(
    'profissional · mobile: bottom bar com destinos do papel e navegação ativa (CA-7)',
    (tester) async {
      await pumpApp(tester);
      assertOnRoute(tester, '/login');

      await loginAsProfissional(tester);
      await awaitRouteChange(tester, '/');
      await tester.pumpAndSettle();

      _setViewport(tester, 400); // compact
      await tester.pumpAndSettle();

      // Shell na forma de NavigationBar com os 3 destinos do papel.
      final bar = find.byKey(const Key('shell-nav-bar'));
      await pumpUntilFound(tester, bar);
      expect(
        find.descendant(of: bar, matching: find.text('Vagas')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: bar, matching: find.text('Turnos')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: bar, matching: find.text('Perfil')),
        findsOneWidget,
      );
      // RBAC: profissional não tem a ação "Nova vaga" (é do contratante).
      expect(find.byKey(const Key('shell-fab-nova-vaga')), findsNothing);
      // Home = Vagas ativo.
      expect(_selectedBottom(tester), 0);

      // STORY-078: o shell é dono da barra superior ("Vagas") e o atalho ad-hoc
      // "Meus turnos" do feed foi removido (CA-2/CA-3). (O drill-down esconder a
      // barra do shell é coberto, determinístico, no widget test do AppShell —
      // aqui evitamos tocar telas com spinner de carga, que travam pumpAndSettle.)
      expect(find.byKey(const Key('shell-app-bar')), findsOneWidget);
      expect(_naBarra('Vagas'), findsOneWidget);
      expect(find.byKey(const Key('feed-meus-turnos-btn')), findsNothing);

      // Alcança Turnos e Perfil — completando 100% dos destinos do papel a partir
      // do estado inicial (CA-1; Vagas já é a home); o título muda no shell (CA-3).
      await tester.tap(find.descendant(of: bar, matching: find.text('Turnos')));
      await tester.pumpAndSettle();
      await awaitRouteChange(tester, '/turnos');
      expect(_selectedBottom(tester), 1);
      expect(_naBarra('Meus turnos'), findsOneWidget);

      // Navega Turnos → Perfil (estado ativo acompanha a rota).
      await tester.tap(find.descendant(of: bar, matching: find.text('Perfil')));
      await tester.pumpAndSettle();
      await awaitRouteChange(tester, '/perfil');
      await pumpUntilFound(tester, find.byKey(const Key('perfil-screen')));
      expect(_selectedBottom(tester), 2);

      // Volta Perfil → Vagas; o shell persiste (nunca recriado) e o ativo atualiza.
      await tester.tap(find.descendant(of: bar, matching: find.text('Vagas')));
      await tester.pumpAndSettle();
      await awaitRouteChange(tester, '/');
      expect(_selectedBottom(tester), 0);

      // Deep-link por URL (notificação/bookmark): entrar direto numa raiz de
      // destino abre DENTRO do shell com o destino certo ativo (CA-4/CA-6).
      await goTo(tester, '/profissional/turnos');
      await pumpUntilFound(tester, find.byKey(const Key('meus-turnos-screen')));
      expect(_selectedBottom(tester), 1);
      expect(_naBarra('Meus turnos'), findsOneWidget);
    },
  );

  testWidgets(
    'contratante · desktop: sidebar com destinos + "Nova vaga" e navegação ativa (CA-7)',
    (tester) async {
      await pumpApp(tester);
      assertOnRoute(tester, '/login');

      await loginAsContratante(tester);
      await awaitRouteChange(tester, '/');
      await tester.pumpAndSettle();

      _setViewport(tester, 1300); // large
      await tester.pumpAndSettle();

      // Shell na forma de sidebar persistente com os 3 destinos.
      final drawer = find.byKey(const Key('shell-nav-drawer'));
      await pumpUntilFound(tester, drawer);
      expect(find.byKey(const Key('shell-nav-vagas')), findsOneWidget);
      expect(find.byKey(const Key('shell-nav-turnos')), findsOneWidget);
      expect(find.byKey(const Key('shell-nav-perfil')), findsOneWidget);
      // RBAC: contratante TEM a ação primária "Nova vaga".
      expect(find.byKey(const Key('shell-fab-nova-vaga')), findsOneWidget);

      // STORY-078: barra superior do shell com "Minhas vagas"; o atalho ad-hoc
      // "Turnos" da AppBar de Minhas vagas foi removido (CA-2/CA-3).
      expect(find.byKey(const Key('shell-app-bar')), findsOneWidget);
      expect(_naBarra('Minhas vagas'), findsOneWidget);
      expect(find.byKey(const Key('minhas-vagas-turnos-btn')), findsNothing);

      // Navega Vagas → Perfil.
      await tester.tap(find.byKey(const Key('shell-nav-perfil')));
      await tester.pumpAndSettle();
      await awaitRouteChange(tester, '/perfil');
      await pumpUntilFound(tester, find.byKey(const Key('perfil-screen')));
      expect(_naBarra('Perfil'), findsOneWidget);

      // Navega Perfil → Turnos (rota canônica role-dispatch → tela do contratante).
      await tester.tap(find.byKey(const Key('shell-nav-turnos')));
      await tester.pumpAndSettle();
      await awaitRouteChange(tester, '/turnos');
      await pumpUntilFound(
        tester,
        find.byKey(const Key('contratante-turnos-screen')),
      );
      // 100% dos destinos do contratante alcançados (CA-1); título no shell (CA-3).
      expect(_naBarra('Turnos'), findsOneWidget);
      // O shell continua visível ao lado do conteúdo (persistente).
      expect(drawer, findsOneWidget);
    },
  );
}
