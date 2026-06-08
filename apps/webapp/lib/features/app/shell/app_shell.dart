import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../auth/auth_service.dart';
import 'app_shell_view.dart';

/// Glue entre o `StatefulNavigationShell` (go_router) e o [AppShellView]
/// apresentacional. Lê o papel da sessão (ADR-007) para os destinos e o chrome,
/// e traduz toque em destino para `goBranch` — preservando o estado de cada aba
/// (IndexedStack) e empilhando drill-downs dentro do branch (DDR-003).
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _goBranch(int index) {
    // Tocar o destino já ativo volta ao topo do branch (comportamento M3);
    // tocar outro restaura onde o usuário estava naquela aba.
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = AuthService().session;
    return AppShellView(
      role: session?.role,
      userName: session?.name ?? '',
      currentIndex: navigationShell.currentIndex,
      onDestinationSelected: _goBranch,
      onNovaVaga: () => context.go('/contratante/vagas/nova'),
      onLogout: () async {
        final router = GoRouter.of(context);
        await AuthService().logout();
        router.go('/login');
      },
      child: navigationShell,
    );
  }
}
