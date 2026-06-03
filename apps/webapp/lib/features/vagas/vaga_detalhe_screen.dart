import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/time/turni_datetime.dart';
import '../../ds/tokens.dart';
import 'candidatura_service.dart';
import 'vaga_detalhe_service.dart';

/// STORY-049 / SCREEN-STORY-049 — detalhe da vaga + breakdown explicável do match. Mostra o
/// cabeçalho da vaga e o bloco "Por que estou vendo esta vaga" com os 4 componentes (ícone,
/// barra, X/Y, prosa — CA-2/CA-3), o total agregado (CA-4) e o CTA "Candidatar-se" / estado
/// "Você já se candidatou" (CA-5/CA-6). RBAC (CA-7): contratante (403) cai em "sem permissão";
/// vaga indisponível (404) cai em estado próprio. A ação de candidatar (modal de confirmação +
/// 3 gates + retirada) é STORY-050 / SCREEN-STORY-050 — ver `candidatura_service.dart`.
class VagaDetalheScreen extends StatefulWidget {
  const VagaDetalheScreen({
    super.key,
    required this.vagaId,
    VagaDetalheService? service,
    CandidaturaService? candidaturaService,
  }) : _service = service,
       _candidaturaService = candidaturaService;

  final int vagaId;
  final VagaDetalheService? _service;
  final CandidaturaService? _candidaturaService;

  @override
  State<VagaDetalheScreen> createState() => _VagaDetalheScreenState();
}

enum _Phase { loading, semPermissao, indisponivel, erro, pronto }

class _VagaDetalheScreenState extends State<VagaDetalheScreen> {
  late final VagaDetalheService _service =
      widget._service ?? VagaDetalheService();
  late final CandidaturaService _candidatura =
      widget._candidaturaService ?? CandidaturaService();

  _Phase _phase = _Phase.loading;
  VagaDetalhe? _vaga;

  // Overrides otimistas (STORY-050): após candidatar/retirar atualizamos a barra de ação
  // in-place, sem refazer o GET (SCREEN-050 §4.3/§4.9). null = usa o valor do servidor.
  bool? _jaCandidatouOverride;
  CandidaturaResumo? _candidaturaOverride;

  // STORY-052 — revisão pós-edição: busy do botão e flag para sumir o banner após manter/retirar.
  bool _revisaoBusy = false;
  bool _revisaoResolvida = false;

  bool get _jaCandidatou => _jaCandidatouOverride ?? _vaga!.jaCandidatou;
  CandidaturaResumo? get _candidaturaVigente =>
      _jaCandidatouOverride == null ? _vaga!.candidatura : _candidaturaOverride;

  // Mostra o banner de revisão (CA-11) enquanto a candidatura está em revisão e o profissional
  // ainda não resolveu (manter/retirar) nesta sessão de tela.
  bool get _mostrarRevisao =>
      _vaga!.emRevisao && !_revisaoResolvida && _vaga!.revisao != null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(VagaDetalheScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Se o go_router reusar este State ao navegar entre /vaga/A e /vaga/B (mesma rota, param
    // diferente — ex.: candidatar numa vaga e abrir outra, STORY-050), o widget chega com um
    // vagaId novo mas o State antigo: recarrega o detalhe da vaga certa.
    if (oldWidget.vagaId != widget.vagaId) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _phase = _Phase.loading;
      _jaCandidatouOverride = null;
      _candidaturaOverride = null;
      _revisaoBusy = false;
      _revisaoResolvida = false;
    });
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

