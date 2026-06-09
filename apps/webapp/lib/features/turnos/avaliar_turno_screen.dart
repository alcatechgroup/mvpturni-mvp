import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/time/turni_datetime.dart';
import '../../ds/components/rating_input.dart';
import '../../ds/components/state_views.dart';
import '../../ds/tokens.dart';
import '../auth/auth_service.dart';
import 'avaliar_turno_service.dart';
import 'turno_detalhe_service.dart';

/// STORY-087 / SCREEN-084 (T1+T2) — captura da avaliação recíproca do turno.
///
/// Uma tarefa só: estrelas obrigatórias (1–5) + comentário opcional (≤280) + enviar. A
/// direção (quem avalia quem) deriva do papel do usuário NO SERVIDOR — aqui só adaptamos a
/// copy: profissional→contratante ("Como foi trabalhar aqui?") × contratante→profissional
/// ("Como foi o trabalho de {nome}?"). Contexto do turno reusa `GET /turnos/{id}`
/// (TurnoDetalheService); o `POST /turnos/{id}/avaliar` grava (AvaliarTurnoService).
///
/// Estados (§4): loading do contexto · formulário (pendente) · encerrado (já avaliado/409 ou
/// estado inválido/422 — informativo, não erro cru) · sem permissão (403/404 fail-secure) ·
/// erro de carga (retry) · erro de envio (banner inline recuperável que MANTÉM o preenchido).
class AvaliarTurnoScreen extends StatefulWidget {
  const AvaliarTurnoScreen({
    super.key,
    required this.turnoId,
    TurnoDetalheService? detalheService,
    AvaliarTurnoService? avaliarService,
  }) : _detalheService = detalheService,
       _avaliarService = avaliarService;

  final String turnoId;
  final TurnoDetalheService? _detalheService;
  final AvaliarTurnoService? _avaliarService;

  @override
  State<AvaliarTurnoScreen> createState() => _AvaliarTurnoScreenState();
}

enum _Phase { loading, form, encerrado, semPermissao, erroCarga }

class _AvaliarTurnoScreenState extends State<AvaliarTurnoScreen> {
  late final TurnoDetalheService _detalheService =
      widget._detalheService ?? TurnoDetalheService();
  late final AvaliarTurnoService _avaliarService =
      widget._avaliarService ?? AvaliarTurnoService();

  final _comentario = TextEditingController();

  _Phase _phase = _Phase.loading;
  TurnoDetalhe? _turno;
  int _estrelas = 0;
  bool _enviando = false;

  /// Mensagem/ícone do estado "encerrado" (já avaliado 409 × estado inválido 422).
  String _encerradoMsg = 'Você já avaliou este turno.';
  IconData _encerradoIcon = Icons.check_circle_outline;

  /// Banner de erro de envio (rede) — recuperável, sem derrubar o preenchido.
  String? _erroEnvio;

