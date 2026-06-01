// Entrypoint agregador da suíte `cadastro/` para o Web (STORY-043 / IDR-010 §correção).
//
// Mesmo motivo de `auth_test.dart`: no Web, `flutter drive` enraíza o `org-dartlang-app:/`
// no diretório do --target, então um leaf em `cadastro/` não resolve `../helpers/` sozinho.
// Mantendo o entrypoint no topo de `integration_test/`, os leaves resolvem `../helpers/`.
//
// Cada cenário continua em seu próprio arquivo `cadastro/<feature>_test.dart` (IDR-011 §d).
// Roda same-origin sob o harness da STORY-043 (ver Makefile `e2e-webapp-integration`).
import 'cadastro/completar_cadastro_contratante_test.dart'
    as completar_contratante;
import 'cadastro/completar_cadastro_test.dart' as completar;
import 'cadastro/pre_cadastro_contratante_test.dart' as contratante;
import 'cadastro/pre_cadastro_profissional_test.dart' as profissional;

void main() {
  profissional.main();
  contratante.main();
  completar.main();
  completar_contratante.main();
}
