import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/format/brl.dart';
import '../../core/time/turni_datetime.dart';
import '../../ds/tokens.dart';
import '../auth/auth_service.dart';
import 'geofencing_copy.dart';
import 'pin_checkin_screen.dart';
import 'pin_checkin_service.dart';
import 'turno_detalhe_service.dart';
import 'turnos_lista_screen.dart' show TurnoEstadoBadge;

/// STORY-060 / SCREEN-STORY-060 — detalhe do turno (`/turnos/{id}`, rota compartilhada).
///
/// A casa do turno: header com estado (badge) + função/onde/quando (CA-2), card de valor com
/// visibilidade por papel (profissional vê o que recebe; contratante vê valor+taxa+total —
/// domain/pagamento.md), link para o aceite eletrônico em modal somente-leitura (CA-5), área
/// de ações placeholder que as STORY-061+ preenchem (CA-4) e timeline descendente do audit
/// log filtrado (CA-3). O papel vem do PAYLOAD (presença de `total_contratante`) — servidor é
/// a fonte de verdade do RBAC; 403/404 caem no mesmo "não encontrado" fail-secure (§4.5).
class TurnoDetalheScreen extends StatefulWidget {
  const TurnoDetalheScreen({
    super.key,
    required this.turnoId,
    TurnoDetalheService? service,
    PinCheckinService? pinService,
  }) : _service = service,
       _pinService = pinService;

  final String turnoId;
  final TurnoDetalheService? _service;
  final PinCheckinService? _pinService;

  @override
  State<TurnoDetalheScreen> createState() => _TurnoDetalheScreenState();
}

enum _Phase { loading, naoEncontrado, erro, pronto }

class _TurnoDetalheScreenState extends State<TurnoDetalheScreen> {
  late final TurnoDetalheService _service =
      widget._service ?? TurnoDetalheService();
  late final PinCheckinService _pinService =
      widget._pinService ?? PinCheckinService();

  _Phase _phase = _Phase.loading;
  TurnoDetalhe? _turno;

  /// Papel para tema/navegação ANTES do payload chegar (loading/erro/não-encontrado):
  /// sessão local. Depois do fetch, o payload manda (souContratante).
  bool get _ehContratante =>
      _turno?.souContratante ?? (AuthService().session?.role == 'contratante');

  String get _listaDoPapel =>
      _ehContratante ? '/contratante/turnos' : '/profissional/turnos';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _phase = _Phase.loading);
    final result = await _service.fetch(widget.turnoId);
    if (!mounted) return;
    setState(() {
      switch (result) {
        case TurnoDetalheSuccess(:final turno):
          _turno = turno;
          _phase = _Phase.pronto;
        case TurnoDetalheNaoEncontrado():
          _phase = _Phase.naoEncontrado;
        case TurnoDetalheError():
          _phase = _Phase.erro;
      }
    });
  }

  Color _accent(bool isDark) => _ehContratante
      ? (isDark
            ? TurniColors.contratanteAccentDark
            : TurniColors.contratanteAccentLight)
      : (isDark ? TurniColors.accentDark : TurniColors.accentLight);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfacePage = isDark
        ? TurniColors.surfacePageDark
        : TurniColors.surfacePageLight;

    return Scaffold(
      key: const Key('turno-detalhe-screen'),
      backgroundColor: surfacePage,
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Voltar',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(_listaDoPapel),
        ),
        title: const Text('Detalhe do turno'),
      ),
      body: SafeArea(child: _body(isDark)),
    );
  }

  Widget _body(bool isDark) {
    switch (_phase) {
      case _Phase.loading:
        return _skeleton(isDark);
      case _Phase.naoEncontrado:
        return _NaoEncontradoView(
          accent: _accent(isDark),
          cta: _ehContratante ? 'Ir para turnos' : 'Ir para meus turnos',
          destino: _listaDoPapel,
        );
      case _Phase.erro:
        return _ErroView(isDark: isDark, onRetry: _load);
      case _Phase.pronto:
        return _DetalheView(
          turno: _turno!,
          isDark: isDark,
          accent: _accent(isDark),
          pinService: _pinService,
          onRecarregar: _load,
        );
    }
  }

  Widget _skeleton(bool isDark) {
    final bar = isDark
        ? TurniColors.borderSubtleDark
        : TurniColors.borderSubtleLight;
    final surface = isDark ? TurniColors.surfaceDark : TurniColors.surfaceLight;
    Widget line(double w) => Container(
      width: w,
      height: 12,
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: bar,
        borderRadius: BorderRadius.circular(6),
      ),
    );
    Widget card(List<double> widths) => Container(
      margin: const EdgeInsets.only(bottom: TurniSpacing.md),
      padding: const EdgeInsets.all(TurniSpacing.md),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: const BorderRadius.all(TurniRadius.md),
        border: Border.all(color: bar),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: widths.map(line).toList(growable: false),
      ),
    );
    return ListView(
      key: const Key('turno-detalhe-skeleton'),
      padding: const EdgeInsets.all(TurniSpacing.md),
      children: [
        card(const [90, 160, 200]),
        card(const [110, 140]),
        card(const [180, 90]),
        card(const [150, 90]),
      ],
    );
  }
}

