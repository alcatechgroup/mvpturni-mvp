import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/time/turni_datetime.dart';
import '../cadastro/shared/cadastro_types.dart' show cadastroApiBase;

/// STORY-088 / STORY-085 (ADR-019 + DDR-004) — leitura da reputação do perfil.
///
/// GET /api/perfil/{id}: o front **só lê** score/nível/XP/depoimentos já recomputados pelo motor
/// (STORY-085). Reciprocidade: profissional traz nível/turnos (+ XP só para o próprio dono);
/// contratante traz só score + depoimentos anônimos (LGPD/DDR-004). Sessão Sanctum same-origin
/// (IDR-019) — sem CSRF mid-sessão (memória do projeto).

/// Um depoimento (avaliação recebida com comentário). Autor nominal (estabelecimento) ou anônimo
/// ("Profissional", sobre o contratante — LGPD). `funcao` é a função exercida no turno.
class Depoimento {
  const Depoimento({
    required this.estrelas,
    required this.comentario,
    required this.funcao,
    required this.autorNome,
    required this.data,
  });

  final int estrelas;
  final String comentario;
  final String? funcao;
  final String? autorNome;
  final DateTime? data;

  factory Depoimento.fromJson(Map<String, dynamic> json) => Depoimento(
    estrelas: (json['estrelas'] as num?)?.toInt() ?? 0,
    comentario: json['comentario'] as String? ?? '',
    funcao: json['funcao'] as String?,
    autorNome: json['autor_nome'] as String?,
    data: TurniDateTime.parse(json['data'] as String?),
  );
}

/// Reputação consultável de um perfil. Profissional expõe nível/turnos (+ XP só para o dono);
/// contratante expõe só score. `temXp` distingue dono (vê XP) de terceiro (não vê).
class ReputacaoPerfil {
  const ReputacaoPerfil({
    required this.papel,
    required this.score,
    required this.totalAvaliacoes,
    required this.seloNovo,
    required this.nivel,
    required this.turnosRealizados,
    required this.xp,
    required this.xpProximoNivel,
    required this.depoimentos,
  });

  final String papel;
  final double score;
  final int totalAvaliacoes;
  final bool seloNovo;

  /// Nível (enum NivelProfissional) — só profissional; `null` para contratante.
  final String? nivel;
  final int? turnosRealizados;

  /// XP atual — só devolvido ao próprio dono (privado, STORY-085). `null` = terceiro/contratante.
  final int? xp;

  /// XP até o próximo nível — `null` no nível máximo (Elite) **ou** quando não é o dono. Só faz
  /// sentido ler junto de [temXp].
  final int? xpProximoNivel;

  final List<Depoimento> depoimentos;

  bool get isProfissional => papel == 'profissional';

  /// Tem XP visível (é o próprio dono e é profissional). A barra de XP só aparece quando true.
  bool get temXp => xp != null;

  factory ReputacaoPerfil.fromJson(Map<String, dynamic> json) {
    final depo = (json['depoimentos'] as List<dynamic>? ?? [])
        .map((e) => Depoimento.fromJson((e as Map).cast<String, dynamic>()))
        .toList(growable: false);

    return ReputacaoPerfil(
      papel: json['papel'] as String? ?? 'profissional',
      score: (json['score'] as num?)?.toDouble() ?? 0,
      totalAvaliacoes: (json['total_avaliacoes'] as num?)?.toInt() ?? 0,
      seloNovo: json['selo_novo'] as bool? ?? false,
      nivel: json['nivel'] as String?,
      turnosRealizados: (json['turnos_realizados'] as num?)?.toInt(),
      // Chave ausente (terceiro/contratante) ⇒ xp null ⇒ temXp false. `containsKey` distingue
      // "ausente" de "presente e null" (este último não ocorre p/ xp; ocorre p/ xp_proximo_nivel).
      xp: json.containsKey('xp') ? (json['xp'] as num?)?.toInt() : null,
      xpProximoNivel: (json['xp_proximo_nivel'] as num?)?.toInt(),
      depoimentos: depo,
    );
  }
}

/// Desfecho de GET /api/perfil/{id}.
sealed class ReputacaoResult {}

/// 200 — reputação carregada.
class ReputacaoCarregada extends ReputacaoResult {
  ReputacaoCarregada(this.perfil);

  final ReputacaoPerfil perfil;
}

/// 404 — perfil inexistente/sem profile de reputação.
class ReputacaoNaoEncontrada extends ReputacaoResult {}

/// Rede/5xx/status inesperado — recuperável (a tela oferece "Tentar de novo").
class ReputacaoErro extends ReputacaoResult {}

class PerfilReputacaoService {
  PerfilReputacaoService({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  Future<ReputacaoResult> fetch(String userId) async {
    http.Response res;
    try {
      res = await _client.get(
        Uri.parse('$cadastroApiBase/api/perfil/$userId'),
        headers: {'Accept': 'application/json'},
      );
    } catch (_) {
      return ReputacaoErro();
    }

    switch (res.statusCode) {
      case 200:
        try {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          return ReputacaoCarregada(ReputacaoPerfil.fromJson(data));
        } catch (_) {
          return ReputacaoErro();
        }
      case 404:
        return ReputacaoNaoEncontrada();
      default:
        return ReputacaoErro();
    }
  }
}
