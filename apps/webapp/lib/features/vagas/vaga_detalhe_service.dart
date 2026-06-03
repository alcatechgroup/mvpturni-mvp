import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/time/turni_datetime.dart';
import '../cadastro/shared/cadastro_types.dart' show cadastroApiBase;
import 'vaga_service.dart' show DiffLinha;

export 'vaga_service.dart' show DiffLinha;

/// STORY-049 — estado visual de um componente do breakdown (domain/match.md / ADR-014):
/// `ok` pontuou cheio, `partial` pontuou parcial, `miss` zerou. A cor/ícone vêm daqui.
enum EstadoComponente {
  ok,
  partial,
  miss;

  static EstadoComponente fromValue(String? v) => switch (v) {
    'ok' => EstadoComponente.ok,
    'partial' => EstadoComponente.partial,
    _ => EstadoComponente.miss,
  };
}

/// STORY-049 — os 4 componentes do match, na ordem canônica de domain/match.md (a UI NÃO
/// reordena). `slug` casa com a chave do `breakdown` do payload; `label` é o texto da linha.
enum ComponenteMatch {
  funcao('funcao', 'Função'),
  distancia('distancia', 'Distância'),
  historico('historico', 'Histórico'),
  nivel('nivel', 'Nível na trilha');

  const ComponenteMatch(this.slug, this.label);

  final String slug;
  final String label;
}

/// Uma linha do breakdown explicável (CA-2/CA-3): pontos obtidos, teto, estado e prosa.
class BreakdownLinha {
  final ComponenteMatch componente;
  final int pontos;
  final int pontosMax;
  final EstadoComponente estado;
  final String descricao;

  const BreakdownLinha({
    required this.componente,
    required this.pontos,
    required this.pontosMax,
    required this.estado,
    required this.descricao,
  });

  factory BreakdownLinha.fromJson(
    ComponenteMatch c,
    Map<String, dynamic> json,
  ) => BreakdownLinha(
    componente: c,
    pontos: (json['pontos'] as num?)?.toInt() ?? 0,
    pontosMax: (json['pontos_max'] as num?)?.toInt() ?? 0,
    estado: EstadoComponente.fromValue(json['estado'] as String?),
    descricao: json['descricao'] as String? ?? '',
  );
}

/// Score + breakdown completo da vaga (shape de `MatchScore::toArray()` — STORY-045).
class ScoreBreakdown {
  final int total;
  final List<BreakdownLinha> linhas;

  const ScoreBreakdown({required this.total, required this.linhas});

  factory ScoreBreakdown.fromJson(Map<String, dynamic> json) {
    final breakdown =
        (json['breakdown'] as Map?)?.cast<String, dynamic>() ?? const {};
    // Ordem fixa (domain/match.md): a UI confia, não reordena.
    final linhas = ComponenteMatch.values
        .where((c) => breakdown[c.slug] != null)
        .map(
          (c) => BreakdownLinha.fromJson(
            c,
            (breakdown[c.slug] as Map).cast<String, dynamic>(),
          ),
        )
        .toList(growable: false);
    return ScoreBreakdown(
      total: (json['total'] as num?)?.toInt() ?? 0,
      linhas: linhas,
    );
  }
}

/// Candidatura vigente do profissional nesta vaga (CA-6). `id` (STORY-050) é necessário para a
/// retirada (DELETE /candidaturas/{id}); é nulo só no estado otimista pós-corrida (CA-6).
class CandidaturaResumo {
  final int? id;
  final String estado;
  final DateTime? criadaEm;

  const CandidaturaResumo({
    this.id,
    required this.estado,
    required this.criadaEm,
  });

  bool get pendente => estado == 'pendente';

  factory CandidaturaResumo.fromJson(Map<String, dynamic> json) =>
      CandidaturaResumo(
        id: (json['id'] as num?)?.toInt(),
        estado: json['estado'] as String? ?? '',
        criadaEm: json['criada_em'] != null
            ? DateTime.tryParse(json['criada_em'] as String)
            : null,
      );
}

/// STORY-052 CA-11 — bloco de revisão pós-edição: prazo para confirmar + o que mudou (diff
/// "o que o profissional viu → estado atual"). Presente só quando a candidatura está em
/// `pendente_revisao_apos_edicao`.
class RevisaoInfo {
  final DateTime? prazoEm;
  final List<DiffLinha> diff;

  const RevisaoInfo({required this.prazoEm, required this.diff});

