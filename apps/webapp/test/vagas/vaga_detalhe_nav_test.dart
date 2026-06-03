import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:turni_webapp/ds/theme.dart';
import 'package:turni_webapp/features/vagas/candidatura_service.dart';
import 'package:turni_webapp/features/vagas/vaga_detalhe_screen.dart';
import 'package:turni_webapp/features/vagas/vaga_detalhe_service.dart';

class _CandSempreCria extends CandidaturaService {
  @override
  Future<CandidaturaResult> candidatar(String vagaId) async =>
      CandidaturaCriada(
        id: vagaId,
        estado: 'pendente',
        candidatouEm: DateTime(2026, 6, 2, 14, 20),
        alerta: false,
      );
}

// STORY-050 — regressão de navegação entre vagas: ao ir de /vaga/A → /feed → /vaga/B (mesma
// rota, param diferente), sem cuidado o go_router reusa o State e mostra a vaga anterior.
// Trava a correção (pageKey por id na MaterialPage + didUpdateWidget → recarrega o detalhe).

class _PorIdService extends VagaDetalheService {
  String? ultimoId;
  @override
  Future<DetalheResult> fetch(String id) async {
    ultimoId = id;
    return DetalheSuccess(
      VagaDetalhe(
        id: id,
        funcao: 'Vaga $id',
        estabelecimento: 'Estab $id',
        cidade: 'São Paulo',
        dataInicio: DateTime(2026, 6, 12, 18),
        dataFim: DateTime(2026, 6, 12, 23),
        valor: double.parse(id), // valor = id → distingue a vaga na tela
        distanciaKm: 1,
        score: const ScoreBreakdown(total: 90, linhas: []),
        podeCandidatar: true,
        jaCandidatou: false,
        candidatura: null,
        motivoBloqueio: null,
      ),
    );
  }
}

void main() {
  testWidgets('navegar /vaga/29 → /feed → /vaga/30 recarrega a vaga certa', (
    tester,
  ) async {
    final svc = _PorIdService();
    final router = GoRouter(
      initialLocation: '/vaga/29',
      routes: [
        GoRoute(
          path: '/feed',
          builder: (_, _) => const Scaffold(body: Text('FEED')),
        ),
        GoRoute(
          path: '/vaga/:id',
          pageBuilder: (context, state) {
            final id = state.pathParameters['id'] ?? '';
            return MaterialPage(
              key: ValueKey('vaga-$id'),
              child: VagaDetalheScreen(vagaId: id, service: svc),
            );
          },
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(theme: buildLightTheme(), routerConfig: router),
    );
    await tester.pumpAndSettle();

    // Em /vaga/29 → mostra a vaga 29 (valor R$ 29,00).
    expect(find.textContaining('R\$ 29,00'), findsOneWidget);
    expect(svc.ultimoId, '29');

    // Vai para /feed e depois /vaga/30 (mesma rota, param diferente).
    router.go('/feed');
    await tester.pumpAndSettle();
    router.go('/vaga/30');
    await tester.pumpAndSettle();

    // Deve recarregar a vaga 30 (R$ 30,00), não continuar na 29.
    expect(
      svc.ultimoId,
      '30',
      reason: 'fetch deveria ter sido chamado para a vaga 30',
    );
    expect(find.textContaining('R\$ 30,00'), findsOneWidget);
    expect(find.textContaining('R\$ 29,00'), findsNothing);
  });

  testWidgets(
    'candidatar na 29 (override) → /feed → /vaga/30 ainda recarrega a 30',
    (tester) async {
      tester.view.physicalSize = const Size(420, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final svc = _PorIdService();
      final cand = _CandSempreCria();
      final router = GoRouter(
        initialLocation: '/vaga/29',
        routes: [
          GoRoute(
            path: '/feed',
            builder: (_, _) => const Scaffold(body: Text('FEED')),
          ),
          GoRoute(
            path: '/vaga/:id',
            pageBuilder: (context, state) {
              final id = state.pathParameters['id'] ?? '';
              return MaterialPage(
                key: ValueKey('vaga-$id'),
                child: VagaDetalheScreen(
                  vagaId: id,
                  service: svc,
                  candidaturaService: cand,
                ),
              );
            },
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp.router(theme: buildLightTheme(), routerConfig: router),
      );
      await tester.pumpAndSettle();

      // Candidata na 29 → badge (override = true neste State).
      await tester.tap(find.byKey(const Key('vaga-detalhe-candidatar-btn')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('candidatura-confirmar-btn')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('vaga-detalhe-ja-candidatou')),
        findsOneWidget,
      );

      // Volta ao feed e abre a 30 (mesma rota, param diferente).
      router.go('/feed');
      await tester.pumpAndSettle();
      router.go('/vaga/30');
      await tester.pumpAndSettle();

      // Deve mostrar a 30 candidatável (sem o badge da 29).
      expect(find.textContaining('R\$ 30,00'), findsOneWidget);
      expect(
        find.byKey(const Key('vaga-detalhe-candidatar-btn')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('vaga-detalhe-ja-candidatou')), findsNothing);
    },
  );
}
