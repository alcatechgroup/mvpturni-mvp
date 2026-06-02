import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:turni_webapp/ds/theme.dart';
import 'package:turni_webapp/features/auth/auth_service.dart';
import 'package:turni_webapp/features/vagas/minhas_vagas_placeholder_screen.dart';
import 'package:turni_webapp/features/vagas/publicar_vaga_screen.dart';
import 'package:turni_webapp/features/vagas/vaga_service.dart';

// STORY-046 — widget tests da PublicarVagaScreen.
// CA-1 (sem permissão p/ profissional), CA-5 (gate PDR-005), CA-2 (validação),
// CA-3 (fim > início), CA-7 (sucesso → Minhas vagas + toast), §4.7 (erro de servidor).

class _FakeVagaService extends VagaService {
  _FakeVagaService({this.gate, this.funcoes = const [], this.publicarResult});

  final GatePublicacao? gate;
  final List<Funcao> funcoes;
  PublicarResult Function()? publicarResult;

  int publicarCalls = 0;
  int? ultimaFuncao;
  double? ultimoValor;
  int? ultimasPosicoes;
  DateTime? ultimoInicio;
  DateTime? ultimoFim;

  @override
  Future<GatePublicacao?> fetchGate() async => gate;

  @override
  Future<List<Funcao>> fetchFuncoes() async => funcoes;

  @override
  Future<PublicarResult> publicar({
    required int funcaoId,
    required DateTime dataInicio,
    required DateTime dataFim,
    required double valor,
    required int posicoes,
    String? observacoes,
  }) async {
    publicarCalls++;
    ultimaFuncao = funcaoId;
    ultimoValor = valor;
    ultimasPosicoes = posicoes;
    ultimoInicio = dataInicio;
    ultimoFim = dataFim;
    return publicarResult?.call() ?? PublicarSuccess(7, 'aberta');
  }
}

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

Widget _comRouter(_FakeVagaService svc) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => PublicarVagaScreen(service: svc),
      ),
      GoRoute(
        path: '/contratante/vagas',
        builder: (_, s) =>
            MinhasVagasPlaceholderScreen(successMessage: s.extra as String?),
      ),
    ],
  );
  return MaterialApp.router(theme: buildLightTheme(), routerConfig: router);
}

const _funcoes = [
  Funcao(id: 1, nome: 'Bartender'),
  Funcao(id: 2, nome: 'Garçom'),
];

Future<void> _tapPublicar(WidgetTester tester) async {
  final btn = find.byKey(const Key('publicar-vaga-submit-btn'));
  await tester.ensureVisible(btn);
  await tester.pumpAndSettle();
  await tester.tap(btn);
  await tester.pumpAndSettle();
}

Future<void> _preencherValido(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('publicar-vaga-funcao-dropdown')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Bartender').last);
  await tester.pumpAndSettle();
  await tester.enterText(
    find.byKey(const Key('publicar-vaga-data-inicio')),
    '12/06/2026',
  );
  await tester.enterText(
    find.byKey(const Key('publicar-vaga-hora-inicio')),
    '18:00',
  );
  await tester.enterText(
    find.byKey(const Key('publicar-vaga-data-fim')),
    '12/06/2026',
  );
  await tester.enterText(
    find.byKey(const Key('publicar-vaga-hora-fim')),
    '23:00',
  );
  await tester.enterText(find.byKey(const Key('publicar-vaga-valor')), '15000');
  await tester.pump();
}

