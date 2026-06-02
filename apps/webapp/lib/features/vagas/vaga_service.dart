import 'dart:convert';

import 'package:http/http.dart' as http;

import '../cadastro/cadastro_service.dart' show Funcao;
import '../cadastro/shared/cadastro_types.dart' show cadastroApiBase;

// Reusa o modelo Funcao do cadastro (GET /api/funcoes — IDR-008). Mesma lista canônica.
export '../cadastro/cadastro_service.dart' show Funcao;

/// Resultado do gate de publicação (PDR-005 / CA-5). `{ pending, turnos }`.
class GatePublicacao {
  final int pending;

  const GatePublicacao({required this.pending});

  bool get bloqueado => pending > 0;

  factory GatePublicacao.fromJson(Map<String, dynamic> json) =>
      GatePublicacao(pending: (json['pending'] as num?)?.toInt() ?? 0);
}

/// Resultado do POST /api/vagas.
sealed class PublicarResult {}

class PublicarSuccess extends PublicarResult {
  final int vagaId;
  final String estado;
  PublicarSuccess(this.vagaId, this.estado);
}

/// 422 — erros de validação por campo (chave = campo da API).
class PublicarValidationError extends PublicarResult {
  final Map<String, String> errors;
  PublicarValidationError(this.errors);
}

/// 403 — papel sem permissão (profissional). RBAC herdado de STORY-016 (CA-1).
class PublicarForbidden extends PublicarResult {}

/// Rede/5xx — erro recuperável; o rascunho é preservado e o usuário pode tentar de novo.
class PublicarServerError extends PublicarResult {}

/// Estado da vaga na lista "Minhas vagas" (STORY-047). `desconhecido` é fail-soft para
/// rótulos novos vindos do back sem quebrar o parse (a UI ignora o card desconhecido).
enum VagaEstadoResumo {
  aberta,
  fechada,
  cancelada,
  desconhecido;

  static VagaEstadoResumo fromApi(String? value) => switch (value) {
    'aberta' => VagaEstadoResumo.aberta,
    'fechada' => VagaEstadoResumo.fechada,
    'cancelada' => VagaEstadoResumo.cancelada,
    _ => VagaEstadoResumo.desconhecido,
  };
}

/// Item da lista "Minhas vagas" (STORY-047 CA-2) — o que o card precisa.
class VagaResumo {
  final int id;
  final String funcao;
  final DateTime dataInicio;
  final DateTime dataFim;
  final double valor;
  final int posicoes;
  final int posicoesPreenchidas;
  final VagaEstadoResumo estado;
  final int candidatosPendentes;

  const VagaResumo({
    required this.id,
    required this.funcao,
    required this.dataInicio,
    required this.dataFim,
    required this.valor,
    required this.posicoes,
    required this.posicoesPreenchidas,
    required this.estado,
    required this.candidatosPendentes,
  });

  factory VagaResumo.fromJson(Map<String, dynamic> json) => VagaResumo(
    id: (json['id'] as num).toInt(),
    funcao: json['funcao'] as String? ?? '',
    dataInicio: DateTime.parse(json['data_inicio'] as String),
    dataFim: DateTime.parse(json['data_fim'] as String),
    valor: (json['valor'] as num?)?.toDouble() ?? 0,
    posicoes: (json['posicoes'] as num?)?.toInt() ?? 0,
    posicoesPreenchidas: (json['posicoes_preenchidas'] as num?)?.toInt() ?? 0,
    estado: VagaEstadoResumo.fromApi(json['estado'] as String?),
    candidatosPendentes: (json['candidatos_pendentes'] as num?)?.toInt() ?? 0,
  );
}

/// Resultado do GET /api/vagas/minhas.
sealed class MinhasVagasResult {}

class MinhasVagasSuccess extends MinhasVagasResult {
  final List<VagaResumo> vagas;
  MinhasVagasSuccess(this.vagas);
}

/// 403 — papel sem permissão (profissional). RBAC herdado de STORY-016 (CA-1).
class MinhasVagasForbidden extends MinhasVagasResult {}

/// Rede/5xx — erro recuperável; a tela mostra retry sem liberar lista às cegas.
class MinhasVagasError extends MinhasVagasResult {}

/// Resultado do DELETE /api/vagas/{id}.
sealed class CancelarResult {}

class CancelarSuccess extends CancelarResult {}

/// 409 — transição inválida (vaga não está mais `aberta`, ex.: fechou entre o load e o clique).
class CancelarConflict extends CancelarResult {}

/// 403 — não é o dono / não é contratante.
class CancelarForbidden extends CancelarResult {}

/// Rede/5xx — falha recuperável; o card não muda de estado.
class CancelarServerError extends CancelarResult {}

