// STORY-016 — CA-5 — Tela de login do WebApp (SCREEN-STORY-016 Tela A)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:turni_webapp/features/auth/login_screen.dart';
import 'package:turni_webapp/ds/tokens.dart';

// Router mínimo para testes de tela isolada
GoRouter _testRouter() => GoRouter(
  routes: [
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(
      path: '/esqueci-minha-senha',
      builder: (context, state) => const Scaffold(body: Text('forgot')),
    ),
    GoRoute(
      path: '/welcome',
      builder: (context, state) => const Scaffold(body: Text('welcome')),
    ),
    GoRoute(
      path: '/',
      builder: (context, state) => const Scaffold(body: Text('home')),
    ),
    GoRoute(
      path: '/cadastro/profissional',
      builder: (context, state) => const Scaffold(body: Text('cadastro')),
    ),
    GoRoute(
      path: '/cadastro/contratante',
      builder: (context, state) =>
          const Scaffold(body: Text('cadastro-contratante')),
    ),
  ],
  initialLocation: '/login',
);

Widget _loginApp() => MaterialApp.router(
  routerConfig: _testRouter(),
  theme: ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: TurniColors.accentLight),
    useMaterial3: true,
  ),
);

void main() {
  group('LoginScreen', () {
    testWidgets('renderiza a logomarca TURNI.', (tester) async {
      await tester.pumpWidget(_loginApp());
      await tester.pumpAndSettle();

      expect(find.text('TURNI.'), findsOneWidget);
    });

    testWidgets('tem campo e-mail com key correta', (tester) async {
      await tester.pumpWidget(_loginApp());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('input-email')), findsOneWidget);
    });

    testWidgets('tem campo senha com key correta', (tester) async {
      await tester.pumpWidget(_loginApp());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('input-password')), findsOneWidget);
    });

    testWidgets('tem botão Entrar com key correta', (tester) async {
      await tester.pumpWidget(_loginApp());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('btn-submit-login')), findsOneWidget);
    });

    testWidgets('tem toggle show/hide senha com key correta', (tester) async {
      await tester.pumpWidget(_loginApp());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('btn-toggle-password')), findsOneWidget);
    });

    testWidgets('tem link "Esqueci minha senha" com key correta', (
      tester,
    ) async {
      await tester.pumpWidget(_loginApp());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('link-forgot-password')), findsOneWidget);
    });

    testWidgets('tem link de criar conta de profissional que leva ao pré-cadastro', (
      tester,
    ) async {
      await tester.pumpWidget(_loginApp());
      await tester.pumpAndSettle();

      final link = find.byKey(const Key('link-criar-conta'));
      expect(link, findsOneWidget);

      await tester.tap(link);
      await tester.pumpAndSettle();
      expect(
        find.text('cadastro'),
        findsOneWidget,
      ); // navegou para /cadastro/profissional
    });

    testWidgets('tem link de criar conta de estabelecimento que leva ao pré-cadastro', (
      tester,
    ) async {
      await tester.pumpWidget(_loginApp());
      await tester.pumpAndSettle();

      final link = find.byKey(const Key('link-criar-conta-contratante'));
      expect(link, findsOneWidget);

      await tester.tap(link);
      await tester.pumpAndSettle();
      expect(
        find.text('cadastro-contratante'),
        findsOneWidget,
      ); // navegou para /cadastro/contratante
    });

    testWidgets('validação exibe erro para campos vazios', (tester) async {
      await tester.pumpWidget(_loginApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('btn-submit-login')));
      await tester.pumpAndSettle();

      expect(find.text('Este campo é obrigatório.'), findsWidgets);
    });

    testWidgets('validação exibe erro para e-mail inválido', (tester) async {
      await tester.pumpWidget(_loginApp());
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('input-email')),
        'nao-e-email',
      );
      await tester.enterText(find.byKey(const Key('input-password')), 'senha');
      await tester.tap(find.byKey(const Key('btn-submit-login')));
      await tester.pumpAndSettle();

      expect(find.text('E-mail inválido.'), findsOneWidget);
    });

    testWidgets('toggle show/hide inverte a visibilidade da senha', (
      tester,
    ) async {
      await tester.pumpWidget(_loginApp());
      await tester.pumpAndSettle();

      // Inicialmente obscuro
      final input = tester.widget<EditableText>(
        find.descendant(
          of: find.byKey(const Key('input-password')),
          matching: find.byType(EditableText),
        ),
      );
      expect(input.obscureText, isTrue);

      // Clica no toggle
      await tester.tap(find.byKey(const Key('btn-toggle-password')));
      await tester.pumpAndSettle();

      final inputAfter = tester.widget<EditableText>(
        find.descendant(
          of: find.byKey(const Key('input-password')),
          matching: find.byType(EditableText),
        ),
      );
      expect(inputAfter.obscureText, isFalse);
    });

    testWidgets('tela tem key screen-login-webapp', (tester) async {
      await tester.pumpWidget(_loginApp());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('screen-login-webapp')), findsOneWidget);
    });
  });
}
