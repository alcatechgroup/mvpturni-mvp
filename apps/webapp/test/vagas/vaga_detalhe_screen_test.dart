import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:turni_webapp/ds/theme.dart';
import 'package:turni_webapp/features/vagas/vaga_detalhe_screen.dart';
import 'package:turni_webapp/features/vagas/vaga_detalhe_service.dart';

// STORY-049 — widget tests da VagaDetalheScreen (SCREEN-049).
// CA-2 (cabeçalho + 4 linhas de breakdown), CA-3 (estados ok/partial/miss → ícone/cor),
// CA-4 (total agregado), CA-5 (CTA + gate + motivo), CA-6 (já candidatou + retirar),
// CA-7 (sem permissão), §4.7 (indisponível), estados loading/erro, distância opcional.

class _FakeService extends VagaDetalheService {
  _FakeService({this.result, this.delay});

  DetalheResult Function()? result;
  final Duration? delay;
  int calls = 0;

  @override
  Future<DetalheResult> fetch(String id) async {
    calls++;
    if (delay != null) await Future<void>.delayed(delay!);
    return result?.call() ?? DetalheError();
  }
}

BreakdownLinha _linha(
  ComponenteMatch c,
  int pontos,
  int max,
  EstadoComponente estado,
  String desc,
) => BreakdownLinha(
  componente: c,
  pontos: pontos,
  pontosMax: max,
  estado: estado,
  descricao: desc,
);

VagaDetalhe _detalhe({
  int total = 97,
  bool podeCandidatar = true,
  bool jaCandidatou = false,
  CandidaturaResumo? candidatura,
  String? motivo,
  double? distanciaKm = 3.0,
  String? estabelecimento = 'Bar do Zé',
  List<BreakdownLinha>? linhas,
}) => VagaDetalhe(
  id: '7',
  funcao: 'Garçom',
  estabelecimento: estabelecimento,
  cidade: 'São Paulo',
  dataInicio: DateTime(2026, 6, 12, 18),
  dataFim: DateTime(2026, 6, 12, 23),
  valor: 150.0,
  distanciaKm: distanciaKm,
  score: ScoreBreakdown(
    total: total,
    linhas:
        linhas ??
        [
          _linha(
            ComponenteMatch.funcao,
            40,
            40,
            EstadoComponente.ok,
            'Sua função primária bate',
          ),
          _linha(
            ComponenteMatch.distancia,
            20,
            20,
            EstadoComponente.ok,
            'Dentro do seu raio de 8km',
          ),
          _linha(
            ComponenteMatch.historico,
            27,
            30,
            EstadoComponente.partial,
            'Sua média 4.9★ em 127 turnos',
          ),
          _linha(
            ComponenteMatch.nivel,
            10,
            10,
            EstadoComponente.ok,
            'Elite na trilha',
          ),
        ],
  ),
  podeCandidatar: podeCandidatar,
  jaCandidatou: jaCandidatou,
  candidatura: candidatura,
  motivoBloqueio: motivo,
);

Widget _comRouter(_FakeService svc) {
  final router = GoRouter(
    initialLocation: '/vaga/7',
    routes: [
      GoRoute(
        path: '/vaga/:id',
        builder: (_, _) => VagaDetalheScreen(vagaId: '7', service: svc),
      ),
      GoRoute(
        path: '/feed',
        builder: (_, _) => const Scaffold(body: Text('FEED')),
      ),
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: Text('HOME')),
      ),
    ],
  );
  return MaterialApp.router(theme: buildLightTheme(), routerConfig: router);
}

