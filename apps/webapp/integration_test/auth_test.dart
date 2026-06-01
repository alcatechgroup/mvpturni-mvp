// Entrypoint agregador da suíte `auth/` para o Web (STORY-038 / IDR-010 §correção).
//
// Por que existe: no Web, `flutter drive` enraíza o `org-dartlang-app:/` no diretório
// do --target; um target dentro de `auth/` não consegue resolver `../helpers/...`.
// Mantendo o entrypoint no topo de `integration_test/`, os arquivos em `auth/`
// resolvem `../helpers/` normalmente. Em Android/iOS isto é dispensável
// (`flutter test integration_test/auth -d <device>` roda a pasta direto).
//
// Cada cenário continua em seu próprio arquivo `auth/<feature>_test.dart` (IDR-011 §d);
// aqui apenas encadeamos os `main()` para uma única execução de drive.
import 'auth/funnel_guard_test.dart' as funnel_guard;
import 'auth/login_structure_test.dart' as login_structure;
import 'auth/login_validation_test.dart' as login_validation;
import 'auth/navigation_test.dart' as navigation;
import 'auth/rbac_admin_rejected_test.dart' as rbac_admin;
import 'auth/rbac_profissional_test.dart' as rbac_profissional;
import 'auth/welcome_test.dart' as welcome;

// Encadeia os cenários de auth migrados de rbac-login.spec.ts + welcome.spec.ts.
// TODOS rodam SAME-ORIGIN sob o harness da STORY-043 (proxy reverso + --web-launch-url —
// ver Makefile `e2e-webapp-integration` e IDR-021): o app e a API/Sanctum aparecem na
// mesma origem para o browser, então o cookie de sessão trafega como em produção. Isso
// substitui o --dart-define=API_BASE_URL cross-origin da STORY-038 e habilita os fluxos
// AUTENTICADOS pós-login (welcome → POST welcome-visto). O welcome fica por ÚLTIMO porque
// muta estado no backend (welcome_visto) — re-semeado por run via `make _e2e-seed` (CA-5).
void main() {
  login_structure.main();
  login_validation.main();
  funnel_guard.main();
  rbac_profissional.main();
  rbac_admin.main();
  navigation.main();
  welcome.main();
}