// ───────────────────────── Caminho feliz ─────────────────────────

class _DetalheView extends StatelessWidget {
  const _DetalheView({
    required this.turno,
    required this.isDark,
    required this.accent,
    required this.pinService,
    required this.onRecarregar,
  });

  final TurnoDetalhe turno;
  final bool isDark;
  final Color accent;
  final PinCheckinService pinService;
  final Future<void> Function() onRecarregar;

  /// STORY-061 — a área de ações vira o bloco do check-in para o PROFISSIONAL em
  /// `confirmado`/`aguardando_checkin` (a janela vem no payload só para ele — CA-1/CA-8).
  /// Contratante e demais estados não-terminais seguem com o placeholder da 060.
  bool get _mostraCheckin =>
      !turno.souContratante &&
      turno.checkinJanela != null &&
      (turno.estadoRaw == 'confirmado' ||
          turno.estadoRaw == 'aguardando_checkin');

  @override
  Widget build(BuildContext context) {
    final colTurno = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _HeaderCard(turno: turno, isDark: isDark),
        const SizedBox(height: TurniSpacing.md),
        _ValorCard(turno: turno, isDark: isDark),
        const SizedBox(height: TurniSpacing.sm),
        if (turno.aceite != null)
          _AceiteLink(aceite: turno.aceite!, isDark: isDark, accent: accent),
        // CA-4 da 060 — moldura do "botão grande"; terminais não têm (§4.1).
        if (!turno.estadoTerminal) ...[
          const SizedBox(height: TurniSpacing.sm),
          if (_mostraCheckin)
            _AcoesCheckin(
              turno: turno,
              isDark: isDark,
              accent: accent,
              pinService: pinService,
              onRecarregar: onRecarregar,
            )
          else
            _AcoesPlaceholder(isDark: isDark),
        ],
      ],
    );

    final colHistorico = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Padding(
            padding: const EdgeInsets.only(
              top: TurniSpacing.lg,
              bottom: TurniSpacing.sm,
            ),
            child: Text(
              'Histórico',
              key: const Key('turno-detalhe-historico-header'),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: isDark
                    ? TurniColors.textMutedDark
                    : TurniColors.textMutedLight,
              ),
            ),
          ),
        ),
        _Timeline(turno: turno, isDark: isDark, accent: accent),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // Desktop ≥1024: 2 colunas (turno × histórico — SCREEN-060 §3); senão empilha.
        final duasColunas = constraints.maxWidth >= 1024;
        final conteudo = duasColunas
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 420, child: colTurno),
                  const SizedBox(width: TurniSpacing.xl),
                  Expanded(child: colHistorico),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [colTurno, colHistorico],
              );

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            TurniSpacing.md,
            TurniSpacing.md,
            TurniSpacing.md,
            TurniSpacing.xl,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: conteudo,
            ),
          ),
        );
      },
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.turno, required this.isDark});

  final TurnoDetalhe turno;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final textStrong = isDark
        ? TurniColors.textStrongDark
        : TurniColors.textStrongLight;
    final textMuted = isDark
        ? TurniColors.textMutedDark
        : TurniColors.textMutedLight;

    return MergeSemantics(
      child: _Card(
        isDark: isDark,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: TurnoEstadoBadge(
                estado: turno.estado,
                chave: 'turno-detalhe-estado',
              ),
            ),
            const SizedBox(height: TurniSpacing.sm),
            Text(
              turno.funcao,
              key: const Key('turno-detalhe-funcao'),
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w700,
                color: textStrong,
              ),
            ),
            // Contratante vê QUEM VEM acima do estabelecimento (SCREEN-060 §3);
            // campo ausente → linha omitida, nunca quebra (§4.6).
            if (turno.souContratante &&
                (turno.profissional ?? '').isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(
                turno.profissional!,
                style: TextStyle(fontSize: 15, color: textStrong),
              ),
            ],
            if ((turno.estabelecimento ?? '').isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(
                turno.estabelecimento!,
                key: const Key('turno-detalhe-onde'),
                style: TextStyle(fontSize: 15, color: textMuted),
              ),
            ],
            const SizedBox(height: 3),
            Text(
              TurniDateTime.formatIntervalo(turno.dataInicio, turno.dataFim),
              key: const Key('turno-detalhe-quando'),
              style: TextStyle(fontSize: 15, color: textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _ValorCard extends StatelessWidget {
  const _ValorCard({required this.turno, required this.isDark});

  final TurnoDetalhe turno;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final textStrong = isDark
        ? TurniColors.textStrongDark
        : TurniColors.textStrongLight;
    final textMuted = isDark
        ? TurniColors.textMutedDark
        : TurniColors.textMutedLight;
    final tituloStyle = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.4,
      color: textMuted,
    );

    // CA-2 / domain/pagamento.md §Visibilidade — o payload já vem filtrado; aqui só layout.
    final corpo = turno.souContratante
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('PAGAMENTO DESTE TURNO', style: tituloStyle),
              const SizedBox(height: TurniSpacing.sm),
              _linha(
                'Valor do profissional',
                formatBRL(turno.valor),
                textMuted,
                textStrong,
              ),
              const SizedBox(height: 10),
              _linha(
                'Taxa Turni',
                formatBRL(turno.taxaTurni ?? 0),
                textMuted,
                textStrong,
              ),
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Container(
                  padding: const EdgeInsets.only(top: 10),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: isDark
                            ? TurniColors.borderSubtleDark
                            : TurniColors.borderSubtleLight,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: textStrong,
                        ),
                      ),
                      Text(
                        formatBRL(turno.totalContratante ?? 0),
                        key: const Key('turno-detalhe-valor-total'),
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: textStrong,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('VOCÊ RECEBE', style: tituloStyle),
              const SizedBox(height: 6),
              Text(
                formatBRL(turno.valor),
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: textStrong,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'valor integral · taxa Turni cobrada do contratante',
                style: TextStyle(fontSize: 13, color: textMuted),
              ),
            ],
          );

    return _Card(
      isDark: isDark,
      key: const Key('turno-detalhe-valor'),
      child: corpo,
    );
  }

  Widget _linha(String rotulo, String valor, Color muted, Color strong) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(rotulo, style: TextStyle(fontSize: 15, color: muted)),
      Text(valor, style: TextStyle(fontSize: 15, color: strong)),
    ],
  );
}

