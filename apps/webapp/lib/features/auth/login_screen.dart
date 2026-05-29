import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../ds/tokens.dart';
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

    return Scaffold(
      key: const Key('screen-login-webapp'),
      backgroundColor: surfacePage,
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: TurniSpacing.lg,
            vertical: isDesktop ? TurniSpacing.x3l : TurniSpacing.x2l,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: isDesktop
                ? Card(
                    child: Padding(
                      padding: const EdgeInsets.all(TurniSpacing.xl),
                      child: _LoginForm(
                        formKey: _formKey,
                        emailCtrl: _emailCtrl,
                        passwordCtrl: _passwordCtrl,
                        obscurePassword: _obscurePassword,
                        loading: _loading,
                        banner: _banner,
                        accent: accent,
                        isDark: isDark,
                        onTogglePassword: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                        onSubmit: _submit,
                      ),
                    ),
                  )
                : _LoginForm(
                    formKey: _formKey,
                    emailCtrl: _emailCtrl,
                    passwordCtrl: _passwordCtrl,
                    obscurePassword: _obscurePassword,
                    loading: _loading,
                    banner: _banner,
                    accent: accent,
                    isDark: isDark,
                    onTogglePassword: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                    onSubmit: _submit,
                  ),
          ),
        ),
      ),
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
          // Logomarca
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
            key: const Key('input-email'),
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
            key: const Key('input-password'),
            controller: passwordCtrl,
            obscureText: obscurePassword,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => onSubmit(),
            decoration: InputDecoration(
              labelText: 'Senha',
              suffixIcon: Tooltip(
                message: obscurePassword ? 'Mostrar senha' : 'Ocultar senha',
                child: IconButton(
                  key: const Key('btn-toggle-password'),
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
              key: const Key('link-forgot-password'),
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
              key: const Key('btn-submit-login'),
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
                      key: const Key('link-criar-conta'),
                      onPressed: () => context.go('/cadastro/profissional'),
                      style: TextButton.styleFrom(
                        foregroundColor: isDark
                            ? TurniColors.accentDark
                            : TurniColors.accentLight,
                      ),
                      child: const Text('Criar conta de profissional'),
                    ),
                    TextButton(
                      key: const Key('link-criar-conta-contratante'),
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
        return const Key('banner-error');
      case _BannerKind.adminRedirect:
        return const Key('banner-admin-redirect');
      case _BannerKind.pending:
        return const Key('banner-pending');
      case _BannerKind.rejected:
        return const Key('banner-rejected');
      case _BannerKind.throttle:
        return const Key('banner-throttle');
    }
  }
}
