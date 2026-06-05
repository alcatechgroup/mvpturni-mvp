import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'features/app/app_shell_screen.dart';
import 'features/auth/auth_service.dart';
import 'features/auth/forgot_password_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/redefinir_senha_screen.dart';
import 'features/cadastro/completar_cadastro_contratante_screen.dart';
import 'features/cadastro/completar_cadastro_screen.dart';
import 'features/cadastro/pre_cadastro_contratante_screen.dart';
import 'features/cadastro/pre_cadastro_profissional_screen.dart';
import 'features/feed/feed_screen.dart';
import 'features/funnel/welcome_screen.dart' as funnel;
import 'features/turno/cronometro_poc_screen.dart';
import 'features/turnos/turno_detalhe_screen.dart';
import 'features/turnos/turnos_lista_screen.dart';
import 'features/vagas/editar_vaga_screen.dart';
import 'features/vagas/minhas_vagas_screen.dart';
import 'features/vagas/painel_candidatos_screen.dart';
import 'features/vagas/publicar_vaga_screen.dart';
import 'features/vagas/vaga_detalhe_screen.dart';
import 'features/vagas/vaga_service.dart' show VagaResumo;
import 'features/welcome/welcome_screen.dart';

// ──────────────────────────────────────────────────────────────
// Funnel guard (CA-10 — STORY-016).
// Roteamento pós-login conforme ADR-009:
//   status=liberado + welcome_seen_at=null → /welcome
//   status=liberado + welcome_seen_at!=null + cadastro=null → /completar-cadastro
//   status=ativo → / (home pós-login)
//   não-logado → /login
// ──────────────────────────────────────────────────────────────
String? _funnelGuard(BuildContext context, GoRouterState state) {
  final auth = AuthService();
  final session = auth.session;

  // Rotas públicas — sem guard. O root `/` NÃO é público: é a home pós-login
  // (redireciona para /login quando não há sessão). A tela informativa fica em /info.
  const publicRoutes = {
    '/info',
    '/login',
    '/esqueci-minha-senha',
    '/redefinir-senha',
    '/cadastro/profissional',
    '/cadastro/contratante',
    '/health',
  };
  if (publicRoutes.contains(state.matchedLocation)) return null;

  // Não logado → /login (inclui o root `/`)
  if (session == null) return '/login';

  final funnel = session.funnelState;

  // Usuário em rota placeholder de funil — permite acesso direto
  if (state.matchedLocation == '/welcome' &&
      funnel == FunnelState.awaitWelcome) {
    return null;
  }
  if (state.matchedLocation == '/completar-cadastro' &&
      funnel == FunnelState.awaitCadastro) {
    return null;
  }

  // Roteamento por estado do funil
  switch (funnel) {
    case FunnelState.awaitWelcome:
      if (state.matchedLocation != '/welcome') return '/welcome';
    case FunnelState.awaitCadastro:
      if (state.matchedLocation != '/completar-cadastro') {
        return '/completar-cadastro';
      }
    case FunnelState.awaitApproval || FunnelState.rejected:
      return '/login';
    case FunnelState.active:
      break;
  }

  return null;
}