class _AceiteLink extends StatelessWidget {
  const _AceiteLink({
    required this.aceite,
    required this.isDark,
    required this.accent,
  });

  final AceiteDoTurno aceite;
  final bool isDark;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final ink = isDark ? accent : accent;
    return InkWell(
      key: const Key('turno-detalhe-aceite-btn'),
      borderRadius: const BorderRadius.all(TurniRadius.sm),
      onTap: () => _abrirModal(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: TurniSpacing.xs,
          vertical: 12, // alvo ≥48dp
        ),
        child: Row(
          children: [
            Icon(Icons.description_outlined, size: 20, color: ink),
            const SizedBox(width: TurniSpacing.sm),
            Text(
              'Ver aceite eletrônico',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: ink,
              ),
            ),
            const Spacer(),
            Icon(
              Icons.chevron_right,
              size: 20,
              color: isDark
                  ? TurniColors.textMutedDark
                  : TurniColors.textMutedLight,
            ),
          ],
        ),
      ),
    );
  }

  void _abrirModal(BuildContext context) {
    final emitido = aceite.emitidoEm == null
        ? 'somente leitura'
        : 'Emitido em ${TurniDateTime.formatEvento(aceite.emitidoEm!)} · somente leitura';
    final largura = MediaQuery.sizeOf(context).width;

    // Documento imutável (ADR-010/ADR-015): só ler e fechar. Sheet cheio no mobile,
    // dialog central no desktop (SCREEN-060 §4.7).
    final corpo = _AceiteModal(aceite: aceite, subtitulo: emitido);
    if (largura >= 1024) {
      showDialog<void>(
        context: context,
        builder: (_) => Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720, maxHeight: 640),
            child: corpo,
          ),
        ),
      );
    } else {
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => FractionallySizedBox(heightFactor: 0.92, child: corpo),
      );
    }
  }
}

