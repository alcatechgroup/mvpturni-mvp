import 'package:flutter/material.dart';

import '../../../ds/tokens.dart';
import 'shell_chrome.dart';
import 'shell_destinations.dart';

/// Camada apresentacional do shell adaptativo (DDR-003 / STORY-077).
///
/// Renderiza a superfície de navegação certa por breakpoint (DDR-001 §5.6):
/// `NavigationBar` (compact <600) → `NavigationRail` (medium/expanded 600–1199,
/// estendida ≥840) → sidebar persistente (large ≥1200), sempre pintada pelo
/// **chrome do perfil**. É puro (sem router): recebe o índice ativo e callbacks,
/// e embrulha o [child] (conteúdo do destino ativo). O glue com
/// `StatefulNavigationShell` fica no router.
///
/// Nesta estória o shell entrega só a navegação; as telas internas mantêm suas
/// próprias `AppBar`/sino (migração de cabeçalho é a STORY-078). "Nova vaga"
/// (contratante) aparece como ação no rail/sidebar; o FAB mobile global fica
/// para a STORY-078 (hoje `MinhasVagasScreen` já tem o seu — evita FAB duplo).
class AppShellView extends StatelessWidget {
  const AppShellView({
    super.key,
    required this.role,
    required this.currentIndex,
    required this.onDestinationSelected,
    required this.onNovaVaga,
    required this.onLogout,
    required this.child,
    this.userName = '',
  });

  final String? role;
  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;
  final VoidCallback onNovaVaga;
  final VoidCallback onLogout;
  final Widget child;
  final String userName;

  // Breakpoints DDR-001 §5.6.
  static const _bpMedium = 600.0;
  static const _bpExpanded = 840.0;
  static const _bpLarge = 1200.0;

