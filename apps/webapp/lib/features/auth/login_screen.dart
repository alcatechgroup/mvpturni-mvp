import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_update/app_update.dart';
import '../../core/install/install.dart';
import '../../core/install/widgets/install_action_slot.dart';
import '../../core/theme/theme_toggle_button.dart';
import '../../ds/components/app_version_label.dart';
import '../../ds/tokens.dart';
import '../../ds/typography.dart';
import 'auth_service.dart';

/// Tela de login do WebApp (CA-5 — SCREEN-STORY-016 Tela A).
/// Tema: pré-login = esquema profissional (verde) neutro (DDR-001 §1).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _obscurePassword = true;
  bool _loading = false;
  _BannerState? _banner;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _banner = null;
    });

    final result = await AuthService().login(
      _emailCtrl.text.trim(),
      _passwordCtrl.text,
    );

    if (!mounted) return;

    setState(() => _loading = false);

    switch (result) {
      case LoginSuccess(:final session):
        // Trigger (iii) da auto-atualização: checa versão ao logar (STORY-037 CA-2).
        appUpdate.onLoginSuccess();
        _redirect(session);
      case LoginAdminRedirect(:final backofficeUrl):
        setState(() => _banner = _BannerState.adminRedirect(backofficeUrl));
      case LoginThrottle(:final retryAfter):
        setState(() => _banner = _BannerState.throttle(retryAfter));
      case LoginError(:final message):
        setState(() => _banner = _BannerState.error(message));
    }
  }

  void _redirect(UserSession session) {
    final state = session.funnelState;
    switch (state) {
      case FunnelState.awaitWelcome:
        context.go('/welcome');
      case FunnelState.awaitCadastro:
        context.go('/completar-cadastro');
      case FunnelState.awaitApproval:
        setState(() => _banner = _BannerState.pending());
      case FunnelState.rejected:
        setState(() => _banner = _BannerState.rejected());
      case FunnelState.active:
        context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= 840;

    final accent = isDark ? TurniColors.accentDark : TurniColors.accentLight;
    final surfacePage = isDark
        ? TurniColors.surfacePageDark
        : TurniColors.surfacePageLight;

    final form = _LoginForm(
      formKey: _formKey,
      emailCtrl: _emailCtrl,
      passwordCtrl: _passwordCtrl,
      obscurePassword: _obscurePassword,
      loading: _loading,
      banner: _banner,
      accent: accent,
      isDark: isDark,
      desktop: isDesktop,
      onTogglePassword: () =>
          setState(() => _obscurePassword = !_obscurePassword),
      onSubmit: _submit,
    );

    final formColumn = Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: isDesktop ? TurniSpacing.x2l : TurniSpacing.lg,
          vertical: isDesktop ? TurniSpacing.x3l : TurniSpacing.x2l,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: form,
        ),
      ),
    );

    return Scaffold(
      key: const ValueKey('login:screen'),
      backgroundColor: surfacePage,
      body: Stack(
        children: [
          // Desktop (≥840): split editorial — imagem da equipe à esquerda,
          // formulário à direita (protótipo SCREEN-STORY-016). Mobile: o
          // formulário centralizado de sempre, sem a imagem hero.
          if (isDesktop)
            Row(
              children: [
                const Expanded(child: _LoginHero()),
                Expanded(
                  child: ColoredBox(color: surfacePage, child: formColumn),
                ),
              ],
            )
          else
            formColumn,

          // Alternância de tema pré-login (mesma fonte do Perfil/shell —
          // [ThemeModeController]). DDR-001 §1: o acento segue neutro; só o
          // claro/escuro é alternável e persistido.
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: const Padding(
                padding: EdgeInsets.all(TurniSpacing.sm),
                child: ThemeToggleButton(key: ValueKey('login:theme-toggle')),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Coluna hero (desktop) — imagem da equipe + brand statement
// ──────────────────────────────────────────────────────────────

/// Lado esquerdo do login em desktop (protótipo SCREEN-STORY-016): imagem da
/// equipe full-bleed com overlay editorial e o brand statement por cima.
/// Renderizado só em ≥840 — no mobile o formulário ocupa a tela inteira.
class _LoginHero extends StatelessWidget {
  const _LoginHero();

  // Verde-claro de realce sobre a imagem (assinatura da marca no chrome escuro).
  static const _heroAccent = Color(0xFF7BC299);

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/img/12-equipe-fundo.jpg'),
          fit: BoxFit.cover,
        ),
      ),
      child: DecoratedBox(
        // Overlay escurece a foto p/ legibilidade do texto (gradiente vertical).
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x8C0F2818), Color(0x4D0F2818), Color(0xCC0F2818)],
            stops: [0.0, 0.35, 1.0],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: TurniSpacing.x2l,
              vertical: TurniSpacing.x2l,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Logomarca branca (no desktop a marca vive aqui, não no form).
                Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(text: 'TURN'),
                      TextSpan(
                        text: 'I',
                        style: TextStyle(color: _heroAccent),
                      ),
                      TextSpan(
                        text: '.',
                        style: TextStyle(color: _heroAccent),
                      ),
                    ],
                  ),
                  style: const TextStyle(
                    fontFamily: 'BebasNeue',
                    fontSize: 56,
                    color: Colors.white,
                    letterSpacing: 4,
                    height: 1.0,
                  ),
                ),
                const Spacer(),

                // Eyebrow "ao vivo" (ponto + rótulo mono).
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF9DD9B0),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: TurniSpacing.sm),
                    Text(
                      'PLATAFORMA TURNI · AO VIVO',
                      style: dsMono(
                        fontSize: 11,
                        letterSpacing: 3,
                        color: const Color(0xFF9DD9B0),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: TurniSpacing.md),

                // Brand statement.
                const Text(
                  'O ponto de encontro entre quem contrata e quem turnifica.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 44,
                    fontWeight: FontWeight.w500,
                    height: 1.05,
                    letterSpacing: -1.0,
                  ),
                ),
                const SizedBox(height: TurniSpacing.md),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Text(
                    'A plataforma que une os dois lados do turno em uma só '
                    'rede. Acesse para retomar de onde parou.',
                    style: TextStyle(
                      color: Colors.white.withAlpha(217),
                      fontSize: 15,
                      height: 1.6,
                    ),
                  ),
                ),
                const SizedBox(height: TurniSpacing.lg),

                // Pilares — assinatura do produto.
                Container(
                  padding: const EdgeInsets.only(top: TurniSpacing.md),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: Color(0x2EFFFFFF))),
                  ),
                  child: const Wrap(
                    spacing: TurniSpacing.md,
                    runSpacing: TurniSpacing.sm,
                    children: [
                      _HeroPillar(icon: Icons.memory, label: 'MATCH IA'),
                      _HeroPillar(
                        icon: Icons.verified_user_outlined,
                        label: 'PIN BILATERAL',
                      ),
                      _HeroPillar(icon: Icons.bolt, label: 'PIX 15MIN'),
                      _HeroPillar(
                        icon: Icons.restaurant,
                        label: 'HOSPITALIDADE',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Um pilar do hero — ícone verde + rótulo mono. Decorativo.
class _HeroPillar extends StatelessWidget {
  const _HeroPillar({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: _LoginHero._heroAccent),
        const SizedBox(width: TurniSpacing.xs),
        Text(
          label,
          style: dsMono(
            fontSize: 10.5,
            letterSpacing: 1.5,
            color: Colors.white.withAlpha(191),
          ),
        ),
      ],
    );
  }
}

class _LoginForm extends StatelessWidget {
  const _LoginForm({
    required this.formKey,
    required this.emailCtrl,
    required this.passwordCtrl,
    required this.obscurePassword,
    required this.loading,
    required this.banner,
    required this.accent,
    required this.isDark,
    required this.desktop,
    required this.onTogglePassword,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailCtrl;
  final TextEditingController passwordCtrl;
  final bool obscurePassword;
  final bool loading;
  final _BannerState? banner;
  final Color accent;
  final bool isDark;

  /// Desktop (≥840) mostra um cabeçalho textual ("Acesse sua conta"), porque a
  /// logomarca vive no hero à esquerda. Mobile mantém a logo grande no topo.
  final bool desktop;
  final VoidCallback onTogglePassword;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabeçalho: no desktop a marca está no hero à esquerda, então aqui
          // entra um cabeçalho textual; no mobile mantemos a logomarca grande.
          if (desktop) ...[
            Text(
              'JÁ É TURNI.',
              style: dsMono(fontSize: 11, letterSpacing: 2.5, color: accent),
            ),
            const SizedBox(height: TurniSpacing.sm),
            Semantics(
              header: true,
              child: Text(
                'Acesse sua conta',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.8,
                  height: 1.1,
                  color: isDark
                      ? TurniColors.textStrongDark
                      : TurniColors.textStrongLight,
                ),
              ),
            ),
            const SizedBox(height: TurniSpacing.xs),
            Text(
              'Use o e-mail cadastrado · seu turno te espera do outro lado.',
              style: TextStyle(
                fontSize: 14,
                height: 1.55,
                color: isDark
                    ? TurniColors.textMutedDark
                    : TurniColors.textMutedLight,
              ),
            ),
          ] else
            Semantics(
              label: 'Turni',
              header: true,
              child: Text(
                'TURNI.',
                style: TextStyle(
                  fontFamily: 'BebasNeue',
                  fontSize: 48,
                  fontWeight: FontWeight.w400,
                  color: TurniColors.brandGreen,
                  height: 1.0,
                ),
              ),
            ),
          const SizedBox(height: TurniSpacing.xl),

          // Campo e-mail
          TextFormField(
            key: const ValueKey('login:email'),
            controller: emailCtrl,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofocus: true,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: 'E-mail',
              hintText: 'seunome@email.com',
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return 'Este campo é obrigatório.';
              }
              if (!v.contains('@') || !v.contains('.')) {
                return 'E-mail inválido.';
              }
              return null;
            },
          ),
          const SizedBox(height: TurniSpacing.md),

          // Campo senha
          TextFormField(
            key: const ValueKey('login:password'),
            controller: passwordCtrl,
            obscureText: obscurePassword,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => onSubmit(),
            decoration: InputDecoration(
              labelText: 'Senha',
              suffixIcon: Tooltip(
                message: obscurePassword ? 'Mostrar senha' : 'Ocultar senha',
                child: IconButton(
                  key: const ValueKey('login:toggle-password'),
                  icon: Icon(
                    obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: onTogglePassword,
                ),
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Informe a senha.';
              return null;
            },
          ),

          // Link recuperação de senha
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              key: const ValueKey('login:forgot-password'),
              onPressed: () => context.go('/esqueci-minha-senha'),
              style: TextButton.styleFrom(foregroundColor: accent),
              child: const Text('Esqueci minha senha'),
            ),
          ),

          const SizedBox(height: TurniSpacing.sm),

          // Botão Entrar
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              key: const ValueKey('login:submit'),
              onPressed: loading ? null : onSubmit,
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                shape: const StadiumBorder(),
              ),
              child: loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(
                      'Entrar',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
            ),
          ),

          // Banner de erro / estado
          if (banner != null) ...[
            const SizedBox(height: TurniSpacing.md),
            _BannerWidget(banner: banner!, accent: accent, isDark: isDark),
          ],

          // Criar conta — duas portas de entrada públicas (STORY-017 profissional,
          // STORY-018 estabelecimento/contratante). Login é neutro (verde); o tema do
          // perfil aparece só na tela de cadastro de destino.
          const SizedBox(height: TurniSpacing.md),
          Center(
            child: Column(
              children: [
                Text(
                  'Não tem conta?',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark
                        ? TurniColors.textMutedDark
                        : TurniColors.textMutedLight,
                  ),
                ),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: TurniSpacing.sm,
                  children: [
                    // Cada porta usa o acento do seu perfil (DDR-001): verde =
                    // profissional, mostarda = estabelecimento/contratante. Antecipa
                    // visualmente o tema da tela de destino.
                    TextButton(
                      key: const ValueKey('login:create-professional'),
                      onPressed: () => context.go('/cadastro/profissional'),
                      style: TextButton.styleFrom(
                        foregroundColor: isDark
                            ? TurniColors.accentDark
                            : TurniColors.accentLight,
                      ),
                      child: const Text('Criar conta de profissional'),
                    ),
                    TextButton(
                      key: const ValueKey('login:create-establishment'),
                      onPressed: () => context.go('/cadastro/contratante'),
                      style: TextButton.styleFrom(
                        foregroundColor: isDark
                            ? TurniColors.contratanteAccentDark
                            : TurniColors.contratanteAccentInkLight,
                      ),
                      child: const Text('Criar conta de estabelecimento'),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Ação "Instalar app" — acima da versão (STORY-042 / IDR-020).
          const SizedBox(height: TurniSpacing.lg),
          InstallActionSlot(
            key: const Key('install-action-login'),
            controller: installController,
          ),

          // Versão rodando no dispositivo — rodapé discreto (STORY-037 CA-8).
          const SizedBox(height: TurniSpacing.sm),
          const Center(
            child: AppVersionLabel(key: Key('app-version-label-login')),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Banner de estado
// ──────────────────────────────────────────────────────────────

enum _BannerKind { error, adminRedirect, pending, rejected, throttle }

class _BannerState {
  final _BannerKind kind;
  final String message;
  final String? backofficeUrl;
  final int? retryAfter;

  const _BannerState._({
    required this.kind,
    required this.message,
    this.backofficeUrl,
    this.retryAfter,
  });

  factory _BannerState.error(String message) =>
      _BannerState._(kind: _BannerKind.error, message: message);

  factory _BannerState.adminRedirect(String url) => _BannerState._(
    kind: _BannerKind.adminRedirect,
    message: 'Este usuário acessa o Backoffice.',
    backofficeUrl: url,
  );

  factory _BannerState.pending() => _BannerState._(
    kind: _BannerKind.pending,
    // STORY-017 CA-8 — inclui o SLA público de 24h (alinha com a tela de cadastro).
    message:
        'Seu cadastro está em análise. Em até 24h enviaremos uma notificação por e-mail.',
  );

  factory _BannerState.rejected() => _BannerState._(
    kind: _BannerKind.rejected,
    message: 'Cadastro não aprovado. Entre em contato com o suporte.',
  );

  factory _BannerState.throttle(int retryAfter) => _BannerState._(
    kind: _BannerKind.throttle,
    message: 'Muitas tentativas. Aguarde antes de tentar novamente.',
    retryAfter: retryAfter,
  );
}

class _BannerWidget extends StatelessWidget {
  const _BannerWidget({
    required this.banner,
    required this.accent,
    required this.isDark,
  });

  final _BannerState banner;
  final Color accent;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color iconColor;
    IconData icon;

    switch (banner.kind) {
      case _BannerKind.error || _BannerKind.rejected || _BannerKind.throttle:
        bgColor = isDark
            ? TurniColors.errorSoftDark
            : TurniColors.errorSoftLight;
        iconColor = isDark ? TurniColors.errorDark : TurniColors.errorLight;
        icon = Icons.error_outline;
      case _BannerKind.adminRedirect:
        bgColor = isDark ? const Color(0x266A8FCC) : TurniColors.infoSoftLight;
        iconColor = TurniColors.infoLight;
        icon = Icons.info_outline;
      case _BannerKind.pending:
        bgColor = isDark ? TurniColors.warnSoftDark : TurniColors.warnSoftLight;
        iconColor = isDark ? TurniColors.warnDark : TurniColors.warnLight;
        icon = Icons.hourglass_top_outlined;
    }

    return Semantics(
      liveRegion: true,
      child: Container(
        key: _testId,
        padding: const EdgeInsets.all(TurniSpacing.md),
        decoration: BoxDecoration(
          color: bgColor,
          border: Border.all(color: iconColor.withAlpha(128)),
          borderRadius: BorderRadius.all(TurniRadius.md),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 18, color: iconColor),
                const SizedBox(width: TurniSpacing.sm),
                Expanded(
                  child: Text(
                    banner.message,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
            if (banner.kind == _BannerKind.adminRedirect &&
                banner.backofficeUrl != null &&
                banner.backofficeUrl!.isNotEmpty) ...[
              const SizedBox(height: TurniSpacing.xs),
              TextButton(
                onPressed: () => launchUrl(Uri.parse(banner.backofficeUrl!)),
                style: TextButton.styleFrom(
                  foregroundColor: TurniColors.infoLight,
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 36),
                ),
                child: const Text('Ir para o Backoffice →'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Key get _testId {
    switch (banner.kind) {
      case _BannerKind.error:
        return const ValueKey('login:error-banner');
      case _BannerKind.adminRedirect:
        return const ValueKey('login:admin-banner');
      case _BannerKind.pending:
        return const ValueKey('login:pending-banner');
      case _BannerKind.rejected:
        return const ValueKey('login:rejected-banner');
      case _BannerKind.throttle:
        return const ValueKey('login:throttle-banner');
    }
  }
}
