import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turni_webapp/ds/components/reputacao_views.dart';
import 'package:turni_webapp/ds/tokens.dart';

// STORY-088 — componentes de reputação do DS (SCREEN-084 §3/§5/§6 / DDR-004).
// display.rating, badge.nivel, meter.xp, card.depoimento. Cada um exercitado nos
// estados visíveis (score/selo Novo, níveis, nível máximo, nominal/anônimo) + a11y.

const _accent = TurniColors.accentLight;

Future<void> _pump(WidgetTester tester, Widget child) {
  return tester.pumpWidget(
    MaterialApp(home: Scaffold(body: Center(child: child))),
  );
}

void main() {
  group('TurniRatingDisplay (display.rating)', () {
    testWidgets('score ≥3: mostra média 1-casa + contagem, sem selo', (
      tester,
    ) async {
      await _pump(
        tester,
        const TurniRatingDisplay(
          score: 4.9,
          totalAvaliacoes: 27,
          seloNovo: false,
          accent: _accent,
        ),
      );

      expect(find.text('4.9'), findsOneWidget);
      expect(find.text('27 avaliações'), findsOneWidget);
      expect(find.textContaining('Novo'), findsNothing);
    });

    testWidgets('selo "Novo na plataforma" quando 0 avaliações', (tester) async {
      await _pump(
        tester,
        const TurniRatingDisplay(
          score: 0,
          totalAvaliacoes: 0,
          seloNovo: true,
          accent: _accent,
        ),
      );

      expect(find.text('Novo na plataforma'), findsOneWidget);
    });

    testWidgets('selo "Novo · 1 avaliação" (singular) e "· 2 avaliações"', (
      tester,
    ) async {
      await _pump(
        tester,
        const TurniRatingDisplay(
          score: 5,
          totalAvaliacoes: 1,
          seloNovo: true,
          accent: _accent,
        ),
      );
      expect(find.text('Novo · 1 avaliação'), findsOneWidget);

      await _pump(
        tester,
        const TurniRatingDisplay(
          score: 5,
          totalAvaliacoes: 2,
          seloNovo: true,
          accent: _accent,
        ),
      );
      expect(find.text('Novo · 2 avaliações'), findsOneWidget);
    });

    testWidgets('semântica anuncia o número (vírgula pt-BR), estrelas mudas', (
      tester,
    ) async {
      await _pump(
        tester,
        const TurniRatingDisplay(
          score: 4.9,
          totalAvaliacoes: 27,
          seloNovo: false,
          accent: _accent,
        ),
      );
      // Nó semântico com o número falado (não depende da cor da estrela).
      expect(
        find.bySemanticsLabel(RegExp('4,9 de 5')),
        findsOneWidget,
      );
    });
  });

  group('TurniNivelBadge (badge.nivel)', () {
    testWidgets('"Confiavel" (enum) exibe rótulo acentuado "Confiável"', (
      tester,
    ) async {
      await _pump(tester, const TurniNivelBadge(nivel: 'Confiavel'));
      expect(find.text('Confiável'), findsOneWidget);
    });

    testWidgets('rótulos dos demais níveis', (tester) async {
      for (final par in const [
        ['Iniciante', 'Iniciante'],
        ['Destaque', 'Destaque'],
        ['Elite', 'Elite'],
      ]) {
        await _pump(tester, TurniNivelBadge(nivel: par[0]));
        expect(find.text(par[1]), findsOneWidget);
      }
    });

    testWidgets('badge tem TEXTO (não só ícone) — a11y', (tester) async {
      await _pump(tester, const TurniNivelBadge(nivel: 'Elite'));
      expect(find.byType(Text), findsWidgets);
    });
  });

  group('TurniXpMeter (meter.xp)', () {
    testWidgets('nível intermediário: "Faltam k XP para {próximo}" + k/total', (
      tester,
    ) async {
      await _pump(
        tester,
        const TurniXpMeter(
          xp: 680,
          xpProximoNivel: 320,
          nivel: 'Confiavel',
          accent: _accent,
        ),
      );
      expect(find.text('Faltam 320 XP para Destaque'), findsOneWidget);
      expect(find.textContaining('680/1000'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('nível máximo (xpProximoNivel null) → "Nível máximo alcançado"', (
      tester,
    ) async {
      await _pump(
        tester,
        const TurniXpMeter(
          xp: 3200,
          xpProximoNivel: null,
          nivel: 'Elite',
          accent: _accent,
        ),
      );
      expect(find.text('Nível máximo alcançado'), findsOneWidget);
      expect(find.textContaining('Faltam'), findsNothing);
    });

    testWidgets('barra tem valor semântico (LinearProgressIndicator.value)', (
      tester,
    ) async {
      await _pump(
        tester,
        const TurniXpMeter(
          xp: 680,
          xpProximoNivel: 320,
          nivel: 'Confiavel',
          accent: _accent,
        ),
      );
      final bar = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(bar.value, closeTo(0.68, 0.001)); // 680 / 1000
    });
  });

  group('TurniDepoimentoCard (card.depoimento)', () {
    Widget card({
      String? autorNome,
      String? funcao = 'Garçom',
      int estrelas = 5,
    }) => TurniDepoimentoCard(
      estrelas: estrelas,
      comentario: 'Pontual e atencioso',
      autorNome: autorNome,
      funcao: funcao,
      data: DateTime.now().subtract(const Duration(days: 3)),
      accent: _accent,
    );

    testWidgets('nominal: estabelecimento · função · data relativa', (
      tester,
    ) async {
      await _pump(tester, card(autorNome: 'Restaurante Vista Mar'));
      expect(find.text('Pontual e atencioso'), findsOneWidget);
      expect(
        find.textContaining('Restaurante Vista Mar'),
        findsOneWidget,
      );
      expect(find.textContaining('Garçom'), findsOneWidget);
      expect(find.textContaining('há 3 dias'), findsOneWidget);
    });

    testWidgets('anônimo (autorNome null): "Profissional", sem nome vazado', (
      tester,
    ) async {
      await _pump(tester, card(autorNome: null));
      expect(find.textContaining('Profissional'), findsOneWidget);
      expect(find.textContaining('Garçom'), findsOneWidget);
    });

    testWidgets('função ausente não quebra (omite o segmento)', (tester) async {
      await _pump(tester, card(autorNome: 'Bar do Porto', funcao: null));
      expect(find.text('Pontual e atencioso'), findsOneWidget);
      expect(find.textContaining('Bar do Porto'), findsOneWidget);
    });
  });
}
