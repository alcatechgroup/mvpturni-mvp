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
import 'app_shell_test.dart' as app_shell;
import 'auth_test.dart' as auth;
import 'cadastro_test.dart' as cadastro;
import 'env_banner_test.dart' as env_banner;
import 'feed_test.dart' as feed;
import 'perfil_test.dart' as perfil;
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
  // app_shell (STORY-077): navegação do shell nos 2 papéis × 2 viewports. Só LÊ
  // (navega), não muta estado; reseta a viewport ao fim de cada cenário.
  app_shell.main();
  // perfil (STORY-088): reputação no Perfil + UX do gate. Usa o usuário de reputação do
  // AvaliacaoSeeder (profissional.avaliacao) — só LÊ/NAVEGA (não envia avaliação), preserva
  // a pendência. Depois do app_shell por ser o mais novo.
  perfil.main();
  // env_banner (STORY-075): aqui (TURNI_ENV ausente → local) asserta AUSÊNCIA do
  // banner; o caminho feliz (visível em homolog) roda em invocação própria com
  // --dart-define=TURNI_ENV=homolog (`make e2e-webapp-banner`).
  env_banner.main();
}
