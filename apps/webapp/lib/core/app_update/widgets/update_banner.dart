import 'package:flutter/material.dart';

import '../../../ds/tokens.dart';
import '../app_update_controller.dart';

/// Injeta o [UpdateBanner] no topo de qualquer rota, escutando o
/// [AppUpdateController]. Plugado uma única vez no `MaterialApp.builder`
/// (STORY-037 CA-4) — o banner aparece em login, cadastro, área logada, welcome.
///
/// Não-bloqueante: ocupa só a faixa superior; o conteúdo abaixo segue interativo.
class UpdateBannerHost extends StatelessWidget {
  const UpdateBannerHost({
    super.key,
    required this.controller,
    required this.child,
  });

  final AppUpdateController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: ListenableBuilder(
              listenable: controller,
              builder: (context, _) {
                if (!controller.showBanner) return const SizedBox.shrink();
                return UpdateBanner(
                  onUpdateNow: controller.applyUpdate,
                  onLater: controller.dismiss,
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// Banner não-bloqueante "Nova versão disponível" (STORY-037 CA-4).
/// Microcopy fixo aprovado pelo PO. Tokens DDR-001; `Semantics` como status para
/// leitor de tela (não-modal).
class UpdateBanner extends StatelessWidget {
  const UpdateBanner({
    super.key,
    required this.onUpdateNow,
    required this.onLater,
  });

  final VoidCallback onUpdateNow;
  final VoidCallback onLater;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? TurniColors.accentDark : TurniColors.accentLight;
    final onAccent = isDark
        ? TurniColors.onAccentDark
        : TurniColors.onAccentLight;
    // surfaceRaised: superfície elevada do DS (cartão sobre a página).
    final surfaceRaised = isDark
        ? TurniColors.surfaceDark
        : TurniColors.surfaceLight;
    final textStrong = isDark
        ? TurniColors.textStrongDark
        : TurniColors.textStrongLight;
    final border = isDark
        ? TurniColors.borderSubtleDark
        : TurniColors.borderSubtleLight;

    return Semantics(
      liveRegion: true,
      container: true,
      label: 'Status: Nova versão disponível',
      child: Padding(
        padding: const EdgeInsets.all(TurniSpacing.sm),
        child: Material(
          color: surfaceRaised,
          elevation: 3,
          borderRadius: const BorderRadius.all(TurniRadius.md),
          child: Container(
            key: const Key('update-banner'),
            padding: const EdgeInsets.symmetric(
              horizontal: TurniSpacing.md,
              vertical: TurniSpacing.sm + TurniSpacing.xs,
            ),
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.all(TurniRadius.md),
              border: Border.all(color: border),
            ),
            child: Row(
              children: [
                Icon(Icons.system_update_alt, size: 20, color: accent),
                const SizedBox(width: TurniSpacing.sm),
                Expanded(
                  child: Text(
                    'Nova versão disponível',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: textStrong,
                    ),
                  ),
                ),
                const SizedBox(width: TurniSpacing.xs),
                TextButton(
                  key: const Key('btn-update-later'),
                  onPressed: onLater,
                  style: TextButton.styleFrom(foregroundColor: textStrong),
                  child: const Text('Depois'),
                ),
                const SizedBox(width: TurniSpacing.xs),
                FilledButton(
                  key: const Key('btn-update-now'),
                  onPressed: onUpdateNow,
                  style: FilledButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: onAccent,
                    shape: const StadiumBorder(),
                  ),
                  child: const Text('Atualizar agora'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