  bool get _ehContratante =>
      _turno?.souContratante ?? (AuthService().session?.role == 'contratante');

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _comentario.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _phase = _Phase.loading);
    final result = await _detalheService.fetch(widget.turnoId);
    if (!mounted) return;
    setState(() {
      switch (result) {
        case TurnoDetalheSuccess(:final turno):
          _turno = turno;
          // CTA só aparece quando pendente; via deep-link pode chegar não-pendente.
          if (turno.avaliacao?.pendente == true) {
            _phase = _Phase.form;
          } else {
            _phase = _Phase.encerrado;
            _encerradoMsg = 'Você já avaliou este turno.';
            _encerradoIcon = Icons.check_circle_outline;
          }
        case TurnoDetalheNaoEncontrado():
          _phase = _Phase.semPermissao;
        case TurnoDetalheError():
          _phase = _Phase.erroCarga;
      }
    });
  }

  Color _accent(bool isDark) => _ehContratante
      ? (isDark
            ? TurniColors.contratanteAccentDark
            : TurniColors.contratanteAccentLight)
      : (isDark ? TurniColors.accentDark : TurniColors.accentLight);

  Future<void> _enviar() async {
    if (_estrelas < 1 || _enviando) return;
    setState(() {
      _enviando = true;
      _erroEnvio = null;
    });

    final result = await _avaliarService.enviar(
      widget.turnoId,
      estrelas: _estrelas,
      comentario: _comentario.text.trim().isEmpty
          ? null
          : _comentario.text.trim(),
    );
    if (!mounted) return;
    setState(() => _enviando = false);

    switch (result) {
      case AvaliacaoEnviada():
        // §4.1 — sucesso celebra com discrição e volta ao contexto; o detalhe recarrega
        // (CTA some — CA-4). O SnackBar vive no ScaffoldMessenger (sobrevive ao pop).
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Avaliação enviada. Obrigado!',
              key: Key('avaliacao-sucesso'),
            ),
          ),
        );
        _voltar(enviou: true);
      case AvaliacaoJaRegistrada():
        setState(() {
          _phase = _Phase.encerrado;
          _encerradoMsg = 'Você já avaliou este turno.';
          _encerradoIcon = Icons.check_circle_outline;
        });
      case AvaliacaoEstadoInvalido():
        setState(() {
          _phase = _Phase.encerrado;
          _encerradoMsg = 'Este turno não pode mais ser avaliado.';
          _encerradoIcon = Icons.info_outline;
        });
      case AvaliacaoNaoAutorizada():
        setState(() => _phase = _Phase.semPermissao);
      case AvaliacaoErro():
        setState(
          () => _erroEnvio = 'Não foi possível enviar agora. Tente de novo.',
        );
    }
  }

  /// Volta ao contexto de origem. Quando empilhado pelo detalhe (push), `pop` devolve o
  /// controle e o detalhe recarrega; em deep-link sem pilha, cai na lista do papel.
  void _voltar({bool enviou = false}) {
    if (context.canPop()) {
      context.pop(enviou);
    } else {
      context.go(
        _ehContratante ? '/contratante/turnos' : '/profissional/turnos',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      key: const Key('avaliar-turno-screen'),
      backgroundColor: isDark
          ? TurniColors.surfacePageDark
          : TurniColors.surfacePageLight,
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Voltar',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => _voltar(),
        ),
        title: const Text('Avaliar turno'),
      ),
      body: SafeArea(child: _body(isDark)),
    );
  }

  Widget _body(bool isDark) {
    switch (_phase) {
      case _Phase.loading:
        return const Center(
          key: Key('avaliar-loading'),
          child: Padding(
            padding: EdgeInsets.all(TurniSpacing.xl),
            child: TurniSkeletonCard(),
          ),
        );
      case _Phase.erroCarga:
        return TurniRetryState(
          key: const Key('avaliar-carga-erro'),
          title: 'Não foi possível carregar o turno.',
          onRetry: _load,
          retryKey: const Key('avaliar-carga-retry-btn'),
          accent: _accent(isDark),
        );
      case _Phase.semPermissao:
        return TurniEmptyState(
          key: const Key('avaliar-sem-permissao'),
          icon: Icons.lock_outline,
          title: 'Este turno não é seu.',
          message: 'Você só avalia turnos dos quais participou.',
          action: FilledButton(
            key: const Key('avaliar-sem-permissao-btn'),
            onPressed: () => _voltar(),
            style: FilledButton.styleFrom(
              backgroundColor: _accent(isDark),
              foregroundColor: TurniColors.onAccentFor(
                isDark ? Brightness.dark : Brightness.light,
              ),
              minimumSize: const Size(0, 48),
              shape: const StadiumBorder(),
            ),
            child: const Text('Voltar aos meus turnos'),
          ),
        );
      case _Phase.encerrado:
        return TurniEmptyState(
          key: const Key('avaliar-encerrado'),
          icon: _encerradoIcon,
          title: _encerradoMsg,
          message: 'Nada mais a fazer aqui.',
          action: FilledButton(
            key: const Key('avaliar-encerrado-btn'),
            onPressed: () => _voltar(),
            style: FilledButton.styleFrom(
              backgroundColor: _accent(isDark),
              foregroundColor: TurniColors.onAccentFor(
                isDark ? Brightness.dark : Brightness.light,
              ),
              minimumSize: const Size(0, 48),
              shape: const StadiumBorder(),
            ),
            child: const Text('Voltar'),
          ),
        );
      case _Phase.form:
        return _form(isDark);
    }
  }

  Widget _form(bool isDark) {
    final accent = _accent(isDark);

    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 1024;
        final conteudo = _Conteudo(
          turno: _turno!,
          ehContratante: _ehContratante,
          isDark: isDark,
          accent: accent,
          estrelas: _estrelas,
          comentario: _comentario,
          enviando: _enviando,
          erroEnvio: _erroEnvio,
          desktop: desktop,
          onEstrelas: (v) => setState(() => _estrelas = v),
          onEnviar: _enviar,
          onVoltar: () => _voltar(),
        );

        if (desktop) {
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: TurniSpacing.md,
              vertical: TurniSpacing.lg,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: conteudo,
              ),
            ),
          );
        }

        // Mobile: conteúdo rolável + rodapé de CTA fixo (padrão das telas de ação).
        return Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(TurniSpacing.md),
                child: conteudo,
              ),
            ),
            _RodapeCta(
              isDark: isDark,
              accent: accent,
              habilitado: _estrelas >= 1 && !_enviando,
              enviando: _enviando,
              onEnviar: _enviar,
            ),
          ],
        );
      },
    );
  }
}

