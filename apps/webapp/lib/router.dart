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
import 'features/funnel/welcome_screen.dart' as funnel;
import 'features/vagas/minhas_vagas_screen.dart';
import 'features/vagas/publicar_vaga_screen.dart';
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
    // Contratante: a home é "Minhas vagas" (STORY-047 — substitui o shell mínimo de
    // STORY-046). Demais papéis seguem no shell até terem tela própria.
    GoRoute(
      path: '/',
      builder: (context, state) => AuthService().session?.role == 'contratante'
          ? const MinhasVagasScreen()
          : const AppShellScreen(),
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
    // Painel de candidatos da vaga (STORY-051). Placeholder até aquela estória entrar;
    // o link "Ver candidatos" de Minhas vagas (CA-6) aponta para cá.
    GoRoute(
      path: '/contratante/vagas/:id/candidatos',
      builder: (context, state) => Scaffold(
        appBar: AppBar(title: const Text('Candidatos')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'O painel de candidatos chega na próxima estória.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
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
