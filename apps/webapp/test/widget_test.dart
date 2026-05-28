// Smoke test: garante que TurniApp inicializa sem erro e renderiza a tela de boas-vindas.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turni_webapp/main.dart';

void main() {
  testWidgets('TurniApp renderiza a tela de boas-vindas', (tester) async {
    await tester.pumpWidget(const TurniApp());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('screen-welcome-webapp')), findsOneWidget);
    expect(find.byKey(const Key('screen-welcome-brand')), findsOneWidget);
    expect(find.byKey(const Key('screen-welcome-health-link')), findsOneWidget);
    expect(find.byKey(const Key('screen-welcome-version')), findsOneWidget);
  });
}
