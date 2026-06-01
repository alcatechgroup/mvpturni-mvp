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
import 'auth/login_structure_test.dart' as login_structure;

void main() {
  login_structure.main();
}
