import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/format/brl.dart';
import '../../core/time/turni_datetime.dart';
import '../../ds/tokens.dart';
import '../auth/auth_service.dart';
import 'cancelar_turno_service.dart';
import 'cronometro_card.dart';
import 'cronometro_service.dart';
import 'geofencing_copy.dart';
import 'pin_checkin_screen.dart';
import 'pin_checkin_service.dart';
import 'pin_checkout_screen.dart';
import 'pin_checkout_service.dart';
import 'turno_detalhe_service.dart';
import 'turnos_lista_screen.dart' show TurnoEstadoBadge;
import 'validar_checkin_service.dart';
import 'validar_checkout_service.dart';

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
    ValidarCheckinService? validarService,
    CronometroService? cronometroService,
    PinCheckoutService? pinCheckoutService,
    ValidarCheckoutService? validarCheckoutService,
    CancelarTurnoService? cancelarService,
  }) : _service = service,
       _pinService = pinService,
       _validarService = validarService,
       _cronometroService = cronometroService,
       _pinCheckoutService = pinCheckoutService,
       _validarCheckoutService = validarCheckoutService,
       _cancelarService = cancelarService;

  final String turnoId;
  final TurnoDetalheService? _service;
  final PinCheckinService? _pinService;
  final ValidarCheckinService? _validarService;
  final CronometroService? _cronometroService;
  final PinCheckoutService? _pinCheckoutService;
  final ValidarCheckoutService? _validarCheckoutService;
  final CancelarTurnoService? _cancelarService;

  @override
  State<TurnoDetalheScreen> createState() => _TurnoDetalheScreenState();
}

enum _Phase { loading, naoEncontrado, erro, pronto }

class _TurnoDetalheScreenState extends State<TurnoDetalheScreen> {
  late final TurnoDetalheService _service =
      widget._service ?? TurnoDetalheService();
  late final PinCheckinService _pinService =
      widget._pinService ?? PinCheckinService();
  late final ValidarCheckinService _validarService =
      widget._validarService ?? ValidarCheckinService();
  late final CronometroService _cronometroService =
      widget._cronometroService ?? CronometroService();
  late final PinCheckoutService _pinCheckoutService =
      widget._pinCheckoutService ?? PinCheckoutService();
  late final ValidarCheckoutService _validarCheckoutService =
      widget._validarCheckoutService ?? ValidarCheckoutService();
  late final CancelarTurnoService _cancelarService =
      widget._cancelarService ?? CancelarTurnoService();

  _Phase _phase = _Phase.loading;
  TurnoDetalhe? _turno;

  /// STORY-062 §4.5 / STORY-064 §4.8 — aviso persistente (PIN expirado por tentativas):
  /// sobrevive ao recarregamento que devolve o turno ao estado de origem (a área de
  /// validação some e o banner é a única pista do que houve). Limpo só por navegação.
  String? _avisoCheckin;

  /// Papel para tema/navegação ANTES do payload chegar (loading/erro/não-encontrado):
  /// sessão local. Depois do fetch, o payload manda (souContratante).
  bool get _ehContratante =>
      _turno?.souContratante ?? (AuthService().session?.role == 'contratante');

  String get _listaDoPapel =>
      _ehContratante ? '/contratante/turnos' : '/profissional/turnos';

