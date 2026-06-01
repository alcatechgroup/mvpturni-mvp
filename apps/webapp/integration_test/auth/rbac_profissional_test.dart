// integration_test — STORY-038 CA-7 (CA-13b da STORY-016).
// Migra "profissional ativo loga e é roteado para rota interna" de rbac-login.spec.ts.
// Bate na API real (docker-compose + seed): usuário profissional.teste@turni.local.
//
// Rodar (Web): exige --dart-define=API_BASE_URL=<origem da API> (ver Makefile),
// pois sob flutter drive o app é servido numa porta efêmera sem o proxy /api.
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../helpers/login_helper.dart';
import '../helpers/pump_app.dart';
import '../helpers/route_helper.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('profissional ativo loga e sai de /login (CA-7)', (tester) async {
    await pumpApp(tester);
    assertOnRoute(tester, '/login');

    await loginAsProfissional(tester);

    // Login bem-sucedido: o destino depende do estado do funil (ativo → `/`,
    // demais → rota de funil). Em qualquer caso, NÃO permanece em /login.
    await awaitRouteLeaves(tester, '/login');
  });
}
