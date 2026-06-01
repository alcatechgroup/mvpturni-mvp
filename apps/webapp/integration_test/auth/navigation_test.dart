// integration_test — STORY-038: navegação pública a partir do login.
// Migra os cenários "Criar conta de profissional/estabelecimento" do grupo
// "navegação" de rbac-login.spec.ts (que será removido — CA-10). Sem CA próprio,
// mas preserva cobertura (quality-standards §1.4). Rotas de cadastro são públicas
// (router guard), então não tocam a API.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../helpers/pump_app.dart';
import '../helpers/route_helper.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('link "Criar conta de profissional" leva ao pré-cadastro', (
    tester,
  ) async {
    await pumpApp(tester);
    assertOnRoute(tester, '/login');

    await tester.tap(find.byKey(const ValueKey('login:create-professional')));
    await tester.pumpAndSettle();

    assertOnRoute(tester, '/cadastro/profissional');
  });

  testWidgets('link "Criar conta de estabelecimento" leva ao pré-cadastro', (
    tester,
  ) async {
    await pumpApp(tester);
    assertOnRoute(tester, '/login');

    await tester.tap(find.byKey(const ValueKey('login:create-establishment')));
    await tester.pumpAndSettle();

    assertOnRoute(tester, '/cadastro/contratante');
  });
}