/// Corpo do formulário (contexto + pergunta + estrelas + comentário + erro). No desktop o
/// par "Voltar / Enviar" entra ao final do card; no mobile o CTA fica no rodapé fixo.
class _Conteudo extends StatelessWidget {
  const _Conteudo({
    required this.turno,
    required this.ehContratante,
    required this.isDark,
    required this.accent,
    required this.estrelas,
    required this.comentario,
    required this.enviando,
    required this.erroEnvio,
    required this.desktop,
    required this.onEstrelas,
    required this.onEnviar,
    required this.onVoltar,
  });

  final TurnoDetalhe turno;
  final bool ehContratante;
  final bool isDark;
  final Color accent;
  final int estrelas;
  final TextEditingController comentario;
  final bool enviando;
  final String? erroEnvio;
  final bool desktop;
  final ValueChanged<int> onEstrelas;
  final VoidCallback onEnviar;
  final VoidCallback onVoltar;

  String get _pergunta => ehContratante
      ? 'Como foi o trabalho de ${_primeiroNome(turno.profissional)}?'
      : 'Como foi trabalhar aqui?';

  String get _quem => ehContratante
      ? _primeiroNome(turno.profissional)
      : (turno.estabelecimento ?? 'Estabelecimento');

  static String _primeiroNome(String? nome) {
    final n = (nome ?? '').trim();
    if (n.isEmpty) return 'profissional';
    return n.split(RegExp(r'\s+')).first;
  }

