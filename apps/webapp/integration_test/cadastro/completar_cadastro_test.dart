// integration_test — STORY-023 CA-15 (E2E browser real, same-origin).
//
// Cobre a ÁREA LOGADA do completar cadastro: profissional em `await_cadastro` (liberado +
// welcome visto) loga → cai em /completar-cadastro → preenche → revisa o contrato renderizado
// (com seu documento) → aceita → fica ativo. É autenticado e faz mutação no backend
// (gera AceiteEletronico + transição → ativo), por isso roda SAME-ORIGIN (IDR-021), nunca
// cross-origin (o cookie de sessão Sanctum precisa trafegar).
//
// Upload de documento: o `file_picker` abre diálogo nativo do SO que o Chrome headless não
// dirige — o gate roda com `--dart-define=E2E_FAKE_PICKER=true`, sob o qual o picker padrão
// devolve um arquivo em memória (seam documentado na tela / IDR-022 §descobertas).
//
// Determinismo (CA-5): `make _e2e-seed` reseta os usuários `completar.pf@` / `completar.mei@`
// para `await_cadastro` com os campos de completar zerados a cada run.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../helpers/login_helper.dart';
import '../helpers/pump_app.dart';
import '../helpers/route_helper.dart';

const pfEmail = 'completar.pf@turni.local';
const meiEmail = 'completar.mei@turni.local';
const blockEmail =
    'completar.block@turni.local'; // nunca concluído — cenário sem checkbox

// Documentos válidos (dígitos verificadores ok) e distintos entre si.
const cpfValido = '529.982.247-25';
const cnpjValido = '11.222.333/0001-81';

Future<void> _preencher(
  WidgetTester tester, {
  required String documento,
}) async {
  await tester.enterText(
    find.byKey(const Key('completar-cadastro:documento')),
    documento,
  );
  await tester.enterText(
    find.byKey(const Key('completar-cadastro:raio')),
    '15',
  );
  await tester.enterText(
    find.byKey(const Key('completar-cadastro:preco')),
    '45',
  );
  await tester.enterText(
    find.byKey(const Key('completar-cadastro:pix')),
    'pix.e2e@turni.local',
  );
  await tester.ensureVisible(
    find.byKey(const Key('completar-cadastro:anexar')),
  );
  await tester.tap(find.byKey(const Key('completar-cadastro:anexar')));
  await tester.pumpAndSettle();
}

Future<void> _revisar(WidgetTester tester) async {
  await tester.ensureVisible(
    find.byKey(const Key('completar-cadastro:revisar')),
  );
  await tester.tap(find.byKey(const Key('completar-cadastro:revisar')));
  await pumpUntilFound(
    tester,
    find.byKey(const Key('completar-cadastro:contrato')),
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'PF: completa cadastro, vê o contrato com CPF e fica ativo (CA-15a)',
    (tester) async {
      await pumpApp(tester);
      await loginAs(tester, email: pfEmail, password: seedPassword);
      await awaitRouteChange(tester, '/completar-cadastro');

      // Contexto carregado (rótulo do documento por tipo_pessoa).
      await pumpUntilFound(tester, find.text('SEU DOCUMENTO (CPF)'));

      await _preencher(tester, documento: cpfValido);
      await _revisar(tester);

      // Preview mostra o contrato renderizado com o CPF do usuário.
      expect(find.textContaining('529.982.247-25'), findsWidgets);

      // Consentimento + aceite.
      await tester.ensureVisible(
        find.byKey(const Key('completar-cadastro:aceite')),
      );
      await tester.tap(find.byKey(const Key('completar-cadastro:aceite')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const Key('completar-cadastro:concluir')),
      );
      await tester.tap(find.byKey(const Key('completar-cadastro:concluir')));

      // Sucesso → continua para a home (usuário agora ativo).
      await pumpUntilFound(
        tester,
        find.byKey(const Key('completar-cadastro:sucesso')),
      );
      await tester.ensureVisible(
        find.byKey(const Key('completar-cadastro:continuar')),
      );
      await tester.tap(find.byKey(const Key('completar-cadastro:continuar')));
      await awaitRouteChange(tester, '/');
    },
  );

  testWidgets('MEI: completa cadastro com CNPJ e template MEI/PJ (CA-15b)', (
    tester,
  ) async {
    await pumpApp(tester);
    await loginAs(tester, email: meiEmail, password: seedPassword);
    await awaitRouteChange(tester, '/completar-cadastro');

    await pumpUntilFound(tester, find.text('SEU DOCUMENTO (CNPJ)'));

    await _preencher(tester, documento: cnpjValido);
    await _revisar(tester);
    expect(find.textContaining('11.222.333/0001-81'), findsWidgets);

    await tester.ensureVisible(
      find.byKey(const Key('completar-cadastro:aceite')),
    );
    await tester.tap(find.byKey(const Key('completar-cadastro:aceite')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('completar-cadastro:concluir')),
    );
    await tester.tap(find.byKey(const Key('completar-cadastro:concluir')));
    await pumpUntilFound(
      tester,
      find.byKey(const Key('completar-cadastro:sucesso')),
    );
  });

  testWidgets(
    'sem marcar o checkbox, o botão de aceite fica desabilitado (CA-15c/CA-8)',
    (tester) async {
      // Usuário dedicado que o E2E nunca conclui → sempre await_cadastro.
      await pumpApp(tester);
      await loginAs(tester, email: blockEmail, password: seedPassword);
      await awaitRouteChange(tester, '/completar-cadastro');

      await pumpUntilFound(
        tester,
        find.byKey(const Key('completar-cadastro:documento')),
      );
      await _preencher(tester, documento: cpfValido);
      await _revisar(tester);

      // Botão de aceite desabilitado enquanto o checkbox não está marcado (CA-8).
      final botao = tester.widget<FilledButton>(
        find.byKey(const Key('completar-cadastro:concluir')),
      );
      expect(botao.onPressed, isNull);
    },
  );
}
