import 'package:flutter_test/flutter_test.dart';
import 'package:turni_webapp/core/time/turni_datetime.dart';

// Política única de data/hora (DDR-002). Testes puros, independentes do fuso da máquina:
// onde o fuso importa, exercitamos INVARIâNCIAS (round-trip, mesmo-instante), não horas fixas.

void main() {
  group('fronteira com a API', () {
    test('parse lê ISO UTC como instante; null para vazio/ inválido', () {
      final i = TurniDateTime.parse('2026-06-12T18:00:00Z')!;
      expect(i.toUtc().hour, 18);
      expect(i.toUtc().day, 12);
      expect(TurniDateTime.parse(null), isNull);
      expect(TurniDateTime.parse(''), isNull);
      expect(TurniDateTime.parse('não-é-data'), isNull);
    });

    test('parse preserva o instante de uma string com offset', () {
      // 18:00-03:00 == 21:00Z
      final i = TurniDateTime.parse('2026-06-12T18:00:00-03:00')!;
      expect(i.toUtc().hour, 21);
    });

    test('toApi serializa SEMPRE em UTC com sufixo Z (de local ou de UTC)', () {
      expect(
        TurniDateTime.toApi(DateTime.utc(2026, 6, 12, 18)),
        '2026-06-12T18:00:00.000Z',
      );
      final api = TurniDateTime.toApi(DateTime(2026, 6, 12, 18));
      expect(api, endsWith('Z'));
      // mesmo instante de volta
      expect(
        TurniDateTime.parse(api)!.isAtSameMomentAs(DateTime(2026, 6, 12, 18)),
        isTrue,
      );
    });

    test('round-trip API: parse(toApi(x)) == x (mesmo instante)', () {
      for (final x in [
        DateTime.utc(2026, 1, 1, 0, 0),
        DateTime.utc(2026, 12, 31, 23, 59),
        DateTime(2026, 6, 12, 18, 30),
      ]) {
        expect(
          TurniDateTime.parse(TurniDateTime.toApi(x))!.isAtSameMomentAs(x),
          isTrue,
        );
      }
    });

    test('parseRequired lança em formato inválido (falha cedo)', () {
      expect(() => TurniDateTime.parseRequired('xx'), throwsFormatException);
    });
  });

  group('entrada do usuário', () {
    test(
      'parseEntrada válida → DateTime local com a hora de parede digitada',
      () {
        final dt = TurniDateTime.parseEntrada('12/06/2026', '18:30')!;
        expect(dt.year, 2026);
        expect(dt.month, 6);
        expect(dt.day, 12);
        expect(dt.hour, 18);
        expect(dt.minute, 30);
        expect(dt.isUtc, isFalse); // horário local (de parede)
      },
    );

    test('parseEntrada rejeita formato, faixa e data inexistente', () {
      expect(
        TurniDateTime.parseEntrada('12-06-2026', '18:00'),
        isNull,
      ); // separador
      expect(
        TurniDateTime.parseEntrada('12/06/2026', '25:00'),
        isNull,
      ); // hora > 23
      expect(
        TurniDateTime.parseEntrada('12/06/2026', '18:99'),
        isNull,
      ); // min > 59
      expect(
        TurniDateTime.parseEntrada('00/13/2026', '18:00'),
        isNull,
      ); // mês/dia
      expect(
        TurniDateTime.parseEntrada('31/02/2026', '18:00'),
        isNull,
      ); // overflow 31/02
      expect(TurniDateTime.parseEntrada('', ''), isNull);
    });
  });

  group('formatação (local, 24h, pt-BR)', () {
    // Entradas LOCAIS → toLocal é identidade → saída determinística em qualquer máquina.
    final inicio = DateTime(2026, 6, 12, 18, 0); // sexta-feira
    final fim = DateTime(2026, 6, 12, 23, 5);

    test('formatData / formatDataCurta / formatHora', () {
      expect(TurniDateTime.formatData(inicio), '12/06/2026');
      expect(TurniDateTime.formatDataCurta(inicio), '12/06');
      expect(TurniDateTime.formatHora(inicio), '18:00');
      expect(TurniDateTime.formatHora(fim), '23:05');
    });

    test('formatHoraComponentes (seletor de hora)', () {
      expect(TurniDateTime.formatHoraComponentes(9, 5), '09:05');
      expect(TurniDateTime.formatHoraComponentes(18, 0), '18:00');
    });

    test('formatDiaSemana abrevia pt-BR', () {
      expect(TurniDateTime.formatDiaSemana(DateTime(2026, 6, 12)), 'Sex');
      expect(TurniDateTime.formatDiaSemana(DateTime(2026, 6, 14)), 'Dom');
      expect(TurniDateTime.formatDiaSemana(DateTime(2026, 6, 8)), 'Seg');
    });

    test('formatIntervalo e formatResumo (card/detalhe/diálogo)', () {
      expect(
        TurniDateTime.formatIntervalo(inicio, fim),
        'Sex, 12/06 · 18:00–23:05',
      );
      expect(TurniDateTime.formatResumo(inicio), 'Sex, 12/06 · 18:00');
    });

    test(
      'formatEvento: timestamp de timeline; ano explícito quando ≠ corrente',
      () {
        final agora = DateTime(2026, 6, 5, 10);
        expect(
          TurniDateTime.formatEvento(
            DateTime(2026, 6, 3, 15, 47),
            agora: agora,
          ),
          'Qua, 03/06 · 15:47',
        );
        expect(
          TurniDateTime.formatEvento(
            DateTime(2025, 12, 31, 23, 59),
            agora: agora,
          ),
          'Qua, 31/12/2025 · 23:59',
        );
      },
    );

    test('formatDataHoraCurta e formatPrazo (diff/banner de revisão)', () {
      expect(TurniDateTime.formatDataHoraCurta(inicio), '12/06 18:00');
      expect(TurniDateTime.formatPrazo(inicio), 'Sex, 12/06 às 18:00');
    });

    test('formatDuracao: 5h, 5h05, 45min, e null quando fim ≤ início', () {
      expect(
        TurniDateTime.formatDuracao(inicio, DateTime(2026, 6, 12, 23, 0)),
        '5h',
      );
      expect(
        TurniDateTime.formatDuracao(inicio, DateTime(2026, 6, 12, 23, 5)),
        '5h05',
      );
      expect(
        TurniDateTime.formatDuracao(inicio, DateTime(2026, 6, 12, 18, 45)),
        '45min',
      );
      expect(TurniDateTime.formatDuracao(inicio, inicio), isNull);
      expect(
        TurniDateTime.formatDuracao(inicio, DateTime(2026, 6, 12, 17, 0)),
        isNull,
      );
    });
  });

  group(
    'INVARIÂNCIA crítica — exibir e reler é lossless (regressão tz STORY-052)',
    () {
      test(
        'parseEntrada(formatData(i), formatHora(i)) == i, para instante em UTC',
        () {
          // O instante vem da API em UTC; a tela exibe local e relê — NÃO pode deslocar.
          for (final i in [
            DateTime.utc(2026, 6, 12, 18, 0),
            DateTime.utc(2026, 1, 1, 3, 30),
            DateTime.utc(2026, 12, 31, 23, 59),
          ]) {
            final reparsed = TurniDateTime.parseEntrada(
              TurniDateTime.formatData(i),
              TurniDateTime.formatHora(i),
            )!;
            expect(
              TurniDateTime.mesmoInstante(reparsed, i),
              isTrue,
              reason: 'exibir→reler deslocou o instante $i',
            );
          }
        },
      );

      test(
        'e toApi do reparse bate com toApi do original (mesma string UTC)',
        () {
          final i = DateTime.utc(2026, 6, 12, 18, 0);
          final reparsed = TurniDateTime.parseEntrada(
            TurniDateTime.formatData(i),
            TurniDateTime.formatHora(i),
          )!;
          expect(TurniDateTime.toApi(reparsed), TurniDateTime.toApi(i));
        },
      );
    },
  );

  group('mesmoInstante', () {
    test('compara o ponto no tempo, não a representação', () {
      expect(
        TurniDateTime.mesmoInstante(
          TurniDateTime.parse('2026-06-12T18:00:00Z')!,
          TurniDateTime.parse('2026-06-12T15:00:00-03:00')!,
        ),
        isTrue,
      );
      expect(
        TurniDateTime.mesmoInstante(
          DateTime.utc(2026, 6, 12, 18),
          DateTime.utc(2026, 6, 12, 19),
        ),
        isFalse,
      );
    });
  });
}
