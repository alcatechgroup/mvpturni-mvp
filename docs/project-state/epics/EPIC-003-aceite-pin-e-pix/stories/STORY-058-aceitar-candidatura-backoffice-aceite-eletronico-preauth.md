---
story_id: STORY-058
slug: aceitar-candidatura-backoffice-aceite-eletronico-preauth
title: Aceitar candidatura no Backoffice + AceiteEletronico imutável + pré-autorização via gateway (fake genérico — PDR-017)
epic_id: EPIC-003
sprint_id: SPRINT-2026-W28
type: implementation
target_role: programador
requires_design: true  # 2026-06-04 (PO em chat): aprovação é do CONTRATANTE no WebApp; designer especifica os modais (bloqueio PF / override PJ / confirmação)
design_screen_id: SCREEN-STORY-058-aprovar-candidatura
status: in_review
owner_agent: claude-opus-4-8
created_at: 2026-06-03
updated_at: 2026-06-04
estimated_session_size: M
produces_idr: null
---

# STORY-058 — Aceitar candidatura: criar Turno + AceiteEletronico + pré-autorização via gateway

> **Nota PDR-017 (2026-06-04):** "pré-autorização" continua sendo o conceito do domínio; o que muda é que o gateway implementador é o **fake genérico** (STORY-056), não o Pagar.me real. O contrato da ACL (`preAutorizar`) e o comportamento esperado (idempotência, emissão de evento `PagamentoPreAutorizado`, audit log) são os mesmos. Quando Pagar.me real entrar na próxima wave, esta estória **não precisa ser tocada** — só o adapter muda.

## Contexto

EPIC-002 entregou painel de candidatos ranqueados (STORY-051). Esta estória pega o **botão "Aprovar" desse painel** e o transforma na ação que **abre o turno** — cria Turno em `confirmado`, emite AceiteEletronico imutável (com cláusula de override de habitualidade PJ se aplicável), aplica gate PDR-002 (bloqueia 3ª alocação PF; alerta+override 3ª PJ), e dispara pré-autorização via `preAutorizar` da ACL de pagamento (STORY-056) de forma idempotente.

É a **primeira escrita** sobre o modelo da STORY-055 e o **primeiro consumo real** da ACL da STORY-056.

- Épico: `epics/EPIC-003-aceite-pin-e-pix/epic.md`
- Documentos:
  - `docs/especificacao/domain/turno.md` (atributos do turno, transição inicial)
  - `docs/especificacao/domain/compliance.md` (AceiteEletronico do turno, placeholders)
  - `docs/especificacao/domain/pagamento.md` (pré-autorização do total_contratante)
  - PDR-002 (habitualidade PF/PJ), PDR-004 (taxa Turni), PDR-012 (templates editáveis), **PDR-017 (pagamento via fake genérico no MVP)**
  - ADR-006 (consulta de habitualidade), ADR-010 (padrão de imutabilidade), ADR-015 (modelo Turno), ADR-016 (ACL de pagamento — revisada pós-PDR-017)

## O quê

Implementar a ação de aceitar candidatura no Backoffice de modo que: (a) consulta habitualidade do par profissional×estabelecimento na semana do turno; (b) se PF e 3ª, bloqueia com mensagem clara em ambos os lados; (c) se PJ e 3ª, mostra alerta com botão "Assumo o risco e aceito"; (d) ao aceitar, cria Turno em `confirmado`, gera AceiteEletronico renderizando o `TemplateVersao` ativa (PF ou MEI/PJ), e dispara `preAutorizar` da ACL (fake genérico — PDR-017) com idempotência (clique duplo não cobra dobrado).

## Por quê

Sem essa ação, o produto não tem Turno. Sem o AceiteEletronico imutável anexado, não há governança jurídica do MVP. Sem habitualidade aplicada no aceite, PDR-002 não está em vigor de verdade.

## Critérios de aceite

