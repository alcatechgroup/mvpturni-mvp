// Entrypoint agregador da suíte `feed/` para o Web (STORY-048 / IDR-021).
//
// Mantém o entrypoint no topo de `integration_test/` para que os arquivos em `feed/`
// resolvam `../helpers/...` (mesma razão de auth_test.dart/vagas_test.dart). Roda
// SAME-ORIGIN sob o harness (proxy reverso + --web-launch-url) — fluxo autenticado.
import 'feed/feed_test.dart' as feed;

void main() {
  feed.main();
}