class _AceiteModal extends StatelessWidget {
  const _AceiteModal({required this.aceite, required this.subtitulo});

  final AceiteDoTurno aceite;
  final String subtitulo;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textMuted = isDark
        ? TurniColors.textMutedDark
        : TurniColors.textMutedLight;

    return Column(
      key: const Key('aceite-modal'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            TurniSpacing.md,
            TurniSpacing.md,
            TurniSpacing.sm,
            TurniSpacing.sm,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Aceite eletrônico',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitulo,
                      style: TextStyle(fontSize: 13, color: textMuted),
                    ),
                  ],
                ),
              ),
              IconButton(
                key: const Key('aceite-modal-fechar'),
                tooltip: 'Fechar',
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              TurniSpacing.lg,
              TurniSpacing.md,
              TurniSpacing.lg,
              TurniSpacing.xl,
            ),
            child: Text(
              aceite.conteudoRenderizado,
              key: const Key('aceite-modal-conteudo'),
              style: const TextStyle(fontSize: 15, height: 1.6),
            ),
          ),
        ),
      ],
    );
  }
}

class _AcoesPlaceholder extends StatelessWidget {
  const _AcoesPlaceholder({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final textStrong = isDark
        ? TurniColors.textStrongDark
        : TurniColors.textStrongLight;
    final textMuted = isDark
        ? TurniColors.textMutedDark
        : TurniColors.textMutedLight;
    final border = isDark
        ? TurniColors.borderSubtleDark
        : TurniColors.borderSubtleLight;

    return Container(
      key: const Key('turno-detalhe-acoes'),
      padding: const EdgeInsets.symmetric(
        vertical: TurniSpacing.lg,
        horizontal: TurniSpacing.md,
      ),
      decoration: BoxDecoration(
        color: isDark ? TurniColors.surfaceDark : TurniColors.surfaceLight,
        borderRadius: const BorderRadius.all(TurniRadius.md),
        border: Border.all(color: border, style: BorderStyle.solid),
      ),
      child: Column(
        children: [
          Text(
            'Nenhuma ação disponível no momento',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: textStrong,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'As ações deste turno aparecem aqui conforme ele avança.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.5, color: textMuted, height: 1.45),
          ),
        ],
      ),
    );
  }
}

// ───────────────────── Área de ações do check-in (STORY-061 / SCREEN-061) ─────────────────────

enum _JanelaEstado { antes, aberta, depois }

/// Bloco do PIN de check-in na área de ações (CA-1/CA-2): janela aberta/antes/depois,
/// loading "um gesto só" (captura geo + POST), erro com retry e — em
/// `aguardando_checkin` — Gerar novo PIN + Cancelar PIN (§4.7).
class _AcoesCheckin extends StatefulWidget {
  const _AcoesCheckin({
    required this.turno,
    required this.isDark,
    required this.accent,
    required this.pinService,
    required this.onRecarregar,
  });

  final TurnoDetalhe turno;
  final bool isDark;
  final Color accent;
  final PinCheckinService pinService;
  final Future<void> Function() onRecarregar;

  @override
  State<_AcoesCheckin> createState() => _AcoesCheckinState();
}

class _AcoesCheckinState extends State<_AcoesCheckin> {
  bool _gerando = false;
  bool _cancelando = false;
  String? _erroMsg;
  Future<void> Function()? _retry;

