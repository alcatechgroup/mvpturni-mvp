// integration_test — STORY-038 CA-9 (funnel guard: rotas internas exigem auth).
// Migra "/welcome sem auth → /login" e "/completar-cadastro sem auth → /login"
// de rbac-login.spec.ts (CA-10/CA-11 da STORY-016). Inclui também o root `/`
// protegido (mesma regra de guard, estava no grupo "navegação" do spec removido).
//
// Sem API: o guard decide o redirect a partir da sessão (null) em memória.
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../helpers/pump_app.dart';
import '../helpers/route_helper.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('root `/` sem sessão redireciona para /login', (tester) async {
    // pumpApp monta em `/`; o funnel guard manda para /login quando não há sessão.
    await pumpApp(tester);
    assertOnRoute(tester, '/login');
  });

  testWidgets('/welcome sem sessão redireciona para /login (CA-9)', (
    tester,
  ) async {
    await pumpApp(tester, initialRoute: '/welcome');
    assertOnRoute(tester, '/login');
  });

  testWidgets('/completar-cadastro sem sessão redireciona para /login (CA-9)', (
    tester,
  ) async {
    await pumpApp(tester, initialRoute: '/completar-cadastro');
    assertOnRoute(tester, '/login');
  });
}
