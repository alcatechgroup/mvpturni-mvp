import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:turni_webapp/ds/theme.dart';
import 'package:turni_webapp/features/auth/auth_service.dart';
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
  String? ultimaFuncao;
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
    required String funcaoId,
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
    return publicarResult?.call() ?? PublicarSuccess('7', 'aberta');
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
      // Destino pós-publicação (STORY-047). Stub local que só exibe o toast de sucesso,
      // para este teste de PublicarVagaScreen não depender da tela de Minhas vagas real.
      GoRoute(
        path: '/contratante/vagas',
        builder: (_, s) => _ToastStub(message: s.extra as String?),
      ),
    ],
  );
  return MaterialApp.router(theme: buildLightTheme(), routerConfig: router);
}

const _funcoes = [
  Funcao(id: '1', nome: 'Bartender'),
  Funcao(id: '2', nome: 'Garçom'),
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
    expect(svc.ultimaFuncao, '1');
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

  testWidgets(
    'exibe a duração precisa do turno quando início e fim são válidos',
    (tester) async {
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

      // Sem datas: nenhum hint de duração.
      expect(find.byKey(const Key('publicar-vaga-duracao')), findsNothing);

      // 18:00 → 23:00 = 5h.
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
      await tester.pump();
      expect(find.byKey(const Key('publicar-vaga-duracao')), findsOneWidget);
      expect(find.text('A vaga dura 5h.'), findsOneWidget);

      // Ajusta o fim para 20:30 → 2h30 (atualiza em tempo real).
      await tester.enterText(
        find.byKey(const Key('publicar-vaga-hora-fim')),
        '20:30',
      );
      await tester.pump();
      expect(find.text('A vaga dura 2h30.'), findsOneWidget);

      // Fim ≤ início → sem duração (e o erro do CA-3 cuida disso no submit).
      await tester.enterText(
        find.byKey(const Key('publicar-vaga-hora-fim')),
        '17:00',
      );
      await tester.pump();
      expect(find.byKey(const Key('publicar-vaga-duracao')), findsNothing);
    },
  );

  testWidgets('CA-4 — digitar um termo filtra as funções no seletor', (
    tester,
  ) async {
    _entrarContratante();
    await tester.pumpWidget(
      _comRouter(
        _FakeVagaService(
          gate: const GatePublicacao(pending: 0),
          funcoes: const [
            Funcao(id: '1', nome: 'Bartender'),
            Funcao(id: '2', nome: 'Garçom'),
            Funcao(id: '3', nome: 'Barista'),
            Funcao(id: '4', nome: 'Cozinheiro'),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Abre o menu — todas as funções aparecem.
    await tester.tap(find.byKey(const Key('publicar-vaga-funcao-dropdown')));
    await tester.pumpAndSettle();
    expect(find.text('Garçom'), findsWidgets);
    expect(find.text('Cozinheiro'), findsWidgets);

    // Digita "bar" no campo do seletor → filtra para Bartender e Barista.
    final campoBusca = find.descendant(
      of: find.byKey(const Key('publicar-vaga-funcao-dropdown')),
      matching: find.byType(TextField),
    );
    await tester.enterText(campoBusca, 'bar');
    await tester.pumpAndSettle();

    expect(find.text('Bartender'), findsWidgets);
    expect(find.text('Barista'), findsWidgets);
    expect(find.text('Garçom'), findsNothing);
    expect(find.text('Cozinheiro'), findsNothing);
  });
}

/// Destino stub pós-publicação: mostra o texto da confirmação e dispara o toast com a
/// Key esperada (CA-7), sem acoplar este teste à tela real de Minhas vagas (STORY-047).
class _ToastStub extends StatefulWidget {
  const _ToastStub({this.message});
  final String? message;

  @override
  State<_ToastStub> createState() => _ToastStubState();
}

class _ToastStubState extends State<_ToastStub> {
  @override
  void initState() {
    super.initState();
    final msg = widget.message;
    if (msg != null && msg.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            key: const Key('publicar-vaga-sucesso-toast'),
            content: Text(msg),
            behavior: SnackBarBehavior.floating,
          ),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('Vaga publicada')));
}
