import 'package:flutter/material.dart';

/// STORY-053 (CA-8) — tipo de notificação. Espelha o enum nativo do backend; o título/resumo
/// in-app reusam o texto-seed dos e-mails (SCREEN-STORY-053 §5) interpolando o `payload`.
enum NotificacaoTipo {
  candidaturaRecebida('candidatura_recebida'),
  vagaEditadaMaterial('vaga_editada_material'),
  vagaCancelada('vaga_cancelada'),
  candidaturaMantida('vaga_editada_material_candidatura_mantida'),
  candidaturaRetirada('vaga_editada_material_candidatura_retirada'),
  desconhecido('');

  const NotificacaoTipo(this.apiValue);
  final String apiValue;

  static NotificacaoTipo fromApi(String? v) =>
      values.firstWhere((e) => e.apiValue == v, orElse: () => desconhecido);

  /// Ícone do tipo (círculo neutro no item — SCREEN-053 §3).
  IconData get icone => switch (this) {
    candidaturaRecebida => Icons.person_add_alt_1_outlined,
    vagaEditadaMaterial => Icons.edit_outlined,
    vagaCancelada => Icons.event_busy_outlined,
    candidaturaMantida => Icons.check_circle_outline,
    candidaturaRetirada => Icons.person_remove_alt_1_outlined,
    desconhecido => Icons.notifications_outlined,
  };
}

/// Uma notificação da caixa in-app (GET /api/notificacoes — CA-7).
class Notificacao {
  final int id;
  final NotificacaoTipo tipo;
  final int? vagaId;
  final int? candidaturaId;
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
    id: (json['id'] as num?)?.toInt() ?? 0,
    tipo: NotificacaoTipo.fromApi(json['tipo'] as String?),
    vagaId: (json['vaga_id'] as num?)?.toInt(),
    candidaturaId: (json['candidatura_id'] as num?)?.toInt(),
    payload: (json['payload'] as Map?)?.cast<String, dynamic>() ?? const {},
    lidaEm: json['lida_em'] != null
        ? DateTime.tryParse(json['lida_em'] as String)
        : null,
    criadaEm: json['criada_em'] != null
        ? DateTime.tryParse(json['criada_em'] as String)
        : null,
  );

  String _p(String k) => (payload[k] ?? '').toString();

  /// Título curto (SCREEN-053 §5).
  String get titulo => switch (tipo) {
    NotificacaoTipo.candidaturaRecebida => 'Nova candidatura recebida',
    NotificacaoTipo.vagaEditadaMaterial => 'Vaga alterada — confirme',
    NotificacaoTipo.vagaCancelada => 'Vaga cancelada pelo contratante',
    NotificacaoTipo.candidaturaMantida => 'Candidato mantido após edição',
    NotificacaoTipo.candidaturaRetirada => 'Candidato saiu da vaga após edição',
    NotificacaoTipo.desconhecido => 'Notificação',
  };

  /// Resumo de até 2 linhas, interpolando o payload (SCREEN-053 §5).
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
    NotificacaoTipo.desconhecido => '',
  };

  /// Rota interna de destino ao tocar (SCREEN-053 §2). `null` se faltar vaga_id.
  String? get rotaDestino {
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
      NotificacaoTipo.desconhecido => null,
    };
  }

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