  /// Candidatura em 1 toque (STORY-050): abre o modal de confirmação; ao confirmar, o modal
  /// chama o endpoint e devolve o desfecho terminal (201/409/422/403). Rede/5xx fica no
  /// próprio modal (retry). 422 → modal de bloqueio do gate; 201/409 → badge + toast.
  Future<void> _candidatar() async {
    final accent = _accent(Theme.of(context).brightness == Brightness.dark);
    final result = await _present<CandidaturaResult>(
      _ConfirmarSheet(
        vaga: _vaga!,
        accent: accent,
        candidatar: () => _candidatura.candidatar(widget.vagaId),
      ),
    );
    if (!mounted || result == null) return;

    switch (result) {
      case CandidaturaCriada(:final id, :final candidatouEm):
        setState(() {
          _jaCandidatouOverride = true;
          _candidaturaOverride = CandidaturaResumo(
            id: id,
            estado: 'pendente',
            criadaEm: candidatouEm,
          );
        });
        _toast('Candidatura enviada!');
      case CandidaturaJaExiste():
        // Corrida/idempotência (CA-6): já está candidatado — mostra o badge sem alarde.
        setState(() {
          _jaCandidatouOverride = true;
          _candidaturaOverride = const CandidaturaResumo(
            estado: 'pendente',
            criadaEm: null,
          );
        });
      case CandidaturaBloqueada(:final erro, :final mensagem, :final conflito):
        await _present<void>(
          _BloqueioSheet(
            erro: erro,
            mensagem: mensagem,
            conflito: conflito,
            accent: accent,
            onConflito: (vagaId) {
              Navigator.of(context).pop();
              context.push('/vaga/$vagaId');
            },
            onVagaFechada: () {
              Navigator.of(context).pop();
              context.go('/feed');
            },
          ),
        );
      case CandidaturaForbidden():
        _toast('Esta área é do profissional.');
      case CandidaturaErroRede():
        break; // tratado dentro do próprio modal (retry); nada a fazer aqui.
    }
  }

  /// Retirada voluntária (CA-8): confirma e chama o DELETE. 200 → CTA volta a "Candidatar-se";
  /// 409 → toast "não pode mais ser retirada".
  Future<void> _retirar(CandidaturaResumo candidatura) async {
    final accent = _accent(Theme.of(context).brightness == Brightness.dark);
    final confirmou = await _present<bool>(_RetirarSheet(accent: accent));
    if (!mounted || confirmou != true) return;

    final result = await _candidatura.retirar(candidatura.id ?? 0);
    if (!mounted) return;
    switch (result) {
      case RetirarSuccess():
        setState(() {
          _jaCandidatouOverride = false;
          _candidaturaOverride = null;
        });
        _toast('Candidatura retirada.');
      case RetirarConflict():
        _toast('Esta candidatura não pode mais ser retirada.');
      case RetirarErro():
        _toast('Não foi possível retirar. Tente de novo.');
    }
  }

  /// STORY-052 CA-7 — mantém a candidatura após a edição. 200 → volta a `pendente` (banner some);
  /// 409 → o prazo já estourou e o cron retirou (banner some, toast informa); rede → toast.
  Future<void> _manterAposEdicao() async {
    final id = _candidaturaVigente?.id;
    if (id == null) return;
    setState(() => _revisaoBusy = true);
    final result = await _candidatura.manterAposEdicao(id);
    if (!mounted) return;
    setState(() => _revisaoBusy = false);
    switch (result) {
      case RevisaoSuccess():
        setState(() {
          _revisaoResolvida = true;
          _jaCandidatouOverride = true;
          _candidaturaOverride = CandidaturaResumo(
            id: id,
            estado: 'pendente',
            criadaEm: _candidaturaVigente?.criadaEm,
          );
        });
        _toast('Candidatura mantida.');
      case RevisaoConflict():
        setState(() => _revisaoResolvida = true);
        _toast(
          'O prazo para confirmar terminou e sua candidatura saiu desta vaga.',
        );
      case RevisaoErro():
        _toast('Não foi possível agora. Tente de novo.');
    }
  }

