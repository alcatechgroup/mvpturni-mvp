import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../ds/tokens.dart';
import '../auth/auth_service.dart';

/// Shell do app para usuários ativo (status=ativo).
/// Placeholder — telas reais vêm em STORY-017/018/022/023/024.
class AppShellScreen extends StatelessWidget {
  const AppShellScreen({super.key});

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
    final session = AuthService().session;

    return Scaffold(
      backgroundColor: surfacePage,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(TurniSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
              const SizedBox(height: TurniSpacing.lg),
              Text(
                'Bem-vindo, ${session?.role ?? 'usuário'}.',
                style: TextStyle(fontSize: 18, color: textMuted),
              ),
              Text(
                'O aplicativo completo chega nas próximas estórias.',
                style: TextStyle(fontSize: 14, color: textMuted),
              ),
              const SizedBox(height: TurniSpacing.xl),
              OutlinedButton(
                onPressed: () => _logout(context),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: accent),
                  foregroundColor: accent,
                  shape: const StadiumBorder(),
                ),
                child: const Text('Sair'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
