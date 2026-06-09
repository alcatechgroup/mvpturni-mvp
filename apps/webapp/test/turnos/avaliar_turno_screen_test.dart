import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:turni_webapp/ds/theme.dart';
import 'package:turni_webapp/features/turnos/avaliar_turno_screen.dart';
import 'package:turni_webapp/features/turnos/avaliar_turno_service.dart';
import 'package:turni_webapp/features/turnos/turno_detalhe_service.dart';
import 'package:turni_webapp/features/turnos/turnos_service.dart'
    show TurnoEstadoResumo;

// STORY-087 — widget tests da AvaliarTurnoScreen (SCREEN-084 T1/T2).
// CA-1/CA-2 (copy por papel + envio), CA-4 (erro recuperável mantém o preenchido; 409 →
// já avaliado), CA-5 (RBAC fail-secure: 404/403 → "Este turno não é seu"). 4 categorias:
// feliz, inválido (sem estrela → CTA disabled), exceção (rede → banner), bordas (409/403/422).

class _FakeDetalhe extends TurnoDetalheService {
  _FakeDetalhe(this.result);
  TurnoDetalheResult Function() result;
  @override
  Future<TurnoDetalheResult> fetch(String id) async => result();
}

class _FakeAvaliar extends AvaliarTurnoService {
  _FakeAvaliar(this.result);
  AvaliarResult Function() result;
  int calls = 0;
  int? estrelasEnviadas;
  String? comentarioEnviado;
  @override
  Future<AvaliarResult> enviar(
    String turnoId, {
    required int estrelas,
    String? comentario,
  }) async {
    calls++;
    estrelasEnviadas = estrelas;
    comentarioEnviado = comentario;
    return result();
  }
}

TurnoDetalhe _turno({
  bool contratante = false,
  bool pendente = true,
  String? profissional,
}) => TurnoDetalhe(
  id: 'u1',
  funcao: 'Garçom',
  dataInicio: DateTime(2026, 6, 12, 18),
  dataFim: DateTime(2026, 6, 12, 23),
  estado: TurnoEstadoResumo.finalizado,
  estadoRaw: 'finalizado',
  valor: 200,
  estabelecimento: 'Restaurante Vista Mar',
  taxaTurni: contratante ? 30 : null,
  totalContratante: contratante ? 230 : null,
  profissional: contratante ? (profissional ?? 'Ana Souza Lima') : null,
  aceite: null,
  timeline: const [],
  avaliacao: AvaliacaoPendencia(
    pendente: pendente,
    direcao: contratante
        ? 'contratante_para_profissional'
        : 'profissional_para_contratante',
  ),
);

Widget _host(_FakeDetalhe detalhe, _FakeAvaliar avaliar) {
  final router = GoRouter(
    initialLocation: '/turnos/u1/avaliar',
    routes: [
      GoRoute(
        path: '/turnos/:id/avaliar',
        builder: (_, _) => AvaliarTurnoScreen(
          turnoId: 'u1',
          detalheService: detalhe,
          avaliarService: avaliar,
        ),
      ),
      GoRoute(
        path: '/profissional/turnos',
        builder: (_, _) => const Scaffold(body: Text('LISTA PRO')),
      ),
      GoRoute(
        path: '/contratante/turnos',
        builder: (_, _) => const Scaffold(body: Text('LISTA CONTR')),
      ),
    ],
  );
  return MaterialApp.router(theme: buildLightTheme(), routerConfig: router);
}

