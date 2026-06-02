import 'package:flutter/material.dart';

import '../../../ds/tokens.dart';

/// Card discreto "Instalar app na tela inicial" (STORY-042 / IDR-020 §3).
///
/// Microcopy fixa aprovada por IDR-020. CTA primário muda conforme a plataforma:
/// "Instalar" (Android/Chromium, dispara o prompt nativo) / "Como instalar" (iOS,
/// abre o modal de instruções). Tokens DDR-001; `Semantics(button:true)` no CTA.
/// Fica acima da `AppVersionLabel` no rodapé das telas onde é plugado.
class InstallActionCard extends StatelessWidget {
  const InstallActionCard({
    super.key,
    required this.isIOS,
    required this.onInstall,
    required this.onDismiss,
  });

  final bool isIOS;
  final VoidCallback onInstall;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? TurniColors.accentDark : TurniColors.accentLight;
    final onAccent = isDark
        ? TurniColors.onAccentDark
        : TurniColors.onAccentLight;
    final surfaceRaised = isDark
        ? TurniColors.surfaceDark
        : TurniColors.surfaceLight;
    final textStrong = isDark
        ? TurniColors.textStrongDark
        : TurniColors.textStrongLight;
    final textMuted = isDark
        ? TurniColors.textMutedDark
        : TurniColors.textMutedLight;
    final border = isDark
        ? TurniColors.borderSubtleDark
        : TurniColors.borderSubtleLight;

    final ctaLabel = isIOS ? 'Como instalar' : 'Instalar';

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: TurniSpacing.md,
        vertical: TurniSpacing.sm,
      ),
      child: Material(
        color: surfaceRaised,
        elevation: 1,
        borderRadius: const BorderRadius.all(TurniRadius.md),
        child: Container(
          padding: const EdgeInsets.all(TurniSpacing.md),
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.all(TurniRadius.md),
            border: Border.all(color: border),
          ),
          // Empilhado: o texto ocupa a largura toda (não fica espremido entre os
          // botões em telas estreitas de celular); os botões vêm abaixo, à direita.
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Icons.add_to_home_screen, size: 22, color: accent),
                  const SizedBox(width: TurniSpacing.sm),
                  Expanded(
                    child: Semantics(
                      button: true,
                      container: true,
                      label: 'Instalar app na tela inicial',
                      child: ExcludeSemantics(
                        child: Text(
                          'Instalar app na tela inicial',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: textStrong,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: TurniSpacing.sm),
              // Wrap (não Row) para os botões quebrarem para a linha de baixo em
              // telas muito estreitas, sem overflow.
              Wrap(
                alignment: WrapAlignment.end,
                spacing: TurniSpacing.xs,
                runSpacing: TurniSpacing.xs,
                children: [
                  TextButton(
                    key: const Key('btn-install-dismiss'),
                    onPressed: onDismiss,
                    style: TextButton.styleFrom(foregroundColor: textMuted),
                    child: const Text('Agora não'),
                  ),
                  FilledButton(
                    key: const Key('btn-install-cta'),
                    onPressed: onInstall,
                    style: FilledButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: onAccent,
                      shape: const StadiumBorder(),
                    ),
                    child: Text(ctaLabel),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