- [ ] **CA-1:** Botão "Aceitar candidatura" do painel de candidatos (STORY-051, WebApp do contratante) chama endpoint backend `POST /api/candidaturas/{id}/aprovar` (RBAC **contratante dono da vaga**; não-dono/profissional → 403). *(Corrigido em 2026-06-04 por decisão do PO em chat: o título original dizia "Backoffice"/RBAC admin, mas épico + `domain/candidatura.md` §"Aprovação pelo contratante" fixam que quem aprova é o contratante no WebApp.)*
- [ ] **CA-2:** Endpoint executa em transação Postgres: consulta habitualidade (ADR-006), aplica regra PDR-002, e — se aprovado — cria Turno (`status: confirmado`), AceiteEletronico imutável (placeholders renderizados a partir de Turno + Profissional + Contratante + flag `habitualidade.override_aceito`), e dispara `preAutorizar` da ACL de pagamento (fake — PDR-017) com chave de idempotência `aceite:{candidatura_id}`.
- [ ] **CA-3:** Habitualidade — PF 3ª: endpoint retorna 422 com mensagem "este profissional é PF e já tem 2 alocações nesta semana neste estabelecimento; bloqueado por PDR-002"; UI mostra modal específico. ~~Profissional vê mesma razão em "Minhas candidaturas"~~ *(ajustado 2026-06-04 por decisão do PO em chat: a tela "Minhas candidaturas" não existe no MVP; o lado do profissional entra com as listas da STORY-059/060).*
- [ ] **CA-4:** Habitualidade — PJ 3ª: UI mostra modal "este profissional já tem 2 alocações nesta semana; clique 'Assumo o risco e aceito' para continuar (registrado no AceiteEletronico)". O clique chama endpoint com `override: true`; AceiteEletronico carimba `habitualidade_override: true` e renderiza cláusula adicional (PDR-002).
- [ ] **CA-5:** Idempotência — duas requisições de aprovação para a mesma candidatura geram **um único** Turno + AceiteEletronico + pré-autorização. Teste cobre clique duplo no botão e double-submit do formulário.
- [ ] **CA-6:** Pré-autorização dispara via worker (assíncrona — ADR-002) com idempotência da STORY-056. Sucesso emite evento de domínio `PagamentoPreAutorizado` → audit log captura; falha emite `PagamentoPreAutorizacaoFalhou` → admin vê na fila. **Fake genérico (PDR-017) responde com sucesso por padrão; falha pode ser simulada por configuração do fake para testar o caminho de exceção.**
- [ ] **CA-7:** Audit log captura `turno.criado`, `aceite_eletronico.emitido`, `pagamento.pre_autorizado` (ou `.pre_autorizacao_falhou`) — imutável por trigger Postgres herdado.
- [ ] **CA-8:** Template-seed v1 dos 2 templates de turno (PF + MEI/PJ) — espelha texto já em `docs/especificacao/contratos/template-pf-autonomo-eventual-v1.md` e `template-mei-pj-b2b-v1.md`; SHA-256 do conteúdo registrado. PO entrega + valida em chat antes de a estória fechar. *(Ajustado 2026-06-04 por decisão do PO em chat: os 2 templates JÁ existem como `TemplateVersao` v1 ativa desde a STORY-020 — categoria `contrato`, SHA-256 logado no seed. O aceite por turno REUSA esses templates (Seção 1+2); não há seed novo nem categoria `contrato_turno`. O CA vira: validar fidelidade da v1 ativa aos docs canônicos.)*
- [ ] **CA-9:** E2E cobre os 4 cenários PDR-002: PF 1ª/2ª libera (turno criado); PF 3ª bloqueia (sem turno); PJ 3ª com override cria turno com cláusula; transição de semana reseta.
- [ ] **CA-10:** Cobertura ≥ 98% no núcleo (regra PDR-002, idempotência, emissão de AceiteEletronico); ≥ 80% no resto.

## Fora de escopo

- UI de listagem dos turnos criados (STORY-059).
- UI de detalhe do turno (STORY-060).
- Qualquer ação sobre o turno depois do `confirmado` (estórias seguintes).
- Tratamento de falha permanente de pré-autorização — registra erro, alerta admin, mas não tenta retry automático.

## Padrões de qualidade

≥ 80% / ≥ 98% no núcleo. E2E backend (cobre os 4 cenários PDR-002) e admin (via `integration_test` mesma origem se aplicável, ou via Playwright smoke do build deployado).

## Dependências

