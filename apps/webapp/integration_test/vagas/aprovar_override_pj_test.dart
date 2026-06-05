// integration_test — STORY-058 CA-4/CA-9 (E2E browser real: override PJ 3ª — PDR-002).
//
// Cenário do AprovacaoCandidaturaSeeder (função exclusiva Hostess / Recepção de Salão):
// Paula Junqueira é MEI e o par já tem 2 turnos confirmados NA MESMA semana da vaga-alvo
// (candidatura com alerta_habitualidade → badge no card + pré-aviso no D1). O backend REAL
// responde 422 `requer_override` → D3 → "Assumo o risco e aceito" reenvia com override e o
// turno nasce com a cláusula de risco carimbada (provado nos testes de backend; aqui o gate
// é o fluxo de UI ponta a ponta). Consome o cenário — o seeder rotaciona a semana no reseed.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../helpers/pump_app.dart';
import 'aprovacao_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'PJ na 3ª alocação: D1 pré-avisa, D3 exige "Assumo o risco e aceito" e o turno nasce (CA-4/CA-9)',
    (tester) async {
      await abrirPainelDoCenario(tester, 'Hostess / Recepção de Salão');
      await pumpUntilFound(tester, find.text('Paula Junqueira'));

      // Badge de habitualidade no card (alerta_habitualidade da candidatura — 051 CA-5).
      expect(
        find.text('Habitualidade — 3ª alocação na semana'),
        findsOneWidget,
      );

      // Aceitar → D1 já com o pré-aviso de que a confirmação de risco vem a seguir.
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
      expect(
        find.byKey(const Key('aprovar-dialog-pre-aviso-habitualidade')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('aprovar-dialog-confirmar-btn')));
      await tester.pumpAndSettle();

      // D3 — aceite de risco (copy canônico de compliance.md / PDR-002).
      await pumpUntilFound(
        tester,
        find.byKey(const Key('aprovar-dialog-override-pj')),
      );
      expect(find.text('3ª alocação na mesma semana'), findsOneWidget);
      expect(find.textContaining('Sinais de habitualidade'), findsOneWidget);

      await tester.tap(
        find.byKey(const Key('aprovar-dialog-override-pj-aceitar-btn')),
      );
      await tester.pumpAndSettle();

      // POST real com override: turno criado → snackbar + candidata sai da lista.
      await pumpUntilFound(
        tester,
        find.byKey(const Key('aprovar-snackbar-sucesso')),
      );
      await pumpUntilFound(
        tester,
        find.byKey(const Key('painel-candidatos-vazio')),
      );
      expect(find.text('Paula Junqueira'), findsNothing);
    },
  );
}