  /// STORY-052 CA-8 — retira a candidatura após a edição (com confirmação leve). 200 → "não está
  /// mais candidatado"; 409 → o cron já retirou (mesmo desfecho visual); rede → toast.
  Future<void> _retirarAposEdicao() async {
    final id = _candidaturaVigente?.id;
    if (id == null) return;
    final accent = _accent(Theme.of(context).brightness == Brightness.dark);
    final confirmou = await _present<bool>(_RetirarSheet(accent: accent));
    if (!mounted || confirmou != true) return;

    setState(() => _revisaoBusy = true);
    final result = await _candidatura.retirarAposEdicao(id);
    if (!mounted) return;
    setState(() => _revisaoBusy = false);
    switch (result) {
      case RevisaoSuccess():
        setState(() {
          _revisaoResolvida = true;
          _jaCandidatouOverride = false;
          _candidaturaOverride = null;
        });
        _toast('Candidatura retirada.');
      case RevisaoConflict():
        setState(() {
          _revisaoResolvida = true;
          _jaCandidatouOverride = false;
          _candidaturaOverride = null;
        });
        _toast(
          'O prazo para confirmar terminou e sua candidatura saiu desta vaga.',
        );
      case RevisaoErro():
        _toast('Não foi possível agora. Tente de novo.');
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  /// Apresenta um modal: bottom-sheet no mobile, dialog centrado no desktop (SCREEN-050 §3).
  Future<T?> _present<T>(Widget child) {
    final wide = MediaQuery.of(context).size.width >= 760;
    if (wide) {
      return showDialog<T>(
        context: context,
        builder: (_) => Dialog(
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(TurniRadius.lg),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: child,
          ),
        ),
      );
    }
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => child,
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
              jaCandidatou: _jaCandidatou,
              candidatura: _candidaturaVigente,
              accent: accent,
              isDark: isDark,
              onCandidatar: _candidatar,
              onRetirar: _retirar,
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
        return _Conteudo(
          vaga: _vaga!,
          isDark: isDark,
          accent: accent,
          revisao: _mostrarRevisao ? _vaga!.revisao : null,
          revisaoBusy: _revisaoBusy,
          onManter: _manterAposEdicao,
          onRetirar: _retirarAposEdicao,
        );
    }
  }
}

// ───────────────────────── Conteúdo (caminho feliz) ─────────────────────────

class _Conteudo extends StatelessWidget {
  const _Conteudo({
    required this.vaga,
    required this.isDark,
    required this.accent,
    required this.revisao,
    required this.revisaoBusy,
    required this.onManter,
    required this.onRetirar,
  });

  final VagaDetalhe vaga;
  final bool isDark;
  final Color accent;
  final RevisaoInfo? revisao;
  final bool revisaoBusy;
  final VoidCallback onManter;
  final VoidCallback onRetirar;

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
                  if (revisao != null) ...[
                    _RevisaoBanner(
                      revisao: revisao!,
                      isDark: isDark,
                      busy: revisaoBusy,
                      onManter: onManter,
                      onRetirar: onRetirar,
                    ),
                    const SizedBox(height: TurniSpacing.lg),
                  ],
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

// ───────────────────────── Banner de revisão pós-edição (STORY-052 CA-11) ─────────────────────────

/// Faixa de revisão pós-edição: "a vaga foi editada", prazo, o que mudou (diff) e as 2 ações
/// Manter/Retirar. Cor de atenção (warnSoft), independente do acento do papel. A diferença é
/// legível sem cor (rótulo + antigo → novo) — WCAG AA (SCREEN-052 §6).
class _RevisaoBanner extends StatelessWidget {
  const _RevisaoBanner({
    required this.revisao,
    required this.isDark,
    required this.busy,
    required this.onManter,
    required this.onRetirar,
  });

  final RevisaoInfo revisao;
  final bool isDark;
  final bool busy;
  final VoidCallback onManter;
  final VoidCallback onRetirar;

