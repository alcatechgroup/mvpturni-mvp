// integration_test — STORY-058 (E2E browser real: caminho feliz da aprovação — CA-1/CA-2).
//
// Same-origin (proxy + --web-launch-url, IDR-021) contra o BACKEND REAL: contratante.teste
// loga → vaga do AprovacaoCandidaturaSeeder (função exclusiva Camareira / Arrumação) →
// painel → "Aceitar candidatura" → D1 (financeiro PDR-004) → "Confirmar aceite" → POST real
// cria o turno (transação CA-2) → snackbar de sucesso → candidato sai da lista. Os irmãos
// aprovar_bloqueio_pf_test (PF 3ª → D2) e aprovar_override_pj_test (PJ 3ª → D3) cobrem os
// ramos de habitualidade em browser real; a virada de semana (4º cenário do CA-9) é regra
// de banco, provada no E2E backend (HabitualidadeAceiteTest/AprovarCandidaturaTest).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../helpers/pump_app.dart';
import 'aprovacao_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'contratante aceita candidatura: D1 com financeiro → turno confirmado (CA-1/CA-2/CA-9)',
    (tester) async {
      await abrirPainelDoCenario(tester, 'Camareira / Arrumação');
      await pumpUntilFound(tester, find.text('Apro Vação'));

      // Aceitar → D1 com o financeiro (PDR-004: 200 + 15% = 230).
      final aceitar = find.byWidgetPredicate((w) {
        final k = w.key;
        return k is ValueKey<String> && k.value.endsWith('-aceitar-btn');
      }, description: 'botão Aceitar candidatura');
      await tester.ensureVisible(aceitar.first);
      await tester.pumpAndSettle();
      await tester.tap(aceitar.first);
      await tester.pumpAndSettle();

      await pumpUntilFound(
        tester,
        find.byKey(const Key('aprovar-dialog-confirmar')),
      );
      expect(find.text(r'R$ 200,00'), findsOneWidget);
      expect(find.text(r'R$ 30,00'), findsOneWidget);
      expect(find.text(r'R$ 230,00'), findsOneWidget);

      // Confirmar → POST real → snackbar de sucesso e lista recarregada sem o candidato.
      await tester.tap(find.byKey(const Key('aprovar-dialog-confirmar-btn')));
      await tester.pumpAndSettle();

      await pumpUntilFound(
        tester,
        find.byKey(const Key('aprovar-snackbar-sucesso')),
      );
      await pumpUntilFound(tester, find.textContaining('Turno confirmado'));

      // O painel recarrega só com pendentes — o candidato aprovado sai.
      await pumpUntilFound(
        tester,
        find.byKey(const Key('painel-candidatos-vazio')),
      );
      expect(find.text('Apro Vação'), findsNothing);
    },
  );
}
