import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turni_webapp/ds/theme.dart';

// STORY-080 — gate automatizado de acessibilidade (CA-1, CA-3, CA-5).
//
// Decisão (IDR-030): o WebApp é Flutter web *canvas-rendered* (CanvasKit), então
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
  // `physicalSize` + dpr=1.0 → a largura lógica é exatamente `surfaceSize.width`
  // (breakpoints do shell determinísticos). `setSurfaceSize` escala por dpr e
  // bagunça o breakpoint efetivo.
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = surfaceSize;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final theme = dark ? buildDarkTheme() : buildLightTheme();
  await tester.pumpWidget(builder(theme));
  await tester.pumpAndSettle();
}

/// Roda os três guidelines de a11y sobre a árvore atualmente montada.
/// Liga a semântica antes e desliga depois (exigência dos matchers).
///
/// [tapTargetGuideline] default = [androidTapTargetGuideline] (≥48dp), o piso de
/// toque do CA-3 para superfícies de toque (mobile, conteúdo das telas). Para a
/// **NavigationRail de desktop** passe [iOSTapTargetGuideline] (≥44dp): o destino
/// do rail Material fica em 44dp por padrão (não há knob de altura no widget) e
/// 44dp é aceito em WCAG 2.1 AA (accessibility-basics.md §7 "WCAG aceita ≥44";
/// 48dp é recomendação Material, não requisito AA). O rail é superfície de
/// mouse/tablet, não de toque primário.
Future<void> expectScreenMeetsA11y(
  WidgetTester tester, {
  AccessibilityGuideline? tapTargetGuideline,
}) async {
  final handle = tester.ensureSemantics();
  await expectLater(tester, meetsGuideline(textContrastGuideline));
  await expectLater(
    tester,
    meetsGuideline(tapTargetGuideline ?? androidTapTargetGuideline),
  );
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  handle.dispose();
}
