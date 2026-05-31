import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turni_webapp/ds/theme.dart';
import 'package:turni_webapp/features/app/app_shell_screen.dart';
import 'package:turni_webapp/features/auth/auth_service.dart';

// STORY-037 — CA-11 — rótulo de versão no rodapé do shell da área logada.

void main() {
  testWidgets('mostra o rótulo de versão discreto no rodapé (CA-11)', (
    tester,
  ) async {
    AuthService().debugSetSession(
      const UserSession(
        name: 'Diego',
        role: 'profissional',
        status: 'ativo',
        welcomeVisto: true,
        cadastroCompleto: true,
      ),
    );
    addTearDown(() => AuthService().debugSetSession(null));

    await tester.pumpWidget(
      MaterialApp(theme: buildLightTheme(), home: const AppShellScreen()),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('app-version-label-app-shell')),
      findsOneWidget,
    );
    expect(find.text('Turni · dev'), findsOneWidget);
    // Continua mostrando o botão Sair (rótulo abaixo dele).
    expect(find.text('Sair'), findsOneWidget);
  });
}
