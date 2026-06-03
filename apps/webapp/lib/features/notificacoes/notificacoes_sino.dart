import 'package:flutter/material.dart';

import '../../ds/tokens.dart';
import 'notificacoes_controller.dart';

/// STORY-053 (CA-8) — sino com badge de contagem nas `actions:` do AppBar das duas homes. O badge
/// usa `error` (convenção de pendência não-vista, SCREEN-053 §"Tema"); abre o `endDrawer` e dispara
/// o carregamento da lista. Observa o controller para refletir a contagem otimista.
class NotificacoesSino extends StatelessWidget {
  const NotificacoesSino({super.key, this.controller});

  final NotificacoesController? controller;

  @override
  Widget build(BuildContext context) {
    final c = controller ?? NotificacoesController.instance;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final error = isDark ? TurniColors.errorDark : TurniColors.errorLight;

    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final n = c.naoLidas;
        const icon = Icon(Icons.notifications_outlined);
        return IconButton(
          key: const Key('notificacoes-sino-btn'),
          tooltip: n > 0 ? 'Notificações, $n não lidas' : 'Notificações',
          icon: n > 0
              ? Badge(
                  key: const Key('notificacoes-badge'),
                  backgroundColor: error,
                  textColor: Colors.white,
                  label: Text(n > 9 ? '9+' : '$n'),
                  child: icon,
                )
              : icon,
          onPressed: () {
            Scaffold.of(context).openEndDrawer();
            c.abrirPainel();
          },
        );
      },
    );
  }
}