  @override
  Widget build(BuildContext context) {
    final textStrong = isDark
        ? TurniColors.textStrongDark
        : TurniColors.textStrongLight;
    final textMuted = isDark
        ? TurniColors.textMutedDark
        : TurniColors.textMutedLight;
    final surface = isDark ? TurniColors.surfaceDark : TurniColors.surfaceLight;
    final border = isDark
        ? TurniColors.borderSubtleDark
        : TurniColors.borderSubtleLight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Contexto do turno: quem você avalia + função + janela (24h — DDR-002).
        Container(
          key: const Key('avaliar-contexto'),
          padding: const EdgeInsets.all(TurniSpacing.md),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: const BorderRadius.all(TurniRadius.md),
            border: Border.all(color: border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _quem,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: textStrong,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${turno.funcao} · '
                '${TurniDateTime.formatIntervalo(turno.dataInicio, turno.dataFim)}',
                style: TextStyle(fontSize: 14, color: textMuted),
              ),
            ],
          ),
        ),
        const SizedBox(height: TurniSpacing.lg),
        Semantics(
          header: true,
          child: Text(
            _pergunta,
            key: const Key('avaliar-pergunta'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: textStrong,
            ),
          ),
        ),
        const SizedBox(height: TurniSpacing.md),
        TurniRatingInput(
          value: estrelas,
          accent: accent,
          onChanged: onEstrelas,
        ),
        const SizedBox(height: TurniSpacing.sm),
        Text(
          'Sua avaliação ajuda a manter a confiança entre os dois lados.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12.5, color: textMuted, height: 1.4),
        ),
        const SizedBox(height: TurniSpacing.lg),
        Text(
          'Comentário (opcional)',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: textStrong,
          ),
        ),
        const SizedBox(height: TurniSpacing.xs),
        TextField(
          key: const Key('avaliacao-comentario'),
          controller: comentario,
          enabled: !enviando,
          maxLength: 280,
          maxLines: 3,
          textInputAction: TextInputAction.newline,
          decoration: InputDecoration(
            hintText: 'Conte como foi…',
            filled: true,
            fillColor: surface,
            border: const OutlineInputBorder(
              borderRadius: BorderRadius.all(TurniRadius.md),
            ),
          ),
        ),
        if (erroEnvio != null) ...[
          const SizedBox(height: TurniSpacing.xs),
          _ErroEnvioBanner(
            mensagem: erroEnvio!,
            isDark: isDark,
            enviando: enviando,
            onRetry: onEnviar,
          ),
        ],
        // Desktop: par "Voltar / Enviar" ao final do card (mobile usa o rodapé fixo).
        if (desktop) ...[
          const SizedBox(height: TurniSpacing.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                key: const Key('avaliacao-voltar-btn'),
                onPressed: enviando ? null : onVoltar,
                child: const Text('Voltar'),
              ),
              const SizedBox(width: TurniSpacing.sm),
              _EnviarButton(
                accent: accent,
                isDark: isDark,
                habilitado: estrelas >= 1 && !enviando,
                enviando: enviando,
                onEnviar: onEnviar,
                fullWidth: false,
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Banner inline recuperável (§4.4 — erro de rede): mantém o preenchido, oferece retry.
class _ErroEnvioBanner extends StatelessWidget {
  const _ErroEnvioBanner({
    required this.mensagem,
    required this.isDark,
    required this.enviando,
    required this.onRetry,
  });

  final String mensagem;
  final bool isDark;
  final bool enviando;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final errorInk = isDark ? TurniColors.errorDark : TurniColors.errorLight;
    return Semantics(
      liveRegion: true,
      child: Container(
        key: const Key('avaliacao-envio-erro'),
        padding: const EdgeInsets.symmetric(
          horizontal: TurniSpacing.md,
          vertical: TurniSpacing.sm,
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
                mensagem,
                style: TextStyle(fontSize: 14, color: errorInk),
              ),
            ),
            TextButton(
              key: const Key('avaliacao-envio-retry-btn'),
              onPressed: enviando ? null : onRetry,
              child: const Text('Tentar de novo'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Rodapé fixo do mobile com o CTA primário (padrão das telas de ação 061/064).
class _RodapeCta extends StatelessWidget {
  const _RodapeCta({
    required this.isDark,
    required this.accent,
    required this.habilitado,
    required this.enviando,
    required this.onEnviar,
  });

  final bool isDark;
  final Color accent;
  final bool habilitado;
  final bool enviando;
  final VoidCallback onEnviar;

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? TurniColors.surfaceDark : TurniColors.surfaceLight;
    final border = isDark
        ? TurniColors.borderSubtleDark
        : TurniColors.borderSubtleLight;
    return Container(
      padding: const EdgeInsets.all(TurniSpacing.md),
      decoration: BoxDecoration(
        color: surface,
        border: Border(top: BorderSide(color: border)),
      ),
      child: _EnviarButton(
        accent: accent,
        isDark: isDark,
        habilitado: habilitado,
        enviando: enviando,
        onEnviar: onEnviar,
        fullWidth: true,
      ),
    );
  }
}

class _EnviarButton extends StatelessWidget {
  const _EnviarButton({
    required this.accent,
    required this.isDark,
    required this.habilitado,
    required this.enviando,
    required this.onEnviar,
    required this.fullWidth,
  });

  final Color accent;
  final bool isDark;
  final bool habilitado;
  final bool enviando;
  final VoidCallback onEnviar;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      key: const Key('avaliacao-enviar-btn'),
      onPressed: habilitado ? onEnviar : null,
      style: FilledButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: TurniColors.onAccentFor(
          isDark ? Brightness.dark : Brightness.light,
        ),
        minimumSize: fullWidth ? const Size.fromHeight(48) : const Size(0, 48),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
      child: enviando
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Colors.white,
              ),
            )
          : const Text('Enviar avaliação'),
    );
  }
}
