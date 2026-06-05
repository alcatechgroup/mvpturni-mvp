/// STORY-061 / SCREEN-061 §4.5/§4.10 — microcopy compartilhada do geofencing
/// (nota na tela do PIN + descrição do evento na timeline). Um lugar só: a tela
/// do PIN e o detalhe não podem divergir na forma de falar de distância/razão.
library;

import 'turno_detalhe_service.dart' show GeofencingCheckin;

/// `< 1000` → "230 m"; `≥ 1000` → "1,2 km" (pt-BR, vírgula decimal).
String formatDistanciaMetros(double metros) {
  if (metros < 1000) return '${metros.round()} m';
  final km = metros / 1000;
  final txt = km.toStringAsFixed(1).replaceFirst('.', ',');
  return '$txt km';
}

/// Razões da captura em linguagem humana (conjunto da STORY-057).
String razaoHumana(String? razao) => switch (razao) {
  'permissao_negada' => 'permissão negada',
  'timeout' => 'tempo esgotado',
  _ => 'indisponível',
};

/// Descrição do evento `checkin_solicitado` na timeline (SCREEN-061 §4.10).
/// `null` quando o evento não tem snapshot (seed antigo) — título fica sozinho.
String? descricaoTimelineGeofencing(GeofencingCheckin? geo) {
  if (geo == null) return null;
  if (geo.ok && geo.distanciaMetros != null) {
    return 'Localização confirmada (a ${formatDistanciaMetros(geo.distanciaMetros!)} do estabelecimento).';
  }
  if (geo.distanciaMetros != null) {
    return 'Fora do raio do estabelecimento (a ${formatDistanciaMetros(geo.distanciaMetros!)}).';
  }
  return 'Localização não capturada (${razaoHumana(geo.razao)}).';
}