  String _prazoTexto() {
    final prazo = revisao.prazoEm;
    if (prazo == null) {
      return 'Confirme em até 24h — senão sua candidatura sai sozinha.';
    }
    return 'Confirme até ${TurniDateTime.formatPrazo(prazo)} — '
        'senão sua candidatura sai sozinha.';
  }

  String _valorLinha(DiffLinha l) {
    switch (l.tipo) {
      case 'valor':
        return '${_brl((l.antes as num?)?.toDouble())} → ${_brl((l.depois as num?)?.toDouble())}';
      case 'data':
        return '${_dataHora(l.antes as String?)} → ${_dataHora(l.depois as String?)}';
      default:
        return '${l.antes} → ${l.depois}';
    }
  }

  String _brl(double? v) {
    if (v == null) return '—';
    final c = (v * 100).round();
    final reais = (c ~/ 100).toString();
    final dec = (c % 100).toString().padLeft(2, '0');
    final b = StringBuffer();
    for (var i = 0; i < reais.length; i++) {
      if (i > 0 && (reais.length - i) % 3 == 0) b.write('.');
      b.write(reais[i]);
    }
    return 'R\$ $b,$dec';
  }

  String _dataHora(String? iso) {
    final d = TurniDateTime.parse(iso);
    return d == null ? '—' : TurniDateTime.formatDataHoraCurta(d);
  }

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? TurniColors.warnSoftDark : TurniColors.warnSoftLight;
    final ink = isDark ? TurniColors.warnDark : TurniColors.warnLight;
    final strong = isDark
        ? TurniColors.textStrongDark
        : TurniColors.textStrongLight;
    final muted = isDark
        ? TurniColors.textMutedDark
        : TurniColors.textMutedLight;
    final verde = isDark ? TurniColors.accentDark : TurniColors.accentLight;

