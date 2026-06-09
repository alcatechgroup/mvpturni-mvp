import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:turni_webapp/features/auth/auth_service.dart';
import 'package:turni_webapp/features/feed/feed_screen.dart';
import 'package:turni_webapp/features/feed/feed_service.dart';
import 'package:turni_webapp/features/turnos/turnos_lista_screen.dart';
import 'package:turni_webapp/features/turnos/turnos_service.dart';
import 'package:turni_webapp/features/vagas/minhas_vagas_screen.dart';
import 'package:turni_webapp/features/vagas/vaga_service.dart';

import 'a11y_harness.dart';

// STORY-080 — gate de a11y das duas homes autenticadas: Feed (profissional) e
// "Minhas vagas" (contratante). Estado CARREGADO com cards variados (estados de
// vaga / score) é onde mora o risco de contraste (chips, badges, barras) e de
// alvo de toque (ações dos cards). CA-1 + CA-3, nos dois temas.

// ───────────────────────── Feed (profissional) ─────────────────────────

class _FakeFeedService extends FeedService {
  _FakeFeedService(this._result);
  final FeedResult _result;
  @override
  Future<FeedResult> fetch({
    FeedFiltro filtro = FeedFiltro.todas,
    int page = 1,
  }) async => _result;
}

FeedVagaResumo _feedVaga({
  String id = '1',
  String funcao = 'Garçom',
  int score = 97,
  bool jaCandidatou = false,
  bool podeCandidatar = true,
}) => FeedVagaResumo(
  id: id,
  funcao: funcao,
  dataInicio: DateTime(2026, 6, 12, 18),
  dataFim: DateTime(2026, 6, 12, 23),
  valor: 150.0,
  distanciaKm: 3.2,
  score: FeedScore(
    total: score,
    componentes: const {
      'funcao': 40,
      'distancia': 20,
      'historico': 27,
      'nivel': 10,
    },
  ),
  jaCandidatou: jaCandidatou,
  emRevisao: false,
  podeCandidatar: podeCandidatar,
);

// ──────────────────── Minhas vagas (contratante) ────────────────────

class _FakeVagaService extends VagaService {
  _FakeVagaService(this._result);
  final MinhasVagasResult _result;
  @override
  Future<MinhasVagasResult> fetchMinhas() async => _result;
}

// ──────────────────── Turnos (lista, ambos os papéis) ────────────────────

class _FakeTurnosService extends TurnosService {
  _FakeTurnosService(this._result);
  final TurnosResult _result;
  @override
  Future<TurnosResult> fetchDoProfissional() async => _result;
  @override
  Future<TurnosResult> fetchDoContratante() async => _result;
}

TurnoResumo _turno({
  String id = 'u1',
  String funcao = 'Garçom',
  TurnoEstadoResumo estado = TurnoEstadoResumo.confirmado,
  String? quem = 'Bar do Zé',
}) => TurnoResumo(
  id: id,
  funcao: funcao,
  dataInicio: DateTime(2026, 6, 12, 18),
  dataFim: DateTime(2026, 6, 12, 23),
  estado: estado,
  valor: 200.0,
  quem: quem,
);

VagaResumo _vaga({
  String id = '1',
  String funcao = 'Garçom',
  VagaEstadoResumo estado = VagaEstadoResumo.aberta,
  int posicoes = 3,
  int preenchidas = 1,
  int pendentes = 2,
}) => VagaResumo(
  id: id,
  funcao: funcao,
  dataInicio: DateTime(2026, 6, 12, 18),
  dataFim: DateTime(2026, 6, 12, 23),
  valor: 150.0,
  posicoes: posicoes,
  posicoesPreenchidas: preenchidas,
  estado: estado,
  candidatosPendentes: pendentes,
);