- **Bloqueada por:** STORY-055 (modelo Turno), STORY-056 (ACL de pagamento + fake + idempotência). PDR-002 já implementado em EPIC-002 — apenas adapta para o aceite do turno.
- **Bloqueia:** STORY-059, STORY-060, STORY-066, STORY-067.
- **Pré-requisitos:** ~~Pagar.me sandbox credentials no Secret Manager~~ **REMOVIDO por PDR-017** — fake genérico não precisa de credenciais externas.

## Decisões já tomadas

- ADR-006, ADR-010, ADR-015, ADR-016, **ADR-018 (UUIDv7 em PKs — Turno + AceiteEletronicoTurno + pagamento_operacoes têm `id` uuid; FKs `foreignUuid`; idempotência usa UUID do turno; URLs/rotas RESTful aceitam UUIDs)** — PDR-002, PDR-004, PDR-010, PDR-012.

## Liberdade técnica

Decide: estrutura interna do controller/service, formato exato dos modais de bloqueio/alerta no admin (reusa padrão do painel da STORY-051).

NÃO decide: regra de habitualidade (PDR-002); valor da taxa Turni (PDR-004 = 15%).

## Definição de Pronto

- [ ] CAs marcados, todos os testes verdes, cobertura exigida.
- [ ] Deploy em homolog verificado por Alexandro (botão "Aprovar" cria turno + pré-autorização registrada em `pagamento_operacoes` com status `concluida` + audit log `pagamento.pre_autorizado` + evento `PagamentoPreAutorizado` emitido — verificável via GET na fila do admin ou inspeção direta do Postgres).
- [ ] Templates carregados como `TemplateVersao` ativa (categoria `contrato_turno`).
- [ ] `index.json` atualizado.
- [ ] "Notas do agente" preenchida.

## Protocolo

`docs/skills/po/references/agent-task-format.md`.

## Notas do agente

### Entrada inicial (2026-06-04 — disciplina de leitura)

**Documentos lidos:** estória inteira; ADR-006/015/016/018; PDR-002/004/012/017; `domain/turno.md` (via ADR-015), `domain/compliance.md` §aceite por turno, `domain/pagamento.md`, `domain/candidatura.md` §aprovação; STORY-051 (estória + SCREEN-051 + código); código existente: `GateHabitualidade`, `CriarCandidaturaService`, `GatewayPagamento`/`OperacaoIdempotente`/`PagarmeGateway`, `Turno`/`TurnoStatus`/`AceiteEletronicoTurno`/`Template`/`TemplateVersao`, `AceiteAdesaoRenderer`, `AuditLog`, `TemplatesContratuaisSeeder`, `painel_candidatos_screen.dart`.

**Entendimento consolidado:** o botão "Aceitar candidatura" do painel do contratante (STORY-051) vira a ação que abre o turno. Endpoint `POST /api/candidaturas/{id}/aprovar` (RBAC contratante dono) roda em transação: consulta habitualidade **sobre `turnos`** (índice de ADR-006/015), aplica PDR-002 (PF 3ª → 422; PJ 3ª → exige `override: true`), cria Turno `confirmado` (financeiro congelado: `valor` da vaga, `taxa_turni` = 15% PDR-004, `total = valor + taxa`), transita candidatura → `aprovada`, preenche posição da vaga (fecha ao preencher a última — domain/vaga.md), emite `AceiteEletronicoTurno` imutável (renderiza TemplateVersao ativa PF ou MEI/PJ, Seção 1+2, cláusula 10 condicional ao override), grava audit logs, e **após o commit** despacha job assíncrono (fila database/ADR-002) que chama `preAutorizar` via `OperacaoIdempotente`.

**Dúvidas escaladas e respondidas pelo PO em chat (2026-06-04):**
1. Quem aprova: **contratante no WebApp** (CA-1 corrigido — o "Backoffice"/RBAC admin do texto original contradizia épico + domain spec).
2. CA-3 lado do profissional: **adiado para STORY-059/060** (tela "Minhas candidaturas" não existe).
3. CA-8: **reusa** os templates seedados na STORY-020 (categoria `contrato`); sem categoria `contrato_turno` nova.

