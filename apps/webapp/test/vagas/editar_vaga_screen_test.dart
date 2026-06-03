import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:turni_webapp/ds/theme.dart';
import 'package:turni_webapp/features/auth/auth_service.dart';
import 'package:turni_webapp/features/vagas/editar_vaga_screen.dart';
import 'package:turni_webapp/features/vagas/vaga_service.dart';

// STORY-052 — widget tests da EditarVagaScreen (SCREEN-052, surface A).
// CA-1 (sem permissão), CA-10 (form pré-preenchido + preview do diff + aviso de candidatos),
// §4.3 (nada mudou), §4.4 (erro de rede no submit, 409 não editável), sucesso → toast.

class _FakeVagaService extends VagaService {
  _FakeVagaService({this.carregar, this.funcoes = const [], this.editarResult});

  CarregarEdicaoResult Function()? carregar;
  final List<Funcao> funcoes;
  EditarResult Function()? editarResult;

  int editarCalls = 0;
  double? ultimoValor;

  @override
  Future<CarregarEdicaoResult> fetchEditar(String vagaId) async =>
      carregar?.call() ?? CarregarEdicaoError();

  @override
  Future<List<Funcao>> fetchFuncoes() async => funcoes;

  @override
  Future<EditarResult> editar(
    String vagaId, {
    required String funcaoId,
    required DateTime dataInicio,
    required DateTime dataFim,
    required double valor,
    required int posicoes,
    String? observacoes,
  }) async {
    editarCalls++;
    ultimoValor = valor;
    return editarResult?.call() ??
        EditarSuccess(material: true, candidatosNotificados: 3, diff: const []);
  }
}

const _funcoes = [
  Funcao(id: '1', nome: 'Garçom'),
  Funcao(id: '2', nome: 'Cozinheiro'),
];

VagaEditar _vagaEditar({int candidatos = 3, bool editavel = true}) =>
    VagaEditar(
      id: '7',
      editavel: editavel,
      funcaoId: '1',
      dataInicio: DateTime(2026, 6, 12, 18),
      dataFim: DateTime(2026, 6, 12, 23),
      valor: 120.0,
      posicoes: 2,
      observacoes: 'Avental preto.',
      candidatosEmRevisao: candidatos,
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

void _entrarProfissional() {
  AuthService().debugSetSession(
    const UserSession(
      role: 'profissional',
      status: 'ativo',
      welcomeVisto: true,
      cadastroCompleto: true,
    ),
  );
}

String? _toastMostrado;

Widget _comRouter(_FakeVagaService svc) {
  _toastMostrado = null;
  final router = GoRouter(
    initialLocation: '/editar',
    routes: [
      GoRoute(
        path: '/editar',
        builder: (_, _) => EditarVagaScreen(vagaId: '7', service: svc),
      ),
      GoRoute(
        path: '/contratante/vagas',
        builder: (_, s) {
          _toastMostrado = s.extra as String?;
          return const Scaffold(body: Text('Minhas vagas'));
        },
      ),
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: Text('home')),
      ),
    ],
  );
  return MaterialApp.router(theme: buildLightTheme(), routerConfig: router);
}