void main() {
  // ───────────────── CA-2/CA-3/CA-4 — cabeçalho + breakdown + total ─────────────────

  testWidgets(
    'cabeçalho mostra função, estabelecimento, distância e score (CA-2)',
    (tester) async {
      final svc = _FakeService(result: () => DetalheSuccess(_detalhe()));
      await tester.pumpWidget(_comRouter(svc));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('vaga-detalhe-cabecalho')), findsOneWidget);
      expect(find.byKey(const Key('vaga-detalhe-funcao')), findsOneWidget);
      expect(find.text('Garçom'), findsOneWidget);
      expect(find.text('Bar do Zé · São Paulo'), findsOneWidget);
      expect(find.byKey(const Key('vaga-detalhe-score-chip')), findsOneWidget);
      expect(find.textContaining('a 3 km'), findsOneWidget);
      expect(
        find.byKey(const Key('vaga-detalhe-alto-match')),
        findsOneWidget,
      ); // 97 ≥ 80
    },
  );

  testWidgets('breakdown renderiza as 4 linhas na ordem canônica (CA-2)', (
    tester,
  ) async {
    final svc = _FakeService(result: () => DetalheSuccess(_detalhe()));
    await tester.pumpWidget(_comRouter(svc));
    await tester.pumpAndSettle();

    for (final slug in ['funcao', 'distancia', 'historico', 'nivel']) {
      expect(find.byKey(Key('vaga-detalhe-breakdown-$slug')), findsOneWidget);
      expect(
        find.byKey(Key('vaga-detalhe-breakdown-$slug-bar')),
        findsOneWidget,
      );
      expect(
        find.byKey(Key('vaga-detalhe-breakdown-$slug-icone')),
        findsOneWidget,
      );
    }
    expect(find.text('Função'), findsOneWidget);
    expect(find.text('Distância'), findsOneWidget);
    expect(find.text('Histórico'), findsOneWidget);
    expect(find.text('Nível na trilha'), findsOneWidget);
    expect(find.text('40/40'), findsOneWidget);
    expect(find.text('27/30'), findsOneWidget);
    expect(find.text('Sua média 4.9★ em 127 turnos'), findsOneWidget);
  });

  testWidgets('estados ok/partial/miss usam ícones distintos (CA-3)', (
    tester,
  ) async {
    final svc = _FakeService(
      result: () => DetalheSuccess(
        _detalhe(
          total: 28,
          linhas: [
            _linha(
              ComponenteMatch.funcao,
              25,
              40,
              EstadoComponente.partial,
              'Uma função secundária bate',
            ),
            _linha(
              ComponenteMatch.distancia,
              0,
              20,
              EstadoComponente.miss,
              'Localização indisponível',
            ),
            _linha(
              ComponenteMatch.historico,
              0,
              30,
              EstadoComponente.miss,
              'Sem histórico de turnos',
            ),
            _linha(
              ComponenteMatch.nivel,
              10,
              10,
              EstadoComponente.ok,
              'Elite na trilha',
            ),
          ],
        ),
      ),
    );
    await tester.pumpWidget(_comRouter(svc));
    await tester.pumpAndSettle();

    Icon icone(String slug) => tester.widget<Icon>(
      find.descendant(
        of: find.byKey(Key('vaga-detalhe-breakdown-$slug-icone')),
        matching: find.byType(Icon),
      ),
    );
    expect(icone('funcao').icon, Icons.adjust); // partial
    expect(icone('distancia').icon, Icons.close); // miss
    expect(icone('nivel').icon, Icons.check); // ok
  });

  testWidgets('total agregado exibe XX/100 (CA-4)', (tester) async {
    final svc = _FakeService(result: () => DetalheSuccess(_detalhe(total: 97)));
    await tester.pumpWidget(_comRouter(svc));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('vaga-detalhe-total')), findsOneWidget);
    expect(find.byKey(const Key('vaga-detalhe-total-bar')), findsOneWidget);
    expect(find.text('97/100'), findsOneWidget);
    expect(find.text('Match total'), findsOneWidget);
  });

  testWidgets('score < 80 não mostra selo Alto match', (tester) async {
    final svc = _FakeService(result: () => DetalheSuccess(_detalhe(total: 61)));
    await tester.pumpWidget(_comRouter(svc));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('vaga-detalhe-alto-match')), findsNothing);
  });

  testWidgets('distância null omite a linha de distância no cabeçalho (§4.8)', (
    tester,
  ) async {
    final svc = _FakeService(
      result: () => DetalheSuccess(_detalhe(distanciaKm: null)),
    );
    await tester.pumpWidget(_comRouter(svc));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('vaga-detalhe-distancia')), findsNothing);
    expect(find.text('R\$ 150,00 · turno'), findsOneWidget);
  });

  testWidgets('sem estabelecimento mostra só a cidade', (tester) async {
    final svc = _FakeService(
      result: () => DetalheSuccess(_detalhe(estabelecimento: null)),
    );
    await tester.pumpWidget(_comRouter(svc));
    await tester.pumpAndSettle();

    expect(find.text('São Paulo'), findsOneWidget);
  });

  // ───────────────── CA-5 — CTA candidatar / gate ─────────────────

  testWidgets('CTA habilitado quando pode e não candidatou (CA-5)', (
    tester,
  ) async {
    final svc = _FakeService(result: () => DetalheSuccess(_detalhe()));
    await tester.pumpWidget(_comRouter(svc));
    await tester.pumpAndSettle();

    final btn = find.byKey(const Key('vaga-detalhe-candidatar-btn'));
    expect(btn, findsOneWidget);
    expect(tester.widget<FilledButton>(btn).onPressed, isNotNull);

    // STORY-050: tocar no CTA abre o modal de confirmação (não candidata direto).
    await tester.tap(btn);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('candidatura-confirmar-sheet')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('candidatura-confirmar-btn')), findsOneWidget);
  });

  testWidgets('gate: banner + botão desabilitado com motivo (CA-5)', (
    tester,
  ) async {
    final svc = _FakeService(
      result: () => DetalheSuccess(
        _detalhe(
          podeCandidatar: false,
          motivo: 'Avalie seu último turno para se candidatar.',
        ),
      ),
    );
    await tester.pumpWidget(_comRouter(svc));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('vaga-detalhe-gate-banner')), findsOneWidget);
    expect(
      find.text('Avalie seu último turno para se candidatar.'),
      findsOneWidget,
    );
    final btn = find.byKey(const Key('vaga-detalhe-candidatar-btn'));
    expect(tester.widget<FilledButton>(btn).onPressed, isNull);
  });

  // ───────────────── CA-6 — já candidatou ─────────────────

  testWidgets('já candidatou (pendente) mostra badge + retirar (CA-6)', (
    tester,
  ) async {
    final svc = _FakeService(
      result: () => DetalheSuccess(
        _detalhe(
          jaCandidatou: true,
          candidatura: CandidaturaResumo(
            id: '1',
            estado: 'pendente',
            criadaEm: DateTime(2026, 6, 2, 14, 20),
          ),
        ),
      ),
    );
    await tester.pumpWidget(_comRouter(svc));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('vaga-detalhe-ja-candidatou')), findsOneWidget);
    expect(find.text('Você já se candidatou'), findsOneWidget);
    expect(find.textContaining('em 02/06 às 14:20'), findsOneWidget);
    expect(find.byKey(const Key('vaga-detalhe-retirar-btn')), findsOneWidget);
    // CTA de candidatar não aparece.
    expect(find.byKey(const Key('vaga-detalhe-candidatar-btn')), findsNothing);
  });

  testWidgets('já candidatou aprovada não mostra retirar (CA-6)', (
    tester,
  ) async {
    final svc = _FakeService(
      result: () => DetalheSuccess(
        _detalhe(
          jaCandidatou: true,
          candidatura: CandidaturaResumo(
            estado: 'aprovada',
            criadaEm: DateTime(2026, 6, 2, 14, 20),
          ),
        ),
      ),
    );
    await tester.pumpWidget(_comRouter(svc));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('vaga-detalhe-ja-candidatou')), findsOneWidget);
    expect(find.byKey(const Key('vaga-detalhe-retirar-btn')), findsNothing);
  });

  // ───────────────── Estados loading / erro / sem permissão / indisponível ─────────────────

  testWidgets('loading mostra skeleton', (tester) async {
    final svc = _FakeService(
      result: () => DetalheSuccess(_detalhe()),
      delay: const Duration(milliseconds: 50),
    );
    await tester.pumpWidget(_comRouter(svc));
    await tester.pump(); // antes do future resolver

    expect(find.byKey(const Key('vaga-detalhe-skeleton')), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('vaga-detalhe-skeleton')), findsNothing);
  });

  testWidgets('erro mostra retry e re-busca (CA-5/§4.5)', (tester) async {
    var first = true;
    final svc = _FakeService(
      result: () => first
          ? (first = false, DetalheError()).$2
          : DetalheSuccess(_detalhe()),
    );
    await tester.pumpWidget(_comRouter(svc));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('vaga-detalhe-erro')), findsOneWidget);
    await tester.tap(find.byKey(const Key('vaga-detalhe-retry-btn')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('vaga-detalhe-erro')), findsNothing);
    expect(find.byKey(const Key('vaga-detalhe-cabecalho')), findsOneWidget);
    expect(svc.calls, 2);
  });

  testWidgets('contratante (403) cai em sem permissão (CA-7)', (tester) async {
    final svc = _FakeService(result: () => DetalheForbidden());
    await tester.pumpWidget(_comRouter(svc));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('vaga-detalhe-sem-permissao')), findsOneWidget);
    expect(find.text('Esta área é do profissional'), findsOneWidget);
  });

  testWidgets('404 cai em vaga indisponível (§4.7)', (tester) async {
    final svc = _FakeService(result: () => DetalheNotFound());
    await tester.pumpWidget(_comRouter(svc));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('vaga-detalhe-indisponivel')), findsOneWidget);
    expect(find.text('Esta vaga não está mais disponível'), findsOneWidget);
  });
}
