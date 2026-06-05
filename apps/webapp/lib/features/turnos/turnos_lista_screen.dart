import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/format/brl.dart';
import '../../core/time/turni_datetime.dart';
import '../../ds/tokens.dart';
import '../notificacoes/notificacoes_controller.dart';
import '../notificacoes/notificacoes_painel.dart';
import '../notificacoes/notificacoes_sino.dart';
import 'turnos_service.dart';

/// Papel dono da lista — define tema, microcopy e a linha "quem" do card (SCREEN-059).
enum TurnosPapel { profissional, contratante }

/// STORY-059 / SCREEN-STORY-059 — listas "Meus turnos" (profissional) e "Turnos"
/// (contratante): os turnos do usuário agrupados por estado na ordem do ciclo de vida
/// (CA-1/CA-2), em duas telas espelhadas com tema por papel (CA-3/CA-4, DDR-001). Overview
/// puro: card sem ação (detalhe é STORY-060). RBAC (CA-5): papel cruzado (403) cai em
/// "sem permissão" fail-secure.
class TurnosListaScreen extends StatefulWidget {
  const TurnosListaScreen({
    super.key,
    required this.papel,
    TurnosService? service,
  }) : _service = service;

  final TurnosPapel papel;
  final TurnosService? _service;

  @override
  State<TurnosListaScreen> createState() => _TurnosListaScreenState();
}

enum _Phase { loading, semPermissao, erro, pronto }

class _TurnosListaScreenState extends State<TurnosListaScreen> {
  late final TurnosService _service = widget._service ?? TurnosService();

  _Phase _phase = _Phase.loading;
  List<GrupoTurnos> _grupos = const [];

  bool get _ehProfissional => widget.papel == TurnosPapel.profissional;

  @override
  void initState() {
    super.initState();
    _load();
    // STORY-053 (CA-8) — contagem de não-lidas para o badge do sino.
    NotificacoesController.instance.carregarContagem();
  }

  Future<void> _load() async {
    setState(() => _phase = _Phase.loading);
    final result = _ehProfissional
        ? await _service.fetchDoProfissional()
        : await _service.fetchDoContratante();
    if (!mounted) return;
    setState(() {
      switch (result) {
        case TurnosSuccess(:final grupos):
          _grupos = grupos;
          _phase = _Phase.pronto;
        case TurnosForbidden():
          _phase = _Phase.semPermissao;
        case TurnosError():
          _phase = _Phase.erro;
      }
    });
  }

  Color _accent(bool isDark) => _ehProfissional
      ? (isDark ? TurniColors.accentDark : TurniColors.accentLight)
      : (isDark
            ? TurniColors.contratanteAccentDark
            : TurniColors.contratanteAccentLight);

  String get _titulo => _ehProfissional ? 'Meus turnos' : 'Turnos';

  String get _home => _ehProfissional ? '/feed' : '/contratante/vagas';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = _accent(isDark);
    final surfacePage = isDark
        ? TurniColors.surfacePageDark
        : TurniColors.surfacePageLight;

