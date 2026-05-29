import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../ds/tokens.dart';
import '../auth/auth_service.dart';

/// Placeholder da tela de welcome (CA-11 — SCREEN-STORY-016 Tela C).
/// Destino do funnel guard para status=liberado, welcome_seen_at=null.
/// Tela real vem em STORY-022.
class WelcomePlaceholderScreen extends StatefulWidget {
  const WelcomePlaceholderScreen({super.key});

  @override
  State<WelcomePlaceholderScreen> createState() =>
      _WelcomePlaceholderScreenState();
}

class _WelcomePlaceholderScreenState extends State<WelcomePlaceholderScreen> {
  bool get _isAtivo => AuthService().session?.status == 'ativo';

  Future<void> _logout() async {
    await AuthService().logout();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? TurniColors.accentDark : TurniColors.accentLight;
    final surfacePage = isDark
        ? TurniColors.surfacePageDark
        : TurniColors.surfacePageLight;
    final textMuted = isDark
        ? TurniColors.textMutedDark
        : TurniColors.textMutedLight;

    return Scaffold(
      key: const Key('screen-placeholder-welcome'),
      backgroundColor: surfacePage,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(TurniSpacing.lg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'TURNI.',
                  semanticsLabel: 'Turni',
                  style: TextStyle(
                    fontFamily: 'BebasNeue',
                    fontSize: 48,
                    fontWeight: FontWeight.w400,
                    color: TurniColors.brandGreen,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: TurniSpacing.xl),
                Text(
                  'A tela de boas-vindas chega em breve.',
                  style: TextStyle(fontSize: 16, color: textMuted),
                ),
                if (_isAtivo) ...[
                  const SizedBox(height: TurniSpacing.md),
                  Container(
                    key: const Key('banner-already-active'),
                    padding: const EdgeInsets.all(TurniSpacing.md),
                    decoration: BoxDecoration(
                      color: TurniColors.infoSoftLight,
                      border: Border.all(
                        color: TurniColors.infoLight.withAlpha(128),
                      ),
                      borderRadius: BorderRadius.all(TurniRadius.md),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          size: 16,
                          color: TurniColors.infoLight,
                        ),
                        const SizedBox(width: TurniSpacing.sm),
                        Expanded(
                          child: Text(
                            'Você já completou o cadastro.',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        TextButton(
                          onPressed: () => context.go('/'),
                          child: const Text('Continuar'),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: TurniSpacing.xl),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton(
                    key: const Key('btn-logout'),
                    onPressed: _logout,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: accent),
                      foregroundColor: accent,
                      shape: const StadiumBorder(),
                    ),
                    child: const Text('Sair'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
