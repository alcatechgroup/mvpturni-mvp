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

// Encadeia os 7 cenários migrados de rbac-login.spec.ts (+ navegação). Os cenários
// que batem na API real (login_validation CA-6, rbac_*, e as telas de cadastro do
// navigation, que fazem fetch ao montar) exigem --dart-define=API_BASE_URL=<origem>
// ao rodar via flutter drive, pois a porta efêmera do web-server não tem o proxy
// /api do container :8003. Ver Makefile (make e2e-webapp-integration) e Notas da STORY-038.
void main() {
  login_structure.main();
  login_validation.main();
  funnel_guard.main();
  rbac_profissional.main();
  rbac_admin.main();
  navigation.main();
}
