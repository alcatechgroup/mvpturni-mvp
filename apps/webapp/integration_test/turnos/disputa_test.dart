// integration_test — STORY-094 (E2E browser real: abertura de disputa pelo CONTRATANTE).
//
// STATUS: mantido FORA do gate (mesma decisão do checkout_test.dart — custo de browser
// real). RODÁVEL SOB DEMANDA via entrypoint top-level que inicialize o binding (imports
// `../helpers` não resolvem mirando o leaf direto — IDR-021):
//   printf "import 'package:integration_test/integration_test.dart';\n%s\n%s\n" \
//     "import 'turnos/disputa_test.dart' as d;" \
//     "void main(){IntegrationTestWidgetsFlutterBinding.ensureInitialized();d.main();}" \
//     > integration_test/_disputa_solo_test.dart
//   make e2e-webapp-pinned E2E_TARGET=integration_test/_disputa_solo_test.dart
//
// Same-origin (proxy + --web-launch-url, IDR-021) contra o BACKEND REAL, com o par
// exclusivo `*.disputa.seed` (turno já em `aguardando_checkout` — TurnosSeeder::
// seedTurnoEmCheckout). UM cenário percorre o ramo de EXCEÇÃO do check-out:
//
//   1. contratante abre o turno em `aguardando_checkout` e toca "Recusar check-out";
//   2. a folha de desambiguação abre; ele escolhe "Tenho um problema com este turno";
//   3. o diálogo de disputa exige justificativa: confirmar fica DESABILITADO vazio (CA-2);
//   4. com justificativa válida, "Abrir disputa" → snackbar de sucesso e o turno some da
//      validação, entrando em `em_disputa` (banner sóbrio do contratante — CA-3).
//
// O cenário CONSOME o turno (em_disputa não volta a aguardando_checkout); o TurnosSeeder
// recria o par no próximo `_e2e-seed`.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../helpers/login_helper.dart';
import '../helpers/pump_app.dart';
import '../helpers/route_helper.dart';

const _contratanteSeed = 'contratante.disputa.seed@turni.local';
const _senha = 'password';

/// Card raiz de turno: `turno-card-{uuid}` (36 chars de uuid, sem sufixo).
final _cardDeTurno = find.byWidgetPredicate((w) {
  final k = w.key;
  return k is ValueKey<String> &&
      k.value.startsWith('turno-card-') &&
      k.value.length == 'turno-card-'.length + 36;
}, description: 'card raiz de turno');

/// Único card em `aguardando_checkout` do par seed (os consumidos ficam em `em_disputa`).
Finder _cardAguardandoCheckout() => find
    .ancestor(of: find.text('Aguardando check-out'), matching: _cardDeTurno)
    .first;

/// Assenta transições SEM exigir quiescência total — `pumpAndSettle` pendura no timer do
/// cronômetro congelado (mesma causa-raiz do checkout_test, STORY-082).
Future<void> _assenta(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _semSnackBar(WidgetTester tester) async {
  final deadline = DateTime.now().add(const Duration(seconds: 8));
  while (find.byType(SnackBar).evaluate().isNotEmpty) {
    if (DateTime.now().isAfter(deadline)) break;
    await tester.pump(const Duration(milliseconds: 100));
  }
}

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

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'contratante recusa o check-out e abre disputa com justificativa → em_disputa (CA-1/2/3)',
    (tester) async {
      await _semSnackBar(tester);
      await pumpApp(tester);
      assertOnRoute(tester, '/login');
      await loginAs(tester, email: _contratanteSeed, password: _senha);
      await awaitRouteChange(tester, '/');
      await _assenta(tester);

      await goToTurnos(tester, profissional: false);
      await awaitRouteChange(tester, '/contratante/turnos');
      await pumpUntilFound(
        tester,
        find.byKey(const Key('contratante-turnos-screen')),
      );

      // Abre o turno em aguardando_checkout (único do par seed nesse estado).
      await pumpUntilFound(tester, _cardAguardandoCheckout());
      await tester.ensureVisible(_cardAguardandoCheckout());
      await tester.tap(_cardAguardandoCheckout());
      await _assenta(tester);
      await pumpUntilFound(
        tester,
        find.byKey(const Key('turno-detalhe-screen')),
      );

      // ── 1. "Recusar check-out" → folha de desambiguação (CA-1) ──
      await pumpUntilFound(
        tester,
        find.byKey(const Key('validar-checkout-area')),
      );
      final recusar = find.byKey(const Key('recusar-checkout-btn'));
      await tester.ensureVisible(recusar);
      await tester.tap(recusar);
      await _assenta(tester);
      await pumpUntilFound(
        tester,
        find.byKey(const Key('disputa-intencao-sheet')),
      );

      // ── 2. "Tenho um problema" → diálogo de disputa ──
      await tester.tap(find.byKey(const Key('disputa-intencao-problema')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('disputa-intencao-continuar')));
      await _assenta(tester);
      await pumpUntilFound(
        tester,
        find.byKey(const Key('abrir-disputa-dialog')),
      );

      // ── 3. CA-2 — confirmar desabilitado sem justificativa ──
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('abrir-disputa-confirmar-btn')),
            )
            .enabled,
        isFalse,
      );

      // ── 4. justificativa válida → abrir disputa (CA-3) ──
      await tester.enterText(
        find.byKey(const Key('abrir-disputa-justificativa-input')),
        'O profissional saiu antes do fim combinado.',
      );
      await tester.pump();
      final confirmar = find.byKey(const Key('abrir-disputa-confirmar-btn'));
      await _pumpUntil(
        tester,
        () => tester.widget<FilledButton>(confirmar).enabled,
        descricao: 'botão "Abrir disputa" habilitado com justificativa',
      );
      await tester.tap(confirmar);
      await tester.pump(); // _enviando=true é síncrono

      await pumpUntilFound(
        tester,
        find.byKey(const Key('abrir-disputa-sucesso')),
        timeout: const Duration(seconds: 20),
      );
      await _assenta(tester);

      // em_disputa: a validação saiu e o banner sóbrio do contratante aparece (CA-3).
      await _pumpUntil(
        tester,
        () =>
            find
                .byKey(const Key('disputa-contratante-banner'))
                .evaluate()
                .isNotEmpty &&
            find.byKey(const Key('validar-checkout-area')).evaluate().isEmpty,
        timeout: const Duration(seconds: 20),
        descricao: 'turno em em_disputa (banner sóbrio, sem validação)',
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('turno-detalhe-estado')),
          matching: find.text('Em disputa'),
        ),
        findsOneWidget,
      );
    },
  );
}
