/// STORY-057 / ADR-017 (decisão a). Núcleo PURO do cronômetro bilateral.
///
/// O servidor é a ÚNICA fonte de verdade do tempo decorrido (CA-4). O cliente NÃO conta o tempo
/// por conta própria: ele recebe a âncora (`iniciadoEm`, carimbada na transição `→ ativo`) e a hora
/// do servidor (`servidorAgora`), calcula um OFFSET contra o próprio relógio e, a partir daí, tica
/// LOCALMENTE — sem rede por tique. O polling curto (~5s) só re-sincroniza este objeto.
///
/// É isso que garante a sincronia ≤ 2s entre os dois lados POR CONSTRUÇÃO: profissional e
/// contratante ancoram no MESMO `iniciadoEm` e cada um cancela o próprio skew de relógio via
/// `offset`. A diferença residual entre os dois é só a latência de rede da sincronização (sub-segundo),
/// nunca o desvio acumulado de dois relógios soltos.
///
/// Classe pura (sem Flutter, sem rede, sem `DateTime.now()` interno) — testável isoladamente.
class CronometroAncora {
  const CronometroAncora({
    required this.iniciadoEm,
    required this.encerradoEm,
    required this.offset,
  });

  /// Instante de início em UTC (`check_in_at`). `null` antes do check-in validado.
  final DateTime? iniciadoEm;

  /// Instante de encerramento em UTC (`check_out_at`). `null` enquanto o turno está `ativo`.
  final DateTime? encerradoEm;

  /// `agoraCliente − servidorAgora` no momento da sincronização. Cancela o skew do relógio local:
  /// `horaServidorEstimada = agoraCliente − offset`.
  final Duration offset;

  /// Antes de qualquer sincronização: âncora vazia (cronômetro zerado, parado).
  static const CronometroAncora vazio = CronometroAncora(
    iniciadoEm: null,
    encerradoEm: null,
    offset: Duration.zero,
  );

  /// Sincroniza com a resposta de `GET /turnos/{id}/cronometro`. [agoraCliente] é o relógio local
  /// no instante do recebimento (injetável para teste). Os instantes da API são ISO-8601 UTC (IDR-026).
  factory CronometroAncora.sincronizar({
    required DateTime? iniciadoEm,
    required DateTime? encerradoEm,
    required DateTime servidorAgora,
    required DateTime agoraCliente,
  }) {
    return CronometroAncora(
      iniciadoEm: iniciadoEm?.toUtc(),
      encerradoEm: encerradoEm?.toUtc(),
      offset: agoraCliente.difference(servidorAgora),
    );
  }

  /// Cronômetro em andamento (tem início e ainda não encerrou).
  bool get rodando => iniciadoEm != null && encerradoEm == null;

  /// Tempo decorrido a exibir, dado o relógio local atual [agoraCliente].
  ///
  /// - Sem âncora (antes do check-in) → `Duration.zero`.
  /// - Encerrado → congela em `encerradoEm − iniciadoEm` (independe do relógio local).
  /// - Rodando → `(horaServidorEstimada) − iniciadoEm`, onde `horaServidorEstimada = agoraCliente − offset`.
  ///
  /// Nunca negativo (clamp em zero) — protege de skew/latência que coloque o "agora" antes do início.
  Duration decorrido(DateTime agoraCliente) {
    final inicio = iniciadoEm;
    if (inicio == null) return Duration.zero;

    final fim = encerradoEm ?? agoraCliente.toUtc().subtract(offset);
    final d = fim.difference(inicio);
    return d.isNegative ? Duration.zero : d;
  }

  /// `HH:MM:SS` para o display do cronômetro (a ticar a cada segundo). Horas não saturam em 24h —
  /// um turno longo mostra `26:10:05` se preciso.
  ///
  /// STORY-063 (CA-2): [curto] usa `MM:SS` para turnos de duração prevista < 1h — mas **promove**
  /// para `HH:MM:SS` quando o decorrido cruza 1h e não regride (nunca exibir "75:30").
  static String formatar(Duration d, {bool curto = false}) {
    String dois(int n) => n.toString().padLeft(2, '0');
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    if (curto && h == 0) return '${dois(m)}:${dois(s)}';
    return '${dois(h)}:${dois(m)}:${dois(s)}';
  }

  /// Placeholder do display antes da primeira sincronização (mesma silhueta do formato final).
  static String placeholder({bool curto = false}) =>
      curto ? '--:--' : '--:--:--';
}