Future<void> _tapRevisar(WidgetTester tester) async {
  final btn = find.byKey(const Key('editar-vaga-revisar-btn'));
  await tester.ensureVisible(btn);
  await tester.pumpAndSettle();
  await tester.tap(btn);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('CA-1 — profissional vê "sem permissão"', (tester) async {
    _entrarProfissional();
    await tester.pumpWidget(_comRouter(_FakeVagaService()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('editar-vaga-sem-permissao')), findsOneWidget);
    expect(find.byKey(const Key('editar-vaga-revisar-btn')), findsNothing);
  });

  testWidgets(
    'CA-10 — carrega valores atuais no form (valor 120 → R\$ 120,00)',
    (tester) async {
      _entrarContratante();
      await tester.pumpWidget(
        _comRouter(
          _FakeVagaService(
            carregar: () => CarregarEdicaoSuccess(_vagaEditar()),
            funcoes: _funcoes,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('editar-vaga-revisar-btn')), findsOneWidget);
      expect(find.text('R\$ 120,00'), findsOneWidget);
      expect(find.text('Avental preto.'), findsOneWidget);
    },
  );

  testWidgets(
    '§4.3 — "Revisar" sem mudar nada mostra aviso e não abre confirmação',
    (tester) async {
      _entrarContratante();
      await tester.pumpWidget(
        _comRouter(
          _FakeVagaService(
            carregar: () => CarregarEdicaoSuccess(_vagaEditar()),
            funcoes: _funcoes,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await _tapRevisar(tester);

      expect(find.byKey(const Key('editar-vaga-nada-mudou')), findsOneWidget);
      expect(
        find.byKey(const Key('editar-vaga-confirmar-sheet')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'CA-10 — mudar valor abre confirmação com diff + aviso de candidatos',
    (tester) async {
      _entrarContratante();
      final svc = _FakeVagaService(
        carregar: () => CarregarEdicaoSuccess(_vagaEditar(candidatos: 3)),
        funcoes: _funcoes,
      );
      await tester.pumpWidget(_comRouter(svc));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('editar-vaga-valor')),
        '15000',
      );
      await tester.pump();
      await _tapRevisar(tester);

      expect(
        find.byKey(const Key('editar-vaga-confirmar-sheet')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('editar-vaga-diff-valor')), findsOneWidget);
      expect(find.textContaining('R\$ 120,00 → R\$ 150,00'), findsOneWidget);
      expect(
        find.textContaining('3 candidatos pendentes vão ser avisados'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'confirmar com sucesso → PATCH chamado e vai p/ Minhas vagas com toast',
    (tester) async {
      _entrarContratante();
      final svc = _FakeVagaService(
        carregar: () => CarregarEdicaoSuccess(_vagaEditar(candidatos: 3)),
        funcoes: _funcoes,
        editarResult: () => EditarSuccess(
          material: true,
          candidatosNotificados: 3,
          diff: const [],
        ),
      );
      await tester.pumpWidget(_comRouter(svc));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('editar-vaga-valor')),
        '15000',
      );
      await tester.pump();
      await _tapRevisar(tester);
      await tester.tap(find.byKey(const Key('editar-vaga-confirmar-btn')));
      await tester.pumpAndSettle();

      expect(svc.editarCalls, 1);
      expect(svc.ultimoValor, 150.0);
      expect(find.text('Minhas vagas'), findsOneWidget);
      expect(_toastMostrado, contains('3 candidatos foram avisados'));
    },
  );

  testWidgets(
    '§4.4 — erro de rede no confirmar mostra banner e mantém a confirmação',
    (tester) async {
      _entrarContratante();
      final svc = _FakeVagaService(
        carregar: () => CarregarEdicaoSuccess(_vagaEditar()),
        funcoes: _funcoes,
        editarResult: () => EditarServerError(),
      );
      await tester.pumpWidget(_comRouter(svc));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('editar-vaga-valor')),
        '15000',
      );
      await tester.pump();
      await _tapRevisar(tester);
      await tester.tap(find.byKey(const Key('editar-vaga-confirmar-btn')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('editar-vaga-erro-rede')), findsOneWidget);
      expect(
        find.byKey(const Key('editar-vaga-confirmar-sheet')),
        findsOneWidget,
      );
    },
  );

  testWidgets('§4.4 — 409 ao confirmar mostra "não pode mais ser editada"', (
    tester,
  ) async {
    _entrarContratante();
    final svc = _FakeVagaService(
      carregar: () => CarregarEdicaoSuccess(_vagaEditar()),
      funcoes: _funcoes,
      editarResult: () => EditarConflict(),
    );
    await tester.pumpWidget(_comRouter(svc));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('editar-vaga-valor')), '15000');
    await tester.pump();
    await _tapRevisar(tester);
    await tester.tap(find.byKey(const Key('editar-vaga-confirmar-btn')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('editar-vaga-erro-409')), findsOneWidget);
  });

  testWidgets('vaga não editável no load cai direto no estado 409', (
    tester,
  ) async {
    _entrarContratante();
    await tester.pumpWidget(
      _comRouter(
        _FakeVagaService(
          carregar: () => CarregarEdicaoSuccess(_vagaEditar(editavel: false)),
          funcoes: _funcoes,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('editar-vaga-erro-409')), findsOneWidget);
    expect(find.byKey(const Key('editar-vaga-revisar-btn')), findsNothing);
  });

  testWidgets('erro ao carregar mostra retry; retry recarrega o form', (
    tester,
  ) async {
    _entrarContratante();
    var falhar = true;
    final svc = _FakeVagaService(funcoes: _funcoes);
    svc.carregar = () =>
        falhar ? CarregarEdicaoError() : CarregarEdicaoSuccess(_vagaEditar());
    await tester.pumpWidget(_comRouter(svc));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('editar-vaga-retry-btn')), findsOneWidget);
    falhar = false;
    await tester.tap(find.byKey(const Key('editar-vaga-retry-btn')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('editar-vaga-revisar-btn')), findsOneWidget);
  });

  testWidgets('diff mostra várias linhas (data, posições, observações)', (
    tester,
  ) async {
    _entrarContratante();
    await tester.pumpWidget(
      _comRouter(
        _FakeVagaService(
          carregar: () => CarregarEdicaoSuccess(_vagaEditar()),
          funcoes: _funcoes,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('editar-vaga-valor')), '20000');
    final mais = find.byKey(const Key('editar-vaga-posicoes-mais'));
    await tester.ensureVisible(mais);
    await tester.tap(mais);
    await tester.enterText(
      find.byKey(const Key('editar-vaga-observacoes')),
      'Avental branco.',
    );
    await tester.pump();
    await _tapRevisar(tester);

    expect(find.byKey(const Key('editar-vaga-diff-valor')), findsOneWidget);
    expect(find.byKey(const Key('editar-vaga-diff-posicoes')), findsOneWidget);
    expect(
      find.byKey(const Key('editar-vaga-diff-observacoes')),
      findsOneWidget,
    );
  });

  testWidgets('desktop (≥1024) abre a confirmação centrada', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    _entrarContratante();
    await tester.pumpWidget(
      _comRouter(
        _FakeVagaService(
          carregar: () => CarregarEdicaoSuccess(_vagaEditar()),
          funcoes: _funcoes,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('editar-vaga-valor')), '15000');
    await tester.pump();
    await _tapRevisar(tester);

    expect(
      find.byKey(const Key('editar-vaga-confirmar-sheet')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('editar-vaga-confirmar-btn')), findsOneWidget);
  });

  testWidgets('aviso sem candidatos muda o texto', (tester) async {
    _entrarContratante();
    await tester.pumpWidget(
      _comRouter(
        _FakeVagaService(
          carregar: () => CarregarEdicaoSuccess(_vagaEditar(candidatos: 0)),
          funcoes: _funcoes,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('editar-vaga-valor')), '15000');
    await tester.pump();
    await _tapRevisar(tester);

    expect(find.textContaining('Ninguém se candidatou ainda'), findsOneWidget);
  });

  testWidgets(
    'regressão tz: horário vindo em UTC, sem mexer, NÃO vira edição material',
    (tester) async {
      _entrarContratante();
      // A API entrega o instante em UTC (app.timezone=UTC). O form exibe `.toLocal()` e o
      // submit reenvia o mesmo instante — abrir "Revisar" sem mexer deve dar "nada mudou".
      final vaga = VagaEditar(
        id: '7',
        editavel: true,
        funcaoId: '1',
        dataInicio: DateTime.utc(2026, 6, 12, 18),
        dataFim: DateTime.utc(2026, 6, 12, 23),
        valor: 120.0,
        posicoes: 2,
        observacoes: 'Avental preto.',
        candidatosEmRevisao: 3,
      );
      await tester.pumpWidget(
        _comRouter(
          _FakeVagaService(
            carregar: () => CarregarEdicaoSuccess(vaga),
            funcoes: _funcoes,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await _tapRevisar(tester);

      expect(find.byKey(const Key('editar-vaga-nada-mudou')), findsOneWidget);
      expect(
        find.byKey(const Key('editar-vaga-confirmar-sheet')),
        findsNothing,
      );
    },
  );
}
