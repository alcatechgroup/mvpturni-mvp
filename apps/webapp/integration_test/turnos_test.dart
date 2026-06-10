// Entrypoint agregador da suíte `turnos/` para o Web (STORY-059/STORY-060 / IDR-021).
//
// Mantém o entrypoint no topo de `integration_test/` para que os arquivos em `turnos/`
// resolvam `../helpers/...` (mesma razão de auth_test.dart/vagas_test.dart). Roda
// SAME-ORIGIN sob o harness (proxy reverso + --web-launch-url) — fluxo autenticado.
import 'turnos/avaliar_turno_test.dart' as avaliar_turno;
import 'turnos/cancelar_turno_test.dart' as cancelar_turno;
// STORY-082: `checkout` segue FORA do gate. Dois flakes ESTRUTURAIS foram corrigidos no
// checkout_test.dart (deflake parcial): (1) a pendura de ~8-9 min — `pumpAndSettle` com
// timer periódico vivo (tick do cronômetro / polling) nunca assenta e estoura no timeout
// de 10 min → trocado por `_assenta` bombeado; (2) "multiple heroes share the same tag" —
// SnackBar do passo anterior vivo durante o `pumpApp` → gate `_semSnackBar` antes de
// remontar; (3) "PIN inválido" intermitente — o teste selecionava o card por RÓTULO DE
// ESTADO com `.first` e o par `*.checkout.seed` acumula turnos LEFTOVER, então a phase 2
// gerava o PIN num turno e a phase 3 validava em OUTRO → fixado pelo id da rota da phase 1
// (`_cardComId`). DEFLAKADO e ESTÁVEL (7/7 isolado). Mantido FORA do gate por decisão do PO
// (custo ~2-3 min) — pronto para reativar: descomentar o import + `checkout.main()`.
// import 'turnos/checkout_test.dart' as checkout;
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
  // STORY-064: ciclo completo confirmado→finalizado. DESATIVADO (flake STORY-082,
  // autorizado pelo PO) — ver nota no import acima.
  // checkout.main();
  // STORY-066: cancelamento dos 2 lados + no-show (pares exclusivos
  // *.cancelarpro/*.cancelaremp/*.noshow.seed; todos recriaConsumido). Por último:
  // o no-show depende do worker ter processado a liberação disparada no _e2e-seed.
  cancelar_turno.main();
  // STORY-087: captura da avaliação (par exclusivo *.aval087.seed, 1 turno finalizado
  // resetado a cada seed). Por último — MUTA o turno (avalia as 2 direções); o
  // `_e2e-seed` da próxima execução reseta para pendente.
  avaliar_turno.main();
}
