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
import 'feed_test.dart' as feed;
import 'vagas_test.dart' as vagas;

void main() {
  auth.main();
  cadastro.main();
  vagas.main();
  feed.main();
}
