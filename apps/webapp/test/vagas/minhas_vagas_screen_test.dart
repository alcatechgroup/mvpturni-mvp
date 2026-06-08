import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:turni_webapp/ds/theme.dart';
import 'package:turni_webapp/features/auth/auth_service.dart';
import 'package:turni_webapp/features/vagas/minhas_vagas_screen.dart';
import 'package:turni_webapp/features/vagas/vaga_service.dart';

// STORY-047 — widget tests da MinhasVagasScreen (SCREEN-047).
// CA-1 (sem permissão p/ profissional), CA-2 (card: função/estado/posições/pendentes),
// CA-3 (filtros client-side), CA-4 (cancelar com diálogo + contagem real), CA-6 (link
// candidatos), CA-7 (vazio + CTA). Estados: loading/vazio/vazio-filtro/erro/cancelando.

class _FakeVagaService extends VagaService {
  _FakeVagaService({this.minhasResult, this.cancelarResult});

  MinhasVagasResult Function()? minhasResult;
  CancelarResult Function()? cancelarResult;

  int cancelarCalls = 0;
  String? ultimaVagaCancelada;

  @override
  Future<MinhasVagasResult> fetchMinhas() async =>
      minhasResult?.call() ?? MinhasVagasSuccess(const []);

  @override
  Future<CancelarResult> cancelar(String vagaId) async {
    cancelarCalls++;
    ultimaVagaCancelada = vagaId;
    return cancelarResult?.call() ?? CancelarSuccess();
  }
}

VagaResumo _vaga({
  String id = '1',
  String funcao = 'Garçom',
  VagaEstadoResumo estado = VagaEstadoResumo.aberta,
  int posicoes = 3,
  int preenchidas = 1,
  int pendentes = 0,
  DateTime? inicio,
}) => VagaResumo(
  id: id,
  funcao: funcao,
  dataInicio: inicio ?? DateTime(2026, 6, 12, 18),
  dataFim: (inicio ?? DateTime(2026, 6, 12, 18)).add(const Duration(hours: 5)),
  valor: 150.00,
  posicoes: posicoes,
  posicoesPreenchidas: preenchidas,
  estado: estado,
  candidatosPendentes: pendentes,
);

void _entrarContratante() {
  AuthService().debugSetSession(
    const UserSession(
      name: 'Bar do Zé',
      role: 'contratante',
      status: 'ativo',
      welcomeVisto: true,
      cadastroCompleto: true,
    ),
  );
}

Widget _comRouter(_FakeVagaService svc, {String? filtroInicial}) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) =>
            MinhasVagasScreen(service: svc, filtroInicial: filtroInicial),
      ),
      GoRoute(
        path: '/contratante/vagas/nova',
        builder: (_, _) => const Scaffold(body: Text('NOVA VAGA')),
      ),
    ],
  );
  return MaterialApp.router(theme: buildLightTheme(), routerConfig: router);
}

