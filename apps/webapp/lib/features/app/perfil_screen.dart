import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/theme_mode_controller.dart';
import '../../ds/components/reputacao_views.dart';
import '../../ds/components/state_views.dart';
import '../../ds/tokens.dart';
import '../auth/auth_service.dart';
import 'perfil_reputacao_service.dart';

/// Destino "Perfil" do shell (DDR-003) + reputação visível do EPIC-004 (STORY-088, T3).
/// Identidade do usuário, **bloco de reputação** (score/nível/XP/depoimentos — reciprocidade:
/// contratante sem nível/XP), e abaixo as Preferências (tema) e Sair. A reputação é só leitura:
/// o front consome o que o motor já recomputou (STORY-085); um erro na reputação não derruba
/// Preferências/Sair (CA-5).
class PerfilScreen extends StatefulWidget {
  const PerfilScreen({super.key, PerfilReputacaoService? reputacaoService})
    : _reputacaoService = reputacaoService;

  final PerfilReputacaoService? _reputacaoService;

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  late final PerfilReputacaoService _service =
      widget._reputacaoService ?? PerfilReputacaoService();

  Future<ReputacaoResult>? _carga;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final id = AuthService().session?.id ?? '';
    setState(() {
      // Sessão antiga sem id (pré-STORY-088): não dá p/ montar /api/perfil/{id} → erro recuperável.
      _carga = id.isEmpty ? Future.value(ReputacaoErro()) : _service.fetch(id);
    });
  }

  Future<void> _logout(BuildContext context) async {
    await AuthService().logout();
    if (context.mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final session = AuthService().session;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final role = session?.role ?? 'profissional';
    final accent = _accentFor(isDark, role);
    final textMuted = isDark
        ? TurniColors.textMutedDark
        : TurniColors.textMutedLight;

    final nome = session?.name.trim() ?? '';
    final papel = role == 'contratante' ? 'Contratante' : 'Profissional';

    return Scaffold(
      key: const Key('perfil-screen'),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(TurniSpacing.lg),
          children: [
            // Identidade
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: accent.withValues(alpha: 0.16),
                  child: Text(
                    _initials(nome),
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w600,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(width: TurniSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (nome.isNotEmpty)
                        Text(
                          nome,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      Text(papel, style: TextStyle(color: textMuted)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: TurniSpacing.lg),

            // Reputação (T3) — score/nível/XP/depoimentos.
            _ReputacaoBloco(carga: _carga, accent: accent, onRetry: _load),
            const Divider(height: TurniSpacing.x2l),

            // Preferências — alternância de tema
            Text(
              'Preferências',
              style: TextStyle(
                color: textMuted,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: TurniSpacing.sm),
            ListenableBuilder(
              listenable: ThemeModeController.instance,
              builder: (context, _) {
                final platform = MediaQuery.platformBrightnessOf(context);
                final dark = ThemeModeController.instance.isDark(platform);
                return SwitchListTile(
                  key: const Key('shell-theme-toggle'),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Tema escuro'),
                  subtitle: const Text('Acompanha o sistema por padrão'),
                  value: dark,
                  onChanged: (v) => ThemeModeController.instance.setDark(v),
                );
              },
            ),
            const Divider(height: TurniSpacing.xl),

            // Sair
            OutlinedButton.icon(
              key: const Key('perfil-logout'),
              onPressed: () => _logout(context),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: accent),
                foregroundColor: accent,
                minimumSize: const Size.fromHeight(48),
              ),
              icon: const Icon(Icons.logout),
              label: const Text('Sair da conta'),
            ),
          ],
        ),
      ),
    );
  }

  static Color _accentFor(bool isDark, String role) => role == 'contratante'
      ? (isDark
            ? TurniColors.contratanteAccentDark
            : TurniColors.contratanteAccentLight)
      : (isDark ? TurniColors.accentDark : TurniColors.accentLight);

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }
}

/// Bloco de reputação: resolve [carga] em loading (skeleton) / erro (retry local, sem derrubar
/// o resto do Perfil) / conteúdo (resumo + depoimentos). Variante por papel vem do próprio
/// payload (contratante não traz nível/XP).
class _ReputacaoBloco extends StatelessWidget {
  const _ReputacaoBloco({
    required this.carga,
    required this.accent,
    required this.onRetry,
  });

  final Future<ReputacaoResult>? carga;
  final Color accent;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ReputacaoResult>(
      future: carga,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const _ReputacaoSkeleton();
        }
        final result = snap.data;
        if (result is ReputacaoCarregada) {
          return _ReputacaoConteudo(perfil: result.perfil, accent: accent);
        }
        // Erro/404/rede — recuperável (inline; Preferências/Sair seguem abaixo).
        return _ReputacaoErro(accent: accent, onRetry: onRetry);
      },
    );
  }
}

class _ReputacaoSkeleton extends StatelessWidget {
  const _ReputacaoSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('perfil-reputacao-skeleton'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        TurniSkeletonBox(width: 180, height: 28),
        SizedBox(height: TurniSpacing.sm),
        TurniSkeletonBox(width: 120),
        SizedBox(height: TurniSpacing.lg),
        TurniSkeletonCard(),
        SizedBox(height: TurniSpacing.sm),
        TurniSkeletonCard(),
      ],
    );
  }
}

class _ReputacaoErro extends StatelessWidget {
  const _ReputacaoErro({required this.accent, required this.onRetry});

