import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:turni_webapp/ds/theme.dart';
import 'package:turni_webapp/features/auth/auth_service.dart';
import 'package:turni_webapp/features/feed/feed_screen.dart';
import 'package:turni_webapp/features/feed/feed_service.dart';

// STORY-048 — widget tests da FeedScreen (SCREEN-048).
// CA-1 (sem permissão p/ contratante), CA-3 (ordem do back), CA-5 (score número+barra,
// filtros re-buscam), CA-8 (gate: banner + botão desabilitado), CA-9 (cold start),
// estados loading/vazio/vazio-filtro/erro, distância opcional, navegação ao detalhe.

class _FakeFeedService extends FeedService {
  _FakeFeedService({this.handler, this.delay});

  FeedResult Function(FeedFiltro filtro, int page)? handler;
  final Duration? delay;
  final List<(FeedFiltro, int)> calls = [];

  @override
  Future<FeedResult> fetch({
    FeedFiltro filtro = FeedFiltro.todas,
    int page = 1,
  }) async {
    calls.add((filtro, page));
    if (delay != null) await Future<void>.delayed(delay!);
    return handler?.call(filtro, page) ?? FeedSuccess(const [], 1, false);
  }
}

FeedVagaResumo _vaga({
  int id = 1,
  String funcao = 'Garçom',
  double valor = 150.0,
  double? distanciaKm = 3.0,
  int score = 97,
  bool jaCandidatou = false,
  bool podeCandidatar = true,
}) => FeedVagaResumo(
  id: id,
  funcao: funcao,
  dataInicio: DateTime(2026, 6, 12, 18),
  dataFim: DateTime(2026, 6, 12, 23),
  valor: valor,
  distanciaKm: distanciaKm,
  score: FeedScore(
    total: score,
    componentes: const {
      'funcao': 40,
      'distancia': 20,
      'historico': 27,
      'nivel': 10,
    },
  ),
  jaCandidatou: jaCandidatou,
  podeCandidatar: podeCandidatar,
);

void _entrarProfissional() {
  AuthService().debugSetSession(
    const UserSession(
      name: 'Maria',
      role: 'profissional',
      status: 'ativo',
      welcomeVisto: true,
      cadastroCompleto: true,
    ),
  );
}

Widget _comRouter(_FakeFeedService svc, {String? filtroInicial}) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) =>
            FeedScreen(service: svc, filtroInicial: filtroInicial),
      ),
      GoRoute(
        path: '/vaga/:id',
        builder: (_, s) =>
            Scaffold(body: Text('DETALHE ${s.pathParameters['id']}')),
      ),
      GoRoute(
        path: '/login',
        builder: (_, _) => const Scaffold(body: Text('LOGIN')),
      ),
    ],
  );
  return MaterialApp.router(theme: buildLightTheme(), routerConfig: router);
}

