import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/theme_mode_controller.dart';
import '../../ds/tokens.dart';
import '../auth/auth_service.dart';
import '../notificacoes/notificacoes_painel.dart';
import '../notificacoes/notificacoes_sino.dart';

/// Destino "Perfil" do shell (DDR-003). Dá um lar visível ao chrome que hoje
/// vive espalhado: identidade do usuário, alternância de tema e Sair. **Não é
/// feature nova** — editar dados, score e depoimentos chegam em épicos futuros
/// (EPIC-004+); o destino já fica pronto para recebê-los.
class PerfilScreen extends StatelessWidget {
  const PerfilScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    await AuthService().logout();
    if (context.mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final session = AuthService().session;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? TurniColors.accentDark : TurniColors.accentLight;
    final textMuted =
        isDark ? TurniColors.textMutedDark : TurniColors.textMutedLight;

    final nome = session?.name.trim() ?? '';
    final papel = session?.role == 'contratante' ? 'Contratante' : 'Profissional';

    return Scaffold(
      key: const Key('perfil-screen'),
      appBar: AppBar(
        title: const Text('Perfil'),
        actions: const [NotificacoesSino()],
      ),
      endDrawer: const NotificacoesPainel(),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(TurniSpacing.lg),
          children: [
            // Identidade
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: accent.withValues(alpha: 0.16),
                  child: Text(
                    _initials(nome),
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w600,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(width: TurniSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (nome.isNotEmpty)
                        Text(
                          nome,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      Text(papel, style: TextStyle(color: textMuted)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: TurniSpacing.xl),

            // Preferências — alternância de tema
            Text(
              'Preferências',
              style: TextStyle(
                color: textMuted,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: TurniSpacing.sm),
            ListenableBuilder(
              listenable: ThemeModeController.instance,
              builder: (context, _) {
                final platform = MediaQuery.platformBrightnessOf(context);
                final dark = ThemeModeController.instance.isDark(platform);
                return SwitchListTile(
                  key: const Key('shell-theme-toggle'),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Tema escuro'),
                  subtitle: const Text('Acompanha o sistema por padrão'),
                  value: dark,
                  onChanged: (v) => ThemeModeController.instance.setDark(v),
                );
              },
            ),
            const Divider(height: TurniSpacing.xl),

            // Sair
            OutlinedButton.icon(
              key: const Key('perfil-logout'),
              onPressed: () => _logout(context),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: accent),
                foregroundColor: accent,
                minimumSize: const Size.fromHeight(48),
              ),
              icon: const Icon(Icons.logout),
              label: const Text('Sair da conta'),
            ),
            const SizedBox(height: TurniSpacing.lg),
            Text(
              'Hoje o Perfil reúne identidade, tema e Sair. Editar dados, score e '
              'depoimentos chegam em épicos futuros.',
              style: TextStyle(color: textMuted, fontSize: 12, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }
}