  bool get _aguardando => widget.turno.estadoRaw == 'aguardando_checkin';

  _JanelaEstado get _janela {
    final j = widget.turno.checkinJanela!;
    final agora = DateTime.now();
    if (agora.isBefore(j.abreEm)) return _JanelaEstado.antes;
    if (agora.isAfter(j.fechaEm)) return _JanelaEstado.depois;
    return _JanelaEstado.aberta;
  }

  Future<void> _gerar() async {
    setState(() {
      _gerando = true;
      _erroMsg = null;
    });

    final result = await widget.pinService.gerar(widget.turno.id);
    if (!mounted) return;
    setState(() => _gerando = false);

    switch (result) {
      case PinGerado(:final pin, :final geofencing):
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => PinCheckinScreen(
              turnoId: widget.turno.id,
              pin: pin,
              geofencing: geofencing,
              funcao: widget.turno.funcao,
              estabelecimento: widget.turno.estabelecimento,
              pinService: widget.pinService,
            ),
          ),
        );
        // Voltou da tela do PIN (cancelou ou saiu): o detalhe recarrega a verdade.
        await widget.onRecarregar();
      case PinForaDaJanela() || PinGeracaoEstadoInvalido():
        // Servidor é a fonte de verdade (relógio do device pode mentir, ou o turno
        // mudou em outra aba): recarrega para reapresentar o estado real.
        await widget.onRecarregar();
      case PinGeracaoErro():
        setState(() {
          _erroMsg = 'Não foi possível gerar o PIN. Verifique sua conexão.';
          _retry = _gerar;
        });
    }
  }

  Future<void> _cancelar() async {
    setState(() {
      _cancelando = true;
      _erroMsg = null;
    });

    final result = await widget.pinService.cancelar(widget.turno.id);
    if (!mounted) return;
    setState(() => _cancelando = false);

    switch (result) {
      case PinCancelado() || PinCancelEstadoInvalido():
        await widget.onRecarregar();
      case PinCancelErro():
        setState(() {
          _erroMsg = 'Não foi possível cancelar o PIN.';
          _retry = _cancelar;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textStrong = widget.isDark
        ? TurniColors.textStrongDark
        : TurniColors.textStrongLight;
    final textMuted = widget.isDark
        ? TurniColors.textMutedDark
        : TurniColors.textMutedLight;

    final (titulo, apoio, habilitado) = _conteudo();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_erroMsg != null) ...[
          Container(
            key: const Key('turno-pin-erro-banner'),
            padding: const EdgeInsets.symmetric(
              horizontal: TurniSpacing.md,
              vertical: TurniSpacing.sm,
            ),
            margin: const EdgeInsets.only(bottom: TurniSpacing.sm),
            decoration: BoxDecoration(
              color: widget.isDark
                  ? TurniColors.errorSoftDark
                  : TurniColors.errorSoftLight,
              borderRadius: const BorderRadius.all(TurniRadius.md),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _erroMsg!,
                    style: TextStyle(
                      fontSize: 14,
                      color: widget.isDark
                          ? TurniColors.errorDark
                          : TurniColors.errorLight,
                    ),
                  ),
                ),
                TextButton(
                  key: const Key('turno-pin-retry-btn'),
                  onPressed: () => _retry?.call(),
                  child: const Text('Tentar de novo'),
                ),
              ],
            ),
          ),
        ],
        Container(
          padding: const EdgeInsets.all(TurniSpacing.md),
          decoration: BoxDecoration(
            color: widget.isDark
                ? TurniColors.surfaceDark
                : TurniColors.surfaceLight,
            borderRadius: const BorderRadius.all(TurniRadius.md),
            border: Border.all(
              color: widget.isDark
                  ? TurniColors.borderSubtleDark
                  : TurniColors.borderSubtleLight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: textStrong,
                ),
              ),
              const SizedBox(height: 4),
              // Fora do botão de propósito: leitor de tela lê mesmo com o botão
              // desabilitado (SCREEN-061 §6).
              Text(
                apoio,
                key: const Key('turno-pin-janela-msg'),
                style: TextStyle(
                  fontSize: 13.5,
                  color: textMuted,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: TurniSpacing.md),
              FilledButton(
                key: Key(
                  _aguardando ? 'turno-pin-regen-btn' : 'turno-pin-gerar-btn',
                ),
                onPressed: habilitado && !_gerando && !_cancelando
                    ? _gerar
                    : null,
                style: FilledButton.styleFrom(
                  backgroundColor: widget.accent,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                  shape: const StadiumBorder(),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: _gerando
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Text('Confirmando sua localização…'),
                        ],
                      )
                    : Text(
                        _aguardando
                            ? 'Gerar novo PIN'
                            : 'Gerar PIN de check-in',
                      ),
              ),
              if (_aguardando) ...[
                const SizedBox(height: TurniSpacing.xs),
                TextButton(
                  key: const Key('turno-pin-cancelar-btn'),
                  onPressed: _gerando || _cancelando ? null : _cancelar,
                  style: TextButton.styleFrom(
                    foregroundColor: widget.accent,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: _cancelando
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        )
                      : const Text(
                          'Não chegou ainda? Cancelar PIN',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// Título/apoio/habilitado por estado (microcopy fixa da SCREEN-061 §5).
  (String, String, bool) _conteudo() {
    if (_aguardando) {
      return (
        'Aguardando validação do contratante',
        'Perdeu o PIN de vista? Gere um novo — o anterior deixa de valer.',
        true,
      );
    }

    final j = widget.turno.checkinJanela!;
    switch (_janela) {
      case _JanelaEstado.antes:
        final minutosAntes = widget.turno.dataInicio
            .difference(j.abreEm)
            .inMinutes;
        return (
          'Ainda não dá para fazer o check-in',
          'O PIN pode ser gerado a partir das ${TurniDateTime.formatHora(j.abreEm)} '
              '($minutosAntes min antes do início).',
          false,
        );
      case _JanelaEstado.depois:
        return (
          'O período de check-in encerrou',
          'O PIN podia ser gerado até as ${TurniDateTime.formatHora(j.fechaEm)}. '
              'Fale com o contratante se você está no local.',
          false,
        );
      case _JanelaEstado.aberta:
        return (
          'Chegou ao local?',
          'Gere o PIN de check-in e mostre ao contratante para confirmar sua chegada.',
          true,
        );
    }
  }
}

// ───────────────────────── Timeline (CA-3 — timeline.event) ─────────────────────────

class _Timeline extends StatelessWidget {
  const _Timeline({
    required this.turno,
    required this.isDark,
    required this.accent,
  });

  final TurnoDetalhe turno;
  final bool isDark;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final textMuted = isDark
        ? TurniColors.textMutedDark
        : TurniColors.textMutedLight;

    if (turno.timeline.isEmpty) {
      // §4.6 — degradado: a tela nunca quebra por causa da trilha.
      return Text(
        'Histórico indisponível no momento.',
        key: const Key('turno-detalhe-timeline'),
        style: TextStyle(fontSize: 14, color: textMuted),
      );
    }

    final eventos = turno.timeline;
    return Column(
      key: const Key('turno-detalhe-timeline'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < eventos.length; i++)
          _TimelineEventoTile(
            evento: eventos[i],
            souContratante: turno.souContratante,
            ultimo: i == eventos.length - 1,
            isDark: isDark,
            accent: accent,
          ),
      ],
    );
  }
}

class _TimelineEventoTile extends StatelessWidget {
  const _TimelineEventoTile({
    required this.evento,
    required this.souContratante,
    required this.ultimo,
    required this.isDark,
    required this.accent,
  });

  final TimelineEvento evento;
  final bool souContratante;
  final bool ultimo;
  final bool isDark;
  final Color accent;

  /// Descrição amigável por papel (SCREEN-060 §4.1 — validada pelo PO). Valores chegam
  /// já filtrados pelo servidor; aqui é só texto.
  String? get _descricao => switch (evento.tipo) {
    TimelineEventoTipo.turnoCriado => 'Candidatura aprovada.',
    // STORY-061 (§4.10) — nota de geofencing registrada na geração do PIN; sem
    // snapshot (seed antigo) o título fica sozinho.
    TimelineEventoTipo.checkinSolicitado => descricaoTimelineGeofencing(
      evento.geofencing,
    ),
    TimelineEventoTipo.checkinCancelado =>
      'Cancelado pelo profissional antes da validação.',
    TimelineEventoTipo.pagamentoPreAutorizado =>
      souContratante
          ? '${formatBRL(evento.valor ?? 0)} reservados no seu meio de pagamento.'
          : 'O contratante garantiu o pagamento deste turno.',
    TimelineEventoTipo.checkinValidado => 'Turno iniciado.',
    TimelineEventoTipo.checkoutValidado => 'Turno encerrado.',
    TimelineEventoTipo.pagamentoCapturado =>
      souContratante && evento.valor != null
          ? '${formatBRL(evento.valor!)} cobrados do seu meio de pagamento.'
          : null,
    TimelineEventoTipo.pixEnviado =>
      souContratante
          ? 'Pix enviado ao profissional.'
          : evento.valor != null
          ? '${formatBRL(evento.valor!)} enviados para você.'
          : null,
    TimelineEventoTipo.cancelado => switch (evento.lado) {
      'pro' => 'Cancelado pelo profissional.',
      'emp' => 'Cancelado pelo contratante.',
      _ => null,
    },
    TimelineEventoTipo.noShowPro => 'O check-in não aconteceu até o limite.',
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    final textStrong = isDark
        ? TurniColors.textStrongDark
        : TurniColors.textStrongLight;
    final textMuted = isDark
        ? TurniColors.textMutedDark
        : TurniColors.textMutedLight;
    final rail = isDark
        ? TurniColors.borderSubtleDark
        : TurniColors.borderStrongLight;

    final descricao = _descricao;

    return Semantics(
      container: true,
      child: IntrinsicHeight(
        child: Row(
          key: Key('timeline-evento-${evento.id}'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Dot + linha: decorativos (excludeSemantics — SCREEN-060 §6).
            ExcludeSemantics(
              child: SizedBox(
                width: 14,
                child: Column(
                  children: [
                    const SizedBox(height: 5),
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    if (!ultimo)
                      Expanded(
                        child: Container(
                          width: 2,
                          margin: const EdgeInsets.only(top: 4),
                          color: rail,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: TurniSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      evento.tipo.titulo,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: textStrong,
                      ),
                    ),
                    if (descricao != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        descricao,
                        style: TextStyle(
                          fontSize: 14,
                          color: textMuted,
                          height: 1.4,
                        ),
                      ),
                    ],
                    const SizedBox(height: 3),
                    Text(
                      TurniDateTime.formatEvento(evento.ocorridoEm),
                      style: TextStyle(fontSize: 13, color: textMuted),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── Estados auxiliares ─────────────────────────

class _NaoEncontradoView extends StatelessWidget {
  const _NaoEncontradoView({
    required this.accent,
    required this.cta,
    required this.destino,
  });

  final Color accent;
  final String cta;
  final String destino;

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const Key('turno-nao-encontrado'),
      child: Padding(
        padding: const EdgeInsets.all(TurniSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off, size: 48),
            const SizedBox(height: TurniSpacing.md),
            Text(
              'Turno não encontrado',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: TurniSpacing.sm),
            const Text(
              'O link pode estar errado ou o turno não existe mais.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: TurniSpacing.lg),
            FilledButton(
              key: const Key('turno-nao-encontrado-cta'),
              onPressed: () => context.go(destino),
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                minimumSize: const Size(220, 48),
                shape: const StadiumBorder(),
              ),
              child: Text(cta),
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
        key: const Key('turno-detalhe-erro-banner'),
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
                'Não foi possível carregar o turno. Verifique sua conexão.',
                style: TextStyle(color: fg),
              ),
            ),
            TextButton(
              key: const Key('turno-detalhe-retry-btn'),
              onPressed: onRetry,
              child: const Text('Tentar de novo'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.isDark, required this.child, super.key});

  final bool isDark;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(TurniSpacing.md),
      decoration: BoxDecoration(
        color: isDark ? TurniColors.surfaceDark : TurniColors.surfaceLight,
        border: Border.all(
          color: isDark
              ? TurniColors.borderSubtleDark
              : TurniColors.borderSubtleLight,
        ),
        borderRadius: const BorderRadius.all(TurniRadius.md),
      ),
      child: child,
    );
  }
}
