import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../ds/tokens.dart';
import 'candidatos_service.dart';
import 'vaga_detalhe_service.dart' show ScoreBreakdown;
import 'vaga_detalhe_screen.dart' show BreakdownRow;

/// STORY-051 / SCREEN-STORY-051 — painel de candidatos do contratante: lista os candidatos
/// `pendentes` da vaga ranqueados por score (CA-2), com o **mesmo** breakdown que o profissional
/// viu (CA-4, reusa `BreakdownRow` da STORY-049). Marca o alerta de habitualidade (CA-5) e deixa
/// "Aceitar"/"Remover" desabilitados — o aceite é EPIC-003 (CA-6). RBAC (CA-1): profissional ou
/// contratante não-dono (403) cai em "sem permissão"; vaga inexistente (404) cai em estado próprio.
/// Tema do papel: contratante (mostarda). Espelho de "Minhas vagas" (SCREEN-047).
class PainelCandidatosScreen extends StatefulWidget {
  const PainelCandidatosScreen({
    super.key,
    required this.vagaId,
    this.funcao,
    this.dataInicio,
    this.dataFim,
    CandidatosService? service,
  }) : _service = service;

  final int vagaId;

  /// Contexto da vaga vindo da navegação de "Minhas vagas" (CA-10). Ausente no deep-link/reload —
  /// a faixa degrada para só a contagem (fail-soft; o contrato CA-1 não inclui dados da vaga).
  final String? funcao;
  final DateTime? dataInicio;
  final DateTime? dataFim;

  final CandidatosService? _service;

  @override
  State<PainelCandidatosScreen> createState() => _PainelCandidatosScreenState();
}

enum _Phase { loading, semPermissao, naoEncontrada, erro, pronto }

class _PainelCandidatosScreenState extends State<PainelCandidatosScreen> {
  late final CandidatosService _service =
      widget._service ?? CandidatosService();

