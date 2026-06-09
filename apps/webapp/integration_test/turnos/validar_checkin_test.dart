// integration_test — STORY-062 (E2E browser real: validação do PIN pelo contratante, CA-8).
//
// Same-origin (proxy + --web-launch-url, IDR-021) contra o BACKEND REAL, com o par
// exclusivo `*.validar.seed` (turno `confirmado` dentro da janela). Fluxo BILATERAL de
// verdade em cada cenário: o profissional loga, gera o PIN (o teste LÊ o plaintext da
// tela — única fonte, CA-4 da 061), e o contratante loga em seguida para validar.
//
//   1. geofencing false (geo negada) + PIN errado + recusa  → CA-5 (card de aviso),
//      CA-2 (erro inline) e CA-6 (dialog + motivo); turno volta a `confirmado`.
//   2. 3 PINs errados → CA-3: banner de expirado, turno volta a `confirmado`.
//   3. PIN correto → CA-1: snackbar + badge "Ativo" + timeline "Check-in validado".
//
// ORDEM IMPORTA: o cenário 3 CONSOME o turno (`ativo` não volta — máquina de estados);
// roda por último e o TurnosSeeder recria o turno no próximo `_e2e-seed` (recriação é
// exclusiva do par validar.seed). Cenários 1–2 são idempotentes (terminam `confirmado`).
//
// A POSIÇÃO do profissional é injetada via `debugCapturarPosicaoOverride` (o browser do
// harness não concede permissão de geolocalização programaticamente — mesmo padrão da 061).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:turni_webapp/features/turno/geolocalizacao.dart';

import '../helpers/login_helper.dart';
import '../helpers/pump_app.dart';
import '../helpers/route_helper.dart';

const _profissionalSeed = 'profissional.validar.seed@turni.local';
const _contratanteSeed = 'contratante.validar.seed@turni.local';
const _senha = 'password';

/// Card raiz de turno: `turno-card-{uuid}` (36 chars de uuid, sem sufixo).
final _cardDeTurno = find.byWidgetPredicate((w) {
  final k = w.key;
  return k is ValueKey<String> &&
      k.value.startsWith('turno-card-') &&
      k.value.length == 'turno-card-'.length + 36;
}, description: 'card raiz de turno');

/// Card de turno cujo badge mostra [estadoLabel] — o contratante validar.seed pode
/// acumular turnos `ativo` de execuções anteriores (o seed recria o consumido), então
/// a navegação ancora no ESTADO, não em "única carta".
Finder _cardComEstado(String estadoLabel) =>
    find.ancestor(of: find.text(estadoLabel), matching: _cardDeTurno).first;

/// Loga o PROFISSIONAL, navega até o detalhe do turno na janela, gera o PIN com a
/// [posicao] injetada e devolve o plaintext lido da tela do PIN. Sai voltando ao
/// detalhe (turno fica `aguardando_checkin`, PIN vivo).
Future<String> _proGeraPin(
  WidgetTester tester, {
  required PosicaoGeo posicao,
}) async {
  debugCapturarPosicaoOverride = () async => posicao;

  await pumpApp(tester);
  assertOnRoute(tester, '/login');
  await loginAs(tester, email: _profissionalSeed, password: _senha);
  await awaitRouteChange(tester, '/');
  await tester.pumpAndSettle();
  await pumpUntilFound(tester, find.byKey(const Key('feed-screen')));

  await goToTurnos(tester, profissional: true);
  await tester.pumpAndSettle();
  await pumpUntilFound(tester, find.byKey(const Key('meus-turnos-screen')));

  // Turno do seed: `confirmado` (caminho normal) ou `aguardando_checkin` (resto de
  // execução interrompida) — nos dois casos dá para (re)gerar o PIN.
  final confirmado = find
      .ancestor(of: find.text('Confirmado'), matching: _cardDeTurno)
      .evaluate()
      .isNotEmpty;
  await tester.tap(
    _cardComEstado(confirmado ? 'Confirmado' : 'Aguardando check-in'),
  );
  await tester.pumpAndSettle();
  await pumpUntilFound(tester, find.byKey(const Key('turno-detalhe-screen')));

  final gerarBtn = confirmado
      ? find.byKey(const Key('turno-pin-gerar-btn'))
      : find.byKey(const Key('turno-pin-regen-btn'));
  await pumpUntilFound(tester, gerarBtn);
  await tester.ensureVisible(gerarBtn);
  await tester.tap(gerarBtn);
  await pumpUntilFound(
    tester,
    find.byKey(const Key('pin-checkin-screen')),
    timeout: const Duration(seconds: 20),
  );

  final pin = tester
      .widget<Text>(find.byKey(const Key('pin-checkin-codigo')))
      .data!;
  expect(pin, matches(RegExp(r'^\d{4}$')));

  // Volta ao detalhe SEM cancelar — o PIN precisa continuar vivo para o contratante.
  await tester.tap(find.byKey(const Key('pin-checkin-voltar')).first);
  await tester.pumpAndSettle();

  return pin;
}