  final Color accent;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textStrong = isDark
        ? TurniColors.textStrongDark
        : TurniColors.textStrongLight;
    final textMuted = isDark
        ? TurniColors.textMutedDark
        : TurniColors.textMutedLight;
    final onAccent = TurniColors.onAccentFor(
      isDark ? Brightness.dark : Brightness.light,
    );

    return Container(
      padding: const EdgeInsets.all(TurniSpacing.lg),
      decoration: BoxDecoration(
        color: isDark ? TurniColors.surfaceDark : TurniColors.surfaceLight,
        borderRadius: const BorderRadius.all(TurniRadius.md),
        border: Border.all(
          color: isDark
              ? TurniColors.borderSubtleDark
              : TurniColors.borderSubtleLight,
        ),
      ),
      child: Column(
        children: [
          Icon(Icons.error_outline, color: textMuted),
          const SizedBox(height: TurniSpacing.sm),
          Text(
            'Não foi possível carregar a reputação.',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w600, color: textStrong),
          ),
          const SizedBox(height: TurniSpacing.md),
          FilledButton(
            key: const Key('perfil-reputacao-retry'),
            onPressed: onRetry,
            style: FilledButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: onAccent,
              minimumSize: const Size(0, 48),
              shape: const StadiumBorder(),
            ),
            child: const Text('Tentar de novo'),
          ),
        ],
      ),
    );
  }
}

class _ReputacaoConteudo extends StatelessWidget {
  const _ReputacaoConteudo({required this.perfil, required this.accent});

  final ReputacaoPerfil perfil;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textMuted = isDark
        ? TurniColors.textMutedDark
        : TurniColors.textMutedLight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Resumo (surface.card): score + nível + XP (prof).
        Container(
          padding: const EdgeInsets.all(TurniSpacing.md),
          decoration: BoxDecoration(
            color: isDark ? TurniColors.surfaceDark : TurniColors.surfaceLight,
            borderRadius: const BorderRadius.all(TurniRadius.md),
            border: Border.all(
              color: isDark
                  ? TurniColors.borderSubtleDark
                  : TurniColors.borderSubtleLight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: TurniRatingDisplay(
                      score: perfil.score,
                      totalAvaliacoes: perfil.totalAvaliacoes,
                      seloNovo: perfil.seloNovo,
                      accent: accent,
                    ),
                  ),
                  if (perfil.isProfissional && perfil.nivel != null) ...[
                    const SizedBox(width: TurniSpacing.sm),
                    TurniNivelBadge(nivel: perfil.nivel!),
                  ],
                ],
              ),
              if (perfil.temXp) ...[
                const SizedBox(height: TurniSpacing.md),
                TurniXpMeter(
                  xp: perfil.xp!,
                  xpProximoNivel: perfil.xpProximoNivel,
                  nivel: perfil.nivel ?? 'Iniciante',
                  accent: accent,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: TurniSpacing.lg),

        // Seção de depoimentos (section.group-header).
        Text(
          'DEPOIMENTOS',
          key: const Key('perfil-depoimentos'),
          style: TextStyle(
            color: textMuted,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: TurniSpacing.sm),
        if (perfil.depoimentos.isEmpty)
          _DepoimentosVazio(total: perfil.totalAvaliacoes)
        else
          Column(
            key: const Key('depoimento-list'),
            children: [
              for (var i = 0; i < perfil.depoimentos.length; i++) ...[
                if (i > 0) const SizedBox(height: TurniSpacing.sm),
                TurniDepoimentoCard(
                  key: Key('depoimento-item-$i'),
                  estrelas: perfil.depoimentos[i].estrelas,
                  comentario: perfil.depoimentos[i].comentario,
                  autorNome: perfil.depoimentos[i].autorNome,
                  funcao: perfil.depoimentos[i].funcao,
                  data: perfil.depoimentos[i].data,
                  accent: accent,
                ),
              ],
            ],
          ),
      ],
    );
  }
}

/// Vazio dos depoimentos (SCREEN-084 §4.3): sem nenhuma avaliação ("Complete turnos…") vs.
/// com score mas sem comentário ("As avaliações com comentário aparecem aqui.").
class _DepoimentosVazio extends StatelessWidget {
  const _DepoimentosVazio({required this.total});

  final int total;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textStrong = isDark
        ? TurniColors.textStrongDark
        : TurniColors.textStrongLight;
    final textMuted = isDark
        ? TurniColors.textMutedDark
        : TurniColors.textMutedLight;

    final semNenhuma = total == 0;
    final titulo = semNenhuma
        ? 'Ainda sem avaliações'
        : 'Ainda sem comentários';
    final msg = semNenhuma
        ? 'Complete turnos para receber suas primeiras avaliações.'
        : 'As avaliações com comentário aparecem aqui.';

    return Container(
      key: const Key('perfil-depoimentos-vazio'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: TurniSpacing.md,
        vertical: TurniSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: isDark ? TurniColors.surfaceDark : TurniColors.surfaceLight,
        borderRadius: const BorderRadius.all(TurniRadius.md),
        border: Border.all(
          color: isDark
              ? TurniColors.borderSubtleDark
              : TurniColors.borderSubtleLight,
        ),
      ),
      child: Column(
        children: [
          Icon(Icons.reviews_outlined, color: textMuted),
          const SizedBox(height: TurniSpacing.sm),
          Text(
            titulo,
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w700, color: textStrong),
          ),
          const SizedBox(height: TurniSpacing.xs),
          Text(
            msg,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: textMuted),
          ),
        ],
      ),
    );
  }
}
