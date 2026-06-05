import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/time/turni_datetime.dart';
import '../cadastro/shared/cadastro_types.dart' show cadastroApiBase;

/// Grupos de estado das listas de turnos (STORY-059 / SCREEN-059 §4.1), na ordem fixa do
/// ciclo de vida. O servidor entrega os grupos já ordenados; o front não reordena —
/// `desconhecido` é fail-soft para grupo novo vindo do back (a UI o renderiza sob
/// "Encerrados", nunca some — SCREEN-059 §4.6).
enum TurnoGrupo {
  confirmado('confirmado', 'Confirmados'),
  aguardandoCheckin('aguardando-checkin', 'Aguardando check-in'),
  ativo('ativo', 'Em andamento'),
  aguardandoCheckout('aguardando-checkout', 'Aguardando check-out'),
  emDisputa('em-disputa', 'Em disputa'),
  finalizado('finalizado', 'Finalizados'),
  encerrado('encerrado', 'Encerrados'),
  desconhecido('encerrado', 'Encerrados');

  const TurnoGrupo(this.slug, this.titulo);

  /// Slug estável para `Key('turnos-grupo-{slug}')` (SCREEN-059 §7).
  final String slug;
  final String titulo;

  static TurnoGrupo fromApi(String? value) => switch (value) {
    'confirmado' => TurnoGrupo.confirmado,
    'aguardando_checkin' => TurnoGrupo.aguardandoCheckin,
    'ativo' => TurnoGrupo.ativo,
    'aguardando_checkout' => TurnoGrupo.aguardandoCheckout,
    'em_disputa' => TurnoGrupo.emDisputa,
    'finalizado' => TurnoGrupo.finalizado,
    'encerrado' => TurnoGrupo.encerrado,
    _ => TurnoGrupo.desconhecido,
  };
}

/// Estado individual do turno — alimenta o selo do card (SCREEN-059 §4.1). Fail-soft:
/// estado novo vira `desconhecido` (selo neutro), nunca quebra o parse.
enum TurnoEstadoResumo {
  confirmado('Confirmado'),
  aguardandoCheckin('Aguardando check-in'),
  ativo('Em andamento'),
  aguardandoCheckout('Aguardando check-out'),
  emDisputa('Em disputa'),
  finalizado('Finalizado'),
  finalizadoAjustado('Finalizado com ajuste'),
  cancelado('Cancelado'),
  noShow('Não realizado'),
  semPagamento('Encerrado sem pagamento'),
  desconhecido('—');

  const TurnoEstadoResumo(this.label);

  final String label;

  static TurnoEstadoResumo fromApi(String? value) => switch (value) {
    'confirmado' => TurnoEstadoResumo.confirmado,
    'aguardando_checkin' => TurnoEstadoResumo.aguardandoCheckin,
    'ativo' => TurnoEstadoResumo.ativo,
    'aguardando_checkout' => TurnoEstadoResumo.aguardandoCheckout,
    'em_disputa' => TurnoEstadoResumo.emDisputa,
    'finalizado' => TurnoEstadoResumo.finalizado,
    'finalizado_ajustado' => TurnoEstadoResumo.finalizadoAjustado,
    'cancelado_pro' || 'cancelado_emp' => TurnoEstadoResumo.cancelado,
    'no_show_pro' => TurnoEstadoResumo.noShow,
    'disputa_resolvida_sem_pagamento' => TurnoEstadoResumo.semPagamento,
    _ => TurnoEstadoResumo.desconhecido,
  };
}

/// Item das listas de turnos (STORY-059 CA-3/CA-4) — o que o card precisa, nos dois papéis.
/// Profissional: `valor` (o que recebe) + `quem` = estabelecimento. Contratante: `valor` =
/// total a pagar (PDR-004) + `quem` = nome do profissional.
class TurnoResumo {
  final String id;
  final String funcao;
  final DateTime dataInicio;
  final DateTime dataFim;
  final TurnoEstadoResumo estado;
  final double valor;

  /// Linha 2 do card: estabelecimento (profissional) ou profissional (contratante).
  /// Nula quando o back não enviou — o card omite a linha (SCREEN-059 §4.6).
  final String? quem;

  const TurnoResumo({
    required this.id,
    required this.funcao,
    required this.dataInicio,
    required this.dataFim,
    required this.estado,
    required this.valor,
    required this.quem,
  });

  factory TurnoResumo.fromJson(Map<String, dynamic> json) => TurnoResumo(
    id: json['id'] as String,
    funcao: json['funcao'] as String? ?? '',
    dataInicio: TurniDateTime.parseRequired(json['data_inicio'] as String),
    dataFim: TurniDateTime.parseRequired(json['data_fim'] as String),
    estado: TurnoEstadoResumo.fromApi(json['estado'] as String?),
    // Profissional recebe `valor`; contratante recebe `total_contratante` (PDR-004).
    valor:
        ((json['valor'] ?? json['total_contratante']) as num?)?.toDouble() ?? 0,
    quem:
        (json['estabelecimento'] as Map<String, dynamic>?)?['nome']
            as String? ??
        (json['profissional'] as Map<String, dynamic>?)?['nome'] as String?,
  );
}

/// Uma seção da lista: grupo + turnos já ordenados pelo servidor (CA-1).
class GrupoTurnos {
  final TurnoGrupo grupo;
  final List<TurnoResumo> turnos;

  const GrupoTurnos({required this.grupo, required this.turnos});

  factory GrupoTurnos.fromJson(Map<String, dynamic> json) => GrupoTurnos(
    grupo: TurnoGrupo.fromApi(json['grupo'] as String?),
    turnos: (json['turnos'] as List? ?? [])
        .map((e) => TurnoResumo.fromJson(e as Map<String, dynamic>))
        .toList(growable: false),
  );
}

/// Resultado dos GETs de lista de turnos.
sealed class TurnosResult {}

class TurnosSuccess extends TurnosResult {
  final List<GrupoTurnos> grupos;
  TurnosSuccess(this.grupos);
}

/// 403 — papel errado na rota (CA-5, fail-secure no servidor).
class TurnosForbidden extends TurnosResult {}

/// Rede/5xx — erro recuperável; a tela mostra retry, não lista vazia às cegas.
class TurnosError extends TurnosResult {}

/// Serviço das listas de turnos (STORY-059). Sessão Sanctum same-origin: o cookie trafega
/// sozinho (não refazemos /sanctum/csrf-cookie no meio da sessão — IDR-019).
class TurnosService {
  TurnosService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  String get _base => '$cadastroApiBase/api';

  /// GET /api/profissional/turnos — "Meus turnos" (CA-1).
  Future<TurnosResult> fetchDoProfissional() =>
      _fetch('$_base/profissional/turnos');

  /// GET /api/contratante/turnos — "Turnos" do contratante (CA-2).
  Future<TurnosResult> fetchDoContratante() =>
      _fetch('$_base/contratante/turnos');

  Future<TurnosResult> _fetch(String url) async {
    http.Response res;
    try {
      res = await _client.get(
        Uri.parse(url),
        headers: {'Accept': 'application/json'},
      );
    } catch (_) {
      return TurnosError();
    }

    switch (res.statusCode) {
      case 200:
        try {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          final grupos = (data['grupos'] as List? ?? [])
              .map((e) => GrupoTurnos.fromJson(e as Map<String, dynamic>))
              .toList(growable: false);
          return TurnosSuccess(grupos);
        } catch (_) {
          return TurnosError();
        }
      case 403:
        return TurnosForbidden();
      default:
        return TurnosError();
    }
  }
}
