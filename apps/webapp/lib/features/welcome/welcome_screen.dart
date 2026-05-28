import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../ds/tokens.dart';

// Versão injetada em tempo de build via --dart-define=APP_VERSION (IDR-002).
// Vazio em dev local (sem dart-define); CI injeta a tag vX.Y.Z-rc.N.
const _appVersion = String.fromEnvironment('APP_VERSION', defaultValue: '');

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark =
        MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isDesktop = screenWidth >= 1024;

    final accentColor =
        isDark ? TurniColors.accentDark : TurniColors.accentLight;
    final textMuted =
        isDark ? TurniColors.textMutedDark : TurniColors.textMutedLight;
    final borderColor =
        isDark ? TurniColors.borderSubtleDark : TurniColors.borderSubtleLight;
    final surfacePage =
        isDark ? TurniColors.surfacePageDark : TurniColors.surfacePageLight;

    final content = _WelcomeContent(
      accentColor: accentColor,
      textMuted: textMuted,
      borderColor: borderColor,
    );

    Widget body = Center(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: TurniSpacing.lg,
          vertical: isDesktop ? TurniSpacing.x3l : TurniSpacing.x2l,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: isDesktop
              ? Card(child: Padding(
                  padding: const EdgeInsets.all(TurniSpacing.x2l),
                  child: content,
                ))
              : content,
        ),
      ),
    );

    return Scaffold(
      key: const Key('screen-welcome-webapp'),
      backgroundColor: surfacePage,
      body: body,
    );
  }
}

class _WelcomeContent extends StatelessWidget {
  const _WelcomeContent({
    required this.accentColor,
    required this.textMuted,
    required this.borderColor,
  });

  final Color accentColor;
  final Color textMuted;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Logomarca — Bebas Neue, display 48px (DDR-001 §5.1, brand.logo).
        // semanticsLabel evita que o leitor anuncie "T-U-R-N-I" letra a letra.
        Text(
          'TURNI.',
          key: const Key('screen-welcome-brand'),
          semanticsLabel: 'Turni',
          style: const TextStyle(
            fontFamily: 'BebasNeue',
            package: null,
            fontSize: 48,
            fontWeight: FontWeight.w400,
            color: TurniColors.brandGreen,
            height: 1.0,
          ),
        ),
        const SizedBox(height: TurniSpacing.sm),
        // Subtítulo — subtitle (16px w500, text.muted).
        Text(
          'Hospitalidade on-demand',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: textMuted,
          ),
        ),
        const SizedBox(height: TurniSpacing.xs),
        // Pilares — body-sm (14px, text.muted).
        Text(
          'Match · PIN · Pix em 15 min',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: textMuted,
          ),
        ),
        const SizedBox(height: TurniSpacing.lg),
        Divider(color: borderColor, thickness: 1),
        const SizedBox(height: TurniSpacing.lg),
        // Link primário — alvo ≥48dp, cor accent com sublinhado/seta (DDR-001 §5.7 a11y).
        _HealthLink(accentColor: accentColor),
        const SizedBox(height: TurniSpacing.x2l),
        // Versão — body-sm (14px) em mobile (piso de texto essencial, DDR-001 §5.1.1).
        Text(
          _appVersion.isNotEmpty ? 'versão $_appVersion' : 'versão indisponível',
          key: const Key('screen-welcome-version'),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: textMuted,
          ),
        ),
      ],
    );
  }
}

class _HealthLink extends StatelessWidget {
  const _HealthLink({required this.accentColor});

  final Color accentColor;

  Future<void> _open() async {
    // Navega para /health no mesmo aba; Firebase Hosting serve health.json (CA-6).
    // webOnlyWindowName: '_self' garante mesma aba no Flutter Web.
    await launchUrl(
      Uri.parse('/health'),
      webOnlyWindowName: '_self',
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: const Key('screen-welcome-health-link'),
      onTap: _open,
      borderRadius: BorderRadius.all(TurniRadius.sm),
      // Padding garante alvo de toque ≥48dp (DDR-001 §5.7).
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: TurniSpacing.sm + TurniSpacing.xs,
          horizontal: TurniSpacing.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                'Ver status do sistema',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: accentColor,
                  decoration: TextDecoration.underline,
                  decorationColor: accentColor,
                ),
              ),
            ),
            const SizedBox(width: TurniSpacing.xs),
            Icon(Icons.arrow_forward, size: 16, color: accentColor),
          ],
        ),
      ),
    );
  }
}
