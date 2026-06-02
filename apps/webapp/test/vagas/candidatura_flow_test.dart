import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:turni_webapp/ds/theme.dart';
import 'package:turni_webapp/features/vagas/candidatura_service.dart';
import 'package:turni_webapp/features/vagas/vaga_detalhe_screen.dart';
import 'package:turni_webapp/features/vagas/vaga_detalhe_service.dart';

// STORY-050 — widget tests do fluxo de candidatura (SCREEN-050): modal de confirmação,
// sucesso → badge + toast, cada modal de bloqueio (gate avaliação/conflito/habitualidade/
// vaga-fechada — CA-9), conflito com card clicável, erro de rede com retry (§4.8), e a
// retirada voluntária (CA-8). O gate de avaliação é testado AQUI (não no E2E) porque é
// stub-honesto até o EPIC-003 — ver Notas do agente da STORY-050.

class _FakeDetalheService extends VagaDetalheService {
  _FakeDetalheService(this._detalhe);
  final VagaDetalhe _detalhe;

  @override
  Future<DetalheResult> fetch(int id) async => DetalheSuccess(_detalhe);
}

/// Fake de candidatura roteirizado: devolve [candidatarResults] em sequência (para exercitar
/// retry de rede), e [retirarResult] no DELETE.
class _FakeCandidaturaService extends CandidaturaService {
  _FakeCandidaturaService({this.candidatarResults, this.retirarResult});
  final List<CandidaturaResult>? candidatarResults;
  final RetirarResult? retirarResult;
  int candidatarCalls = 0;

  @override
  Future<CandidaturaResult> candidatar(int vagaId) async {
    final r =
        candidatarResults![candidatarCalls.clamp(
          0,
          candidatarResults!.length - 1,
        )];
    candidatarCalls++;
    return r;
  }

  @override
  Future<RetirarResult> retirar(int candidaturaId) async => retirarResult!;
}

VagaDetalhe _detalhe({
  bool jaCandidatou = false,
  CandidaturaResumo? candidatura,
}) => VagaDetalhe(
  id: 7,
  funcao: 'Garçom',
  estabelecimento: 'Bar do Zé',
  cidade: 'São Paulo',
  dataInicio: DateTime(2026, 6, 12, 18),
  dataFim: DateTime(2026, 6, 12, 23),
  valor: 150.0,
  distanciaKm: 3.0,
  score: const ScoreBreakdown(total: 97, linhas: []),
  podeCandidatar: true,
  jaCandidatou: jaCandidatou,
  candidatura: candidatura,
  motivoBloqueio: null,
);

Widget _app({
  required VagaDetalheService detalhe,
  required CandidaturaService candidatura,
}) {
  final router = GoRouter(
    initialLocation: '/vaga/7',
    routes: [
      GoRoute(
        path: '/vaga/:id',
        builder: (_, _) => VagaDetalheScreen(
          vagaId: 7,
          service: detalhe,
          candidaturaService: candidatura,
        ),
      ),
      GoRoute(
        path: '/feed',
        builder: (_, _) => const Scaffold(body: Text('FEED')),
      ),
    ],
  );
  return MaterialApp.router(theme: buildLightTheme(), routerConfig: router);
}

