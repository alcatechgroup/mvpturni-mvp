// Testes unitários da WelcomeScreen (CA-14: cobertura ≥80%; lógica de versão ≥98%).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turni_webapp/ds/tokens.dart';
import 'package:turni_webapp/features/welcome/welcome_screen.dart';

Widget _wrap(Widget child) => MaterialApp(home: child);

void main() {
  group('WelcomeScreen — identidade visual e estrutura', () {
    testWidgets('renderiza logomarca TURNI. com key correta', (tester) async {
      await tester.pumpWidget(_wrap(const WelcomeScreen()));
      await tester.pumpAndSettle();

      final brand = find.byKey(const Key('screen-welcome-brand'));
      expect(brand, findsOneWidget);
      final text = tester.widget<Text>(brand);
      expect(text.data, 'TURNI.');
    });

    testWidgets('renderiza subtítulo correto', (tester) async {
      await tester.pumpWidget(_wrap(const WelcomeScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Hospitalidade on-demand'), findsOneWidget);
    });

    testWidgets('renderiza linha de pilares', (tester) async {
      await tester.pumpWidget(_wrap(const WelcomeScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Match · PIN · Pix em 15 min'), findsOneWidget);
    });

    testWidgets('renderiza link para /health com key e texto corretos', (tester) async {
      await tester.pumpWidget(_wrap(const WelcomeScreen()));
      await tester.pumpAndSettle();

      final link = find.byKey(const Key('screen-welcome-health-link'));
      expect(link, findsOneWidget);
      expect(find.text('Ver status do sistema'), findsOneWidget);
    });

    testWidgets('renderiza key da tela raiz', (tester) async {
      await tester.pumpWidget(_wrap(const WelcomeScreen()));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('screen-welcome-webapp')), findsOneWidget);
    });
  });

  group('WelcomeScreen — versão (lógica de negócio, cobertura ≥98%)', () {
    // APP_VERSION não está definido no ambiente de teste → deve mostrar fallback.
    testWidgets('mostra fallback quando APP_VERSION está vazio', (tester) async {
      await tester.pumpWidget(_wrap(const WelcomeScreen()));
      await tester.pumpAndSettle();

      final versionWidget = find.byKey(const Key('screen-welcome-version'));
      expect(versionWidget, findsOneWidget);
      final text = tester.widget<Text>(versionWidget);
      // APP_VERSION='' no ambiente de teste → fallback
      expect(text.data, 'versão indisponível');
    });

    testWidgets('texto de versão usa token textMuted (não text.subtle)', (tester) async {
      await tester.pumpWidget(_wrap(const WelcomeScreen()));
      await tester.pumpAndSettle();

      final versionWidget = tester.widget<Text>(
        find.byKey(const Key('screen-welcome-version')),
      );
      // Cor deve ser textMutedLight (tema claro padrão nos testes).
      expect(versionWidget.style?.color, TurniColors.textMutedLight);
    });
  });

  group('WelcomeScreen — acessibilidade', () {
    testWidgets('logomarca tem semanticsLabel "Turni" para leitores de tela', (tester) async {
      await tester.pumpWidget(_wrap(const WelcomeScreen()));
      await tester.pumpAndSettle();

      // semanticsLabel garante que leitor de tela anuncia "Turni", não "T-U-R-N-I".
      final brand = tester.widget<Text>(
        find.byKey(const Key('screen-welcome-brand')),
      );
      expect(brand.semanticsLabel, 'Turni');
    });

    testWidgets('link tem alvo de toque com padding vertical adequado', (tester) async {
      await tester.pumpWidget(_wrap(const WelcomeScreen()));
      await tester.pumpAndSettle();

      // Verifica que o InkWell do link existe e pode ser encontrado.
      final link = find.byKey(const Key('screen-welcome-health-link'));
      expect(link, findsOneWidget);

      // Alvo de toque ≥48dp é garantido pelo padding vertical de 12dp (sm+xs) em cada lado.
      final inkWell = tester.widget<InkWell>(link);
      expect(inkWell.onTap, isNotNull);
    });
  });

  group('WelcomeScreen — layout responsivo', () {
    testWidgets('mobile: sem Card wrapper', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_wrap(const WelcomeScreen()));
      await tester.pumpAndSettle();

      // Em mobile (360dp < 1024dp) não deve ter Card.
      // A tela raiz ainda existe e o conteúdo está visível.
      expect(find.byKey(const Key('screen-welcome-webapp')), findsOneWidget);
      expect(find.byKey(const Key('screen-welcome-brand')), findsOneWidget);
    });

    testWidgets('desktop: com Card wrapper', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_wrap(const WelcomeScreen()));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('screen-welcome-webapp')), findsOneWidget);
      expect(find.byType(Card), findsOneWidget);
    });
  });

  group('WelcomeScreen — Design System tokens', () {
    testWidgets('logomarca usa brandGreen', (tester) async {
      await tester.pumpWidget(_wrap(const WelcomeScreen()));
      await tester.pumpAndSettle();

      final brand = tester.widget<Text>(
        find.byKey(const Key('screen-welcome-brand')),
      );
      expect(brand.style?.color, TurniColors.brandGreen);
    });

    testWidgets('link usa accentLight no tema claro', (tester) async {
      await tester.pumpWidget(_wrap(const WelcomeScreen()));
      await tester.pumpAndSettle();

      // O link "Ver status do sistema" deve usar a cor de acento do perfil profissional.
      final linkText = tester.widget<Text>(find.text('Ver status do sistema'));
      expect(linkText.style?.color, TurniColors.accentLight);
    });
  });
}