  factory RevisaoInfo.fromJson(Map<String, dynamic> json) => RevisaoInfo(
    prazoEm: json['prazo_em'] != null
        ? DateTime.tryParse(json['prazo_em'] as String)
        : null,
    diff: (json['diff'] as List? ?? [])
        .map((e) => DiffLinha.fromJson(e as Map<String, dynamic>))
        .toList(growable: false),
  );
}

/// Detalhe completo da vaga (contrato CA-1).
class VagaDetalhe {
  final int id;
  final String funcao;
  final String? estabelecimento;
  final String? cidade;
  final DateTime dataInicio;
  final DateTime dataFim;
  final double valor;
  final double? distanciaKm;
  final ScoreBreakdown score;
  final bool podeCandidatar;
  final bool jaCandidatou;
  final CandidaturaResumo? candidatura;
  final String? motivoBloqueio;
  final RevisaoInfo? revisao;

  const VagaDetalhe({
    required this.id,
    required this.funcao,
    required this.estabelecimento,
    required this.cidade,
    required this.dataInicio,
    required this.dataFim,
    required this.valor,
    required this.distanciaKm,
    required this.score,
    required this.podeCandidatar,
    required this.jaCandidatou,
    required this.candidatura,
    required this.motivoBloqueio,
    this.revisao,
  });

  /// A candidatura precisa de revisão pós-edição (banner com Manter/Retirar — CA-11).
  bool get emRevisao => candidatura?.estado == 'pendente_revisao_apos_edicao';

  factory VagaDetalhe.fromJson(Map<String, dynamic> json) => VagaDetalhe(
    id: (json['id'] as num).toInt(),
    funcao: json['funcao'] as String? ?? '',
    estabelecimento: json['estabelecimento'] as String?,
    cidade: json['cidade'] as String?,
    dataInicio: TurniDateTime.parseRequired(json['data_inicio'] as String),
    dataFim: TurniDateTime.parseRequired(json['data_fim'] as String),
    valor: (json['valor'] as num?)?.toDouble() ?? 0,
    distanciaKm: (json['distancia_km'] as num?)?.toDouble(),
    score: ScoreBreakdown.fromJson(
      (json['score_breakdown'] as Map?)?.cast<String, dynamic>() ?? const {},
    ),
    podeCandidatar: json['pode_candidatar'] as bool? ?? true,
    jaCandidatou: json['ja_candidatou'] as bool? ?? false,
    candidatura: json['candidatura'] != null
        ? CandidaturaResumo.fromJson(
            (json['candidatura'] as Map).cast<String, dynamic>(),
          )
        : null,
    motivoBloqueio: json['motivo_bloqueio'] as String?,
    revisao: json['revisao'] != null
        ? RevisaoInfo.fromJson((json['revisao'] as Map).cast<String, dynamic>())
        : null,
  );
}

/// Resultado do GET /api/vagas/{id}/detalhe.
sealed class DetalheResult {}

class DetalheSuccess extends DetalheResult {
  final VagaDetalhe vaga;
  DetalheSuccess(this.vaga);
}

/// 403 — papel sem permissão (contratante). RBAC CA-7.
class DetalheForbidden extends DetalheResult {}

/// 404 — vaga inexistente/encerrada/no passado (SCREEN-049 §4.7).
class DetalheNotFound extends DetalheResult {}

/// Rede/5xx — erro recuperável; a tela oferece retry.
class DetalheError extends DetalheResult {}

/// Serviço do detalhe da vaga (STORY-049). Sessão Sanctum same-origin: o cookie trafega
/// sozinho (não refazemos /sanctum/csrf-cookie no meio da sessão — IDR-019).
class VagaDetalheService {
  VagaDetalheService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  String get _base => '$cadastroApiBase/api';

  /// GET /api/vagas/{id}/detalhe — 200 → sucesso; 403 → contratante; 404 → indisponível;
  /// rede/5xx → erro.
  Future<DetalheResult> fetch(int id) async {
    http.Response res;
    try {
      res = await _client.get(
        Uri.parse('$_base/vagas/$id/detalhe'),
        headers: {'Accept': 'application/json'},
      );
    } catch (_) {
      return DetalheError();
    }

    switch (res.statusCode) {
      case 200:
        try {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          return DetalheSuccess(VagaDetalhe.fromJson(data));
        } catch (_) {
          return DetalheError();
        }
      case 403:
        return DetalheForbidden();
      case 404:
        return DetalheNotFound();
      default:
        return DetalheError();
    }
  }
}