/// Serviço da publicação de vaga (STORY-046). Sessão Sanctum same-origin: o cookie
/// trafega sozinho (não refazemos /sanctum/csrf-cookie no meio da sessão — IDR-019).
class VagaService {
  VagaService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  String get _base => '$cadastroApiBase/api';

  /// GET /api/funcoes — lista canônica para o dropdown (CA-4).
  Future<List<Funcao>> fetchFuncoes() async {
    http.Response res;
    try {
      res = await _client.get(
        Uri.parse('$_base/funcoes'),
        headers: {'Accept': 'application/json'},
      );
    } catch (_) {
      return [];
    }
    if (res.statusCode != 200) return [];
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final list = (data['data'] as List? ?? []);
    return list
        .map((e) => Funcao.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// GET /api/avaliacoes/pendentes-do-contratante — gate PDR-005 (CA-5).
  /// Retorna null em erro (a tela mostra erro com retry — não libera o form às cegas).
  Future<GatePublicacao?> fetchGate() async {
    http.Response res;
    try {
      res = await _client.get(
        Uri.parse('$_base/avaliacoes/pendentes-do-contratante'),
        headers: {'Accept': 'application/json'},
      );
    } catch (_) {
      return null;
    }
    if (res.statusCode != 200) return null;
    return GatePublicacao.fromJson(
      jsonDecode(res.body) as Map<String, dynamic>,
    );
  }

  /// POST /api/vagas — publica a vaga (CA-6). 6 campos materiais; localização é
  /// derivada do contratante no servidor (ADR-013), por isso não vai no payload.
  Future<PublicarResult> publicar({
    required int funcaoId,
    required DateTime dataInicio,
    required DateTime dataFim,
    required double valor,
    required int posicoes,
    String? observacoes,
  }) async {
    http.Response res;
    try {
      res = await _client.post(
        Uri.parse('$_base/vagas'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'funcao_id': funcaoId,
          'data_inicio': dataInicio.toIso8601String(),
          'data_fim': dataFim.toIso8601String(),
          'valor': valor,
          'posicoes': posicoes,
          'observacoes': observacoes,
        }),
      );
    } catch (_) {
      return PublicarServerError();
    }

    final data = _json(res.body);
    switch (res.statusCode) {
      case 201:
        return PublicarSuccess(
          (data['id'] as num?)?.toInt() ?? 0,
          data['estado'] as String? ?? 'aberta',
        );
      case 422:
        return PublicarValidationError(_flatten(data['errors']));
      case 403:
        return PublicarForbidden();
      default:
        return PublicarServerError();
    }
  }

  /// GET /api/vagas/minhas — vagas do contratante (STORY-047 CA-1/CA-2). 403 → profissional;
  /// rede/5xx → erro (a tela oferece retry, não libera lista vazia às cegas).
  Future<MinhasVagasResult> fetchMinhas() async {
    http.Response res;
    try {
      res = await _client.get(
        Uri.parse('$_base/vagas/minhas'),
        headers: {'Accept': 'application/json'},
      );
    } catch (_) {
      return MinhasVagasError();
    }

    switch (res.statusCode) {
      case 200:
        final data = (_json(res.body)['data'] as List? ?? []);
        final vagas = data
            .map((e) => VagaResumo.fromJson(e as Map<String, dynamic>))
            .toList(growable: false);
        return MinhasVagasSuccess(vagas);
      case 403:
        return MinhasVagasForbidden();
      default:
        return MinhasVagasError();
    }
  }

  /// DELETE /api/vagas/{id} — cancela a vaga (STORY-047 CA-4/CA-5). 200 → ok; 409 →
  /// transição inválida (vaga não está mais aberta); 403 → não-dono; rede/5xx → erro.
  Future<CancelarResult> cancelar(int vagaId) async {
    http.Response res;
    try {
      res = await _client.delete(
        Uri.parse('$_base/vagas/$vagaId'),
        headers: {'Accept': 'application/json'},
      );
    } catch (_) {
      return CancelarServerError();
    }

    switch (res.statusCode) {
      case 200:
        return CancelarSuccess();
      case 409:
        return CancelarConflict();
      case 403:
        return CancelarForbidden();
      default:
        return CancelarServerError();
    }
  }

  Map<String, dynamic> _json(String body) {
    try {
      final decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> ? decoded : {};
    } catch (_) {
      return {};
    }
  }

  Map<String, String> _flatten(Object? errors) {
    final out = <String, String>{};
    if (errors is Map<String, dynamic>) {
      errors.forEach((field, messages) {
        if (messages is List && messages.isNotEmpty) {
          out[field] = messages.first.toString();
        }
      });
    }
    return out;
  }
}
