// Smoke test: garante que TurniApp inicializa sem erro. Como o root `/` é a home
// pós-login (protegida), sem sessão o funnel guard redireciona para /login.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turni_webapp/main.dart';

void main() {
  testWidgets('TurniApp inicializa e o root protegido cai no login', (
    tester,
  ) async {
    await tester.pumpWidget(const TurniApp());
    await tester.pumpAndSettle();

    // Sem sessão, o root `/` redireciona para a tela de login.
    expect(find.byKey(const Key('screen-login-webapp')), findsOneWidget);
    expect(find.byKey(const Key('btn-submit-login')), findsOneWidget);
  });
}