void main() {
  testWidgets('CA-1 — profissional vê "sem permissão", sem formulário', (
    tester,
  ) async {
    _entrarProfissional();
    await tester.pumpWidget(
      _comRouter(_FakeVagaService(gate: const GatePublicacao(pending: 0))),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('publicar-vaga-sem-permissao')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('publicar-vaga-funcao-dropdown')),
      findsNothing,
    );
  });

  testWidgets(
    'CA-5 — gate PDR-005 com pending>0 mostra aviso e bloqueia o form',
    (tester) async {
      _entrarContratante();
      await tester.pumpWidget(
        _comRouter(_FakeVagaService(gate: const GatePublicacao(pending: 2))),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('publicar-vaga-gate')), findsOneWidget);
      expect(find.textContaining('2 turnos finalizados'), findsOneWidget);
      expect(
        find.byKey(const Key('publicar-vaga-gate-avaliar-btn')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('publicar-vaga-funcao-dropdown')),
        findsNothing,
      );
    },
  );

  testWidgets('CA-5 — gate com pending=0 renderiza o formulário', (
    tester,
  ) async {
    _entrarContratante();
    await tester.pumpWidget(
      _comRouter(
        _FakeVagaService(
          gate: const GatePublicacao(pending: 0),
          funcoes: _funcoes,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('publicar-vaga-funcao-dropdown')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('publicar-vaga-valor')), findsOneWidget);
    expect(find.byKey(const Key('publicar-vaga-gate')), findsNothing);
  });

  testWidgets('CA-2 — submeter vazio mostra erros de campo', (tester) async {
    _entrarContratante();
    await tester.pumpWidget(
      _comRouter(
        _FakeVagaService(
          gate: const GatePublicacao(pending: 0),
          funcoes: _funcoes,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _tapPublicar(tester);

    expect(find.text('Escolha a função do turno.'), findsOneWidget);
    expect(find.text('Informe quando o turno começa.'), findsOneWidget);
    expect(find.text('Informe o valor por turno.'), findsOneWidget);
  });

  testWidgets('CA-3 — fim ≤ início mostra erro e não publica', (tester) async {
    _entrarContratante();
    final svc = _FakeVagaService(
      gate: const GatePublicacao(pending: 0),
      funcoes: _funcoes,
    );
    await tester.pumpWidget(_comRouter(svc));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('publicar-vaga-funcao-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bartender').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('publicar-vaga-data-inicio')),
      '12/06/2026',
    );
    await tester.enterText(
      find.byKey(const Key('publicar-vaga-hora-inicio')),
      '20:00',
    );
    await tester.enterText(
      find.byKey(const Key('publicar-vaga-data-fim')),
      '12/06/2026',
    );
    await tester.enterText(
      find.byKey(const Key('publicar-vaga-hora-fim')),
      '19:00',
    );
    await tester.enterText(
      find.byKey(const Key('publicar-vaga-valor')),
      '15000',
    );
    await tester.pump();

    await _tapPublicar(tester);

    expect(find.text('O fim precisa ser depois do início.'), findsOneWidget);
    expect(svc.publicarCalls, 0);
  });

  testWidgets('CA-7 — sucesso publica e navega para Minhas vagas com toast', (
    tester,
  ) async {
    _entrarContratante();
    final svc = _FakeVagaService(
      gate: const GatePublicacao(pending: 0),
      funcoes: _funcoes,
    );
    await tester.pumpWidget(_comRouter(svc));
    await tester.pumpAndSettle();

    await _preencherValido(tester);
    await _tapPublicar(tester);

    expect(svc.publicarCalls, 1);
    expect(svc.ultimaFuncao, 1);
    expect(svc.ultimoValor, 150.0);
    expect(svc.ultimasPosicoes, 1);
    expect(svc.ultimoInicio, DateTime(2026, 6, 12, 18, 0));
    expect(svc.ultimoFim, DateTime(2026, 6, 12, 23, 0));

    // Navegou para o placeholder de Minhas vagas com o toast (CA-7).
    expect(find.text('Vaga publicada'), findsWidgets);
    expect(
      find.byKey(const Key('publicar-vaga-sucesso-toast')),
      findsOneWidget,
    );
  });

  testWidgets('§4.7 — erro de servidor mostra banner e preserva o form', (
    tester,
  ) async {
    _entrarContratante();
    final svc = _FakeVagaService(
      gate: const GatePublicacao(pending: 0),
      funcoes: _funcoes,
      publicarResult: () => PublicarServerError(),
    );
    await tester.pumpWidget(_comRouter(svc));
    await tester.pumpAndSettle();

    await _preencherValido(tester);
    await _tapPublicar(tester);

    expect(find.byKey(const Key('publicar-vaga-erro-banner')), findsOneWidget);
    expect(
      find.byKey(const Key('publicar-vaga-funcao-dropdown')),
      findsOneWidget,
    );
  });

  testWidgets('erro ao carregar o gate mostra retry', (tester) async {
    _entrarContratante();
    await tester.pumpWidget(_comRouter(_FakeVagaService(gate: null)));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('publicar-vaga-retry-btn')), findsOneWidget);
  });
}
