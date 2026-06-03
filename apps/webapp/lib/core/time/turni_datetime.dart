/// Política ÚNICA de data/hora do Turni (DDR-002: pt-BR, 24h, nunca AM/PM).
///
/// **Por que existe:** horário é crítico na plataforma (turno, prazo de revisão PDR-009, Pix em
/// 15 min). Antes desta peça, cada tela parseava/formatava/serializava à mão — e uma tela lia o
/// horário cru em UTC enquanto outra convertia para local, deslocando o turno em 3h. Aqui a
/// política vive num só lugar, puro e testável; as telas e serviços **delegam**, nunca improvisam.
///
/// **Contrato:**
/// - A API troca **instantes** em ISO-8601 **UTC** (a coluna é `timestamptz`, `app.timezone=UTC`).
/// - O usuário pensa em **horário de parede local** (o relógio do estabelecimento). Toda exibição
///   converte o instante para local; toda entrada do usuário é interpretada como local.
/// - Ida-e-volta é **lossless**: `parseEntrada(formatData(i), formatHora(i))` reproduz o mesmo
///   instante `i`. É essa invariância que impede uma edição "sem mexer no horário" de virar uma
///   alteração material fantasma (STORY-052).
///
/// **Fuso:** o produto é Brasil-only; usamos o fuso **local do dispositivo** (`toLocal()`) — a
/// mesma convenção já adotada por "Minhas vagas"/"Detalhe"/"Feed". Se um dia o horário precisar
/// ser fixado no fuso do estabelecimento (e não no do espectador), o único ponto a mudar é o
/// helper privado [_local] — daí o ganho de centralizar. Ver IDR-026.
abstract final class TurniDateTime {
  /// Abreviações pt-BR de Seg..Dom (alinhadas com `DateTime.weekday` 1..7).
  static const _diasSemana = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];

  static final _reData = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$');
  static final _reHora = RegExp(r'^(\d{1,2}):(\d{2})$');

  // ───────────────────────── Fronteira com a API ─────────────────────────

  /// Lê um ISO-8601 da API como **instante** (preserva o ponto no tempo, UTC/offset). `null` se
  /// ausente ou inválido — o chamador decide o fallback (não inventamos data).
  static DateTime? parse(String? iso) {
    if (iso == null || iso.isEmpty) return null;
    return DateTime.tryParse(iso);
  }

  /// Igual a [parse], mas exige valor — para contratos onde a data é garantida (lança em formato
  /// inválido, falha alto e cedo em vez de mascarar um bug de contrato).
  static DateTime parseRequired(String iso) => DateTime.parse(iso);

  /// Serializa um instante para a API: **sempre UTC** com sufixo `Z`. Aceita DateTime local ou
  /// UTC — converte para o mesmo instante em UTC. É o único jeito de mandar data ao back.
  static String toApi(DateTime instant) => instant.toUtc().toIso8601String();

  // ───────────────────────── Entrada do usuário ─────────────────────────

  /// `"dd/mm/aaaa"` + `"HH:mm"` (horário **local** que o usuário digitou/escolheu) → instante.
  /// `null` se qualquer parte for inválida (formato, faixa, ou data inexistente como 31/02).
  static DateTime? parseEntrada(String data, String hora) {
    final dm = _reData.firstMatch(data.trim());
    final hm = _reHora.firstMatch(hora.trim());
    if (dm == null || hm == null) return null;

    final dia = int.parse(dm.group(1)!);
    final mes = int.parse(dm.group(2)!);
    final ano = int.parse(dm.group(3)!);
    final h = int.parse(hm.group(1)!);
    final min = int.parse(hm.group(2)!);
    if (mes < 1 || mes > 12 || dia < 1 || dia > 31 || h > 23 || min > 59) {
      return null;
    }

    // DateTime local (fuso do dispositivo). Rejeita datas que "transbordam" (31/02 → 02/03).
    final dt = DateTime(ano, mes, dia, h, min);
    if (dt.month != mes || dt.day != dia) return null;
    return dt;
  }

  // ───────────────────────── Formatação (local, 24h) ─────────────────────────

  /// `"12/06/2026"`.
  static String formatData(DateTime instant) {
    final l = _local(instant);
    return '${_pad(l.day)}/${_pad(l.month)}/${l.year}';
  }

  /// `"12/06"`.
  static String formatDataCurta(DateTime instant) {
    final l = _local(instant);
    return '${_pad(l.day)}/${_pad(l.month)}';
  }

  /// `"18:00"` (24h).
  static String formatHora(DateTime instant) {
    final l = _local(instant);
    return '${_pad(l.hour)}:${_pad(l.minute)}';
  }

  /// `"18:00"` a partir dos componentes de um seletor de hora (TimeOfDay.hour/minute).
  static String formatHoraComponentes(int hora, int minuto) =>
      '${_pad(hora)}:${_pad(minuto)}';

  /// `"Qui"`.
  static String formatDiaSemana(DateTime instant) =>
      _diasSemana[_local(instant).weekday - 1];

  /// `"Qui, 12/06 · 18:00–23:00"` — usado no card/detalhe/feed.
  static String formatIntervalo(DateTime inicio, DateTime fim) {
    final i = _local(inicio);
    final f = _local(fim);
    return '${_diasSemana[i.weekday - 1]}, ${_pad(i.day)}/${_pad(i.month)} · '
        '${_pad(i.hour)}:${_pad(i.minute)}–${_pad(f.hour)}:${_pad(f.minute)}';
  }

  /// `"Qui, 12/06 · 18:00"` — resumo curto (diálogo de confirmação).
  static String formatResumo(DateTime inicio) {
    final i = _local(inicio);
    return '${_diasSemana[i.weekday - 1]}, ${_pad(i.day)}/${_pad(i.month)} · '
        '${_pad(i.hour)}:${_pad(i.minute)}';
  }

  /// `"12/06 18:00"` — data+hora compacta (linha de diff, conflito de horário).
  static String formatDataHoraCurta(DateTime instant) {
    final l = _local(instant);
    return '${_pad(l.day)}/${_pad(l.month)} ${_pad(l.hour)}:${_pad(l.minute)}';
  }

  /// `"Qui, 12/06 às 18:00"` — prazo do banner de revisão pós-edição (STORY-052).
  static String formatPrazo(DateTime instant) {
    final l = _local(instant);
    return '${_diasSemana[l.weekday - 1]}, ${_pad(l.day)}/${_pad(l.month)} '
        'às ${_pad(l.hour)}:${_pad(l.minute)}';
  }

  /// Duração do turno em texto preciso: `"5h"`, `"5h30"`, `"45min"`. `null` se `fim ≤ inicio`.
  /// (Comparar instantes — independe de fuso.)
  static String? formatDuracao(DateTime inicio, DateTime fim) {
    if (!fim.isAfter(inicio)) return null;
    final d = fim.difference(inicio);
    final h = d.inHours;
    final m = d.inMinutes % 60;
    if (h == 0) return '${m}min';
    if (m == 0) return '${h}h';
    return '${h}h${_pad(m)}';
  }

  // ───────────────────────── Comparação ─────────────────────────

  /// Dois instantes representam o mesmo ponto no tempo? (independe de fuso/representação)
  static bool mesmoInstante(DateTime a, DateTime b) => a.isAtSameMomentAs(b);

  // ───────────────────────── internos ─────────────────────────

  /// **Único** ponto que decide o fuso de exibição (ver doc da classe / IDR-026).
  static DateTime _local(DateTime d) => d.toLocal();

  static String _pad(int n) => n.toString().padLeft(2, '0');
}
