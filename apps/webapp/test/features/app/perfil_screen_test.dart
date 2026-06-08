import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:turni_webapp/core/theme/theme_mode_controller.dart';
import 'package:turni_webapp/features/app/perfil_screen.dart';
import 'package:turni_webapp/features/auth/auth_service.dart';

// STORY-077 — Perfil mínimo (DDR-003): consolida identidade do usuário,
// alternância de tema e Sair (chrome que hoje vive espalhado). Sem feature nova.

UserSession _session({
  String name = 'Diego Martins',
  String role = 'profissional',
}) => UserSession(
  name: name,
  role: role,
  status: 'ativo',
  welcomeVisto: true,
  cadastroCompleto: true,
);

Future<void> _pump(WidgetTester tester) async {
  await tester.pumpWidget(const MaterialApp(home: PerfilScreen()));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ThemeModeController.instance.setMode(ThemeMode.system);
  });
  tearDown(() => AuthService().debugSetSession(null));

  testWidgets('(a) feliz — mostra nome e papel do profissional', (
    tester,
  ) async {
    AuthService().debugSetSession(_session());
    await _pump(tester);
    expect(find.text('Diego Martins'), findsOneWidget);
    expect(find.text('Profissional'), findsOneWidget);
  });

  testWidgets('(d) borda — contratante vê o rótulo de papel correto', (
    tester,
  ) async {
    AuthService().debugSetSession(
      _session(name: 'Marina Souza', role: 'contratante'),
    );
    await _pump(tester);
    expect(find.text('Marina Souza'), findsOneWidget);
    expect(find.text('Contratante'), findsOneWidget);
  });

  testWidgets('(b) inválido — sessão sem nome não quebra (avatar fallback)', (
    tester,
  ) async {
    AuthService().debugSetSession(_session(name: ''));
    await _pump(tester);
    expect(find.byKey(const Key('perfil-screen')), findsOneWidget);
    expect(find.text('Profissional'), findsOneWidget);
  });

  testWidgets(
    '(a) feliz — alterna o tema escuro pelo switch e persiste no controller',
    (tester) async {
      AuthService().debugSetSession(_session());
      await _pump(tester);

      final toggle = find.byKey(const Key('shell-theme-toggle'));
      expect(toggle, findsOneWidget);
      expect(ThemeModeController.instance.mode, ThemeMode.system);

      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(ThemeModeController.instance.mode, ThemeMode.dark);
    },
  );

  testWidgets('(a) feliz — expõe o sino de notificações e o botão Sair', (
    tester,
  ) async {
    AuthService().debugSetSession(_session());
    await _pump(tester);
    expect(find.byKey(const Key('notificacoes-sino-btn')), findsOneWidget);
    expect(find.byKey(const Key('perfil-logout')), findsOneWidget);
  });
}