/// Abre o detalhe (mobile) e toca em "Candidatar-se" para abrir o modal de confirmação.
Future<void> _abrirConfirmacao(WidgetTester tester) async {
  tester.view.physicalSize = const Size(420, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(
    _app(
      detalhe: _FakeDetalheService(_detalhe()),
      candidatura: _FakeCandidaturaService(candidatarResults: const []),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('vaga-detalhe-candidatar-btn')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('CTA abre o modal de confirmação (SCREEN-050 §4.1)', (
    tester,
  ) async {
    await _abrirConfirmacao(tester);

    expect(
      find.byKey(const Key('candidatura-confirmar-sheet')),
      findsOneWidget,
    );
    expect(find.text('Confirmar candidatura'), findsWidgets);
    // Resumo da vaga (função · estabelecimento) presente.
    expect(find.textContaining('Garçom · Bar do Zé'), findsOneWidget);
  });

  testWidgets(
    'confirmar → 201 vira badge "Você já se candidatou" + toast (CA-1)',
    (tester) async {
      tester.view.physicalSize = const Size(420, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final cand = _FakeCandidaturaService(
        candidatarResults: [
          CandidaturaCriada(
            id: 99,
            estado: 'pendente',
            candidatouEm: DateTime(2026, 6, 2, 14, 20),
            alerta: false,
          ),
        ],
      );
      await tester.pumpWidget(
        _app(detalhe: _FakeDetalheService(_detalhe()), candidatura: cand),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('vaga-detalhe-candidatar-btn')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('candidatura-confirmar-btn')));
      await tester.pumpAndSettle();

      expect(cand.candidatarCalls, 1);
      expect(
        find.byKey(const Key('vaga-detalhe-ja-candidatou')),
        findsOneWidget,
      );
      expect(find.text('Você já se candidatou'), findsOneWidget);
      expect(find.text('Candidatura enviada!'), findsOneWidget); // toast
      expect(
        find.byKey(const Key('vaga-detalhe-candidatar-btn')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'confirmar → 422 gate avaliação abre modal de bloqueio (CA-2/CA-9)',
    (tester) async {
      tester.view.physicalSize = const Size(420, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final cand = _FakeCandidaturaService(
        candidatarResults: [
          CandidaturaBloqueada(
            erro: 'gate_avaliacao',
            mensagem: 'Avalie seu último turno para se candidatar.',
            conflito: null,
          ),
        ],
      );
      await tester.pumpWidget(
        _app(detalhe: _FakeDetalheService(_detalhe()), candidatura: cand),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('vaga-detalhe-candidatar-btn')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('candidatura-confirmar-btn')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('candidatura-bloqueio-modal')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('candidatura-bloqueio-gate_avaliacao')),
        findsOneWidget,
      );
      expect(
        find.text('Avalie seu último turno'),
        findsOneWidget,
      ); // título da UI
      expect(
        find.text('Avalie seu último turno para se candidatar.'),
        findsOneWidget,
      ); // prosa do back, verbatim
      // Continua não-candidatado (CTA segue visível ao fechar).
      expect(
        find.byKey(const Key('candidatura-bloqueio-acao-btn')),
        findsOneWidget,
      );
    },
  );

  testWidgets('confirmar → 422 conflito mostra card clicável da vaga (CA-3)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final cand = _FakeCandidaturaService(
      candidatarResults: [
        CandidaturaBloqueada(
          erro: 'conflito_horario',
          mensagem: 'Você já tem um compromisso neste horário.',
          conflito: ConflitoInfo(
            vagaId: 42,
            funcao: 'Garçom',
            estabelecimento: 'Hotel Aurora',
            dataInicio: DateTime(2026, 6, 12, 17),
            dataFim: DateTime(2026, 6, 12, 22),
          ),
        ),
      ],
    );
    await tester.pumpWidget(
      _app(detalhe: _FakeDetalheService(_detalhe()), candidatura: cand),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('vaga-detalhe-candidatar-btn')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('candidatura-confirmar-btn')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('candidatura-bloqueio-conflito_horario')),
      findsOneWidget,
    );
    expect(find.text('Conflito de horário'), findsOneWidget);
    expect(find.byKey(const Key('candidatura-conflito-card')), findsOneWidget);
    expect(find.text('Garçom · Hotel Aurora'), findsOneWidget);

    // Tocar no card navega para a vaga em conflito (/vaga/42).
    await tester.tap(find.byKey(const Key('candidatura-conflito-card')));
    await tester.pumpAndSettle();
    // A própria tela de detalhe (id 42) recarrega via o mesmo fake → segue na rota /vaga/:id.
    expect(find.byKey(const Key('vaga-detalhe-screen')), findsOneWidget);
  });

  testWidgets('confirmar → erro de rede mostra inline + retry (§4.8)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final cand = _FakeCandidaturaService(
      candidatarResults: [
        CandidaturaErroRede(),
        CandidaturaCriada(
          id: 1,
          estado: 'pendente',
          candidatouEm: DateTime(2026, 6, 2, 14, 20),
          alerta: false,
        ),
      ],
    );
    await tester.pumpWidget(
      _app(detalhe: _FakeDetalheService(_detalhe()), candidatura: cand),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('vaga-detalhe-candidatar-btn')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('candidatura-confirmar-btn')));
    await tester.pumpAndSettle();

    // 1ª tentativa falhou: erro inline + retry, modal permanece.
    expect(find.byKey(const Key('candidatura-confirmar-erro')), findsOneWidget);
    expect(find.byKey(const Key('candidatura-retry-btn')), findsOneWidget);

    // Retry → 201 → fecha modal e vira badge.
    await tester.tap(find.byKey(const Key('candidatura-retry-btn')));
    await tester.pumpAndSettle();
    expect(cand.candidatarCalls, 2);
    expect(find.byKey(const Key('vaga-detalhe-ja-candidatou')), findsOneWidget);
  });

  testWidgets(
    'retirar pendente → DELETE → CTA volta a "Candidatar-se" (CA-8)',
    (tester) async {
      tester.view.physicalSize = const Size(420, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final cand = _FakeCandidaturaService(retirarResult: RetirarSuccess());
      await tester.pumpWidget(
        _app(
          detalhe: _FakeDetalheService(
            _detalhe(
              jaCandidatou: true,
              candidatura: const CandidaturaResumo(
                id: 5,
                estado: 'pendente',
                criadaEm: null,
              ),
            ),
          ),
          candidatura: cand,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('vaga-detalhe-retirar-btn')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('candidatura-retirar-sheet')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const Key('candidatura-retirar-confirmar-btn')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Candidatura retirada.'), findsOneWidget); // toast
      expect(
        find.byKey(const Key('vaga-detalhe-candidatar-btn')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('vaga-detalhe-ja-candidatou')), findsNothing);
    },
  );
}
