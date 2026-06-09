import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// STORY-080 — seam de tipografia do DS.
//
// Em produção usamos Google Fonts: Inter no corpo (via tema) e JetBrains Mono nos
// dígitos de PIN/cronômetro. Em teste, `useSystemFontsForTests` é ligado pelo
// `test/flutter_test_config.dart` (toda a suíte). Motivo: Google Fonts busca o .ttf
// em runtime (rede) e — pior para o nosso caso — o gate de a11y
// (`textContrastGuideline`) rasteriza o texto dentro de `runAsync`, o que força o
// fetch pendente a estourar quando não há rede (CI, sandbox). A família da fonte
// não altera o contraste WCAG (que depende de cor + tamanho), então em teste caímos
// na fonte padrão. Bônus: a suíte inteira passa a rodar offline/determinística.
bool useSystemFontsForTests = false;

/// Text theme do corpo — Inter em produção, fonte padrão em teste.
TextTheme dsTextTheme(TextTheme base) =>
    useSystemFontsForTests ? base : GoogleFonts.interTextTheme(base);

/// Estilo monoespaçado para dígitos (PIN, cronômetro) — JetBrains Mono em
/// produção, monospace padrão em teste.
TextStyle dsMono({
  double? fontSize,
  FontWeight? fontWeight,
  Color? color,
  double? letterSpacing,
  double? height,
  List<FontFeature>? fontFeatures,
}) {
  if (useSystemFontsForTests) {
    return TextStyle(
      fontFamily: 'monospace',
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
      fontFeatures: fontFeatures,
    );
  }
  return GoogleFonts.jetBrainsMono(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    letterSpacing: letterSpacing,
    height: height,
    fontFeatures: fontFeatures,
  );
}