  /// STORY-065 (CA-4) — polling SILENCIOSO do Pix: o profissional em `finalizado`
  /// vê "Pix a caminho…" e a linha troca sozinha quando o webhook confirma (sem
  /// refresh manual). Ajuste consciente sobre a 064 §4.11 ("polling morto em
  /// terminal"): vivo APENAS enquanto `pix.status == a_caminho`; morre quando o
  /// Pix confirma. Refresh silencioso — nada de skeleton a cada tick.
  Timer? _pixPoll;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _pixPoll?.cancel();
    super.dispose();
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
    _agendarPixPoll();
  }

  /// Tick do polling do Pix: atualiza `_turno` por baixo da tela montada. Erro de
  /// rede é ignorado — a verdade anterior continua de pé e o próximo tick retenta.
  Future<void> _refreshSilencioso() async {
    final result = await _service.fetch(widget.turnoId);
    if (!mounted) return;
    if (result is TurnoDetalheSuccess) {
      setState(() => _turno = result.turno);
    }
    _agendarPixPoll();
  }

  bool get _pixACaminho =>
      _phase == _Phase.pronto &&
      _turno != null &&
      !_turno!.souContratante &&
      _turno!.estadoRaw == 'finalizado' &&
      _turno!.pix != null &&
      !_turno!.pix!.enviado;

  void _agendarPixPoll() {
    _pixPoll?.cancel();
    _pixPoll = null;
    if (_pixACaminho) {
      _pixPoll = Timer(const Duration(seconds: 10), _refreshSilencioso);
    }
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
          validarService: _validarService,
          cronometroService: _cronometroService,
          pinCheckoutService: _pinCheckoutService,
          validarCheckoutService: _validarCheckoutService,
          cancelarService: _cancelarService,
          avisoCheckin: _avisoCheckin,
          onAvisoCheckin: (msg) => setState(() => _avisoCheckin = msg),
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
    required this.validarService,
    required this.cronometroService,
    required this.pinCheckoutService,
    required this.validarCheckoutService,
    required this.cancelarService,
    required this.avisoCheckin,
    required this.onAvisoCheckin,
    required this.onRecarregar,
  });

  final TurnoDetalhe turno;
  final bool isDark;
  final Color accent;
  final PinCheckinService pinService;
  final ValidarCheckinService validarService;
  final CronometroService cronometroService;
  final PinCheckoutService pinCheckoutService;
  final ValidarCheckoutService validarCheckoutService;
  final CancelarTurnoService cancelarService;
  final String? avisoCheckin;
  final ValueChanged<String> onAvisoCheckin;
  final Future<void> Function() onRecarregar;

  /// STORY-061 — a área de ações vira o bloco do check-in para o PROFISSIONAL em
  /// `confirmado`/`aguardando_checkin` (a janela vem no payload só para ele — CA-1/CA-8).
  bool get _mostraCheckin =>
      !turno.souContratante &&
      turno.checkinJanela != null &&
      (turno.estadoRaw == 'confirmado' ||
          turno.estadoRaw == 'aguardando_checkin');

  /// STORY-062 — o CONTRATANTE em `aguardando_checkin` valida o PIN (SCREEN-062).
  /// Demais papéis/estados não-terminais seguem com o placeholder da 060.
  bool get _mostraValidacao =>
      turno.souContratante && turno.estadoRaw == 'aguardando_checkin';

  /// STORY-064 — o PROFISSIONAL em `ativo`/`aguardando_checkout` gera/cancela o PIN
  /// de check-out (SCREEN-064 §3.1; CA-1 — sem janela horária).
  bool get _mostraCheckout =>
      !turno.souContratante &&
      (turno.estadoRaw == 'ativo' || turno.estadoRaw == 'aguardando_checkout');

  /// STORY-064 — o CONTRATANTE em `aguardando_checkout` valida o check-out (§3.3).
  bool get _mostraValidacaoCheckout =>
      turno.souContratante && turno.estadoRaw == 'aguardando_checkout';

  @override
  Widget build(BuildContext context) {
    final colTurno = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _HeaderCard(turno: turno, isDark: isDark),
        // STORY-063 / SCREEN-063 §3.1 — em `ativo` o tempo é a informação mais quente
        // da tela: o cronômetro entra logo abaixo do header (congelado em
        // `aguardando_checkout` — CA-5; duração final em `finalizado` — 064 CA-6).
        if (turno.estadoRaw == 'ativo' ||
            turno.estadoRaw == 'aguardando_checkout' ||
            turno.estadoRaw == 'finalizado') ...[
          const SizedBox(height: TurniSpacing.md),
          CronometroCard(
            turnoId: turno.id,
            estadoRaw: turno.estadoRaw,
            dataInicio: turno.dataInicio,
            dataFim: turno.dataFim,
            isDark: isDark,
            accent: accent,
            onEstadoMudou: onRecarregar,
            service: cronometroService,
          ),
        ],
        const SizedBox(height: TurniSpacing.md),
        _ValorCard(turno: turno, isDark: isDark),
        const SizedBox(height: TurniSpacing.sm),
        if (turno.aceite != null)
          _AceiteLink(aceite: turno.aceite!, isDark: isDark, accent: accent),
        // STORY-062 §4.5 — banner persistente do PIN expirado (acima da área de ações;
        // sobrevive ao reload que esvazia a área).
        if (avisoCheckin != null) ...[
          const SizedBox(height: TurniSpacing.sm),
          _AvisoBanner(mensagem: avisoCheckin!, isDark: isDark),
        ],
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
          else if (_mostraValidacao) ...[
            // CA-5 — aviso de geofencing ANTES do input; nunca bloqueia (PDR-008).
            if (turno.geofencingCheckin != null &&
                !turno.geofencingCheckin!.ok) ...[
              _GeoAvisoValidacao(
                geofencing: turno.geofencingCheckin!,
                isDark: isDark,
              ),
              const SizedBox(height: TurniSpacing.md),
            ],
            _AcoesValidarCheckin(
              turno: turno,
              isDark: isDark,
              accent: accent,
              validarService: validarService,
              onAvisoCheckin: onAvisoCheckin,
              onRecarregar: onRecarregar,
            ),
          ] else if (_mostraCheckout)
            _AcoesCheckout(
              turno: turno,
              isDark: isDark,
              accent: accent,
              pinService: pinCheckoutService,
              onRecarregar: onRecarregar,
            )
          // STORY-064 §4.7 — SEM aviso de geofencing no check-out (diferença
          // intencional da 062: o registro vai só para a timeline, CA-7).
          else if (_mostraValidacaoCheckout)
            _AcoesValidarCheckout(
              turno: turno,
              isDark: isDark,
              accent: accent,
              validarService: validarCheckoutService,
              onAvisoCheckin: onAvisoCheckin,
              onRecarregar: onRecarregar,
            )
          else
            _AcoesPlaceholder(isDark: isDark),
        ],
        // STORY-066 (CA-1 / SCREEN-066 §A.3) — gatilho de cancelar: baixa ênfase
        // destrutiva, abaixo da área de ações, SÓ em `confirmado` (PDR-007), ambos
        // os papéis. Nunca compete com a ação primária.
        if (turno.estadoRaw == 'confirmado') ...[
          const SizedBox(height: TurniSpacing.sm),
          _CancelarTrigger(
            turno: turno,
            isDark: isDark,
            cancelarService: cancelarService,
            onRecarregar: onRecarregar,
          ),
        ],
        // STORY-087 — em turno avaliável com a direção do usuário PENDENTE, o CTA leva à
        // tela de captura (SCREEN-084 §2). Some quando a pendência se resolve: o reload
        // pós-retorno reflete `avaliacao.pendente == false` (CA-4).
        if (turno.avaliacao?.pendente == true) ...[
          const SizedBox(height: TurniSpacing.sm),
          _AvaliarTurnoCta(
            turnoId: turno.id,
            isDark: isDark,
            accent: accent,
            onRecarregar: onRecarregar,
          ),
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
              // STORY-065 (CA-4 / SCREEN-065 §A) — status do Pix pós-turno: o
              // dinheiro chegou? A resposta mora onde o profissional já olha o valor.
              if (turno.pix != null) ...[
                const SizedBox(height: 14),
                _PixStatusLinha(
                  pix: turno.pix!,
                  isDark: isDark,
                  textMuted: textMuted,
                ),
              ],
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

/// STORY-065 (CA-4 / SCREEN-065 §A.3–A.5) — linha de status do Pix dentro do card de
/// valor do profissional. Dois sub-estados: "a caminho" (entre `finalizado` e o webhook;
/// inclui falha — §A.4) e "enviado" (microcopy fixado pelo CA-4, hora 24h DDR-002;
/// dd/MM quando o dia ≠ corrente). `liveRegion`: o leitor de tela anuncia a chegada do
/// dinheiro quando o polling troca a linha. Ícone ESTÁTICO de propósito: animação
/// contínua nunca aquieta o frame scheduler (mesmo racional do _DotVivo da 063) — o
/// protótipo usava spinner; mudança consciente registrada no spec.
class _PixStatusLinha extends StatelessWidget {
  const _PixStatusLinha({
    required this.pix,
    required this.isDark,
    required this.textMuted,
  });

  final PixDoTurno pix;
  final bool isDark;
  final Color textMuted;

  String get _labelEnviado {
    final em = pix.enviadoEm;
    if (em == null) return 'Pix enviado';
    final l = em.toLocal();
    final agora = DateTime.now();
    final mesmoDia =
        l.year == agora.year && l.month == agora.month && l.day == agora.day;
    final hora = TurniDateTime.formatHora(em);
    return mesmoDia
        ? 'Pix enviado em $hora'
        : 'Pix enviado em ${TurniDateTime.formatDataCurta(em)} · $hora';
  }

  @override
  Widget build(BuildContext context) {
    final divisor = isDark
        ? TurniColors.borderSubtleDark
        : TurniColors.borderSubtleLight;
    // Dark sem token success próprio: accentDark cumpre o papel (precedente da 061).
    final success = isDark ? TurniColors.accentDark : TurniColors.successLight;

    final conteudo = pix.enviado
        ? Row(
            key: const Key('turno-detalhe-pix-enviado'),
            children: [
              ExcludeSemantics(
                child: Icon(Icons.check, size: 15, color: success),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  _labelEnviado,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: success,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          )
        : Row(
            key: const Key('turno-detalhe-pix-acaminho'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(Icons.schedule, size: 15, color: textMuted),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Pix a caminho — normalmente chega em até 15 min.',
                  style: TextStyle(
                    fontSize: 13.5,
                    color: textMuted,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          );

    return Container(
      key: const Key('turno-detalhe-pix-status'),
      padding: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: divisor)),
      ),
      // O flip a_caminho → enviado chega pelo polling silencioso: anuncia ao leitor.
      child: Semantics(liveRegion: true, child: conteudo),
    );
  }
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

/// STORY-087 — CTA "Avaliar turno" no detalhe de um turno finalizado pendente (SCREEN-084
/// §2). Empilha a tela de captura (push) e, ao voltar, recarrega o detalhe — quando a
/// pendência se resolve, este bloco some (CA-4). Acento do perfil; alvo ≥48dp.
class _AvaliarTurnoCta extends StatelessWidget {
  const _AvaliarTurnoCta({
    required this.turnoId,
    required this.isDark,
    required this.accent,
    required this.onRecarregar,
  });

  final String turnoId;
  final bool isDark;
  final Color accent;
  final Future<void> Function() onRecarregar;

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
      key: const Key('turno-detalhe-avaliar'),
      padding: const EdgeInsets.all(TurniSpacing.md),
      decoration: BoxDecoration(
        color: isDark ? TurniColors.surfaceDark : TurniColors.surfaceLight,
        borderRadius: const BorderRadius.all(TurniRadius.md),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Avalie este turno',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: textStrong,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Conte como foi — sua avaliação libera a próxima ação.',
            style: TextStyle(fontSize: 13.5, color: textMuted, height: 1.45),
          ),
          const SizedBox(height: TurniSpacing.md),
          FilledButton(
            key: const Key('turno-detalhe-avaliar-btn'),
            onPressed: () async {
              await context.push('/turnos/$turnoId/avaliar');
              await onRecarregar();
            },
            style: FilledButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: TurniColors.onAccentFor(
                Theme.of(context).brightness,
              ),
              minimumSize: const Size.fromHeight(48),
              shape: const StadiumBorder(),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            child: const Text('Avaliar turno'),
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
                  foregroundColor: TurniColors.onAccentFor(
                    Theme.of(context).brightness,
                  ),
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

// ──────────── Validação do check-in pelo contratante (STORY-062 / SCREEN-062) ────────────

/// Banner warning persistente (§4.5 — "PIN expirado por excesso de tentativas").
class _AvisoBanner extends StatelessWidget {
  const _AvisoBanner({required this.mensagem, required this.isDark});

  final String mensagem;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final ink = isDark
        ? TurniColors.warnDark
        : TurniColors.contratanteAccentInkLight;
    return Semantics(
      liveRegion: true,
      child: Container(
        key: const Key('validar-checkin-banner'),
        padding: const EdgeInsets.symmetric(
          horizontal: TurniSpacing.md,
          vertical: TurniSpacing.sm + 4,
        ),
        decoration: BoxDecoration(
          color: isDark ? TurniColors.warnSoftDark : TurniColors.warnSoftLight,
          borderRadius: const BorderRadius.all(TurniRadius.md),
          border: Border.all(color: ink.withValues(alpha: 0.4)),
        ),
        child: Text(
          mensagem,
          style: TextStyle(fontSize: 14, color: ink, height: 1.45),
        ),
      ),
    );
  }
}

/// Card de aviso de geofencing (CA-5 / §4.2): warning + ícone + texto, ANTES do input.
/// Informa, não bloqueia (PDR-008) — o fluxo de validação é idêntico com ou sem ele.
class _GeoAvisoValidacao extends StatelessWidget {
  const _GeoAvisoValidacao({required this.geofencing, required this.isDark});

  final GeofencingCheckin geofencing;
  final bool isDark;

  String get _texto {
    final sufixo =
        'Confirme com ele antes de validar — você pode validar mesmo assim.';
    if (geofencing.distanciaMetros != null) {
      return 'O profissional está a cerca de '
          '${formatDistanciaMetros(geofencing.distanciaMetros!)} do estabelecimento. '
          '$sufixo';
    }
    return 'Localização do profissional não disponível '
        '(${razaoHumana(geofencing.razao)}). $sufixo';
  }

  @override
  Widget build(BuildContext context) {
    final ink = isDark
        ? TurniColors.warnDark
        : TurniColors.contratanteAccentInkLight;

    return Container(
      key: const Key('validar-checkin-geo-aviso'),
      padding: const EdgeInsets.symmetric(
        horizontal: TurniSpacing.md,
        vertical: TurniSpacing.sm + 4,
      ),
      decoration: BoxDecoration(
        color: isDark ? TurniColors.warnSoftDark : TurniColors.warnSoftLight,
        borderRadius: const BorderRadius.all(TurniRadius.md),
        border: Border.all(color: ink.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: Icon(Icons.warning_amber_rounded, size: 20, color: ink),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _texto,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: ink,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bloco de validação (CA-1/2/3 — §3.1): input de 4 dígitos em mono (espelho de
/// entrada do pin.display da 061), Validar (primário) e Recusar (texto, com dialog).
class _AcoesValidarCheckin extends StatefulWidget {
  const _AcoesValidarCheckin({
    required this.turno,
    required this.isDark,
    required this.accent,
    required this.validarService,
    required this.onAvisoCheckin,
    required this.onRecarregar,
  });

  final TurnoDetalhe turno;
  final bool isDark;
  final Color accent;
  final ValidarCheckinService validarService;
  final ValueChanged<String> onAvisoCheckin;
  final Future<void> Function() onRecarregar;

  @override
  State<_AcoesValidarCheckin> createState() => _AcoesValidarCheckinState();
}

class _AcoesValidarCheckinState extends State<_AcoesValidarCheckin> {
  final _pinController = TextEditingController();
  final _pinFocus = FocusNode();

  bool _validando = false;
  bool _pinInvalido = false;
  String? _bannerMsg;
  bool _bannerComRetry = false;

  @override
  void dispose() {
    _pinController.dispose();
    _pinFocus.dispose();
    super.dispose();
  }

  bool get _pinCompleto => _pinController.text.length == 4;

  Future<void> _validar() async {
    final pin = _pinController.text;
    setState(() {
      _validando = true;
      _pinInvalido = false;
      _bannerMsg = null;
    });

    final result = await widget.validarService.validar(widget.turno.id, pin);
    if (!mounted) return;
    setState(() => _validando = false);

    switch (result) {
      case PinValidado():
        // §4.8 — sucesso celebra com discrição; a verdade vem do reload (badge
        // "Ativo" + timeline "Check-in validado").
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Check-in validado — turno iniciado.',
              key: Key('validar-checkin-sucesso'),
            ),
          ),
        );
        await widget.onRecarregar();
      case PinInvalido():
        // §4.4 — erro no campo; valor mantido SELECIONADO (re-digitar é um toque).
        setState(() => _pinInvalido = true);
        _pinController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _pinController.text.length,
        );
        _pinFocus.requestFocus();
      case PinExpirado():
        // §4.5 — o turno já voltou a `confirmado` no servidor; o banner persistente
        // (acima da área) é a única pista após o reload esvaziar este bloco.
        widget.onAvisoCheckin(
          'PIN expirado por excesso de tentativas. '
          'Peça ao profissional para gerar um novo.',
        );
        await widget.onRecarregar();
      case ValidarRateLimit():
        setState(() {
          _bannerMsg =
              'Muitas tentativas em pouco tempo. '
              'Aguarde um minuto e tente de novo.';
          _bannerComRetry = false;
        });
      case ValidarEstadoInvalido():
        // §4.10 — mudou em outra aba; o servidor é a fonte de verdade.
        await widget.onRecarregar();
      case ValidarErro():
        setState(() {
          _bannerMsg =
              'Não foi possível validar o check-in. Verifique sua conexão.';
          _bannerComRetry = true; // retry reenvia o MESMO PIN digitado (§4.7)
        });
    }
  }

  Future<void> _abrirRecusa() async {
    final recusou = await showDialog<bool>(
      context: context,
      builder: (_) => _RecusaDialog(
        turnoId: widget.turno.id,
        validarService: widget.validarService,
      ),
    );
    if (recusou == true) await widget.onRecarregar();
  }

  @override
  Widget build(BuildContext context) {
    final textStrong = widget.isDark
        ? TurniColors.textStrongDark
        : TurniColors.textStrongLight;
    final textMuted = widget.isDark
        ? TurniColors.textMutedDark
        : TurniColors.textMutedLight;
    final errorInk = widget.isDark
        ? TurniColors.errorDark
        : TurniColors.errorLight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_bannerMsg != null) ...[
          Semantics(
            liveRegion: true,
            child: Container(
              key: const Key('validar-checkin-banner'),
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
                      _bannerMsg!,
                      style: TextStyle(fontSize: 14, color: errorInk),
                    ),
                  ),
                  if (_bannerComRetry)
                    TextButton(
                      key: const Key('validar-checkin-retry-btn'),
                      onPressed: _validando ? null : _validar,
                      child: const Text('Tentar de novo'),
                    ),
                ],
              ),
            ),
          ),
        ],
        Container(
          key: const Key('validar-checkin-area'),
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
                'Profissional chegou?',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: textStrong,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Peça o PIN de 4 dígitos que aparece no celular do '
                'profissional e digite abaixo.',
                style: TextStyle(
                  fontSize: 13.5,
                  color: textMuted,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: TurniSpacing.md),
              // input.pin (SCREEN-062 §8) — espelho de entrada do pin.display da 061.
              Center(
                child: SizedBox(
                  width: 220,
                  child: Semantics(
                    label: 'PIN de check-in, 4 dígitos',
                    child: TextField(
                      key: const Key('validar-checkin-pin-input'),
                      controller: _pinController,
                      focusNode: _pinFocus,
                      enabled: !_validando,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(4),
                      ],
                      textAlign: TextAlign.center,
                      autocorrect: false,
                      enableSuggestions: false,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 10,
                        color: textStrong,
                      ),
                      decoration: InputDecoration(
                        counterText: '',
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: TurniSpacing.sm,
                        ),
                        // §4.4 — erro vinculado ao campo (borda); a mensagem visível
                        // (com liveRegion) fica logo abaixo, centrada como o campo.
                        errorText: _pinInvalido ? '' : null,
                        errorStyle: const TextStyle(fontSize: 0, height: 0.01),
                      ),
                      onChanged: (_) => setState(() => _pinInvalido = false),
                      onSubmitted: (_) {
                        if (_pinCompleto && !_validando) _validar();
                      },
                    ),
                  ),
                ),
              ),
              if (_pinInvalido) ...[
                const SizedBox(height: 6),
                Center(
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      'PIN inválido. Confira com o profissional.',
                      key: const Key('validar-checkin-pin-erro'),
                      style: TextStyle(
                        fontSize: 13.5,
                        color: errorInk,
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: TurniSpacing.md),
              FilledButton(
                key: const Key('validar-checkin-btn'),
                onPressed: _pinCompleto && !_validando ? _validar : null,
                style: FilledButton.styleFrom(
                  backgroundColor: widget.accent,
                  foregroundColor: TurniColors.onAccentFor(
                    Theme.of(context).brightness,
                  ),
                  minimumSize: const Size.fromHeight(48),
                  shape: const StadiumBorder(),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: _validando
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(width: 10),
                          Text('Validando…'),
                        ],
                      )
                    : const Text('Validar check-in'),
              ),
              const SizedBox(height: TurniSpacing.xs),
              TextButton(
                key: const Key('recusar-checkin-btn'),
                onPressed: _validando ? null : _abrirRecusa,
                style: TextButton.styleFrom(
                  foregroundColor: widget.accent,
                  minimumSize: const Size.fromHeight(48),
                ),
                child: const Text(
                  'Profissional não está no local? Recusar check-in',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Dialog de confirmação da recusa (CA-6 / §3.2 — dialog.confirm): a recusa mata o
/// PIN do profissional, por isso confirmação (≠ cancelamento da 061, do próprio dono).
/// Devolve `true` quando a recusa foi efetivada (inclui estado_invalido: a tela
/// recarrega a verdade do mesmo jeito).
class _RecusaDialog extends StatefulWidget {
  const _RecusaDialog({required this.turnoId, required this.validarService});

  final String turnoId;
  final ValidarCheckinService validarService;

  @override
  State<_RecusaDialog> createState() => _RecusaDialogState();
}

class _RecusaDialogState extends State<_RecusaDialog> {
  final _motivoController = TextEditingController();
  bool _enviando = false;
  bool _erro = false;

  @override
  void dispose() {
    _motivoController.dispose();
    super.dispose();
  }

  Future<void> _confirmar() async {
    setState(() {
      _enviando = true;
      _erro = false;
    });

    final motivo = _motivoController.text.trim();
    final result = await widget.validarService.recusar(
      widget.turnoId,
      motivo: motivo.isEmpty ? null : motivo,
    );
    if (!mounted) return;

    switch (result) {
      case RecusaOk() || RecusaEstadoInvalido():
        Navigator.of(context).pop(true);
      case RecusaErro():
        setState(() {
          _enviando = false;
          _erro = true;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textMuted = isDark
        ? TurniColors.textMutedDark
        : TurniColors.textMutedLight;
    final errorColor = isDark ? TurniColors.errorDark : TurniColors.errorLight;

    return AlertDialog(
      key: const Key('recusar-checkin-dialog'),
      title: const Text('Recusar check-in?'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 432),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'O PIN atual deixa de valer e o turno volta para "Confirmado". '
              'O profissional poderá gerar um novo PIN.',
              style: TextStyle(fontSize: 14, color: textMuted, height: 1.5),
            ),
            const SizedBox(height: TurniSpacing.md),
            const Text(
              'Motivo (opcional)',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            TextField(
              key: const Key('recusar-checkin-motivo-input'),
              controller: _motivoController,
              enabled: !_enviando,
              maxLines: 3,
              maxLength: 280,
              decoration: const InputDecoration(
                counterText: '',
                hintText:
                    'Ex.: o profissional ainda não chegou ao '
                    'estabelecimento',
                hintMaxLines: 2,
              ),
            ),
            if (_erro) ...[
              const SizedBox(height: TurniSpacing.sm),
              Semantics(
                liveRegion: true,
                child: Text(
                  'Não foi possível recusar. Tente de novo.',
                  key: const Key('recusar-checkin-erro'),
                  style: TextStyle(fontSize: 13.5, color: errorColor),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const Key('recusar-checkin-voltar-btn'),
          onPressed: _enviando ? null : () => Navigator.of(context).pop(false),
          child: const Text('Voltar'),
        ),
        FilledButton(
          key: const Key('recusar-checkin-confirmar-btn'),
          onPressed: _enviando ? null : _confirmar,
          style: FilledButton.styleFrom(
            backgroundColor: TurniColors.errorLight,
            foregroundColor: Colors.white,
            minimumSize: const Size(0, 48),
            shape: const StadiumBorder(),
          ),
          child: _enviando
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : const Text('Recusar check-in'),
        ),
      ],
    );
  }
}

// ───────────── Cancelamento do turno (STORY-066 / SCREEN-066 §A) ─────────────

/// Gatilho "…? Cancelar turno" — `button.text` destrutivo de baixa ênfase
/// (SCREEN-066 §A.3, padrão "pergunta? ação" das 061/062). Só em `confirmado`
/// (PDR-007); o sucesso recarrega a verdade e mostra snackbar discreto.
class _CancelarTrigger extends StatelessWidget {
  const _CancelarTrigger({
    required this.turno,
    required this.isDark,
    required this.cancelarService,
    required this.onRecarregar,
  });

  final TurnoDetalhe turno;
  final bool isDark;
  final CancelarTurnoService cancelarService;
  final Future<void> Function() onRecarregar;

  Future<void> _abrir(BuildContext context) async {
    final cancelou = await showDialog<bool>(
      context: context,
      builder: (_) => _CancelarDialog(
        turnoId: turno.id,
        souContratante: turno.souContratante,
        cancelarService: cancelarService,
      ),
    );
    if (cancelou == null || !context.mounted) return;

    // true = cancelado com sucesso; false com 422 também recarrega (a verdade
    // mudou debaixo do usuário — SCREEN-066 §A.6). Voltar puro devolve null.
    await onRecarregar();
    if (cancelou && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          key: Key('turno-cancelado-snackbar'),
          content: Text('Turno cancelado.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final errorColor = isDark ? TurniColors.errorDark : TurniColors.errorLight;

    return TextButton(
      key: const Key('turno-detalhe-cancelar-btn'),
      onPressed: () => _abrir(context),
      style: TextButton.styleFrom(
        foregroundColor: errorColor,
        minimumSize: const Size.fromHeight(48),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
      child: Text(
        turno.souContratante
            ? 'Não precisa mais deste turno? Cancelar turno'
            : 'Não vai poder comparecer? Cancelar turno',
        textAlign: TextAlign.center,
      ),
    );
  }
}

/// Dialog de confirmação do cancelamento (CA-1 / SCREEN-066 §A.4 — dialog.confirm,
/// 3º uso). Motivo OPCIONAL ≤280; consequência explícita no corpo; erro inline
/// (o dialog NÃO fecha em erro). Devolve `true` no sucesso; `false` quando o 422
/// foi visto (a tela recarrega ao fechar); `null` em Voltar/ESC/scrim.
class _CancelarDialog extends StatefulWidget {
  const _CancelarDialog({
    required this.turnoId,
    required this.souContratante,
    required this.cancelarService,
  });

  final String turnoId;
  final bool souContratante;
  final CancelarTurnoService cancelarService;

  @override
  State<_CancelarDialog> createState() => _CancelarDialogState();
}

class _CancelarDialogState extends State<_CancelarDialog> {
  final _motivoController = TextEditingController();
  bool _enviando = false;
  String? _erro;

  /// 422 visto: o próximo fechamento devolve `false` (recarregar a verdade).
  bool _estadoInvalido = false;

  @override
  void dispose() {
    _motivoController.dispose();
    super.dispose();
  }

  Future<void> _confirmar() async {
    setState(() {
      _enviando = true;
      _erro = null;
    });

    final motivo = _motivoController.text.trim();
    final result = await widget.cancelarService.cancelar(
      widget.turnoId,
      motivo: motivo.isEmpty ? null : motivo,
    );
    if (!mounted) return;

    switch (result) {
      case CancelamentoOk():
        Navigator.of(context).pop(true);
      case CancelamentoEstadoInvalido():
        setState(() {
          _enviando = false;
          _estadoInvalido = true;
          _erro = 'Este turno não pode mais ser cancelado.';
        });
      case CancelamentoErro():
        setState(() {
          _enviando = false;
          _erro = 'Não foi possível cancelar. Tente de novo.';
        });
    }
  }

  void _voltar() => Navigator.of(context).pop(_estadoInvalido ? false : null);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textMuted = isDark
        ? TurniColors.textMutedDark
        : TurniColors.textMutedLight;
    final errorColor = isDark ? TurniColors.errorDark : TurniColors.errorLight;

    return PopScope(
      // ESC/back do browser também precisa honrar o pós-422 (recarregar).
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_enviando) _voltar();
      },
      child: AlertDialog(
        key: const Key('cancelar-dialog'),
        title: const Text('Cancelar este turno?'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 432),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.souContratante
                    ? 'A reserva do pagamento será liberada e o profissional '
                          'será avisado. Essa ação não pode ser desfeita.'
                    : 'A reserva do pagamento será liberada e o contratante '
                          'será avisado. Essa ação não pode ser desfeita.',
                style: TextStyle(fontSize: 14, color: textMuted, height: 1.5),
              ),
              const SizedBox(height: TurniSpacing.md),
              const Text(
                'Motivo (opcional)',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              TextField(
                key: const Key('cancelar-dialog-motivo'),
                controller: _motivoController,
                enabled: !_enviando && !_estadoInvalido,
                maxLines: 3,
                maxLength: 280,
                decoration: InputDecoration(
                  counterText: '',
                  hintText: widget.souContratante
                      ? 'Ex.: o evento foi cancelado'
                      : 'Ex.: tive um imprevisto e não poderei comparecer',
                  hintMaxLines: 2,
                ),
              ),
              if (_erro != null) ...[
                const SizedBox(height: TurniSpacing.sm),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _erro!,
                    key: const Key('cancelar-dialog-erro'),
                    style: TextStyle(fontSize: 13.5, color: errorColor),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            key: const Key('cancelar-dialog-voltar'),
            onPressed: _enviando ? null : _voltar,
            child: const Text('Voltar'),
          ),
          FilledButton(
            key: const Key('cancelar-dialog-confirmar'),
            onPressed: _enviando || _estadoInvalido ? null : _confirmar,
            style: FilledButton.styleFrom(
              backgroundColor: TurniColors.errorLight,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 48),
              shape: const StadiumBorder(),
            ),
            child: _enviando
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : const Text('Cancelar turno'),
          ),
        ],
      ),
    );
  }
}

// ───────────── Check-out: geração pelo profissional (STORY-064 / SCREEN-064 §3.1) ─────────────

/// Bloco do PIN de check-out na área de ações — espelho da _AcoesCheckin SEM janela
/// horária (CA-1: em `ativo` o botão é sempre habilitado; turno pode estender) e com
/// captura de geolocalização silenciosa (CA-2 — loading diz "Gerando PIN…", não
/// promete localização). Em `aguardando_checkout`: Gerar novo PIN + Cancelar (§4.4/4.6).
class _AcoesCheckout extends StatefulWidget {
  const _AcoesCheckout({
    required this.turno,
    required this.isDark,
    required this.accent,
    required this.pinService,
    required this.onRecarregar,
  });

  final TurnoDetalhe turno;
  final bool isDark;
  final Color accent;
  final PinCheckoutService pinService;
  final Future<void> Function() onRecarregar;

  @override
  State<_AcoesCheckout> createState() => _AcoesCheckoutState();
}

class _AcoesCheckoutState extends State<_AcoesCheckout> {
  bool _gerando = false;
  bool _cancelando = false;
  String? _erroMsg;
  Future<void> Function()? _retry;

  bool get _aguardando => widget.turno.estadoRaw == 'aguardando_checkout';

  Future<void> _gerar() async {
    setState(() {
      _gerando = true;
      _erroMsg = null;
    });

    final result = await widget.pinService.gerar(widget.turno.id);
    if (!mounted) return;
    setState(() => _gerando = false);

    switch (result) {
      case PinGerado(:final pin):
        // §4.3 — tela do PIN sem nota de geofencing (registro vai para a timeline).
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => PinCheckoutScreen(
              turnoId: widget.turno.id,
              pin: pin,
              funcao: widget.turno.funcao,
              estabelecimento: widget.turno.estabelecimento,
              pinService: widget.pinService,
            ),
          ),
        );
        // Voltou da tela do PIN (cancelou ou saiu): o detalhe recarrega a verdade.
        await widget.onRecarregar();
      case PinForaDaJanela() || PinGeracaoEstadoInvalido():
        // Check-out não tem janela; estado_invalido = mudou em outra aba.
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
        // §4.6 — volta a `ativo`: o cronômetro retoma e o display salta (honesto).
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

    final (titulo, apoio) = _aguardando
        ? (
            'Aguardando validação do contratante',
            'Perdeu o PIN de vista? Gere um novo — o anterior deixa de valer.',
          )
        : (
            'Terminou o turno?',
            'Gere o PIN de check-out e mostre ao contratante para confirmar o '
                'fim do turno.',
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_erroMsg != null) ...[
          Container(
            key: const Key('turno-checkout-erro-banner'),
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
                  key: const Key('turno-checkout-retry-btn'),
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
              Text(
                apoio,
                style: TextStyle(
                  fontSize: 13.5,
                  color: textMuted,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: TurniSpacing.md),
              FilledButton(
                key: Key(
                  _aguardando
                      ? 'turno-checkout-regen-btn'
                      : 'turno-checkout-gerar-btn',
                ),
                onPressed: _gerando || _cancelando ? null : _gerar,
                style: FilledButton.styleFrom(
                  backgroundColor: widget.accent,
                  foregroundColor: TurniColors.onAccentFor(
                    Theme.of(context).brightness,
                  ),
                  minimumSize: const Size.fromHeight(48),
                  shape: const StadiumBorder(),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: _gerando
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(width: 10),
                          Text('Gerando PIN…'),
                        ],
                      )
                    : Text(
                        _aguardando
                            ? 'Gerar novo PIN'
                            : 'Gerar PIN de check-out',
                      ),
              ),
              if (_aguardando) ...[
                const SizedBox(height: TurniSpacing.xs),
                TextButton(
                  key: const Key('turno-checkout-cancelar-btn'),
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
                          'Ainda não terminou? Cancelar PIN',
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
}

// ─────────── Check-out: validação pelo contratante (STORY-064 / SCREEN-064 §3.3) ───────────

/// Bloco de validação do check-out — espelho da _AcoesValidarCheckin SEM o card de
/// aviso de geofencing (diferença intencional — estória; o registro fica na timeline).
/// PIN expirado (3 erros) devolve o turno a `ativo` e o cronômetro retoma (CA-4).
class _AcoesValidarCheckout extends StatefulWidget {
  const _AcoesValidarCheckout({
    required this.turno,
    required this.isDark,
    required this.accent,
    required this.validarService,
    required this.onAvisoCheckin,
    required this.onRecarregar,
  });

  final TurnoDetalhe turno;
  final bool isDark;
  final Color accent;
  final ValidarCheckoutService validarService;
  final ValueChanged<String> onAvisoCheckin;
  final Future<void> Function() onRecarregar;

  @override
  State<_AcoesValidarCheckout> createState() => _AcoesValidarCheckoutState();
}

class _AcoesValidarCheckoutState extends State<_AcoesValidarCheckout> {
  final _pinController = TextEditingController();
  final _pinFocus = FocusNode();

  bool _validando = false;
  bool _pinInvalido = false;
  String? _bannerMsg;
  bool _bannerComRetry = false;

  @override
  void dispose() {
    _pinController.dispose();
    _pinFocus.dispose();
    super.dispose();
  }

  bool get _pinCompleto => _pinController.text.length == 4;

  Future<void> _validar() async {
    final pin = _pinController.text;
    setState(() {
      _validando = true;
      _pinInvalido = false;
      _bannerMsg = null;
    });

    final result = await widget.validarService.validar(widget.turno.id, pin);
    if (!mounted) return;
    setState(() => _validando = false);

    switch (result) {
      case PinValidado():
        // §4.11 — sucesso celebra com discrição; a verdade vem do reload (badge
        // "Finalizado" + cronômetro final + timeline "Check-out validado").
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Check-out validado — turno finalizado.',
              key: Key('validar-checkout-sucesso'),
            ),
          ),
        );
        await widget.onRecarregar();
      case PinInvalido():
        // §4.8 — erro no campo; valor mantido SELECIONADO (re-digitar é um toque).
        setState(() => _pinInvalido = true);
        _pinController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _pinController.text.length,
        );
        _pinFocus.requestFocus();
      case PinExpirado():
        // §4.8 — o turno já voltou a `ativo` no servidor (cronômetro retoma); o
        // banner persistente é a única pista após o reload esvaziar este bloco.
        widget.onAvisoCheckin(
          'PIN expirado por excesso de tentativas. '
          'Peça ao profissional para gerar um novo.',
        );
        await widget.onRecarregar();
      case ValidarRateLimit():
        setState(() {
          _bannerMsg =
              'Muitas tentativas em pouco tempo. '
              'Aguarde um minuto e tente de novo.';
          _bannerComRetry = false;
        });
      case ValidarEstadoInvalido():
        // §4.13 — mudou em outra aba; o servidor é a fonte de verdade.
        await widget.onRecarregar();
      case ValidarErro():
        setState(() {
          _bannerMsg =
              'Não foi possível validar o check-out. Verifique sua conexão.';
          _bannerComRetry = true; // retry reenvia o MESMO PIN digitado
        });
    }
  }

  Future<void> _abrirRecusa() async {
    final recusou = await showDialog<bool>(
      context: context,
      builder: (_) => _RecusaCheckoutDialog(
        turnoId: widget.turno.id,
        validarService: widget.validarService,
      ),
    );
    if (recusou == true) await widget.onRecarregar();
  }

  @override
  Widget build(BuildContext context) {
    final textStrong = widget.isDark
        ? TurniColors.textStrongDark
        : TurniColors.textStrongLight;
    final textMuted = widget.isDark
        ? TurniColors.textMutedDark
        : TurniColors.textMutedLight;
    final errorInk = widget.isDark
        ? TurniColors.errorDark
        : TurniColors.errorLight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_bannerMsg != null) ...[
          Semantics(
            liveRegion: true,
            child: Container(
              key: const Key('validar-checkout-banner'),
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
                      _bannerMsg!,
                      style: TextStyle(fontSize: 14, color: errorInk),
                    ),
                  ),
                  if (_bannerComRetry)
                    TextButton(
                      key: const Key('validar-checkout-retry-btn'),
                      onPressed: _validando ? null : _validar,
                      child: const Text('Tentar de novo'),
                    ),
                ],
              ),
            ),
          ),
        ],
        Container(
          key: const Key('validar-checkout-area'),
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
                'Turno concluído?',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: textStrong,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Peça o PIN de 4 dígitos que aparece no celular do '
                'profissional e digite abaixo.',
                style: TextStyle(
                  fontSize: 13.5,
                  color: textMuted,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: TurniSpacing.md),
              // input.pin (mono.display) — mesmo espelho de entrada da 062.
              Center(
                child: SizedBox(
                  width: 220,
                  child: Semantics(
                    label: 'PIN de check-out, 4 dígitos',
                    child: TextField(
                      key: const Key('validar-checkout-pin-input'),
                      controller: _pinController,
                      focusNode: _pinFocus,
                      enabled: !_validando,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(4),
                      ],
                      textAlign: TextAlign.center,
                      autocorrect: false,
                      enableSuggestions: false,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 10,
                        color: textStrong,
                      ),
                      decoration: InputDecoration(
                        counterText: '',
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: TurniSpacing.sm,
                        ),
                        errorText: _pinInvalido ? '' : null,
                        errorStyle: const TextStyle(fontSize: 0, height: 0.01),
                      ),
                      onChanged: (_) => setState(() => _pinInvalido = false),
                      onSubmitted: (_) {
                        if (_pinCompleto && !_validando) _validar();
                      },
                    ),
                  ),
                ),
              ),
              if (_pinInvalido) ...[
                const SizedBox(height: 6),
                Center(
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      'PIN inválido. Confira com o profissional.',
                      key: const Key('validar-checkout-pin-erro'),
                      style: TextStyle(
                        fontSize: 13.5,
                        color: errorInk,
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: TurniSpacing.md),
              FilledButton(
                key: const Key('validar-checkout-btn'),
                onPressed: _pinCompleto && !_validando ? _validar : null,
                style: FilledButton.styleFrom(
                  backgroundColor: widget.accent,
                  foregroundColor: TurniColors.onAccentFor(
                    Theme.of(context).brightness,
                  ),
                  minimumSize: const Size.fromHeight(48),
                  shape: const StadiumBorder(),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: _validando
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(width: 10),
                          Text('Validando…'),
                        ],
                      )
                    : const Text('Validar check-out'),
              ),
              const SizedBox(height: TurniSpacing.xs),
              TextButton(
                key: const Key('recusar-checkout-btn'),
                onPressed: _validando ? null : _abrirRecusa,
                style: TextButton.styleFrom(
                  foregroundColor: widget.accent,
                  minimumSize: const Size.fromHeight(48),
                ),
                child: const Text(
                  'Turno ainda não terminou? Recusar check-out',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Dialog de confirmação da recusa de check-out (CA-5 / §3.4 — dialog.confirm, 2º uso).
/// A recusa devolve o turno a `ativo` — o tempo CONTINUA contando (nunca `em_disputa`,
/// EPIC-005 fora de escopo). Devolve `true` quando efetivada (inclui estado_invalido:
/// a tela recarrega a verdade do mesmo jeito).
class _RecusaCheckoutDialog extends StatefulWidget {
  const _RecusaCheckoutDialog({
    required this.turnoId,
    required this.validarService,
  });

  final String turnoId;
  final ValidarCheckoutService validarService;

  @override
  State<_RecusaCheckoutDialog> createState() => _RecusaCheckoutDialogState();
}

class _RecusaCheckoutDialogState extends State<_RecusaCheckoutDialog> {
  final _motivoController = TextEditingController();
  bool _enviando = false;
  bool _erro = false;

  @override
  void dispose() {
    _motivoController.dispose();
    super.dispose();
  }

  Future<void> _confirmar() async {
    setState(() {
      _enviando = true;
      _erro = false;
    });

    final motivo = _motivoController.text.trim();
    final result = await widget.validarService.recusar(
      widget.turnoId,
      motivo: motivo.isEmpty ? null : motivo,
    );
    if (!mounted) return;

    switch (result) {
      case RecusaOk() || RecusaEstadoInvalido():
        Navigator.of(context).pop(true);
      case RecusaErro():
        setState(() {
          _enviando = false;
          _erro = true;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textMuted = isDark
        ? TurniColors.textMutedDark
        : TurniColors.textMutedLight;
    final errorColor = isDark ? TurniColors.errorDark : TurniColors.errorLight;

    return AlertDialog(
      key: const Key('recusar-checkout-dialog'),
      title: const Text('Recusar check-out?'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 432),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'O PIN atual deixa de valer e o turno volta para "Ativo" — o '
              'tempo continua contando. O profissional poderá gerar um novo '
              'PIN.',
              style: TextStyle(fontSize: 14, color: textMuted, height: 1.5),
            ),
            const SizedBox(height: TurniSpacing.md),
            const Text(
              'Motivo (opcional)',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            TextField(
              key: const Key('recusar-checkout-motivo-input'),
              controller: _motivoController,
              enabled: !_enviando,
              maxLines: 3,
              maxLength: 280,
              decoration: const InputDecoration(
                counterText: '',
                hintText: 'Ex.: o turno ainda não terminou',
                hintMaxLines: 2,
              ),
            ),
            if (_erro) ...[
              const SizedBox(height: TurniSpacing.sm),
              Semantics(
                liveRegion: true,
                child: Text(
                  'Não foi possível recusar. Tente de novo.',
                  key: const Key('recusar-checkout-erro'),
                  style: TextStyle(fontSize: 13.5, color: errorColor),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const Key('recusar-checkout-voltar-btn'),
          onPressed: _enviando ? null : () => Navigator.of(context).pop(false),
          child: const Text('Voltar'),
        ),
        FilledButton(
          key: const Key('recusar-checkout-confirmar-btn'),
          onPressed: _enviando ? null : _confirmar,
          style: FilledButton.styleFrom(
            backgroundColor: TurniColors.errorLight,
            foregroundColor: Colors.white,
            minimumSize: const Size(0, 48),
            shape: const StadiumBorder(),
          ),
          child: _enviando
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : const Text('Recusar check-out'),
        ),
      ],
    );
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
    // STORY-062 (§4.11) — sem o motivo da recusa (trilha do admin).
    TimelineEventoTipo.checkinRecusado => 'Recusado pelo contratante.',
    TimelineEventoTipo.checkinPinExpirado =>
      'Expirado por excesso de tentativas de validação.',
    TimelineEventoTipo.pagamentoPreAutorizado =>
      souContratante
          ? '${formatBRL(evento.valor ?? 0)} reservados no seu meio de pagamento.'
          : 'O contratante garantiu o pagamento deste turno.',
    TimelineEventoTipo.checkinValidado => 'Turno iniciado.',
    // STORY-064 (§4.12) — geofencing do check-out só aparece aqui (CA-7); recusa/
    // cancelamento/expiração devolvem a `ativo` e a trilha explica (motivo é admin-only).
    TimelineEventoTipo.checkoutSolicitado => descricaoTimelineGeofencing(
      evento.geofencing,
    ),
    TimelineEventoTipo.checkoutCancelado =>
      'Cancelado pelo profissional antes da validação.',
    TimelineEventoTipo.checkoutValidado => 'Turno finalizado.',
    TimelineEventoTipo.checkoutRecusado => 'Recusado pelo contratante.',
    TimelineEventoTipo.checkoutPinExpirado =>
      'Expirado por excesso de tentativas de validação.',
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
    // STORY-066 (SCREEN-066 §A.5) — quem cancelou, na voz de quem lê ("Você
    // cancelou…" para o lado que cancelou); o motivo entra como linha própria.
    TimelineEventoTipo.cancelado => switch (evento.lado) {
      'pro' =>
        souContratante
            ? 'Cancelado pelo profissional.'
            : 'Você cancelou este turno.',
      'emp' =>
        souContratante
            ? 'Você cancelou este turno.'
            : 'Cancelado pelo contratante.',
      _ => null,
    },
    TimelineEventoTipo.noShowPro =>
      evento.limiteHoras != null
          ? 'O check-in não aconteceu em até ${evento.limiteHoras} '
                '${evento.limiteHoras == 1 ? 'hora' : 'horas'} após o início '
                'previsto.'
          : 'O check-in não aconteceu até o limite.',
    TimelineEventoTipo.pagamentoLiberado =>
      souContratante && evento.valor != null
          ? '${formatBRL(evento.valor!)} liberados no seu meio de pagamento.'
          : 'O contratante não foi cobrado.',
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
                    // STORY-066 (§A.5) — motivo do cancelamento, visível aos 2
                    // lados (decisão do PO), entre aspas e em itálico.
                    if (evento.tipo == TimelineEventoTipo.cancelado &&
                        evento.motivo != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        '“${evento.motivo}”',
                        style: TextStyle(
                          fontSize: 14,
                          color: textMuted,
                          fontStyle: FontStyle.italic,
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
                foregroundColor: TurniColors.onAccentFor(
                  Theme.of(context).brightness,
                ),
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
