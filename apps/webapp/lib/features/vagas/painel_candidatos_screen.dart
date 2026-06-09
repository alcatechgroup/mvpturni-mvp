import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/format/brl.dart';
import '../../core/time/turni_datetime.dart';
import '../../ds/components/state_views.dart';
import '../../ds/tokens.dart';
import 'candidatos_service.dart';
import 'vaga_detalhe_service.dart' show ScoreBreakdown;
import 'vaga_detalhe_screen.dart' show BreakdownRow;

/// STORY-051 / SCREEN-STORY-051 — painel de candidatos do contratante: lista os candidatos
/// `pendentes` da vaga ranqueados por score (CA-2), com o **mesmo** breakdown que o profissional
/// viu (CA-4, reusa `BreakdownRow` da STORY-049). Marca o alerta de habitualidade (CA-5). RBAC
/// (CA-1): profissional ou contratante não-dono (403) cai em "sem permissão"; vaga inexistente
/// (404) cai em estado próprio. Tema do papel: contratante (mostarda).
///
/// STORY-058 / SCREEN-STORY-058 — "Aceitar candidatura" agora ABRE O TURNO: D1 (confirmação com
/// o financeiro PDR-004 + pré-aviso de habitualidade), D2 (bloqueio PF 3ª — PDR-002), D3 (aceite
/// de risco PJ 3ª com override explícito) e snackbars de desfecho. "Remover" segue desabilitado
/// (recusa é Lacuna do MVP).
class PainelCandidatosScreen extends StatefulWidget {
  const PainelCandidatosScreen({
    super.key,
    required this.vagaId,
    this.funcao,
    this.dataInicio,
    this.dataFim,
    CandidatosService? service,
  }) : _service = service;

  final String vagaId;

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
  VagaFinanceiro? _financeiro; // preview valor/taxa/total (STORY-058 — D1)

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
        case CandidatosSuccess(:final candidatos, :final total, :final vaga):
          _candidatos = candidatos;
          _total = total;
          _financeiro = vaga;
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

  // ───────────────── Aceite da candidatura (STORY-058 / SCREEN-058) ─────────────────

  /// D1 — confirmação. Confirmar dispara o POST dentro do próprio dialog (CTA em
  /// "Confirmando…", barrier travada — anti clique-duplo na UI; o servidor é idempotente).
  Future<void> _iniciarAceite(CandidatoCard candidato) async {
    final result = await showDialog<AprovarResult>(
      context: context,
      builder: (_) => _AprovarConfirmaDialog(
        candidato: candidato,
        financeiro: _financeiro,
        dataInicio: widget.dataInicio,
        dataFim: widget.dataFim,
        aprovar: () => _service.aprovar(candidato.id),
      ),
    );
    if (!mounted || result == null) return;
    await _tratarDesfecho(candidato, result);
  }

  Future<void> _tratarDesfecho(
    CandidatoCard candidato,
    AprovarResult result,
  ) async {
    switch (result) {
      case AprovarSucesso():
        _snack(
          key: 'aprovar-snackbar-sucesso',
          icone: Icons.check_circle_outline,
          texto:
              'Turno confirmado. O contrato foi registrado e o pagamento está sendo pré-autorizado.',
          duracao: const Duration(seconds: 6),
        );
        await _load();
      case AprovarJaAceita():
        _snack(texto: 'Esta candidatura já foi aceita — o turno existe.');
        await _load();
      case AprovarBloqueio(:final erro):
        switch (erro) {
          case 'habitualidade_bloqueio':
            await _mostrarBloqueioPf();
          case 'requer_override':
            final r = await showDialog<AprovarResult>(
              context: context,
              builder: (_) => _AprovarOverrideDialog(
                aprovar: () => _service.aprovar(candidato.id, override: true),
              ),
            );
            if (!mounted || r == null) return;
            await _tratarDesfecho(candidato, r);
          case 'vaga_fechada':
            _snack(
              texto: 'Esta vaga não está mais aberta. A lista foi atualizada.',
            );
            await _load();
          default:
            _snack(
              texto: 'Esta candidatura não está mais disponível para aceite.',
            );
            await _load();
        }
      case AprovarErro():
        _snack(
          key: 'aprovar-snackbar-erro',
          icone: Icons.warning_amber_rounded,
          texto: 'Não foi possível concluir o aceite.',
          erro: true,
          acao: SnackBarAction(
            label: 'Tentar de novo',
            onPressed: () => _iniciarAceite(candidato),
          ),
        );
    }
  }

