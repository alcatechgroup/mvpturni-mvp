import 'package:flutter/material.dart';

import '../../core/app_update/app_version.dart';
import '../tokens.dart';

/// Rótulo discreto com a versão que está rodando agora no dispositivo
/// (STORY-037 CA-8..CA-11). Formato: "Turni · v0.1.0-rc.24" — ou "Turni · dev"
/// em build local. Usa `body-xs` + `textMuted` (DDR-001), centralizado.
///
/// Reutilizável: mesma estética em login, cadastros e área logada. Quando o menu
/// real da área logada chegar, basta mover a instância para o rodapé do menu.
class AppVersionLabel extends StatelessWidget {
  const AppVersionLabel({super.key, this.version});

  /// Injetável para teste; em produção lê a versão de build.
  final AppVersion? version;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textMuted = isDark
        ? TurniColors.textMutedDark
        : TurniColors.textMutedLight;
    final v = version ?? AppVersion.current();

    return Text(
      'Turni · ${v.value}',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 12, // body-xs (DDR-001 §5.1)
        fontWeight: FontWeight.w400,
        color: textMuted.withValues(alpha: 0.8), // discreto
      ),
    );
  }
}
