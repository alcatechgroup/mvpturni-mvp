import 'package:flutter/material.dart';

// DDR-001 — fundação do Design System (tokens imutáveis).
// Fonte de verdade: docs/project-state/decisions/ddr/DDR-001-fundacao-do-design-system.md
// Tokens são constantes; não use valores crus em widgets — consuma os tokens.

abstract final class TurniColors {
  // Marca — apenas logomarca (branco sobre esta cor = 3.1:1, reprova AA texto).
  static const brandGreen = Color(0xFF00A868);

  // Profissional — esquema pré-login (verde-sage, DDR-001 §2.2).
  static const accentLight = Color(0xFF2D5F3F); // link/CTA claro (7.4:1 AA ✅)
  static const accentDark = Color(0xFF5FA37C); // link/CTA escuro (5.6:1 AA ✅)
  static const onAccentLight = Color(0xFFFFFFFF);
  static const onAccentDark = Color(0xFF0F1411);
  static const accentHoverLight = Color(0xFF3A7050);

  // Contratante — esquema pré-login (mostarda, DDR-001 / tokens.md §6).
  // Claro: CTA usa accent (#9A6E25, on-accent branco = 4.5:1 ✅); texto/link usa
  // accent.ink (#6E4E12, 7.6:1 ✅). Escuro: accent (#D4A95C) serve a botão e texto
  // (on-accent #0F1411 = 8.3:1 ✅). O mostarda vibrante #B8842F é só chrome/realce
  // grande — texto branco sobre ele reprova AA, por isso não é cor de CTA.
  static const contratanteAccentLight = Color(
    0xFF9A6E25,
  ); // CTA claro (4.5:1 ✅)
  static const contratanteAccentInkLight = Color(
    0xFF6E4E12,
  ); // texto/link claro (7.6:1 ✅)
  static const contratanteAccentDark = Color(
    0xFFD4A95C,
  ); // CTA/link escuro (8.3:1 ✅)

  // Superfícies — tema claro (DDR-001 §3.1).
  static const surfacePageLight = Color(0xFFF7F4EC);
  static const surfaceLight = Color(0xFFFFFFFF);
  static const borderSubtleLight = Color(0xFFE0DDD3);
  static const borderStrongLight = Color(0xFFC8C5BB);

  // Texto — tema claro.
  static const textStrongLight = Color(0xFF0F1B2D); // 15.7:1 ✅
  static const textMutedLight = Color(0xFF42504A); // 7.7:1 ✅

  // Superfícies — tema escuro (DDR-001 §3.2).
  static const surfacePageDark = Color(0xFF0F1411);
  static const surfaceDark = Color(0xFF1A2018);
  static const borderSubtleDark = Color(0xFF2A322D);

  // Texto — tema escuro.
  static const textStrongDark = Color(0xFFECEDE5); // 15.8:1 ✅
  static const textMutedDark = Color(0xFFA8B2A8); // 8.5:1 ✅

  // Semânticas — erro (DDR-001 §4).
  static const errorLight = Color(0xFFB83A3A); // #FFF/error = 5.7:1 ✅
  static const errorSoftLight = Color(0xFFFBE2E2);
  static const errorDark = Color(0xFFD85A5A);
  static const errorSoftDark = Color(0x26D85A5A);

  // Semânticas — sucesso.
  static const successLight = Color(0xFF2D7A4F);
  static const successSoftLight = Color(0xFFE2F0E5);

  // Semânticas — informação.
  static const infoLight = Color(0xFF4A6FA5);
  static const infoSoftLight = Color(0xFFE0E9F5);

  // Semânticas — atenção.
  static const warnLight = Color(0xFF9A6E25);
  static const warnSoftLight = Color(0xFFFBEED1);
  static const warnDark = Color(0xFFD4A95C);
  static const warnSoftDark = Color(0x26D4A95C);
}

// Espaçamento — grade 8pt com meio-passo de 4pt (DDR-001 §5.2).
abstract final class TurniSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const x2l = 48.0;
  static const x3l = 64.0;
}

// Raio de borda (DDR-001 §5.3).
abstract final class TurniRadius {
  static const sm = Radius.circular(8);
  static const md = Radius.circular(12);
  static const lg = Radius.circular(16);
  static const xl = Radius.circular(24);
  static const full = Radius.circular(999);
}
