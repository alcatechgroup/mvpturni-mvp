import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:turni_webapp/core/theme/theme_mode_controller.dart';
import 'package:turni_webapp/features/app/perfil_reputacao_service.dart';
import 'package:turni_webapp/features/app/perfil_screen.dart';
import 'package:turni_webapp/features/auth/auth_service.dart';

// STORY-077 — Perfil mínimo (DDR-003): identidade + tema + Sair.
// STORY-088 (T3) — bloco de reputação acima de Preferências: score/nível/XP/depoimentos,
// reciprocidade (contratante sem nível/XP), e estados vazio/erro/loading (CA-1/CA-2/CA-5).

UserSession _session({
  String id = 'me-1',
  String name = 'Diego Martins',
  String role = 'profissional',
}) => UserSession(
  id: id,
  name: name,
  role: role,
  status: 'ativo',
  welcomeVisto: true,
  cadastroCompleto: true,
);

/// Fake do service: result controlável + contador (p/ exercitar o retry).
class _FakeReputacao extends PerfilReputacaoService {
  _FakeReputacao(this.result);
  ReputacaoResult Function() result;
  int calls = 0;
  @override
  Future<ReputacaoResult> fetch(String userId) async {
    calls++;
    return result();
  }
}

/// Fake que segura a resposta até ser liberada — para capturar o frame de loading.
class _PendingReputacao extends PerfilReputacaoService {
  final completer = Completer<ReputacaoResult>();
  @override
  Future<ReputacaoResult> fetch(String userId) => completer.future;
}

ReputacaoPerfil _perfilProf({
  bool seloNovo = false,
  int total = 27,
  List<Depoimento> depoimentos = const [],
}) => ReputacaoPerfil(
  papel: 'profissional',
  score: 4.9,
  totalAvaliacoes: total,
  seloNovo: seloNovo,
  nivel: 'Confiavel',
  turnosRealizados: 17,
  xp: 680,
  xpProximoNivel: 320,
  depoimentos: depoimentos,
);

ReputacaoPerfil _perfilContratante({List<Depoimento> depoimentos = const []}) =>
    ReputacaoPerfil(
      papel: 'contratante',
      score: 4.5,
      totalAvaliacoes: 8,
      seloNovo: false,
      nivel: null,
      turnosRealizados: null,
      xp: null,
      xpProximoNivel: null,
      depoimentos: depoimentos,
    );

Depoimento _depo({String? autor = 'Bar do Porto'}) => Depoimento(
  estrelas: 5,
  comentario: 'Pontual e atencioso',
  funcao: 'Garçom',
  autorNome: autor,
  data: DateTime.now().subtract(const Duration(days: 3)),
);