    return Scaffold(
      key: Key(
        _ehProfissional ? 'meus-turnos-screen' : 'contratante-turnos-screen',
      ),
      backgroundColor: surfacePage,
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Voltar',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(_home),
        ),
        title: Text(_titulo),
        actions: const [NotificacoesSino()],
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
        return _SemPermissaoView(
          accent: accent,
          ehAreaDoProfissional: _ehProfissional,
        );
      case _Phase.erro:
        return _ErroView(isDark: isDark, onRetry: _load);
      case _Phase.pronto:
        if (_grupos.isEmpty) {
          return _VazioView(
            accent: accent,
            ehProfissional: _ehProfissional,
            home: _home,
          );
        }
        return _lista(isDark);
    }
  }

  Widget _skeleton(bool isDark) => ListView(
    key: const Key('turnos-skeleton'),
    padding: const EdgeInsets.all(TurniSpacing.md),
    children: List.generate(
      3,
      (_) => Padding(
        padding: const EdgeInsets.only(bottom: TurniSpacing.md),
        child: _SkeletonCard(isDark: isDark),
      ),
    ),
  );

  Widget _lista(bool isDark) => LayoutBuilder(
    builder: (context, constraints) {
      // Desktop/tablet: 2 colunas quando couber (~440px/card); senão 1 (SCREEN-059 §3).
      const gap = TurniSpacing.md;
      final disponivel = constraints.maxWidth - TurniSpacing.md * 2;
      final duasColunas = constraints.maxWidth >= 940;
      final cardW = duasColunas ? (disponivel - gap) / 2 : disponivel;

      return SingleChildScrollView(
        key: const Key('turnos-lista'),
        padding: const EdgeInsets.fromLTRB(
          TurniSpacing.md,
          TurniSpacing.xs,
          TurniSpacing.md,
          TurniSpacing.xl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final grupo in _grupos) ...[
              _GrupoHeader(grupo: grupo, isDark: isDark),
              Wrap(
                spacing: gap,
                runSpacing: gap,
                children: grupo.turnos
                    .map(
                      (t) => SizedBox(
                        width: cardW,
                        child: _TurnoCard(
                          turno: t,
                          isDark: isDark,
                          ehProfissional: _ehProfissional,
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
            ],
          ],
        ),
      );
    },
  );
}

// ───────────────────────── Cabeçalho de seção (section.group-header) ─────────────────────────

class _GrupoHeader extends StatelessWidget {
  const _GrupoHeader({required this.grupo, required this.isDark});

  final GrupoTurnos grupo;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final n = grupo.turnos.length;
    return Semantics(
      header: true,
      label: '${grupo.grupo.titulo}, $n ${n == 1 ? 'turno' : 'turnos'}',
      child: Padding(
        padding: const EdgeInsets.only(
          top: TurniSpacing.lg,
          bottom: TurniSpacing.sm,
        ),
        child: Text(
          '${grupo.grupo.titulo} ($n)',
          key: Key('turnos-grupo-${grupo.grupo.slug}'),
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
    );
  }
}

// ───────────────────────── Card de turno (sem ação — STORY-060 fará navegar) ─────────────────

class _TurnoCard extends StatelessWidget {
  const _TurnoCard({
    required this.turno,
    required this.isDark,
    required this.ehProfissional,
  });

  final TurnoResumo turno;
  final bool isDark;
  final bool ehProfissional;

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

    // STORY-060: o card inteiro vira alvo de toque para o detalhe (decisão antecipada na
    // SCREEN-059 §10 — anatomia inalterada, sem chevron; ripple/hover dão a affordance).
    return MergeSemantics(
      child: Material(
        color: surface,
        borderRadius: const BorderRadius.all(TurniRadius.md),
        child: InkWell(
          key: Key('turno-card-${turno.id}'),
          borderRadius: const BorderRadius.all(TurniRadius.md),
          onTap: () => context.go('/turnos/${turno.id}'),
          child: Container(
            padding: const EdgeInsets.all(TurniSpacing.md),
            decoration: BoxDecoration(
              border: Border.all(color: border),
              borderRadius: const BorderRadius.all(TurniRadius.md),
            ),
            child: _conteudo(textStrong, textMuted),
          ),
        ),
      ),
    );
  }

  Widget _conteudo(Color textStrong, Color textMuted) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  turno.funcao,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: textStrong,
                  ),
                ),
                // Linha "quem": estabelecimento (prof.) / profissional (contr.);
                // ausente no payload → omite, nunca quebra (SCREEN-059 §4.6).
                if (turno.quem != null && turno.quem!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    turno.quem!,
                    style: TextStyle(fontSize: 14, color: textMuted),
                  ),
                ],
                const SizedBox(height: 2),
                Text(
                  TurniDateTime.formatIntervalo(
                    turno.dataInicio,
                    turno.dataFim,
                  ),
                  style: TextStyle(fontSize: 14, color: textMuted),
                ),
              ],
            ),
          ),
          TurnoEstadoBadge(
            estado: turno.estado,
            chave: 'turno-card-${turno.id}-estado',
          ),
        ],
      ),
      const SizedBox(height: TurniSpacing.sm),
      Text.rich(
        key: Key('turno-card-${turno.id}-valor'),
        TextSpan(
          text: formatBRL(turno.valor),
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: textStrong,
          ),
          children: [
            // Contratante vê o TOTAL que paga (PDR-004); o sufixo explicita.
            if (!ehProfissional)
              TextSpan(
                text: ' · total',
                style: TextStyle(fontWeight: FontWeight.w400, color: textMuted),
              ),
          ],
        ),
      ),
    ],
  );
}

// ───────────────────────── Selo de estado (badge.status — variantes de Turno) ────────────────

/// Selo de estado de Turno (badge.status do DS) — compartilhado entre a lista (059) e o
/// detalhe (060). `chave` vira a `Key` estável do teste (`turno-card-{id}-estado` na lista;
/// `turno-detalhe-estado` no detalhe).
class TurnoEstadoBadge extends StatelessWidget {
  const TurnoEstadoBadge({
    super.key,
    required this.estado,
    required this.chave,
  });