void main() {
  tearDown(() => AuthService().debugSetSession(null));

  void entrar(String role) => AuthService().debugSetSession(
    UserSession(
      name: role == 'contratante' ? 'Bar do Zé' : 'Maria',
      role: role,
      status: 'ativo',
      welcomeVisto: true,
      cadastroCompleto: true,
    ),
  );

  group('FeedScreen — gate a11y (carregado)', () {
    for (final dark in [false, true]) {
      final tema = dark ? 'escuro' : 'claro';
      testWidgets('cards de vaga com score — tema $tema', (tester) async {
        entrar('profissional');
        final svc = _FakeFeedService(
          FeedSuccess(
            [
              _feedVaga(id: '1', score: 97),
              _feedVaga(id: '2', funcao: 'Cozinheiro', score: 62),
              _feedVaga(
                id: '3',
                funcao: 'Recepção',
                score: 35,
                jaCandidatou: true,
              ),
            ],
            1,
            false,
          ),
        );
        await pumpA11y(
          tester,
          (theme) => MaterialApp.router(
            theme: theme,
            routerConfig: GoRouter(
              initialLocation: '/',
              routes: [
                GoRoute(
                  path: '/',
                  builder: (_, _) => FeedScreen(service: svc),
                ),
                GoRoute(
                  path: '/vaga/:id',
                  builder: (_, s) => const Scaffold(body: Text('DETALHE')),
                ),
              ],
            ),
          ),
          dark: dark,
          surfaceSize: const Size(420, 900),
        );
        await expectScreenMeetsA11y(tester);
      });
    }
  });

  group('TurnosListaScreen — gate a11y (carregado)', () {
    final papeis = {
      TurnosPapel.profissional: 'profissional',
      TurnosPapel.contratante: 'contratante',
    };
    for (final entry in papeis.entries) {
      for (final dark in [false, true]) {
        final tema = dark ? 'escuro' : 'claro';
        testWidgets('${entry.value} — tema $tema', (tester) async {
          entrar(entry.value);
          final svc = _FakeTurnosService(
            TurnosSuccess([
              GrupoTurnos(grupo: TurnoGrupo.confirmado, turnos: [_turno()]),
              GrupoTurnos(
                grupo: TurnoGrupo.finalizado,
                turnos: [
                  _turno(
                    id: 'u2',
                    funcao: 'Bartender',
                    estado: TurnoEstadoResumo.finalizado,
                  ),
                ],
              ),
            ]),
          );
          await pumpA11y(
            tester,
            (theme) => MaterialApp.router(
              theme: theme,
              routerConfig: GoRouter(
                initialLocation: '/',
                routes: [
                  GoRoute(
                    path: '/',
                    builder: (_, _) =>
                        TurnosListaScreen(papel: entry.key, service: svc),
                  ),
                  GoRoute(
                    path: '/turnos/:id',
                    builder: (_, _) => const Scaffold(body: Text('DET')),
                  ),
                ],
              ),
            ),
            dark: dark,
            surfaceSize: const Size(420, 900),
          );
          await expectScreenMeetsA11y(tester);
        });
      }
    }
  });

  group('MinhasVagasScreen — gate a11y (carregado)', () {
    for (final dark in [false, true]) {
      final tema = dark ? 'escuro' : 'claro';
      testWidgets('cards de vaga com estados — tema $tema', (tester) async {
        entrar('contratante');
        final svc = _FakeVagaService(
          MinhasVagasSuccess([
            _vaga(id: '1', estado: VagaEstadoResumo.aberta, pendentes: 2),
            _vaga(
              id: '2',
              funcao: 'Cozinheiro',
              estado: VagaEstadoResumo.fechada,
              preenchidas: 3,
              pendentes: 0,
            ),
            _vaga(
              id: '3',
              funcao: 'Recepção',
              estado: VagaEstadoResumo.cancelada,
              pendentes: 0,
            ),
          ]),
        );
        await pumpA11y(
          tester,
          (theme) => MaterialApp.router(
            theme: theme,
            routerConfig: GoRouter(
              initialLocation: '/',
              routes: [
                GoRoute(
                  path: '/',
                  builder: (_, _) => MinhasVagasScreen(service: svc),
                ),
                GoRoute(
                  path: '/contratante/vagas/nova',
                  builder: (_, _) => const Scaffold(body: Text('NOVA')),
                ),
                GoRoute(
                  path: '/contratante/vagas/:id/candidatos',
                  builder: (_, _) => const Scaffold(body: Text('CAND')),
                ),
              ],
            ),
          ),
          dark: dark,
          surfaceSize: const Size(420, 900),
        );
        await expectScreenMeetsA11y(tester);
      });
    }
  });
}
