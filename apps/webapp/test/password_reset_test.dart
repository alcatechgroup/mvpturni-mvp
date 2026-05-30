import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turni_webapp/ds/theme.dart';
import 'package:turni_webapp/features/auth/forgot_password_screen.dart';
import 'package:turni_webapp/features/auth/password_reset_service.dart';
import 'package:turni_webapp/features/auth/redefinir_senha_screen.dart';

// STORY-021 CA-6/CA-13b — widget tests do fluxo de recuperação de senha.

/// Serviço fake — não toca a rede.
class _FakeService extends PasswordResetService {
  _FakeService({this.onRequest, this.onReset});
  final Future<ResetResult> Function(String email)? onRequest;
  final Future<ResetResult> Function()? onReset;

  @override
  Future<ResetResult> requestReset(String email) async =>
      onRequest?.call(email) ?? const ResetOk();

  @override
  Future<ResetResult> reset({
    required String token,
    required String email,
    required String password,
    required String passwordConfirmation,
  }) async => onReset?.call() ?? const ResetOk();
}

Future<void> _pump(WidgetTester tester, Widget screen) async {
  await tester.binding.setSurfaceSize(const Size(420, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(theme: buildLightTheme(), home: screen));
}

void main() {
  group('ForgotPasswordScreen', () {
    testWidgets('e-mail válido → banner neutro de sucesso', (tester) async {
      await _pump(tester, ForgotPasswordScreen(service: _FakeService()));
      await tester.enterText(find.byKey(const Key('input-email')), 'a@b.com');
      await tester.tap(find.byKey(const Key('btn-submit-forgot')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('banner-forgot-success')), findsOneWidget);
    });

    testWidgets('falha de rede → mostra erro', (tester) async {
      await _pump(
        tester,
        ForgotPasswordScreen(
          service: _FakeService(
            onRequest: (_) async => const ResetNetworkError(),
          ),
        ),
      );
      await tester.enterText(find.byKey(const Key('input-email')), 'a@b.com');
      await tester.tap(find.byKey(const Key('btn-submit-forgot')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('forgot-error')), findsOneWidget);
      expect(find.byKey(const Key('banner-forgot-success')), findsNothing);
    });

    testWidgets('e-mail vazio → validação bloqueia submit', (tester) async {
      var chamou = false;
      await _pump(
        tester,
        ForgotPasswordScreen(
          service: _FakeService(
            onRequest: (_) async {
              chamou = true;
              return const ResetOk();
            },
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('btn-submit-forgot')));
      await tester.pumpAndSettle();
      expect(chamou, isFalse);
      expect(find.text('Este campo é obrigatório.'), findsOneWidget);
    });
  });

  group('RedefinirSenhaScreen', () {
    testWidgets('token ausente → tela de link inválido', (tester) async {
      await _pump(tester, const RedefinirSenhaScreen(token: '', email: ''));
      expect(find.byKey(const Key('redefinir-token-invalido')), findsOneWidget);
    });

    testWidgets('sucesso → banner + botão ir para login', (tester) async {
      await _pump(
        tester,
        RedefinirSenhaScreen(
          token: 'tok',
          email: 'a@b.com',
          service: _FakeService(onReset: () async => const ResetOk()),
        ),
      );
      await tester.enterText(
        find.byKey(const Key('input-password')),
        'NovaSenha@2026',
      );
      await tester.enterText(
        find.byKey(const Key('input-password-confirm')),
        'NovaSenha@2026',
      );
      await tester.tap(find.byKey(const Key('btn-submit-redefinir')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('redefinir-success')), findsOneWidget);
      expect(find.byKey(const Key('btn-ir-login')), findsOneWidget);
    });

    testWidgets('token inválido do servidor → tela de link inválido', (
      tester,
    ) async {
      await _pump(
        tester,
        RedefinirSenhaScreen(
          token: 'velho',
          email: 'a@b.com',
          service: _FakeService(onReset: () async => const ResetInvalidToken()),
        ),
      );
      await tester.enterText(
        find.byKey(const Key('input-password')),
        'NovaSenha@2026',
      );
      await tester.enterText(
        find.byKey(const Key('input-password-confirm')),
        'NovaSenha@2026',
      );
      await tester.tap(find.byKey(const Key('btn-submit-redefinir')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('redefinir-token-invalido')), findsOneWidget);
    });

    testWidgets('senhas diferentes → validação bloqueia', (tester) async {
      var chamou = false;
      await _pump(
        tester,
        RedefinirSenhaScreen(
          token: 'tok',
          email: 'a@b.com',
          service: _FakeService(
            onReset: () async {
              chamou = true;
              return const ResetOk();
            },
          ),
        ),
      );
      await tester.enterText(
        find.byKey(const Key('input-password')),
        'NovaSenha@2026',
      );
      await tester.enterText(
        find.byKey(const Key('input-password-confirm')),
        'Diferente@2026',
      );
      await tester.tap(find.byKey(const Key('btn-submit-redefinir')));
      await tester.pumpAndSettle();
      expect(chamou, isFalse);
      expect(find.text('As senhas não coincidem.'), findsOneWidget);
    });
  });
}
