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
  checkinCancelado('checkin_cancelado', 'PIN de check-in cancelado'),
  checkinValidado('checkin_validado', 'Check-in validado'),
  // STORY-062 (SCREEN-062 §4.11) — recusa e expiração devolvem o turno a `confirmado`;
  // o profissional entende pela trilha por quê (o motivo da recusa NÃO vem — admin only).
  checkinRecusado('checkin_recusado', 'Check-in recusado'),
  checkinPinExpirado('checkin_pin_expirado', 'PIN de check-in expirado'),
  checkoutSolicitado('checkout_solicitado', 'PIN de check-out gerado'),
  // STORY-064 (SCREEN-064 §4.12) — espelhos de check-out: cancelamento, recusa e
  // expiração devolvem o turno a `ativo`; a trilha explica por quê (motivo da recusa
  // NÃO vem — admin only).
  checkoutCancelado('checkout_cancelado', 'PIN de check-out cancelado'),
  checkoutValidado('checkout_validado', 'Check-out validado'),
  checkoutRecusado('checkout_recusado', 'Check-out recusado'),
  checkoutPinExpirado('checkout_pin_expirado', 'PIN de check-out expirado'),
  pagamentoCapturado('pagamento_capturado', 'Pagamento processado'),
  pixEnviado('pix_enviado', 'Pix enviado'),
  cancelado('cancelado', 'Turno cancelado'),
  noShowPro('no_show_pro', 'Turno não realizado'),
  // STORY-066 (SCREEN-066 §A.5) — liberação da pré-autorização (cancelamento/no-show).
  pagamentoLiberado('pagamento_liberado', 'Reserva de pagamento liberada'),
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

/// Resultado do geofencing do check-in (PDR-008 / STORY-061): aparece no evento
/// `checkin_solicitado` da timeline e na resposta da geração do PIN.
class GeofencingCheckin {
  final bool ok;
  final double? distanciaMetros;
  final String?
  razao; // fora_do_raio | permissao_negada | timeout | indisponivel

  const GeofencingCheckin({
    required this.ok,
    required this.distanciaMetros,
    required this.razao,
  });

  factory GeofencingCheckin.fromJson(Map<String, dynamic> json) =>
      GeofencingCheckin(
        ok: json['ok'] as bool? ?? false,
        distanciaMetros: (json['distancia_metros'] as num?)?.toDouble(),
        razao: json['razao'] as String?,
      );
}

/// Janela de geração do PIN de check-in (STORY-061 CA-1) — calculada no servidor a
/// partir da config; a UI só compara com o relógio local para o estado do botão
/// (o servidor revalida na geração — 422 se o relógio do device mentir).
class CheckinJanela {
  final DateTime abreEm;
  final DateTime fechaEm;

  const CheckinJanela({required this.abreEm, required this.fechaEm});

  factory CheckinJanela.fromJson(Map<String, dynamic> json) => CheckinJanela(
    abreEm: TurniDateTime.parseRequired(json['abre_em'] as String),
    fechaEm: TurniDateTime.parseRequired(json['fecha_em'] as String),
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

  /// Motivo do cancelamento — visível aos DOIS lados (SCREEN-066 §A.5,
  /// decisão do PO 2026-06-06); null quando quem cancelou não informou.
  final String? motivo;

  /// X horas do no-show — presente só em `no_show_pro` (STORY-066; a copy usa
  /// "em até {X} horas"; seeds antigos sem o campo degradam para copy genérica).
  final int? limiteHoras;

  /// Nota de geofencing — presente em `checkin_solicitado` (STORY-061) e
  /// `checkout_solicitado` (STORY-064 — único lugar onde o geo de check-out aparece;
  /// seeds antigos não a têm — a timeline degrada para título sem descrição).
  final GeofencingCheckin? geofencing;

  const TimelineEvento({
    required this.id,
    required this.tipo,
    required this.ocorridoEm,
    this.valor,
    this.lado,
    this.motivo,
    this.limiteHoras,
    this.geofencing,
  });

  factory TimelineEvento.fromJson(Map<String, dynamic> json) => TimelineEvento(
    id: json['id'] as String,
    tipo: TimelineEventoTipo.fromApi(json['evento'] as String?),
    ocorridoEm: TurniDateTime.parseRequired(json['ocorrido_em'] as String),
    valor: (json['valor'] as num?)?.toDouble(),
    lado: json['lado'] as String?,
    motivo: json['motivo'] as String?,
    limiteHoras: (json['limite_horas'] as num?)?.toInt(),
    geofencing: json['geofencing'] == null
        ? null
        : GeofencingCheckin.fromJson(
            json['geofencing'] as Map<String, dynamic>,
          ),
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

/// STORY-065 (CA-4 / SCREEN-065 §A) — status do Pix pós-turno. Só chega para o
/// PROFISSIONAL em `finalizado`. O servidor já decide o que o profissional vê:
/// falha de Pix chega como `a_caminho` (§A.4 — PDR-010, tratamento é da operação);
/// o front nem sabe distinguir.
class PixDoTurno {
  final bool enviado;
  final DateTime? enviadoEm;

  const PixDoTurno({required this.enviado, this.enviadoEm});

  factory PixDoTurno.fromJson(Map<String, dynamic> json) => PixDoTurno(
    enviado: json['status'] == 'enviado',
    enviadoEm: TurniDateTime.parse(json['enviado_em'] as String?),
  );
}

/// STORY-087 / ADR-019 (D2) — pendência de avaliação derivada do estado. Só chega em
/// turnos avaliáveis (`finalizado`/`finalizado_ajustado`); `pendente` diz se a direção
/// DESTE usuário ainda não foi avaliada (alimenta o CTA "Avaliar turno" e a tela de captura).
class AvaliacaoPendencia {
  final bool pendente;
  final String direcao;

  const AvaliacaoPendencia({required this.pendente, required this.direcao});

  factory AvaliacaoPendencia.fromJson(Map<String, dynamic> json) =>
      AvaliacaoPendencia(
        pendente: json['pendente'] as bool? ?? false,
        direcao: json['direcao'] as String? ?? '',
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

  /// Janela de geração do PIN — só chega para o PROFISSIONAL (STORY-061 CA-1).
  final CheckinJanela? checkinJanela;

  /// Snapshot de geofencing da geração do PIN — só chega para o CONTRATANTE em
  /// `aguardando_checkin` (STORY-062 CA-5: alimenta o card de aviso da validação).
  final GeofencingCheckin? geofencingCheckin;

  /// Status do Pix pós-turno — só chega para o PROFISSIONAL em `finalizado`
  /// (STORY-065 CA-4: linha do card de valor).
  final PixDoTurno? pix;

  /// Pendência de avaliação do usuário (STORY-087) — só em estados avaliáveis.
  final AvaliacaoPendencia? avaliacao;

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
    this.checkinJanela,
    this.geofencingCheckin,
    this.pix,
    this.avaliacao,
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
    checkinJanela: json['checkin_janela'] == null
        ? null
        : CheckinJanela.fromJson(
            json['checkin_janela'] as Map<String, dynamic>,
          ),
    geofencingCheckin: json['geofencing_check_in'] == null
        ? null
        : GeofencingCheckin.fromJson(
            json['geofencing_check_in'] as Map<String, dynamic>,
          ),
    pix: json['pix'] == null
        ? null
        : PixDoTurno.fromJson(json['pix'] as Map<String, dynamic>),
    avaliacao: json['avaliacao'] == null
        ? null
        : AvaliacaoPendencia.fromJson(
            json['avaliacao'] as Map<String, dynamic>,
          ),
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
