import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'features/app/app_shell_screen.dart';
import 'features/auth/auth_service.dart';
import 'features/auth/forgot_password_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/funnel/completar_cadastro_placeholder_screen.dart';
import 'features/funnel/welcome_placeholder_screen.dart';
import 'features/welcome/welcome_screen.dart';

// ──────────────────────────────────────────────────────────────
// Funnel guard (CA-10 — STORY-016).
// Roteamento pós-login conforme ADR-009:
//   status=liberado + welcome_seen_at=null → /welcome
//   status=liberado + welcome_seen_at!=null + cadastro=null → /completar-cadastro
//   status=ativo → /app
//   não-logado → /login
// ──────────────────────────────────────────────────────────────
String? _funnelGuard(BuildContext context, GoRouterState state) {
  final auth = AuthService();
  final session = auth.session;

  // Rotas públicas — sem guard
  const publicRoutes = {'/', '/login', '/esqueci-minha-senha', '/health'};
  if (publicRoutes.contains(state.matchedLocation)) return null;

  // Não logado → /login
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
    // Rota pública (hello world / landing)
    GoRoute(path: '/', builder: (context, state) => const WelcomeScreen()),

    // Auth
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(
      path: '/esqueci-minha-senha',
      builder: (context, state) => const ForgotPasswordScreen(),
    ),

    // Funnel guard — placeholders
    GoRoute(
      path: '/welcome',
      builder: (context, state) => const WelcomePlaceholderScreen(),
    ),
    GoRoute(
      path: '/completar-cadastro',
      builder: (context, state) => const CompletarCadastroPlaceholderScreen(),
    ),

    // App shell — usuários ativos
    GoRoute(path: '/app', builder: (context, state) => const AppShellScreen()),

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
