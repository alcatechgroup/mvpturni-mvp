import 'dart:convert';

import 'package:http/http.dart' as http;

import '../cadastro/shared/cadastro_types.dart' show cadastroApiBase;

/// STORY-048 — filtros fixos do feed (CA-1/CA-4). `slug` casa com o `?filtro=` da API;
/// `label` é o texto do chip (microcopy SCREEN-048 §5).
enum FeedFiltro {
  todas('todas', 'Todas'),
  minhaFuncao('minha_funcao', 'Minha função'),
  altoMatch('alto_match', 'Alto match'),
  candidatadas('candidatadas', 'Candidatadas');

  const FeedFiltro(this.slug, this.label);

  final String slug;
  final String label;

  static FeedFiltro fromSlug(String? slug) => FeedFiltro.values.firstWhere(
    (f) => f.slug == slug,
    orElse: () => FeedFiltro.todas,
  );
}

/// Score de match de uma vaga (ADR-014). O breakdown textual fica no detalhe (STORY-049);
/// o card usa `total` (barra + número) e, se quiser, os `componentes`.
class FeedScore {
  final int total;
  final Map<String, int> componentes;

  const FeedScore({required this.total, required this.componentes});

  factory FeedScore.fromJson(Map<String, dynamic> json) => FeedScore(
    total: (json['total'] as num?)?.toInt() ?? 0,
    componentes: ((json['componentes'] as Map?) ?? {}).map(
      (k, v) => MapEntry(k as String, (v as num?)?.toInt() ?? 0),
    ),
  );
}

/// Item do feed (SCREEN-048 — o que o card precisa). `distanciaKm` null = geo indisponível
/// (o card omite a distância). `podeCandidatar` vem do gate PDR-005 (CA-8).
class FeedVagaResumo {
  final int id;
  final String funcao;
  final DateTime dataInicio;
  final DateTime dataFim;
  final double valor;
  final double? distanciaKm;
  final FeedScore score;
  final bool jaCandidatou;
  final bool podeCandidatar;

  const FeedVagaResumo({
    required this.id,
    required this.funcao,
    required this.dataInicio,
    required this.dataFim,
    required this.valor,
    required this.distanciaKm,
    required this.score,
    required this.jaCandidatou,
    required this.podeCandidatar,
  });

  factory FeedVagaResumo.fromJson(Map<String, dynamic> json) => FeedVagaResumo(
    id: (json['id'] as num).toInt(),
    funcao: json['funcao'] as String? ?? '',
    dataInicio: DateTime.parse(json['data_inicio'] as String),
    dataFim: DateTime.parse(json['data_fim'] as String),
    valor: (json['valor'] as num?)?.toDouble() ?? 0,
    distanciaKm: (json['distancia_km'] as num?)?.toDouble(),
    score: FeedScore.fromJson(
      (json['score'] as Map?)?.cast<String, dynamic>() ?? {},
    ),
    jaCandidatou: json['ja_candidatou'] as bool? ?? false,
    podeCandidatar: json['pode_candidatar'] as bool? ?? true,
  );
}

/// Resultado do GET /api/feed.
sealed class FeedResult {}

class FeedSuccess extends FeedResult {
  final List<FeedVagaResumo> vagas;
  final int page;
  final bool hasNext;
  FeedSuccess(this.vagas, this.page, this.hasNext);
}

/// 403 — papel sem permissão (contratante). RBAC herdado de STORY-016.
class FeedForbidden extends FeedResult {}

/// Rede/5xx — erro recuperável; a tela oferece retry sem liberar lista vazia às cegas.
class FeedError extends FeedResult {}

/// Serviço do feed do profissional (STORY-048). Sessão Sanctum same-origin: o cookie
/// trafega sozinho (não refazemos /sanctum/csrf-cookie no meio da sessão — IDR-019).
class FeedService {
  FeedService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  String get _base => '$cadastroApiBase/api';

  /// GET /api/feed?filtro=…&page=N — lista ranqueada (CA-1). 403 → contratante;
  /// rede/5xx → erro.
  Future<FeedResult> fetch({
    FeedFiltro filtro = FeedFiltro.todas,
    int page = 1,
  }) async {
    http.Response res;
    try {
      res = await _client.get(
        Uri.parse('$_base/feed?filtro=${filtro.slug}&page=$page'),
        headers: {'Accept': 'application/json'},
      );
    } catch (_) {
      return FeedError();
    }

    switch (res.statusCode) {
      case 200:
        final data = _json(res.body);
        final vagas = ((data['vagas'] as List?) ?? [])
            .map((e) => FeedVagaResumo.fromJson(e as Map<String, dynamic>))
            .toList(growable: false);
        return FeedSuccess(
          vagas,
          (data['page'] as num?)?.toInt() ?? page,
          data['has_next'] as bool? ?? false,
        );
      case 403:
        return FeedForbidden();
      default:
        return FeedError();
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