  /// D2 — bloqueio PF 3ª (PDR-002): não é erro do usuário; tom de proteção (SCREEN-058 §3).
  Future<void> _mostrarBloqueioPf() {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        key: const Key('aprovar-dialog-bloqueio-pf'),
        title: Row(
          children: [
            Semantics(
              label: 'Bloqueado por regra de proteção',
              child: const Icon(Icons.shield_outlined),
            ),
            const SizedBox(width: TurniSpacing.sm),
            const Expanded(child: Text('Aceite bloqueado')),
          ],
        ),
        content: const Text(
          'Este profissional é PF e já tem 2 alocações nesta semana neste '
          'estabelecimento.\n\n'
          'Para proteger a relação de trabalho eventual, a plataforma bloqueia a 3ª '
          'alocação semanal de profissionais PF — sem exceção.\n\n'
          'Você pode aceitá-lo a partir da próxima semana, ou escolher outro candidato.',
        ),
        actions: [
          FilledButton(
            key: const Key('aprovar-dialog-bloqueio-pf-entendi-btn'),
            onPressed: () => Navigator.of(context).pop(),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            child: const Text('Entendi'),
          ),
        ],
      ),
    );
  }

  void _snack({
    String? key,
    IconData? icone,
    required String texto,
    bool erro = false,
    Duration duracao = const Duration(seconds: 4),
    SnackBarAction? acao,
  }) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: duracao,
        backgroundColor: erro ? const Color(0xFF4A2222) : null,
        action: acao,
        content: Row(
          key: key != null ? Key(key) : null,
          children: [
            if (icone != null) ...[
              Icon(icone, size: 18, color: erro ? TurniColors.warnDark : null),
              const SizedBox(width: TurniSpacing.sm),
            ],
            Expanded(child: Text(texto)),
          ],
        ),
      ),
    );
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
        return const TurniSkeletonList(
          key: Key('painel-candidatos-skeleton'),
          itemBuilder: _skeletonCandidato,
        );
      case _Phase.semPermissao:
        return _SemPermissaoView(accent: _accent(isDark));
      case _Phase.naoEncontrada:
        return _NaoEncontradaView(accent: _accent(isDark));
      case _Phase.erro:
        return TurniRetryState(
          key: const Key('painel-candidatos-erro'),
          retryKey: const Key('painel-candidatos-retry-btn'),
          title: 'Não foi possível carregar os candidatos.',
          accent: _accent(isDark),
          onRetry: _load,
        );
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
                                    onAceitar: () => _iniciarAceite(c),
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
      return '$f · ${TurniDateTime.formatIntervalo(dataInicio!, dataFim!)}';
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
    required this.onAceitar,
  });

  final CandidatoCard candidato;
  final bool isDark;
  final Color accent;
  final Color accentInk;
  final VoidCallback onAceitar;

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
              'Candidatou ${TurniDateTime.formatResumo(c.candidatouEm!)}',
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
          // Aceitar habilitado (STORY-058); remover segue desabilitado (Lacuna MVP).
          Divider(color: border, height: TurniSpacing.lg),
          _Acoes(vagaCandidatoId: c.id, onAceitar: widget.onAceitar),
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
  final String vagaCandidatoId;

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
  final String vagaCandidatoId;

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
  final String vagaCandidatoId;

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
  final String vagaCandidatoId;

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
  final String vagaCandidatoId;
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
  final String vagaCandidatoId;

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

/// Ações do card: "Aceitar candidatura" habilitado (STORY-058 — abre o D1); "Remover
/// candidato" segue desabilitado (recusa é Lacuna do MVP — domain/candidatura.md).
class _Acoes extends StatelessWidget {
  const _Acoes({required this.vagaCandidatoId, required this.onAceitar});

