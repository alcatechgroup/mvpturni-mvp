// STORY-057 / ADR-017 (decisão a) — núcleo do cronômetro bilateral. Prova o mecanismo de forma
// determinística: âncora comum + cancelamento de skew → sincronia estrutural ≤ 2s entre os dois lados.

import 'package:flutter_test/flutter_test.dart';
import 'package:turni_webapp/features/turno/cronometro_ancora.dart';

void main() {
  group('CronometroAncora — âncora + offset', () {
    test('sem âncora (antes do check-in) → decorrido zero e parado', () {
      const a = CronometroAncora.vazio;

      expect(a.rodando, isFalse);
      expect(a.decorrido(DateTime.now()), Duration.zero);
    });

    test(
      'rodando: decorrido ≈ tempo desde iniciadoEm (relógios alinhados)',
      () {
        final servidorAgora = DateTime.utc(2026, 6, 4, 12, 0, 0);
        final iniciadoEm = servidorAgora.subtract(
          const Duration(hours: 1, minutes: 30),
        );
        // Cliente com relógio igual ao do servidor no momento da sincronização.
        final a = CronometroAncora.sincronizar(
          iniciadoEm: iniciadoEm,
          encerradoEm: null,
          servidorAgora: servidorAgora,
          agoraCliente: servidorAgora,
        );

        expect(a.rodando, isTrue);
        // 1 segundo depois no relógio do cliente.
        final d = a.decorrido(servidorAgora.add(const Duration(seconds: 1)));
        expect(d.inSeconds, 1 * 3600 + 30 * 60 + 1);
      },
    );

    test(
      'cancela o skew do cliente: relógio +10s adiantado mostra o mesmo decorrido',
      () {
        final servidorAgora = DateTime.utc(2026, 6, 4, 12, 0, 0);
        final iniciadoEm = servidorAgora.subtract(const Duration(minutes: 20));

        // Cliente cujo relógio local está 10s à frente do servidor.
        final skew = const Duration(seconds: 10);
        final clienteNoSync = servidorAgora.add(skew);
        final a = CronometroAncora.sincronizar(
          iniciadoEm: iniciadoEm,
          encerradoEm: null,
          servidorAgora: servidorAgora,
          agoraCliente: clienteNoSync,
        );

        // Um tique depois (relógio do cliente, ainda +10s adiantado).
        final d = a.decorrido(clienteNoSync.add(const Duration(seconds: 1)));
        // Deve ser 20min + 1s — o skew de 10s foi cancelado pelo offset.
        expect(d.inSeconds, 20 * 60 + 1);
      },
    );

    test('SINCRONIA BILATERAL: dois lados com skews opostos ficam < 2s entre si', () {
      final servidorAgora = DateTime.utc(2026, 6, 4, 12, 0, 0);
      final iniciadoEm = servidorAgora.subtract(const Duration(hours: 2));

      // Profissional: relógio 30s adiantado. Contratante: 45s atrasado. (73s de diferença bruta.)
      final pro = CronometroAncora.sincronizar(
        iniciadoEm: iniciadoEm,
        encerradoEm: null,
        servidorAgora: servidorAgora,
        agoraCliente: servidorAgora.add(const Duration(seconds: 30)),
      );
      final emp = CronometroAncora.sincronizar(
        iniciadoEm: iniciadoEm,
        encerradoEm: null,
        servidorAgora: servidorAgora,
        agoraCliente: servidorAgora.subtract(const Duration(seconds: 45)),
      );

      // Num MESMO instante de tempo real (digamos +3s após o sync), cada um lê com seu relógio.
      final instanteReal = servidorAgora.add(const Duration(seconds: 3));
      final dPro = pro.decorrido(instanteReal.add(const Duration(seconds: 30)));
      final dEmp = emp.decorrido(
        instanteReal.subtract(const Duration(seconds: 45)),
      );

      final difanca = (dPro - dEmp).abs();
      expect(
        difanca.inSeconds,
        lessThanOrEqualTo(2),
        reason:
            'âncora comum + offset → diferença residual sub-segundo, nunca o skew de 73s',
      );
    });

    test(
      'encerrado: congela em encerradoEm − iniciadoEm, independe do relógio local',
      () {
        final servidorAgora = DateTime.utc(2026, 6, 4, 18, 0, 0);
        final iniciadoEm = DateTime.utc(2026, 6, 4, 12, 0, 0);
        final encerradoEm = DateTime.utc(
          2026,
          6,
          4,
          17,
          30,
          0,
        ); // 5h30 de turno

        final a = CronometroAncora.sincronizar(
          iniciadoEm: iniciadoEm,
          encerradoEm: encerradoEm,
          servidorAgora: servidorAgora,
          agoraCliente: servidorAgora,
        );

        expect(a.rodando, isFalse);
        // Mesmo "avançando" o relógio do cliente em 1 dia, o decorrido fica congelado.
        final d = a.decorrido(servidorAgora.add(const Duration(days: 1)));
        expect(d, const Duration(hours: 5, minutes: 30));
      },
    );

    test('nunca negativo: âncora no futuro (skew patológico) → zero', () {
      final servidorAgora = DateTime.utc(2026, 6, 4, 12, 0, 0);
      final iniciadoEm = servidorAgora.add(
        const Duration(minutes: 5),
      ); // início "no futuro"

      final a = CronometroAncora.sincronizar(
        iniciadoEm: iniciadoEm,
        encerradoEm: null,
        servidorAgora: servidorAgora,
        agoraCliente: servidorAgora,
      );

      expect(a.decorrido(servidorAgora), Duration.zero);
    });

    test(
      'parse de instante ISO UTC vindo da API preserva o ponto no tempo',
      () {
        final a = CronometroAncora.sincronizar(
          iniciadoEm: DateTime.parse('2026-06-04T12:00:00Z'),
          encerradoEm: null,
          servidorAgora: DateTime.parse('2026-06-04T13:00:00Z'),
          agoraCliente: DateTime.parse('2026-06-04T13:00:00Z'),
        );

        expect(
          a.decorrido(DateTime.parse('2026-06-04T13:00:00Z')),
          const Duration(hours: 1),
        );
      },
    );
  });

  group('CronometroAncora.formatar', () {
    test('HH:MM:SS com zero à esquerda', () {
      expect(CronometroAncora.formatar(const Duration(seconds: 5)), '00:00:05');
      expect(
        CronometroAncora.formatar(const Duration(minutes: 3, seconds: 9)),
        '00:03:09',
      );
      expect(
        CronometroAncora.formatar(
          const Duration(hours: 1, minutes: 2, seconds: 3),
        ),
        '01:02:03',
      );
    });

    test('horas não saturam em 24h', () {
      expect(
        CronometroAncora.formatar(
          const Duration(hours: 26, minutes: 10, seconds: 5),
        ),
        '26:10:05',
      );
    });
  });
}
