// integration_test — STORY-058 CA-3/CA-9 (E2E browser real: bloqueio duro PF 3ª — PDR-002).
//
// Cenário do AprovacaoCandidaturaSeeder (função exclusiva Copeiro(a)): Pedro Fonseca é PF e
// o par já tem 2 turnos confirmados NA MESMA semana da vaga-alvo. Aprovar dispara o backend
// REAL, que recusa com 422 `habitualidade_bloqueio` → a UI mostra o D2 "Aceite bloqueado".
// NADA é consumido: o candidato segue na lista e o cenário fica estável entre execuções.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../helpers/pump_app.dart';
import 'aprovacao_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'PF na 3ª alocação da semana: D2 bloqueia o aceite e nenhum turno é criado (CA-3/CA-9)',
    (tester) async {
      await abrirPainelDoCenario(tester, 'Copeiro(a)');
      await pumpUntilFound(tester, find.text('Pedro Fonseca'));

      await aceitarEConfirmar(tester);

      // D2 — bloqueio duro (tom de proteção, não erro do usuário).
      await pumpUntilFound(
        tester,
        find.byKey(const Key('aprovar-dialog-bloqueio-pf')),
      );
      expect(find.text('Aceite bloqueado'), findsOneWidget);
      expect(
        find.textContaining(
          'bloqueia a 3ª alocação semanal de profissionais PF',
        ),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const Key('aprovar-dialog-bloqueio-pf-entendi-btn')),
      );
      await tester.pumpAndSettle();

      // Nada consumido: sem snackbar de sucesso e o candidato segue pendente na lista.
      expect(find.byKey(const Key('aprovar-snackbar-sucesso')), findsNothing);
      expect(find.text('Pedro Fonseca'), findsOneWidget);
    },
  );
}
