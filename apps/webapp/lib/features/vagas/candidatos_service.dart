import 'dart:convert';

import 'package:http/http.dart' as http;

import '../cadastro/shared/cadastro_types.dart' show cadastroApiBase;
import 'vaga_detalhe_service.dart' show ScoreBreakdown;

/// STORY-051 — perfil do candidato exibido no card do painel (CA-3). `plano` é stub (null no
/// MVP — STORY-045 CA-5); `fotoUrl` é best-effort (null → avatar cai para iniciais).
class PerfilCandidato {
  final String id;
  final String nome;
  final String? fotoUrl;
  final String? funcaoPrimaria;
  final String? nivel;
  final double? scoreHistorico;
  final String? plano;

  const PerfilCandidato({
    required this.id,
    required this.nome,
    required this.fotoUrl,
    required this.funcaoPrimaria,
    required this.nivel,
    required this.scoreHistorico,
    required this.plano,
  });

  /// Iniciais para o fallback do avatar (até 2 letras das primeiras palavras do nome).
  String get iniciais {
    final partes = nome.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (partes.isEmpty) return '?';
    final letras = partes.take(2).map((p) => p[0].toUpperCase()).join();
    return letras.isEmpty ? '?' : letras;
  }

  factory PerfilCandidato.fromJson(Map<String, dynamic> json) =>
      PerfilCandidato(
        id: json['id'] as String,
        nome: json['nome'] as String? ?? '',
        fotoUrl: json['foto_url'] as String?,
        funcaoPrimaria: json['funcao_primaria'] as String?,
        nivel: json['nivel'] as String?,
        scoreHistorico: (json['score_historico'] as num?)?.toDouble(),
        plano: json['plano'] as String?,
      );
}

/// Um candidato no painel: a candidatura + o perfil + o snapshot de score/breakdown (CA-1).
/// `score` (breakdown) é o **snapshot persistido** no instante da candidatura — não recalculado
/// (CA-2/CA-4); pode ser nulo em candidatura legada (fail-soft, esconde o breakdown).
class CandidatoCard {
  final String id;
  final PerfilCandidato profissional;
  final int? scoreNoMomento;
  final ScoreBreakdown? score;
  final DateTime? candidatouEm;
  final bool alertaHabitualidade;

  const CandidatoCard({
    required this.id,
    required this.profissional,
    required this.scoreNoMomento,
    required this.score,
    required this.candidatouEm,
    required this.alertaHabitualidade,
  });

