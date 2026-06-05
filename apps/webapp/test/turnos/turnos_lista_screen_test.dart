import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:turni_webapp/ds/theme.dart';
import 'package:turni_webapp/features/turnos/turnos_lista_screen.dart';
import 'package:turni_webapp/features/turnos/turnos_service.dart';

// STORY-059 — widget tests da TurnosListaScreen (SCREEN-059).
// CA-3 (card do profissional: função/quem/data/valor/selo), CA-4 (espelho do contratante:
// título "Turnos", total, nome do profissional), CA-5 (sem permissão por papel cruzado),
// CA-6 (vazio com microcopy por papel). Estados: loading/erro/seções na ordem do servidor.

class _FakeTurnosService extends TurnosService {
  _FakeTurnosService(this.result);

  TurnosResult Function() result;
  int calls = 0;

  @override
  Future<TurnosResult> fetchDoProfissional() async {
    calls++;
    return result();
  }

  @override
  Future<TurnosResult> fetchDoContratante() async {
    calls++;
    return result();
  }
}

TurnoResumo _turno({
  String id = 'u1',
  String funcao = 'Garçom',
  TurnoEstadoResumo estado = TurnoEstadoResumo.confirmado,
  String? quem = 'Bar do Zé',
  double valor = 200.0,
}) => TurnoResumo(
  id: id,
  funcao: funcao,
  dataInicio: DateTime(2026, 6, 12, 18),
  dataFim: DateTime(2026, 6, 12, 23),
  estado: estado,
  valor: valor,
  quem: quem,
);

Widget _comRouter(
  _FakeTurnosService svc, {
  TurnosPapel papel = TurnosPapel.profissional,
}) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => TurnosListaScreen(papel: papel, service: svc),
      ),
      GoRoute(
        path: '/feed',
        builder: (_, _) => const Scaffold(body: Text('FEED')),
      ),
      GoRoute(
        path: '/contratante/vagas',
        builder: (_, _) => const Scaffold(body: Text('MINHAS VAGAS')),
      ),
      // STORY-060: o card da lista navega para o detalhe.
      GoRoute(
        path: '/turnos/:id',
        builder: (_, state) =>
            Scaffold(body: Text('DETALHE ${state.pathParameters['id']}')),
      ),
    ],
  );
  return MaterialApp.router(theme: buildLightTheme(), routerConfig: router);
}

