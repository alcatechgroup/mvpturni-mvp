import 'package:flutter/material.dart';

import 'theme_mode_controller.dart';

/// Botão de alternância claro↔escuro para as telas públicas (login, cadastro).
/// Mesma fonte de verdade do Perfil/shell ([ThemeModeController]) — a escolha
/// vale já no pré-login e persiste após o usuário entrar. DDR-001 §1: o acento
/// segue neutro; só o claro/escuro é alternável.
///
/// Passe uma [key] para identificar o botão em testes (ex.: `login:theme-toggle`).
class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = ThemeModeController.instance;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final platform = MediaQuery.platformBrightnessOf(context);
        final dark = controller.isDark(platform);
        return IconButton(
          tooltip: dark ? 'Tema claro' : 'Tema escuro',
          icon: Icon(
            dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
          ),
          onPressed: () => controller.setDark(!dark),
        );
      },
    );
  }
}
