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
import 'vaga_service.dart';

/// STORY-047 / SCREEN-STORY-047 — "Minhas vagas" do contratante: lista as próprias
/// vagas (CA-1/CA-2), filtra por estado client-side (CA-3) e cancela vaga `aberta` com
/// confirmação que informa a contagem real de candidatos (CA-4). É a home do contratante;
/// hospeda o CTA "Publicar vaga". RBAC (CA-1): profissional (403) cai em "sem permissão".
class MinhasVagasScreen extends StatefulWidget {
  const MinhasVagasScreen({
    super.key,
    VagaService? service,
    AuthService? auth,
    this.filtroInicial,
    this.successMessage,
  }) : _service = service,
       _auth = auth;

  final VagaService? _service;
  final AuthService? _auth;

  /// Filtro inicial (deep-link `?filtro=`); senão usa o último da sessão / "ativas".
  final String? filtroInicial;

  /// Toast de confirmação vindo da publicação (STORY-046 CA-7, via `extra` da navegação).
  final String? successMessage;

  @override
  State<MinhasVagasScreen> createState() => _MinhasVagasScreenState();
}

enum _Phase { loading, semPermissao, erro, pronto }

/// Filtro escolhido persiste na sessão (não em DB — CA-3): sobrevive a navegar para
/// publicar e voltar, sem precisar de back-end. Reinicia em "ativas" a cada boot do app.
String _filtroSessao = 'ativas';

/// Reseta o filtro de sessão — só para isolar testes (cada teste começa em "ativas").
@visibleForTesting
void debugResetFiltroSessao() => _filtroSessao = 'ativas';

const _filtros = <String, String>{
  'ativas': 'Ativas',
  'abertas': 'Abertas',
  'fechadas': 'Fechadas',
  'canceladas': 'Canceladas',
  'todas': 'Todas',
};

class _MinhasVagasScreenState extends State<MinhasVagasScreen> {
  late final VagaService _service = widget._service ?? VagaService();
  late final AuthService _auth = widget._auth ?? AuthService();

  _Phase _phase = _Phase.loading;
  List<VagaResumo> _todas = const [];
  late String _filtro;

