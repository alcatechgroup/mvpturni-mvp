// STORY-022 — tela de welcome pós-aprovação (SCREEN-STORY-022-welcome).
// Cobre: headline personalizada por papel, bullets por papel, tema por papel,
// estado já-ativo (CA-6), fallback de nome, "Fazer depois" = logout, erro ao marcar.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:turni_webapp/ds/tokens.dart';
import 'package:turni_webapp/features/auth/auth_service.dart';
import 'package:turni_webapp/features/funnel/welcome_screen.dart';

GoRouter _router() => GoRouter(
  initialLocation: '/welcome',
  routes: [
    GoRoute(path: '/welcome', builder: (c, s) => const WelcomeScreen()),
    GoRoute(
      path: '/completar-cadastro',
      builder: (c, s) => const Scaffold(body: Text('completar-cadastro')),
    ),
    GoRoute(
      path: '/login',
      builder: (c, s) => const Scaffold(body: Text('login')),
    ),
    GoRoute(
      path: '/',
      builder: (c, s) => const Scaffold(body: Text('home')),
    ),
  ],
);

Widget _app() => MaterialApp.router(
  routerConfig: _router(),
  theme: ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: TurniColors.accentLight),
    useMaterial3: true,
  ),
);

UserSession _session({
  String name = 'Diego Silva',
  String role = 'profissional',
  String status = 'liberado',
  bool welcomeVisto = false,
}) => UserSession(
  name: name,
  role: role,
  status: status,
  welcomeVisto: welcomeVisto,
  cadastroCompleto: false,
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    AuthService().debugSetSession(null);
  });

  group('WelcomeScreen — estrutura e conteúdo (CA-1, CA-2)', () {
    testWidgets('tem key screen-welcome e logomarca', (tester) async {
      AuthService().debugSetSession(_session());
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('screen-welcome')), findsOneWidget);
      expect(find.byKey(const Key('welcome-brand')), findsOneWidget);
      expect(find.text('TURNI.'), findsOneWidget);
    });

    testWidgets('headline usa o primeiro nome do usuário', (tester) async {
      AuthService().debugSetSession(_session(name: 'Diego Silva'));
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      final headline = tester.widget<Text>(
        find.byKey(const Key('welcome-headline')),
      );
      expect(headline.data, 'Bem-vindo(a), Diego!');
    });

    testWidgets('headline cai no fallback quando não há nome', (tester) async {
      AuthService().debugSetSession(_session(name: ''));
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      final headline = tester.widget<Text>(
        find.byKey(const Key('welcome-headline')),
      );
      expect(headline.data, 'Boas-vindas!');
    });

    testWidgets('CTA "Vamos lá" e link "Fazer depois" presentes', (
      tester,
    ) async {
      AuthService().debugSetSession(_session());
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('btn-vamos-la')), findsOneWidget);
      expect(find.text('Vamos lá'), findsOneWidget);
      expect(find.byKey(const Key('link-fazer-depois')), findsOneWidget);
      expect(find.text('Fazer depois'), findsOneWidget);
    });
  });

  group('WelcomeScreen — bullets por papel (CA-2)', () {
    testWidgets('profissional vê bullets de documento/Pix/comprovante', (
      tester,
    ) async {
      AuthService().debugSetSession(_session(role: 'profissional'));
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      expect(find.text('Seu documento (CPF ou CNPJ)'), findsOneWidget);
      expect(find.text('Sua chave Pix para receber'), findsOneWidget);
      expect(find.text('Uma foto de comprovante'), findsOneWidget);
    });

    testWidgets('contratante vê bullets de CNPJ/endereço/cultura', (
      tester,
    ) async {
      AuthService().debugSetSession(_session(role: 'contratante'));
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      expect(find.text('O CNPJ do estabelecimento'), findsOneWidget);
      expect(find.text('O endereço completo'), findsOneWidget);
      expect(find.text('Um pouco da cultura do lugar'), findsOneWidget);
      // não mostra os bullets do profissional
      expect(find.text('Sua chave Pix para receber'), findsNothing);
    });
  });

  group('WelcomeScreen — tema por papel (CA-3)', () {
    testWidgets('CTA do profissional usa accentLight (verde)', (tester) async {
      AuthService().debugSetSession(_session(role: 'profissional'));
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      final btn = tester.widget<FilledButton>(
        find.byKey(const Key('btn-vamos-la')),
      );
      final bg = btn.style?.backgroundColor?.resolve({});
      expect(bg, TurniColors.accentLight);
    });

    testWidgets('CTA do contratante usa contratanteAccentLight (mostarda)', (
      tester,
    ) async {
      AuthService().debugSetSession(_session(role: 'contratante'));
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      final btn = tester.widget<FilledButton>(
        find.byKey(const Key('btn-vamos-la')),
      );
      final bg = btn.style?.backgroundColor?.resolve({});
      expect(bg, TurniColors.contratanteAccentLight);
    });
  });

  group('WelcomeScreen — usuário já ativo (CA-6)', () {
    testWidgets(
      'status=ativo mostra banner informativo + link para home, sem CTA',
      (tester) async {
        AuthService().debugSetSession(
          _session(status: 'ativo', welcomeVisto: true),
        );
        await tester.pumpWidget(_app());
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('banner-already-active')), findsOneWidget);
        expect(
          find.text('Você já está com o cadastro completo.'),
          findsOneWidget,
        );
        expect(find.byKey(const Key('link-home')), findsOneWidget);
        // não há CTA "Vamos lá" nem bullets
        expect(find.byKey(const Key('btn-vamos-la')), findsNothing);
        expect(find.byKey(const Key('welcome-bullets')), findsNothing);
      },
    );

    testWidgets('link "Ir para a home" navega para /', (tester) async {
      AuthService().debugSetSession(
        _session(status: 'ativo', welcomeVisto: true),
      );
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('link-home')));
      await tester.pumpAndSettle();
      expect(find.text('home'), findsOneWidget);
    });
  });

  group('WelcomeScreen — "Fazer depois" (CA-5)', () {
    testWidgets('faz logout e volta para /login', (tester) async {
      AuthService().debugSetSession(_session());
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('link-fazer-depois')));
      await tester.pumpAndSettle();

      expect(find.text('login'), findsOneWidget);
      // sessão foi limpa (logout sem marcar welcome)
      expect(AuthService().session, isNull);
    });
  });

  group('WelcomeScreen — erro ao marcar (estado §5.3)', () {
    testWidgets('falha na chamada mostra banner de erro e mantém em /welcome', (
      tester,
    ) async {
      AuthService().debugSetSession(_session());
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      // Sem servidor no ambiente de teste, markWelcomeSeen retorna false.
      await tester.tap(find.byKey(const Key('btn-vamos-la')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('banner-welcome-erro')), findsOneWidget);
      expect(
        find.text('Não conseguimos seguir agora. Tentar de novo.'),
        findsOneWidget,
      );
      // não navegou
      expect(find.text('completar-cadastro'), findsNothing);
    });
  });
}
