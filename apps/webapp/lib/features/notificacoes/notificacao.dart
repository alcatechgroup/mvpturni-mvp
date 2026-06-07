import 'package:flutter/material.dart';

/// STORY-053 (CA-8) — tipo de notificação. Espelha o enum nativo do backend; o título/resumo
/// in-app reusam o texto-seed dos e-mails (SCREEN-STORY-053 §5) interpolando o `payload`.
/// STORY-067 acrescenta os 8 tipos do ciclo do turno (SCREEN-STORY-067 §2).
enum NotificacaoTipo {
  candidaturaRecebida('candidatura_recebida'),
  vagaEditadaMaterial('vaga_editada_material'),
  vagaCancelada('vaga_cancelada'),
  candidaturaMantida('vaga_editada_material_candidatura_mantida'),
  candidaturaRetirada('vaga_editada_material_candidatura_retirada'),
  // STORY-067 — eventos do turno.
  turnoConfirmado('turno_confirmado'),
  checkinSolicitado('checkin_solicitado'),
  turnoAtivo('turno_ativo'),
  checkoutSolicitado('checkout_solicitado'),
  turnoFinalizado('turno_finalizado'),
  pixEnviado('pix_enviado'),
  turnoCancelado('turno_cancelado'),
  noShowPro('no_show_pro'),
  desconhecido('');

  const NotificacaoTipo(this.apiValue);
  final String apiValue;

  static NotificacaoTipo fromApi(String? v) =>
      values.firstWhere((e) => e.apiValue == v, orElse: () => desconhecido);

  /// Ícone do tipo (círculo neutro no item — SCREEN-053 §3; SCREEN-067 §2).
  IconData get icone => switch (this) {
    candidaturaRecebida => Icons.person_add_alt_1_outlined,
    vagaEditadaMaterial => Icons.edit_outlined,
    vagaCancelada => Icons.event_busy_outlined,
    candidaturaMantida => Icons.check_circle_outline,
    candidaturaRetirada => Icons.person_remove_alt_1_outlined,
    turnoConfirmado => Icons.event_available,
    checkinSolicitado => Icons.login,
    turnoAtivo => Icons.play_circle_outline,
    checkoutSolicitado => Icons.logout,
    turnoFinalizado => Icons.task_alt,
    pixEnviado => Icons.pix,
    turnoCancelado => Icons.event_busy_outlined,
    noShowPro => Icons.person_off_outlined,
    desconhecido => Icons.notifications_outlined,
  };
}

/// Uma notificação da caixa in-app (GET /api/notificacoes — CA-7).
class Notificacao {
  final String id;
  final NotificacaoTipo tipo;
  final String? vagaId;
  final String? candidaturaId;
  final Map<String, dynamic> payload;
  DateTime? lidaEm;
  final DateTime? criadaEm;

  Notificacao({
    required this.id,
    required this.tipo,
    required this.vagaId,
    required this.candidaturaId,
    required this.payload,
    required this.lidaEm,
    required this.criadaEm,
  });

  bool get lida => lidaEm != null;

  factory Notificacao.fromJson(Map<String, dynamic> json) => Notificacao(
    id: json['id'] as String,
    tipo: NotificacaoTipo.fromApi(json['tipo'] as String?),
    vagaId: json['vaga_id'] as String?,
    candidaturaId: json['candidatura_id'] as String?,
    payload: (json['payload'] as Map?)?.cast<String, dynamic>() ?? const {},
    lidaEm: json['lida_em'] != null
        ? DateTime.tryParse(json['lida_em'] as String)
        : null,
    criadaEm: json['criada_em'] != null
        ? DateTime.tryParse(json['criada_em'] as String)
        : null,
  );

  String _p(String k) => (payload[k] ?? '').toString();

  /// Título curto (SCREEN-053 §5; SCREEN-067 §2 — título = h1 do e-mail).
  String get titulo => switch (tipo) {
    NotificacaoTipo.candidaturaRecebida => 'Nova candidatura recebida',
    NotificacaoTipo.vagaEditadaMaterial => 'Vaga alterada — confirme',
    NotificacaoTipo.vagaCancelada => 'Vaga cancelada pelo contratante',
    NotificacaoTipo.candidaturaMantida => 'Candidato mantido após edição',
    NotificacaoTipo.candidaturaRetirada => 'Candidato saiu da vaga após edição',
    NotificacaoTipo.turnoConfirmado => 'Turno confirmado',
    NotificacaoTipo.checkinSolicitado => 'Check-in aguardando validação',
    NotificacaoTipo.turnoAtivo => 'Turno em andamento',
    NotificacaoTipo.checkoutSolicitado => 'Check-out aguardando validação',
    NotificacaoTipo.turnoFinalizado => 'Turno finalizado',
    NotificacaoTipo.pixEnviado => 'Pix enviado',
    NotificacaoTipo.turnoCancelado => 'Turno cancelado',
    NotificacaoTipo.noShowPro => 'Turno encerrado — check-in não realizado',
    NotificacaoTipo.desconhecido => 'Notificação',
  };

