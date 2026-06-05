// Entrypoint agregador da suíte `vagas/` para o Web (STORY-046 / IDR-021).
//
// Mantém o entrypoint no topo de `integration_test/` para que os arquivos em `vagas/`
// resolvam `../helpers/...` (mesma razão de auth_test.dart/cadastro_test.dart). Roda
// SAME-ORIGIN sob o harness (proxy reverso + --web-launch-url) — fluxo autenticado.
import 'vagas/aprovar_bloqueio_pf_test.dart' as aprovar_bloqueio_pf;
import 'vagas/aprovar_candidatura_test.dart' as aprovar_candidatura;
import 'vagas/aprovar_override_pj_test.dart' as aprovar_override_pj;
import 'vagas/candidatura_test.dart' as candidatura;
import 'vagas/editar_vaga_test.dart' as editar_vaga;
import 'vagas/minhas_vagas_test.dart' as minhas_vagas;
import 'vagas/painel_candidatos_test.dart' as painel_candidatos;
import 'vagas/publicar_vaga_test.dart' as publicar_vaga;

void main() {
  // painel_candidatos roda PRIMEIRO de propósito: ele só LÊ a vaga seed (aberta, 3 candidatos),
  // enquanto minhas_vagas CANCELA uma vaga arbitrária do contratante.teste (`Cancelar vaga`.first)
  // e deixa o filtro em "Todas". Rodar o painel antes garante que a vaga seed ainda esteja
  // `aberta` (botão "Ver candidatos" presente) e o filtro no padrão.
  painel_candidatos.main();
  // Trio de aprovação (STORY-058): cada um usa a PRÓPRIA vaga seed do
  // AprovacaoCandidaturaSeeder (funções exclusivas; datas em 2027 — nunca roubam `.first`
  // de ninguém). feliz e override CONSOMEM a vaga (fecham ao aprovar; o seeder rotaciona a
  // semana no reseed); bloqueio_pf não consome nada. Rodam depois do painel e antes de
  // minhas_vagas (que cancela vaga aberta arbitrária).
  aprovar_candidatura.main();
  aprovar_bloqueio_pf.main();
  aprovar_override_pj.main();
  publicar_vaga.main();
  // editar_vaga publica e edita a PRÓPRIA vaga (self-contained); roda antes de minhas_vagas
  // (que mexe no filtro/cancela) para começar do estado padrão da lista.
  editar_vaga.main();
  minhas_vagas.main();
  candidatura.main();
}
