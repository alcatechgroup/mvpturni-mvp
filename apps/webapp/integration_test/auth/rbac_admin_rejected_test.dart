// integration_test — STORY-038 CA-8 (CA-13c da STORY-016).
// Migra "admin não loga no WebApp — vê banner de redirecionamento" de rbac-login.spec.ts.
// Bate na API real: admin@turni.local recebe 403 admin_must_use_backoffice.
//
// Rodar (Web): exige --dart-define=API_BASE_URL=<origem da API> (ver Makefile).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../helpers/login_helper.dart';
import '../helpers/pump_app.dart';
import '../helpers/route_helper.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('admin é rejeitado e vê banner para o Backoffice (CA-8)', (
    tester,
  ) async {
    await pumpApp(tester);
    assertOnRoute(tester, '/login');

    await loginAsAdmin(tester);

    // A API responde 403 (admin_must_use_backoffice); o app mostra o banner
    // informativo e mantém o usuário em /login.
    await pumpUntilFound(
      tester,
      find.byKey(const ValueKey('login:admin-banner')),
    );
    expect(find.text('Este usuário acessa o Backoffice.'), findsOneWidget);
    assertOnRoute(tester, '/login');
  });
}
