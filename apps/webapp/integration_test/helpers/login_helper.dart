// Helper de login para integration_test (STORY-038 / IDR-011 §c).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turni_webapp/router.dart';

import 'route_helper.dart';

/// Senha dos usuários de seed (`_e2e-seed` no Makefile). Sobrescrevível por
/// `--dart-define=ADMIN_SEED_PASSWORD=...` para alinhar com homolog.
const seedPassword = String.fromEnvironment(
  'ADMIN_SEED_PASSWORD',
  defaultValue: 'turni-dev',
);

/// E-mail do profissional ativo do seed (CA-13b).
const profissionalSeedEmail = 'profissional.teste@turni.local';

/// E-mail do contratante ativo do seed (STORY-046 — publicar vaga).
const contratanteSeedEmail = 'contratante.teste@turni.local';

/// E-mail do admin do seed (CA-13c). Sobrescrevível por `--dart-define`.
const adminSeedEmail = String.fromEnvironment(
  'ADMIN_SEED_EMAIL',
  defaultValue: 'admin@turni.local',
);

/// Preenche o formulário de `/login` com [email]/[password] e submete.
///
/// Assume que o app já foi montado (via `pumpApp`); navega para `/login` se ainda
/// não estiver lá. **Não asseria o resultado** — quem chama decide o que esperar
/// (redirect via [awaitRouteChange], banner de erro via `find.byKey`, etc.),
/// porque o desfecho depende do estado do usuário no backend.
///
/// Não usa `pumpAndSettle()` após o submit de propósito: enquanto o login está em
/// voo o botão mostra um `CircularProgressIndicator` (animação contínua), que faz
/// `pumpAndSettle()` nunca quiescer. Use [awaitRouteChange] ou aguarde o banner.
///
/// Exemplo:
/// ```dart
/// await pumpApp(tester);
/// await loginAs(tester, email: profissionalSeedEmail, password: seedPassword);
/// await awaitRouteChange(tester, '/');
/// ```
Future<void> loginAs(
  WidgetTester tester, {
  required String email,
  required String password,
}) async {
  if (currentRoute() != '/login') {
    router.go('/login');
    await tester.pumpAndSettle();
  }
  // Web (flutter drive): `tester.enterText` frequentemente NÃO preenche o campo
  // (flutter/flutter#100393). Caminho confiável (doc oficial do flutter_test):
  // garantir o foco com um TAP real no campo e então injetar o texto via
  // `testTextInput`. Registramos o mock de input antes (necessário no binding de
  // integração na web).
  tester.testTextInput.register();
  await _fillField(tester, const ValueKey('login:email'), email);
  await _fillField(tester, const ValueKey('login:password'), password);
  await tester.tap(find.byKey(const ValueKey('login:submit')));
  await tester
      .pump(); // dispara a requisição; o desfecho é aguardado por quem chama
}

/// Foca o campo [key] com um tap real e injeta [text] pelo `testTextInput`
/// (confiável na web — ver [loginAs]). Verifica que o texto entrou de fato e
/// falha com mensagem clara caso contrário (em vez de estourar só lá no
/// `awaitRouteChange`).
Future<void> _fillField(WidgetTester tester, Key key, String text) async {
  await tester.tap(find.byKey(key));
  await tester.pumpAndSettle();
  tester.testTextInput.enterText(text);
  await tester.pumpAndSettle();

  final editable = find.descendant(
    of: find.byKey(key),
    matching: find.byType(EditableText),
  );
  final atual = tester.widget<EditableText>(editable).controller.text;
  if (atual != text) {
    fail(
      'Campo $key não preencheu na web (#100393): esperado "$text", '
      'obtido "$atual"',
    );
  }
}

/// Atalho: loga como o profissional ativo do seed (CA-13b).
Future<void> loginAsProfissional(WidgetTester tester) =>
    loginAs(tester, email: profissionalSeedEmail, password: seedPassword);

/// Atalho: loga como o admin do seed — rejeitado no WebApp (CA-13c).
Future<void> loginAsAdmin(WidgetTester tester) =>
    loginAs(tester, email: adminSeedEmail, password: seedPassword);

/// Atalho: loga como o contratante ativo do seed (STORY-046).
Future<void> loginAsContratante(WidgetTester tester) =>
    loginAs(tester, email: contratanteSeedEmail, password: seedPassword);