    return Semantics(
      liveRegion: true,
      child: Container(
        key: const Key('vaga-detalhe-revisao-banner'),
        padding: const EdgeInsets.all(TurniSpacing.md),
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: ink.withAlpha(110)),
          borderRadius: const BorderRadius.all(TurniRadius.md),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.edit_calendar_outlined, size: 20, color: ink),
                const SizedBox(width: TurniSpacing.sm),
                Expanded(
                  child: Text(
                    'Esta vaga foi editada',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: strong,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: TurniSpacing.xs),
            Text(
              _prazoTexto(),
              style: TextStyle(
                fontSize: 14,
                color: strong,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (revisao.diff.isNotEmpty) ...[
              const SizedBox(height: TurniSpacing.md),
              Text(
                'O QUE MUDOU',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: muted,
                  letterSpacing: .5,
                ),
              ),
              const SizedBox(height: TurniSpacing.xs),
              for (final l in revisao.diff)
                Padding(
                  key: Key('vaga-detalhe-revisao-diff-${l.campo}'),
                  padding: const EdgeInsets.symmetric(
                    vertical: TurniSpacing.xs,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 96,
                        child: Text(
                          l.label,
                          style: TextStyle(
                            fontSize: 13,
                            color: muted,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Semantics(
                          label: '${l.label}: de ${l.antes} para ${l.depois}',
                          child: Text(
                            _valorLinha(l),
                            style: TextStyle(
                              fontSize: 14,
                              color: strong,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            const SizedBox(height: TurniSpacing.md),
            FilledButton(
              key: const Key('vaga-detalhe-manter-btn'),
              onPressed: busy ? null : onManter,
              style: FilledButton.styleFrom(
                backgroundColor: verde,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
                shape: const StadiumBorder(),
              ),
              child: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Manter candidatura'),
            ),
            const SizedBox(height: TurniSpacing.sm),
            OutlinedButton(
              key: const Key('vaga-detalhe-retirar-btn'),
              onPressed: busy ? null : onRetirar,
              style: OutlinedButton.styleFrom(
                foregroundColor: strong,
                minimumSize: const Size.fromHeight(48),
                shape: const StadiumBorder(),
              ),
              child: const Text('Retirar'),
            ),
          ],
        ),
      ),
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
            TurniDateTime.formatIntervalo(vaga.dataInicio, vaga.dataFim),
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
    required this.jaCandidatou,
    required this.candidatura,
    required this.accent,
    required this.isDark,
    required this.onCandidatar,
    required this.onRetirar,
  });

  final VagaDetalhe vaga;
  final bool jaCandidatou;
  final CandidaturaResumo? candidatura;
  final Color accent;
  final bool isDark;
  final VoidCallback onCandidatar;
  final void Function(CandidaturaResumo) onRetirar;

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
    if (jaCandidatou) {
      return _JaCandidatou(candidatura: candidatura, onRetirar: onRetirar);
    }

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
  const _JaCandidatou({required this.candidatura, required this.onRetirar});

  final CandidaturaResumo? candidatura;
  final void Function(CandidaturaResumo) onRetirar;

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
            'em ${TurniDateTime.formatDataCurta(quando)} às ${TurniDateTime.formatHora(quando)}',
            style: const TextStyle(
              fontSize: 13,
              color: TurniColors.textMutedLight,
            ),
          ),
        ],
        if ((candidatura?.pendente ?? false) && candidatura?.id != null) ...[
          const SizedBox(height: 4),
          TextButton(
            key: const Key('vaga-detalhe-retirar-btn'),
            onPressed: () => onRetirar(candidatura!),
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

// ───────────────────────── Modais de candidatura (STORY-050) ─────────────────────────

/// Mapeia o código de `erro` do gate para o título curto do modal de bloqueio (SCREEN-050 §5).
/// A prosa (`mensagem`) vem do back e é exibida verbatim; o título dá o contexto acima dela.
String _tituloBloqueio(String erro) => switch (erro) {
  'gate_avaliacao' => 'Avalie seu último turno',
  'conflito_horario' => 'Conflito de horário',
  'habitualidade_bloqueio' => 'Limite semanal neste local',
  'vaga_fechada' => 'Vaga indisponível',
  _ => 'Não foi possível se candidatar',
};

/// sheet.confirm — confirmação deliberada antes de enviar (princípio #1). Dono do estado
/// "enviando" + erro de rede inline (retry). Só fecha (pop com o resultado) num desfecho
/// terminal (201/409/422/403); rede/5xx mantém o modal aberto (SCREEN-050 §4.2/§4.8).
class _ConfirmarSheet extends StatefulWidget {
  const _ConfirmarSheet({
    required this.vaga,
    required this.accent,
    required this.candidatar,
  });

  final VagaDetalhe vaga;
  final Color accent;
  final Future<CandidaturaResult> Function() candidatar;

  @override
  State<_ConfirmarSheet> createState() => _ConfirmarSheetState();
}

class _ConfirmarSheetState extends State<_ConfirmarSheet> {
  bool _enviando = false;
  bool _erroRede = false;

  Future<void> _confirmar() async {
    setState(() {
      _enviando = true;
      _erroRede = false;
    });
    final result = await widget.candidatar();
    if (!mounted) return;
    if (result is CandidaturaErroRede) {
      setState(() {
        _enviando = false;
        _erroRede = true;
      });
      return;
    }
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final v = widget.vaga;
    final estab = v.estabelecimento?.trim();
    final resumo = [
      if (estab != null && estab.isNotEmpty)
        '${v.funcao} · $estab'
      else
        v.funcao,
      '${TurniDateTime.formatIntervalo(v.dataInicio, v.dataFim)} · ${_formatBRL(v.valor)}',
    ].join('\n');

    return _SheetShell(
      testKey: 'candidatura-confirmar-sheet',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Confirmar candidatura',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: isDark
                  ? TurniColors.textStrongDark
                  : TurniColors.textStrongLight,
            ),
          ),
          const SizedBox(height: TurniSpacing.sm),
          Text(
            resumo,
            key: const Key('candidatura-confirmar-resumo'),
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              color: isDark
                  ? TurniColors.textMutedDark
                  : TurniColors.textMutedLight,
            ),
          ),
          const SizedBox(height: TurniSpacing.lg),
          FilledButton(
            key: const Key('candidatura-confirmar-btn'),
            onPressed: _enviando ? null : _confirmar,
            style: FilledButton.styleFrom(
              backgroundColor: widget.accent,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 48),
              shape: const StadiumBorder(),
            ),
            child: _enviando
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Confirmar candidatura'),
          ),
          const SizedBox(height: TurniSpacing.xs),
          TextButton(
            key: const Key('candidatura-cancelar-btn'),
            onPressed: _enviando ? null : () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          if (_erroRede) ...[
            const SizedBox(height: TurniSpacing.xs),
            Container(
              key: const Key('candidatura-confirmar-erro'),
              padding: const EdgeInsets.all(TurniSpacing.sm),
              decoration: BoxDecoration(
                color: isDark
                    ? TurniColors.errorSoftDark
                    : TurniColors.errorSoftLight,
                borderRadius: const BorderRadius.all(TurniRadius.sm),
              ),
              child: Text(
                'Não foi possível enviar. Verifique sua conexão.',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark
                      ? TurniColors.errorDark
                      : TurniColors.errorLight,
                ),
              ),
            ),
            TextButton(
              key: const Key('candidatura-retry-btn'),
              onPressed: _confirmar,
              child: const Text('Tentar de novo'),
            ),
          ],
        ],
      ),
    );
  }
}

/// block.modal — bloqueio por gate: cabeçalho warning + prosa do back + (em conflito) card
/// clicável da vaga em conflito. Nunca vermelho (gate ≠ erro — SCREEN-050 §Tema).
class _BloqueioSheet extends StatelessWidget {
  const _BloqueioSheet({
    required this.erro,
    required this.mensagem,
    required this.conflito,
    required this.accent,
    required this.onConflito,
    required this.onVagaFechada,
  });

