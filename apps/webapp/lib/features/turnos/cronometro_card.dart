import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/time/turni_datetime.dart';
import '../../ds/tokens.dart';
import '../turno/cronometro_ancora.dart';
import 'cronometro_service.dart';

/// STORY-063 / SCREEN-STORY-063 — card do cronômetro bilateral vivo no detalhe do turno.
///
/// Mecanismo da ADR-017 (decisão a): o servidor é a ÚNICA fonte de verdade do tempo (CA-4).
/// O card busca a âncora (`iniciado_em` + `servidor_agora`), calcula o offset de relógio e
/// tica LOCALMENTE a cada 1s — sem rede por tique. O polling (janela mandada pelo servidor,
/// CA-1) só reconcilia o offset e detecta a saída de `ativo`. Dois lados ancorados no mesmo
/// `iniciado_em` ficam sincronizados ≤ 2s por construção (CA-3).
///
/// Estados (SCREEN-063 §4): sincronizando (`--:--:--`), rodando (tick 1s + dot pulsante),
/// reconectando (CA-6 — falha de polling > 30s mostra a linha de aviso; o display NUNCA
/// congela em `ativo`: a âncora local segue válida), congelado (CA-5 — `aguardando_checkout`
/// exibe a duração e para o polling), FINAL (STORY-064 CA-6 — `finalizado` exibe a duração
/// final `check_out_at − check_in_at`, estado terminal sem polling) e erro da 1ª
/// sincronização (retry).
///
/// Aba em background pausa os timers (`AppLifecycleState` ↔ visibilitychange no Web — ADR-017);
/// ao voltar, a primeira reconciliação corrige o display para a verdade.
class CronometroCard extends StatefulWidget {
  const CronometroCard({
    super.key,
    required this.turnoId,
    required this.estadoRaw,
    required this.dataInicio,
    required this.dataFim,
    required this.isDark,
    required this.accent,
    required this.onEstadoMudou,
    CronometroService? service,
    DateTime Function()? now,
  }) : _service = service,
       _now = now;

  final String turnoId;

  /// Estado do payload do detalhe no momento do build
  /// (`ativo` | `aguardando_checkout` | `finalizado` — STORY-064 CA-6).
  final String estadoRaw;

  /// Início/fim PREVISTOS (CA-2 — microcopy fixa "Início previsto" / "Duração prevista").
  final DateTime dataInicio;
  final DateTime dataFim;

  final bool isDark;
  final Color accent;

  /// Polling detectou estado fora de {ativo, aguardando_checkout} (ex.: `finalizado`, 064+):
  /// a tela recarrega a verdade do servidor (badge/timeline/ações se reorganizam).
  final Future<void> Function() onEstadoMudou;

  final CronometroService? _service;

  /// Relógio injetável (testes da janela de 30s do CA-6 — `pump` avança timers fake,
  /// não o `DateTime.now()` real). Produção usa o relógio do dispositivo.
  final DateTime Function()? _now;

  @override
  State<CronometroCard> createState() => _CronometroCardState();
}