void main() {
  setUp(() {
    _entrarContratante();
    debugResetFiltroSessao(); // isola o filtro de sessão entre testes
  });
  tearDown(() => AuthService().debugSetSession(null));

  // ─────── STORY-078 — FAB "Publicar vaga" só no mobile (CA-2) ───────
  // Com lista preenchida, o FAB aparece no compact; no desktop o shell já
  // oferece "Nova vaga" no rail/sidebar — o FAB sumiria (sem caminho duplicado).

  Future<void> _pumpAtWidth(WidgetTester tester, double width) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = Size(width, 900);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final svc = _FakeVagaService(
      minhasResult: () => MinhasVagasSuccess([_vaga()]),
    );
    await tester.pumpWidget(_comRouter(svc));
    await tester.pumpAndSettle();
  }

  testWidgets('(a) lista preenchida no mobile (<600) mostra o FAB', (
    tester,
  ) async {
    await _pumpAtWidth(tester, 400);
    expect(find.byKey(const Key('minhas-vagas-publicar-btn')), findsOneWidget);
  });

  testWidgets('(d) lista preenchida no desktop (≥600) NÃO mostra o FAB', (
    tester,
  ) async {
    await _pumpAtWidth(tester, 1000);
    // O caminho "Nova vaga" no desktop é do shell — sem FAB duplicado.
    expect(find.byKey(const Key('minhas-vagas-publicar-btn')), findsNothing);
  });

  // ───────────────── CA-2 — card preenchido ─────────────────

  testWidgets(
    'lista renderiza o card com função, estado, posições e pendentes (CA-2)',
    (tester) async {
      final svc = _FakeVagaService(
        minhasResult: () => MinhasVagasSuccess([_vaga(pendentes: 2)]),
      );
      await tester.pumpWidget(_comRouter(svc));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('vaga-card-1')), findsOneWidget);
      expect(find.text('Garçom'), findsOneWidget);
      expect(find.byKey(const Key('vaga-card-1-estado')), findsOneWidget);
      expect(find.text('Aberta'), findsOneWidget);
      expect(find.byKey(const Key('vaga-card-1-posicoes')), findsOneWidget);
      expect(find.text('1/3'), findsOneWidget);
      expect(find.byKey(const Key('vaga-card-1-pendentes')), findsOneWidget);
      expect(find.text('2 candidatos aguardando'), findsOneWidget);
    },
  );

  testWidgets('card sem pendentes não mostra o contador (borda)', (
    tester,
  ) async {
    final svc = _FakeVagaService(
      minhasResult: () => MinhasVagasSuccess([_vaga(pendentes: 0)]),
    );
    await tester.pumpWidget(_comRouter(svc));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('vaga-card-1-pendentes')), findsNothing);
  });

  testWidgets('card aberta tem botão cancelar; fechada não (CA-4/CA-6)', (
    tester,
  ) async {
    final svc = _FakeVagaService(
      minhasResult: () => MinhasVagasSuccess([
        _vaga(id: '1', estado: VagaEstadoResumo.aberta, pendentes: 1),
        _vaga(id: '2', estado: VagaEstadoResumo.fechada, funcao: 'Cozinheira'),
      ]),
    );
    await tester.pumpWidget(_comRouter(svc, filtroInicial: 'todas'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('vaga-card-1-cancelar-btn')), findsOneWidget);
    expect(find.byKey(const Key('vaga-card-2-cancelar-btn')), findsNothing);
    // Ver candidatos: aberta c/ pendentes>0 e fechada (CA-6).
    expect(find.byKey(const Key('vaga-card-1-ver-candidatos')), findsOneWidget);
    expect(find.byKey(const Key('vaga-card-2-ver-candidatos')), findsOneWidget);
  });

  // ───────────────── CA-1 — sem permissão ─────────────────

  testWidgets('profissional (403) vê o estado sem permissão (CA-1)', (
    tester,
  ) async {
    final svc = _FakeVagaService(minhasResult: () => MinhasVagasForbidden());
    await tester.pumpWidget(_comRouter(svc));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('minhas-vagas-sem-permissao')), findsOneWidget);
    expect(find.text('Esta área é do contratante'), findsOneWidget);
    expect(find.byKey(const Key('minhas-vagas-lista')), findsNothing);
  });

  // ───────────────── CA-7 — vazio ─────────────────

  testWidgets('lista vazia mostra estado vazio + CTA publicar (CA-7)', (
    tester,
  ) async {
    final svc = _FakeVagaService(
      minhasResult: () => MinhasVagasSuccess(const []),
    );
    await tester.pumpWidget(_comRouter(svc));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('minhas-vagas-vazio')), findsOneWidget);
    expect(find.text('Você ainda não publicou vagas'), findsOneWidget);
    expect(find.byKey(const Key('minhas-vagas-publicar-btn')), findsOneWidget);
  });

  testWidgets('CTA publicar navega para /contratante/vagas/nova (CA-7)', (
    tester,
  ) async {
    final svc = _FakeVagaService(
      minhasResult: () => MinhasVagasSuccess(const []),
    );
    await tester.pumpWidget(_comRouter(svc));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('minhas-vagas-publicar-btn')));
    await tester.pumpAndSettle();
    expect(find.text('NOVA VAGA'), findsOneWidget);
  });

  // ───────────────── erro de fetch ─────────────────

  testWidgets('erro de rede mostra banner + retry; retry refaz o fetch', (
    tester,
  ) async {
    var chamada = 0;
    final svc = _FakeVagaService(
      minhasResult: () {
        chamada++;
        return chamada == 1
            ? MinhasVagasError()
            : MinhasVagasSuccess([_vaga()]);
      },
    );
    await tester.pumpWidget(_comRouter(svc));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('minhas-vagas-erro-banner')), findsOneWidget);

    await tester.tap(find.byKey(const Key('minhas-vagas-retry-btn')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('minhas-vagas-erro-banner')), findsNothing);
    expect(find.byKey(const Key('vaga-card-1')), findsOneWidget);
  });

  // ───────────────── CA-3 — filtros client-side ─────────────────

  testWidgets('filtro "Canceladas" mostra só canceladas (CA-3)', (
    tester,
  ) async {
    final svc = _FakeVagaService(
      minhasResult: () => MinhasVagasSuccess([
        _vaga(id: '1', estado: VagaEstadoResumo.aberta),
        _vaga(id: '2', estado: VagaEstadoResumo.cancelada, funcao: 'Bartender'),
      ]),
    );
    await tester.pumpWidget(_comRouter(svc));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('minhas-vagas-filtro-canceladas')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('vaga-card-2')), findsOneWidget);
    expect(find.byKey(const Key('vaga-card-1')), findsNothing);
  });

  testWidgets(
    'filtro sem resultado mostra vazio-por-filtro (não o vazio de 1ª vez)',
    (tester) async {
      final svc = _FakeVagaService(
        minhasResult: () => MinhasVagasSuccess([
          _vaga(id: '1', estado: VagaEstadoResumo.aberta),
        ]),
      );
      await tester.pumpWidget(_comRouter(svc));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('minhas-vagas-filtro-canceladas')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('minhas-vagas-vazio-filtro')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('minhas-vagas-vazio')), findsNothing);
      expect(
        find.text('Nenhuma vaga cancelada. Troque o filtro para ver outras.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'filtroInicial via query param abre já filtrado (deep-link CA-3)',
    (tester) async {
      final svc = _FakeVagaService(
        minhasResult: () => MinhasVagasSuccess([
          _vaga(id: '1', estado: VagaEstadoResumo.aberta),
          _vaga(id: '2', estado: VagaEstadoResumo.cancelada),
        ]),
      );
      await tester.pumpWidget(_comRouter(svc, filtroInicial: 'canceladas'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('vaga-card-2')), findsOneWidget);
      expect(find.byKey(const Key('vaga-card-1')), findsNothing);
    },
  );

  // ───────────────── CA-4 — cancelar com diálogo ─────────────────

  testWidgets('cancelar abre diálogo com contagem real de candidatos (CA-4)', (
    tester,
  ) async {
    final svc = _FakeVagaService(
      minhasResult: () => MinhasVagasSuccess([_vaga(id: '1', pendentes: 2)]),
    );
    await tester.pumpWidget(_comRouter(svc));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('vaga-card-1-cancelar-btn')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('vaga-cancelar-dialog')), findsOneWidget);
    expect(
      find.text(
        '2 candidatos serão notificados do cancelamento. Esta ação não pode ser desfeita.',
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'diálogo sem pendentes usa a copy de "Nenhum candidato" (CA-4 borda)',
    (tester) async {
      final svc = _FakeVagaService(
        minhasResult: () => MinhasVagasSuccess([_vaga(id: '1', pendentes: 0)]),
      );
      await tester.pumpWidget(_comRouter(svc));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('vaga-card-1-cancelar-btn')));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Nenhum candidato será notificado. Esta ação não pode ser desfeita.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('"Manter vaga" fecha o diálogo sem cancelar (CA-4)', (
    tester,
  ) async {
    final svc = _FakeVagaService(
      minhasResult: () => MinhasVagasSuccess([_vaga(id: '1')]),
    );
    await tester.pumpWidget(_comRouter(svc));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('vaga-card-1-cancelar-btn')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('vaga-cancelar-manter-btn')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('vaga-cancelar-dialog')), findsNothing);
    expect(svc.cancelarCalls, 0);
  });

  testWidgets('confirmar cancelamento → vaga vira cancelada + toast (CA-4)', (
    tester,
  ) async {
    final svc = _FakeVagaService(
      minhasResult: () => MinhasVagasSuccess([_vaga(id: '1', pendentes: 1)]),
      cancelarResult: () => CancelarSuccess(),
    );
    await tester.pumpWidget(_comRouter(svc, filtroInicial: 'todas'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('vaga-card-1-cancelar-btn')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('vaga-cancelar-confirmar-btn')));
    await tester.pump(); // resolve o cancelar (microtask)
    await tester.pump(
      const Duration(seconds: 1),
    ); // fecha o diálogo + insere o toast

    expect(svc.cancelarCalls, 1);
    expect(svc.ultimaVagaCancelada, '1');
    expect(find.byKey(const Key('vaga-cancelada-toast')), findsOneWidget);
    // O selo vira "Cancelada" e o botão cancelar some.
    expect(find.text('Cancelada'), findsOneWidget);
    expect(find.byKey(const Key('vaga-card-1-cancelar-btn')), findsNothing);
  });

  testWidgets('cancelamento com 409 não muda o card e mostra erro', (
    tester,
  ) async {
    final svc = _FakeVagaService(
      minhasResult: () => MinhasVagasSuccess([_vaga(id: '1')]),
      cancelarResult: () => CancelarConflict(),
    );
    await tester.pumpWidget(_comRouter(svc));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('vaga-card-1-cancelar-btn')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('vaga-cancelar-confirmar-btn')));
    await tester.pump(); // resolve o cancelar (microtask)
    await tester.pump(
      const Duration(seconds: 1),
    ); // fecha o diálogo + insere o aviso

    expect(
      find.text('Esta vaga não pode mais ser cancelada. Atualize a lista.'),
      findsOneWidget,
    );
    // Card permanece aberta (botão cancelar ainda presente).
    expect(find.byKey(const Key('vaga-card-1-cancelar-btn')), findsOneWidget);
  });
}
