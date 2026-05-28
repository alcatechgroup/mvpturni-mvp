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

  // Superfícies — tema claro (DDR-001 §3.1).
  static const surfacePageLight = Color(0xFFF7F4EC);
  static const surfaceLight = Color(0xFFFFFFFF);
  static const borderSubtleLight = Color(0xFFE0DDD3);

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
}
