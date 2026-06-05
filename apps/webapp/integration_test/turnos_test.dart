// Entrypoint agregador da suíte `turnos/` para o Web (STORY-059/STORY-060 / IDR-021).
//
// Mantém o entrypoint no topo de `integration_test/` para que os arquivos em `turnos/`
// resolvam `../helpers/...` (mesma razão de auth_test.dart/vagas_test.dart). Roda
// SAME-ORIGIN sob o harness (proxy reverso + --web-launch-url) — fluxo autenticado.
import 'turnos/checkout_test.dart' as checkout;
import 'turnos/cronometro_test.dart' as cronometro;
import 'turnos/detalhe_turno_test.dart' as detalhe_turno;
import 'turnos/listas_turnos_test.dart' as listas_turnos;
import 'turnos/pin_checkin_test.dart' as pin_checkin;
import 'turnos/validar_checkin_test.dart' as validar_checkin;

void main() {
  listas_turnos.main();
  detalhe_turno.main();
  pin_checkin.main();
  // STORY-063: leitura pura sobre o par exclusivo *.cronometro.seed (turno `ativo`
  // estável); a janela de amostragem (~60s+) é a parte mais longa do gate.
  cronometro.main();
  // STORY-062 por último entre as de check-in: o cenário final CONSOME o turno
  // validar.seed (→ ativo); o TurnosSeeder recria no próximo `_e2e-seed`.
  validar_checkin.main();
  // STORY-064: ciclo completo confirmado→finalizado sobre o par exclusivo
  // *.checkout.seed (CONSOME o turno; o seeder recria — recriaConsumido).
  checkout.main();
}