**Plano (resumo):**
1. Designer: SCREEN-STORY-058 (modais de confirmação/bloqueio PF/override PJ + estados) + protótipo HTML, reusando padrão do painel 051.
2. Backend TDD (red→green por CA): service `AprovarCandidaturaService` + `GateHabitualidadeAceite` (sobre turnos) + `AceiteTurnoRenderer` + job `PreAutorizarTurnoJob` + eventos `PagamentoPreAutorizado`/`PagamentoPreAutorizacaoFalhou`.
3. WebApp: habilitar botão, modais conforme spec, service de aprovação.
4. E2E backend (4 cenários PDR-002) + `integration_test` same-origin (IDR-021, gate local IDR-004).

**Mapeamento CA → testes planejados (antes de codar):**
- CA-1 → `AprovarCandidaturaTest`: dono 200/cria turno; não-dono 403; profissional 403; 401; candidatura inexistente 404. (a/b)
- CA-2 → `AprovarCandidaturaTest`: transação cria Turno+Aceite+job em um commit; rollback se aceite falha (ex.: template sem versão ativa → 500 sem turno órfão). (a/c)
- CA-3 → `HabitualidadeAceiteTest`: PF 3ª → 422 com mensagem PDR-002, sem turno; PF 1ª/2ª libera. (b)
- CA-4 → PJ 3ª sem `override` → 422 com `requer_override`; com `override: true` → turno criado + `habitualidade_override: true` no aceite + cláusula 10 renderizada. (a/b)
- CA-5 → clique duplo/double-submit: 2ª chamada não duplica (409/200 idempotente; um único turno/aceite/pré-auth — UNIQUE candidatura_id + UNIQUE (turno_id,tipo)). (d)
- CA-6 → `PreAutorizarTurnoJobTest`: sucesso emite `PagamentoPreAutorizado` + audit; falha fatal emite `PagamentoPreAutorizacaoFalhou` + audit + operação `falhou`; `GatewayIndisponivel` → retry do job. (a/c)
- CA-7 → audit `turno.criado`, `aceite_eletronico.emitido`, `pagamento.pre_autorizado`/`.pre_autorizacao_falhou`. (a)
- CA-8 → teste de fidelidade: SHA-256 da v1 ativa == SHA-256 do doc canônico (PF e MEI/PJ). (a)
- CA-9 → E2E backend 4 cenários (PF 1ª/2ª, PF 3ª, PJ 3ª override, virada de semana) + `integration_test` da aprovação no painel. (a/b/d)
- CA-10 → cobertura ≥98% núcleo (gate, renderer, idempotência) / ≥80% resto.
- Bordas extras: renderização com placeholder ausente falha duro (sem aceite incompleto); vaga fechada/cancelada → 422; candidatura `retirada` → 422; última posição fecha a vaga.

### Decisões tomadas