  _Phase _phase = _Phase.loading;
  List<CandidatoCard> _candidatos = const [];
  int _total = 0;

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
        case CandidatosSuccess(:final candidatos, :final total):
          _candidatos = candidatos;
          _total = total;
          _phase = _Phase.pronto;
        case CandidatosForbidden():
          _phase = _Phase.semPermissao;
        case CandidatosNotFound():
          _phase = _Phase.naoEncontrada;
        case CandidatosError():
          _phase = _Phase.erro;
      }
    });
  }

  void _voltar() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/contratante/vagas');
    }
  }

  Color _accent(bool isDark) => isDark
      ? TurniColors.contratanteAccentDark
      : TurniColors.contratanteAccentLight;

  Color _accentInk(bool isDark) => isDark
      ? TurniColors.contratanteAccentDark
      : TurniColors.contratanteAccentInkLight;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfacePage = isDark
        ? TurniColors.surfacePageDark
        : TurniColors.surfacePageLight;

    return Scaffold(
      key: const Key('painel-candidatos-screen'),
      backgroundColor: surfacePage,
      appBar: AppBar(
        leading: IconButton(
          key: const Key('painel-candidatos-voltar-btn'),
          tooltip: 'Voltar',
          icon: const Icon(Icons.arrow_back),
          onPressed: _voltar,
        ),
        title: const Text('Candidatos'),
      ),
      body: SafeArea(child: _body(isDark)),
    );
  }

  Widget _body(bool isDark) {
    switch (_phase) {
      case _Phase.loading:
        return const _SkeletonView();
      case _Phase.semPermissao:
        return _SemPermissaoView(accent: _accent(isDark));
      case _Phase.naoEncontrada:
        return _NaoEncontradaView(accent: _accent(isDark));
      case _Phase.erro:
        return _ErroView(isDark: isDark, onRetry: _load);
      case _Phase.pronto:
        return _conteudo(isDark);
    }
  }

  Widget _conteudo(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Contexto(
          funcao: widget.funcao,
          dataInicio: widget.dataInicio,
          dataFim: widget.dataFim,
          total: _total,
          isDark: isDark,
        ),
        Expanded(
          child: _candidatos.isEmpty
              ? _VazioView(accent: _accent(isDark))
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final largura = constraints.maxWidth >= 760
                        ? 720.0
                        : constraints.maxWidth;
                    return SingleChildScrollView(
                      key: const Key('painel-candidatos-lista'),
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
                              for (final c in _candidatos)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: TurniSpacing.md,
                                  ),
                                  child: _CandidatoCardView(
                                    candidato: c,
                                    isDark: isDark,
                                    accent: _accent(isDark),
                                    accentInk: _accentInk(isDark),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ───────────────────────── Faixa de contexto da vaga ─────────────────────────

class _Contexto extends StatelessWidget {
  const _Contexto({
    required this.funcao,
    required this.dataInicio,
    required this.dataFim,
    required this.total,
    required this.isDark,
  });

  final String? funcao;
  final DateTime? dataInicio;
  final DateTime? dataFim;
  final int total;
  final bool isDark;

  String get _contagem => switch (total) {
    0 => 'Nenhum candidato ainda',
    1 => '1 candidato',
    _ => '$total candidatos',
  };

  String? get _linhaVaga {
    final f = funcao?.trim();
    if (f == null || f.isEmpty) return null;
    if (dataInicio != null && dataFim != null) {
      return '$f · ${_formatQuando(dataInicio!, dataFim!)}';
    }
    return f;
  }

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
    final linhaVaga = _linhaVaga;

    return Container(
      key: const Key('painel-candidatos-contexto'),
      width: double.infinity,
      padding: const EdgeInsets.all(TurniSpacing.md),
      decoration: BoxDecoration(
        color: surface,
        border: Border(bottom: BorderSide(color: border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (linhaVaga != null) ...[
            Text(
              linhaVaga,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: textStrong,
              ),
            ),
            const SizedBox(height: 2),
          ],
          Text(_contagem, style: TextStyle(fontSize: 14, color: textMuted)),
        ],
      ),
    );
  }
}

// ───────────────────────── Card de candidato ─────────────────────────

class _CandidatoCardView extends StatefulWidget {
  const _CandidatoCardView({
    required this.candidato,
    required this.isDark,
    required this.accent,
    required this.accentInk,
  });

  final CandidatoCard candidato;
  final bool isDark;
  final Color accent;
  final Color accentInk;

  @override
  State<_CandidatoCardView> createState() => _CandidatoCardViewState();
}

class _CandidatoCardViewState extends State<_CandidatoCardView> {
  bool _aberto = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.candidato;
    final isDark = widget.isDark;
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

    final score = c.score;
    final temBreakdown = score != null && score.linhas.isNotEmpty;

    return Container(
      key: Key('candidato-card-${c.id}'),
      padding: const EdgeInsets.all(TurniSpacing.md),
      decoration: BoxDecoration(
        color: surface,
        border: Border.all(color: border),
        borderRadius: const BorderRadius.all(TurniRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabeçalho: avatar + nome + score chip.
          MergeSemantics(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Avatar(candidato: c, accent: widget.accent),
                const SizedBox(width: TurniSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              c.profissional.nome,
                              key: Key('candidato-card-${c.id}-nome'),
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: textStrong,
                              ),
                            ),
                          ),
                          const SizedBox(width: TurniSpacing.sm),
                          if (c.scoreNoMomento != null)
                            _ScoreChip(
                              total: c.scoreNoMomento!,
                              accent: widget.accent,
                              accentInk: widget.accentInk,
                              vagaCandidatoId: c.id,
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      _FuncaoNivel(candidato: c, isDark: isDark),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Barra de score + número.
          if (c.scoreNoMomento != null) ...[
            const SizedBox(height: TurniSpacing.sm),
            _ScoreBar(
              total: c.scoreNoMomento!,
              accent: widget.accent,
              isDark: isDark,
              vagaCandidatoId: c.id,
            ),
          ],
          // Data da candidatura.
          if (c.candidatouEm != null) ...[
            const SizedBox(height: TurniSpacing.xs),
            Text(
              'Candidatou ${_formatDataHora(c.candidatouEm!)}',
              key: Key('candidato-card-${c.id}-data'),
              style: TextStyle(fontSize: 13, color: textMuted),
            ),
          ],
          // Alerta de habitualidade (CA-5).
          if (c.alertaHabitualidade) ...[
            const SizedBox(height: TurniSpacing.sm),
            _HabitualidadeBadge(isDark: isDark, vagaCandidatoId: c.id),
          ],
          // Toggle do breakdown (CA-4) — só quando há snapshot.
          if (temBreakdown) ...[
            _BreakdownToggle(
              aberto: _aberto,
              accentInk: widget.accentInk,
              nome: c.profissional.nome,
              vagaCandidatoId: c.id,
              onTap: () => setState(() => _aberto = !_aberto),
            ),
            if (_aberto)
              _BreakdownBloco(
                score: score,
                isDark: isDark,
                vagaCandidatoId: c.id,
              ),
          ],
          // Ações futuras desabilitadas (CA-6).
          Divider(color: border, height: TurniSpacing.lg),
          _AcoesDesabilitadas(vagaCandidatoId: c.id),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.candidato, required this.accent});

  final CandidatoCard candidato;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final foto = candidato.profissional.fotoUrl;
    return Semantics(
      label: 'Foto de ${candidato.profissional.nome}',
      image: foto != null,
      child: CircleAvatar(
        key: Key('candidato-card-${candidato.id}-avatar'),
        radius: 22,
        backgroundColor: accent,
        foregroundImage: foto != null ? NetworkImage(foto) : null,
        child: ExcludeSemantics(
          child: Text(
            candidato.profissional.iniciais,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }
}

class _FuncaoNivel extends StatelessWidget {
  const _FuncaoNivel({required this.candidato, required this.isDark});

  final CandidatoCard candidato;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final textMuted = isDark
        ? TurniColors.textMutedDark
        : TurniColors.textMutedLight;
    final funcao = candidato.profissional.funcaoPrimaria?.trim();
    final nivel = candidato.profissional.nivel?.trim();

    return Row(
      key: Key('candidato-card-${candidato.id}-funcao-nivel'),
      children: [
        Flexible(
          child: Text(
            (funcao == null || funcao.isEmpty) ? 'Profissional' : funcao,
            style: TextStyle(fontSize: 14, color: textMuted),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (nivel != null && nivel.isNotEmpty) ...[
          const SizedBox(width: TurniSpacing.xs),
          _NivelBadge(
            nivel: nivel,
            isDark: isDark,
            vagaCandidatoId: candidato.id,
          ),
        ],
      ],
    );
  }
}

/// badge.nivel — selo neutro do nível na trilha (SCREEN-051 §8).
class _NivelBadge extends StatelessWidget {
  const _NivelBadge({
    required this.nivel,
    required this.isDark,
    required this.vagaCandidatoId,
  });

  final String nivel;
  final bool isDark;
  final int vagaCandidatoId;

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? TurniColors.surfacePageDark : const Color(0xFFF0EEE6);
    final border = isDark
        ? TurniColors.borderSubtleDark
        : TurniColors.borderSubtleLight;
    final fg = isDark
        ? TurniColors.textStrongDark
        : TurniColors.textStrongLight;

    return Container(
      key: Key('candidato-card-$vagaCandidatoId-nivel'),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.all(TurniRadius.full),
        border: Border.all(color: border),
      ),
      child: Text(
        nivel,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }
}

/// match.scorechip — número de match (⬢ + número) no acento do contratante. Reuso de 048/049.
class _ScoreChip extends StatelessWidget {
  const _ScoreChip({
    required this.total,
    required this.accent,
    required this.accentInk,
    required this.vagaCandidatoId,
  });

  final int total;
  final Color accent;
  final Color accentInk;
  final int vagaCandidatoId;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('candidato-card-$vagaCandidatoId-score-chip'),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
      decoration: BoxDecoration(
        color: TurniColors.warnSoftLight,
        borderRadius: const BorderRadius.all(TurniRadius.full),
        border: Border.all(color: accent.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.hexagon, size: 13, color: accentInk),
          const SizedBox(width: 5),
          Text(
            '$total',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: accentInk,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

/// match.scorebar — barra grande do score do candidato (acento do contratante) + número.
class _ScoreBar extends StatelessWidget {
  const _ScoreBar({
    required this.total,
    required this.accent,
    required this.isDark,
    required this.vagaCandidatoId,
  });

  final int total;
  final Color accent;
  final bool isDark;
  final int vagaCandidatoId;

  @override
  Widget build(BuildContext context) {
    final track = isDark
        ? TurniColors.borderSubtleDark
        : TurniColors.borderSubtleLight;
    final textStrong = isDark
        ? TurniColors.textStrongDark
        : TurniColors.textStrongLight;

    return Semantics(
      label: 'Match $total de 100',
      child: Row(
        children: [
          Expanded(
            child: ExcludeSemantics(
              child: Container(
                key: Key('candidato-card-$vagaCandidatoId-score-bar'),
                height: 10,
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
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: textStrong,
            ),
          ),
        ],
      ),
    );
  }
}

/// habitualidade.badge — pill warning de alerta de habitualidade no card (SCREEN-051 §8 / CA-5).
class _HabitualidadeBadge extends StatelessWidget {
  const _HabitualidadeBadge({
    required this.isDark,
    required this.vagaCandidatoId,
  });

  final bool isDark;
  final int vagaCandidatoId;

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? TurniColors.warnSoftDark : TurniColors.warnSoftLight;
    final fg = isDark
        ? TurniColors.warnDark
        : TurniColors.contratanteAccentInkLight;

    return Tooltip(
      message:
          'Profissional MEI/PJ acima do limite semanal neste local. Sinalização para o aceite; não bloqueia.',
      child: Semantics(
        label: 'Alerta de habitualidade: terceira alocação na semana.',
        child: Container(
          key: Key('candidato-card-$vagaCandidatoId-habitualidade'),
          padding: const EdgeInsets.symmetric(
            horizontal: TurniSpacing.sm,
            vertical: 5,
          ),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: const BorderRadius.all(TurniRadius.full),
            border: Border.all(color: fg.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.warning_amber_rounded, size: 15, color: fg),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'Habitualidade — 3ª alocação na semana',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: fg,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BreakdownToggle extends StatelessWidget {
  const _BreakdownToggle({
    required this.aberto,
    required this.accentInk,
    required this.nome,
    required this.vagaCandidatoId,
    required this.onTap,
  });

  final bool aberto;
  final Color accentInk;
  final String nome;
  final int vagaCandidatoId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Semantics(
        button: true,
        expanded: aberto,
        label: 'Ver breakdown de $nome',
        child: TextButton.icon(
          key: Key('candidato-card-$vagaCandidatoId-breakdown-toggle'),
          onPressed: onTap,
          style: TextButton.styleFrom(
            foregroundColor: accentInk,
            padding: const EdgeInsets.symmetric(vertical: TurniSpacing.sm),
            minimumSize: const Size(0, 44),
          ),
          icon: Icon(aberto ? Icons.expand_less : Icons.expand_more, size: 18),
          label: Text(aberto ? 'Ocultar breakdown' : 'Ver breakdown'),
        ),
      ),
    );
  }
}

class _BreakdownBloco extends StatelessWidget {
  const _BreakdownBloco({
    required this.score,
    required this.isDark,
    required this.vagaCandidatoId,
  });

  final ScoreBreakdown score;
  final bool isDark;
  final int vagaCandidatoId;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: Key('candidato-card-$vagaCandidatoId-breakdown'),
      children: [
        const SizedBox(height: TurniSpacing.xs),
        for (final linha in score.linhas)
          Padding(
            padding: const EdgeInsets.only(bottom: TurniSpacing.md),
            // Reuso idêntico do widget da STORY-049 (CA-4). As keys internas dele usam o prefixo
            // `vaga-detalhe-breakdown-*`; o card inteiro é ancorado pela key do bloco acima.
            child: BreakdownRow(linha: linha, isDark: isDark),
          ),
      ],
    );
  }
}

/// Ações de "Aceitar"/"Remover" desabilitadas — promessa honesta do EPIC-003 (CA-6).
class _AcoesDesabilitadas extends StatelessWidget {
  const _AcoesDesabilitadas({required this.vagaCandidatoId});

  final int vagaCandidatoId;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Tooltip(
          message: 'Disponível no EPIC-003 — Aceite, PIN e Pix',
          child: Semantics(
            enabled: false,
            label: 'Aceitar candidatura. Disponível no EPIC-003',
            child: FilledButton(
              key: Key('candidato-card-$vagaCandidatoId-aceitar-btn'),
              onPressed: null,
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 48),
                shape: const StadiumBorder(),
              ),
              child: const Text('Aceitar candidatura'),
            ),
          ),
        ),
        const SizedBox(height: TurniSpacing.xs),
        Tooltip(
          message: 'Disponível no EPIC-003',
          child: Semantics(
            enabled: false,
            label: 'Remover candidato. Disponível no EPIC-003',
            child: TextButton(
              key: Key('candidato-card-$vagaCandidatoId-remover-btn'),
              onPressed: null,
              child: const Text('Remover candidato'),
            ),
          ),
        ),
      ],
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
    final surface = isDark ? TurniColors.surfaceDark : TurniColors.surfaceLight;

    Widget line(double w, {double h = 12}) => Container(
      width: w,
      height: h,
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: bar,
        borderRadius: BorderRadius.circular(6),
      ),
    );
    Widget card() => Container(
      margin: const EdgeInsets.only(bottom: TurniSpacing.md),
      padding: const EdgeInsets.all(TurniSpacing.md),
      decoration: BoxDecoration(
        color: surface,
        border: Border.all(color: bar),
        borderRadius: const BorderRadius.all(TurniRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: bar, shape: BoxShape.circle),
          ),
          const SizedBox(width: TurniSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [line(140), line(90), line(double.infinity, h: 10)],
            ),
          ),
        ],
      ),
    );

    return ExcludeSemantics(
      child: ListView(
        key: const Key('painel-candidatos-skeleton'),
        padding: const EdgeInsets.all(TurniSpacing.md),
        children: [for (var i = 0; i < 3; i++) card()],
      ),
    );
  }
}

class _VazioView extends StatelessWidget {
  const _VazioView({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const Key('painel-candidatos-vazio'),
      child: Padding(
        padding: const EdgeInsets.all(TurniSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.groups_outlined, size: 48),
            const SizedBox(height: TurniSpacing.md),
            Text(
              'Ainda sem candidatos',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: TurniSpacing.sm),
            const Text(
              'Vamos avisar assim que chegar o primeiro. Member Start: em até 2h.',
              textAlign: TextAlign.center,
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
    return Center(
      key: const Key('painel-candidatos-erro'),
      child: Padding(
        padding: const EdgeInsets.all(TurniSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning_amber_rounded, size: 44),
            const SizedBox(height: TurniSpacing.md),
            Text(
              'Não foi possível carregar os candidatos.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: TurniSpacing.sm),
            const Text('Verifique sua conexão.', textAlign: TextAlign.center),
            const SizedBox(height: TurniSpacing.lg),
            OutlinedButton(
              key: const Key('painel-candidatos-retry-btn'),
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
      key: const Key('painel-candidatos-sem-permissao'),
      child: Padding(
        padding: const EdgeInsets.all(TurniSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 48),
            const SizedBox(height: TurniSpacing.md),
            Text(
              'Esta área é do contratante dono',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: TurniSpacing.sm),
            const Text(
              'Só quem publicou a vaga vê seus candidatos.',
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

class _NaoEncontradaView extends StatelessWidget {
  const _NaoEncontradaView({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const Key('painel-candidatos-nao-encontrada'),
      child: Padding(
        padding: const EdgeInsets.all(TurniSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.event_busy, size: 48),
            const SizedBox(height: TurniSpacing.md),
            Text(
              'Vaga não encontrada',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: TurniSpacing.sm),
            const Text(
              'Ela pode ter sido removida. Veja suas vagas.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: TurniSpacing.lg),
            FilledButton(
              onPressed: () => context.go('/contratante/vagas'),
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
              ),
              child: const Text('Voltar às minhas vagas'),
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

/// "Sex, 12/06 · 14:20" — data/hora da candidatura (24h, pt-BR).
String _formatDataHora(DateTime d) {
  final l = d.toLocal();
  final dia = _diasSemana[l.weekday - 1];
  return '$dia, ${_dois(l.day)}/${_dois(l.month)} · ${_dois(l.hour)}:${_dois(l.minute)}';
}
