import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:turni_webapp/ds/theme.dart';
import 'package:turni_webapp/features/turnos/turno_detalhe_screen.dart';
import 'package:turni_webapp/features/turnos/turno_detalhe_service.dart';
import 'package:turni_webapp/features/turnos/turnos_service.dart'
    show TurnoEstadoResumo;

// STORY-065 (CA-4) — linha de status do Pix no card de valor (SCREEN-065 §A).
// Profissional em `finalizado`: "Pix a caminho…" → "Pix enviado em HH:MM" via
// polling SILENCIOSO (sem skeleton; morre quando o Pix confirma). Falha de Pix
// chega do servidor como a_caminho (§A.4 — o front nem sabe distinguir).

class _FakeService extends TurnoDetalheService {
  _FakeService(this.result);

  TurnoDetalheResult Function() result;
  int calls = 0;

  @override
  Future<TurnoDetalheResult> fetch(String id) async {
    calls++;
    return result();
  }
}

TurnoDetalhe _turno({
  String estadoRaw = 'finalizado',
  TurnoEstadoResumo estado = TurnoEstadoResumo.finalizado,
  PixDoTurno? pix,
  double? taxaTurni,
  double? totalContratante,
  String? profissional,
}) => TurnoDetalhe(
  id: 'u1',
  funcao: 'Garçom',
  dataInicio: DateTime(2026, 6, 12, 18),
  dataFim: DateTime(2026, 6, 12, 23),
  estado: estado,
  estadoRaw: estadoRaw,
  valor: 200.0,
  estabelecimento: 'Bar do Zé',
  taxaTurni: taxaTurni,
  totalContratante: totalContratante,
  profissional: profissional,
  aceite: null,
  timeline: const [],
  pix: pix,
);

Widget _comRouter(_FakeService svc) {
  final router = GoRouter(
    initialLocation: '/turnos/u1',
    routes: [
      GoRoute(
        path: '/turnos/:id',
        builder: (_, _) => TurnoDetalheScreen(turnoId: 'u1', service: svc),
      ),
      GoRoute(
        path: '/profissional/turnos',
        builder: (_, _) => const Scaffold(body: Text('LISTA PRO')),
      ),
      GoRoute(
        path: '/contratante/turnos',
        builder: (_, _) => const Scaffold(body: Text('LISTA CONTR')),
      ),
    ],
  );
  return MaterialApp.router(theme: buildLightTheme(), routerConfig: router);
}