  final String vagaCandidatoId;
  final VoidCallback onAceitar;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton(
          key: Key('candidato-card-$vagaCandidatoId-aceitar-btn'),
          onPressed: onAceitar,
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 48),
            shape: const StadiumBorder(),
          ),
          child: const Text('Aceitar candidatura'),
        ),
        const SizedBox(height: TurniSpacing.xs),
        Tooltip(
          message: 'Em breve',
          child: Semantics(
            enabled: false,
            label: 'Remover candidato. Em breve',
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

// ───────────────── Dialogs do aceite (STORY-058 / SCREEN-058) ─────────────────

/// D1 — confirmação do aceite: quem, quando, o financeiro (PDR-004) e a nota legal.
/// O POST roda DENTRO do dialog (CTA vira "Confirmando…", barrier travada) e o desfecho
/// é devolvido ao chamador via `Navigator.pop(result)`.
class _AprovarConfirmaDialog extends StatefulWidget {
  const _AprovarConfirmaDialog({
    required this.candidato,
    required this.financeiro,
    required this.dataInicio,
    required this.dataFim,
    required this.aprovar,
  });

  final CandidatoCard candidato;
  final VagaFinanceiro? financeiro;
  final DateTime? dataInicio;
  final DateTime? dataFim;
  final Future<AprovarResult> Function() aprovar;

  @override
  State<_AprovarConfirmaDialog> createState() => _AprovarConfirmaDialogState();
}

class _AprovarConfirmaDialogState extends State<_AprovarConfirmaDialog> {
  bool _enviando = false;

  Future<void> _confirmar() async {
    setState(() => _enviando = true);
    final result = await widget.aprovar();
    if (!mounted) return;
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.candidato;
    final fin = widget.financeiro;
    final funcao = c.profissional.funcaoPrimaria;
    final quando = (widget.dataInicio != null && widget.dataFim != null)
        ? TurniDateTime.formatIntervalo(widget.dataInicio!, widget.dataFim!)
        : null;
    final muted = Theme.of(context).textTheme.bodyMedium;

    return PopScope(
      canPop: !_enviando, // anti clique-duplo: travado durante o envio
      child: AlertDialog(
        key: const Key('aprovar-dialog-confirmar'),
        title: const Text('Aceitar candidatura'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(
                TextSpan(
                  text: 'Você está abrindo um turno com ',
                  children: [
                    TextSpan(
                      text: c.profissional.nome,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    if (funcao != null && funcao.isNotEmpty)
                      TextSpan(text: ' — $funcao'),
                    if (quando != null) TextSpan(text: '\n$quando'),
                  ],
                ),
              ),
              if (fin != null) ...[
                const SizedBox(height: TurniSpacing.md),
                _Financeiro(financeiro: fin),
              ],
              if (c.alertaHabitualidade) ...[
                const SizedBox(height: TurniSpacing.md),
                Container(
                  key: const Key('aprovar-dialog-pre-aviso-habitualidade'),
                  padding: const EdgeInsets.all(TurniSpacing.sm),
                  decoration: BoxDecoration(
                    color: TurniColors.warnSoftLight,
                    borderRadius: const BorderRadius.all(TurniRadius.sm),
                    border: Border.all(
                      color: TurniColors.contratanteAccentInkLight.withValues(
                        alpha: 0.35,
                      ),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.warning_amber_rounded, size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Este profissional já tem 2 turnos com você nesta semana. '
                          'Vamos pedir sua confirmação de risco no próximo passo.',
                          style: TextStyle(
                            fontSize: 13.5,
                            color: TurniColors.contratanteAccentInkLight,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: TurniSpacing.md),
              Text(
                'Ao confirmar, o pagamento é pré-autorizado e o contrato do turno é '
                'emitido e registrado.',
                style: muted,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            key: const Key('aprovar-dialog-voltar-btn'),
            onPressed: _enviando ? null : () => Navigator.of(context).pop(),
            child: const Text('Voltar'),
          ),
          _CtaEnviando(
            chave: 'aprovar-dialog-confirmar-btn',
            label: 'Confirmar aceite',
            enviando: _enviando,
            onPressed: _confirmar,
          ),
        ],
      ),
    );
  }
}

/// D3 — aceite de risco PJ na 3ª alocação (PDR-002/compliance.md). O CTA usa o verbo do
/// registro jurídico ("Assumo o risco e aceito") e reenvia o POST com `override: true`.
class _AprovarOverrideDialog extends StatefulWidget {
  const _AprovarOverrideDialog({required this.aprovar});

  final Future<AprovarResult> Function() aprovar;

  @override
  State<_AprovarOverrideDialog> createState() => _AprovarOverrideDialogState();
}

class _AprovarOverrideDialogState extends State<_AprovarOverrideDialog> {
  bool _enviando = false;

  Future<void> _assumir() async {
    setState(() => _enviando = true);
    final result = await widget.aprovar();
    if (!mounted) return;
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_enviando,
      child: AlertDialog(
        key: const Key('aprovar-dialog-override-pj'),
        title: Row(
          children: [
            Semantics(
              label: 'Atenção: aceite de risco',
              child: const Icon(Icons.warning_amber_rounded),
            ),
            const SizedBox(width: TurniSpacing.sm),
            const Expanded(child: Text('3ª alocação na mesma semana')),
          ],
        ),
        content: const Text(
          'Este profissional já realizou 2 turnos com você nesta semana. Sinais de '
          'habitualidade.\n\n'
          'Você pode prosseguir, mas isso fica registrado como aceite consciente de '
          'risco no contrato do turno. Considere se faz sentido continuar.',
        ),
        actions: [
          TextButton(
            key: const Key('aprovar-dialog-override-pj-voltar-btn'),
            onPressed: _enviando ? null : () => Navigator.of(context).pop(),
            child: const Text('Voltar'),
          ),
          _CtaEnviando(
            chave: 'aprovar-dialog-override-pj-aceitar-btn',
            label: 'Assumo o risco e aceito',
            enviando: _enviando,
            onPressed: _assumir,
          ),
        ],
      ),
    );
  }
}

/// dialog.destaque-financeiro (SCREEN-058 §8 — candidato a DS quando STORY-060 reusar):
/// tabela valor / taxa / total (PDR-004 — o contratante vê os 3 separados na decisão).
class _Financeiro extends StatelessWidget {
  const _Financeiro({required this.financeiro});

  final VagaFinanceiro financeiro;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final border = isDark
        ? TurniColors.borderSubtleDark
        : TurniColors.borderSubtleLight;

    Widget linha(String label, String valor, {bool forte = false}) {
      final estilo = TextStyle(
        fontSize: 14,
        fontWeight: forte ? FontWeight.w800 : FontWeight.w400,
      );
      return MergeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: estilo),
              Text(
                formatBRLDecimal(valor),
                style: estilo.copyWith(
                  fontWeight: forte ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      key: const Key('aprovar-dialog-financeiro'),
      padding: const EdgeInsets.symmetric(
        horizontal: TurniSpacing.md,
        vertical: TurniSpacing.sm,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: border),
        borderRadius: const BorderRadius.all(TurniRadius.sm),
      ),
      child: Column(
        children: [
          linha('Profissional recebe', financeiro.valor),
          linha('Taxa Turni (15%)', financeiro.taxaTurni),
          Divider(color: border, height: TurniSpacing.md),
          linha('Total a pagar', financeiro.totalContratante, forte: true),
        ],
      ),
    );
  }
}

/// CTA primário com estado de envio (spinner inline + "Confirmando…") — anti clique-duplo.
class _CtaEnviando extends StatelessWidget {
  const _CtaEnviando({
    required this.chave,
    required this.label,
    required this.enviando,
    required this.onPressed,
  });

  final String chave;
  final String label;
  final bool enviando;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      enabled: !enviando,
      label: enviando ? 'Confirmando aceite' : null,
      child: FilledButton(
        key: Key(chave),
        onPressed: enviando ? null : onPressed,
        style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
        child: enviando
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: TurniSpacing.sm),
                  const Text('Confirmando…'),
                ],
              )
            : Text(label),
      ),
    );
  }
}

