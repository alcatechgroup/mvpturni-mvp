import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:turni_webapp/ds/theme.dart';
import 'package:turni_webapp/features/vagas/candidatos_service.dart';
import 'package:turni_webapp/features/vagas/painel_candidatos_screen.dart';

// STORY-058 / SCREEN-058 — aprovar candidatura no painel do contratante.
// Service: POST /api/candidaturas/{id}/aprovar (201/409/422/403/rede) + preview financeiro
// no GET do painel. Widget: D1 (confirmação c/ financeiro PDR-004 + pré-aviso PJ), D2
// (bloqueio PF), D3 (override PJ), snackbars de desfecho, anti clique-duplo.

const _utf8 = {'content-type': 'application/json; charset=utf-8'};

CandidatoCard _cand({
  String id = 'c1',
  String nome = 'Júlia Santos',
  bool alerta = false,
}) => CandidatoCard(
  id: id,
  profissional: PerfilCandidato(
    id: 'p1',
    nome: nome,
    fotoUrl: null,
    funcaoPrimaria: 'Garçom',
    nivel: 'Elite',
    scoreHistorico: 4.9,
    plano: null,
  ),
  scoreNoMomento: 92,
  score: null,
  candidatouEm: DateTime(2026, 6, 12, 14, 20),
  alertaHabitualidade: alerta,
);

const _financeiro = VagaFinanceiro(
  valor: '200.00',
  taxaTurni: '30.00',
  totalContratante: '230.00',
);

class _FakeService extends CandidatosService {
  _FakeService({required this.candidatos, this.aprovarResults = const []});

  List<CandidatoCard> candidatos;
  List<AprovarResult Function()> aprovarResults;

  int fetches = 0;
  int aprovacoes = 0;
  final List<({String id, bool override})> chamadas = [];

  @override
  Future<CandidatosResult> fetch(String vagaId) async {
    fetches++;
    return CandidatosSuccess(candidatos, candidatos.length, _financeiro);
  }

  @override
  Future<AprovarResult> aprovar(
    String candidaturaId, {
    bool override = false,
  }) async {
    chamadas.add((id: candidaturaId, override: override));
    final i = aprovacoes < aprovarResults.length
        ? aprovacoes
        : aprovarResults.length - 1;
    aprovacoes++;
    return aprovarResults[i]();
  }
}

Future<_FakeService> _pump(
  WidgetTester tester, {
  List<CandidatoCard>? candidatos,
  List<AprovarResult Function()> aprovar = const [],
}) async {
  final service = _FakeService(
    candidatos: candidatos ?? [_cand()],
    aprovarResults: aprovar,
  );
  final router = GoRouter(
    initialLocation: '/contratante/vagas/v1/candidatos',
    routes: [
      GoRoute(path: '/', builder: (_, _) => const Scaffold()),
      GoRoute(path: '/contratante/vagas', builder: (_, _) => const Scaffold()),
      GoRoute(
        path: '/contratante/vagas/:id/candidatos',
        builder: (_, _) =>
            PainelCandidatosScreen(vagaId: 'v1', service: service),
      ),
    ],
  );
  await tester.pumpWidget(
    MaterialApp.router(theme: buildLightTheme(), routerConfig: router),
  );
  await tester.pumpAndSettle();
  return service;
}

