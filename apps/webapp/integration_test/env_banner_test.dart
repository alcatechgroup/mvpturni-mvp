// Entrypoint agregador da suíte `env_banner/` para o Web (STORY-075).
//
// Mesmo racional do auth_test.dart: no Web o `flutter drive` enraíza o app no
// diretório do --target, então o entrypoint fica no topo de integration_test/
// para `env_banner/` resolver `../helpers/`.
//
// Dois modos de execução (ver banner_visibility_test.dart):
//   - via web_test.dart (gate normal, TURNI_ENV ausente → `local`): asserções
//     de AUSÊNCIA do banner (CA-2/CA-4);
//   - via `make e2e-webapp-banner` (--dart-define=TURNI_ENV=homolog): caminho
//     feliz — banner visível pós-login (CA-1) e ausente pré-auth (CA-4).
import 'env_banner/banner_visibility_test.dart' as banner_visibility;

void main() {
  banner_visibility.main();
}
