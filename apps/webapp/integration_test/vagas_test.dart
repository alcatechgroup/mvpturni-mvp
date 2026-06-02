// Entrypoint agregador da suíte `vagas/` para o Web (STORY-046 / IDR-021).
//
// Mantém o entrypoint no topo de `integration_test/` para que os arquivos em `vagas/`
// resolvam `../helpers/...` (mesma razão de auth_test.dart/cadastro_test.dart). Roda
// SAME-ORIGIN sob o harness (proxy reverso + --web-launch-url) — fluxo autenticado.
import 'vagas/candidatura_test.dart' as candidatura;
import 'vagas/minhas_vagas_test.dart' as minhas_vagas;
import 'vagas/publicar_vaga_test.dart' as publicar_vaga;

void main() {
  publicar_vaga.main();
  minhas_vagas.main();
  candidatura.main();
}
