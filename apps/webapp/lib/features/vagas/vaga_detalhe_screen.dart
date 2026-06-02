import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../ds/tokens.dart';
import 'vaga_detalhe_service.dart';

/// STORY-049 / SCREEN-STORY-049 — detalhe da vaga + breakdown explicável do match. Mostra o
/// cabeçalho da vaga e o bloco "Por que estou vendo esta vaga" com os 4 componentes (ícone,
/// barra, X/Y, prosa — CA-2/CA-3), o total agregado (CA-4) e o CTA "Candidatar-se" / estado
/// "Você já se candidatou" (CA-5/CA-6). RBAC (CA-7): contratante (403) cai em "sem permissão";
/// vaga indisponível (404) cai em estado próprio. A candidatura em si é STORY-050 (placeholder).
class VagaDetalheScreen extends StatefulWidget {
  const VagaDetalheScreen({
    super.key,
    required this.vagaId,
    VagaDetalheService? service,
  }) : _service = service;

  final int vagaId;
  final VagaDetalheService? _service;

  @override
  State<VagaDetalheScreen> createState() => _VagaDetalheScreenState();
}

enum _Phase { loading, semPermissao, indisponivel, erro, pronto }

class _VagaDetalheScreenState extends State<VagaDetalheScreen> {
  late final VagaDetalheService _service =
      widget._service ?? VagaDetalheService();

  _Phase _phase = _Phase.loading;
  VagaDetalhe? _vaga;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _phase = _Phase.loading);
    final result = await _service.fetch(widget.vagaId);
    if (!mounted) return;
    setState(() {
      switch (result) {
        case DetalheSuccess(:final vaga):
          _vaga = vaga;
          _phase = _Phase.pronto;
        case DetalheForbidden():
          _phase = _Phase.semPermissao;
        case DetalheNotFound():
          _phase = _Phase.indisponivel;
        case DetalheError():
          _phase = _Phase.erro;
      }
    });
  }

  void _voltar() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/feed');
    }
  }

  /// Placeholder de candidatura (STORY-050): registra a intenção e avisa. O fluxo real
  /// (1 toque + 3 gates) chega na próxima estória.
  void _candidatar() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Candidatura chega na próxima etapa.')),
    );
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
      key: const Key('vaga-detalhe-screen'),
      backgroundColor: surfacePage,
      appBar: AppBar(
        leading: IconButton(
          key: const Key('vaga-detalhe-voltar-btn'),
          tooltip: 'Voltar',
          icon: const Icon(Icons.arrow_back),
          onPressed: _voltar,
        ),
        title: const Text('Detalhe da vaga'),
      ),
      body: SafeArea(child: _body(isDark, accent)),
      bottomNavigationBar: _phase == _Phase.pronto
          ? _AcaoBar(
              vaga: _vaga!,
              accent: accent,
              isDark: isDark,
              onCandidatar: _candidatar,
            )
          : null,
    );
  }

  Widget _body(bool isDark, Color accent) {
    switch (_phase) {
      case _Phase.loading:
        return const _SkeletonView();
      case _Phase.semPermissao:
        return _SemPermissaoView(
          accent: accent,
          onVoltar: () => context.go('/'),
        );
      case _Phase.indisponivel:
        return _IndisponivelView(
          accent: accent,
          onVoltar: () => context.go('/feed'),
        );
      case _Phase.erro:
        return _ErroView(isDark: isDark, onRetry: _load);
      case _Phase.pronto:
        return _Conteudo(vaga: _vaga!, isDark: isDark, accent: accent);
    }
  }
}

// ───────────────────────── Conteúdo (caminho feliz) ─────────────────────────

class _Conteudo extends StatelessWidget {
  const _Conteudo({
    required this.vaga,
    required this.isDark,
    required this.accent,
  });

