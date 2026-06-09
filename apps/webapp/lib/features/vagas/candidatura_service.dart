import 'dart:convert';

import 'package:http/http.dart' as http;

import '../cadastro/shared/cadastro_types.dart' show cadastroApiBase;

/// STORY-050 — vaga em conflito de horário (detalhe.conflito_com de um bloqueio
/// `conflito_horario`). Função/estabelecimento podem vir nulos (fail-soft): o card cai para só
/// "Ver vaga em conflito" e o link ainda funciona via [vagaId] (SCREEN-050 §4.5 / §10).
class ConflitoInfo {
  final String vagaId;
  final String? funcao;
  final String? estabelecimento;
  final DateTime? dataInicio;
  final DateTime? dataFim;

  const ConflitoInfo({
    required this.vagaId,
    required this.funcao,
    required this.estabelecimento,
    required this.dataInicio,
    required this.dataFim,
  });

  static ConflitoInfo? fromDetalhe(Map<String, dynamic>? detalhe) {
    final c = (detalhe?['conflito_com'] as Map?)?.cast<String, dynamic>();
    if (c == null) return null;
    final vagaId = c['vaga_id'] as String?;
    if (vagaId == null) return null;
    return ConflitoInfo(
      vagaId: vagaId,
      funcao: c['funcao'] as String?,
      estabelecimento: c['estabelecimento'] as String?,
      dataInicio: c['data_inicio'] != null
          ? DateTime.tryParse(c['data_inicio'] as String)
          : null,
      dataFim: c['data_fim'] != null
          ? DateTime.tryParse(c['data_fim'] as String)
          : null,
    );
  }
}

/// Resultado do POST /api/vagas/{id}/candidaturas (CA-1/CA-9).
sealed class CandidaturaResult {}

/// 201 — candidatura criada (`pendente`). `alerta` = MEI/PJ na 3ª alocação (não bloqueia).
class CandidaturaCriada extends CandidaturaResult {
  final String id;
  final String estado;
  final DateTime? candidatouEm;
  final bool alerta;
  CandidaturaCriada({
    required this.id,
    required this.estado,
    required this.candidatouEm,
    required this.alerta,
  });
}

/// 409 — já candidatado (corrida/idempotência — CA-6). A UI trata como sucesso silencioso.
class CandidaturaJaExiste extends CandidaturaResult {}

/// 422 — bloqueado por um gate (CA-2/CA-3/CA-4/CA-5). `erro` mapeia o título do modal; `mensagem`
/// é a prosa pronta do back (exibida verbatim). `conflito` ≠ null só em `conflito_horario`.
class CandidaturaBloqueada extends CandidaturaResult {
  final String erro;
  final String mensagem;
  final ConflitoInfo? conflito;

  /// STORY-088 (CA-4) — turno pendente mais antigo (gate de avaliação), p/ o deep-link
  /// "Avaliar agora". Só vem em `gate_avaliacao`; `null` no caminho fail-secure (sem deep-link).
  final String? turnoId;
  CandidaturaBloqueada({
    required this.erro,
    required this.mensagem,
    required this.conflito,
    this.turnoId,
  });
}

/// 403 — papel sem permissão (contratante). RBAC CA-1.
class CandidaturaForbidden extends CandidaturaResult {}

/// Rede/5xx — falha técnica recuperável; o modal mantém-se com "Tentar de novo" (§4.8).
class CandidaturaErroRede extends CandidaturaResult {}

/// Resultado do DELETE /api/candidaturas/{id} (CA-8).
sealed class RetirarResult {}

class RetirarSuccess extends RetirarResult {}

/// 409 — não retirável (mudou de estado, ex.: aprovada). SCREEN-050 §4.9.
class RetirarConflict extends RetirarResult {}

/// 403/404/rede — falha; a UI avisa sem alterar o estado visual otimista.
class RetirarErro extends RetirarResult {}

