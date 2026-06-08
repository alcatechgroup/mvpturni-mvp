import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../auth/auth_service.dart';
import 'app_shell_view.dart';
import 'shell_destinations.dart';

/// Glue entre o `StatefulNavigationShell` (go_router) e o [AppShellView]
/// apresentacional. Lê o papel da sessão (ADR-007) para os destinos e o chrome,
/// e traduz toque em destino para `goBranch` — preservando o estado de cada aba
/// (IndexedStack) e empilhando drill-downs dentro do branch (DDR-003).
///
/// STORY-078: recebe a [location] corrente (`state.uri.path`) para decidir se a
/// barra superior do shell aparece (raiz de destino) ou não (drill-down). O
/// título vem do destino ativo (`currentIndex`), variando por papel.
class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.navigationShell,
    required this.location,
  });

  final StatefulNavigationShell navigationShell;
  final String location;

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
    final role = session?.role;
    // Barra do shell só nas raízes de destino; nos drill-downs o título é null
    // e a própria tela mostra a sua AppBar (voltar + título específico).
    final appBarTitle = isDestinationRoot(location)
        ? sectionTitleFor(role, navigationShell.currentIndex)
        : null;
    return AppShellView(
      role: role,
      userName: session?.name ?? '',
      currentIndex: navigationShell.currentIndex,
      appBarTitle: appBarTitle,
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