1. **Habitualidade do aceite conta TURNOS, não candidaturas** (`GateHabitualidadeAceite`): a tabela-alvo é `turnos` (índice de ADR-006/ADR-015), excluindo `cancelado_pro`/`cancelado_emp`/`no_show_pro` (alocação desfeita — PDR-007). O gate da candidatura (STORY-050) continua contando candidaturas vivas — são réguas diferentes para momentos diferentes.
2. **Chave de idempotência da pré-autorização**: o CA-2 citava `aceite:{candidatura_id}`, mas ADR-016 (aceita, implementada) fixou `{tipo}:{turno_id}` no runner `OperacaoIdempotente`. ADR vence. O efeito do CA-5 está garantido em três camadas: UNIQUE(candidatura_id) em turnos (ADR-015) + UNIQUE(turno_id, tipo_operacao) em pagamento_operacoes + curto-circuito do runner.
3. **Eventos do desfecho da pré-autorização**: `PagamentoPreAutorizado` / `PagamentoPreAutorizacaoFalhou` (CA-6) são emitidos pelo `PreAutorizarTurnoJob` (desfecho síncrono da chamada à ACL), distintos do `PreAutorizacaoCriada` da ADR-016 (que nasce do webhook do fake). Falha fatal (recusa) NÃO relança — registra audit + evento + operação `falhou` (sem retry, espelha PDR-010); `GatewayIndisponivel` relança (worker retenta com backoff; `failed()` registra o desfecho).
4. **`meioPagamentoToken` stub** (`tok_mvp_{contratante_id}`): tokenização real é da wave de integração Pagar.me (ADR-016 §consequências); o fake (PDR-017) honra qualquer token.
5. **Financeiro em centavos inteiros** (`AprovarCandidaturaService::financeiro`): 15% (PDR-004) com meio-arredondamento para cima, sem float/bcmath — espelha `PagarmeGateway::centavos()`. O CHECK do banco (total = valor + taxa) é satisfeito por construção. Mesma conta serve o preview no payload do painel (SCREEN-058 D1).
6. **`AceiteTurnoRenderer` separado do de adesão**: renderiza Seção 1+2+Assinatura (adesão corta a 2); a cláusula 10 condicional entra só com override real (3ª PJ + clique), e a linha-diretiva do template (instrução ao motor) nunca aparece no documento. Reusa `substituir()` do renderer de adesão (composição, não herança).
7. **Override só carimba onde há risco**: `override: true` sem 3ª alocação NÃO marca `habitualidade_override` nem renderiza cláusula — o registro jurídico reflete a realidade, não o payload.
8. **Aprovação preenche posição da vaga** (fecha na última — `domain/vaga.md` + `domain/candidatura.md` §aprovação dispara decremento). Notificação ao profissional fica para STORY-067.
9. **`formatBRL` promovido a `core/format/brl.dart`** no WebApp (4º uso — regra de três; feed/minhas vagas/detalhe migrados).
10. **Seeder E2E em semana virgem** (`AprovacaoCandidaturaSeeder`): turno/aceite são imutáveis (não dá para "desfazer" no reseed), então cada cenário consumido leva o próximo a uma semana ainda não usada pelo par — PDR-002 nunca acumula e o caminho feliz é determinístico. Production-safe (sem fake()/factory).

### Descobertas

- **Locale pt-BR muda o default de `startOfWeek()` para domingo** (Carbon). PDR-002 fixa segunda→domingo; o gate usa `CarbonInterface::MONDAY` explícito e os helpers de teste idem. Pegadinha real: testes de borda de semana passavam "por sorte" dependendo do dia da execução.
- O CA-6 da STORY-051 (botões desabilitados) foi atualizado conscientemente no widget test do painel — aceitar agora habilitado (este é o EPIC-003 chegando), remover segue desabilitado (Lacuna MVP).
- `GET /api/vagas/{vaga}/candidatos` ganhou o bloco `vaga: { valor, taxa_turni, total_contratante }` (aditivo — não quebra consumidores).
- **Acoplamento latente na suíte E2E `vagas/` (consertado):** o teste de edição (STORY-052) tapeava `find.text('Editar').first` — que, com "Minhas vagas" ordenada por `data_inicio ASC`, apontava para a **vaga seed do painel** (STORY-051), não para a vaga que ele mesmo publica (31/12/2026). A 1ª execução editava a vaga do painel materialmente → as 3 candidaturas viravam `pendente_revisao_apos_edicao` → "3 candidatos aguardando" sumia e o E2E do painel quebrava nas execuções seguintes. Correções: (a) `editar_vaga_test` acha o card da própria vaga pelo valor único R$ 175,00 (sem `.first`); (b) `PainelCandidatosSeeder` agora **restaura** as candidaturas ao estado canônico (3 pendentes) em cada seed; (c) a vaga do `AprovacaoCandidaturaSeeder` vive em 2027 (nunca rouba `.first` de ninguém) com função exclusiva (Camareira). Gate `make e2e` completo verde após os fixes (integration + smoke + admin).

### Bloqueios encontrados

Nenhum técnico. Três ambiguidades de produto escaladas e decididas pelo PO em chat (2026-06-04) — ver "Entrada inicial": quem aprova (contratante/WebApp), CA-3 lado do profissional (adiado p/ STORY-059/060), CA-8 (reusa templates da STORY-020).

### IDRs criados

Nenhum — nenhuma lib nova, nenhum padrão transversal novo (tudo dentro de ADR-015/016/018 e PDR-002/004/017).

### Cobertura final

