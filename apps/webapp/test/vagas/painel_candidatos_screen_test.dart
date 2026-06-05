import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:turni_webapp/ds/theme.dart';
import 'package:turni_webapp/features/vagas/candidatos_service.dart';
import 'package:turni_webapp/features/vagas/painel_candidatos_screen.dart';
import 'package:turni_webapp/features/vagas/vaga_detalhe_service.dart'
    show BreakdownLinha, ComponenteMatch, EstadoComponente, ScoreBreakdown;

// STORY-051 — widget tests da PainelCandidatosScreen (SCREEN-051).
// CA-2 (ordem ranqueada renderizada), CA-3 (avatar/nome/função/nível/score), CA-4 (toggle do
// breakdown reusando BreakdownRow), CA-5 (badge de habitualidade), CA-6 (ações desabilitadas),
// CA-7 (vazio com SLA), CA-1 (sem permissão / 404), estados loading/erro.

class _FakeService extends CandidatosService {
  _FakeService({this.result, this.delay});

  CandidatosResult Function()? result;
  final Duration? delay;
  int calls = 0;

  @override
  Future<CandidatosResult> fetch(String vagaId) async {
    calls++;
    if (delay != null) await Future<void>.delayed(delay!);
    return result?.call() ?? CandidatosError();
  }
}

ScoreBreakdown _score(int total) => ScoreBreakdown(
  total: total,
  linhas: const [
    BreakdownLinha(
      componente: ComponenteMatch.funcao,
      pontos: 40,
      pontosMax: 40,
      estado: EstadoComponente.ok,
      descricao: 'Função primária bate',
    ),
    BreakdownLinha(
      componente: ComponenteMatch.distancia,
      pontos: 14,
      pontosMax: 20,
      estado: EstadoComponente.partial,
      descricao: 'A 6 km',
    ),
    BreakdownLinha(
      componente: ComponenteMatch.historico,
      pontos: 26,
      pontosMax: 30,
      estado: EstadoComponente.partial,
      descricao: 'Média 4,7 em 64 turnos',
    ),
    BreakdownLinha(
      componente: ComponenteMatch.nivel,
      pontos: 6,
      pontosMax: 10,
      estado: EstadoComponente.partial,
      descricao: 'Destaque na trilha',
    ),
  ],
);

CandidatoCard _cand({
  String id = '1',
  String nome = 'Júlia Santos',
  String? funcao = 'Garçom',
  String? nivel = 'Elite',
  int? score = 92,
  bool comBreakdown = true,
  bool alerta = false,
  String? foto,
}) => CandidatoCard(
  id: id,
  profissional: PerfilCandidato(
    id: 'p',
    nome: nome,
    fotoUrl: foto,
    funcaoPrimaria: funcao,
    nivel: nivel,
    scoreHistorico: 4.9,
    plano: null,
  ),
  scoreNoMomento: score,
  score: comBreakdown && score != null ? _score(score) : null,
  candidatouEm: DateTime(2026, 6, 12, 14, 20),
  alertaHabitualidade: alerta,
);

Widget _comRouter(_FakeService svc) {
  final router = GoRouter(
    initialLocation: '/contratante/vagas/7/candidatos',
    routes: [
      GoRoute(
        path: '/contratante/vagas/:id/candidatos',
        builder: (_, _) => PainelCandidatosScreen(
          vagaId: '7',
          funcao: 'Garçom',
          dataInicio: DateTime(2026, 6, 12, 18),
          dataFim: DateTime(2026, 6, 12, 23),
          service: svc,
        ),
      ),
      GoRoute(
        path: '/contratante/vagas',
        builder: (_, _) => const Scaffold(body: Text('MINHAS VAGAS')),
      ),
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: Text('HOME')),
      ),
    ],
  );
  return MaterialApp.router(theme: buildLightTheme(), routerConfig: router);
}