  final TurnoEstadoResumo estado;
  final String chave;

  @override
  Widget build(BuildContext context) {
    // Cor SEMÂNTICA, não de perfil (SCREEN-059 §4.1): rótulo + ícone + borda, nunca só cor.
    final (fg, bg, icon, filled) = switch (estado) {
      TurnoEstadoResumo.confirmado => (
        const Color(0xFF1D5235),
        TurniColors.successSoftLight,
        Icons.circle,
        false,
      ),
      TurnoEstadoResumo.aguardandoCheckin ||
      TurnoEstadoResumo.aguardandoCheckout => (
        TurniColors.contratanteAccentInkLight,
        TurniColors.warnSoftLight,
        Icons.hourglass_top,
        false,
      ),
      // Vivo agora — selo preenchido (success + branco, AA ✅).
      TurnoEstadoResumo.ativo => (
        Colors.white,
        TurniColors.successLight,
        Icons.play_arrow,
        true,
      ),
      TurnoEstadoResumo.emDisputa => (
        const Color(0xFF8A2B2B),
        TurniColors.errorSoftLight,
        Icons.warning_amber,
        false,
      ),
      TurnoEstadoResumo.finalizado || TurnoEstadoResumo.finalizadoAjustado => (
        TurniColors.textMutedLight,
        const Color(0xFFECEAE2),
        Icons.check_circle,
        false,
      ),
      TurnoEstadoResumo.cancelado ||
      TurnoEstadoResumo.noShow ||
      TurnoEstadoResumo.semPagamento => (
        const Color(0xFF9C5454),
        const Color(0xFFF4E9E9),
        Icons.block,
        false,
      ),
      TurnoEstadoResumo.desconhecido => (
        TurniColors.textMutedLight,
        const Color(0xFFECEAE2),
        Icons.help,
        false,
      ),
    };

    return Container(
      key: Key(chave),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.all(TurniRadius.full),
        border: Border.all(color: filled ? bg : fg.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: fg),
          const SizedBox(width: 5),
          Text(
            estado.label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── Estados auxiliares ─────────────────────────

class _VazioView extends StatelessWidget {
  const _VazioView({
    required this.accent,
    required this.ehProfissional,
    required this.home,
  });

  final Color accent;
  final bool ehProfissional;
  final String home;

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const Key('turnos-vazio'),
      child: Padding(
        padding: const EdgeInsets.all(TurniSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.event_note_outlined, size: 48),
            const SizedBox(height: TurniSpacing.md),
            Text(
              'Ainda não há turnos',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: TurniSpacing.sm),
            Text(
              ehProfissional
                  ? 'Quando o contratante aceitar sua candidatura, o turno aparece aqui.'
                  : 'Quando você aceitar uma candidatura, o turno aparece aqui.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: TurniSpacing.lg),
            FilledButton(
              key: const Key('turnos-vazio-cta'),
              onPressed: () => context.go(home),
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                minimumSize: const Size(220, 48),
                shape: const StadiumBorder(),
              ),
              child: Text(
                ehProfissional ? 'Ver vagas disponíveis' : 'Ver minhas vagas',
              ),
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
        key: const Key('turnos-erro-banner'),
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
                'Não foi possível carregar seus turnos. Verifique sua conexão.',
                style: TextStyle(color: fg),
              ),
            ),
            TextButton(
              key: const Key('turnos-retry-btn'),
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
  const _SemPermissaoView({
    required this.accent,
    required this.ehAreaDoProfissional,
  });

  final Color accent;

  /// True quando a rota invadida é a do profissional (quem invadiu é contratante).
  final bool ehAreaDoProfissional;

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const Key('turnos-sem-permissao'),
      child: Padding(
        padding: const EdgeInsets.all(TurniSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 48),
            const SizedBox(height: TurniSpacing.md),
            Text(
              ehAreaDoProfissional
                  ? 'Esta área é do profissional'
                  : 'Esta área é do contratante',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: TurniSpacing.sm),
            Text(
              ehAreaDoProfissional
                  ? 'Meus turnos mostra os turnos de quem trabalha. Sua conta é de contratante.'
                  : 'Acompanhar os turnos das vagas é uma ação de quem contrata. Sua conta é de profissional.',
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
    Widget line(double w) => Container(
      width: w,
      height: 12,
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: bar,
        borderRadius: BorderRadius.circular(6),
      ),
    );
    return Container(
      padding: const EdgeInsets.all(TurniSpacing.md),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: const BorderRadius.all(TurniRadius.md),
        border: Border.all(color: bar),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [line(140), line(200), line(90)],
      ),
    );
  }
}