  /// Resumo de até 2 linhas, interpolando o payload (SCREEN-053 §5; SCREEN-067 §2 —
  /// resumo = 1ª linha do 1º parágrafo do e-mail).
  String get resumo => switch (tipo) {
    NotificacaoTipo.candidaturaRecebida =>
      '${_p('profissional_nome')} se candidatou à sua vaga de ${_p('vaga_funcao')}.',
    NotificacaoTipo.vagaEditadaMaterial =>
      'A vaga de ${_p('vaga_funcao')} mudou. Confirme se ainda quer participar.',
    NotificacaoTipo.vagaCancelada =>
      'A vaga de ${_p('vaga_funcao')} marcada para ${_p('vaga_data_inicio')} foi cancelada.',
    NotificacaoTipo.candidaturaMantida =>
      '${_p('profissional_nome')} confirmou continuar na sua vaga de ${_p('vaga_funcao')}.',
    NotificacaoTipo.candidaturaRetirada =>
      '${_p('profissional_nome')} não confirmou as mudanças na vaga de ${_p('vaga_funcao')}.',
    NotificacaoTipo.turnoConfirmado =>
      'Seu turno de ${_p('vaga_funcao')} no ${_p('estabelecimento_nome')} em ${_p('turno_data_inicio')} está confirmado.',
    NotificacaoTipo.checkinSolicitado =>
      '${_p('profissional_nome')} gerou o PIN de check-in do turno de ${_p('vaga_funcao')}. Valide para iniciar.',
    NotificacaoTipo.turnoAtivo =>
      'Check-in validado. Seu turno de ${_p('vaga_funcao')} está em andamento.',
    NotificacaoTipo.checkoutSolicitado =>
      '${_p('profissional_nome')} gerou o PIN de check-out do turno de ${_p('vaga_funcao')}. Valide para encerrar.',
    NotificacaoTipo.turnoFinalizado =>
      'Turno de ${_p('vaga_funcao')} encerrado. O pagamento de R\$ ${_p('valor')} está em processamento.',
    NotificacaoTipo.pixEnviado =>
      'O Pix de R\$ ${_p('valor')} do turno de ${_p('vaga_funcao')} foi enviado.',
    NotificacaoTipo.turnoCancelado =>
      'O turno de ${_p('vaga_funcao')} de ${_p('turno_data_inicio')} foi cancelado ${_p('cancelado_por')}.',
    NotificacaoTipo.noShowPro =>
      'O turno de ${_p('vaga_funcao')} de ${_p('turno_data_inicio')} foi encerrado: o check-in não aconteceu no prazo.',
    NotificacaoTipo.desconhecido => '',
  };

  /// Rota interna de destino ao tocar (SCREEN-053 §2; SCREEN-067 §2 — turno: destino
  /// único `/turnos/{id}`, o `turno_id` vem do payload). `null` se faltar o id.
  String? get rotaDestino {
    final turnoId = payload['turno_id'] as String?;
    if (_tipoDeTurno) {
      return turnoId == null ? null : '/turnos/$turnoId';
    }
    final v = vagaId;
    if (v == null) {
      return tipo == NotificacaoTipo.vagaCancelada ? '/feed' : null;
    }
    return switch (tipo) {
      NotificacaoTipo.candidaturaRecebida ||
      NotificacaoTipo.candidaturaMantida ||
      NotificacaoTipo.candidaturaRetirada => '/contratante/vagas/$v/candidatos',
      NotificacaoTipo.vagaEditadaMaterial => '/vaga/$v',
      NotificacaoTipo.vagaCancelada => '/feed',
      _ => null,
    };
  }

  bool get _tipoDeTurno => switch (tipo) {
    NotificacaoTipo.turnoConfirmado ||
    NotificacaoTipo.checkinSolicitado ||
    NotificacaoTipo.turnoAtivo ||
    NotificacaoTipo.checkoutSolicitado ||
    NotificacaoTipo.turnoFinalizado ||
    NotificacaoTipo.pixEnviado ||
    NotificacaoTipo.turnoCancelado ||
    NotificacaoTipo.noShowPro => true,
    _ => false,
  };

  /// Tempo relativo pt-BR 24h (SCREEN-053 §5; DDR-002 — nunca AM/PM).
  String tempoRelativo([DateTime? agora]) {
    final c = criadaEm;
    if (c == null) return '';
    final n = agora ?? DateTime.now();
    final diff = n.difference(c);
    if (diff.inMinutes < 1) return 'agora';
    if (diff.inMinutes < 60) return 'há ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'há ${diff.inHours} h';
    final l = c.toLocal();
    final hh = l.hour.toString().padLeft(2, '0');
    final mm = l.minute.toString().padLeft(2, '0');
    if (diff.inHours < 48) return 'ontem · $hh:$mm';
    final dd = l.day.toString().padLeft(2, '0');
    final mo = l.month.toString().padLeft(2, '0');
    return '$dd/$mo · $hh:$mm';
  }
}
