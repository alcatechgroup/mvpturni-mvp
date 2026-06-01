// integration_test — STORY-043 CA-3/CA-4/CA-5 (migra welcome.spec.ts).
//
// Cobre a ÁREA LOGADA: a tela de welcome pós-aprovação faz uma chamada AUTENTICADA
// pós-login (POST /api/usuarios/me/welcome-visto via "Vamos lá"). Isso só funciona
// SAME-ORIGIN: o cookie de sessão Sanctum (SameSite=Lax) precisa trafegar junto da
// requisição. Por isso este cenário roda sob o harness same-origin (proxy reverso +
// --web-launch-url — ver Makefile `e2e-webapp-integration` e IDR-021), NÃO com o
// --dart-define cross-origin da STORY-038 (sob o qual "Vamos lá" trava em /welcome).
//
// Contraste do spike (2026-06-01): same-origin → login → /welcome → "Vamos lá"
// (POST autenticado) → /completar-cadastro, backend persiste welcome_visto=true;
// cross-origin → trava em /welcome no passo autenticado (sem cookie).
//
// Determinismo (CA-5): o seed (`make _e2e-seed`) faz `updateOrCreate` em
// bemvindo.profissional@turni.local com welcome_seen_at=null a cada run do gate,
// então cada execução começa com o usuário "não welcomado" — sem o gotcha do
// "2º run pega usuário já welcomado".
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../helpers/login_helper.dart';
import '../helpers/pump_app.dart';
import '../helpers/route_helper.dart';

/// Profissional recém-aprovado do seed (status=liberado, welcome_seen_at=null).
const welcomeSeedEmail = 'bemvindo.profissional@turni.local';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'profissional liberado vê /welcome e segue por "Vamos lá" → /completar-cadastro (CA-4)',
    (tester) async {
      await pumpApp(tester);
      assertOnRoute(tester, '/login');

      // 1º login: status=liberado + welcome_visto=false → funnel guard → /welcome.
      await loginAs(tester, email: welcomeSeedEmail, password: seedPassword);
      await awaitRouteChange(tester, '/welcome');

      // A rota muda antes do botão renderizar — espera o CTA montar (gotcha do spike).
      await pumpUntilFound(tester, find.byKey(const Key('btn-vamos-la')));

      // "Vamos lá" dispara o POST AUTENTICADO welcome-visto (precisa do cookie
      // same-origin) e, em sucesso, navega para /completar-cadastro.
      await tester.tap(find.byKey(const Key('btn-vamos-la')));
      await awaitRouteChange(tester, '/completar-cadastro');
    },
  );

  testWidgets(
    '2º login com welcome já visto pula /welcome → /completar-cadastro (CA-4)',
    (tester) async {
      // O teste anterior persistiu welcome_visto=true no backend (POST same-origin).
      // Novo login (sessão do cliente resetada por pumpApp) deve cair DIRETO em
      // /completar-cadastro, sem passar pelo /welcome.
      await pumpApp(tester);
      assertOnRoute(tester, '/login');

      await loginAs(tester, email: welcomeSeedEmail, password: seedPassword);
      await awaitRouteChange(tester, '/completar-cadastro');

      expect(currentRoute(), isNot('/welcome'));
    },
  );
}
