import 'package:flutter/foundation.dart';

import 'notificacao.dart';
import 'notificacoes_service.dart';

enum NotificacoesFase { idle, carregando, pronto, erro }

/// STORY-053 (CA-8) — estado compartilhado da caixa de notificações (sino + painel). Vive como
/// singleton (`instance`), igual ao AuthService, para o sino e o painel das duas homes observarem
/// a mesma contagem/lista. Marcação de lida é **otimista** (SCREEN-053 §4.7 / Princípio #6).
class NotificacoesController extends ChangeNotifier {
  NotificacoesController({NotificacoesService? service})
    : _service = service ?? NotificacoesService();

  static final NotificacoesController instance = NotificacoesController();

  final NotificacoesService _service;

  int naoLidas = 0;
  List<Notificacao> itens = const [];
  NotificacoesFase fase = NotificacoesFase.idle;

  /// Contagem para o badge do sino — chamada no mount da home (CA-8 §4.1). Silenciosa: falha não
  /// quebra a home (o badge fica com o último valor conhecido).
  Future<void> carregarContagem() async {
    try {
      final r = await _service.fetch(somenteNaoLidas: true);
      naoLidas = r.naoLidas;
      notifyListeners();
    } catch (_) {
      // Mantém o último valor conhecido (sem cache persistente no MVP — push é onda 2).
    }
  }

  /// Carrega a lista ao abrir o painel (CA-7 — últimas 50, lidas + não-lidas).
  Future<void> abrirPainel() async {
    fase = NotificacoesFase.carregando;
    notifyListeners();
    try {
      final r = await _service.fetch();
      itens = r.notificacoes;
      naoLidas = r.naoLidas;
      fase = NotificacoesFase.pronto;
    } catch (_) {
      fase = NotificacoesFase.erro;
    }
    notifyListeners();
  }

  /// Marca uma como lida — otimista: some o ponto/decrementa o badge na hora; o POST reconcilia
  /// no próximo fetch se falhar (a navegação já aconteceu — CA-8 §4.7).
  Future<void> marcarLida(Notificacao n) async {
    if (!n.lida) {
      n.lidaEm = DateTime.now();
      naoLidas = (naoLidas - 1).clamp(0, 1 << 30);
      notifyListeners();
    }
    await _service.marcarLida(n.id);
  }

  /// Marca todas como lidas — otimista; em falha reverte e devolve `false` (a UI mostra SnackBar).
  Future<bool> marcarTodasLidas() async {
    final anteriores = {for (final n in itens) n.id: n.lidaEm};
    final agora = DateTime.now();
    for (final n in itens) {
      n.lidaEm ??= agora;
    }
    final naoLidasAntes = naoLidas;
    naoLidas = 0;
    notifyListeners();

    final ok = await _service.marcarTodasLidas();
    if (!ok) {
      for (final n in itens) {
        n.lidaEm = anteriores[n.id];
      }
      naoLidas = naoLidasAntes;
      notifyListeners();
    }
    return ok;
  }
}