void main() {
  // ───────────────────── Service: parsing do contrato ─────────────────────

  group('CandidatosService.fetch — preview financeiro (SCREEN-058 D1)', () {
    test('parseia vaga.valor/taxa/total do GET do painel', () async {
      final service = CandidatosService(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'candidatos': [],
              'total': 0,
              'vaga': {
                'valor': '200.00',
                'taxa_turni': '30.00',
                'total_contratante': '230.00',
              },
            }),
            200,
            headers: _utf8,
          ),
        ),
      );

      final r = await service.fetch('v1') as CandidatosSuccess;
      expect(r.vaga?.valor, '200.00');
      expect(r.vaga?.taxaTurni, '30.00');
      expect(r.vaga?.totalContratante, '230.00');
    });

    test('payload sem vaga (legado) → vaga null, sem quebrar', () async {
      final service = CandidatosService(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({'candidatos': [], 'total': 0}),
            200,
            headers: _utf8,
          ),
        ),
      );

      final r = await service.fetch('v1') as CandidatosSuccess;
      expect(r.vaga, isNull);
    });
  });

  group('CandidatosService.aprovar — contrato do POST', () {
    CandidatosService comResposta(
      int status,
      Map<String, dynamic> body, {
      void Function(http.Request)? captura,
    }) => CandidatosService(
      client: MockClient((req) async {
        captura?.call(req);
        return http.Response(jsonEncode(body), status, headers: _utf8);
      }),
    );

    test('201 → AprovarSucesso com o turno', () async {
      late http.Request req;
      final service = comResposta(201, {
        'turno': {'id': 't1', 'status': 'confirmado'},
      }, captura: (r) => req = r);

      final r = await service.aprovar('c1');
      expect(r, isA<AprovarSucesso>());
      expect((r as AprovarSucesso).turnoId, 't1');
      expect(req.url.path, '/api/candidaturas/c1/aprovar');
      expect(jsonDecode(req.body), {});
    });

    test('override=true vai no corpo', () async {
      late http.Request req;
      final service = comResposta(201, {
        'turno': {'id': 't1', 'status': 'confirmado'},
      }, captura: (r) => req = r);

      await service.aprovar('c1', override: true);
      expect(jsonDecode(req.body), {'override': true});
    });

    test('409 → AprovarJaAceita (idempotência CA-5)', () async {
      final r = await comResposta(409, {
        'erro': 'ja_aprovada',
        'turno_id': 't9',
      }).aprovar('c1');
      expect(r, isA<AprovarJaAceita>());
    });

    test('422 → AprovarBloqueio com erro+mensagem verbatim', () async {
      final r = await comResposta(422, {
        'erro': 'habitualidade_bloqueio',
        'mensagem': 'bloqueado por PDR-002',
      }).aprovar('c1');
      expect(r, isA<AprovarBloqueio>());
      expect((r as AprovarBloqueio).erro, 'habitualidade_bloqueio');
      expect(r.mensagem, 'bloqueado por PDR-002');
    });

    test('403/500/rede → AprovarErro', () async {
      expect(await comResposta(403, {}).aprovar('c1'), isA<AprovarErro>());
      expect(await comResposta(500, {}).aprovar('c1'), isA<AprovarErro>());
      final semRede = CandidatosService(
        client: MockClient((_) async => throw http.ClientException('offline')),
      );
      expect(await semRede.aprovar('c1'), isA<AprovarErro>());
    });
  });

  // ───────────────────── Widget: D1 confirmação ─────────────────────

  group('D1 — dialog de confirmação', () {
    testWidgets(
      'botão Aceitar agora habilitado abre o D1 com o financeiro (PDR-004)',
      (tester) async {
        await _pump(tester);

        await tester.tap(
          find.byKey(const Key('candidato-card-c1-aceitar-btn')),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('aprovar-dialog-confirmar')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('aprovar-dialog-financeiro')),
          findsOneWidget,
        );
        expect(find.text('R\$ 200,00'), findsOneWidget);
        expect(find.text('R\$ 30,00'), findsOneWidget);
        expect(find.text('R\$ 230,00'), findsOneWidget);
        expect(find.textContaining('Júlia Santos'), findsWidgets);
        expect(
          find.textContaining('o contrato do turno é emitido e registrado'),
          findsOneWidget,
        );
        // Sem pré-aviso quando o candidato não tem alerta.
        expect(
          find.byKey(const Key('aprovar-dialog-pre-aviso-habitualidade')),
          findsNothing,
        );
      },
    );

    testWidgets('candidato com alerta de habitualidade vê o pré-aviso no D1', (
      tester,
    ) async {
      await _pump(tester, candidatos: [_cand(alerta: true)]);

      await tester.tap(find.byKey(const Key('candidato-card-c1-aceitar-btn')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('aprovar-dialog-pre-aviso-habitualidade')),
        findsOneWidget,
      );
    });

    testWidgets('Voltar fecha o D1 sem chamar o endpoint', (tester) async {
      final service = await _pump(tester);

      await tester.tap(find.byKey(const Key('candidato-card-c1-aceitar-btn')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('aprovar-dialog-voltar-btn')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('aprovar-dialog-confirmar')), findsNothing);
      expect(service.aprovacoes, 0);
    });
  });

  // ───────────────────── Desfechos ─────────────────────

  group('desfechos da aprovação', () {
    Future<void> confirmar(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('candidato-card-c1-aceitar-btn')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('aprovar-dialog-confirmar-btn')));
      await tester.pumpAndSettle();
    }

    testWidgets('sucesso → snackbar + lista recarrega (candidato some)', (
      tester,
    ) async {
      final service = await _pump(
        tester,
        aprovar: [() => AprovarSucesso('t1')],
      );
      // Após aprovar, o backend não devolve mais o candidato (virou turno).
      service.candidatos = [];

      await confirmar(tester);

      expect(find.byKey(const Key('aprovar-snackbar-sucesso')), findsOneWidget);
      expect(find.textContaining('Turno confirmado'), findsOneWidget);
      expect(service.fetches, 2); // inicial + reload
      expect(service.chamadas.single, (id: 'c1', override: false));
      expect(find.text('Júlia Santos'), findsNothing);
    });

    testWidgets('habitualidade_bloqueio (PF 3ª) → D2 com a razão e sem turno', (
      tester,
    ) async {
      await _pump(
        tester,
        aprovar: [
          () => AprovarBloqueio(erro: 'habitualidade_bloqueio', mensagem: 'x'),
        ],
      );

      await confirmar(tester);

      expect(
        find.byKey(const Key('aprovar-dialog-bloqueio-pf')),
        findsOneWidget,
      );
      expect(find.text('Aceite bloqueado'), findsOneWidget);
      expect(
        find.textContaining(
          'bloqueia a 3ª alocação semanal de profissionais PF',
        ),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const Key('aprovar-dialog-bloqueio-pf-entendi-btn')),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('aprovar-dialog-bloqueio-pf')), findsNothing);
    });

    testWidgets(
      'requer_override (PJ 3ª) → D3; "Assumo o risco" reenvia com override',
      (tester) async {
        final service = await _pump(
          tester,
          aprovar: [
            () => AprovarBloqueio(erro: 'requer_override', mensagem: 'x'),
            () => AprovarSucesso('t1'),
          ],
        );

        await confirmar(tester);

        expect(
          find.byKey(const Key('aprovar-dialog-override-pj')),
          findsOneWidget,
        );
        expect(find.text('3ª alocação na mesma semana'), findsOneWidget);
        expect(find.textContaining('Sinais de habitualidade'), findsOneWidget);

        await tester.tap(
          find.byKey(const Key('aprovar-dialog-override-pj-aceitar-btn')),
        );
        await tester.pumpAndSettle();

        expect(service.chamadas, [
          (id: 'c1', override: false),
          (id: 'c1', override: true),
        ]);
        expect(
          find.byKey(const Key('aprovar-snackbar-sucesso')),
          findsOneWidget,
        );
      },
    );

    testWidgets('D3 — Voltar desiste sem 2ª chamada', (tester) async {
      final service = await _pump(
        tester,
        aprovar: [
          () => AprovarBloqueio(erro: 'requer_override', mensagem: 'x'),
        ],
      );

      await confirmar(tester);
      await tester.tap(
        find.byKey(const Key('aprovar-dialog-override-pj-voltar-btn')),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('aprovar-dialog-override-pj')), findsNothing);
      expect(service.aprovacoes, 1);
    });

    testWidgets('ja_aprovada (409) → snackbar idempotente + reload', (
      tester,
    ) async {
      final service = await _pump(
        tester,
        aprovar: [() => AprovarJaAceita('t1')],
      );

      await confirmar(tester);

      expect(find.textContaining('já foi aceita'), findsOneWidget);
      expect(service.fetches, 2);
    });

    testWidgets('vaga_fechada → snackbar + reload', (tester) async {
      final service = await _pump(
        tester,
        aprovar: [() => AprovarBloqueio(erro: 'vaga_fechada', mensagem: 'x')],
      );

      await confirmar(tester);

      expect(find.textContaining('não está mais aberta'), findsOneWidget);
      expect(service.fetches, 2);
    });

    testWidgets(
      'erro de rede → snackbar com "Tentar de novo" que reabre o D1',
      (tester) async {
        await _pump(tester, aprovar: [() => AprovarErro()]);

        await confirmar(tester);

        expect(find.byKey(const Key('aprovar-snackbar-erro')), findsOneWidget);
        expect(
          find.textContaining('Não foi possível concluir o aceite'),
          findsOneWidget,
        );

        await tester.tap(find.text('Tentar de novo'));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('aprovar-dialog-confirmar')),
          findsOneWidget,
        );
      },
    );
  });
}