class _CronometroCardState extends State<CronometroCard>
    with WidgetsBindingObserver {
  late final CronometroService _service =
      widget._service ?? CronometroService();
  late final DateTime Function() _agora = widget._now ?? DateTime.now;

  CronometroAncora _ancora = CronometroAncora.vazio;
  late String _estado = widget.estadoRaw;
  bool _sincronizou = false;
  bool _erroInicial = false;
  bool _avisouEstadoMudou = false;

  /// Última reconciliação BEM-SUCEDIDA — base da janela de 30s do "Reconectando…" (CA-6).
  DateTime? _ultimoSyncOk;

  /// Decorrido congelado quando `aguardando_checkout` chega sem `encerrado_em`
  /// (degrade pré-064 — SCREEN-063 §10): melhor último valor conhecido.
  Duration? _decorridoCongelado;

  int _pollSegundos = 5;
  Timer? _tick; // re-render a cada 1s (LOCAL, sem rede)
  Timer? _poll; // reconciliação na janela do servidor

  /// Duração prevista < 1h → MM:SS (CA-2; promove ao cruzar 1h — CronometroAncora.formatar).
  bool get _curto =>
      widget.dataFim.difference(widget.dataInicio) < const Duration(hours: 1);

  bool get _congelado => _estado == 'aguardando_checkout';

  /// STORY-064 (CA-6) — `finalizado` é estado TERMINAL exibível: duração final
  /// (`check_out_at − check_in_at`) congelada, sem polling, sem dot.
  bool get _finalizado => _estado == 'finalizado';

  bool get _reconectando {
    if (!_sincronizou || _congelado || _finalizado) return false;
    final base = _ultimoSyncOk;
    return base != null &&
        _agora().difference(base) > const Duration(seconds: 30);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sincronizar();
    _agendarTimers();
  }

  @override
  void didUpdateWidget(covariant CronometroCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // STORY-064 — a tela recarregou com outro estado SEM remontar o card (o State
    // persiste no mesmo slot da árvore): ex.: validação do check-out leva
    // aguardando_checkout → finalizado. Re-ancora e re-agenda para o novo estado —
    // sem isto o card ficaria preso no estado da montagem.
    if (oldWidget.estadoRaw != widget.estadoRaw) {
      _estado = widget.estadoRaw;
      _avisouEstadoMudou = false;
      _decorridoCongelado = null;
      _sincronizar();
      _agendarTimers();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cancelarTimers();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Background pausa o polling E o tick (nada para renderizar); o retorno re-sincroniza
    // imediatamente — o display salta para a verdade (correto por construção, ADR-017).
    if (state == AppLifecycleState.resumed) {
      _sincronizar();
      _agendarTimers();
    } else if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      _cancelarTimers();
    }
  }

  void _agendarTimers() {
    _cancelarTimers();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    if (!_congelado && !_finalizado) {
      _poll = Timer.periodic(
        Duration(seconds: _pollSegundos),
        (_) => _sincronizar(),
      );
    }
  }

  void _cancelarTimers() {
    _tick?.cancel();
    _poll?.cancel();
    _tick = null;
    _poll = null;
  }

  Future<void> _sincronizar() async {
    final snap = await _service.fetch(widget.turnoId);
    if (!mounted) return;

    if (snap == null) {
      // Falha de reconciliação: o tick local segue (CA-6) — só re-renderiza para o
      // cálculo de _reconectando/_erroInicial aparecer no frame.
      setState(() => _erroInicial = !_sincronizou);
      return;
    }

    setState(() {
      _erroInicial = false;
      _ultimoSyncOk = _agora();
      _ancora = CronometroAncora.sincronizar(
        iniciadoEm: snap.iniciadoEm,
        encerradoEm: snap.encerradoEm,
        servidorAgora: snap.servidorAgora,
        agoraCliente: _agora().toUtc(),
      );
      _estado = snap.estado;
      _sincronizou = true;

      if (snap.pollingSegundos != _pollSegundos) {
        _pollSegundos = snap.pollingSegundos;
        _agendarTimers();
      }

      if (_congelado || _finalizado) {
        // CA-5 (063) / CA-6 (064) — duração congelada: encerrado_em do servidor
        // (idêntica nos 2 lados); degrade sem encerrado_em congela no último decorrido
        // conhecido. O polling para — nada mais muda sozinho nestes estados.
        _decorridoCongelado ??= _ancora.decorrido(_agora().toUtc());
        _poll?.cancel();
        _poll = null;
        // STORY-064 — o polling pegou uma transição que a tela ainda não viu (ex.:
        // contratante em `ativo` quando o profissional gera o PIN de check-out): a tela
        // recarrega a verdade e a área de ações se reorganiza (bloco de validação).
        if (_estado != widget.estadoRaw && !_avisouEstadoMudou) {
          _avisouEstadoMudou = true;
          widget.onEstadoMudou();
        }
      } else if (_estado != 'ativo') {
        // Saiu do ciclo do cronômetro (cancelado/disputa/...): a tela recarrega a verdade.
        _cancelarTimers();
        if (!_avisouEstadoMudou) {
          _avisouEstadoMudou = true;
          widget.onEstadoMudou();
        }
      }
    });
  }

  Duration get _decorrido {
    if (_congelado || _finalizado) {
      if (_ancora.encerradoEm != null && _ancora.iniciadoEm != null) {
        return _ancora.decorrido(_agora().toUtc());
      }
      return _decorridoCongelado ?? Duration.zero;
    }
    return _ancora.decorrido(_agora().toUtc());
  }

  @override
  Widget build(BuildContext context) {
    final textStrong = widget.isDark
        ? TurniColors.textStrongDark
        : TurniColors.textStrongLight;
    final textMuted = widget.isDark
        ? TurniColors.textMutedDark
        : TurniColors.textMutedLight;

    return Container(
      key: const Key('cronometro-card'),
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
      child: _erroInicial
          ? _ErroSincronizacao(isDark: widget.isDark, onRetry: _sincronizar)
          : Column(
              children: [
                _titulo(textMuted),
                _display(textStrong),
                if (_congelado)
                  // STORY-064 CA-6 — microcopy trocada conscientemente sobre a da 063
                  // ("duração final" mentia: recusa/cancelamento retomam o tempo).
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      'Aguardando validação — duração: '
                      '${_sincronizou ? CronometroAncora.formatar(_decorrido) : CronometroAncora.placeholder()}',
                      key: const Key('cronometro-aguardando-checkout'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13.5,
                        color: textMuted,
                        height: 1.5,
                      ),
                    ),
                  )
                else if (_finalizado)
                  // STORY-064 CA-6 — duração final de verdade: check_out_at carimbado.
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      'Turno finalizado — duração: '
                      '${_sincronizou ? CronometroAncora.formatar(_decorrido) : CronometroAncora.placeholder()}',
                      key: const Key('cronometro-finalizado'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13.5,
                        color: textMuted,
                        height: 1.5,
                      ),
                    ),
                  )
                else ...[
                  Text(
                    'Início previsto: ${TurniDateTime.formatHora(widget.dataInicio)}\n'
                    'Duração prevista: '
                    '${TurniDateTime.formatDuracao(widget.dataInicio, widget.dataFim) ?? '—'}',
                    key: const Key('cronometro-previsto'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13.5,
                      color: textMuted,
                      height: 1.6,
                    ),
                  ),
                  if (_reconectando) ...[
                    const SizedBox(height: TurniSpacing.md),
                    _Reconectando(isDark: widget.isDark),
                  ],
                ],
              ],
            ),
    );
  }

  Widget _titulo(Color textMuted) {
    final estilo = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.4,
      color: textMuted,
    );

    if (_congelado) return Text('AGUARDANDO CHECK-OUT', style: estilo);
    if (_finalizado) return Text('TURNO FINALIZADO', style: estilo);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ExcludeSemantics(
          child: _DotVivo(accent: widget.accent, decorrido: _decorrido),
        ),
        const SizedBox(width: 8),
        Text('TURNO EM ANDAMENTO', style: estilo),
      ],
    );
  }

  Widget _display(Color textStrong) {
    final largura = MediaQuery.sizeOf(context).width;
    final decorrido = _decorrido;

    // Leitor de tela: anunciar a cada segundo é tortura — o nó semântico carrega só
    // horas/minutos (muda 1x/min) e NUNCA é liveRegion (SCREEN-063 §6).
    return Semantics(
      label:
          'Tempo decorrido: ${decorrido.inHours} horas, '
          '${decorrido.inMinutes % 60} minutos',
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: TurniSpacing.md),
          child: Text(
            _sincronizou
                ? CronometroAncora.formatar(decorrido, curto: _curto)
                : CronometroAncora.placeholder(curto: _curto),
            key: const Key('cronometro-display'),
            textAlign: TextAlign.center,
            style: GoogleFonts.jetBrainsMono(
              fontSize: largura >= 1024 ? 48 : 40,
              fontWeight: FontWeight.w600,
              color: textStrong,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ),
    );
  }
}

