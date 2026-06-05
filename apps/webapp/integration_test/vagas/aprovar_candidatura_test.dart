// integration_test — STORY-058 (E2E da aprovação de candidatura no WebApp).
//
// Same-origin (proxy + --web-launch-url, IDR-021) contra o BACKEND REAL: contratante.teste
// loga → "Minhas vagas" → vaga do AprovacaoCandidaturaSeeder ("1 candidato aguardando") →
// painel → "Aceitar candidatura" → D1 (financeiro PDR-004) → "Confirmar aceite" → POST real
// cria o turno (transação CA-2) → snackbar de sucesso → candidato sai da lista (painel só
// lista pendentes). Os 4 cenários PDR-002 (PF 3ª, PJ 3ª override, virada de semana) são
// cobertos no E2E backend (AprovarCandidaturaTest/HabitualidadeAceiteTest, Postgres real) —
// aqui o gate é o caminho feliz ponta a ponta na UI (gate local — IDR-004).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../helpers/login_helper.dart';
import '../helpers/pump_app.dart';
import '../helpers/route_helper.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'contratante aceita candidatura: D1 com financeiro → turno confirmado (CA-1/CA-2/CA-9)',
    (tester) async {
      await pumpApp(tester);
      assertOnRoute(tester, '/login');

      await loginAsContratante(tester);
      await awaitRouteChange(tester, '/');
      await tester.pumpAndSettle();

      // 1) "Minhas vagas" — acha a vaga do cenário de aprovação (única com 1 candidato).
      await pumpUntilFound(
        tester,
        find.byKey(const Key('minhas-vagas-screen')),
      );
      await pumpUntilFound(tester, find.text('1 candidato aguardando'));

      // 2) "Ver candidatos" DESTA vaga: o texto de contagem carrega a key
      // `vaga-card-{id}-pendentes` — extrai o id e tapeia o botão correspondente.
      final contagem = tester.widget<Text>(find.text('1 candidato aguardando'));
      final vagaId = (contagem.key! as ValueKey<String>).value
          .replaceFirst('vaga-card-', '')
          .replaceFirst('-pendentes', '');
      final verCandidatos = find.byKey(Key('vaga-card-$vagaId-ver-candidatos'));
      await pumpUntilFound(tester, verCandidatos);
      await tester.ensureVisible(verCandidatos);
      await tester.pumpAndSettle();
      await tester.tap(verCandidatos);
      await tester.pumpAndSettle();

      // 3) Painel com o candidato seed.
      await pumpUntilFound(
        tester,
        find.byKey(const Key('painel-candidatos-lista')),
      );
      await pumpUntilFound(tester, find.text('Apro Vação'));

      // 4) Aceitar → D1 com o financeiro (PDR-004: 200 + 15% = 230).
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

      // 5) Confirmar → POST real → snackbar de sucesso e lista recarregada sem o candidato.
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
