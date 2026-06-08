import 'package:flutter/material.dart';

import '../../../ds/tokens.dart';

/// Cores de chrome do shell de navegação por perfil (DDR-001 §2.2 / DDR-003 / CA-4).
///
/// A superfície de navegação (NavigationBar / NavigationRail / sidebar) é pintada
/// com o chrome do papel autenticado — verde-sage do profissional, mostarda do
/// contratante — e é **escura nos dois temas**: por isso [ShellChrome] não depende
/// do [Brightness]. É a assinatura visual do produto.
///
/// Fail-secure (ADR-007): papel desconhecido/nulo cai no chrome neutro do
/// profissional, nunca na identidade do contratante por engano.
@immutable
class ShellChrome {
  const ShellChrome({
    required this.surface,
    required this.accent,
    required this.accentSoft,
    required this.on,
    required this.onMuted,
    required this.line,
  });

  /// Fundo da superfície de navegação (sidebar/rail/bar).
  final Color surface;

  /// Acento do item ativo (ícone + rótulo) sobre o chrome escuro.
  final Color accent;

  /// Pílula do indicador ativo (acento com baixa opacidade).
  final Color accentSoft;

  /// Cor do rótulo/ícone do item ativo e da marca.
  final Color on;

  /// Cor do rótulo/ícone dos itens inativos (mais apagada).
  final Color onMuted;

  /// Divisórias finas sobre o chrome.
  final Color line;

  static ShellChrome forRole(String? role) {
    final isContratante = role == 'contratante';
    final accent = isContratante
        ? TurniColors.contratanteAccentDark
        : TurniColors.accentDark;
    return ShellChrome(
      surface: isContratante
          ? TurniColors.chromeContratante
          : TurniColors.chromeProfissional,
      accent: accent,
      // Pílula do ativo: protótipo usa ~.20 (contratante) / ~.18 (profissional).
      accentSoft: accent.withValues(alpha: isContratante ? 0.20 : 0.18),
      on: TurniColors.chromeOn,
      onMuted: TurniColors.chromeOnMuted,
      line: TurniColors.chromeLine,
    );
  }
}
