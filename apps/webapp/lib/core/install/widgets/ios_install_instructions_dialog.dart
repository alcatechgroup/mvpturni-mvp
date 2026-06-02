import 'package:flutter/material.dart';

import '../../../ds/tokens.dart';

/// Modal de instruções de instalação no iOS (STORY-042 / IDR-020 §3).
///
/// O WebKit não implementa `beforeinstallprompt`, então no iOS a instalação é um
/// gesto manual. Este modal mostra os 2 passos com ícones Material. Microcopy fixa
/// por IDR-020. Tokens DDR-001; cada passo tem `Semantics(label:)`.
class IosInstallInstructionsDialog extends StatelessWidget {
  const IosInstallInstructionsDialog({super.key, required this.onClose});

  final VoidCallback onClose;

  static const _step1 = 'Toque no botão Compartilhar na barra do navegador.';
  static const _step2 = 'Role e toque em Adicionar à Tela de Início.';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? TurniColors.accentDark : TurniColors.accentLight;
    final onAccent = isDark
        ? TurniColors.onAccentDark
        : TurniColors.onAccentLight;
    final surface = isDark ? TurniColors.surfaceDark : TurniColors.surfaceLight;
    final textStrong = isDark
        ? TurniColors.textStrongDark
        : TurniColors.textStrongLight;

    return Dialog(
      key: const Key('ios-install-dialog'),
      backgroundColor: surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(TurniRadius.lg),
      ),
      child: Padding(
        padding: const EdgeInsets.all(TurniSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Instalar na tela inicial',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: textStrong,
              ),
            ),
            const SizedBox(height: TurniSpacing.lg),
            _Step(
              icon: Icons.ios_share,
              number: '1',
              text: _step1,
              accent: accent,
              textStrong: textStrong,
            ),
            const SizedBox(height: TurniSpacing.md),
            _Step(
              icon: Icons.add_to_home_screen,
              number: '2',
              text: _step2,
              accent: accent,
              textStrong: textStrong,
            ),
            const SizedBox(height: TurniSpacing.lg),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                key: const Key('btn-ios-understood'),
                onPressed: onClose,
                style: FilledButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: onAccent,
                  shape: const StadiumBorder(),
                ),
                child: const Text('Entendi'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.icon,
    required this.number,
    required this.text,
    required this.accent,
    required this.textStrong,
  });

  final IconData icon;
  final String number;
  final String text;
  final Color accent;
  final Color textStrong;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Passo $number: $text',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 24, color: accent),
          const SizedBox(width: TurniSpacing.sm),
          Expanded(
            child: Text(
              '$number. $text',
              style: TextStyle(fontSize: 15, color: textStrong),
            ),
          ),
        ],
      ),
    );
  }
}