// ───────────────────────── Estados auxiliares ─────────────────────────

// Skeleton de uma linha de candidato (avatar + 3 linhas), para o
// `TurniSkeletonList` da tela. STORY-079.
Widget _skeletonCandidato(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final surface = isDark ? TurniColors.surfaceDark : TurniColors.surfaceLight;
  final border = isDark
      ? TurniColors.borderSubtleDark
      : TurniColors.borderSubtleLight;

  return Container(
    padding: const EdgeInsets.all(TurniSpacing.md),
    decoration: BoxDecoration(
      color: surface,
      border: Border.all(color: border),
      borderRadius: const BorderRadius.all(TurniRadius.md),
    ),
    child: const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TurniSkeletonBox(width: 44, circle: true),
        SizedBox(width: TurniSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TurniSkeletonBox(width: 140),
              SizedBox(height: 10),
              TurniSkeletonBox(width: 90),
              SizedBox(height: 10),
              TurniSkeletonBox(width: double.infinity, height: 10),
            ],
          ),
        ),
      ],
    ),
  );
}

class _VazioView extends StatelessWidget {
  const _VazioView({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    return const TurniEmptyState(
      key: Key('painel-candidatos-vazio'),
      icon: Icons.groups_outlined,
      title: 'Ainda sem candidatos',
      message: 'Assim que alguém se candidatar, você é avisado por aqui.',
    );
  }
}

class _SemPermissaoView extends StatelessWidget {
  const _SemPermissaoView({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    return TurniEmptyState(
      key: const Key('painel-candidatos-sem-permissao'),
      icon: Icons.lock_outline,
      title: 'Esta área é do contratante dono',
      message: 'Só quem publicou a vaga vê seus candidatos.',
      action: FilledButton(
        onPressed: () => context.go('/'),
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: TurniColors.onAccentFor(
            Theme.of(context).brightness,
          ),
          minimumSize: const Size(0, 48),
          shape: const StadiumBorder(),
        ),
        child: const Text('Voltar ao início'),
      ),
    );
  }
}

class _NaoEncontradaView extends StatelessWidget {
  const _NaoEncontradaView({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    return TurniEmptyState(
      key: const Key('painel-candidatos-nao-encontrada'),
      icon: Icons.event_busy,
      title: 'Vaga não encontrada',
      message: 'Ela pode ter sido removida. Veja suas vagas.',
      action: FilledButton(
        onPressed: () => context.go('/contratante/vagas'),
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: TurniColors.onAccentFor(
            Theme.of(context).brightness,
          ),
          minimumSize: const Size(0, 48),
          shape: const StadiumBorder(),
        ),
        child: const Text('Voltar às minhas vagas'),
      ),
    );
  }
}
