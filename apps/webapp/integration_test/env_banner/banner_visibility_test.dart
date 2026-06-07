// integration_test — STORY-075 (PDR-017): banner global "Ambiente de teste —
// pagamentos simulados".
//
// A suíte é sensível ao build: com `--dart-define=TURNI_ENV=homolog` (alvo
// `e2e-webapp-banner` do Makefile) ela exercita o caminho FELIZ (banner visível
// pós-login) + pré-auth ausente; SEM o define (gate normal, `web_test.dart`,
// ambiente `local`) ela exercita o caminho alternativo do CA-2 — logado e ainda
// assim sem banner. Os dois modos rodam no gate local (IDR-004).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:turni_webapp/core/env/env_banner.dart';
import 'package:turni_webapp/router.dart';

import '../helpers/login_helper.dart';
import '../helpers/pump_app.dart';
import '../helpers/route_helper.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const banner = Key('env-banner');
  const emHomolog = turniEnv == 'homolog';

  testWidgets('pré-auth (/login) NUNCA mostra o banner — CA-4', (tester) async {
    await pumpApp(tester);
    assertOnRoute(tester, '/login');

    expect(find.byKey(banner), findsNothing);
  });

  testWidgets(
    emHomolog
        ? 'homolog: banner visível pós-login com a microcopy exata — CA-1'
        : 'local: logado e MESMO ASSIM sem banner — CA-2',
    (tester) async {
      await pumpApp(tester);
      await loginAsProfissional(tester);
      await awaitRouteLeaves(tester, '/login');
      await tester.pumpAndSettle();

      if (emHomolog) {
        expect(find.byKey(banner), findsOneWidget);
        expect(find.text(EnvBanner.microcopy), findsOneWidget);
      } else {
        expect(find.byKey(banner), findsNothing);
      }
    },
  );

  testWidgets(
    emHomolog
        ? 'homolog: banner persiste ao navegar entre telas autenticadas — CA-1'
        : 'local: segue sem banner ao navegar entre telas autenticadas — CA-2',
    (tester) async {
      await pumpApp(tester);
      await loginAsContratante(tester);
      await awaitRouteLeaves(tester, '/login');
      await tester.pumpAndSettle();

      // Contratante: home é "Minhas vagas"; navega para outra tela autenticada.
      router.go('/contratante/turnos');
      await tester.pumpAndSettle();

      expect(find.byKey(banner), emHomolog ? findsOneWidget : findsNothing);
    },
  );
}
