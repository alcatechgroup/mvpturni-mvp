import 'dart:convert';

import 'package:http/http.dart' as http;

import '../cadastro/shared/cadastro_types.dart' show cadastroApiBase;
import 'notificacao.dart';

/// Resultado do GET /api/notificacoes (CA-7).
class NotificacoesResult {
  final List<Notificacao> notificacoes;
  final int naoLidas;
  const NotificacoesResult(this.notificacoes, this.naoLidas);
}

/// Serviço da caixa de notificações (STORY-053). Sessão Sanctum same-origin — o cookie trafega
/// sozinho (não refazemos /sanctum/csrf-cookie no meio da sessão — IDR-019).
class NotificacoesService {
  NotificacoesService({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  String get _base => '$cadastroApiBase/api';

  /// GET /api/notificacoes[?lidas=false]. Lança em rede/status inesperado (o controller trata).
  Future<NotificacoesResult> fetch({bool somenteNaoLidas = false}) async {
    final uri = Uri.parse(
      '$_base/notificacoes${somenteNaoLidas ? '?lidas=false' : ''}',
    );
    final res = await _client.get(uri, headers: {'Accept': 'application/json'});
    if (res.statusCode != 200) {
      throw Exception('GET notificacoes falhou: ${res.statusCode}');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final lista = (data['notificacoes'] as List? ?? const [])
        .map((e) => Notificacao.fromJson((e as Map).cast<String, dynamic>()))
        .toList(growable: false);
    final naoLidas = (data['nao_lidas'] as num?)?.toInt() ?? 0;
    return NotificacoesResult(lista, naoLidas);
  }

  /// POST /api/notificacoes/{id}/marcar-lida. `false` em falha (a marcação é otimista — CA-8 §4.7).
  Future<bool> marcarLida(String id) async {
    try {
      final res = await _client.post(
        Uri.parse('$_base/notificacoes/$id/marcar-lida'),
        headers: {'Accept': 'application/json'},
      );
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// POST /api/notificacoes/marcar-todas-lidas. `false` em falha (reverte o otimismo — CA-8 §4.7).
  Future<bool> marcarTodasLidas() async {
    try {
      final res = await _client.post(
        Uri.parse('$_base/notificacoes/marcar-todas-lidas'),
        headers: {'Accept': 'application/json'},
      );
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
