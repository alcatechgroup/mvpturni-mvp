import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/time/turni_datetime.dart';
import '../cadastro/cadastro_service.dart' show Funcao;
import '../cadastro/shared/cadastro_types.dart' show cadastroApiBase;

// Reusa o modelo Funcao do cadastro (GET /api/funcoes — IDR-008). Mesma lista canônica.
export '../cadastro/cadastro_service.dart' show Funcao;

/// Resultado do gate de publicação (PDR-005 / CA-5). `{ pending, turnos }`.
class GatePublicacao {
  final int pending;

  /// STORY-088 (T4): turno pendente mais antigo (turnos[0]), p/ o deep-link "Avaliar agora".
  /// `null` quando não há pendência (ou contrato sem turnos) — o CTA cai no destino Turnos.
  final String? turnoId;

  const GatePublicacao({required this.pending, this.turnoId});

  bool get bloqueado => pending > 0;

  factory GatePublicacao.fromJson(Map<String, dynamic> json) {
    final turnos = json['turnos'] as List<dynamic>? ?? const [];
    final primeiro = turnos.isNotEmpty
        ? (turnos.first as Map).cast<String, dynamic>()
        : null;
    return GatePublicacao(
      pending: (json['pending'] as num?)?.toInt() ?? 0,
      turnoId: primeiro?['turno_id'] as String?,
    );
  }
}

/// Resultado do POST /api/vagas.
sealed class PublicarResult {}

class PublicarSuccess extends PublicarResult {
  final String vagaId;
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
  final String id;
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
    id: json['id'] as String,
    funcao: json['funcao'] as String? ?? '',
    dataInicio: TurniDateTime.parseRequired(json['data_inicio'] as String),
    dataFim: TurniDateTime.parseRequired(json['data_fim'] as String),
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

/// STORY-052 — uma linha do diff de edição material (`{campo,label,tipo,antes,depois}`). É o
/// mesmo shape devolvido pelo servidor (PATCH e detalhe), mas no preview do contratante o diff
/// é montado no cliente (a UI tem antes/depois do próprio form). `tipo` orienta a formatação.
class DiffLinha {
  final String campo;
  final String label;
  final String tipo; // funcao | data | valor | posicoes | texto
  final Object? antes;
  final Object? depois;

  const DiffLinha({
    required this.campo,
    required this.label,
    required this.tipo,
    required this.antes,
    required this.depois,
  });

  factory DiffLinha.fromJson(Map<String, dynamic> json) => DiffLinha(
    campo: json['campo'] as String? ?? '',
    label: json['label'] as String? ?? '',
    tipo: json['tipo'] as String? ?? 'texto',
    antes: json['antes'],
    depois: json['depois'],
  );
}

/// Valores atuais da vaga para o formulário de edição (STORY-052 CA-10).
class VagaEditar {
  final String id;
  final bool editavel;
  final String funcaoId;
  final DateTime dataInicio;
  final DateTime dataFim;
  final double valor;
  final int posicoes;
  final String? observacoes;
  final int candidatosEmRevisao;

  const VagaEditar({
    required this.id,
    required this.editavel,
    required this.funcaoId,
    required this.dataInicio,
    required this.dataFim,
    required this.valor,
    required this.posicoes,
    required this.observacoes,
    required this.candidatosEmRevisao,
  });