/// Loga o CONTRATANTE e navega até o detalhe do turno `aguardando_checkin`.
Future<void> _contratanteAteODetalhe(WidgetTester tester) async {
  await pumpApp(tester);
  assertOnRoute(tester, '/login');
  await loginAs(tester, email: _contratanteSeed, password: _senha);
  await awaitRouteChange(tester, '/');
  await tester.pumpAndSettle();

  await pumpUntilFound(tester, find.byKey(const Key('minhas-vagas-screen')));
  await goToTurnos(tester, profissional: false);
  await awaitRouteChange(tester, '/contratante/turnos');
  await pumpUntilFound(
    tester,
    find.byKey(const Key('contratante-turnos-screen')),
  );

  await tester.tap(_cardComEstado('Aguardando check-in'));
  await tester.pumpAndSettle();
  await pumpUntilFound(tester, find.byKey(const Key('turno-detalhe-screen')));
  await pumpUntilFound(tester, find.byKey(const Key('validar-checkin-area')));
}

/// Pumpa até [cond] (ou estoura [timeout]) — complemento do pumpUntilFound para
/// condições de DESAPARECIMENTO/estado (o stale-anchor quebra o E2E: ver _validarCom).
Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() cond, {
  Duration timeout = const Duration(seconds: 20),
  required String descricao,
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!cond()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('condição não satisfeita em ${timeout.inSeconds}s: $descricao');
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Digita [pin] e toca em Validar, e SÓ RETORNA quando a resposta da tentativa foi
/// processada pela UI — anchor no ciclo do botão, que é determinístico: `_validando`
/// desabilita o botão SINCRONAMENTE no tap e o reabilita quando a resposta chega
/// (ou o bloco some, quando o reload troca a área). Não depende de `onChanged`
/// (re-digitar o mesmo texto não o dispara) nem de limpar o campo (`enterText('')`
/// não esvazia o campo no Web) — aprendizados dos runs 2–4 deste gate.
Future<void> _validarCom(WidgetTester tester, String pin) async {
  final input = find.byKey(const Key('validar-checkin-pin-input'));
  final btn = find.byKey(const Key('validar-checkin-btn'));

  await tester.ensureVisible(input);
  await tester.enterText(input, pin);
  await tester.pump();

  await tester.ensureVisible(btn);
  await _pumpUntil(
    tester,
    () => tester.widget<FilledButton>(btn).enabled,
    descricao: 'botão Validar habilitado (4 dígitos, sem request em voo)',
  );
  await tester.tap(btn);
  await tester
      .pump(); // _validando=true é síncrono → botão desabilita já neste frame

  await _pumpUntil(
    tester,
    () => btn.evaluate().isEmpty || tester.widget<FilledButton>(btn).enabled,
    descricao:
        'resposta da validação processada (botão reabilitado ou área trocada)',
  );
}

/// PIN garantidamente diferente de [pin] (mesmo comprimento, 4 dígitos).
String _pinErrado(String pin) => pin == '0000' ? '1111' : '0000';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() => debugCapturarPosicaoOverride = null);

  testWidgets(
    'geo negada: contratante vê o card de aviso, erra o PIN (inline) e RECUSA com motivo '
    '(CA-2/5/6 — turno volta a confirmado)',
    (tester) async {
      final pin = await _proGeraPin(
        tester,
        posicao: const PosicaoGeo(razao: 'permissao_negada'),
      );

      await _contratanteAteODetalhe(tester);

      // CA-5 — aviso destacado antes do input; razão em linguagem humana; não bloqueia.
      await pumpUntilFound(
        tester,
        find.byKey(const Key('validar-checkin-geo-aviso')),
      );
      expect(
        find.textContaining(
          'Localização do profissional não disponível (permissão negada).',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('você pode validar mesmo assim'),
        findsOneWidget,
      );

      // CA-2 — PIN errado: erro inline, microcopy fixa, sem expor tentativas.
      await _validarCom(tester, _pinErrado(pin));
      await pumpUntilFound(
        tester,
        find.byKey(const Key('validar-checkin-pin-erro')),
        timeout: const Duration(seconds: 20),
      );
      expect(
        find.text('PIN inválido. Confira com o profissional.'),
        findsOneWidget,
      );

      // CA-6 — recusa com confirmação + motivo opcional → volta a `confirmado`.
      final recusar = find.byKey(const Key('recusar-checkin-btn'));
      await tester.ensureVisible(recusar);
      await tester.tap(recusar);
      await tester.pumpAndSettle();
      await pumpUntilFound(
        tester,
        find.byKey(const Key('recusar-checkin-dialog')),
      );
      await tester.enterText(
        find.byKey(const Key('recusar-checkin-motivo-input')),
        'Profissional ainda não chegou (E2E STORY-062)',
      );
      await tester.tap(find.byKey(const Key('recusar-checkin-confirmar-btn')));

      // Reload: badge volta a Confirmado, área de validação some, trilha registra.
      await pumpUntilFound(
        tester,
        find.text('Check-in recusado'),
        timeout: const Duration(seconds: 20),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('validar-checkin-area')), findsNothing);
      expect(find.text('Recusado pelo contratante.'), findsOneWidget);
    },
  );

  testWidgets(
    '3 PINs errados: PIN expira (CA-3) — banner, turno volta a confirmado e trilha registra',
    (tester) async {
      final pin = await _proGeraPin(
        tester,
        posicao: const PosicaoGeo(lat: -23.550135, lng: -46.63, accuracyM: 10),
      );

      await _contratanteAteODetalhe(tester);
      // Geo ok → SEM card de aviso (contraprova do CA-5).
      expect(find.byKey(const Key('validar-checkin-geo-aviso')), findsNothing);

      final errado = _pinErrado(pin);
      for (var i = 0; i < 2; i++) {
        await _validarCom(tester, errado);
        await pumpUntilFound(
          tester,
          find.byKey(const Key('validar-checkin-pin-erro')),
          timeout: const Duration(seconds: 20),
        );
      }

      // 3º erro → expira: banner warning + área some (turno `confirmado`).
      await _validarCom(tester, errado);
      await pumpUntilFound(
        tester,
        find.text(
          'PIN expirado por excesso de tentativas. '
          'Peça ao profissional para gerar um novo.',
        ),
        timeout: const Duration(seconds: 20),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('validar-checkin-area')), findsNothing);
      expect(find.text('PIN de check-in expirado'), findsWidgets);
    },
  );

  testWidgets(
    'PIN correto: check-in validado (CA-1) — snackbar, badge Ativo e "Turno iniciado." '
    '(consome o turno; o seed recria no próximo run)',
    (tester) async {
      final pin = await _proGeraPin(
        tester,
        posicao: const PosicaoGeo(lat: -23.550135, lng: -46.63, accuracyM: 10),
      );

      await _contratanteAteODetalhe(tester);
      await _validarCom(tester, pin);

      await pumpUntilFound(
        tester,
        find.byKey(const Key('validar-checkin-sucesso')),
        timeout: const Duration(seconds: 20),
      );
      await pumpUntilFound(
        tester,
        find.text('Check-in validado'),
        timeout: const Duration(seconds: 20),
      );
      await tester.pumpAndSettle();

      expect(find.text('Turno iniciado.'), findsOneWidget);
      expect(find.byKey(const Key('validar-checkin-area')), findsNothing);
      // Badge do detalhe: turno vivo agora (label do TurnoEstadoResumo.ativo).
      expect(
        find.descendant(
          of: find.byKey(const Key('turno-detalhe-estado')),
          matching: find.text('Em andamento'),
        ),
        findsOneWidget,
      );
    },
  );
}
