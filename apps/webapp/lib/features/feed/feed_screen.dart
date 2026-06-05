import 'package:flutter/material.dart';

import 'package:go_router/go_router.dart';

import '../../core/format/brl.dart';
import '../../core/time/turni_datetime.dart';
import '../../ds/tokens.dart';
import '../auth/auth_service.dart';
import '../notificacoes/notificacoes_controller.dart';
import '../notificacoes/notificacoes_painel.dart';
import '../notificacoes/notificacoes_sino.dart';
import '../turno/turno_ativo_acao.dart';
import 'feed_service.dart';

/// STORY-048 / SCREEN-STORY-048 — feed do profissional: lista ranqueada por match (CA-1/CA-3)
/// com filtros que re-buscam sem reload (CA-5), score numérico + barra em cada card (CA-5),
/// distância, e botão de candidatar desabilitado pelo gate PDR-005 (CA-8). É a home do
/// profissional. RBAC (CA-1): contratante (403) cai em "sem permissão". Tocar no card abre o
/// detalhe (STORY-049, placeholder até lá).
class FeedScreen extends StatefulWidget {
  const FeedScreen({
    super.key,
    FeedService? service,
    AuthService? auth,
    this.filtroInicial,
  }) : _service = service,
       _auth = auth;

  final FeedService? _service;
  final AuthService? _auth;

  /// Filtro inicial (deep-link `?filtro=`); senão "todas".
  final String? filtroInicial;

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

enum _Phase { loading, semPermissao, erro, pronto }

class _FeedScreenState extends State<FeedScreen> {
  late final FeedService _service = widget._service ?? FeedService();
  late final AuthService _auth = widget._auth ?? AuthService();
  final ScrollController _scroll = ScrollController();

  _Phase _phase = _Phase.loading;
  List<FeedVagaResumo> _vagas = const [];
  late FeedFiltro _filtro;
  int _page = 1;
  bool _hasNext = false;
  bool _loadingMore = false;

  @override
  void initState() {
    super.initState();
    _filtro = FeedFiltro.fromSlug(widget.filtroInicial);
    _scroll.addListener(_onScroll);
    _load();
    // STORY-053 (CA-8) — contagem de não-lidas para o badge do sino.
    NotificacoesController.instance.carregarContagem();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Gate PDR-005 (CA-8): uniforme por request — se a 1ª vaga não pode candidatar, todas
  /// estão sob o gate. Dispara a faixa de aviso e desabilita os botões.
  bool get _gateAtivo => _vagas.isNotEmpty && !_vagas.first.podeCandidatar;

  Future<void> _logout() async {
    await _auth.logout();
    if (mounted) context.go('/login');
  }

  /// Primeira carga / troca de filtro / retry: reinicia a paginação (página 1).
  Future<void> _load() async {
    setState(() {
      _phase = _Phase.loading;
      _page = 1;
    });
    final result = await _service.fetch(filtro: _filtro, page: 1);
    if (!mounted) return;
    setState(() {
      switch (result) {
        case FeedSuccess(:final vagas, :final hasNext):
          _vagas = vagas;
          _hasNext = hasNext;
          _phase = _Phase.pronto;
        case FeedForbidden():
          _phase = _Phase.semPermissao;
        case FeedError():
          _phase = _Phase.erro;
      }
    });
  }

  void _onScroll() {
    if (!_hasNext || _loadingMore || _phase != _Phase.pronto) return;
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 240) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    setState(() => _loadingMore = true);
    final result = await _service.fetch(filtro: _filtro, page: _page + 1);
    if (!mounted) return;
    setState(() {
      _loadingMore = false;
      if (result is FeedSuccess) {
        _vagas = [..._vagas, ...result.vagas];
        _page = result.page;
        _hasNext = result.hasNext;
      }
    });
  }

  void _setFiltro(FeedFiltro filtro) {
    if (filtro == _filtro) return;
    setState(() => _filtro = filtro);
    _load();
  }

  Color _accent(bool isDark) =>
      isDark ? TurniColors.accentDark : TurniColors.accentLight;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = _accent(isDark);
    final surfacePage = isDark
        ? TurniColors.surfacePageDark
        : TurniColors.surfacePageLight;