final router = GoRouter(
  initialLocation: '/',
  redirect: _funnelGuard,
  routes: [
    // Home pós-login (status=ativo). Não logado → o guard manda para /login.
    // Contratante: home = "Minhas vagas" (STORY-047). Profissional: home = feed de vagas
    // (STORY-048 — substitui o shell mínimo). Demais papéis seguem no shell.
    GoRoute(
      path: '/',
      builder: (context, state) {
        return switch (AuthService().session?.role) {
          'contratante' => const MinhasVagasScreen(),
          'profissional' => const FeedScreen(),
          _ => const AppShellScreen(),
        };
      },
    ),

    // Tela informativa pública (antigo root)
    GoRoute(path: '/info', builder: (context, state) => const WelcomeScreen()),

    // Auth
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(
      path: '/esqueci-minha-senha',
      builder: (context, state) => const ForgotPasswordScreen(),
    ),
    // Destino do link do e-mail recuperacao_senha (STORY-021 CA-6/CA-13b).
    GoRoute(
      path: '/redefinir-senha',
      builder: (context, state) => RedefinirSenhaScreen(
        token: state.uri.queryParameters['token'] ?? '',
        email: state.uri.queryParameters['email'] ?? '',
      ),
    ),

    // Pré-cadastro público de profissional (STORY-017)
    GoRoute(
      path: '/cadastro/profissional',
      builder: (context, state) => const PreCadastroProfissionalScreen(),
    ),

    // Pré-cadastro público de contratante (STORY-018)
    GoRoute(
      path: '/cadastro/contratante',
      builder: (context, state) => const PreCadastroContratanteScreen(),
    ),

    // Welcome pós-aprovação (STORY-022 — tela real substitui o placeholder de STORY-016)
    GoRoute(
      path: '/welcome',
      builder: (context, state) => const funnel.WelcomeScreen(),
    ),
    // Completar cadastro + aceite eletrônico. Mesma rota; o builder ramifica pelo papel:
    // profissional (STORY-023) ou contratante (STORY-024). O funnel guard já garantiu
    // sessão em `await_cadastro`.
    GoRoute(
      path: '/completar-cadastro',
      builder: (context, state) => AuthService().session?.role == 'contratante'
          ? const CompletarCadastroContratanteScreen()
          : const CompletarCadastroScreen(),
    ),

    // Feed do profissional (STORY-048). Rota explícita além da home `/`; deep-link `?filtro=`.
    // RBAC (CA-1) tratado dentro da tela: contratante (403) cai em "sem permissão".
    GoRoute(
      path: '/feed',
      builder: (context, state) =>
          FeedScreen(filtroInicial: state.uri.queryParameters['filtro']),
    ),
    // Detalhe da vaga + breakdown explicável (STORY-049). RBAC (CA-7) tratado dentro da tela:
    // contratante (403) cai em "sem permissão"; 404 cai em "vaga indisponível". O card do feed
    // e o botão "Candidatar-se" (STORY-050) apontam para cá.
    GoRoute(
      path: '/vaga/:id',
      // pageKey por URL completa: sem isto o go_router reusa a MESMA Page (e o State) ao
      // navegar entre /vaga/A e /vaga/B (mesma rota, param diferente — ex.: candidatar numa
      // vaga e abrir outra, STORY-050), e a tela continua mostrando a vaga anterior. A key na
      // MaterialPage força uma Page nova → State novo → recarrega o detalhe da vaga certa.
      pageBuilder: (context, state) {
        final id = state.pathParameters['id'] ?? '';
        return MaterialPage(
          key: ValueKey('vaga-$id'),
          child: VagaDetalheScreen(vagaId: id),
        );
      },
    ),

    // Publicar vaga do contratante (STORY-046). RBAC (CA-1) tratado dentro da tela:
    // profissional ativo cai no estado "sem permissão". Status=ativo garantido pelo
    // funnel guard (rota não-pública).
    GoRoute(
      path: '/contratante/vagas/nova',
      builder: (context, state) => const PublicarVagaScreen(),
    ),
    // "Minhas vagas" do contratante (STORY-047). Filtro via `?filtro=` (deep-link);
    // recebe o toast de sucesso da publicação por `extra` (STORY-046 CA-7).
    GoRoute(
      path: '/contratante/vagas',
      builder: (context, state) => MinhasVagasScreen(
        filtroInicial: state.uri.queryParameters['filtro'],
        successMessage: state.extra as String?,
      ),
    ),
    // Editar vaga do contratante (STORY-052 / PDR-009). RBAC (CA-1) tratado dentro da tela:
    // profissional/não-dono cai em "sem permissão"; vaga não-aberta cai em "não pode mais ser
    // editada". O link "Editar" de Minhas vagas (047) aponta para cá. `/editar` antes de
    // `/:id/candidatos` na lista de rotas só por organização — paths distintos não conflitam.
    GoRoute(
      path: '/contratante/vagas/:id/editar',
      pageBuilder: (context, state) {
        final id = state.pathParameters['id'] ?? '';
        return MaterialPage(
          key: ValueKey('editar-vaga-$id'),
          child: EditarVagaScreen(vagaId: id),
        );
      },
    ),

    // Painel de candidatos da vaga (STORY-051). RBAC (CA-1) tratado dentro da tela: profissional
    // ou contratante não-dono (403) cai em "sem permissão"; 404 cai em "vaga não encontrada". O
    // link "Ver candidatos" de Minhas vagas (047 CA-6) aponta para cá e passa o contexto da vaga
    // (função/horário) por `extra` para a faixa de cabeçalho; no deep-link a faixa degrada para
    // só a contagem (o contrato CA-1 não inclui dados da vaga).
    GoRoute(
      path: '/contratante/vagas/:id/candidatos',
      builder: (context, state) {
        final id = state.pathParameters['id'] ?? '';
        final ctx = state.extra is VagaResumo
            ? state.extra as VagaResumo
            : null;
        return PainelCandidatosScreen(
          vagaId: id,
          funcao: ctx?.funcao,
          dataInicio: ctx?.dataInicio,
          dataFim: ctx?.dataFim,
        );
      },
    ),

    // Listas de turnos por papel (STORY-059 / SCREEN-059). RBAC (CA-5) tratado dentro da
    // tela: papel cruzado (403 do back) cai em "sem permissão" fail-secure. Entrada pelos
    // ícones na AppBar do feed e de Minhas vagas; deep-link sobrevive a reload.
    GoRoute(
      path: '/profissional/turnos',
      builder: (context, state) =>
          const TurnosListaScreen(papel: TurnosPapel.profissional),
    ),
    GoRoute(
      path: '/contratante/turnos',
      builder: (context, state) =>
          const TurnosListaScreen(papel: TurnosPapel.contratante),
    ),

    // Detalhe do turno (STORY-060 / SCREEN-060) — rota COMPARTILHADA pelos 2 papéis (a
    // estória fixa `/turnos/{id}`; o tema/microcopy vêm do papel). RBAC no backend: 403
    // cruzado e 404 inexistente caem no MESMO "não encontrado" fail-secure (§4.5).
    GoRoute(
      path: '/turnos/:id',
      pageBuilder: (context, state) {
        final id = state.pathParameters['id'] ?? '';
        return MaterialPage(
          key: ValueKey('turno-detalhe-$id'),
          child: TurnoDetalheScreen(turnoId: id),
        );
      },
    ),

    // PoC do cronômetro bilateral + geofencing (STORY-057 / ADR-017 — CA-5). Rota não-pública
    // (funnel guard exige sessão ativa); os dois lados do turno abrem a MESMA URL em navegadores
    // distintos para demonstrar a sincronia ≤ 2s. RBAC bilateral é do backend (404 p/ terceiros).
    GoRoute(
      path: '/turno/:id/cronometro-poc',
      pageBuilder: (context, state) {
        final id = state.pathParameters['id'] ?? '';
        return MaterialPage(
          key: ValueKey('cronometro-poc-$id'),
          child: CronometroPocScreen(turnoId: id),
        );
      },
    ),

    // Health (dev local)
    GoRoute(
      path: '/health',
      builder: (context, state) => const _HealthInfoScreen(),
    ),
  ],
);

// Tela de health para dev local — em produção, Firebase serve health.json.
class _HealthInfoScreen extends StatelessWidget {
  const _HealthInfoScreen();

  static const _version = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: 'dev',
  );

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now().toUtc().toIso8601String();
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: SelectableText(
          '{\n'
          '  "status": "ok",\n'
          '  "version": "$_version",\n'
          '  "timestamp": "$now",\n'
          '  "service": "webapp"\n'
          '}',
          style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
        ),
      ),
    );
  }
}