Future<void> _pump(WidgetTester tester, _FakeService svc) async {
  await tester.pumpWidget(_comRouter(svc));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('loading mostra skeleton antes do fetch (CA / §4.2)', (
    tester,
  ) async {
    final svc = _FakeService(
      result: () => CandidatosSuccess([_cand()], 1),
      delay: const Duration(milliseconds: 50),
    );
    await tester.pumpWidget(_comRouter(svc));
    await tester.pump(); // initState dispara o fetch; ainda em loading.

    expect(find.byKey(const Key('painel-candidatos-skeleton')), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('painel-candidatos-skeleton')), findsNothing);
  });

  testWidgets(
    'lista renderiza os candidatos com nome, função, nível e score (CA-3)',
    (tester) async {
      final svc = _FakeService(
        result: () => CandidatosSuccess([
          _cand(id: '1', nome: 'Júlia Santos', score: 92),
          _cand(
            id: '2',
            nome: 'Bruno Costa',
            funcao: 'Cozinheiro',
            nivel: 'Destaque',
            score: 88,
          ),
        ], 2),
      );
      await _pump(tester, svc);

      expect(find.byKey(const Key('painel-candidatos-lista')), findsOneWidget);
      expect(find.byKey(const Key('candidato-card-1')), findsOneWidget);
      expect(find.byKey(const Key('candidato-card-2')), findsOneWidget);
      expect(find.text('Júlia Santos'), findsOneWidget);
      expect(find.text('Bruno Costa'), findsOneWidget);
      expect(find.text('92/100'), findsOneWidget);
      expect(find.text('88/100'), findsOneWidget);
      // Função + nível.
      expect(find.byKey(const Key('candidato-card-1-nivel')), findsOneWidget);
      expect(find.text('Elite'), findsOneWidget);
      expect(find.text('Destaque'), findsOneWidget);
      // Faixa de contexto com função + contagem.
      expect(
        find.byKey(const Key('painel-candidatos-contexto')),
        findsOneWidget,
      );
      expect(find.text('2 candidatos'), findsOneWidget);
    },
  );

  testWidgets('a ordem ranqueada é renderizada como veio do serviço (CA-2)', (
    tester,
  ) async {
    final svc = _FakeService(
      result: () => CandidatosSuccess([
        _cand(id: '1', nome: 'Alta', score: 92),
        _cand(id: '2', nome: 'Media', score: 88),
        _cand(id: '3', nome: 'Baixa', score: 71),
      ], 3),
    );
    await _pump(tester, svc);

    final cards = tester.widgetList<Container>(
      find.byKey(const Key('candidato-card-1')),
    );
    expect(cards, isNotEmpty);
    // Posição vertical crescente = ordem da lista (sem reordenar no cliente).
    final yAlta = tester.getTopLeft(find.text('Alta')).dy;
    final yMedia = tester.getTopLeft(find.text('Media')).dy;
    final yBaixa = tester.getTopLeft(find.text('Baixa')).dy;
    expect(yAlta, lessThan(yMedia));
    expect(yMedia, lessThan(yBaixa));
  });

  testWidgets(
    'toggle expande e colapsa o breakdown reusando BreakdownRow (CA-4)',
    (tester) async {
      final svc = _FakeService(
        result: () => CandidatosSuccess([_cand(id: '1')], 1),
      );
      await _pump(tester, svc);

      // Colapsado: bloco ausente.
      expect(find.byKey(const Key('candidato-card-1-breakdown')), findsNothing);
      expect(find.text('Ver breakdown'), findsOneWidget);

      await tester.tap(
        find.byKey(const Key('candidato-card-1-breakdown-toggle')),
      );
      await tester.pumpAndSettle();

      // Expandido: bloco + as 4 linhas (BreakdownRow usa as keys vaga-detalhe-breakdown-*).
      expect(
        find.byKey(const Key('candidato-card-1-breakdown')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('vaga-detalhe-breakdown-funcao')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('vaga-detalhe-breakdown-distancia')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('vaga-detalhe-breakdown-historico')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('vaga-detalhe-breakdown-nivel')),
        findsOneWidget,
      );
      expect(find.text('Ocultar breakdown'), findsOneWidget);

      await tester.tap(
        find.byKey(const Key('candidato-card-1-breakdown-toggle')),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('candidato-card-1-breakdown')), findsNothing);
    },
  );

  testWidgets(
    'candidato sem snapshot não mostra o toggle do breakdown (borda)',
    (tester) async {
      final svc = _FakeService(
        result: () => CandidatosSuccess([
          _cand(id: '1', comBreakdown: false, score: null),
        ], 1),
      );
      await _pump(tester, svc);

      expect(
        find.byKey(const Key('candidato-card-1-breakdown-toggle')),
        findsNothing,
      );
      expect(find.byKey(const Key('candidato-card-1-score-bar')), findsNothing);
    },
  );

  testWidgets('alerta de habitualidade mostra o badge (CA-5)', (tester) async {
    final svc = _FakeService(
      result: () => CandidatosSuccess([_cand(id: '1', alerta: true)], 1),
    );
    await _pump(tester, svc);

    expect(
      find.byKey(const Key('candidato-card-1-habitualidade')),
      findsOneWidget,
    );
    expect(find.textContaining('Habitualidade'), findsOneWidget);
  });

  testWidgets('sem alerta não renderiza o badge de habitualidade', (
    tester,
  ) async {
    final svc = _FakeService(
      result: () => CandidatosSuccess([_cand(id: '1')], 1),
    );
    await _pump(tester, svc);

    expect(
      find.byKey(const Key('candidato-card-1-habitualidade')),
      findsNothing,
    );
  });

  // STORY-058 atualizou o CA-6 da 051: "Aceitar" agora está HABILITADO (abre o D1 — fluxo
  // coberto em aprovar_candidatura_test.dart); "Remover" segue desabilitado (Lacuna MVP).
  testWidgets('aceitar habilitado (STORY-058); remover segue desabilitado', (
    tester,
  ) async {
    final svc = _FakeService(
      result: () => CandidatosSuccess([_cand(id: '1')], 1),
    );
    await _pump(tester, svc);

    final aceitar = tester.widget<FilledButton>(
      find.byKey(const Key('candidato-card-1-aceitar-btn')),
    );
    final remover = tester.widget<TextButton>(
      find.byKey(const Key('candidato-card-1-remover-btn')),
    );
    expect(aceitar.onPressed, isNotNull);
    expect(remover.onPressed, isNull);
  });

  testWidgets('vazio mostra estado com SLA prometido (CA-7)', (tester) async {
    final svc = _FakeService(result: () => CandidatosSuccess(const [], 0));
    await _pump(tester, svc);

    expect(find.byKey(const Key('painel-candidatos-vazio')), findsOneWidget);
    expect(find.text('Ainda sem candidatos'), findsOneWidget);
    expect(find.textContaining('em até 2h'), findsOneWidget);
    // A faixa mostra "Nenhum candidato ainda".
    expect(find.text('Nenhum candidato ainda'), findsOneWidget);
  });

  testWidgets('403 cai em sem permissão (CA-1)', (tester) async {
    final svc = _FakeService(result: () => CandidatosForbidden());
    await _pump(tester, svc);

    expect(
      find.byKey(const Key('painel-candidatos-sem-permissao')),
      findsOneWidget,
    );
    expect(find.text('Esta área é do contratante dono'), findsOneWidget);
  });

  testWidgets('404 cai em vaga não encontrada', (tester) async {
    final svc = _FakeService(result: () => CandidatosNotFound());
    await _pump(tester, svc);

    expect(
      find.byKey(const Key('painel-candidatos-nao-encontrada')),
      findsOneWidget,
    );
  });

  testWidgets('erro de rede mostra retry e re-busca (estado erro)', (
    tester,
  ) async {
    var primeiro = true;
    final svc = _FakeService(
      result: () =>
          primeiro ? CandidatosError() : CandidatosSuccess([_cand(id: '1')], 1),
    );
    await _pump(tester, svc);

    expect(find.byKey(const Key('painel-candidatos-erro')), findsOneWidget);

    primeiro = false;
    await tester.tap(find.byKey(const Key('painel-candidatos-retry-btn')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('painel-candidatos-erro')), findsNothing);
    expect(find.byKey(const Key('candidato-card-1')), findsOneWidget);
    expect(svc.calls, 2);
  });

  testWidgets('voltar navega para minhas vagas quando não há pilha', (
    tester,
  ) async {
    final svc = _FakeService(
      result: () => CandidatosSuccess([_cand(id: '1')], 1),
    );
    await _pump(tester, svc);

    await tester.tap(find.byKey(const Key('painel-candidatos-voltar-btn')));
    await tester.pumpAndSettle();

    expect(find.text('MINHAS VAGAS'), findsOneWidget);
  });
}
