import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turni_webapp/core/env/env_banner.dart';
import 'package:turni_webapp/ds/theme.dart';
import 'package:turni_webapp/ds/tokens.dart';
import 'package:turni_webapp/features/auth/auth_service.dart';

// STORY-075 — banner global "Ambiente de teste — pagamentos simulados" (PDR-017).
// Visível apenas em homolog + sessão ativa; nunca em production/local nem pré-auth.

const _microcopy = 'Ambiente de teste — pagamentos simulados';

UserSession _sessaoAtiva({String role = 'profissional'}) => UserSession(
  name: 'Diego',
  role: role,
  status: 'ativo',
  welcomeVisto: true,
  cadastroCompleto: true,
);

Widget _app({required String ambiente, ThemeData? theme}) {
  return MaterialApp(
    theme: theme ?? buildLightTheme(),
    builder: (context, child) => EnvBannerHost(
      ambiente: ambiente,
      auth: AuthService(),
      child: child ?? const SizedBox.shrink(),
    ),
    home: const Scaffold(body: Center(child: Text('conteúdo'))),
  );
}

void main() {
  tearDown(() => AuthService().debugSetSession(null));

  group('EnvBannerHost — visibilidade por ambiente (CA-1/CA-2)', () {
    testWidgets('mostra o banner em homolog com sessão ativa, microcopy exata '
        '(CA-1)', (tester) async {
      AuthService().debugSetSession(_sessaoAtiva());

      await tester.pumpWidget(_app(ambiente: 'homolog'));

      expect(find.byKey(const Key('env-banner')), findsOneWidget);
      expect(find.text(_microcopy), findsOneWidget);
      // Conteúdo da tela continua presente (banner empurra, não cobre).
      expect(find.text('conteúdo'), findsOneWidget);
    });

    testWidgets('mostra o banner também para contratante (mesma microcopy '
        'para todos os papéis)', (tester) async {
      AuthService().debugSetSession(_sessaoAtiva(role: 'contratante'));

      await tester.pumpWidget(_app(ambiente: 'homolog'));

      expect(find.byKey(const Key('env-banner')), findsOneWidget);
    });

    testWidgets('NÃO mostra em production mesmo com sessão ativa (CA-2)', (
      tester,
    ) async {
      AuthService().debugSetSession(_sessaoAtiva());

      await tester.pumpWidget(_app(ambiente: 'production'));

      expect(find.byKey(const Key('env-banner')), findsNothing);
      expect(find.text('conteúdo'), findsOneWidget);
    });

    testWidgets('NÃO mostra em local (dev) mesmo com sessão ativa (CA-2)', (
      tester,
    ) async {
      AuthService().debugSetSession(_sessaoAtiva());

      await tester.pumpWidget(_app(ambiente: 'local'));

      expect(find.byKey(const Key('env-banner')), findsNothing);
    });

    testWidgets('fail-safe: ambiente desconhecido NÃO mostra o banner '
        '(borda)', (tester) async {
      AuthService().debugSetSession(_sessaoAtiva());

      await tester.pumpWidget(_app(ambiente: 'staging'));

      expect(find.byKey(const Key('env-banner')), findsNothing);
    });

    testWidgets('fail-safe: ambiente vazio NÃO mostra o banner (borda)', (
      tester,
    ) async {
      AuthService().debugSetSession(_sessaoAtiva());

      await tester.pumpWidget(_app(ambiente: ''));

      expect(find.byKey(const Key('env-banner')), findsNothing);
    });
  });

  group('EnvBannerHost — sessão (CA-4)', () {
    testWidgets('NÃO mostra sem sessão (pré-auth: login/cadastro/reset) '
        'mesmo em homolog (CA-4)', (tester) async {
      AuthService().debugSetSession(null);

      await tester.pumpWidget(_app(ambiente: 'homolog'));

      expect(find.byKey(const Key('env-banner')), findsNothing);
      expect(find.text('conteúdo'), findsOneWidget);
    });

    testWidgets('banner aparece no login da sessão e some no logout '
        '(reage ao AuthService — borda de expiração)', (tester) async {
      AuthService().debugSetSession(null);

      await tester.pumpWidget(_app(ambiente: 'homolog'));
      expect(find.byKey(const Key('env-banner')), findsNothing);

      // Sessão entra (login) → banner aparece sem rebuild externo.
      AuthService().debugSetSession(_sessaoAtiva());
      await tester.pump();
      expect(find.byKey(const Key('env-banner')), findsOneWidget);

      // Sessão expira (401/logout) → banner some junto.
      AuthService().debugSetSession(null);
      await tester.pump();
      expect(find.byKey(const Key('env-banner')), findsNothing);
    });
  });

  group('EnvBanner — não dispensável (CA-5)', () {
    testWidgets('não tem botão de fechar nem qualquer ação interativa', (
      tester,
    ) async {
      AuthService().debugSetSession(_sessaoAtiva());

      await tester.pumpWidget(_app(ambiente: 'homolog'));

      final banner = find.byKey(const Key('env-banner'));
      expect(
        find.descendant(
          of: banner,
          matching: find.byWidgetPredicate(
            (w) => w is ButtonStyleButton || w is IconButton || w is InkWell,
          ),
        ),
        findsNothing,
      );

      // Tocar no banner não o remove.
      await tester.tap(banner, warnIfMissed: false);
      await tester.pump();
      expect(banner, findsOneWidget);
    });
  });

  group('EnvBanner — tokens DS e acessibilidade (CA-6/CA-7)', () {
    testWidgets('tema claro: fundo warning.soft + texto neutro '
        'alto-contraste + ícone warning (CA-6, padrão DDR-001 §4)', (
      tester,
    ) async {
      AuthService().debugSetSession(_sessaoAtiva());

      await tester.pumpWidget(_app(ambiente: 'homolog'));

      final material = tester.widget<Material>(
        find.descendant(
          of: find.byType(EnvBanner),
          matching: find.byType(Material),
        ),
      );
      expect(material.color, TurniColors.warnSoftLight);

      final icon = tester.widget<Icon>(
        find.descendant(
          of: find.byKey(const Key('env-banner')),
          matching: find.byType(Icon),
        ),
      );
      expect(icon.color, TurniColors.warnLight);

      final text = tester.widget<Text>(find.text(_microcopy));
      expect(text.style?.color, TurniColors.textStrongLight);
    });

    testWidgets('tema escuro: tokens warning escuros (CA-6)', (tester) async {
      AuthService().debugSetSession(_sessaoAtiva());

      await tester.pumpWidget(
        _app(ambiente: 'homolog', theme: buildDarkTheme()),
      );

      final material = tester.widget<Material>(
        find.descendant(
          of: find.byType(EnvBanner),
          matching: find.byType(Material),
        ),
      );
      expect(material.color, TurniColors.warnSoftDark);

      final icon = tester.widget<Icon>(
        find.descendant(
          of: find.byKey(const Key('env-banner')),
          matching: find.byType(Icon),
        ),
      );
      expect(icon.color, TurniColors.warnDark);
    });

    testWidgets('expõe Semantics de status não-modal (CA-7)', (tester) async {
      AuthService().debugSetSession(_sessaoAtiva());

      await tester.pumpWidget(_app(ambiente: 'homolog'));

      final semantics = tester.widget<Semantics>(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == 'Aviso: $_microcopy',
        ),
      );
      expect(semantics.container, isTrue);
    });

    testWidgets('legível em tela estreita 360px — sem overflow (CA-7, '
        'mobile-first)', (tester) async {
      AuthService().debugSetSession(_sessaoAtiva());
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_app(ambiente: 'homolog'));

      // Sem exceção de overflow e o texto segue visível.
      expect(tester.takeException(), isNull);
      expect(find.text(_microcopy), findsOneWidget);
    });
  });
}
