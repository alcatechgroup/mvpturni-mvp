import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:turni_webapp/ds/theme.dart';
import 'package:turni_webapp/features/vagas/candidatura_service.dart';
import 'package:turni_webapp/features/vagas/vaga_detalhe_screen.dart';
import 'package:turni_webapp/features/vagas/vaga_detalhe_service.dart';

// STORY-052 — widget tests do banner de revisão pós-edição (SCREEN-052, surface B / CA-11).
// Banner com prazo + diff; Manter (→ some + toast); Retirar (confirma → toast); 409 (prazo
// expirado).

class _FakeDetalheService extends VagaDetalheService {
  _FakeDetalheService(this._vaga);
  final VagaDetalhe _vaga;

  @override
  Future<DetalheResult> fetch(int id) async => DetalheSuccess(_vaga);
}

class _FakeCandidaturaService extends CandidaturaService {
  _FakeCandidaturaService({this.manterResult});
  RevisaoResult Function()? manterResult;
  int manterCalls = 0;
  int retirarCalls = 0;

  @override
  Future<RevisaoResult> manterAposEdicao(int id) async {
    manterCalls++;
    return manterResult?.call() ?? RevisaoSuccess('pendente');
  }

  @override
  Future<RevisaoResult> retirarAposEdicao(int id) async {
    retirarCalls++;
    return RevisaoSuccess('retirada_por_edicao');
  }
}

VagaDetalhe _emRevisao() => VagaDetalhe(
  id: 7,
  funcao: 'Garçom',
  estabelecimento: 'Bar do Zé',
  cidade: 'São Paulo',
  dataInicio: DateTime(2026, 6, 12, 19),
  dataFim: DateTime(2026, 6, 12, 23),
  valor: 150.0,
  distanciaKm: 2.3,
  score: const ScoreBreakdown(total: 90, linhas: []),
  podeCandidatar: false,
  jaCandidatou: true,
  candidatura: const CandidaturaResumo(
    id: 33,
    estado: 'pendente_revisao_apos_edicao',
    criadaEm: null,
  ),
  motivoBloqueio: null,
  revisao: RevisaoInfo(
    prazoEm: DateTime(2026, 6, 12, 18),
    diff: const [
      DiffLinha(
        campo: 'valor',
        label: 'Valor',
        tipo: 'valor',
        antes: 120.0,
        depois: 150.0,
      ),
    ],
  ),
);

Widget _comRouter(_FakeDetalheService det, _FakeCandidaturaService cand) {
  final router = GoRouter(
    initialLocation: '/vaga/7',
    routes: [
      GoRoute(
        path: '/vaga/:id',
        builder: (_, _) => VagaDetalheScreen(
          vagaId: 7,
          service: det,
          candidaturaService: cand,
        ),
      ),
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: Text('home')),
      ),
      GoRoute(
        path: '/feed',
        builder: (_, _) => const Scaffold(body: Text('feed')),
      ),
    ],
  );
  return MaterialApp.router(theme: buildLightTheme(), routerConfig: router);
}

void main() {
  testWidgets('CA-11 — banner de revisão mostra prazo + diff + 2 ações', (
    tester,
  ) async {
    await tester.pumpWidget(
      _comRouter(_FakeDetalheService(_emRevisao()), _FakeCandidaturaService()),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('vaga-detalhe-revisao-banner')),
      findsOneWidget,
    );
    expect(find.text('Esta vaga foi editada'), findsOneWidget);
    expect(
      find.byKey(const Key('vaga-detalhe-revisao-diff-valor')),
      findsOneWidget,
    );
    expect(find.textContaining('R\$ 120,00 → R\$ 150,00'), findsOneWidget);
    expect(find.byKey(const Key('vaga-detalhe-manter-btn')), findsOneWidget);
    expect(find.byKey(const Key('vaga-detalhe-retirar-btn')), findsOneWidget);
  });

  testWidgets(
    'CA-7 — Manter candidatura chama o serviço, some o banner e mostra toast',
    (tester) async {
      final cand = _FakeCandidaturaService();
      await tester.pumpWidget(
        _comRouter(_FakeDetalheService(_emRevisao()), cand),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('vaga-detalhe-manter-btn')));
      await tester.pumpAndSettle();

      expect(cand.manterCalls, 1);
      expect(
        find.byKey(const Key('vaga-detalhe-revisao-banner')),
        findsNothing,
      );
      expect(find.text('Candidatura mantida.'), findsOneWidget);
    },
  );

  testWidgets('CA-8 — Retirar confirma e chama o serviço, mostra toast', (
    tester,
  ) async {
    final cand = _FakeCandidaturaService();
    await tester.pumpWidget(
      _comRouter(_FakeDetalheService(_emRevisao()), cand),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('vaga-detalhe-retirar-btn')));
    await tester.pumpAndSettle();
    // confirma no sheet de retirada (reusa o de STORY-050)
    await tester.tap(
      find.byKey(const Key('candidatura-retirar-confirmar-btn')),
    );
    await tester.pumpAndSettle();

    expect(cand.retirarCalls, 1);
    expect(find.text('Candidatura retirada.'), findsOneWidget);
    expect(find.byKey(const Key('vaga-detalhe-revisao-banner')), findsNothing);
  });

  testWidgets('§4.6 — 409 ao manter (prazo expirou) some o banner e informa', (
    tester,
  ) async {
    final cand = _FakeCandidaturaService(manterResult: () => RevisaoConflict());
    await tester.pumpWidget(
      _comRouter(_FakeDetalheService(_emRevisao()), cand),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('vaga-detalhe-manter-btn')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('vaga-detalhe-revisao-banner')), findsNothing);
    expect(
      find.textContaining('O prazo para confirmar terminou'),
      findsOneWidget,
    );
  });

  testWidgets('candidatura pendente normal não mostra o banner de revisão', (
    tester,
  ) async {
    final vaga = VagaDetalhe(
      id: 7,
      funcao: 'Garçom',
      estabelecimento: 'Bar do Zé',
      cidade: 'São Paulo',
      dataInicio: DateTime(2026, 6, 12, 19),
      dataFim: DateTime(2026, 6, 12, 23),
      valor: 150.0,
      distanciaKm: 2.3,
      score: const ScoreBreakdown(total: 90, linhas: []),
      podeCandidatar: false,
      jaCandidatou: true,
      candidatura: const CandidaturaResumo(
        id: 33,
        estado: 'pendente',
        criadaEm: null,
      ),
      motivoBloqueio: null,
      revisao: null,
    );
    await tester.pumpWidget(
      _comRouter(_FakeDetalheService(vaga), _FakeCandidaturaService()),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('vaga-detalhe-revisao-banner')), findsNothing);
  });
}