void main() {
  // ─────────────── copy por papel (CA-1/CA-2) ───────────────

  testWidgets(
    'profissional vê T1: "Como foi trabalhar aqui?" + estabelecimento',
    (tester) async {
      final d = _FakeDetalhe(() => TurnoDetalheSuccess(_turno()));
      final a = _FakeAvaliar(() => AvaliacaoEnviada(5));
      await tester.pumpWidget(_host(d, a));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('avaliar-turno-screen')), findsOneWidget);
      expect(find.text('Como foi trabalhar aqui?'), findsOneWidget);
      expect(find.text('Restaurante Vista Mar'), findsOneWidget);
      expect(find.byKey(const Key('avaliacao-estrelas')), findsOneWidget);
    },
  );

  testWidgets('contratante vê T2: "Como foi o trabalho de {1º nome}?"', (
    tester,
  ) async {
    final d = _FakeDetalhe(
      () => TurnoDetalheSuccess(_turno(contratante: true)),
    );
    final a = _FakeAvaliar(() => AvaliacaoEnviada(5));
    await tester.pumpWidget(_host(d, a));
    await tester.pumpAndSettle();

    expect(find.text('Como foi o trabalho de Ana?'), findsOneWidget);
  });

  // ─────────────── (b) inválido — sem estrela o CTA fica desabilitado ───────────────

  testWidgets('sem estrela escolhida → CTA "Enviar avaliação" desabilitado', (
    tester,
  ) async {
    final d = _FakeDetalhe(() => TurnoDetalheSuccess(_turno()));
    final a = _FakeAvaliar(() => AvaliacaoEnviada(5));
    await tester.pumpWidget(_host(d, a));
    await tester.pumpAndSettle();

    final btn = tester.widget<FilledButton>(
      find.byKey(const Key('avaliacao-enviar-btn')),
    );
    expect(btn.onPressed, isNull);

    // Tentar enviar não dispara nada (bloqueado).
    await tester.tap(find.byKey(const Key('avaliacao-enviar-btn')));
    await tester.pumpAndSettle();
    expect(a.calls, 0);
  });

  // ─────────────── (a) feliz — escolher estrela habilita e envia ───────────────

  testWidgets(
    'escolher estrela habilita o CTA; enviar chama a API e mostra sucesso',
    (tester) async {
      final d = _FakeDetalhe(() => TurnoDetalheSuccess(_turno()));
      final a = _FakeAvaliar(() => AvaliacaoEnviada(4));
      await tester.pumpWidget(_host(d, a));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('avaliacao-estrela-4')));
      await tester.pumpAndSettle();

      final btn = tester.widget<FilledButton>(
        find.byKey(const Key('avaliacao-enviar-btn')),
      );
      expect(btn.onPressed, isNotNull);

      await tester.tap(find.byKey(const Key('avaliacao-enviar-btn')));
      await tester.pumpAndSettle();

      expect(a.calls, 1);
      expect(a.estrelasEnviadas, 4);
      // Sucesso: volta para a lista (não há detalhe na pilha deste host).
      expect(find.text('LISTA PRO'), findsOneWidget);
    },
  );

  testWidgets('comentário preenchido viaja no envio', (tester) async {
    final d = _FakeDetalhe(() => TurnoDetalheSuccess(_turno()));
    final a = _FakeAvaliar(() => AvaliacaoEnviada(5));
    await tester.pumpWidget(_host(d, a));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('avaliacao-estrela-5')));
    await tester.enterText(
      find.byKey(const Key('avaliacao-comentario')),
      'Equipe acolhedora',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('avaliacao-enviar-btn')));
    await tester.pumpAndSettle();

    expect(a.comentarioEnviado, 'Equipe acolhedora');
  });

  // ─────────────── (c) exceção — erro de rede é recuperável e mantém o preenchido ───────────────

  testWidgets(
    'erro de envio mostra banner recuperável e MANTÉM estrelas/comentário',
    (tester) async {
      final d = _FakeDetalhe(() => TurnoDetalheSuccess(_turno()));
      final a = _FakeAvaliar(() => AvaliacaoErro());
      await tester.pumpWidget(_host(d, a));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('avaliacao-estrela-3')));
      await tester.enterText(
        find.byKey(const Key('avaliacao-comentario')),
        'comentário longo',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('avaliacao-enviar-btn')));
      await tester.pumpAndSettle();

      // Banner de erro + estado preservado (estrelas e comentário continuam lá).
      expect(find.byKey(const Key('avaliacao-envio-erro')), findsOneWidget);
      expect(
        find.text('Não foi possível enviar agora. Tente de novo.'),
        findsOneWidget,
      );
      expect(find.text('Bom'), findsOneWidget); // helper de 3★ continua
      expect(find.text('comentário longo'), findsOneWidget);

      // Retry re-tenta o mesmo envio.
      await tester.tap(find.byKey(const Key('avaliacao-envio-retry-btn')));
      await tester.pumpAndSettle();
      expect(a.calls, 2);
    },
  );

  // ─────────────── (d) borda — 409 já avaliado → informativo ───────────────

  testWidgets(
    '409 ja_avaliado → estado informativo "Você já avaliou este turno."',
    (tester) async {
      final d = _FakeDetalhe(() => TurnoDetalheSuccess(_turno()));
      final a = _FakeAvaliar(() => AvaliacaoJaRegistrada());
      await tester.pumpWidget(_host(d, a));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('avaliacao-estrela-5')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('avaliacao-enviar-btn')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('avaliar-encerrado')), findsOneWidget);
      expect(find.text('Você já avaliou este turno.'), findsOneWidget);
    },
  );

  testWidgets(
    '422 estado_invalido → "Este turno não pode mais ser avaliado."',
    (tester) async {
      final d = _FakeDetalhe(() => TurnoDetalheSuccess(_turno()));
      final a = _FakeAvaliar(() => AvaliacaoEstadoInvalido());
      await tester.pumpWidget(_host(d, a));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('avaliacao-estrela-2')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('avaliacao-enviar-btn')));
      await tester.pumpAndSettle();

      expect(
        find.text('Este turno não pode mais ser avaliado.'),
        findsOneWidget,
      );
    },
  );

  // ─────────────── CA-5 — RBAC fail-secure: detalhe 403/404 → "Este turno não é seu" ───────────────

  testWidgets(
    'turno não encontrado/alheio → "Este turno não é seu." (fail-secure)',
    (tester) async {
      final d = _FakeDetalhe(() => TurnoDetalheNaoEncontrado());
      final a = _FakeAvaliar(() => AvaliacaoEnviada(5));
      await tester.pumpWidget(_host(d, a));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('avaliar-sem-permissao')), findsOneWidget);
      expect(find.text('Este turno não é seu.'), findsOneWidget);
    },
  );

  testWidgets(
    '403 no envio → "Este turno não é seu." (RBAC servidor é a verdade)',
    (tester) async {
      final d = _FakeDetalhe(() => TurnoDetalheSuccess(_turno()));
      final a = _FakeAvaliar(() => AvaliacaoNaoAutorizada());
      await tester.pumpWidget(_host(d, a));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('avaliacao-estrela-5')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('avaliacao-enviar-btn')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('avaliar-sem-permissao')), findsOneWidget);
    },
  );

  // ─────────────── não-pendente (deep-link) → informativo, não formulário ───────────────

  testWidgets(
    'avaliação não pendente (deep-link) → informativo, sem formulário',
    (tester) async {
      final d = _FakeDetalhe(
        () => TurnoDetalheSuccess(_turno(pendente: false)),
      );
      final a = _FakeAvaliar(() => AvaliacaoEnviada(5));
      await tester.pumpWidget(_host(d, a));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('avaliar-encerrado')), findsOneWidget);
      expect(find.byKey(const Key('avaliacao-estrelas')), findsNothing);
    },
  );

  // ─────────────── erro de carga do contexto → retry ───────────────

  testWidgets('falha ao carregar o turno → retry recarrega', (tester) async {
    var falhar = true;
    final d = _FakeDetalhe(
      () => falhar ? TurnoDetalheError() : TurnoDetalheSuccess(_turno()),
    );
    final a = _FakeAvaliar(() => AvaliacaoEnviada(5));
    await tester.pumpWidget(_host(d, a));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('avaliar-carga-retry-btn')), findsOneWidget);

    falhar = false;
    await tester.tap(find.byKey(const Key('avaliar-carga-retry-btn')));
    await tester.pumpAndSettle();

    expect(find.text('Como foi trabalhar aqui?'), findsOneWidget);
  });

  // ─────────────── desktop: card centrado com par Voltar/Enviar ───────────────

  testWidgets('desktop mostra o botão Voltar ao lado do Enviar', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final d = _FakeDetalhe(() => TurnoDetalheSuccess(_turno()));
    final a = _FakeAvaliar(() => AvaliacaoEnviada(5));
    await tester.pumpWidget(_host(d, a));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('avaliacao-voltar-btn')), findsOneWidget);
    expect(find.byKey(const Key('avaliacao-enviar-btn')), findsOneWidget);
  });
}