void main() {
  // ───────────────── CA-3 — card do profissional ─────────────────

  testWidgets('lista do profissional renderiza seções e card completo (CA-3)', (
    tester,
  ) async {
    final svc = _FakeTurnosService(
      () => TurnosSuccess([
        GrupoTurnos(grupo: TurnoGrupo.confirmado, turnos: [_turno()]),
        GrupoTurnos(
          grupo: TurnoGrupo.finalizado,
          turnos: [
            _turno(
              id: 'u2',
              funcao: 'Bartender',
              estado: TurnoEstadoResumo.finalizado,
              quem: 'Pub Central',
              valor: 220.0,
            ),
          ],
        ),
      ]),
    );
    await tester.pumpWidget(_comRouter(svc));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('meus-turnos-screen')), findsOneWidget);
    expect(find.text('Meus turnos'), findsOneWidget);

    // Seções na ordem do servidor, com contador.
    expect(find.byKey(const Key('turnos-grupo-confirmado')), findsOneWidget);
    expect(find.text('Confirmados (1)'), findsOneWidget);
    expect(find.byKey(const Key('turnos-grupo-finalizado')), findsOneWidget);
    expect(find.text('Finalizados (1)'), findsOneWidget);

    // Card: função + quem (estabelecimento) + data 24h + valor sem sufixo + selo.
    expect(find.byKey(const Key('turno-card-u1')), findsOneWidget);
    expect(find.text('Garçom'), findsOneWidget);
    expect(find.text('Bar do Zé'), findsOneWidget);
    expect(find.textContaining('18:00'), findsWidgets);
    expect(find.byKey(const Key('turno-card-u1-estado')), findsOneWidget);
    expect(find.text('Confirmado'), findsOneWidget);
    final valor = tester.widget<Text>(
      find.byKey(const Key('turno-card-u1-valor')),
    );
    expect(valor.textSpan!.toPlainText(), 'R\$ 200,00'); // sem "· total"

    expect(find.text('Finalizado'), findsOneWidget);
  });

  testWidgets('card sem "quem" omite a linha, não quebra (§4.6)', (
    tester,
  ) async {
    final svc = _FakeTurnosService(
      () => TurnosSuccess([
        GrupoTurnos(grupo: TurnoGrupo.confirmado, turnos: [_turno(quem: null)]),
      ]),
    );
    await tester.pumpWidget(_comRouter(svc));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('turno-card-u1')), findsOneWidget);
    expect(find.text('Bar do Zé'), findsNothing);
  });

  testWidgets('selos das variantes de estado (§4.1)', (tester) async {
    final svc = _FakeTurnosService(
      () => TurnosSuccess([
        GrupoTurnos(
          grupo: TurnoGrupo.ativo,
          turnos: [_turno(id: 'a', estado: TurnoEstadoResumo.ativo)],
        ),
        GrupoTurnos(
          grupo: TurnoGrupo.emDisputa,
          turnos: [_turno(id: 'b', estado: TurnoEstadoResumo.emDisputa)],
        ),
        GrupoTurnos(
          grupo: TurnoGrupo.encerrado,
          turnos: [
            _turno(id: 'c', estado: TurnoEstadoResumo.noShow),
            _turno(id: 'd', estado: TurnoEstadoResumo.semPagamento),
          ],
        ),
      ]),
    );
    await tester.pumpWidget(_comRouter(svc));
    await tester.pumpAndSettle();

    // "Em andamento" aparece no header e no selo.
    expect(find.text('Em andamento (1)'), findsOneWidget);
    expect(find.text('Em andamento'), findsOneWidget);
    expect(find.text('Em disputa'), findsOneWidget);
    expect(find.text('Não realizado'), findsOneWidget);
    expect(find.text('Encerrado sem pagamento'), findsOneWidget);
    expect(find.text('Encerrados (2)'), findsOneWidget);
  });

  // ───────────────── CA-4 — espelho do contratante ─────────────────

  testWidgets(
    'contratante: título "Turnos", total e nome do profissional (CA-4)',
    (tester) async {
      final svc = _FakeTurnosService(
        () => TurnosSuccess([
          GrupoTurnos(
            grupo: TurnoGrupo.confirmado,
            turnos: [_turno(quem: 'Júlia Santos', valor: 230.0)],
          ),
        ]),
      );
      await tester.pumpWidget(_comRouter(svc, papel: TurnosPapel.contratante));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('contratante-turnos-screen')),
        findsOneWidget,
      );
      expect(find.text('Turnos'), findsOneWidget);
      expect(find.text('Júlia Santos'), findsOneWidget);
      final valor = tester.widget<Text>(
        find.byKey(const Key('turno-card-u1-valor')),
      );
      expect(valor.textSpan!.toPlainText(), 'R\$ 230,00 · total');
    },
  );

  // ───────────────── CA-6 — vazio por papel ─────────────────

  testWidgets('vazio do profissional: microcopy do PO + CTA → /feed (CA-6)', (
    tester,
  ) async {
    final svc = _FakeTurnosService(() => TurnosSuccess(const []));
    await tester.pumpWidget(_comRouter(svc));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('turnos-vazio')), findsOneWidget);
    expect(find.text('Ainda não há turnos'), findsOneWidget);
    expect(
      find.text(
        'Quando o contratante aceitar sua candidatura, o turno aparece aqui.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('turnos-vazio-cta')));
    await tester.pumpAndSettle();
    expect(find.text('FEED'), findsOneWidget);
  });

  testWidgets('vazio do contratante: espelho + CTA → minhas vagas (CA-6)', (
    tester,
  ) async {
    final svc = _FakeTurnosService(() => TurnosSuccess(const []));
    await tester.pumpWidget(_comRouter(svc, papel: TurnosPapel.contratante));
    await tester.pumpAndSettle();

    expect(
      find.text('Quando você aceitar uma candidatura, o turno aparece aqui.'),
      findsOneWidget,
    );
    expect(find.text('Ver minhas vagas'), findsOneWidget);

    await tester.tap(find.byKey(const Key('turnos-vazio-cta')));
    await tester.pumpAndSettle();
    expect(find.text('MINHAS VAGAS'), findsOneWidget);
  });

  // ───────────────── CA-5 — sem permissão (fail-secure) ─────────────────

  testWidgets('contratante em /profissional/turnos cai em sem permissão (CA-5)', (
    tester,
  ) async {
    final svc = _FakeTurnosService(() => TurnosForbidden());
    await tester.pumpWidget(_comRouter(svc));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('turnos-sem-permissao')), findsOneWidget);
    expect(find.text('Esta área é do profissional'), findsOneWidget);
    expect(
      find.text(
        'Meus turnos mostra os turnos de quem trabalha. Sua conta é de contratante.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('profissional em /contratante/turnos cai em sem permissão (CA-5)', (
    tester,
  ) async {
    final svc = _FakeTurnosService(() => TurnosForbidden());
    await tester.pumpWidget(_comRouter(svc, papel: TurnosPapel.contratante));
    await tester.pumpAndSettle();

    expect(find.text('Esta área é do contratante'), findsOneWidget);
    expect(
      find.text(
        'Acompanhar os turnos das vagas é uma ação de quem contrata. Sua conta é de profissional.',
      ),
      findsOneWidget,
    );
  });

  // ───────────────── Estados loading / erro ─────────────────

  testWidgets('loading mostra skeleton antes do fetch resolver', (
    tester,
  ) async {
    final svc = _FakeTurnosService(() => TurnosSuccess(const []));
    await tester.pumpWidget(_comRouter(svc));
    // Antes do settle, a fase é loading.
    expect(find.byKey(const Key('turnos-skeleton')), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('turnos-skeleton')), findsNothing);
  });

  testWidgets('toque no card navega para o detalhe (STORY-060)', (
    tester,
  ) async {
    final svc = _FakeTurnosService(
      () => TurnosSuccess([
        GrupoTurnos(grupo: TurnoGrupo.confirmado, turnos: [_turno()]),
      ]),
    );
    await tester.pumpWidget(_comRouter(svc));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('turno-card-u1')));
    await tester.pumpAndSettle();

    expect(find.text('DETALHE u1'), findsOneWidget);
  });

  testWidgets('erro de rede mostra banner e o retry recarrega', (tester) async {
    var falha = true;
    final svc = _FakeTurnosService(
      () => falha
          ? TurnosError()
          : TurnosSuccess([
              GrupoTurnos(grupo: TurnoGrupo.confirmado, turnos: [_turno()]),
            ]),
    );
    await tester.pumpWidget(_comRouter(svc));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('turnos-erro-banner')), findsOneWidget);
    expect(
      find.text(
        'Não foi possível carregar seus turnos. Verifique sua conexão.',
      ),
      findsOneWidget,
    );

    falha = false;
    await tester.tap(find.byKey(const Key('turnos-retry-btn')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('turnos-erro-banner')), findsNothing);
    expect(find.byKey(const Key('turno-card-u1')), findsOneWidget);
    expect(svc.calls, 2);
  });
}
