import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../ds/tokens.dart';
import '../auth/auth_service.dart';

/// Tela de welcome pós-aprovação (STORY-022 — SCREEN-STORY-022-welcome).
///
/// Primeira tela que o usuário recém-aprovado vê. Destino do funnel guard para
/// `status=liberado, welcome_seen_at=null`. Saudação personalizada + lista do que
/// será pedido no completar cadastro (adaptada ao papel), CTA "Vamos lá" (marca
/// welcome_visto e segue a /completar-cadastro) e link "Fazer depois" (logout sem
/// marcar — força consciência do checkpoint). Tema por papel (DDR-001).
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool _loading = false;
  bool _error = false;

  UserSession? get _session => AuthService().session;
  bool get _isAtivo => _session?.status == 'ativo';
  bool get _isContratante => _session?.role == 'contratante';

  // Bullets do que será pedido no completar cadastro (domain/usuario.md), por papel.
  List<String> get _bullets => _isContratante
      ? const [
          'O CNPJ do estabelecimento',
          'O endereço completo',
          'Um pouco da cultura do lugar',
        ]
      : const [
          'Seu documento (CPF ou CNPJ)',
          'Sua chave Pix para receber',
          'Uma foto de comprovante',
        ];

  Future<void> _vamosLa() async {
    setState(() {
      _loading = true;
      _error = false;
    });

    final ok = await AuthService().markWelcomeSeen();
    if (!mounted) return;

    if (ok) {
      context.go('/completar-cadastro');
    } else {
      setState(() {
        _loading = false;
        _error = true;
      });
    }
  }

  Future<void> _fazerDepois() async {
    // Logout limpo SEM marcar welcome_visto — no próximo login o usuário vê o
    // welcome de novo (CA-5). Não é atalho para /completar-cadastro.
    await AuthService().logout();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= 840;

    final surfacePage = isDark
        ? TurniColors.surfacePageDark
        : TurniColors.surfacePageLight;

    final content = _isAtivo
        ? _AlreadyActive(isDark: isDark)
        : _WelcomeBody(
            firstName: _session?.firstName ?? '',
            bullets: _bullets,
            accent: _Accent.of(isContratante: _isContratante, isDark: isDark),
            loading: _loading,
            showError: _error,
            onVamosLa: _vamosLa,
            onFazerDepois: _fazerDepois,
          );

    return Scaffold(
      key: const Key('screen-welcome'),
      backgroundColor: surfacePage,
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: TurniSpacing.lg,
            vertical: isDesktop ? TurniSpacing.x3l : TurniSpacing.x2l,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: isDesktop
                ? Card(
                    child: Padding(
                      padding: const EdgeInsets.all(TurniSpacing.x2l),
                      child: content,
                    ),
                  )
                : content,
          ),
        ),
      ),
    );
  }
}

/// Conjunto de cores de acento resolvido por papel + tema (DDR-001).
class _Accent {
  const _Accent({required this.cta, required this.onCta, required this.link});

  final Color cta; // fundo do CTA primário
  final Color onCta; // texto sobre o CTA
  final Color link; // texto-link e marcador de bullet

  factory _Accent.of({required bool isContratante, required bool isDark}) {
    if (isContratante) {
      return _Accent(
        cta: isDark
            ? TurniColors.contratanteAccentDark
            : TurniColors.contratanteAccentLight,
        onCta: isDark ? TurniColors.onAccentDark : TurniColors.onAccentLight,
        link: isDark
            ? TurniColors.contratanteAccentDark
            : TurniColors.contratanteAccentInkLight,
      );
    }
    return _Accent(
      cta: isDark ? TurniColors.accentDark : TurniColors.accentLight,
      onCta: isDark ? TurniColors.onAccentDark : TurniColors.onAccentLight,
      link: isDark ? TurniColors.accentDark : TurniColors.accentLight,
    );
  }
}

class _WelcomeBody extends StatelessWidget {
  const _WelcomeBody({
    required this.firstName,
    required this.bullets,
    required this.accent,
    required this.loading,
    required this.showError,
    required this.onVamosLa,
    required this.onFazerDepois,
  });

  final String firstName;
  final List<String> bullets;
  final _Accent accent;
  final bool loading;
  final bool showError;
  final VoidCallback onVamosLa;
  final VoidCallback onFazerDepois;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textStrong = isDark
        ? TurniColors.textStrongDark
        : TurniColors.textStrongLight;
    final textMuted = isDark
        ? TurniColors.textMutedDark
        : TurniColors.textMutedLight;

