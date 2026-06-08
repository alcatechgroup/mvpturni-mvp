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

/// Rotas-raiz de cada destino (STORY-078). Só nelas o shell mostra a barra
/// superior (título + sino + tema). Os drill-downs empilhados dentro do branch
/// (detalhe de vaga/turno, candidatos, editar, nova, cronômetro PoC) NÃO estão
/// aqui — mantêm a própria `AppBar` (voltar + título específico).
const _destinationRootRoutes = <String>{
  '/', // home role-dispatch: feed (profissional) / minhas vagas (contratante)
  '/feed',
  '/contratante/vagas',
  '/turnos', // turnos canônico (role-dispatch)
  '/profissional/turnos',
  '/contratante/turnos',
  '/perfil',
};

/// `true` quando [location] (use `state.uri.path`, sem query string) é a raiz de
/// um destino — o shell pinta a barra superior. Drill-downs e rotas
/// públicas/desconhecidas → `false` (fail-safe; a tela cuida da própria AppBar).
bool isDestinationRoot(String location) =>
    _destinationRootRoutes.contains(location);

/// Título da barra superior do shell = título do destino ATIVO (varia por
/// papel). Fail-secure: papel desconhecido/nulo ou índice fora do range → null.
String? sectionTitleFor(String? role, int index) {
  final destinations = destinationsFor(role);
  if (index < 0 || index >= destinations.length) return null;
  return destinations[index].title;
}
