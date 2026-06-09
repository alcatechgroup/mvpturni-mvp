import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turni_webapp/ds/theme.dart';

// STORY-080 — gate automatizado de acessibilidade (CA-1, CA-3, CA-5).
//
// Decisão (IDR-022): o WebApp é Flutter web *canvas-rendered* (CanvasKit), então
// axe/lighthouse enxergam um <canvas> quase vazio e dariam falso-verde. Os matchers
// nativos do Flutter `meetsGuideline` operam sobre a árvore de Semântica que o Flutter
// exporta — exatamente o que vira ARIA no DOM — e rodam em `flutter test` sem browser
// nem banco. Cobrem:
//   - textContrastGuideline      → WCAG AA (4.5:1 normal / 3:1 grande)        [CA-1]
//   - androidTapTargetGuideline  → alvo de toque ≥ 48dp                        [CA-3]
//   - labeledTapTargetGuideline  → todo alvo de toque tem label acessível      [CA-3]
//
// Como usar numa tela autenticada já montada pelo seu harness de teste:
//
//   await pumpA11y(tester, (theme) => MaterialApp(theme: theme, home: ...));
//   await expectScreenMeetsA11y(tester);
//
// `expectScreenMeetsA11y` roda os 3 guidelines. Para rodar nos dois temas, use
// `forEachTheme` ou chame `pumpA11y` com `dark: true`.

/// Constrói o widget sob teste com o tema do DS (claro por padrão, escuro se [dark]).
/// O [builder] recebe o `ThemeData` já pronto e devolve a árvore (normalmente um
/// `MaterialApp`/`MaterialApp.router`).
Future<void> pumpA11y(
  WidgetTester tester,
  Widget Function(ThemeData theme) builder, {
  bool dark = false,
  Size surfaceSize = const Size(1280, 900),
}) async {
  await tester.binding.setSurfaceSize(surfaceSize);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final theme = dark ? buildDarkTheme() : buildLightTheme();
  await tester.pumpWidget(builder(theme));
  await tester.pumpAndSettle();
}

/// Roda os três guidelines de a11y sobre a árvore atualmente montada.
/// Liga a semântica antes e desliga depois (exigência dos matchers).
Future<void> expectScreenMeetsA11y(WidgetTester tester) async {
  final handle = tester.ensureSemantics();
  await expectLater(tester, meetsGuideline(textContrastGuideline));
  await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  handle.dispose();
}