void main() {
  // ───────────── (a) caminho feliz — os dois sub-estados ─────────────

  testWidgets('profissional finalizado: linha "Pix a caminho" no card de valor', (
    tester,
  ) async {
    final svc = _FakeService(
      () => TurnoDetalheSuccess(_turno(pix: const PixDoTurno(enviado: false))),
    );
    await tester.pumpWidget(_comRouter(svc));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('turno-detalhe-pix-acaminho')), findsOneWidget);
    expect(
      find.text('Pix a caminho — normalmente chega em até 15 min.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('turno-detalhe-pix-enviado')), findsNothing);
  });

  testWidgets('CA-4: "Pix enviado em HH:MM" quando o webhook confirmou (hoje)', (
    tester,
  ) async {
    final agora = DateTime.now();
    final enviadoEm = DateTime(agora.year, agora.month, agora.day, 18, 32);
    final svc = _FakeService(
      () => TurnoDetalheSuccess(
        _turno(pix: PixDoTurno(enviado: true, enviadoEm: enviadoEm)),
      ),
    );
    await tester.pumpWidget(_comRouter(svc));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('turno-detalhe-pix-enviado')), findsOneWidget);
    expect(find.text('Pix enviado em 18:32'), findsOneWidget);
    expect(find.byKey(const Key('turno-detalhe-pix-acaminho')), findsNothing);
  });

  // ───────────── (d) borda — data ≠ dia corrente ─────────────

  testWidgets('CA-4: Pix enviado em dia anterior mostra dd/MM · HH:MM', (
    tester,
  ) async {
    final ontem = DateTime.now().subtract(const Duration(days: 1));
    final enviadoEm = DateTime(ontem.year, ontem.month, ontem.day, 18, 32);
    final svc = _FakeService(
      () => TurnoDetalheSuccess(
        _turno(pix: PixDoTurno(enviado: true, enviadoEm: enviadoEm)),
      ),
    );
    await tester.pumpWidget(_comRouter(svc));
    await tester.pumpAndSettle();

    final dd = enviadoEm.day.toString().padLeft(2, '0');
    final mm = enviadoEm.month.toString().padLeft(2, '0');
    expect(find.text('Pix enviado em $dd/$mm · 18:32'), findsOneWidget);
  });

  // ───────────── (b) casos inválidos — papel/estado sem a linha ─────────────

  testWidgets(
    'contratante em finalizado NÃO tem linha de Pix (payload nem traz)',
    (tester) async {
      final svc = _FakeService(
        () => TurnoDetalheSuccess(
          _turno(
            taxaTurni: 30.0,
            totalContratante: 230.0,
            profissional: 'Júlia Santos',
          ),
        ),
      );
      await tester.pumpWidget(_comRouter(svc));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('turno-detalhe-pix-acaminho')), findsNothing);
      expect(find.byKey(const Key('turno-detalhe-pix-enviado')), findsNothing);
    },
  );

  testWidgets('turno não-finalizado NÃO tem linha de Pix', (tester) async {
    final svc = _FakeService(
      () => TurnoDetalheSuccess(
        _turno(estadoRaw: 'confirmado', estado: TurnoEstadoResumo.confirmado),
      ),
    );
    await tester.pumpWidget(_comRouter(svc));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('turno-detalhe-pix-acaminho')), findsNothing);
    expect(find.byKey(const Key('turno-detalhe-pix-enviado')), findsNothing);
  });

  // ───────────── (a/d) polling silencioso até o Pix confirmar ─────────────

  testWidgets(
    'polling silencioso: a_caminho vira "Pix enviado" sem refresh manual; depois morre',
    (tester) async {
      var enviado = false;
      final svc = _FakeService(
        () => TurnoDetalheSuccess(
          _turno(
            pix: enviado
                ? PixDoTurno(enviado: true, enviadoEm: DateTime.now())
                : const PixDoTurno(enviado: false),
          ),
        ),
      );
      await tester.pumpWidget(_comRouter(svc));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('turno-detalhe-pix-acaminho')),
        findsOneWidget,
      );

      // O webhook confirma no servidor; o próximo tick do polling troca a linha.
      enviado = true;
      await tester.pump(const Duration(seconds: 11));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('turno-detalhe-pix-enviado')),
        findsOneWidget,
      );

      // Pix entregue → polling morre (agora sim, estado terminal de verdade).
      final chamadasAposFlip = svc.calls;
      await tester.pump(const Duration(seconds: 30));
      expect(svc.calls, chamadasAposFlip);
    },
  );

  // ───────────── (c) exceção — falha de rede no tick não derruba a tela ─────────────

  testWidgets('tick do polling com erro de rede mantém a linha e tenta de novo', (
    tester,
  ) async {
    var falha = false;
    final svc = _FakeService(
      () => falha
          ? TurnoDetalheError()
          : TurnoDetalheSuccess(_turno(pix: const PixDoTurno(enviado: false))),
    );
    await tester.pumpWidget(_comRouter(svc));
    await tester.pumpAndSettle();

    falha = true;
    await tester.pump(const Duration(seconds: 11));
    await tester.pumpAndSettle();

    // Refresh silencioso falhou: a tela NÃO vira erro — segue mostrando a verdade anterior.
    expect(find.byKey(const Key('turno-detalhe-pix-acaminho')), findsOneWidget);

    // Próximo tick volta a tentar (polling vivo).
    final chamadas = svc.calls;
    await tester.pump(const Duration(seconds: 11));
    expect(svc.calls, greaterThan(chamadas));
  });

  testWidgets('polling do Pix NÃO roda fora do caso (não-finalizado)', (
    tester,
  ) async {
    final svc = _FakeService(
      () => TurnoDetalheSuccess(
        _turno(estadoRaw: 'confirmado', estado: TurnoEstadoResumo.confirmado),
      ),
    );
    await tester.pumpWidget(_comRouter(svc));
    await tester.pumpAndSettle();

    final chamadasIniciais = svc.calls;
    await tester.pump(const Duration(seconds: 30));
    expect(svc.calls, chamadasIniciais);
  });
}