  @override
  Widget build(BuildContext context) {
    final destinations = destinationsFor(role);
    final chrome = ShellChrome.forRole(role);

    // Mensageiro de SnackBar próprio do CONTEÚDO. Como o shell envolve as telas
    // numa Scaffold (para a barra/rail), a tela interna também é uma Scaffold —
    // Scaffold aninhada. Sem um mensageiro próprio aqui, os SnackBars das telas
    // (via ScaffoldMessenger.of) sobem para o mensageiro RAIZ e renderizam no
    // rodapé da JANELA, cobrindo a `bottomNavigationBar` de ação da tela interna
    // (ex.: o botão "Retirar" do detalhe da vaga vira intocável). Com o mensageiro
    // aqui, o SnackBar volta a renderizar acima da barra de ação da própria tela
    // (comportamento pré-shell). Migração de cabeçalho/ação é a STORY-078.
    final content = ScaffoldMessenger(child: child);

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        if (w < _bpMedium) {
          return _bottomLayout(destinations, chrome, content);
        }
        if (w < _bpLarge) {
          return _railLayout(
            destinations,
            chrome,
            content,
            extended: w >= _bpExpanded,
          );
        }
        return _drawerLayout(destinations, chrome, content);
      },
    );
  }

  // ── compact: NavigationBar inferior ──
  Widget _bottomLayout(
    List<ShellDestination> destinations,
    ShellChrome chrome,
    Widget content,
  ) {
    // M3 exige ≥2 destinos; sem destinos (fail-secure) o shell some, só o
    // conteúdo fica.
    final bar = destinations.length >= 2
        ? NavigationBarTheme(
            data: _barTheme(chrome),
            child: NavigationBar(
              key: const Key('shell-nav-bar'),
              backgroundColor: chrome.surface,
              indicatorColor: chrome.accentSoft,
              selectedIndex: currentIndex.clamp(0, destinations.length - 1),
              onDestinationSelected: onDestinationSelected,
              destinations: [
                for (final d in destinations)
                  NavigationDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selectedIcon),
                    label: d.label,
                    tooltip: d.label,
                  ),
              ],
            ),
          )
        : null;
    return Scaffold(body: content, bottomNavigationBar: bar);
  }

  // ── medium/expanded: NavigationRail à esquerda ──
  Widget _railLayout(
    List<ShellDestination> destinations,
    ShellChrome chrome,
    Widget content, {
    required bool extended,
  }) {
    if (destinations.length < 2) {
      return Scaffold(body: content);
    }
    final rail = NavigationRail(
      key: const Key('shell-nav-rail'),
      backgroundColor: chrome.surface,
      extended: extended,
      indicatorColor: chrome.accentSoft,
      selectedIndex: currentIndex.clamp(0, destinations.length - 1),
      onDestinationSelected: onDestinationSelected,
      groupAlignment: -1.0,
      selectedIconTheme: IconThemeData(color: chrome.accent),
      unselectedIconTheme: IconThemeData(color: chrome.onMuted),
      selectedLabelTextStyle: TextStyle(
        color: chrome.accent,
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelTextStyle: TextStyle(color: chrome.onMuted),
      leading: _railLeading(chrome, extended: extended),
      trailing: Expanded(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: TurniSpacing.md),
            child: IconButton(
              key: const Key('shell-logout'),
              tooltip: 'Sair',
              onPressed: onLogout,
              icon: Icon(Icons.logout, color: chrome.onMuted),
            ),
          ),
        ),
      ),
      destinations: [
        for (final d in destinations)
          NavigationRailDestination(
            icon: Icon(d.icon),
            selectedIcon: Icon(d.selectedIcon),
            label: Text(d.label),
          ),
      ],
    );
    return Scaffold(
      body: Row(
        children: [
          rail,
          const VerticalDivider(width: 1, thickness: 1),
          Expanded(child: content),
        ],
      ),
    );
  }

  Widget _railLeading(ShellChrome chrome, {required bool extended}) {
    return Padding(
      padding: const EdgeInsets.only(
        top: TurniSpacing.sm,
        bottom: TurniSpacing.sm,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _brand(chrome, fontSize: 22),
          if (hasNovaVagaAction(role)) ...[
            const SizedBox(height: TurniSpacing.md),
            IconButton.filled(
              key: const Key('shell-fab-nova-vaga'),
              tooltip: 'Nova vaga',
              onPressed: onNovaVaga,
              style: IconButton.styleFrom(
                backgroundColor: chrome.accent,
                foregroundColor: chrome.surface,
              ),
              icon: const Icon(Icons.add),
            ),
          ],
        ],
      ),
    );
  }

  // ── large: sidebar persistente (drawer) ──
  Widget _drawerLayout(
    List<ShellDestination> destinations,
    ShellChrome chrome,
    Widget content,
  ) {
    return Scaffold(
      body: Row(
        children: [
          SizedBox(
            key: const Key('shell-nav-drawer'),
            width: 248,
            child: Container(
              color: chrome.surface,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Marca + papel
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      TurniSpacing.lg,
                      TurniSpacing.lg,
                      TurniSpacing.lg,
                      TurniSpacing.md,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _brand(chrome, fontSize: 30),
                        const SizedBox(height: TurniSpacing.xs),
                        Text(
                          _roleTag(role).toUpperCase(),
                          style: TextStyle(
                            color: chrome.onMuted,
                            fontSize: 12,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: chrome.line),
                  if (userName.trim().isNotEmpty) _userPill(chrome),
                  const SizedBox(height: TurniSpacing.sm),
                  // Destinos
                  for (var i = 0; i < destinations.length; i++)
                    _SidebarItem(
                      destination: destinations[i],
                      selected: i == currentIndex,
                      chrome: chrome,
                      onTap: () => onDestinationSelected(i),
                    ),
                  // Ação primária do contratante
                  if (hasNovaVagaAction(role))
                    Padding(
                      padding: const EdgeInsets.all(TurniSpacing.md),
                      child: FilledButton.icon(
                        key: const Key('shell-fab-nova-vaga'),
                        onPressed: onNovaVaga,
                        style: FilledButton.styleFrom(
                          backgroundColor: chrome.accent,
                          foregroundColor: chrome.surface,
                          minimumSize: const Size.fromHeight(48),
                        ),
                        icon: const Icon(Icons.add),
                        label: const Text('Nova vaga'),
                      ),
                    ),
                  const Spacer(),
                  Divider(height: 1, color: chrome.line),
                  // Sair
                  Padding(
                    padding: const EdgeInsets.all(TurniSpacing.sm),
                    child: TextButton.icon(
                      key: const Key('shell-logout'),
                      onPressed: onLogout,
                      style: TextButton.styleFrom(
                        foregroundColor: chrome.onMuted,
                        alignment: Alignment.centerLeft,
                        minimumSize: const Size.fromHeight(48),
                      ),
                      icon: const Icon(Icons.logout),
                      label: const Text('Sair'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const VerticalDivider(width: 1, thickness: 1),
          Expanded(child: content),
        ],
      ),
    );
  }

  Widget _userPill(ShellChrome chrome) {
    final initials = _initials(userName);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        TurniSpacing.lg,
        TurniSpacing.md,
        TurniSpacing.lg,
        TurniSpacing.md,
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 19,
            backgroundColor: chrome.accentSoft,
            child: Text(
              initials,
              style: TextStyle(
                color: chrome.accent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: TurniSpacing.sm),
          Expanded(
            child: Text(
              userName,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: chrome.on, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _brand(ShellChrome chrome, {required double fontSize}) {
    return Text.rich(
      TextSpan(
        children: [
          const TextSpan(text: 'TURN'),
          TextSpan(
            text: 'I',
            style: TextStyle(color: chrome.accent),
          ),
          const TextSpan(text: '.'),
        ],
      ),
      semanticsLabel: 'Turni',
      style: TextStyle(
        fontFamily: 'BebasNeue',
        fontSize: fontSize,
        color: chrome.on,
        height: 1.0,
        letterSpacing: 1.0,
      ),
    );
  }

  NavigationBarThemeData _barTheme(ShellChrome chrome) {
    return NavigationBarThemeData(
      backgroundColor: chrome.surface,
      indicatorColor: chrome.accentSoft,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: states.contains(WidgetState.selected)
              ? chrome.accent
              : chrome.onMuted,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? chrome.accent
              : chrome.onMuted,
        ),
      ),
    );
  }

  static String _roleTag(String? role) =>
      role == 'contratante' ? 'Contratante' : 'Profissional';

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }
}

/// Item de navegação da sidebar (large). Botão focável com semântica de
/// selecionado para teclado/leitor de tela (CA-6).
class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.destination,
    required this.selected,
    required this.chrome,
    required this.onTap,
  });

  final ShellDestination destination;
  final bool selected;
  final ShellChrome chrome;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? chrome.accent : chrome.onMuted;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: TurniSpacing.sm,
        vertical: 2,
      ),
      child: Semantics(
        button: true,
        selected: selected,
        label: destination.label,
        child: Material(
          color: selected ? chrome.accentSoft : Colors.transparent,
          borderRadius: const BorderRadius.all(TurniRadius.md),
          child: InkWell(
            key: Key('shell-nav-${destination.id}'),
            borderRadius: const BorderRadius.all(TurniRadius.md),
            onTap: onTap,
            child: Container(
              constraints: const BoxConstraints(minHeight: 48),
              padding: const EdgeInsets.symmetric(
                horizontal: TurniSpacing.md,
                vertical: TurniSpacing.sm,
              ),
              child: Row(
                children: [
                  Icon(
                    selected ? destination.selectedIcon : destination.icon,
                    color: fg,
                    size: 22,
                  ),
                  const SizedBox(width: TurniSpacing.md),
                  Text(
                    destination.label,
                    style: TextStyle(
                      color: fg,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