    final headline = firstName.isEmpty
        ? 'Boas-vindas!'
        : 'Bem-vindo(a), $firstName!';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Brand(),
        const SizedBox(height: TurniSpacing.xl),
        Semantics(
          header: true,
          child: Text(
            headline,
            key: const Key('welcome-headline'),
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w600,
              height: 1.15,
              color: textStrong,
            ),
          ),
        ),
        const SizedBox(height: TurniSpacing.md),
        Text(
          'Tudo certo, seu cadastro foi aprovado. Falta só completar seu perfil '
          '— leva uns 5 minutos.',
          style: TextStyle(fontSize: 16, color: textMuted, height: 1.5),
        ),
        const SizedBox(height: TurniSpacing.xl),
        Text(
          'Vamos pedir:',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 1,
            color: textMuted,
          ),
        ),
        const SizedBox(height: TurniSpacing.sm + TurniSpacing.xs),
        _Bullets(items: bullets, marker: accent.link, textColor: textStrong),
        const SizedBox(height: TurniSpacing.xl),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton(
            key: const Key('btn-vamos-la'),
            onPressed: loading ? null : onVamosLa,
            style: FilledButton.styleFrom(
              backgroundColor: accent.cta,
              foregroundColor: accent.onCta,
              shape: const StadiumBorder(),
            ),
            child: loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    'Vamos lá',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
          ),
        ),
        const SizedBox(height: TurniSpacing.xs),
        Center(
          child: TextButton(
            key: const Key('link-fazer-depois'),
            onPressed: loading ? null : onFazerDepois,
            style: TextButton.styleFrom(
              foregroundColor: textMuted,
              minimumSize: const Size(0, 48),
            ),
            child: const Text('Fazer depois'),
          ),
        ),
        if (showError) ...[
          const SizedBox(height: TurniSpacing.md),
          _ErrorBanner(isDark: isDark),
        ],
      ],
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Turni',
      header: true,
      child: const Text(
        'TURNI.',
        key: Key('welcome-brand'),
        style: TextStyle(
          fontFamily: 'BebasNeue',
          fontSize: 48,
          fontWeight: FontWeight.w400,
          color: TurniColors.brandGreen,
          height: 1.0,
        ),
      ),
    );
  }
}

class _Bullets extends StatelessWidget {
  const _Bullets({
    required this.items,
    required this.marker,
    required this.textColor,
  });

  final List<String> items;
  final Color marker;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('welcome-bullets'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: TurniSpacing.sm + 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Marcador decorativo — excluído da semântica (o texto basta).
                ExcludeSemantics(
                  child: Container(
                    margin: const EdgeInsets.only(
                      top: 9,
                      right: TurniSpacing.sm + 4,
                    ),
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: marker,
                      borderRadius: BorderRadius.all(TurniRadius.full),
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    item,
                    style: TextStyle(
                      fontSize: 16,
                      color: textColor,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? TurniColors.errorSoftDark : TurniColors.errorSoftLight;
    final fg = isDark ? TurniColors.errorDark : TurniColors.errorLight;

    return Semantics(
      liveRegion: true,
      child: Container(
        key: const Key('banner-welcome-erro'),
        padding: const EdgeInsets.all(TurniSpacing.md),
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: fg.withAlpha(128)),
          borderRadius: BorderRadius.all(TurniRadius.md),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline, size: 18, color: fg),
            const SizedBox(width: TurniSpacing.sm),
            const Expanded(
              child: Text(
                'Não conseguimos seguir agora. Tentar de novo.',
                style: TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Acesso direto a /welcome por usuário já `ativo` (CA-6): informa e oferece a home.
class _AlreadyActive extends StatelessWidget {
  const _AlreadyActive({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final textStrong = isDark
        ? TurniColors.textStrongDark
        : TurniColors.textStrongLight;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Brand(),
        const SizedBox(height: TurniSpacing.xl),
        Text(
          'Boas-vindas de volta.',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w600,
            color: textStrong,
          ),
        ),
        const SizedBox(height: TurniSpacing.lg),
        Semantics(
          liveRegion: true,
          child: Container(
            key: const Key('banner-already-active'),
            padding: const EdgeInsets.all(TurniSpacing.md),
            decoration: BoxDecoration(
              color: TurniColors.infoSoftLight,
              border: Border.all(color: TurniColors.infoLight.withAlpha(128)),
              borderRadius: BorderRadius.all(TurniRadius.md),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline,
                  size: 18,
                  color: TurniColors.infoLight,
                ),
                const SizedBox(width: TurniSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Você já está com o cadastro completo.',
                        style: TextStyle(fontSize: 13),
                      ),
                      const SizedBox(height: TurniSpacing.xs),
                      TextButton(
                        key: const Key('link-home'),
                        onPressed: () => context.go('/'),
                        style: TextButton.styleFrom(
                          foregroundColor: TurniColors.infoLight,
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 48),
                        ),
                        child: const Text('Ir para a home'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