/// Linha "Reconectando…" (CA-6 — só após 30s sem reconciliar; o display segue ticando).
class _Reconectando extends StatelessWidget {
  const _Reconectando({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final ink = isDark
        ? TurniColors.warnDark
        : TurniColors.contratanteAccentInkLight;

    return Semantics(
      liveRegion: true,
      child: Row(
        key: const Key('cronometro-reconectando'),
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(child: Icon(Icons.sync, size: 18, color: ink)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'Reconectando… O tempo continua valendo.',
              style: TextStyle(
                fontSize: 13.5,
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

/// Erro da 1ª sincronização (§4.5) — a âncora nunca chegou; o resto do detalhe segue vivo.
class _ErroSincronizacao extends StatelessWidget {
  const _ErroSincronizacao({required this.isDark, required this.onRetry});

  final bool isDark;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final fg = isDark ? TurniColors.errorDark : TurniColors.errorLight;

    return Semantics(
      liveRegion: true,
      child: Container(
        key: const Key('cronometro-erro'),
        padding: const EdgeInsets.symmetric(
          horizontal: TurniSpacing.sm,
          vertical: TurniSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: isDark
              ? TurniColors.errorSoftDark
              : TurniColors.errorSoftLight,
          borderRadius: const BorderRadius.all(TurniRadius.md),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Não foi possível carregar o cronômetro. Verifique sua conexão.',
                style: TextStyle(fontSize: 14, color: fg, height: 1.4),
              ),
            ),
            TextButton(
              key: const Key('cronometro-retry-btn'),
              onPressed: onRetry,
              child: const Text('Tentar de novo'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dot de "vivo" no acento do papel — pulso sutil dirigido pelo TICK do cronômetro
/// (alterna a cada segundo → ciclo ~2s), desligado quando o sistema pede menos movimento
/// (o tick dos segundos já comunica vida — SCREEN-063 §4.2). Sem animação contínua de
/// propósito: uma animação `repeat` nunca aquieta o frame scheduler e travaria os
/// `pumpAndSettle` dos testes na tela do turno ativo.
class _DotVivo extends StatelessWidget {
  const _DotVivo({required this.accent, required this.decorrido});

  final Color accent;
  final Duration decorrido;

  @override
  Widget build(BuildContext context) {
    final dot = Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
    );

    if (MediaQuery.disableAnimationsOf(context)) return dot;

    return AnimatedOpacity(
      opacity: decorrido.inSeconds.isEven ? 1.0 : 0.45,
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeInOut,
      child: dot,
    );
  }
}
