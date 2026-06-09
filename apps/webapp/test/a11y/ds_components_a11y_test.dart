import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turni_webapp/ds/components/state_views.dart';
import 'package:turni_webapp/ds/tokens.dart';

import 'a11y_harness.dart';

// STORY-080 — gate de a11y dos componentes do DS (CA-1 contraste, CA-3 alvo/label).
// Os estados padronizados (STORY-079) são consumidos por todas as listas; auditá-los
// uma vez cobre o contraste/alvo deles em todas as telas. Roda nos dois temas e nos
// dois acentos de perfil (profissional/sage e contratante/mostarda).

Widget _scaffold(Widget child) => Scaffold(body: child);

void main() {
  group('TurniEmptyState — gate a11y', () {
    for (final dark in [false, true]) {
      final tema = dark ? 'escuro' : 'claro';
      testWidgets('estado vazio com CTA — tema $tema', (tester) async {
        await pumpA11y(
          tester,
          (theme) => MaterialApp(
            theme: theme,
            home: _scaffold(
              TurniEmptyState(
                icon: Icons.work_outline,
                title: 'Você ainda não publicou vagas',
                message: 'Publique uma vaga para começar.',
                action: FilledButton(
                  onPressed: () {},
                  child: const Text('Publicar vaga'),
                ),
              ),
            ),
          ),
          dark: dark,
        );
        await expectScreenMeetsA11y(tester);
      });
    }
  });

  group('TurniRetryState — gate a11y', () {
    // null = primary (profissional); + mostarda do contratante por tema.
    final acentosPorTema = {
      false: <Color?>[null, TurniColors.contratanteAccentLight],
      true: <Color?>[null, TurniColors.contratanteAccentDark],
    };
    for (final dark in [false, true]) {
      final tema = dark ? 'escuro' : 'claro';
      for (final accent in acentosPorTema[dark]!) {
        final perfil = accent == null ? 'profissional' : 'contratante';
        testWidgets('erro recuperável — $perfil / tema $tema', (tester) async {
          await pumpA11y(
            tester,
            (theme) => MaterialApp(
              theme: theme,
              home: _scaffold(
                TurniRetryState(
                  title: 'Não foi possível carregar as vagas.',
                  onRetry: () {},
                  accent: accent,
                ),
              ),
            ),
            dark: dark,
          );
          await expectScreenMeetsA11y(tester);
        });
      }
    }
  });
}
