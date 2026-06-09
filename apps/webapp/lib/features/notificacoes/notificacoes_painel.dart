import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../ds/components/state_views.dart';
import '../../ds/tokens.dart';
import '../auth/auth_service.dart';
import 'notificacao.dart';
import 'notificacoes_controller.dart';

/// STORY-053 (CA-8) — painel lateral (`endDrawer`) com a caixa de notificações. Full-width no
/// mobile, 400dp no desktop/tablet (SCREEN-053 §3). Tema herda o papel logado (DDR-001).
class NotificacoesPainel extends StatelessWidget {
  const NotificacoesPainel({super.key, this.controller});

  final NotificacoesController? controller;

  Color _acento(bool isDark) {
    final role = AuthService().session?.role;
    if (role == 'contratante') {
      return isDark
          ? TurniColors.contratanteAccentDark
          : TurniColors.contratanteAccentInkLight;
    }
    return isDark ? TurniColors.accentDark : TurniColors.accentLight;
  }

  @override
  Widget build(BuildContext context) {
    final c = controller ?? NotificacoesController.instance;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final acento = _acento(isDark);
    final surface = isDark ? TurniColors.surfaceDark : TurniColors.surfaceLight;
    final textStrong = isDark
        ? TurniColors.textStrongDark
        : TurniColors.textStrongLight;
    final largura = MediaQuery.sizeOf(context).width;
    final painelW = largura < 400 ? largura : 400.0;

    return Drawer(
      key: const Key('notificacoes-painel'),
      width: painelW,
      backgroundColor: surface,
      shape: const RoundedRectangleBorder(),
      child: SafeArea(
        child: ListenableBuilder(
          listenable: c,
          builder: (context, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _cabecalho(context, c, acento, textStrong, isDark),
              Expanded(child: _corpo(context, c, acento, isDark)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cabecalho(
    BuildContext context,
    NotificacoesController c,
    Color acento,
    Color textStrong,
    bool isDark,
  ) {
    final divisor = isDark
        ? TurniColors.borderSubtleDark
        : TurniColors.borderSubtleLight;
    return Container(
      padding: const EdgeInsets.fromLTRB(
        TurniSpacing.md,
        TurniSpacing.sm,
        TurniSpacing.sm,
        TurniSpacing.sm,
      ),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: divisor)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Notificações',
              key: const Key('notificacoes-painel-titulo'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: textStrong,
              ),
            ),
          ),
          if (c.naoLidas > 0)
            TextButton(
              key: const Key('notificacoes-marcar-todas-btn'),
              onPressed: () async {
                final ok = await c.marcarTodasLidas();
                if (!ok && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Não foi possível marcar todas como lidas. Tente de novo.',
                      ),
                    ),
                  );
                }
              },
              style: TextButton.styleFrom(foregroundColor: acento),
              child: const Text('Marcar todas como lidas'),
            ),
        ],
      ),
    );
  }

  Widget _corpo(
    BuildContext context,
    NotificacoesController c,
    Color acento,
    bool isDark,
  ) {
    switch (c.fase) {
      case NotificacoesFase.carregando:
      case NotificacoesFase.idle:
        return _skeleton(isDark);
      case NotificacoesFase.erro:
        return _erro(context, c, acento);
      case NotificacoesFase.pronto:
        if (c.itens.isEmpty) return _vazio(isDark);
        return ListView.builder(
          key: const Key('notificacoes-lista'),
          itemCount: c.itens.length,
          itemBuilder: (context, i) =>
              _item(context, c, c.itens[i], acento, isDark),
        );
    }
  }

  Widget _item(
    BuildContext context,
    NotificacoesController c,
    Notificacao n,
    Color acento,
    bool isDark,
  ) {
    final textStrong = isDark
        ? TurniColors.textStrongDark
        : TurniColors.textStrongLight;
    final textMuted = isDark
        ? TurniColors.textMutedDark
        : TurniColors.textMutedLight;
    final sunken = isDark
        ? TurniColors.surfaceDark
        : const Color(0xFFF0EDE3); // surface.sunken (claro)
    final divisor = isDark
        ? TurniColors.borderSubtleDark
        : TurniColors.borderSubtleLight;
    final bg = n.lida ? Colors.transparent : acento.withValues(alpha: 0.12);

    return Semantics(
      button: true,
      label:
          '${n.titulo}. ${n.resumo}. ${n.tempoRelativo()}.${n.lida ? '' : ' Não lida.'}',
      child: InkWell(
        key: Key('notificacao-item-${n.id}'),
        onTap: () {
          c.marcarLida(
            n,
          ); // otimista (SCREEN-053 §4.7) — não bloqueia a navegação
          Scaffold.of(context).closeEndDrawer();
          final rota = n.rotaDestino;
          if (rota != null) context.go(rota);
        },
        child: Container(
          padding: const EdgeInsets.all(TurniSpacing.md),
          decoration: BoxDecoration(
            color: bg,
            border: Border(bottom: BorderSide(color: divisor)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!n.lida)
                Padding(
                  padding: const EdgeInsets.only(top: 6, right: 6),
                  child: Container(
                    key: Key('notificacao-item-${n.id}-naolida'),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: acento,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: sunken,
                  shape: BoxShape.circle,
                ),
                child: Icon(n.tipo.icone, size: 20, color: textMuted),
              ),
              const SizedBox(width: TurniSpacing.sm),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      n.titulo,
                      key: Key('notificacao-item-${n.id}-titulo'),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: n.lida ? FontWeight.w500 : FontWeight.w700,
                        color: textStrong,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      n.resumo,
                      key: Key('notificacao-item-${n.id}-resumo'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14, color: textMuted),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      n.tempoRelativo(),
                      key: Key('notificacao-item-${n.id}-tempo'),
                      style: TextStyle(fontSize: 13, color: textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _skeleton(bool isDark) => const TurniSkeletonList(
    key: Key('notificacoes-skeleton'),
    itemBuilder: _skeletonNotificacao,
  );

  Widget _vazio(bool isDark) => const TurniEmptyState(
    key: Key('notificacoes-vazio'),
    icon: Icons.notifications_none,
    title: 'Nenhuma notificação ainda',
    // SCREEN-STORY-067 §4 — o centro agora cobre o ciclo do turno.
    message:
        'Quando algo acontecer com suas vagas, candidaturas ou turnos, '
        'avisamos aqui.',
  );

  Widget _erro(BuildContext context, NotificacoesController c, Color acento) {
    return TurniRetryState(
      key: const Key('notificacoes-erro'),
      retryKey: const Key('notificacoes-retry-btn'),
      title: 'Não foi possível carregar suas notificações.',
      accent: acento,
      onRetry: c.abrirPainel,
    );
  }
}

// Skeleton de uma linha de notificação (avatar + 3 linhas). STORY-079.
Widget _skeletonNotificacao(BuildContext context) => const Row(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    TurniSkeletonBox(width: 40, circle: true),
    SizedBox(width: TurniSpacing.sm),
    Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TurniSkeletonBox(width: 120),
          SizedBox(height: 8),
          TurniSkeletonBox(width: double.infinity),
          SizedBox(height: 8),
          TurniSkeletonBox(width: 60),
        ],
      ),
    ),
  ],
);