  final String erro;
  final String mensagem;
  final ConflitoInfo? conflito;
  final Color accent;
  final void Function(int vagaId) onConflito;
  final VoidCallback onVagaFechada;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final warnInk = isDark
        ? TurniColors.warnDark
        : TurniColors.contratanteAccentInkLight;
    final acaoFechada = erro == 'vaga_fechada';

    return _SheetShell(
      testKey: 'candidatura-bloqueio-modal',
      child: Semantics(
        liveRegion: true,
        child: Column(
          key: Key('candidatura-bloqueio-$erro'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: isDark
                        ? TurniColors.warnSoftDark
                        : TurniColors.warnSoftLight,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.warning_amber_rounded,
                    size: 17,
                    color: warnInk,
                  ),
                ),
                const SizedBox(width: TurniSpacing.sm),
                Expanded(
                  child: Text(
                    _tituloBloqueio(erro),
                    key: const Key('candidatura-bloqueio-titulo'),
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: isDark
                          ? TurniColors.textStrongDark
                          : TurniColors.textStrongLight,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: TurniSpacing.sm),
            Text(
              mensagem,
              key: const Key('candidatura-bloqueio-mensagem'),
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: isDark
                    ? TurniColors.textMutedDark
                    : TurniColors.textMutedLight,
              ),
            ),
            if (conflito != null) ...[
              const SizedBox(height: TurniSpacing.md),
              _ConflitoCard(
                conflito: conflito!,
                accent: accent,
                isDark: isDark,
                onTap: () => onConflito(conflito!.vagaId),
              ),
            ],
            const SizedBox(height: TurniSpacing.md),
            TextButton(
              key: const Key('candidatura-bloqueio-acao-btn'),
              onPressed: acaoFechada
                  ? onVagaFechada
                  : () => Navigator.of(context).pop(),
              child: Text(acaoFechada ? 'Voltar ao feed' : 'Entendi'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Card clicável da vaga em conflito (SCREEN-050 §4.5). Fail-soft: sem função/estab. mostra só
/// o CTA "Ver vaga em conflito" — o link ainda navega via vagaId.
class _ConflitoCard extends StatelessWidget {
  const _ConflitoCard({
    required this.conflito,
    required this.accent,
    required this.isDark,
    required this.onTap,
  });

  final ConflitoInfo conflito;
  final Color accent;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textStrong = isDark
        ? TurniColors.textStrongDark
        : TurniColors.textStrongLight;
    final textMuted = isDark
        ? TurniColors.textMutedDark
        : TurniColors.textMutedLight;
    final titulo = [
      conflito.funcao,
      conflito.estabelecimento,
    ].whereType<String>().where((s) => s.trim().isNotEmpty).join(' · ');
    final quando = conflito.dataInicio != null && conflito.dataFim != null
        ? TurniDateTime.formatIntervalo(conflito.dataInicio!, conflito.dataFim!)
        : null;

    return Semantics(
      button: true,
      label: titulo.isEmpty
          ? 'Ver vaga em conflito'
          : '$titulo${quando != null ? ', $quando' : ''}. Ver vaga em conflito.',
      child: InkWell(
        key: const Key('candidatura-conflito-card'),
        onTap: onTap,
        borderRadius: const BorderRadius.all(TurniRadius.md),
        child: Container(
          padding: const EdgeInsets.all(TurniSpacing.sm),
          decoration: BoxDecoration(
            color: isDark
                ? TurniColors.surfacePageDark
                : TurniColors.surfacePageLight,
            border: Border.all(
              color: isDark
                  ? TurniColors.borderSubtleDark
                  : TurniColors.borderSubtleLight,
            ),
            borderRadius: const BorderRadius.all(TurniRadius.md),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (titulo.isNotEmpty)
                Text(
                  titulo,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: textStrong,
                  ),
                ),
              if (quando != null) ...[
                const SizedBox(height: 2),
                Text(quando, style: TextStyle(fontSize: 13, color: textMuted)),
              ],
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Ver vaga em conflito',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: accent,
                    ),
                  ),
                  Icon(Icons.chevron_right, size: 18, color: accent),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// sheet.confirm de retirada (CA-8 / §4.9). Pop `true` = retirar, `false`/dismiss = cancela.
class _RetirarSheet extends StatelessWidget {
  const _RetirarSheet({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return _SheetShell(
      testKey: 'candidatura-retirar-sheet',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Retirar candidatura?',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: isDark
                  ? TurniColors.textStrongDark
                  : TurniColors.textStrongLight,
            ),
          ),
          const SizedBox(height: TurniSpacing.sm),
          Text(
            'Você pode se candidatar de novo enquanto a vaga estiver aberta.',
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              color: isDark
                  ? TurniColors.textMutedDark
                  : TurniColors.textMutedLight,
            ),
          ),
          const SizedBox(height: TurniSpacing.lg),
          TextButton(
            key: const Key('candidatura-retirar-confirmar-btn'),
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: isDark
                  ? TurniColors.errorDark
                  : TurniColors.errorLight,
            ),
            child: const Text('Retirar'),
          ),
          TextButton(
            key: const Key('candidatura-retirar-cancelar-btn'),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }
}

/// Casca comum dos modais: padding + SafeArea + acomoda o teclado (mobile). O drag handle do
/// bottom-sheet é do `showDragHandle`; no dialog (desktop) a casca é só padding.
class _SheetShell extends StatelessWidget {
  const _SheetShell({required this.testKey, required this.child});

  final String testKey;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: Key(testKey),
      padding: EdgeInsets.fromLTRB(
        TurniSpacing.lg,
        TurniSpacing.sm,
        TurniSpacing.lg,
        TurniSpacing.lg + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(top: false, child: child),
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

String _dois(int n) => n.toString().padLeft(2, '0');

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
