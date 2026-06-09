import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turni_webapp/ds/components/rating_input.dart';
import 'package:turni_webapp/ds/theme.dart';

// STORY-087 — input.rating (SCREEN-084 §3/§5/§6): estrelas obrigatórias 1–5, helper
// textual que duplica a informação da cor (não só cor — AA), estado de erro associado.

Widget _host(Widget child) => MaterialApp(
  theme: buildLightTheme(),
  home: Scaffold(body: child),
);

void main() {
  group('TurniRatingInput', () {
    // (a) feliz — tocar uma estrela emite o valor escolhido.
    testWidgets('tocar a 4ª estrela emite onChanged(4)', (tester) async {
      int? escolhido;
      await tester.pumpWidget(
        _host(
          TurniRatingInput(
            value: 0,
            accent: const Color(0xFF2D5F3F),
            onChanged: (v) => escolhido = v,
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('avaliacao-estrela-4')));
      await tester.pumpAndSettle();

      expect(escolhido, 4);
    });

    // (a) feliz — o helper traduz o valor em palavra (§5), duplicando a cor.
    testWidgets('helper vira a palavra do valor escolhido', (tester) async {
      await tester.pumpWidget(
        _host(
          TurniRatingInput(
            value: 5,
            accent: const Color(0xFF2D5F3F),
            onChanged: (_) {},
          ),
        ),
      );

      expect(find.text('Ótimo'), findsOneWidget);
    });

    testWidgets('cada valor 1–5 mostra a palavra certa', (tester) async {
      const palavras = {
        1: 'Ruim',
        2: 'Regular',
        3: 'Bom',
        4: 'Muito bom',
        5: 'Ótimo',
      };
      for (final entry in palavras.entries) {
        await tester.pumpWidget(
          _host(
            TurniRatingInput(
              value: entry.key,
              accent: const Color(0xFF2D5F3F),
              onChanged: (_) {},
            ),
          ),
        );
        expect(
          find.text(entry.value),
          findsOneWidget,
          reason: '${entry.key}★ deveria mostrar "${entry.value}"',
        );
      }
    });

    // (b) borda — valor 0 (vazio): helper de convite, nenhuma estrela preenchida.
    testWidgets('valor 0 mostra "Toque para avaliar" e 0 estrelas cheias', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          TurniRatingInput(
            value: 0,
            accent: const Color(0xFF2D5F3F),
            onChanged: (_) {},
          ),
        ),
      );

      expect(find.text('Toque para avaliar'), findsOneWidget);
      expect(find.byIcon(Icons.star_rounded), findsNothing);
      expect(find.byIcon(Icons.star_border_rounded), findsNWidgets(5));
    });

    // (d) borda — a contagem de estrelas cheias/vazias casa com o valor (ícone, não só cor).
    testWidgets('valor 3 → 3 cheias + 2 vazias (ícone distingue, não só cor)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          TurniRatingInput(
            value: 3,
            accent: const Color(0xFF2D5F3F),
            onChanged: (_) {},
          ),
        ),
      );

      expect(find.byIcon(Icons.star_rounded), findsNWidgets(3));
      expect(find.byIcon(Icons.star_border_rounded), findsNWidgets(2));
    });

    // (b) inválido — estado de erro: a mensagem associada substitui o helper.
    testWidgets('errorText substitui o helper e expõe a key de erro', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          TurniRatingInput(
            value: 0,
            accent: const Color(0xFF2D5F3F),
            onChanged: (_) {},
            errorText: 'Escolha de 1 a 5 estrelas.',
          ),
        ),
      );

      expect(find.byKey(const Key('avaliacao-estrelas-erro')), findsOneWidget);
      expect(find.text('Escolha de 1 a 5 estrelas.'), findsOneWidget);
      expect(find.text('Toque para avaliar'), findsNothing);
    });

    // (c)/a11y — o grupo é alcançável pela key estável e anuncia o valor.
    testWidgets('grupo tem a key estável avaliacao-estrelas', (tester) async {
      await tester.pumpWidget(
        _host(
          TurniRatingInput(
            value: 2,
            accent: const Color(0xFF2D5F3F),
            onChanged: (_) {},
          ),
        ),
      );

      expect(find.byKey(const Key('avaliacao-estrelas')), findsOneWidget);
    });
  });
}
