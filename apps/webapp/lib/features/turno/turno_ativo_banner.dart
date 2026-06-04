import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../ds/tokens.dart';
import 'turno_poc_service.dart';

/// STORY-057 / ADR-017 — banner de NAVEGAÇÃO para a PoC do cronômetro. Resolve o problema do PWA
/// instalado (sem barra de URL) + home sem lista de turnos: ao montar, pergunta ao backend se o
/// usuário tem um turno `ativo` (`GET /turnos/meu-ativo`, qualquer lado) e, se sim, mostra um card
/// tocável que leva a `/turno/{id}/cronometro-poc`. Sem turno ativo → não ocupa espaço.
///
/// É a ponte mínima até a tela "Meus turnos" (STORY-059) existir.
class TurnoAtivoBanner extends StatefulWidget {
  const TurnoAtivoBanner({super.key});

  @override
  State<TurnoAtivoBanner> createState() => _TurnoAtivoBannerState();
}

class _TurnoAtivoBannerState extends State<TurnoAtivoBanner> {
  String? _turnoId;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    final id = await TurnoPocService().meuTurnoAtivo();
    if (mounted) setState(() => _turnoId = id);
  }

  @override
  Widget build(BuildContext context) {
    final id = _turnoId;
    if (id == null) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? TurniColors.accentDark : TurniColors.accentLight;
    final onAccent = isDark
        ? TurniColors.onAccentDark
        : TurniColors.onAccentLight;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        TurniSpacing.md,
        TurniSpacing.md,
        TurniSpacing.md,
        0,
      ),
      child: Material(
        color: accent,
        borderRadius: const BorderRadius.all(TurniRadius.md),
        child: InkWell(
          key: const Key('turno-ativo-banner'),
          borderRadius: const BorderRadius.all(TurniRadius.md),
          onTap: () => context.go('/turno/$id/cronometro-poc'),
          child: Padding(
            padding: const EdgeInsets.all(TurniSpacing.md),
            child: Row(
              children: [
                Icon(Icons.timer_outlined, size: 22, color: onAccent),
                const SizedBox(width: TurniSpacing.sm),
                Expanded(
                  child: Text(
                    'Turno em andamento — abrir cronômetro',
                    style: TextStyle(
                      color: onAccent,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right, color: onAccent),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