  factory VagaEditar.fromJson(Map<String, dynamic> json) => VagaEditar(
    id: json['id'] as String,
    editavel: json['editavel'] as bool? ?? false,
    funcaoId: json['funcao_id'] as String? ?? '',
    dataInicio: TurniDateTime.parseRequired(json['data_inicio'] as String),
    dataFim: TurniDateTime.parseRequired(json['data_fim'] as String),
    valor: (json['valor'] as num?)?.toDouble() ?? 0,
    posicoes: (json['posicoes'] as num?)?.toInt() ?? 1,
    observacoes: json['observacoes'] as String?,
    candidatosEmRevisao: (json['candidatos_em_revisao'] as num?)?.toInt() ?? 0,
  );
}

/// Resultado do GET /api/vagas/{id}/editar.
sealed class CarregarEdicaoResult {}

class CarregarEdicaoSuccess extends CarregarEdicaoResult {
  final VagaEditar vaga;
  CarregarEdicaoSuccess(this.vaga);
}

/// 403 — não-dono / profissional. 404 — vaga inexistente. Rede/5xx — erro recuperável.
class CarregarEdicaoForbidden extends CarregarEdicaoResult {}

class CarregarEdicaoNotFound extends CarregarEdicaoResult {}

class CarregarEdicaoError extends CarregarEdicaoResult {}

/// Resultado do PATCH /api/vagas/{id} (STORY-052 CA-1..CA-5).
sealed class EditarResult {}

class EditarSuccess extends EditarResult {
  final bool material;
  final int candidatosNotificados;
  final List<DiffLinha> diff;
  EditarSuccess({
    required this.material,
    required this.candidatosNotificados,
    required this.diff,
  });
}

/// 422 — erros de validação por campo.
class EditarValidationError extends EditarResult {
  final Map<String, String> errors;
  EditarValidationError(this.errors);
}

/// 409 — vaga não editável (fechou/cancelou entre o load e o submit). SCREEN-052 §4.4.
class EditarConflict extends EditarResult {}

/// 403 — não-dono / profissional.
class EditarForbidden extends EditarResult {}

/// Rede/5xx — erro recuperável; o rascunho é preservado.
class EditarServerError extends EditarResult {}

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
    required String funcaoId,
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
          // Serialização de data é política única do TurniDateTime (sempre UTC — IDR-026).
          'data_inicio': TurniDateTime.toApi(dataInicio),
          'data_fim': TurniDateTime.toApi(dataFim),
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
          data['id'] as String? ?? '',
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
  Future<CancelarResult> cancelar(String vagaId) async {
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

  /// GET /api/vagas/{id}/editar — valores atuais + candidatos a notificar (STORY-052 CA-10).
  Future<CarregarEdicaoResult> fetchEditar(String vagaId) async {
    http.Response res;
    try {
      res = await _client.get(
        Uri.parse('$_base/vagas/$vagaId/editar'),
        headers: {'Accept': 'application/json'},
      );
    } catch (_) {
      return CarregarEdicaoError();
    }

    switch (res.statusCode) {
      case 200:
        try {
          return CarregarEdicaoSuccess(VagaEditar.fromJson(_json(res.body)));
        } catch (_) {
          return CarregarEdicaoError();
        }
      case 403:
        return CarregarEdicaoForbidden();
      case 404:
        return CarregarEdicaoNotFound();
      default:
        return CarregarEdicaoError();
    }
  }

  /// PATCH /api/vagas/{id} — edita a vaga (STORY-052). 200 → diff + nº notificados; 422 →
  /// validação; 409 → não editável; 403 → não-dono; rede/5xx → erro recuperável.
  Future<EditarResult> editar(
    String vagaId, {
    required String funcaoId,
    required DateTime dataInicio,
    required DateTime dataFim,
    required double valor,
    required int posicoes,
    String? observacoes,
  }) async {
    http.Response res;
    try {
      res = await _client.patch(
        Uri.parse('$_base/vagas/$vagaId'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'funcao_id': funcaoId,
          // Mesma serialização UTC do publicar (TurniDateTime) — round-trip idêntico: editar e
          // salvar sem mexer no horário NÃO desloca a vaga nem dispara edição material (IDR-026).
          'data_inicio': TurniDateTime.toApi(dataInicio),
          'data_fim': TurniDateTime.toApi(dataFim),
          'valor': valor,
          'posicoes': posicoes,
          'observacoes': observacoes,
        }),
      );
    } catch (_) {
      return EditarServerError();
    }

    final data = _json(res.body);
    switch (res.statusCode) {
      case 200:
        final diff = (data['diff'] as List? ?? [])
            .map((e) => DiffLinha.fromJson(e as Map<String, dynamic>))
            .toList(growable: false);
        return EditarSuccess(
          material: data['material'] as bool? ?? false,
          candidatosNotificados:
              (data['candidatos_notificados'] as num?)?.toInt() ?? 0,
          diff: diff,
        );
      case 422:
        return EditarValidationError(_flatten(data['errors']));
      case 409:
        return EditarConflict();
      case 403:
        return EditarForbidden();
      default:
        return EditarServerError();
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
