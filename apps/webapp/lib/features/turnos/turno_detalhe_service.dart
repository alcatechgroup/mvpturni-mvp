import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/time/turni_datetime.dart';
import '../cadastro/shared/cadastro_types.dart' show cadastroApiBase;
import 'turnos_service.dart' show TurnoEstadoResumo;

/// Eventos da timeline do turno (STORY-060 CA-3 / SCREEN-060 §4.1). Fail-soft: evento novo
/// vindo do back vira `desconhecido` ("Atualização do turno"), nunca quebra o parse.
enum TimelineEventoTipo {
  turnoCriado('turno_criado', 'Turno confirmado'),
  aceiteEmitido('aceite_eletronico_emitido', 'Aceite eletrônico emitido'),
  pagamentoPreAutorizado('pagamento_pre_autorizado', 'Pagamento reservado'),
  checkinSolicitado('checkin_solicitado', 'PIN de check-in gerado'),
  checkinValidado('checkin_validado', 'Check-in validado'),
  checkoutSolicitado('checkout_solicitado', 'PIN de check-out gerado'),
  checkoutValidado('checkout_validado', 'Check-out validado'),
  pagamentoCapturado('pagamento_capturado', 'Pagamento processado'),
  pixEnviado('pix_enviado', 'Pix enviado'),
  cancelado('cancelado', 'Turno cancelado'),
  noShowPro('no_show_pro', 'Turno não realizado'),
  desconhecido('', 'Atualização do turno');

  const TimelineEventoTipo(this.slug, this.titulo);

  final String slug;
  final String titulo;

  static TimelineEventoTipo fromApi(String? value) =>
      TimelineEventoTipo.values.firstWhere(
        (e) => e.slug == value && e != TimelineEventoTipo.desconhecido,
        orElse: () => TimelineEventoTipo.desconhecido,
      );
}

/// Um evento da trilha simplificada (audit log filtrado pelo servidor).
class TimelineEvento {
  final String id;
  final TimelineEventoTipo tipo;
  final DateTime ocorridoEm;

  /// Valor financeiro do evento, já filtrado por papel no SERVIDOR (SCREEN-060 §4.1):
  /// profissional só o recebe em `pix_enviado`; contratante nos eventos de pagamento.
  final double? valor;

  /// Quem cancelou (`pro`|`emp`) — presente só em `cancelado` (STORY-066).
  final String? lado;

  const TimelineEvento({
    required this.id,
    required this.tipo,
    required this.ocorridoEm,
    this.valor,
    this.lado,
  });

  factory TimelineEvento.fromJson(Map<String, dynamic> json) => TimelineEvento(
    id: json['id'] as String,
    tipo: TimelineEventoTipo.fromApi(json['evento'] as String?),
    ocorridoEm: TurniDateTime.parseRequired(json['ocorrido_em'] as String),
    valor: (json['valor'] as num?)?.toDouble(),
    lado: json['lado'] as String?,
  );
}

/// Aceite eletrônico imutável do turno — alimenta o modal somente-leitura (CA-5).
class AceiteDoTurno {
  final DateTime? emitidoEm;
  final String conteudoRenderizado;

  const AceiteDoTurno({
    required this.emitidoEm,
    required this.conteudoRenderizado,
  });

  factory AceiteDoTurno.fromJson(Map<String, dynamic> json) => AceiteDoTurno(
    emitidoEm: TurniDateTime.parse(json['emitido_em'] as String?),
    conteudoRenderizado: json['conteudo_renderizado'] as String? ?? '',
  );
}

/// Detalhe do turno (STORY-060 CA-2). O payload é filtrado por papel no servidor:
/// `taxaTurni`/`totalContratante`/`profissional` chegam null para o profissional (que
/// nunca os vê — PDR-004) e preenchidos para o contratante.
class TurnoDetalhe {
  final String id;
  final String funcao;
  final DateTime dataInicio;
  final DateTime dataFim;
  final TurnoEstadoResumo estado;

