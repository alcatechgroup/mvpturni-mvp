// Entrypoint agregador da suíte `perfil/` para o Web (STORY-088 / IDR-021).
//
// Mantém o entrypoint no topo de `integration_test/` para que os arquivos em `perfil/`
// resolvam `../helpers/...` (mesma razão de turnos_test.dart/vagas_test.dart). Roda
// SAME-ORIGIN sob o harness (proxy reverso + --web-launch-url) — fluxo autenticado.
import 'perfil/reputacao_e_gate_test.dart' as reputacao_e_gate;

void main() {
  reputacao_e_gate.main();
}