- **api** (suíte completa, 734+ testes verdes, global **92,4%**, gate ≥80% ✓). Núcleo da estória (gate ≥98%):
  - `GateHabitualidadeAceite` **100%** · `AceiteTurnoRenderer` **100%** · `AprovarCandidaturaService` **99,3%** · `PreAutorizarTurnoJob` **100%** · `AprovarCandidaturaController` **100%** · `AprovarCandidaturaResultado` **100%**.
- **webapp**: suíte completa **376 testes verdes** (17 novos em `aprovar_candidatura_test.dart`: service 201/409/422/403/rede + D1/D2/D3 + desfechos + anti clique-duplo). `flutter analyze` limpo (2 infos pré-existentes em telas de cadastro intocadas); `dart format` limpo; `pint` api+admin verdes.

### Mapeamento CA → teste (final)

- CA-1 → `AprovarCandidaturaTest`: "contratante dono aprova → 201", "NÃO-dono → 403", "profissional → 403", "sem sessão → 401 / inexistente → 404".
- CA-2 → `AprovarCandidaturaTest`: "cria Turno confirmado com financeiro congelado", "candidatura aprovada + vaga preenche posição", "múltiplas posições continua aberta", "aceite referencia versão ativa do tipo", "PF usa pf_autonomo_eventual", "despacha o job", "rollback: template sem versão ativa → nada persiste".
- CA-3 → `AprovarCandidaturaTest` "PF 3ª → 422 mensagem PDR-002" + `HabitualidadeAceiteTest` (12 cenários: liberações, bloqueio, default PF, exclusões, bordas seg/dom).
- CA-4 → `AprovarCandidaturaTest`: "PJ 3ª sem override → 422", "com override → cláusula no aceite", "override sem risco não carimba", "PF não aceita override"; renderer: cláusula condicional (4 testes).
- CA-5 → `AprovarCandidaturaTest` "aprovar duas vezes → 1 turno + 409" + `PreAutorizarTurnoJobTest` "duas execuções → 1 chamada ao provedor" + UI anti clique-duplo (CTA travado).
- CA-6 → `PreAutorizarTurnoJobTest` (8 testes: sucesso/evento/audit, curto-circuito, recusa fatal sem relançar, indisponível relança, failed() esgotado, defensivos, fila database).
- CA-7 → `AprovarCandidaturaTest` "grava turno.criado e aceite_eletronico.emitido" + `PreAutorizarTurnoJobTest` (pagamento.pre_autorizado / .pre_autorizacao_falhou). Imutabilidade da trilha herdada (testes de ADR-013/015 vigentes).
- CA-8 → `TemplatesTurnoFidelidadeTest` (SHA-256 da v1 ativa == texto-seed vendorado; placeholders da Seção 2; cláusula condicional só no MEI/PJ). Fidelidade docs↔vendored conferida no host (FIEL nos 2). **Validação do PO em chat: pendente no fechamento.**
- CA-9 → E2E backend: 4 cenários PDR-002 em `AprovarCandidaturaTest`+`HabitualidadeAceiteTest` (PF 1ª/2ª libera; PF 3ª bloqueia sem turno; PJ 3ª override com cláusula; virada de semana reseta) contra Postgres real. UI: `integration_test/vagas/aprovar_candidatura_test.dart` same-origin (IDR-021, gate local IDR-004) — caminho feliz ponta a ponta com POST real.
- CA-10 → cobertura acima.

### Links de evidência
- PR: n/a — commit direto na `main` (git workflow Turni). Commits: 89028f5 (red), ff80f29 (backend), 030f307 (UI+seeder), bffaff3 (fix determinismo E2E).
- Pipeline: CI da main verde + Release `v0.1.0-rc.69` verde (run 26991292632 — 2 reruns por infra: Cloud SQL desligado pelo scheduler de economia e warm-up do Postgres; nada de código).
- Deploy de homologação: rc.69 deployado em 2026-06-05 (migrar+seed com `AprovacaoCandidaturaSeeder`, API, Admin, smoke pós-deploy verdes). **Verificação do Alexandro pendente** (botão Aceitar → turno + `pagamento_operacoes` `concluida` + audit `pagamento.pre_autorizado`).