  /// Estado cru do servidor (decide se a área de ações aparece — terminais não têm).
  final String estadoRaw;
  final double valor;
  final String? estabelecimento;
  final double? taxaTurni;
  final double? totalContratante;
  final String? profissional;
  final AceiteDoTurno? aceite;
  final List<TimelineEvento> timeline;

  const TurnoDetalhe({
    required this.id,
    required this.funcao,
    required this.dataInicio,
    required this.dataFim,
    required this.estado,
    required this.estadoRaw,
    required this.valor,
    required this.estabelecimento,
    required this.taxaTurni,
    required this.totalContratante,
    required this.profissional,
    required this.aceite,
    required this.timeline,
  });

  /// O payload do contratante carrega o total — é assim que a tela sabe o papel sem
  /// depender de estado global (o servidor é a fonte de verdade do RBAC).
  bool get souContratante => totalContratante != null;

  /// Estados terminais não ganham área de ações (SCREEN-060 §4.1 — não prometer ação
  /// onde nunca haverá).
  bool get estadoTerminal => const {
    'finalizado',
    'finalizado_ajustado',
    'cancelado_pro',
    'cancelado_emp',
    'no_show_pro',
    'disputa_resolvida_sem_pagamento',
  }.contains(estadoRaw);

  factory TurnoDetalhe.fromJson(Map<String, dynamic> json) => TurnoDetalhe(
    id: json['id'] as String,
    funcao: json['funcao'] as String? ?? '',
    dataInicio: TurniDateTime.parseRequired(json['data_inicio'] as String),
    dataFim: TurniDateTime.parseRequired(json['data_fim'] as String),
    estado: TurnoEstadoResumo.fromApi(json['estado'] as String?),
    estadoRaw: json['estado'] as String? ?? '',
    valor: (json['valor'] as num?)?.toDouble() ?? 0,
    estabelecimento:
        (json['estabelecimento'] as Map<String, dynamic>?)?['nome'] as String?,
    taxaTurni: (json['taxa_turni'] as num?)?.toDouble(),
    totalContratante: (json['total_contratante'] as num?)?.toDouble(),
    profissional:
        (json['profissional'] as Map<String, dynamic>?)?['nome'] as String?,
    aceite: json['aceite'] == null
        ? null
        : AceiteDoTurno.fromJson(json['aceite'] as Map<String, dynamic>),
    timeline: (json['timeline'] as List? ?? [])
        .map((e) => TimelineEvento.fromJson(e as Map<String, dynamic>))
        .toList(growable: false),
  );
}

/// Resultado do GET de detalhe.
sealed class TurnoDetalheResult {}

class TurnoDetalheSuccess extends TurnoDetalheResult {
  final TurnoDetalhe turno;
  TurnoDetalheSuccess(this.turno);
}

/// 403 (cruzado) e 404 (inexistente) renderizam o MESMO estado "não encontrado"
/// (SCREEN-060 §4.5 — fail-secure: não confirmar existência de turno alheio).
class TurnoDetalheNaoEncontrado extends TurnoDetalheResult {}

class TurnoDetalheError extends TurnoDetalheResult {}

/// Serviço do detalhe do turno (STORY-060). Sessão Sanctum same-origin (IDR-019).
class TurnoDetalheService {
  TurnoDetalheService({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  /// GET /api/turnos/{id} — rota compartilhada; RBAC no servidor (CA-1).
  Future<TurnoDetalheResult> fetch(String id) async {
    http.Response res;
    try {
      res = await _client.get(
        Uri.parse('$cadastroApiBase/api/turnos/$id'),
        headers: {'Accept': 'application/json'},
      );
    } catch (_) {
      return TurnoDetalheError();
    }

    switch (res.statusCode) {
      case 200:
        try {
          return TurnoDetalheSuccess(
            TurnoDetalhe.fromJson(jsonDecode(res.body) as Map<String, dynamic>),
          );
        } catch (_) {
          return TurnoDetalheError();
        }
      case 403 || 404:
        return TurnoDetalheNaoEncontrado();
      default:
        return TurnoDetalheError();
    }
  }
}
