// integration_test — STORY-024 CA-15 (E2E browser real, same-origin).
//
// Cobre a ÁREA LOGADA do completar cadastro do CONTRATANTE: contratante em `await_cadastro`
// (liberado + welcome visto) loga → cai em /completar-cadastro (router ramifica por papel) →
// preenche o wizard de 3 passos → revisa os Termos de Adesão renderizados (com CNPJ + taxa
// Turni 15%) → aceita → fica ativo. Autenticado e com mutação no backend (gera AceiteEletronico
// referenciando termos_plataforma_contratante + transição → ativo), por isso roda SAME-ORIGIN
// (IDR-021).
//
// Determinismo (CA-15): `make _e2e-seed` reseta `completar.contratante@` para `await_cadastro`
// com os campos de completar zerados a cada run (AdminUserSeeder §6).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../helpers/login_helper.dart';
import '../helpers/pump_app.dart';
import '../helpers/route_helper.dart';

const contratanteEmail = 'completar.contratante@turni.local';
const cnpjValido = '11.222.333/0001-81';

Future<void> _selecionar(
  WidgetTester tester,
  String fieldKey,
  String valor,
) async {
  await tester.ensureVisible(find.byKey(Key(fieldKey)));
  await tester.tap(find.byKey(Key(fieldKey)));
  await tester.pumpAndSettle();
  // Toca o item no menu aberto. Para o dropdown de UF (27 itens) o menu é um ListView
  // lazy em viewport headless — itens fora da dobra não são construídos; por isso o E2E
  // seleciona valores no topo da lista (o valor exato é irrelevante para a asserção, que
  // verifica o CNPJ renderizado).
  await tester.tap(find.text(valor).last);
  await tester.pumpAndSettle();
}

Future<void> _continuar(WidgetTester tester) async {
  await tester.ensureVisible(
    find.byKey(const Key('completar-cadastro:continuar')),
  );
  await tester.tap(find.byKey(const Key('completar-cadastro:continuar')));
  await tester.pumpAndSettle();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Contratante completa cadastro, vê os termos com CNPJ + taxa e fica ativo (CA-15)',
    (tester) async {
      await pumpApp(tester);
      await loginAs(tester, email: contratanteEmail, password: seedPassword);
      await awaitRouteChange(tester, '/completar-cadastro');

      // Passo 1 — Identidade do Estabelecimento.
      await pumpUntilFound(
        tester,
        find.byKey(const Key('completar-cadastro:cnpj')),
      );
      await tester.enterText(
        find.byKey(const Key('completar-cadastro:cnpj')),
        cnpjValido,
      );
      await tester.enterText(
        find.byKey(const Key('completar-cadastro:cep')),
        '01001-000',
      );
      await tester.enterText(
        find.byKey(const Key('completar-cadastro:logradouro')),
        'Praça da Sé',
      );
      await tester.enterText(
        find.byKey(const Key('completar-cadastro:numero')),
        '100',
      );
      await tester.enterText(
        find.byKey(const Key('completar-cadastro:bairro')),
        'Centro',
      );
      // Cidade vem pré-preenchida do pré-cadastro; sobrescreve para casar com a UF do topo.
      await tester.enterText(
        find.byKey(const Key('completar-cadastro:cidade')),
        'Rio Branco',
      );
      await _selecionar(tester, 'completar-cadastro:uf', 'AC');
      await _continuar(tester);

      // Passo 2 — Operação.
      await pumpUntilFound(
        tester,
        find.byKey(const Key('completar-cadastro:segmento')),
      );
      await tester.enterText(
        find.byKey(const Key('completar-cadastro:segmento')),
        'Bar e petiscaria',
      );
      await tester.enterText(
        find.byKey(const Key('completar-cadastro:ano-fundacao')),
        '2015',
      );
      await _selecionar(tester, 'completar-cadastro:qtd-funcionarios', '11-50');
      await _continuar(tester);

      // Passo 3 — Cultura & Contatos (tudo opcional) → revisar termos.
      await pumpUntilFound(
        tester,
        find.byKey(const Key('completar-cadastro:revisar')),
      );
      await tester.ensureVisible(
        find.byKey(const Key('completar-cadastro:revisar')),
      );
      await tester.tap(find.byKey(const Key('completar-cadastro:revisar')));
      await pumpUntilFound(
        tester,
        find.byKey(const Key('completar-cadastro:contrato')),
      );

      // Preview mostra os termos renderizados com o CNPJ do contratante.
      expect(find.textContaining('11.222.333/0001-81'), findsWidgets);

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

      // Sucesso → continua para a home (contratante agora ativo).
      await pumpUntilFound(
        tester,
        find.byKey(const Key('completar-cadastro:sucesso')),
      );
      await tester.ensureVisible(
        find.byKey(const Key('completar-cadastro:continuar-home')),
      );
      await tester.tap(
        find.byKey(const Key('completar-cadastro:continuar-home')),
      );
      await awaitRouteChange(tester, '/');
    },
  );
}