  final VagaDetalhe vaga;
  final bool isDark;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final largura = constraints.maxWidth >= 760
            ? 720.0
            : constraints.maxWidth;
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            TurniSpacing.md,
            TurniSpacing.md,
            TurniSpacing.md,
            TurniSpacing.lg,
          ),
          child: Center(
            child: SizedBox(
              width: largura,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Cabecalho(vaga: vaga, isDark: isDark, accent: accent),
                  const SizedBox(height: TurniSpacing.lg),
                  Text(
                    'Por que estou vendo esta vaga',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? TurniColors.textStrongDark
                          : TurniColors.textStrongLight,
                    ),
                  ),
                  const SizedBox(height: TurniSpacing.md),
                  Column(
                    key: const Key('vaga-detalhe-breakdown'),
                    children: [
                      for (final linha in vaga.score.linhas)
                        Padding(
                          padding: const EdgeInsets.only(
                            bottom: TurniSpacing.md,
                          ),
                          child: BreakdownRow(linha: linha, isDark: isDark),
                        ),
                    ],
                  ),
                  Divider(
                    color: isDark
                        ? TurniColors.borderSubtleDark
                        : TurniColors.borderSubtleLight,
                  ),
                  const SizedBox(height: TurniSpacing.sm),
                  _TotalRow(
                    total: vaga.score.total,
                    isDark: isDark,
                    accent: accent,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ───────────────────────── Cabeçalho da vaga ─────────────────────────

class _Cabecalho extends StatelessWidget {
  const _Cabecalho({
    required this.vaga,
    required this.isDark,
    required this.accent,
  });

  final VagaDetalhe vaga;
  final bool isDark;
  final Color accent;

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

    final estabLinha = _estabelecimentoLinha(vaga);

    return Container(
      key: const Key('vaga-detalhe-cabecalho'),
      padding: const EdgeInsets.all(TurniSpacing.md),
      decoration: BoxDecoration(
        color: surface,
        border: Border.all(color: border),
        borderRadius: const BorderRadius.all(TurniRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MergeSemantics(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    vaga.funcao,
                    key: const Key('vaga-detalhe-funcao'),
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: textStrong,
                    ),
                  ),
                ),
                const SizedBox(width: TurniSpacing.sm),
                _ScoreChip(
                  total: vaga.score.total,
                  accent: accent,
                  isDark: isDark,
                ),
                if (vaga.score.total >= 80) ...[
                  const SizedBox(width: TurniSpacing.sm),
                  const _AltoMatchBadge(),
                ],
              ],
            ),
          ),
          if (estabLinha != null) ...[
            const SizedBox(height: TurniSpacing.xs),
            Text(estabLinha, style: TextStyle(fontSize: 14, color: textMuted)),
          ],
          const SizedBox(height: 2),
          Text(
            _formatQuando(vaga.dataInicio, vaga.dataFim),
            style: TextStyle(fontSize: 14, color: textMuted),
          ),
          const SizedBox(height: TurniSpacing.sm),
          _linhaValorWidget(vaga, textStrong),
        ],
      ),
    );
  }

  Widget _linhaValorWidget(VagaDetalhe v, Color textStrong) {
    final base = '${_formatBRL(v.valor)} · turno';
    final d = v.distanciaKm;
    if (d == null) {
      return Text(base, style: TextStyle(fontSize: 15, color: textStrong));
    }
    final dist = d < 1 ? 'a menos de 1 km' : 'a ${d.round()} km';
    return Semantics(
      label: 'a ${d.round()} quilômetros de distância',
      child: Text(
        '$base · $dist',
        key: const Key('vaga-detalhe-distancia'),
        style: TextStyle(fontSize: 15, color: textStrong),
      ),
    );
  }

  static String? _estabelecimentoLinha(VagaDetalhe v) {
    final estab = v.estabelecimento?.trim();
    final cidade = v.cidade?.trim();
    if (estab != null &&
        estab.isNotEmpty &&
        cidade != null &&
        cidade.isNotEmpty) {
      return '$estab · $cidade';
    }
    if (estab != null && estab.isNotEmpty) return estab;
    if (cidade != null && cidade.isNotEmpty) return cidade;
    return null;
  }
}

/// match.scorechip — número de match no canto do cabeçalho (⬢ + número). Reuso de SCREEN-048.
class _ScoreChip extends StatelessWidget {
  const _ScoreChip({
    required this.total,
    required this.accent,
    required this.isDark,
  });

