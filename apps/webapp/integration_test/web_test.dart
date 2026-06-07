// Entrypoint ÚNICO do gate de integration_test no Web (STORY-043 / IDR-021).
//
// `flutter drive` roda UM --target por invocação e cada invocação recompila + reabre o
// browser (~40s). Para manter o gate rápido e determinístico (CA-9), o Makefile aponta
// para ESTE agregador, que compõe as suítes por feature numa única execução de drive:
//   - auth      (login/RBAC/funnel/welcome — área pública + logada)
//   - cadastro  (validações de pré-cadastro PF/MEI + contratante)
//
// Para iterar numa feature isolada em dev, rode o agregador da feature direto:
//   flutter drive --driver=test_driver/integration_test.dart --target=integration_test/auth_test.dart ...
//   flutter drive --driver=test_driver/integration_test.dart --target=integration_test/cadastro_test.dart ...
//
// Tudo roda SAME-ORIGIN sob o harness (proxy reverso + --web-launch-url) — ver Makefile.
import 'auth_test.dart' as auth;
import 'cadastro_test.dart' as cadastro;
import 'env_banner_test.dart' as env_banner;
import 'feed_test.dart' as feed;
import 'turnos_test.dart' as turnos;
import 'vagas_test.dart' as vagas;

void main() {
  auth.main();
  cadastro.main();
  vagas.main();
  feed.main();
  // turnos usa usuários EXCLUSIVOS do TurnosSeeder (*.turnos.seed@turni.local) — não
  // disputa estado com nenhuma suíte acima; roda por último por ser o mais novo.
  turnos.main();
  // env_banner (STORY-075): aqui (TURNI_ENV ausente → local) asserta AUSÊNCIA do
  // banner; o caminho feliz (visível em homolog) roda em invocação própria com
  // --dart-define=TURNI_ENV=homolog (`make e2e-webapp-banner`).
  env_banner.main();
}
