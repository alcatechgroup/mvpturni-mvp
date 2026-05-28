import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../ds/tokens.dart';
import '../auth/auth_service.dart';

/// Placeholder da tela de completar cadastro (CA-11 — SCREEN-STORY-016 Tela D).
/// Destino do funnel guard para status=liberado, welcome_seen_at!=null, cadastro_completed_at=null.
/// Tela real vem em STORY-023/024.
class CompletarCadastroPlaceholderScreen extends StatelessWidget {
  const CompletarCadastroPlaceholderScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    await AuthService().logout();
    if (context.mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? TurniColors.accentDark : TurniColors.accentLight;
    final surfacePage = isDark ? TurniColors.surfacePageDark : TurniColors.surfacePageLight;
    final textMuted = isDark ? TurniColors.textMutedDark : TurniColors.textMutedLight;

    return Scaffold(
      key: const Key('screen-placeholder-completar-cadastro'),
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
                  'A tela para completar seu cadastro chega em breve.',
                  style: TextStyle(fontSize: 16, color: textMuted),
                ),
                const SizedBox(height: TurniSpacing.xl),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton(
                    key: const Key('btn-logout'),
                    onPressed: () => _logout(context),
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
