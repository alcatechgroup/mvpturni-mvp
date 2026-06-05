// Entrypoint agregador da suíte `turnos/` para o Web (STORY-059 / IDR-021).
//
// Mantém o entrypoint no topo de `integration_test/` para que os arquivos em `turnos/`
// resolvam `../helpers/...` (mesma razão de auth_test.dart/vagas_test.dart). Roda
// SAME-ORIGIN sob o harness (proxy reverso + --web-launch-url) — fluxo autenticado.
import 'turnos/listas_turnos_test.dart' as listas_turnos;

void main() {
  listas_turnos.main();
}