  final int total;
  final Color accent;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final soft = isDark ? const Color(0x265FA37C) : const Color(0xFFE5F0E8);
    return Container(
      key: const Key('vaga-detalhe-score-chip'),
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

class _AltoMatchBadge extends StatelessWidget {
  const _AltoMatchBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('vaga-detalhe-alto-match'),
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

// ───────────────────────── BreakdownRow (reutilizável — STORY-051) ─────────────────────────

/// match.breakdownrow — uma linha do breakdown explicável: ícone de estado (✓/◐/✕) + label +
/// barra proporcional (na cor do estado) + `X/Y` + descrição em prosa. Reusada no painel do
/// contratante (STORY-051). Score nunca só por cor: ícone + número + prosa acompanham sempre
/// (CA-8 / DDR-001).
class BreakdownRow extends StatelessWidget {
  const BreakdownRow({super.key, required this.linha, required this.isDark});

  final BreakdownLinha linha;
  final bool isDark;

  Color get _cor => switch (linha.estado) {
    EstadoComponente.ok =>
      isDark ? const Color(0xFF4FA374) : TurniColors.successLight,
    EstadoComponente.partial =>
      isDark ? TurniColors.warnDark : TurniColors.warnLight,
    EstadoComponente.miss =>
      isDark ? TurniColors.textMutedDark : TurniColors.textMutedLight,
  };

  IconData get _icone => switch (linha.estado) {
    EstadoComponente.ok => Icons.check,
    EstadoComponente.partial => Icons.adjust,
    EstadoComponente.miss => Icons.close,
  };

  String get _iconeSemantica => switch (linha.estado) {
    EstadoComponente.ok => 'atende',
    EstadoComponente.partial => 'atende parcialmente',
    EstadoComponente.miss => 'não atende',
  };

  @override
  Widget build(BuildContext context) {
    final cor = _cor;
    final track = isDark
        ? TurniColors.borderSubtleDark
        : TurniColors.borderSubtleLight;
    final textStrong = isDark
        ? TurniColors.textStrongDark
        : TurniColors.textStrongLight;
    final textMuted = isDark
        ? TurniColors.textMutedDark
        : TurniColors.textMutedLight;
    final fracao = linha.pontosMax == 0
        ? 0.0
        : (linha.pontos / linha.pontosMax).clamp(0.0, 1.0);

    return Semantics(
      container: true,
      label:
          '${linha.componente.label}: $_iconeSemantica · ${linha.pontos} de ${linha.pontosMax} pontos · ${linha.descricao}',
      child: Row(
        key: Key('vaga-detalhe-breakdown-${linha.componente.slug}'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            key: Key('vaga-detalhe-breakdown-${linha.componente.slug}-icone'),
            width: 22,
            height: 22,
            margin: const EdgeInsets.only(top: 1),
            decoration: BoxDecoration(color: cor, shape: BoxShape.circle),
            child: Icon(_icone, size: 13, color: Colors.white),
          ),
          const SizedBox(width: TurniSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 96,
                      child: Text(
                        linha.componente.label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: textStrong,
                        ),
                      ),
                    ),
                    Expanded(
                      child: ExcludeSemantics(
                        child: Container(
                          key: Key(
                            'vaga-detalhe-breakdown-${linha.componente.slug}-bar',
                          ),
                          height: 8,
                          decoration: BoxDecoration(
                            color: track,
                            borderRadius: const BorderRadius.all(
                              TurniRadius.full,
                            ),
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: fracao,
                            child: Container(
                              decoration: BoxDecoration(
                                color: cor,
                                borderRadius: const BorderRadius.all(
                                  TurniRadius.full,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: TurniSpacing.sm),
                    Text(
                      '${linha.pontos}/${linha.pontosMax}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: textStrong,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  linha.descricao,
                  style: TextStyle(fontSize: 13, color: textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// match.scoretotal — total agregado XX/100 com barra grande no acento do perfil.
class _TotalRow extends StatelessWidget {
  const _TotalRow({
    required this.total,
    required this.isDark,
    required this.accent,
  });

  final int total;
  final bool isDark;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final track = isDark
        ? TurniColors.borderSubtleDark
        : TurniColors.borderSubtleLight;
    final textStrong = isDark
        ? TurniColors.textStrongDark
        : TurniColors.textStrongLight;

    return Semantics(
      container: true,
      label: 'Match total $total de 100',
      child: Row(
        key: const Key('vaga-detalhe-total'),
        children: [
          SizedBox(
            width: 96 + 22 + TurniSpacing.sm,
            child: Text(
              'Match total',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: textStrong,
              ),
            ),
          ),
          Expanded(
            child: ExcludeSemantics(
              child: Container(
                key: const Key('vaga-detalhe-total-bar'),
                height: 12,
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
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: textStrong,
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── Barra de ação (CTA / já candidatou / gate) ─────────────────────────

class _AcaoBar extends StatelessWidget {
  const _AcaoBar({
    required this.vaga,
    required this.accent,
    required this.isDark,
    required this.onCandidatar,
  });

  final VagaDetalhe vaga;
  final Color accent;
  final bool isDark;
  final VoidCallback onCandidatar;

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? TurniColors.surfaceDark : TurniColors.surfaceLight;
    final border = isDark
        ? TurniColors.borderSubtleDark
        : TurniColors.borderSubtleLight;

    return Container(
      decoration: BoxDecoration(
        color: surface,
        border: Border(top: BorderSide(color: border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(TurniSpacing.md),
          child: _conteudo(context),
        ),
      ),
    );
  }

  Widget _conteudo(BuildContext context) {
    if (vaga.jaCandidatou) return _JaCandidatou(candidatura: vaga.candidatura);

    final habilitado = vaga.podeCandidatar;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!habilitado && vaga.motivoBloqueio != null)
          _GateBanner(motivo: vaga.motivoBloqueio!, isDark: isDark),
        _candidatarBtn(habilitado),
      ],
    );
  }

  Widget _candidatarBtn(bool habilitado) {
    final botao = SizedBox(
      width: double.infinity,
      child: FilledButton(
        key: const Key('vaga-detalhe-candidatar-btn'),
        onPressed: habilitado ? onCandidatar : null,
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

    final motivo = vaga.motivoBloqueio ?? 'Você não pode se candidatar agora';
    return Tooltip(
      message: motivo,
      child: Semantics(
        enabled: false,
        label: 'Candidatar-se. $motivo',
        child: botao,
      ),
    );
  }
}

class _JaCandidatou extends StatelessWidget {
  const _JaCandidatou({required this.candidatura});

  final CandidaturaResumo? candidatura;

  @override
  Widget build(BuildContext context) {
    final quando = candidatura?.criadaEm;
    return Column(
      key: const Key('vaga-detalhe-ja-candidatou'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: TurniSpacing.md,
            vertical: TurniSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: TurniColors.successSoftLight,
            borderRadius: const BorderRadius.all(TurniRadius.full),
            border: Border.all(color: const Color(0xFF9CC7AD)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check, size: 16, color: Color(0xFF1D5235)),
              SizedBox(width: 6),
              Text(
                'Você já se candidatou',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1D5235),
                ),
              ),
            ],
          ),
        ),
        if (quando != null) ...[
          const SizedBox(height: 6),
          Text(
            'em ${_formatData(quando)} às ${_formatHora(quando)}',
            style: const TextStyle(
              fontSize: 13,
              color: TurniColors.textMutedLight,
            ),
          ),
        ],
        if (candidatura?.pendente ?? false) ...[
          const SizedBox(height: 4),
          TextButton(
            key: const Key('vaga-detalhe-retirar-btn'),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Retirar candidatura chega na próxima etapa.'),
                ),
              );
            },
            child: const Text('Retirar candidatura'),
          ),
        ],
      ],
    );
  }
}

class _GateBanner extends StatelessWidget {
  const _GateBanner({required this.motivo, required this.isDark});

  final String motivo;
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
        key: const Key('vaga-detalhe-gate-banner'),
        margin: const EdgeInsets.only(bottom: TurniSpacing.sm),
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
              child: Text(motivo, style: TextStyle(color: fg, fontSize: 14)),
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── Estados auxiliares ─────────────────────────

class _SkeletonView extends StatelessWidget {
  const _SkeletonView();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bar = isDark
        ? TurniColors.borderSubtleDark
        : TurniColors.borderSubtleLight;
    Widget line(double w, {double h = 14}) => Container(
      width: w,
      height: h,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: bar,
        borderRadius: BorderRadius.circular(6),
      ),
    );
    return ExcludeSemantics(
      child: SingleChildScrollView(
        key: const Key('vaga-detalhe-skeleton'),
        padding: const EdgeInsets.all(TurniSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            line(180, h: 24),
            line(220),
            line(160),
            const SizedBox(height: TurniSpacing.lg),
            for (var i = 0; i < 4; i++) line(double.infinity, h: 28),
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
    return Center(
      key: const Key('vaga-detalhe-erro'),
      child: Padding(
        padding: const EdgeInsets.all(TurniSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning_amber_rounded, size: 44),
            const SizedBox(height: TurniSpacing.md),
            Text(
              'Não foi possível carregar a vaga.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: TurniSpacing.sm),
            const Text('Verifique sua conexão.', textAlign: TextAlign.center),
            const SizedBox(height: TurniSpacing.lg),
            OutlinedButton(
              key: const Key('vaga-detalhe-retry-btn'),
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
  const _SemPermissaoView({required this.accent, required this.onVoltar});

  final Color accent;
  final VoidCallback onVoltar;

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const Key('vaga-detalhe-sem-permissao'),
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
              'O detalhe de vagas é de quem pega turnos. Sua conta é de contratante.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: TurniSpacing.lg),
            FilledButton(
              onPressed: onVoltar,
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

class _IndisponivelView extends StatelessWidget {
  const _IndisponivelView({required this.accent, required this.onVoltar});

  final Color accent;
  final VoidCallback onVoltar;

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const Key('vaga-detalhe-indisponivel'),
      child: Padding(
        padding: const EdgeInsets.all(TurniSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.event_busy, size: 48),
            const SizedBox(height: TurniSpacing.md),
            Text(
              'Esta vaga não está mais disponível',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: TurniSpacing.sm),
            const Text(
              'Ela pode ter sido preenchida ou encerrada. Veja outras no seu feed.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: TurniSpacing.lg),
            FilledButton(
              onPressed: onVoltar,
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
              ),
              child: const Text('Voltar ao feed'),
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── Formatação pt-BR / 24h (DDR-002) ─────────────────────────

const _diasSemana = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];

String _dois(int n) => n.toString().padLeft(2, '0');

/// "Sex, 12/06 · 18:00–23:00" (24h, pt-BR). Horário local do dispositivo.
String _formatQuando(DateTime inicio, DateTime fim) {
  final i = inicio.toLocal();
  final f = fim.toLocal();
  final dia = _diasSemana[i.weekday - 1];
  return '$dia, ${_dois(i.day)}/${_dois(i.month)} · '
      '${_dois(i.hour)}:${_dois(i.minute)}–${_dois(f.hour)}:${_dois(f.minute)}';
}

String _formatData(DateTime d) {
  final l = d.toLocal();
  return '${_dois(l.day)}/${_dois(l.month)}';
}

String _formatHora(DateTime d) {
  final l = d.toLocal();
  return '${_dois(l.hour)}:${_dois(l.minute)}';
}

/// "R$ 1.234,56" — formatação monetária pt-BR sem dependência de intl.
String _formatBRL(double valor) {
  final centavos = (valor * 100).round();
  final reais = (centavos ~/ 100).toString();
  final cents = _dois(centavos % 100);
  final buf = StringBuffer();
  for (var i = 0; i < reais.length; i++) {
    if (i > 0 && (reais.length - i) % 3 == 0) buf.write('.');
    buf.write(reais[i]);
  }
  return 'R\$ $buf,$cents';
}
