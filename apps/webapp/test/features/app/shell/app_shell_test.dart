import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:turni_webapp/features/app/shell/app_shell.dart';
import 'package:turni_webapp/features/auth/auth_service.dart';

// STORY-078 — glue do shell: a partir da rota corrente (state.uri.path) e do
// papel da sessão, o AppShell decide o título da barra superior e se ela aparece
// (raiz de destino) ou não (drill-down). Testa a integração location → barra que
// no E2E é coberta de ponta a ponta; aqui isola o glue num GoRouter mínimo.

UserSession _sessao(String role) => UserSession(
  name: 'Fulano',
  role: role,
  status: 'ativo',
  welcomeVisto: true,
  cadastroCompleto: true,
);

GoRouter _router() => GoRouter(
  initialLocation: '/',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          AppShell(navigationShell: navigationShell, location: state.uri.path),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/', builder: (_, _) => const Text('home-body')),
            // Drill-down dentro do branch Vagas: traz a própria AppBar.
            GoRoute(
              path: '/vaga/:id',
              builder: (_, _) => Scaffold(
                appBar: AppBar(title: const Text('Detalhe da vaga')),
                body: const Text('drill-body'),
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          initialLocation: '/turnos',
          routes: [
            GoRoute(path: '/turnos', builder: (_, _) => const Text('turnos')),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/perfil', builder: (_, _) => const Text('perfil')),
          ],
        ),
      ],
    ),
  ],
);

Future<void> _pump(WidgetTester tester, GoRouter router) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(400, 900); // compact
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pumpAndSettle();
}

Finder _naBarra(String t) => find.descendant(
  of: find.byKey(const Key('shell-app-bar')),
  matching: find.text(t),
);

void main() {
  tearDown(() => AuthService().debugSetSession(null));

  testWidgets('(a) profissional na raiz "/" → barra do shell com "Vagas"', (
    tester,
  ) async {
    AuthService().debugSetSession(_sessao('profissional'));
    await _pump(tester, _router());
    expect(find.byKey(const Key('shell-app-bar')), findsOneWidget);
    expect(_naBarra('Vagas'), findsOneWidget);
  });

  testWidgets(
    '(a) contratante na raiz "/" → barra do shell com "Minhas vagas"',
    (tester) async {
      AuthService().debugSetSession(_sessao('contratante'));
      await _pump(tester, _router());
      expect(_naBarra('Minhas vagas'), findsOneWidget);
    },
  );

  testWidgets(
    '(b) drill-down /vaga/:id → sem barra do shell (a tela tem a sua)',
    (tester) async {
      AuthService().debugSetSession(_sessao('profissional'));
      final router = _router();
      await _pump(tester, router);

      router.go('/vaga/abc');
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('shell-app-bar')), findsNothing);
      expect(
        find.text('Detalhe da vaga'),
        findsOneWidget,
      ); // AppBar da própria tela
    },
  );

  testWidgets('(c) fail-secure — papel desconhecido não pinta título', (
    tester,
  ) async {
    AuthService().debugSetSession(_sessao('admin'));
    await _pump(tester, _router());
    // Sem destinos (fail-secure) não há título de seção para mostrar.
    expect(find.byKey(const Key('shell-app-bar')), findsNothing);
  });
}
