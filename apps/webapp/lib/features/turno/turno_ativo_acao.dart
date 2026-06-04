import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'turno_poc_service.dart';

/// STORY-057 / ADR-017 — ação de NAVEGAÇÃO para a PoC do cronômetro, na AppBar do feed
/// (profissional) e do "Minhas vagas" (contratante). Resolve a falta de barra de URL no PWA
/// instalado + home sem lista de turnos.
///
/// Diferente de um banner que busca no mount, o fetch acontece SÓ no toque — não adiciona chamada
/// de rede ao carregamento das telas (que são quentes e cobertas por E2E). Sem turno ativo, mostra
/// um aviso curto. É a ponte mínima até "Meus turnos" (STORY-059).
class TurnoAtivoAcao extends StatefulWidget {
  const TurnoAtivoAcao({super.key});

  @override
  State<TurnoAtivoAcao> createState() => _TurnoAtivoAcaoState();
}

class _TurnoAtivoAcaoState extends State<TurnoAtivoAcao> {
  bool _carregando = false;

  Future<void> _abrir() async {
    if (_carregando) return;
    setState(() => _carregando = true);
    final id = await TurnoPocService().meuTurnoAtivo();
    if (!mounted) return;
    setState(() => _carregando = false);

    if (id != null) {
      context.go('/turno/$id/cronometro-poc');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nenhum turno em andamento agora.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: const Key('turno-ativo-acao'),
      tooltip: 'Turno em andamento',
      icon: _carregando
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.timer_outlined),
      onPressed: _carregando ? null : _abrir,
    );
  }
}