    return Scaffold(
      key: const Key('feed-screen'),
      backgroundColor: surfacePage,
      appBar: AppBar(
        title: const Text('Vagas para você'),
        actions: [
          const TurnoAtivoAcao(),
          const NotificacoesSino(),
          IconButton(
            key: const Key('feed-logout-btn'),
            tooltip: 'Sair',
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      endDrawer: const NotificacoesPainel(),
      body: SafeArea(child: _body(isDark, accent)),
    );
  }

  Widget _body(bool isDark, Color accent) {
    switch (_phase) {
      case _Phase.loading:
        return _skeleton(isDark);
      case _Phase.semPermissao:
        return _SemPermissaoView(accent: accent);
      case _Phase.erro:
        return _ErroView(isDark: isDark, onRetry: _load);
      case _Phase.pronto:
        return _conteudo(isDark, accent);
    }
  }

  Widget _skeleton(bool isDark) => ListView(
    key: const Key('feed-skeleton'),
    padding: const EdgeInsets.all(TurniSpacing.md),
    children: List.generate(
      3,
      (_) => Padding(
        padding: const EdgeInsets.only(bottom: TurniSpacing.md),
        child: _SkeletonCard(isDark: isDark),
      ),
    ),
  );

  Widget _conteudo(bool isDark, Color accent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_gateAtivo) _GateBanner(isDark: isDark),
        _filtrosRow(accent),
        Expanded(
          child: _vagas.isEmpty
              ? (_filtro == FeedFiltro.todas
                    ? const _VazioView()
                    : _VazioFiltroView(
                        filtro: _filtro,
                        onVerTodas: () => _setFiltro(FeedFiltro.todas),
                      ))
              : _lista(isDark, accent),
        ),
      ],
    );
  }