Future<void> _pump(WidgetTester tester, PerfilReputacaoService svc) async {
  await tester.pumpWidget(
    MaterialApp(home: PerfilScreen(reputacaoService: svc)),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ThemeModeController.instance.setMode(ThemeMode.system);
  });
  tearDown(() => AuthService().debugSetSession(null));

  // ─────────────── identidade / tema / sair (STORY-077, regressão) ───────────────

  testWidgets('(a) feliz — mostra nome e papel do profissional', (
    tester,
  ) async {
    AuthService().debugSetSession(_session());
    await _pump(
      tester,
      _FakeReputacao(() => ReputacaoCarregada(_perfilProf())),
    );
    expect(find.text('Diego Martins'), findsOneWidget);
    expect(find.text('Profissional'), findsOneWidget);
  });

  testWidgets('(d) borda — contratante vê o rótulo de papel correto', (
    tester,
  ) async {
    AuthService().debugSetSession(
      _session(name: 'Marina Souza', role: 'contratante'),
    );
    await _pump(
      tester,
      _FakeReputacao(() => ReputacaoCarregada(_perfilContratante())),
    );
    expect(find.text('Marina Souza'), findsOneWidget);
    expect(find.text('Contratante'), findsOneWidget);
  });

  testWidgets('(a) feliz — alterna o tema escuro e persiste', (tester) async {
    AuthService().debugSetSession(_session());
    await _pump(
      tester,
      _FakeReputacao(() => ReputacaoCarregada(_perfilProf())),
    );

    final toggle = find.byKey(const Key('shell-theme-toggle'));
    expect(toggle, findsOneWidget);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(ThemeModeController.instance.mode, ThemeMode.dark);
  });

  testWidgets('(a) feliz — expõe o botão Sair', (tester) async {
    AuthService().debugSetSession(_session());
    await _pump(
      tester,
      _FakeReputacao(() => ReputacaoCarregada(_perfilProf())),
    );
    expect(find.byKey(const Key('perfil-logout')), findsOneWidget);
  });

  // ─────────────── T3: reputação (CA-1) ───────────────

  testWidgets('CA-1 profissional: score + nível + XP + depoimentos', (
    tester,
  ) async {
    AuthService().debugSetSession(_session());
    await _pump(
      tester,
      _FakeReputacao(
        () => ReputacaoCarregada(_perfilProf(depoimentos: [_depo()])),
      ),
    );

    expect(find.byKey(const Key('perfil-score')), findsOneWidget);
    expect(find.byKey(const Key('perfil-nivel-badge')), findsOneWidget);
    expect(find.byKey(const Key('perfil-xp-meter')), findsOneWidget);
    expect(find.byKey(const Key('perfil-depoimentos')), findsOneWidget);
    expect(find.byKey(const Key('depoimento-item-0')), findsOneWidget);
    expect(find.text('Pontual e atencioso'), findsOneWidget);
  });

  testWidgets(
    'CA-1 depoimentos têm larguras IGUAIS (alinhados, não content-width)',
    (tester) async {
      AuthService().debugSetSession(_session());
      await _pump(
        tester,
        _FakeReputacao(
          () => ReputacaoCarregada(
            _perfilProf(
              depoimentos: [
                Depoimento(
                  estrelas: 5,
                  comentario: 'Curto.',
                  funcao: 'Garçom',
                  autorNome: 'Bar A',
                  data: DateTime.now().subtract(const Duration(days: 1)),
                ),
                Depoimento(
                  estrelas: 4,
                  comentario:
                      'Comentário bem mais longo que o anterior para forçar '
                      'larguras diferentes se os cards fossem content-width.',
                  funcao: 'Auxiliar de Cozinha',
                  autorNome: 'Restaurante do Porto',
                  data: DateTime.now().subtract(const Duration(days: 2)),
                ),
              ],
            ),
          ),
        ),
      );

      final w0 = tester
          .getSize(find.byKey(const Key('depoimento-item-0')))
          .width;
      final w1 = tester
          .getSize(find.byKey(const Key('depoimento-item-1')))
          .width;
      expect(w0, w1); // mesma largura cheia, independente do tamanho do texto
    },
  );

  // ─────────────── T3: reciprocidade do contratante (CA-2) ───────────────

  testWidgets('CA-2 contratante: score + depoimentos, SEM nível e SEM XP', (
    tester,
  ) async {
    AuthService().debugSetSession(_session(role: 'contratante'));
    await _pump(
      tester,
      _FakeReputacao(
        () => ReputacaoCarregada(
          _perfilContratante(depoimentos: [_depo(autor: null)]),
        ),
      ),
    );

    expect(find.byKey(const Key('perfil-score')), findsOneWidget);
    expect(find.byKey(const Key('perfil-nivel-badge')), findsNothing);
    expect(find.byKey(const Key('perfil-xp-meter')), findsNothing);
    expect(find.byKey(const Key('depoimento-item-0')), findsOneWidget);
  });

  // ─────────────── T3: estados (CA-5) ───────────────

  testWidgets('CA-5 loading — skeleton enquanto carrega (sem spinner pelado)', (
    tester,
  ) async {
    AuthService().debugSetSession(_session());
    final pending = _PendingReputacao();
    await tester.pumpWidget(
      MaterialApp(home: PerfilScreen(reputacaoService: pending)),
    );
    await tester.pump(); // 1 frame: ainda carregando

    expect(find.byKey(const Key('perfil-reputacao-skeleton')), findsOneWidget);

    pending.completer.complete(ReputacaoCarregada(_perfilProf()));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('perfil-reputacao-skeleton')), findsNothing);
  });

  testWidgets('CA-5 vazio sem avaliações → "Ainda sem avaliações"', (
    tester,
  ) async {
    AuthService().debugSetSession(_session());
    await _pump(
      tester,
      _FakeReputacao(
        () => ReputacaoCarregada(
          _perfilProf(seloNovo: true, total: 0, depoimentos: const []),
        ),
      ),
    );

    expect(find.byKey(const Key('perfil-depoimentos-vazio')), findsOneWidget);
    expect(find.text('Ainda sem avaliações'), findsOneWidget);
  });

  testWidgets('CA-5 com score mas sem comentário → "Ainda sem comentários"', (
    tester,
  ) async {
    AuthService().debugSetSession(_session());
    await _pump(
      tester,
      _FakeReputacao(
        () => ReputacaoCarregada(_perfilProf(total: 12, depoimentos: const [])),
      ),
    );

    expect(find.byKey(const Key('perfil-depoimentos-vazio')), findsOneWidget);
    expect(find.text('Ainda sem comentários'), findsOneWidget);
  });

  testWidgets('CA-5 erro — retry refaz a carga; Sair continua disponível', (
    tester,
  ) async {
    AuthService().debugSetSession(_session());
    var falha = true;
    final svc = _FakeReputacao(
      () => falha ? ReputacaoErro() : ReputacaoCarregada(_perfilProf()),
    );
    await _pump(tester, svc);

    expect(find.byKey(const Key('perfil-reputacao-retry')), findsOneWidget);
    // O resto do Perfil segue funcionando (CA-5).
    expect(find.byKey(const Key('perfil-logout')), findsOneWidget);

    falha = false;
    await tester.tap(find.byKey(const Key('perfil-reputacao-retry')));
    await tester.pumpAndSettle();

    expect(svc.calls, 2);
    expect(find.byKey(const Key('perfil-reputacao-retry')), findsNothing);
    expect(find.byKey(const Key('perfil-score')), findsOneWidget);
  });
}
