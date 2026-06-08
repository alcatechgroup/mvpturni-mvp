// Entrypoint agregador da suíte `app_shell/` para o Web (STORY-077 / IDR-021).
//
// Mantém o entrypoint no topo de `integration_test/` para que os arquivos em
// `app_shell/` resolvam `../helpers/...` (mesma razão de auth_test.dart). Roda
// SAME-ORIGIN sob o harness (proxy reverso + --web-launch-url) — fluxo
// autenticado nos dois papéis.
import 'app_shell/navegacao_test.dart' as navegacao;

void main() {
  navegacao.main();
}