/// STORY-052 (CA-7/CA-8) — desfecho de manter/retirar candidatura após edição material.
sealed class RevisaoResult {}

class RevisaoSuccess extends RevisaoResult {
  /// Estado resultante (`pendente` ao manter; `retirada_por_edicao` ao retirar).
  final String estado;
  RevisaoSuccess(this.estado);
}

/// 409 — não está mais em revisão (o prazo estourou e o cron já retirou). SCREEN-052 §4.6.
class RevisaoConflict extends RevisaoResult {}

/// 403/404/rede — falha; a UI volta o botão ao normal sem mudar o estado visual.
class RevisaoErro extends RevisaoResult {}

/// Serviço de candidatura (STORY-050). Sessão Sanctum same-origin: o cookie trafega sozinho
/// (não refazemos /sanctum/csrf-cookie no meio da sessão — IDR-019).
class CandidaturaService {
  CandidaturaService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  String get _base => '$cadastroApiBase/api';

  /// POST /api/vagas/{id}/candidaturas — candidata em 1 toque, aplicando os 3 gates no back.
  Future<CandidaturaResult> candidatar(String vagaId) async {
    http.Response res;
    try {
      res = await _client.post(
        Uri.parse('$_base/vagas/$vagaId/candidaturas'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      );
    } catch (_) {
      return CandidaturaErroRede();
    }

    final data = _json(res.body);
    switch (res.statusCode) {
      case 201:
        return CandidaturaCriada(
          id: data['id'] as String? ?? '',
          estado: data['estado'] as String? ?? 'pendente',
          candidatouEm: data['candidatou_em'] != null
              ? DateTime.tryParse(data['candidatou_em'] as String)
              : null,
          alerta: data['alerta'] as bool? ?? false,
        );
      case 409:
        return CandidaturaJaExiste();
      case 422:
        final detalhe = (data['detalhe'] as Map?)?.cast<String, dynamic>();
        return CandidaturaBloqueada(
          erro: data['erro'] as String? ?? 'desconhecido',
          mensagem:
              data['mensagem'] as String? ?? 'Não foi possível se candidatar.',
          conflito: ConflitoInfo.fromDetalhe(detalhe),
          turnoId: detalhe?['turno_id'] as String?,
        );
      case 403:
        return CandidaturaForbidden();
      default:
        return CandidaturaErroRede();
    }
  }

  /// DELETE /api/candidaturas/{id} — retira a própria candidatura `pendente` (CA-8).
  Future<RetirarResult> retirar(String candidaturaId) async {
    http.Response res;
    try {
      res = await _client.delete(
        Uri.parse('$_base/candidaturas/$candidaturaId'),
        headers: {'Accept': 'application/json'},
      );
    } catch (_) {
      return RetirarErro();
    }

    switch (res.statusCode) {
      case 200:
        return RetirarSuccess();
      case 409:
        return RetirarConflict();
      default:
        return RetirarErro();
    }
  }

  /// POST /api/candidaturas/{id}/confirmar-apos-edicao — mantém a candidatura (CA-7).
  Future<RevisaoResult> manterAposEdicao(String candidaturaId) =>
      _revisao('$_base/candidaturas/$candidaturaId/confirmar-apos-edicao');

  /// POST /api/candidaturas/{id}/retirar-apos-edicao — retira a candidatura (CA-8).
  Future<RevisaoResult> retirarAposEdicao(String candidaturaId) =>
      _revisao('$_base/candidaturas/$candidaturaId/retirar-apos-edicao');

  Future<RevisaoResult> _revisao(String url) async {
    http.Response res;
    try {
      res = await _client.post(
        Uri.parse(url),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      );
    } catch (_) {
      return RevisaoErro();
    }

    switch (res.statusCode) {
      case 200:
        return RevisaoSuccess(_json(res.body)['estado'] as String? ?? '');
      case 409:
        return RevisaoConflict();
      default:
        return RevisaoErro();
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
}
