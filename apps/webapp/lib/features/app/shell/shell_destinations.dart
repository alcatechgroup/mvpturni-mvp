import 'package:flutter/material.dart';

/// Um destino de navegação do shell (DDR-003). São 3 por papel — Vagas, Turnos,
/// Perfil — na mesma ordem; só o [title] da tela muda por papel. Drill-downs
/// (detalhe de vaga/turno, candidatos, editar) NÃO são destinos: empilham sobre
/// o destino ativo dentro do mesmo branch.
@immutable
class ShellDestination {
  const ShellDestination({
    required this.id,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.title,
    required this.route,
  });

  /// Identificador lógico — vira `Key('shell-nav-<id>')` nos testes.
  final String id;

  /// Ícone do item inativo (contorno).
  final IconData icon;

  /// Ícone do item ativo (preenchido).
  final IconData selectedIcon;

  /// Rótulo curto na barra/rail/drawer (igual nos dois papéis).
  final String label;

  /// Título da tela na barra superior (varia por papel — DDR-003).
  final String title;

  /// Rota canônica do branch (initialLocation do `StatefulShellBranch`).
  final String route;
}

/// Destinos do papel autenticado (CA-2). Fail-secure (ADR-007): papel
/// desconhecido/nulo → lista vazia (nenhum destino exposto).
List<ShellDestination> destinationsFor(String? role) {
  switch (role) {
    case 'profissional':
      return const [
        ShellDestination(
          id: 'vagas',
          icon: Icons.work_outline,
          selectedIcon: Icons.work,
          label: 'Vagas',
          title: 'Vagas',
          route: '/',
        ),
        ShellDestination(
          id: 'turnos',
          icon: Icons.event_outlined,
          selectedIcon: Icons.event,
          label: 'Turnos',
          title: 'Meus turnos',
          route: '/turnos',
        ),
        ShellDestination(
          id: 'perfil',
          icon: Icons.person_outline,
          selectedIcon: Icons.person,
          label: 'Perfil',
          title: 'Perfil',
          route: '/perfil',
        ),
      ];
    case 'contratante':
      return const [
        ShellDestination(
          id: 'vagas',
          icon: Icons.work_outline,
          selectedIcon: Icons.work,
          label: 'Vagas',
          title: 'Minhas vagas',
          route: '/',
        ),
        ShellDestination(
          id: 'turnos',
          icon: Icons.event_outlined,
          selectedIcon: Icons.event,
          label: 'Turnos',
          title: 'Turnos',
          route: '/turnos',
        ),
        ShellDestination(
          id: 'perfil',
          icon: Icons.person_outline,
          selectedIcon: Icons.person,
          label: 'Perfil',
          title: 'Perfil',
          route: '/perfil',
        ),
      ];
    default:
      return const [];
  }
}

/// "Nova vaga" é ação primária do contratante (FAB/rail/drawer), não destino
/// (DDR-003). Só o contratante a vê.
bool hasNovaVagaAction(String? role) => role == 'contratante';