  Widget _filtrosRow(Color accent) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.symmetric(
      horizontal: TurniSpacing.md,
      vertical: TurniSpacing.sm,
    ),
    child: Row(
      children: FeedFiltro.values
          .map(
            (f) => Padding(
              padding: const EdgeInsets.only(right: TurniSpacing.sm),
              child: ChoiceChip(
                key: Key('feed-filtro-${f.slug}'),
                label: Text(f.label),
                selected: _filtro == f,
                selectedColor: accent,
                labelStyle: TextStyle(
                  color: _filtro == f ? Colors.white : null,
                  fontWeight: _filtro == f ? FontWeight.w600 : null,
                ),
                onSelected: (_) => _setFiltro(f),
              ),
            ),
          )
          .toList(growable: false),
    ),
  );

  Widget _lista(bool isDark, Color accent) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = TurniSpacing.md;
        final disponivel = constraints.maxWidth - TurniSpacing.md * 2;
        final duasColunas = constraints.maxWidth >= 940;
        final cardW = duasColunas ? (disponivel - gap) / 2 : disponivel;
        return SingleChildScrollView(
          controller: _scroll,
          key: const Key('feed-lista'),
          padding: const EdgeInsets.fromLTRB(
            TurniSpacing.md,
            0,
            TurniSpacing.md,
            TurniSpacing.lg,
          ),
          child: Column(
            children: [
              Wrap(
                spacing: gap,
                runSpacing: gap,
                children: _vagas
                    .map(
                      (v) => SizedBox(
                        width: cardW,
                        child: _FeedCard(
                          vaga: v,
                          isDark: isDark,
                          accent: accent,
                          onAbrir: () => context.go('/vaga/${v.id}'),
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
              if (_loadingMore)
                Padding(
                  key: const Key('feed-skeleton-proxima'),
                  padding: const EdgeInsets.only(top: TurniSpacing.md),
                  child: _SkeletonCard(isDark: isDark),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ───────────────────────── Card do feed ─────────────────────────

class _FeedCard extends StatelessWidget {
  const _FeedCard({
    required this.vaga,
    required this.isDark,
    required this.accent,
    required this.onAbrir,
  });

  final FeedVagaResumo vaga;
  final bool isDark;
  final Color accent;
  final VoidCallback onAbrir;

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? TurniColors.surfaceDark : TurniColors.surfaceLight;
    final border = isDark
        ? TurniColors.borderSubtleDark
        : TurniColors.borderSubtleLight;
    final textStrong = isDark
        ? TurniColors.textStrongDark
        : TurniColors.textStrongLight;
    final textMuted = isDark
        ? TurniColors.textMutedDark
        : TurniColors.textMutedLight;

    return Semantics(
      button: true,
      label: 'Ver vaga de ${vaga.funcao}, match ${vaga.score.total} de 100',
      child: Material(
        color: surface,
        borderRadius: const BorderRadius.all(TurniRadius.md),
        child: InkWell(
          key: Key('feed-card-${vaga.id}'),
          onTap: onAbrir,
          borderRadius: const BorderRadius.all(TurniRadius.md),
          child: Container(
            padding: const EdgeInsets.all(TurniSpacing.md),
            decoration: BoxDecoration(
              border: Border.all(color: border),
              borderRadius: const BorderRadius.all(TurniRadius.md),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MergeSemantics(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              vaga.funcao,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: textStrong,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              TurniDateTime.formatIntervalo(
                                vaga.dataInicio,
                                vaga.dataFim,
                              ),
                              style: TextStyle(fontSize: 14, color: textMuted),
                            ),
                          ],
                        ),
                      ),
                      _ScoreChip(
                        vagaId: vaga.id,
                        total: vaga.score.total,
                        accent: accent,
                        isDark: isDark,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: TurniSpacing.sm),
                Text(
                  _linhaValor(vaga),
                  style: TextStyle(fontSize: 15, color: textStrong),
                ),
                // STORY-052 CA-11 — selo informativo: a vaga que ele se candidatou foi editada.
                // O quê exatamente mudou fica no detalhe (toque no card abre lá).
                if (vaga.emRevisao) ...[
                  const SizedBox(height: TurniSpacing.sm),
                  _SeloRevisao(vagaId: vaga.id, isDark: isDark),
                ],
                const SizedBox(height: 12),
                _ScoreBar(
                  vagaId: vaga.id,
                  total: vaga.score.total,
                  accent: accent,
                  isDark: isDark,
                ),
                const SizedBox(height: TurniSpacing.md),
                _CandidatarButton(vaga: vaga, accent: accent, onAbrir: onAbrir),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// match.scorechip — número de match no canto do card (⬢ + número).
/// STORY-052 CA-11 — selo "Vaga editada — confirme" no card de uma vaga candidatada em revisão
/// pós-edição. Apenas informa (cor de atenção, ícone ✎); o diff + Manter/Retirar ficam no detalhe.
class _SeloRevisao extends StatelessWidget {
  const _SeloRevisao({required this.vagaId, required this.isDark});

  final String vagaId;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? TurniColors.warnSoftDark : TurniColors.warnSoftLight;
    final ink = isDark
        ? TurniColors.contratanteAccentDark
        : TurniColors.contratanteAccentInkLight;
    return Container(
      key: Key('feed-card-revisao-$vagaId'),
      padding: const EdgeInsets.symmetric(
        horizontal: TurniSpacing.sm,
        vertical: TurniSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.all(TurniRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.edit_calendar_outlined, size: 15, color: ink),
          const SizedBox(width: TurniSpacing.xs),
          Text(
            'Vaga editada — confirme',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreChip extends StatelessWidget {
  const _ScoreChip({
    required this.vagaId,
    required this.total,
    required this.accent,
    required this.isDark,
  });

  final String vagaId;
  final int total;
  final Color accent;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final soft = isDark ? const Color(0x265FA37C) : const Color(0xFFE5F0E8);
    return Container(
      key: Key('feed-card-$vagaId-score'),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
      decoration: BoxDecoration(
        color: soft,
        borderRadius: const BorderRadius.all(TurniRadius.full),
        border: Border.all(color: accent.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.hexagon, size: 13, color: accent),
          const SizedBox(width: 5),
          Text(
            '$total',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: accent,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

/// match.scorebar — barra 0–100 + número + selo "Alto match" (≥80). Score nunca só por cor.
class _ScoreBar extends StatelessWidget {
  const _ScoreBar({
    required this.vagaId,
    required this.total,
    required this.accent,
    required this.isDark,
  });

  final String vagaId;
  final int total;
  final Color accent;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final track = isDark
        ? TurniColors.borderSubtleDark
        : TurniColors.borderSubtleLight;
    final textMuted = isDark
        ? TurniColors.textMutedDark
        : TurniColors.textMutedLight;
    final textStrong = isDark
        ? TurniColors.textStrongDark
        : TurniColors.textStrongLight;

    return Row(
      children: [
        Text(
          'match',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: textMuted,
          ),
        ),
        const SizedBox(width: TurniSpacing.sm),
        Expanded(
          child: Semantics(
            label: 'Match $total de 100',
            value: '$total',
            child: Container(
              key: Key('feed-card-$vagaId-score-bar'),
              height: 8,
              decoration: BoxDecoration(
                color: track,
                borderRadius: const BorderRadius.all(TurniRadius.full),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: (total / 100).clamp(0.0, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: const BorderRadius.all(TurniRadius.full),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: TurniSpacing.sm),
        Text(
          '$total/100',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: textStrong,
          ),
        ),
        if (total >= 80) ...[
          const SizedBox(width: TurniSpacing.sm),
          _AltoMatchBadge(vagaId: vagaId),
        ],
      ],
    );
  }
}

class _AltoMatchBadge extends StatelessWidget {
  const _AltoMatchBadge({required this.vagaId});

  final String vagaId;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('feed-card-$vagaId-alto-match'),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: TurniColors.successSoftLight,
        borderRadius: const BorderRadius.all(TurniRadius.full),
        border: Border.all(color: const Color(0xFF9CC7AD)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check, size: 12, color: Color(0xFF1D5235)),
          SizedBox(width: 3),
          Text(
            'Alto match',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1D5235),
            ),
          ),
        ],
      ),
    );
  }
}

/// Botão "Candidatar-se" — desabilitado pelo gate PDR-005 com tooltip (CA-8). A candidatura
/// em si é STORY-050; aqui abre o detalhe (placeholder do fluxo).
class _CandidatarButton extends StatelessWidget {
  const _CandidatarButton({
    required this.vaga,
    required this.accent,
    required this.onAbrir,
  });

  final FeedVagaResumo vaga;
  final Color accent;
  final VoidCallback onAbrir;

  @override
  Widget build(BuildContext context) {
    // Já candidatou (STORY-050): o card mostra um selo no lugar do botão; tocar abre o
    // detalhe (onde dá para ver o status e retirar). Espelha o badge da tela de detalhe.
    if (vaga.jaCandidatou) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final bg = isDark
          ? const Color(0x265FA37C)
          : TurniColors.successSoftLight;
      final fg = isDark ? const Color(0xFF7FBF9A) : const Color(0xFF1D5235);
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          key: Key('feed-card-${vaga.id}-ja-candidatou'),
          onPressed: onAbrir,
          icon: Icon(Icons.check_circle, size: 18, color: fg),
          label: const Text('Você já se candidatou'),
          style: OutlinedButton.styleFrom(
            foregroundColor: fg,
            backgroundColor: bg,
            side: BorderSide(color: fg.withValues(alpha: 0.4)),
            minimumSize: const Size(0, 48),
            shape: const StadiumBorder(),
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      );
    }

    final habilitado = vaga.podeCandidatar;
    final botao = SizedBox(
      width: double.infinity,
      child: FilledButton(
        key: Key('feed-card-${vaga.id}-candidatar-btn'),
        onPressed: habilitado ? onAbrir : null,
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 48),
          shape: const StadiumBorder(),
        ),
        child: const Text('Candidatar-se'),
      ),
    );

    if (habilitado) return botao;

    return Tooltip(
      message: 'Avalie seu último turno para se candidatar',
      child: Semantics(
        enabled: false,
        label: 'Candidatar-se. Avalie seu último turno para se candidatar',
        child: botao,
      ),
    );
  }
}

// ───────────────────────── Faixa de gate (PDR-005) ─────────────────────────

class _GateBanner extends StatelessWidget {
  const _GateBanner({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? TurniColors.warnSoftDark : TurniColors.warnSoftLight;
    final fg = isDark
        ? TurniColors.warnDark
        : TurniColors.contratanteAccentInkLight;

    return Semantics(
      liveRegion: true,
      child: Container(
        key: const Key('feed-gate-banner'),
        margin: const EdgeInsets.fromLTRB(
          TurniSpacing.md,
          TurniSpacing.md,
          TurniSpacing.md,
          0,
        ),
        padding: const EdgeInsets.all(TurniSpacing.md),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.all(TurniRadius.md),
          border: Border.all(color: fg.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded, size: 20, color: fg),
            const SizedBox(width: TurniSpacing.sm),
            Expanded(
              child: Text(
                'Avalie seu último turno para voltar a se candidatar.',
                style: TextStyle(color: fg, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── Estados auxiliares ─────────────────────────

class _VazioView extends StatelessWidget {
  const _VazioView();

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const Key('feed-vazio'),
      child: Padding(
        padding: const EdgeInsets.all(TurniSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search, size: 48),
            const SizedBox(height: TurniSpacing.md),
            Text(
              'Nenhuma vaga por aqui ainda',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: TurniSpacing.sm),
            const Text(
              'Assim que surgir uma vaga na sua função e na sua região, ela aparece aqui.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _VazioFiltroView extends StatelessWidget {
  const _VazioFiltroView({required this.filtro, required this.onVerTodas});

  final FeedFiltro filtro;
  final VoidCallback onVerTodas;

  String get _msg => switch (filtro) {
    FeedFiltro.minhaFuncao => 'Nenhuma vaga na sua função primária agora.',
    FeedFiltro.altoMatch => 'Nenhuma vaga com alto match agora.',
    FeedFiltro.candidatadas => 'Você ainda não se candidatou a nenhuma vaga.',
    FeedFiltro.todas => 'Nenhuma vaga por aqui ainda.',
  };

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).brightness == Brightness.dark
        ? TurniColors.accentDark
        : TurniColors.accentLight;
    return Center(
      key: const Key('feed-vazio-filtro'),
      child: Padding(
        padding: const EdgeInsets.all(TurniSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_msg, textAlign: TextAlign.center),
            const SizedBox(height: TurniSpacing.md),
            OutlinedButton(
              key: const Key('feed-vazio-filtro-todas-btn'),
              onPressed: onVerTodas,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: accent),
                foregroundColor: accent,
                shape: const StadiumBorder(),
              ),
              child: const Text('Ver todas as vagas'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErroView extends StatelessWidget {
  const _ErroView({required this.isDark, required this.onRetry});

  final bool isDark;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? TurniColors.errorSoftDark : TurniColors.errorSoftLight;
    final fg = isDark ? TurniColors.errorDark : TurniColors.errorLight;

    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        key: const Key('feed-erro-banner'),
        margin: const EdgeInsets.all(TurniSpacing.md),
        padding: const EdgeInsets.all(TurniSpacing.md),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.all(TurniRadius.md),
          border: Border.all(color: fg.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Não foi possível carregar as vagas. Verifique sua conexão.',
                style: TextStyle(color: fg),
              ),
            ),
            TextButton(
              key: const Key('feed-retry-btn'),
              onPressed: onRetry,
              child: const Text('Tentar de novo'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SemPermissaoView extends StatelessWidget {
  const _SemPermissaoView({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const Key('feed-sem-permissao'),
      child: Padding(
        padding: const EdgeInsets.all(TurniSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 48),
            const SizedBox(height: TurniSpacing.md),
            Text(
              'Esta área é do profissional',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: TurniSpacing.sm),
            const Text(
              'O feed de vagas é de quem pega turnos. Sua conta é de contratante.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: TurniSpacing.lg),
            FilledButton(
              onPressed: () => context.go('/'),
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
              ),
              child: const Text('Voltar ao início'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? TurniColors.surfaceDark : TurniColors.surfaceLight;
    final bar = isDark
        ? TurniColors.borderSubtleDark
        : TurniColors.borderSubtleLight;
    Widget line(double w, {double h = 12}) => Container(
      width: w,
      height: h,
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: bar,
        borderRadius: BorderRadius.circular(6),
      ),
    );
    return ExcludeSemantics(
      child: Container(
        padding: const EdgeInsets.all(TurniSpacing.md),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: const BorderRadius.all(TurniRadius.md),
          border: Border.all(color: bar),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [line(140), line(200), line(double.infinity, h: 8)],
        ),
      ),
    );
  }
}

// ───────────────────────── Formatação pt-BR / 24h (DDR-002) ─────────────────────────
// Formatação monetária promovida a core/format/brl.dart (4º uso — STORY-058).

/// "R$ 150,00 · turno" ou "R$ 150,00 · turno · a 3 km" (distância só quando há geo).
String _linhaValor(FeedVagaResumo v) {
  final base = '${formatBRL(v.valor)} · turno';
  final d = v.distanciaKm;
  if (d == null) return base;
  final dist = d < 1 ? 'a menos de 1 km' : 'a ${d.round()} km';
  return '$base · $dist';
}