  factory CandidatoCard.fromJson(Map<String, dynamic> json) {
    final breakdown = (json['score_breakdown'] as Map?)
        ?.cast<String, dynamic>();
    return CandidatoCard(
      id: json['id'] as String,
      profissional: PerfilCandidato.fromJson(
        (json['profissional'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      scoreNoMomento: (json['score_no_momento'] as num?)?.toInt(),
      score: breakdown != null ? ScoreBreakdown.fromJson(breakdown) : null,
      candidatouEm: json['candidatou_em'] != null
          ? DateTime.tryParse(json['candidatou_em'] as String)
          : null,
      alertaHabitualidade: json['alerta_habitualidade'] as bool? ?? false,
    );
  }
}

/// STORY-058 (SCREEN-058 D1) — preview financeiro da vaga no payload do painel: o contratante
/// vê valor/taxa/total separados ANTES de confirmar o aceite (PDR-004). Strings decimais
/// ("200.00") como o backend serializa (cast decimal:2).
class VagaFinanceiro {
  final String valor;
  final String taxaTurni;
  final String totalContratante;

  const VagaFinanceiro({
    required this.valor,
    required this.taxaTurni,
    required this.totalContratante,
  });

  static VagaFinanceiro? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    return VagaFinanceiro(
      valor: json['valor'] as String? ?? '0.00',
      taxaTurni: json['taxa_turni'] as String? ?? '0.00',
      totalContratante: json['total_contratante'] as String? ?? '0.00',
    );
  }
}

/// Resultado do GET /api/vagas/{id}/candidatos.
sealed class CandidatosResult {}

class CandidatosSuccess extends CandidatosResult {
  final List<CandidatoCard> candidatos;
  final int total;

  /// Preview financeiro (STORY-058). Nulo em payload legado — o D1 degrada sem a tabela.
  final VagaFinanceiro? vaga;
  CandidatosSuccess(this.candidatos, this.total, [this.vaga]);
}

/// 403 — papel sem permissão (profissional) ou contratante não-dono. RBAC CA-1.
class CandidatosForbidden extends CandidatosResult {}

/// 404 — vaga inexistente.
class CandidatosNotFound extends CandidatosResult {}

/// Rede/5xx — erro recuperável; a tela oferece retry.
class CandidatosError extends CandidatosResult {}

/// STORY-058 — desfecho do POST /api/candidaturas/{id}/aprovar (contrato SCREEN-058 §10).
sealed class AprovarResult {}

/// 201 — turno criado (`confirmado`); a pré-autorização roda assíncrona no worker.
class AprovarSucesso extends AprovarResult {
  final String turnoId;
  AprovarSucesso(this.turnoId);
}

/// 409 — clique duplo / outra sessão já aprovou (idempotência CA-5). UI trata como informativo.
class AprovarJaAceita extends AprovarResult {
  final String? turnoId;
  AprovarJaAceita(this.turnoId);
}

/// 422 — bloqueio de negócio: `habitualidade_bloqueio` (PF 3ª — D2), `requer_override`
/// (PJ 3ª — D3), `vaga_fechada`, `candidatura_invalida`. `mensagem` vem pronta do back.
class AprovarBloqueio extends AprovarResult {
  final String erro;
  final String mensagem;
  AprovarBloqueio({required this.erro, required this.mensagem});
}

/// 403/404/5xx/rede — falha técnica; snackbar com "Tentar de novo".
class AprovarErro extends AprovarResult {}

/// Serviço do painel de candidatos (STORY-051). Sessão Sanctum same-origin: o cookie trafega
/// sozinho (não refazemos /sanctum/csrf-cookie no meio da sessão — IDR-019).
class CandidatosService {
  CandidatosService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  String get _base => '$cadastroApiBase/api';

  /// GET /api/vagas/{id}/candidatos — 200 → sucesso; 403 → sem permissão; 404 → vaga
  /// inexistente; rede/5xx → erro.
  Future<CandidatosResult> fetch(String vagaId) async {
    http.Response res;
    try {
      res = await _client.get(
        Uri.parse('$_base/vagas/$vagaId/candidatos'),
        headers: {'Accept': 'application/json'},
      );
    } catch (_) {
      return CandidatosError();
    }

    switch (res.statusCode) {
      case 200:
        try {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          final lista = (data['candidatos'] as List? ?? const [])
              .map(
                (e) =>
                    CandidatoCard.fromJson((e as Map).cast<String, dynamic>()),
              )
              .toList(growable: false);
          final total = (data['total'] as num?)?.toInt() ?? lista.length;
          final vaga = VagaFinanceiro.fromJson(
            (data['vaga'] as Map?)?.cast<String, dynamic>(),
          );
          return CandidatosSuccess(lista, total, vaga);
        } catch (_) {
          return CandidatosError();
        }
      case 403:
        return CandidatosForbidden();
      case 404:
        return CandidatosNotFound();
      default:
        return CandidatosError();
    }
  }

  /// STORY-058 — POST /api/candidaturas/{id}/aprovar. Abre o turno (201), responde 409 no
  /// clique duplo entre sessões e 422 nos bloqueios de negócio (PDR-002, vaga fechada).
  /// `override` = "Assumo o risco e aceito" do D3 (PJ na 3ª alocação — CA-4).
  Future<AprovarResult> aprovar(
    String candidaturaId, {
    bool override = false,
  }) async {
    http.Response res;
    try {
      res = await _client.post(
        Uri.parse('$_base/candidaturas/$candidaturaId/aprovar'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(override ? {'override': true} : {}),
      );
    } catch (_) {
      return AprovarErro();
    }

    Map<String, dynamic> data;
    try {
      data = (jsonDecode(res.body) as Map).cast<String, dynamic>();
    } catch (_) {
      data = const {};
    }

    switch (res.statusCode) {
      case 201:
        final turno = (data['turno'] as Map?)?.cast<String, dynamic>();
        return AprovarSucesso(turno?['id'] as String? ?? '');
      case 409:
        return AprovarJaAceita(data['turno_id'] as String?);
      case 422:
        return AprovarBloqueio(
          erro: data['erro'] as String? ?? 'desconhecido',
          mensagem:
              data['mensagem'] as String? ??
              'Não foi possível concluir o aceite.',
        );
      default:
        return AprovarErro();
    }
  }
}