  @override
  void initState() {
    super.initState();
    final inicial = widget.filtroInicial;
    if (inicial != null && _filtros.containsKey(inicial)) {
      _filtroSessao = inicial;
    }
    _filtro = _filtroSessao;
    _load();
    // STORY-053 (CA-8) — contagem de não-lidas para o badge do sino.
    NotificacoesController.instance.carregarContagem();

    // Toast de "Vaga publicada" carregado da navegação pós-publicação (STORY-046 CA-7).
    final msg = widget.successMessage;
    if (msg != null && msg.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _toast(msg, key: const Key('publicar-vaga-sucesso-toast'));
      });
    }
  }

  Future<void> _logout() async {
    await _auth.logout();
    if (mounted) context.go('/login');
  }

  Future<void> _load() async {
    setState(() => _phase = _Phase.loading);
    final result = await _service.fetchMinhas();
    if (!mounted) return;
    setState(() {
      switch (result) {
        case MinhasVagasSuccess(:final vagas):
          _todas = vagas
              .where((v) => v.estado != VagaEstadoResumo.desconhecido)
              .toList(growable: false);
          _phase = _Phase.pronto;
        case MinhasVagasForbidden():
          _phase = _Phase.semPermissao;
        case MinhasVagasError():
          _phase = _Phase.erro;
      }
    });
  }

  void _setFiltro(String slug) {
    setState(() {
      _filtro = slug;
      _filtroSessao = slug;
    });
  }

  bool _passaFiltro(VagaResumo v) {
    switch (_filtro) {
      case 'abertas':
        return v.estado == VagaEstadoResumo.aberta;
      case 'fechadas':
        return v.estado == VagaEstadoResumo.fechada;
      case 'canceladas':
        return v.estado == VagaEstadoResumo.cancelada;
      case 'todas':
        return true;
      case 'ativas':
      default:
        // Ativas = abertas + fechadas da última semana (CA-3).
        if (v.estado == VagaEstadoResumo.aberta) return true;
        if (v.estado == VagaEstadoResumo.fechada) {
          return v.dataInicio.isAfter(
            DateTime.now().subtract(const Duration(days: 7)),
          );
        }
        return false;
    }
  }

  Color _accent(bool isDark) => isDark
      ? TurniColors.contratanteAccentDark
      : TurniColors.contratanteAccentLight;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = _accent(isDark);
    final surfacePage = isDark
        ? TurniColors.surfacePageDark
        : TurniColors.surfacePageLight;

    return Scaffold(
      key: const Key('minhas-vagas-screen'),
      backgroundColor: surfacePage,
      appBar: AppBar(
        title: const Text('Minhas vagas'),
        actions: [
          // Porta de entrada de "Turnos" do contratante (STORY-059 / SCREEN-059 §2).
          IconButton(
            key: const Key('minhas-vagas-turnos-btn'),
            tooltip: 'Turnos',
            icon: const Icon(Icons.event_note),
            onPressed: () => context.go('/contratante/turnos'),
          ),
          const TurnoAtivoAcao(),
          const NotificacoesSino(),
          IconButton(
            key: const Key('minhas-vagas-logout-btn'),
            tooltip: 'Sair',
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      endDrawer: const NotificacoesPainel(),
      floatingActionButton: _phase == _Phase.pronto && _todas.isNotEmpty
          ? FloatingActionButton.extended(
              key: const Key('minhas-vagas-publicar-btn'),
              backgroundColor: accent,
              foregroundColor: Colors.white,
              onPressed: () => context.go('/contratante/vagas/nova'),
              icon: const Icon(Icons.add),
              label: const Text('Publicar vaga'),
            )
          : null,
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
        if (_todas.isEmpty) return _VazioView(accent: accent);
        return _lista(isDark, accent);
    }
  }

  Widget _skeleton(bool isDark) => ListView(
    key: const Key('minhas-vagas-skeleton'),
    padding: const EdgeInsets.all(TurniSpacing.md),
    children: List.generate(
      3,
      (_) => Padding(
        padding: const EdgeInsets.only(bottom: TurniSpacing.md),
        child: _SkeletonCard(isDark: isDark),
      ),
    ),
  );

  Widget _lista(bool isDark, Color accent) {
    final visiveis = _todas.where(_passaFiltro).toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _filtrosRow(accent),
        Expanded(
          child: visiveis.isEmpty
              ? _VazioFiltroView(filtro: _filtro)
              : LayoutBuilder(
                  builder: (context, constraints) {
                    // Desktop/tablet: 2 colunas quando couber (~440px/card); senão 1.
                    const gap = TurniSpacing.md;
                    final disponivel =
                        constraints.maxWidth - TurniSpacing.md * 2;
                    final duasColunas = constraints.maxWidth >= 940;
                    final cardW = duasColunas
                        ? (disponivel - gap) / 2
                        : disponivel;
                    return SingleChildScrollView(
                      key: const Key('minhas-vagas-lista'),
                      padding: const EdgeInsets.fromLTRB(
                        TurniSpacing.md,
                        0,
                        TurniSpacing.md,
                        96, // espaço para o FAB não cobrir o último card
                      ),
                      child: Wrap(
                        spacing: gap,
                        runSpacing: gap,
                        children: visiveis
                            .map(
                              (v) => SizedBox(
                                width: cardW,
                                child: _VagaCard(
                                  vaga: v,
                                  isDark: isDark,
                                  accent: accent,
                                  onCancelar: () => _confirmarCancelamento(v),
                                  onVerCandidatos: () => context.go(
                                    '/contratante/vagas/${v.id}/candidatos',
                                    // Passa o contexto da vaga (função/horário) para a faixa do
                                    // painel (STORY-051); no deep-link a tela degrada p/ a contagem.
                                    extra: v,
                                  ),
                                  onEditar: () => context.go(
                                    '/contratante/vagas/${v.id}/editar',
                                  ),
                                ),
                              ),
                            )
                            .toList(growable: false),
                      ),
                    );
                  },
                ),
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
      children: _filtros.entries
          .map(
            (e) => Padding(
              padding: const EdgeInsets.only(right: TurniSpacing.sm),
              child: ChoiceChip(
                key: Key('minhas-vagas-filtro-${e.key}'),
                label: Text(e.value),
                selected: _filtro == e.key,
                selectedColor: accent,
                labelStyle: TextStyle(
                  color: _filtro == e.key ? Colors.white : null,
                  fontWeight: _filtro == e.key ? FontWeight.w600 : null,
                ),
                onSelected: (_) => _setFiltro(e.key),
              ),
            ),
          )
          .toList(growable: false),
    ),
  );

  Future<void> _confirmarCancelamento(VagaResumo vaga) async {
    final result = await showDialog<CancelarResult>(
      context: context,
      builder: (_) => _CancelarDialog(
        vaga: vaga,
        onConfirm: () => _service.cancelar(vaga.id),
      ),
    );
    if (!mounted || result == null) return;

    switch (result) {
      case CancelarSuccess():
        setState(() {
          _todas = _todas
              .map((v) => v.id == vaga.id ? _comoCancelada(v) : v)
              .toList(growable: false);
        });
        _toast('Vaga cancelada.', key: const Key('vaga-cancelada-toast'));
      case CancelarConflict():
        _toast('Esta vaga não pode mais ser cancelada. Atualize a lista.');
      case CancelarForbidden():
        _toast('Você não tem permissão para cancelar esta vaga.');
      case CancelarServerError():
        _toast('Não foi possível cancelar agora. Tente de novo.');
    }
  }

  VagaResumo _comoCancelada(VagaResumo v) => VagaResumo(
    id: v.id,
    funcao: v.funcao,
    dataInicio: v.dataInicio,
    dataFim: v.dataFim,
    valor: v.valor,
    posicoes: v.posicoes,
    posicoesPreenchidas: v.posicoesPreenchidas,
    estado: VagaEstadoResumo.cancelada,
    candidatosPendentes: 0,
  );

  void _toast(String msg, {Key? key}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: key,
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

// ───────────────────────── Card de vaga ─────────────────────────

class _VagaCard extends StatelessWidget {
  const _VagaCard({
    required this.vaga,
    required this.isDark,
    required this.accent,
    required this.onCancelar,
    required this.onVerCandidatos,
    required this.onEditar,
  });

  final VagaResumo vaga;
  final bool isDark;
  final Color accent;
  final VoidCallback onCancelar;
  final VoidCallback onVerCandidatos;
  final VoidCallback onEditar;

  // Editar é permitido enquanto a vaga está `aberta` (STORY-052 / PDR-009).
  bool get _podeEditar => vaga.estado == VagaEstadoResumo.aberta;
  bool get _podeCancelar => vaga.estado == VagaEstadoResumo.aberta;
  bool get _podeVerCandidatos =>
      (vaga.estado == VagaEstadoResumo.aberta &&
          vaga.candidatosPendentes > 0) ||
      vaga.estado == VagaEstadoResumo.fechada;

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
    final inkLink = isDark
        ? TurniColors.contratanteAccentDark
        : TurniColors.contratanteAccentInkLight;

    return Container(
      key: Key('vaga-card-${vaga.id}'),
      padding: const EdgeInsets.all(TurniSpacing.md),
      decoration: BoxDecoration(
        color: surface,
        border: Border.all(color: border),
        borderRadius: const BorderRadius.all(TurniRadius.md),
      ),
      child: Column(
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
              _EstadoBadge(estado: vaga.estado, vagaId: vaga.id),
            ],
          ),
          const SizedBox(height: TurniSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${formatBRL(vaga.valor)} · turno',
                style: TextStyle(fontSize: 15, color: textStrong),
              ),
              _PosicoesPill(
                vagaId: vaga.id,
                preenchidas: vaga.posicoesPreenchidas,
                total: vaga.posicoes,
              ),
            ],
          ),
          if (vaga.candidatosPendentes > 0) ...[
            const SizedBox(height: TurniSpacing.sm),
            Text(
              key: Key('vaga-card-${vaga.id}-pendentes'),
              vaga.candidatosPendentes == 1
                  ? '1 candidato aguardando'
                  : '${vaga.candidatosPendentes} candidatos aguardando',
              style: TextStyle(fontSize: 14, color: textMuted),
            ),
          ],
          if (_podeCancelar || _podeVerCandidatos || _podeEditar) ...[
            Divider(color: border, height: TurniSpacing.lg),
            Wrap(
              spacing: TurniSpacing.sm,
              children: [
                if (_podeVerCandidatos)
                  TextButton(
                    key: Key('vaga-card-${vaga.id}-ver-candidatos'),
                    onPressed: onVerCandidatos,
                    style: TextButton.styleFrom(foregroundColor: inkLink),
                    child: const Text('Ver candidatos'),
                  ),
                if (_podeEditar)
                  TextButton(
                    key: Key('minhas-vagas-editar-${vaga.id}'),
                    onPressed: onEditar,
                    style: TextButton.styleFrom(foregroundColor: inkLink),
                    child: const Text('Editar'),
                  ),
                if (_podeCancelar)
                  TextButton(
                    key: Key('vaga-card-${vaga.id}-cancelar-btn'),
                    onPressed: onCancelar,
                    style: TextButton.styleFrom(
                      foregroundColor: isDark
                          ? TurniColors.errorDark
                          : TurniColors.errorLight,
                    ),
                    child: const Text('Cancelar vaga'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _EstadoBadge extends StatelessWidget {
  const _EstadoBadge({required this.estado, required this.vagaId});

  final VagaEstadoResumo estado;
  final String vagaId;

  @override
  Widget build(BuildContext context) {
    final (label, fg, bg, icon) = switch (estado) {
      VagaEstadoResumo.aberta => (
        'Aberta',
        const Color(0xFF1D5235),
        TurniColors.successSoftLight,
        Icons.circle,
      ),
      VagaEstadoResumo.fechada => (
        'Fechada',
        TurniColors.textMutedLight,
        const Color(0xFFECEAE2),
        Icons.check_circle,
      ),
      VagaEstadoResumo.cancelada => (
        'Cancelada',
        const Color(0xFF8A2B2B),
        TurniColors.errorSoftLight,
        Icons.cancel,
      ),
      VagaEstadoResumo.desconhecido => (
        '—',
        TurniColors.textMutedLight,
        const Color(0xFFECEAE2),
        Icons.help,
      ),
    };

    return Container(
      key: Key('vaga-card-$vagaId-estado'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.all(TurniRadius.full),
        border: Border.all(color: fg.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 9, color: fg),
          const SizedBox(width: 5),
          Text(
            label,
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

class _PosicoesPill extends StatelessWidget {
  const _PosicoesPill({
    required this.vagaId,
    required this.preenchidas,
    required this.total,
  });

  final String vagaId;
  final int preenchidas;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$preenchidas de $total posições preenchidas',
      child: Container(
        key: Key('vaga-card-$vagaId-posicoes'),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFF0EEE6),
          borderRadius: const BorderRadius.all(TurniRadius.full),
          border: Border.all(color: TurniColors.borderSubtleLight),
        ),
        child: Text(
          '$preenchidas/$total',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: TurniColors.textStrongLight,
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── Diálogo de cancelamento (button.danger) ─────────────────────────

class _CancelarDialog extends StatefulWidget {
  const _CancelarDialog({required this.vaga, required this.onConfirm});

  final VagaResumo vaga;
  final Future<CancelarResult> Function() onConfirm;

  @override
  State<_CancelarDialog> createState() => _CancelarDialogState();
}

class _CancelarDialogState extends State<_CancelarDialog> {
  bool _loading = false;

  String get _aviso {
    final n = widget.vaga.candidatosPendentes;
    if (n == 0) {
      return 'Nenhum candidato será notificado. Esta ação não pode ser desfeita.';
    }
    if (n == 1) {
      return '1 candidato será notificado do cancelamento. Esta ação não pode ser desfeita.';
    }
    return '$n candidatos serão notificados do cancelamento. Esta ação não pode ser desfeita.';
  }

  Future<void> _confirmar() async {
    setState(() => _loading = true);
    final result = await widget.onConfirm();
    if (!mounted) return;
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final error = Theme.of(context).brightness == Brightness.dark
        ? TurniColors.errorDark
        : TurniColors.errorLight;

    return AlertDialog(
      key: const Key('vaga-cancelar-dialog'),
      title: const Text('Cancelar esta vaga?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${widget.vaga.funcao} · ${TurniDateTime.formatResumo(widget.vaga.dataInicio)}',
            style: TextStyle(color: TurniColors.textMutedLight, fontSize: 14),
          ),
          const SizedBox(height: TurniSpacing.sm),
          Text(_aviso, style: const TextStyle(fontSize: 15)),
        ],
      ),
      actions: [
        TextButton(
          key: const Key('vaga-cancelar-manter-btn'),
          onPressed: _loading ? null : () => Navigator.of(context).pop(),
          child: const Text('Manter vaga'),
        ),
        FilledButton(
          key: const Key('vaga-cancelar-confirmar-btn'),
          onPressed: _loading ? null : _confirmar,
          style: FilledButton.styleFrom(
            backgroundColor: error,
            foregroundColor: Colors.white,
          ),
          child: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Cancelar vaga'),
        ),
      ],
    );
  }
}

// ───────────────────────── Estados auxiliares ─────────────────────────

class _VazioView extends StatelessWidget {
  const _VazioView({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const Key('minhas-vagas-vazio'),
      child: Padding(
        padding: const EdgeInsets.all(TurniSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.work_outline, size: 48),
            const SizedBox(height: TurniSpacing.md),
            Text(
              'Você ainda não publicou vagas',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: TurniSpacing.sm),
            const Text(
              'Publique uma vaga para começar a receber candidaturas de profissionais.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: TurniSpacing.lg),
            FilledButton.icon(
              key: const Key('minhas-vagas-publicar-btn'),
              onPressed: () => context.go('/contratante/vagas/nova'),
              icon: const Icon(Icons.add),
              label: const Text('Publicar vaga'),
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                minimumSize: const Size(220, 48),
                shape: const StadiumBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VazioFiltroView extends StatelessWidget {
  const _VazioFiltroView({required this.filtro});

  final String filtro;

  String get _msg => switch (filtro) {
    'abertas' => 'Nenhuma vaga aberta. Troque o filtro para ver outras.',
    'fechadas' => 'Nenhuma vaga fechada. Troque o filtro para ver outras.',
    'canceladas' => 'Nenhuma vaga cancelada. Troque o filtro para ver outras.',
    _ => 'Nenhuma vaga ativa. Troque o filtro para ver outras.',
  };

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const Key('minhas-vagas-vazio-filtro'),
      child: Padding(
        padding: const EdgeInsets.all(TurniSpacing.xl),
        child: Text(_msg, textAlign: TextAlign.center),
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
        key: const Key('minhas-vagas-erro-banner'),
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
                'Não foi possível carregar suas vagas. Verifique sua conexão.',
                style: TextStyle(color: fg),
              ),
            ),
            TextButton(
              key: const Key('minhas-vagas-retry-btn'),
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
      key: const Key('minhas-vagas-sem-permissao'),
      child: Padding(
        padding: const EdgeInsets.all(TurniSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 48),
            const SizedBox(height: TurniSpacing.md),
            Text(
              'Esta área é do contratante',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: TurniSpacing.sm),
            const Text(
              'Gerir vagas é uma ação de quem contrata. Sua conta é de profissional.',
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

// Formatação monetária promovida a core/format/brl.dart (4º uso — STORY-058).