void main() {
  setUp(_entrarProfissional);
  tearDown(() => AuthService().debugSetSession(null));

  // ───────────────── CA-5 — card com score número + barra + distância ─────────────────

  testWidgets(
    'card mostra função, score (número+chip+barra), distância e Alto match (CA-5)',
    (tester) async {
      final svc = _FakeFeedService(
        handler: (_, _) => FeedSuccess([_vaga(score: 97)], 1, false),
      );
      await tester.pumpWidget(_comRouter(svc));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('feed-card-1')), findsOneWidget);
      expect(find.text('Garçom'), findsOneWidget);
      expect(find.byKey(const Key('feed-card-1-score')), findsOneWidget);
      expect(find.byKey(const Key('feed-card-1-score-bar')), findsOneWidget);
      expect(find.text('97/100'), findsOneWidget);
      expect(
        find.byKey(const Key('feed-card-1-alto-match')),
        findsOneWidget,
      ); // ≥80
      expect(find.textContaining('a 3 km'), findsOneWidget);
      expect(
        find.byKey(const Key('feed-card-1-candidatar-btn')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'vaga já candidatada mostra selo "Você já se candidatou" no lugar do botão (STORY-050)',
    (tester) async {
      final svc = _FakeFeedService(
        handler: (_, _) => FeedSuccess([_vaga(jaCandidatou: true)], 1, false),
      );
      await tester.pumpWidget(_comRouter(svc));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('feed-card-1-ja-candidatou')),
        findsOneWidget,
      );
      expect(find.text('Você já se candidatou'), findsOneWidget);
      // O botão "Candidatar-se" não aparece quando já candidatou.
      expect(find.byKey(const Key('feed-card-1-candidatar-btn')), findsNothing);
    },
  );

  testWidgets('score < 80 não mostra selo Alto match', (tester) async {
    final svc = _FakeFeedService(
      handler: (_, _) => FeedSuccess([_vaga(score: 61)], 1, false),
    );
    await tester.pumpWidget(_comRouter(svc));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('feed-card-1-alto-match')), findsNothing);
    expect(find.text('61/100'), findsOneWidget);
  });

  testWidgets('distância null omite a linha de distância', (tester) async {
    final svc = _FakeFeedService(
      handler: (_, _) => FeedSuccess([_vaga(distanciaKm: null)], 1, false),
    );
    await tester.pumpWidget(_comRouter(svc));
    await tester.pumpAndSettle();

    expect(find.textContaining('km'), findsNothing);
    expect(find.textContaining('R\$ 150,00 · turno'), findsOneWidget);
  });

  testWidgets('cards aparecem na ordem do backend (CA-3)', (tester) async {
    final svc = _FakeFeedService(
      handler: (_, _) => FeedSuccess(
        [
          _vaga(id: 7, funcao: 'Garçom', score: 94),
          _vaga(id: 9, funcao: 'Cozinheira', score: 70),
        ],
        1,
        false,
      ),
    );
    await tester.pumpWidget(_comRouter(svc));
    await tester.pumpAndSettle();

    final cards = tester.widgetList(find.byType(InkWell)).toList();
    expect(cards.length, greaterThanOrEqualTo(2));
    // O primeiro card renderizado é o de maior score (ordem do back, sem reordenar).
    final garcomY = tester.getTopLeft(find.text('Garçom')).dy;
    final cozinheiraY = tester.getTopLeft(find.text('Cozinheira')).dy;
    expect(garcomY, lessThan(cozinheiraY));
  });

  // ───────────────── CA-5 — filtros re-buscam ─────────────────

  testWidgets('trocar filtro para Alto match re-busca e atualiza (CA-5)', (
    tester,
  ) async {
    final svc = _FakeFeedService(
      handler: (filtro, _) => switch (filtro) {
        FeedFiltro.altoMatch => FeedSuccess(
          [_vaga(id: 1, score: 94)],
          1,
          false,
        ),
        _ => FeedSuccess(
          [
            _vaga(id: 1, score: 94),
            _vaga(id: 2, funcao: 'Cozinheira', score: 70),
          ],
          1,
          false,
        ),
      },
    );
    await tester.pumpWidget(_comRouter(svc));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('feed-card-2')), findsOneWidget);

    await tester.tap(find.byKey(const Key('feed-filtro-alto_match')));
    await tester.pumpAndSettle();

    expect(svc.calls.any((c) => c.$1 == FeedFiltro.altoMatch), isTrue);
    expect(find.byKey(const Key('feed-card-2')), findsNothing); // a 70 saiu
    expect(find.byKey(const Key('feed-card-1')), findsOneWidget);
  });

  // ───────────────── estados ─────────────────

  testWidgets('loading mostra skeleton antes da resposta', (tester) async {
    final svc = _FakeFeedService(
      delay: const Duration(milliseconds: 50),
      handler: (_, _) => FeedSuccess([_vaga()], 1, false),
    );
    await tester.pumpWidget(_comRouter(svc));
    await tester.pump(); // fetch em voo (delay): estado loading
    expect(find.byKey(const Key('feed-skeleton')), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('feed-skeleton')), findsNothing);
  });

  testWidgets('feed vazio (todas) mostra o estado vazio', (tester) async {
    final svc = _FakeFeedService(
      handler: (_, _) => FeedSuccess(const [], 1, false),
    );
    await tester.pumpWidget(_comRouter(svc));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('feed-vazio')), findsOneWidget);
    expect(find.text('Nenhuma vaga por aqui ainda'), findsOneWidget);
  });

  testWidgets(
    'vazio por filtro mostra mensagem e atalho "Ver todas" (volta p/ todas)',
    (tester) async {
      final svc = _FakeFeedService(
        handler: (filtro, _) => switch (filtro) {
          FeedFiltro.altoMatch => FeedSuccess(const [], 1, false),
          _ => FeedSuccess([_vaga()], 1, false),
        },
      );
      await tester.pumpWidget(_comRouter(svc, filtroInicial: 'alto_match'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('feed-vazio-filtro')), findsOneWidget);
      expect(find.text('Nenhuma vaga com alto match agora.'), findsOneWidget);

      await tester.tap(find.byKey(const Key('feed-vazio-filtro-todas-btn')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('feed-card-1')), findsOneWidget);
    },
  );

  testWidgets('erro de rede mostra banner + retry recarrega', (tester) async {
    var falhar = true;
    final svc = _FakeFeedService(
      handler: (_, _) =>
          falhar ? FeedError() : FeedSuccess([_vaga()], 1, false),
    );
    await tester.pumpWidget(_comRouter(svc));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('feed-erro-banner')), findsOneWidget);
    falhar = false;
    await tester.tap(find.byKey(const Key('feed-retry-btn')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('feed-card-1')), findsOneWidget);
  });

  testWidgets('contratante (403) cai em "sem permissão" (CA-1)', (
    tester,
  ) async {
    final svc = _FakeFeedService(handler: (_, _) => FeedForbidden());
    await tester.pumpWidget(_comRouter(svc));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('feed-sem-permissao')), findsOneWidget);
    expect(find.text('Esta área é do profissional'), findsOneWidget);
  });

  // ───────────────── CA-8 — gate PDR-005 ─────────────────

  testWidgets(
    'gate ativo mostra banner e desabilita o botão candidatar (CA-8)',
    (tester) async {
      final svc = _FakeFeedService(
        handler: (_, _) =>
            FeedSuccess([_vaga(podeCandidatar: false)], 1, false),
      );
      await tester.pumpWidget(_comRouter(svc));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('feed-gate-banner')), findsOneWidget);
      final btn = tester.widget<FilledButton>(
        find.byKey(const Key('feed-card-1-candidatar-btn')),
      );
      expect(btn.onPressed, isNull); // desabilitado
    },
  );

  testWidgets('sem gate, candidatar habilitado navega ao detalhe', (
    tester,
  ) async {
    final svc = _FakeFeedService(
      handler: (_, _) =>
          FeedSuccess([_vaga(id: 5, podeCandidatar: true)], 1, false),
    );
    await tester.pumpWidget(_comRouter(svc));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('feed-gate-banner')), findsNothing);
    await tester.tap(find.byKey(const Key('feed-card-5-candidatar-btn')));
    await tester.pumpAndSettle();
    expect(find.text('DETALHE 5'), findsOneWidget);
  });

  testWidgets('tocar no corpo do card abre o detalhe (STORY-049)', (
    tester,
  ) async {
    final svc = _FakeFeedService(
      handler: (_, _) => FeedSuccess([_vaga(id: 8)], 1, false),
    );
    await tester.pumpWidget(_comRouter(svc));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('feed-card-8')));
    await tester.pumpAndSettle();
    expect(find.text('DETALHE 8'), findsOneWidget);
  });

  // ───────────────── CA-9 — cold start ─────────────────

  testWidgets('cold start (score baixo) ainda renderiza o card (CA-9)', (
    tester,
  ) async {
    final svc = _FakeFeedService(
      handler: (_, _) => FeedSuccess([_vaga(score: 60)], 1, false),
    );
    await tester.pumpWidget(_comRouter(svc));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('feed-card-1')), findsOneWidget);
    expect(find.text('60/100'), findsOneWidget);
    expect(find.byKey(const Key('feed-card-1-alto-match')), findsNothing);
  });
}
