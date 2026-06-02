import 'package:flutter/material.dart';

import '../install_controller.dart';
import 'install_action_card.dart';
import 'ios_install_instructions_dialog.dart';

/// Ponto de plugagem reutilizável da ação "Instalar app" (STORY-042 / IDR-020 §2).
///
/// Plugado no rodapé de login, pré-cadastros e app shell (acima da
/// `AppVersionLabel`) com Keys `install-action-*`. Fica **sempre** montado e mostra
/// o [InstallActionCard] ou nada via `ListenableBuilder` sobre o
/// [InstallController].
///
/// **Dispensa não persiste (CA-6):** ao montar (entrar de novo na rota) chama
/// `resetDismiss()`, reabrindo a ação se ainda houver instalabilidade. Dispensar na
/// mesma tela mantém escondido até trocar de rota. O modal iOS é aberto
/// imperativamente quando o controller liga `showIosInstructions`.
class InstallActionSlot extends StatefulWidget {
  const InstallActionSlot({super.key, required this.controller});

  final InstallController controller;

  @override
  State<InstallActionSlot> createState() => _InstallActionSlotState();
}

class _InstallActionSlotState extends State<InstallActionSlot> {
  bool _dialogOpen = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    // Entrar na rota reabre a ação dispensada num ciclo anterior (CA-6).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.controller.resetDismiss();
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    if (widget.controller.showIosInstructions && !_dialogOpen) {
      _openIosDialog();
    }
  }

  Future<void> _openIosDialog() async {
    _dialogOpen = true;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => IosInstallInstructionsDialog(
        onClose: () => Navigator.of(dialogContext).pop(),
      ),
    );
    _dialogOpen = false;
    widget.controller.dismissIosInstructions();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        if (!widget.controller.showAction) return const SizedBox.shrink();
        return InstallActionCard(
          isIOS: widget.controller.isIOS,
          onInstall: widget.controller.requestInstall,
          onDismiss: widget.controller.dismiss,
        );
      },
    );
  }
}
