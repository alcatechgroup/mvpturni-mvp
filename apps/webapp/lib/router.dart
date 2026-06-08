import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'features/app/app_shell_screen.dart';
import 'features/app/perfil_screen.dart';
import 'features/app/shell/app_shell.dart';
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
    // ──────────────────────────────────────────────────────────────
    // Shell de navegação global (STORY-077 / DDR-003). Envolve as rotas
    // AUTENTICADAS num StatefulShellRoute.indexedStack — um branch por destino
    // (Vagas / Turnos / Perfil) — para preservar o estado de cada aba ao trocar
    // de destino. Drill-downs (detalhe de vaga/turno, candidatos, editar, nova,
    // cronômetro PoC) empilham DENTRO do branch correspondente: o shell continua
    // visível e o "voltar" retorna ao destino. As rotas públicas/funil ficam
    // FORA do shell (sem barra de navegação).
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          AppShell(navigationShell: navigationShell, location: state.uri.path),
      branches: [
        // Branch 0 — Vagas (home de cada papel + drill-downs de vagas).
        StatefulShellBranch(
          routes: [
            // Home pós-login (status=ativo). Contratante: "Minhas vagas"
            // (STORY-047). Profissional: feed (STORY-048). Demais papéis: shell
            // mínimo. O funnel guard já garante sessão ativa aqui.
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
            // Feed do profissional (STORY-048). Rota explícita além da home `/`;
            // deep-link `?filtro=`. RBAC (CA-1) tratado dentro da tela.
            GoRoute(
              path: '/feed',
              builder: (context, state) => FeedScreen(
                filtroInicial: state.uri.queryParameters['filtro'],
              ),
            ),
            // Detalhe da vaga + breakdown explicável (STORY-049). pageKey por URL
            // (sem isto o go_router reusa a mesma Page/State entre /vaga/A e
            // /vaga/B). RBAC/404 tratados dentro da tela.
            GoRoute(
              path: '/vaga/:id',
              pageBuilder: (context, state) {
                final id = state.pathParameters['id'] ?? '';
                return MaterialPage(
                  key: ValueKey('vaga-$id'),
                  child: VagaDetalheScreen(vagaId: id),
                );
              },
            ),
            // "Minhas vagas" do contratante (STORY-047). Filtro via `?filtro=`;
            // recebe o toast de sucesso da publicação por `extra` (STORY-046 CA-7).
            GoRoute(
              path: '/contratante/vagas',
              builder: (context, state) => MinhasVagasScreen(
                filtroInicial: state.uri.queryParameters['filtro'],
                successMessage: state.extra as String?,
              ),
            ),
            // Publicar vaga do contratante (STORY-046). RBAC tratado na tela.
            GoRoute(
              path: '/contratante/vagas/nova',
              builder: (context, state) => const PublicarVagaScreen(),
            ),
            // Editar vaga do contratante (STORY-052 / PDR-009). RBAC na tela.
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
            // Painel de candidatos da vaga (STORY-051). RBAC/404 tratados na tela;
            // contexto da vaga por `extra` (degrada no deep-link).
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
          ],
        ),
        // Branch 1 — Turnos. `/turnos` é a rota canônica role-dispatch
        // (initialLocation do branch, alvo do destino "Turnos"); os paths por
        // papel continuam válidos (deep-links e botões já existentes).
        StatefulShellBranch(
          initialLocation: '/turnos',
          routes: [
            GoRoute(
              path: '/turnos',
              builder: (context, state) =>
                  AuthService().session?.role == 'contratante'
                  ? const TurnosListaScreen(papel: TurnosPapel.contratante)
                  : const TurnosListaScreen(papel: TurnosPapel.profissional),
            ),
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
            // Detalhe do turno (STORY-060) — rota compartilhada pelos 2 papéis.
            // RBAC no backend: 403 cruzado e 404 caem no mesmo "não encontrado".
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
            // PoC do cronômetro bilateral + geofencing (STORY-057 / ADR-017).
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
          ],
        ),
        // Branch 2 — Perfil (STORY-077): identidade + tema + Sair (DDR-003).
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/perfil',
              builder: (context, state) => const PerfilScreen(),
            ),
          ],
        ),
      ],
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
