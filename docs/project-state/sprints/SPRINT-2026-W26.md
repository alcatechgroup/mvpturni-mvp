---
sprint_id: SPRINT-2026-W26
wave: WAVE-2026-01
status: closed
start_date: null
end_date: 2026-06-01
soft_cap_date: null
opened_at: 2026-05-31
opened_by: "PO (Alexandro / Claude)"
closed_at: 2026-06-01
closed_by: "PO (Alexandro / Claude)"
goal_outcome: achieved_rescoped
closure_rule: "[RE-ESCOPADA 2026-06-01 — Web-only] Encerra por goal-atingido quando STORY-038 e STORY-043 estiverem `done` E IDR-010 e IDR-011 estiverem `accepted` E IDR-006 estiver atualizada anotando supersede parcial de §b. A camada Patrol/mobile (STORY-039/040) saiu do escopo — MVP sem mobile — e migrou para o EPIC-009 (backlog), portanto NÃO é mais critério de fechamento. [Regra original: exigia STORY-038/039/040 `done` + IDR-010/011 aceitas + IDR-006 anotada.]"
goal: "[RE-ESCOPADO 2026-06-01 — Web-only] Fechar o EPIC-007 na parte Web — modelo E2E híbrido do WebApp em vigor: `integration_test` cobrindo UI Flutter (7 cenários de RBAC/funnel migrados de Playwright + área logada same-origin via STORY-043, rodando 0 flake em Chrome headless), Playwright reduzido a smoke HTTP do build deployado. `make e2e-webapp` orquestrando as camadas Web. IDR-010 e IDR-011 aceitas; IDR-006 §b marcada como parcialmente superseded. Padrão de teste Flutter (Keys/mocks/helpers/naming) registrado antes da STORY-022+ entrar para reduzir retrabalho. [Goal original incluía 'Patrol em pé com 1 cenário smoke em Android emulator' — removido no re-escopo; ver EPIC-009.]"
---

# SPRINT-2026-W26

> **⚠️ Fechada e re-escopada em 2026-06-01 (`status: closed`, `achieved_rescoped`).** O escopo Web foi entregue (STORY-038 + STORY-043 `done`, IDR-010/011 aceitas, IDR-006 §b anotada) e o EPIC-007 fechou Web-only. A camada **Patrol/mobile (STORY-039/040)** foi **despriorizada — o MVP não terá mobile** — e migrada para o **EPIC-009 (backlog)**. As seções abaixo são o **plano de abertura** (3→4 stories, incl. mobile) e ficam como contexto histórico; o resultado real está em §"Fechamento do sprint". Detalhes do corte em §"Mudanças no escopo".

## Objetivo do sprint

A SPRINT-2026-W25 está fechando o EPIC-001 (funil de identidade ponta a ponta em homolog). A W26 abre com escopo único: **fechar o EPIC-007 — E2E híbrida do WebApp Flutter**. É a primeira sprint Turni dedicada exclusivamente a um épico de fundação técnica (zero valor direto a profissional/contratante; valor indireto via determinismo do gate, prontidão para mobile, e redução de retrabalho na STORY-022+).

O epic.md de EPIC-007 já está escrito (`wave: WAVE-2026-01`, `status: draft`). As 3 estórias estão detalhadas em `status: draft`, e as 2 decisões transversais (IDR-010 modelo híbrido, IDR-011 padrão de teste Flutter) estão escritas em `status: proposed` aguardando aprovação do PO. Não há nada a inventar nesta sprint — só executar o plano que IDR-010 desenhou.

Recorte:

1. **STORY-038** (antiga 034 do EPIC-007 — renomeada por colisão com STORY-034 worker de EPIC-001) entrega o miolo: scaffolding de `integration_test` em `apps/webapp/integration_test/`, helpers compartilhados (`pumpApp`, `loginAs`, `assertOnRoute`), Keys namespaced nos widgets relevantes (padrão IDR-011), migração dos 7 cenários de `rbac-login.spec.ts` para Dart, Playwright reduzido a 5 cenários de smoke HTTP. Inclui propor IDR-010 e IDR-011 (já escritas, falta sair de `proposed` → `accepted`).
2. **STORY-039** adota Patrol como framework — `patrol` + `patrol_cli` em `dev_dependencies`, configuração Android (gradle, runner) e iOS (Podfile, test target), 1 cenário de smoke rodando em Android emulator local via `make e2e-webapp-patrol-android`. Não entrega cobertura nativa real — só prova que o framework está de pé.
3. **STORY-040** fecha o gate mobile local — `make e2e-webapp-android` rodando os `integration_test` em Android emulator com os 7 cenários da STORY-038 verdes, `make e2e-webapp-ios` análogo em iOS simulator (condicionalmente, se houver macOS), runbook documentando setup e política (opcional no MVP, obrigatório a partir da 1ª release mobile — IDR-010 §e).
4. **STORY-043** (adicionada 2026-06-01) entrega o **harness same-origin** para `integration_test` no Web — reverse-proxy + `--web-launch-url` para o app rodar same-origin com a API sob `flutter drive`, de modo que o **cookie de sessão Sanctum funcione** e a **área logada** seja testável (welcome e demais fluxos autenticados). Migra os fluxos flaky restantes (welcome, validações de pré-cadastro) de Playwright para `integration_test`, deixa `app-update` como smoke, e reduz `tests/e2e/` ao smoke HTTP. Caminho técnico **já provado por spike** durante a STORY-038. Bloqueada por STORY-038; paraleliza com STORY-039/040 (que são mobile/Patrol).

O sprint **NÃO** abre frente nova fora do EPIC-007: EPIC-002 (vaga + feed + candidatura), que era a sequência natural pós-EPIC-001, fica para SPRINT-2026-W27. Justificativa: STORY-022+ (já planejada para EPIC-001 mas ainda não escrita) e todas as stories de feature nova do WebApp pós-EPIC-001 devem nascer em `integration_test` seguindo IDR-011 — quanto antes o padrão estiver de pé, menos dívida de reescrita gera EPIC-002 em diante.

## Escopo e duração

- **Escopo confirmado**: 3 estórias — todas de enablement (038/039/040), todas para o `programador`. Zero estórias de implementation de feature, zero de validation (EPIC-007 não tem story de validador — métrica de sucesso é objetiva: 5 execuções consecutivas verdes do `make e2e-webapp` sem flake, comparação de wall-time, IDRs aceitas).
- **Duração**: **aberta**, com fechamento por goal-atingido. Sem histórico de sprint de fundação técnica para calibrar; expectativa realista **1–2 semanas** baseada em (a) `integration_test` é caminho pavimentado pela documentação oficial do Flutter, (b) os 7 cenários a migrar já têm equivalente Playwright funcional como referência de comportamento esperado, (c) Patrol envolve setup nativo Android (e iOS condicional) — risco de tempo se o ambiente local não tiver Android SDK pronto.
- **Soft-cap**: a definir na ativação (~14 dias úteis após `start_date`). Se o goal ainda não bateu na data, gatilho de reavaliação: (a) seguir sem ajuste, (b) reduzir STORY-040 a Android-only deixando iOS para sprint futura (mantém goal-atingido se Android emulator local prova o gate), (c) renegociar o L de STORY-038 dividindo migração de cenários (auth fechado vs. funnel/RBAC fechado).

## Estórias incluídas

| ID        | Título                                                                                | Épico    | Tipo       | Papel       | Tamanho | Design? | Status final                                          |
| --------- | ------------------------------------------------------------------------------------- | -------- | ---------- | ----------- | ------- | ------- | ----------------------------------------------------- |
| STORY-038 | Adotar `integration_test` no WebApp Flutter Web e migrar os 7 cenários de RBAC/funnel | EPIC-007 | enablement | programador | **L**   | não     | **`done`**                                            |
| STORY-043 | Harness same-origin para integration_test no Web — cobrir a área logada e migrar os fluxos flaky restantes | EPIC-007 | enablement | programador | **L**   | não     | **`done`**                                            |
| ~~STORY-039~~ | ~~Adotar Patrol para cenários nativos~~ → **movida p/ EPIC-009 (backlog)**         | EPIC-009 | enablement | programador | M       | não     | **de-escopada** 2026-06-01 (MVP sem mobile)           |
| ~~STORY-040~~ | ~~Gate E2E mobile local — Android emulator + iOS simulator~~ → **movida p/ EPIC-009** | EPIC-009 | enablement | programador | M       | não     | **de-escopada** 2026-06-01 (MVP sem mobile)           |

**Sizing entregue**: **2L** (STORY-038 + STORY-043, ambas `done`). Plano original era 2L+2M; as 2M (STORY-039/040, Patrol/mobile) foram **de-escopadas em 2026-06-01** quando o PO decidiu que o MVP não terá mobile — migraram para o EPIC-009 (backlog). **Sem estória stretch.** O objetivo Web — gate determinístico + área logada testável — foi atingido pelas 2L.

**Sem `requires_design: true` em nenhuma das 3 estórias.** Designer não é gargalo aqui — sprint exclusivamente de programador. Designer pode usar a folga para adiantar specs do EPIC-002 (vaga + feed + candidatura).

## Ordem de execução obrigatória (dependências do EPIC-007)

```
SPRINT-2026-W25 fecha (EPIC-001 done) ──► PO aceita IDR-010 + IDR-011 ──► STORY-038 vira `ready`
                                                                              │
                                                                              ▼
                                                        STORY-038 (integration_test + 7 cenários migrados)
                                                                              │
                                                                ┌─────────────┤
                                                                │             │
                                                                ▼             ▼
                                                         STORY-039      (paralelizável a partir
                                                         (Patrol)        de STORY-038 done — ver Paralelismo)
                                                                │
                                                                ▼
                                                         STORY-040 (gate mobile + runbook)
                                                                │
                                                                ▼
                                                         EPIC-007 done
```

**Justificativa da ordem** (respeita `blocked_by` registrados em cada `.md`):

- **STORY-038** não tem `blocked_by` de outra story, mas tem **pré-condição de processo**: IDR-010 e IDR-011 precisam estar `accepted` antes do PO promover a story para `ready`. IDR-010 e IDR-011 já estão escritas em `status: proposed` — basta o PO ler, ajustar se quiser, e marcar `accepted` com `decided_at` e `decided_by`. **STORY-022+ não são bloqueadas por STORY-038** (cobertura existente continua via Playwright até a migração completar), mas nascerão seguindo IDR-011 — quanto antes melhor.
- **STORY-039** depende de STORY-038 `done` (precisa do scaffolding `integration_test` + IDR-010 aceita + IDR-011 aceita). Não pode começar antes.
- **STORY-040** depende de STORY-038 `done` (precisa dos 7 cenários `integration_test` rodando em Web para então rodar os mesmos em mobile) **e** STORY-039 `done` (runbook referencia `make e2e-webapp-patrol-android` como complemento — IDR-010 §c).

**Paralelismo legítimo:**

- STORY-039 e STORY-040 podem ser **parcialmente paralelizadas** após STORY-038 fechar: STORY-039 trabalha em `apps/webapp/{android,ios}/` (config Patrol + 1 cenário smoke) enquanto STORY-040 começa o runbook e o Makefile target `e2e-webapp-android`. Mas STORY-040 só sai de `in_progress` quando STORY-039 fechar (runbook referencia Patrol como complemento).
- **STORY-043** também paraleliza com STORY-039/040 após STORY-038 fechar: ela mexe no harness Web (proxy + Makefile + migração de specs Web), enquanto 039/040 mexem no nativo (Android/iOS/Patrol). Não há sobreposição de arquivos relevante. STORY-043 é bloqueada só por STORY-038.
- Nenhum paralelismo com EPIC-002 — sprint é mono-épico.

## Compromisso visível ao fim do sprint

- **`apps/webapp/integration_test/`** contém:
  - `helpers/pump_app.dart`, `helpers/login_helper.dart`, `helpers/route_helper.dart` — todos com docstrings e usos de exemplo (IDR-011 §c).
  - `auth/login_structure_test.dart`, `auth/login_validation_test.dart`, `auth/rbac_profissional_test.dart`, `auth/rbac_admin_rejected_test.dart`, `auth/funnel_guard_test.dart` — 7 cenários migrados de Playwright para Dart, rodando 100% em Chrome headless via `flutter test integration_test -d chrome --headless` (sem flake em 5 execuções consecutivas).
  - `native/patrol_smoke_test.dart` — 1 cenário Patrol (sugestão da STORY-039: permissão de notificação ou `image_picker` abrindo sheet do SO), rodando em Android emulator local via `make e2e-webapp-patrol-android`.

- **`apps/webapp/tests/e2e/`** reduzido a smoke HTTP enxuto: `webapp-hello-world.spec.ts` mantido + 1 cenário novo de deep link via URL real do browser (proteção IDR-006 §a). `rbac-login.spec.ts` **removido** (migrado para `integration_test/auth/`).

- **`apps/webapp/pubspec.yaml`** tem `integration_test` (SDK) e `patrol` em `dev_dependencies`; `pubspec.lock` commitado.

- **`Makefile`** com targets:
  - `make e2e-webapp` orquestra `webapp-build` → `flutter test integration_test -d chrome --headless` → `npx playwright test`. Sai 0 quando tudo passa. Tempo de wall-clock ≤ tempo atual da W25 (ou justificado se passar).
  - `make e2e-webapp-android` roda `flutter test integration_test` em Android emulator detectado, sai 0 quando os 7 cenários passam.
  - `make e2e-webapp-patrol-android` roda os cenários Patrol em Android emulator.
  - `make e2e-webapp-ios` análogo em iOS simulator (condicionalmente disponível em macOS).
  - `make e2e-webapp-integration` e `make e2e-webapp-smoke` documentados como atalhos para rodar isoladamente em modo dev (IDR-010 §d).

- **Decisões registradas**:
  - **IDR-010** e **IDR-011** em `status: accepted`, com `decided_at: <data do PO>` e `decided_by: Alexandro`.
  - **IDR-006** atualizada: header anota "§b parcialmente superseded por IDR-010 a partir de <data>"; §a (path strategy) e §c (build fresco) intocados.

- **Documentação**:
  - `apps/webapp/README.md` tem seção "Testes E2E" descrevendo o modelo híbrido, quando usar cada ferramenta, comandos.
  - `docs/operacao/runbook-mobile-e2e.md` (ou nome equivalente — STORY-040 decide) documenta setup do Android emulator e iOS simulator local, política de gate (opcional MVP / obrigatório pós-1ª release mobile).

- **Métrica de sucesso do EPIC-007 batida**:
  - Paridade de cobertura sem regressão: 7 cenários migrados, gate verde.
  - Determinismo: 5 execuções locais consecutivas de `make e2e-webapp` sem flake.
  - Tempo de gate: wall-time ≤ tempo atual (ou justificado).
  - IDRs aceitas.
  - Patrol vivo: ao menos 1 cenário smoke em Android.
  - Pronto para mobile: quando primeira story do native chegar, esforço é "adicionar target Android/iOS aos `integration_test` existentes", não reescrever.

## Decisões de produto/arquitetura que entram em vigor agora

- **IDR-010 — Modelo E2E híbrido** sai de `proposed` para `accepted`: `integration_test` cobre UI Flutter, Playwright fica reduzido a smoke HTTP do build deployado, Patrol cobre cenários do SO nativo. Tabela de decisão rápida (final da IDR-010) vira referência canônica para a STORY-022+.
- **IDR-011 — Padrão de teste Flutter** sai de `proposed` para `accepted`: Keys namespaced `ValueKey('<feature>:<element>')`, política de mock vs API real (default: API real via docker-compose + seed), helpers em `integration_test/helpers/`, naming `<feature>_<cenario>_test.dart`, determinismo via `pumpAndSettle()`. Vira pré-requisito de STORY-022+ — PO inclui referência a IDR-011 nas stories que escrever a partir da aceitação.
- **IDR-006 §b parcialmente superseded**: padrão Playwright/semantics fica histórico para os 5 cenários que continuam em Playwright (smoke HTTP). Cenários novos de interação **não nascem mais em Playwright**. §a (path strategy `usePathUrlStrategy()`) e §c (build fresco antes do gate) continuam vigentes — STORY-038 mantém `webapp-build` antes de `make e2e-webapp` (lição direta da IDR-006 §c).
- **IDR-004 refinada**: gate continua local e pré-tag. Conteúdo do gate muda (integration_test + smoke Playwright em vez de só Playwright completo). Smoke curl pós-deploy continua igual.
- **Política de gate mobile** (IDR-010 §e) registrada como referência para STORY-040: opcional no MVP; obrigatório a partir da 1ª release mobile (gatilho objetivo a definir na própria STORY-040).
- **Drift de wave a resolver**: `WAVE-2026-01.epic_ids` no `index.json` lista EPIC-000..006 mas não EPIC-007. EPIC-007 declara `wave: WAVE-2026-01` no próprio frontmatter. Durante a abertura da W26, atualizar `index.json` adicionando `EPIC-007` ao array da wave — alinhamento de documentação, não decisão de produto.
- **Colisão de ID resolvida**: as 3 estórias do EPIC-007, originalmente STORY-034/035/036 (criadas 2026-05-29), foram renomeadas para **STORY-038/039/040** em 2026-05-31. Motivo: EPIC-001 STORY-034 (worker Cloud Run Job, criada 2026-05-30, done em W25) reusou o ID 034 sem detectar a colisão; as 3 stories de EPIC-007 nunca tinham sido registradas no `index.json`, então a colisão não foi pega na origem. Renomeação preservou EPIC-001 STORY-034 intacta (já `done` com IDR-016 e commits) e atualizou: frontmatters das 3 stories do EPIC-007, `epic.md` de EPIC-007, IDR-010 e IDR-011 (referências internas). `SPRINT-2026-W25.md` e IDR-016 não foram tocados (referenciam o EPIC-001 STORY-034 legítimo).

## Riscos identificados na abertura

| Risco | Probabilidade | Impacto | Mitigação | Owner |
|---|---|---|---|---|
| STORY-038 (L) estoura sessão única — scaffolding + 7 migrações + 2 IDRs aceitas + atualização de IDR-006 + README + Makefile é peça grande | alta | médio | Critério de quebra escrito na própria estória (auth fechado vs. funnel/RBAC fechado); agente escala ao PO antes de inflar; aceitar carry-over é exceção válida (mesma régua de STORY-016/STORY-023 nas sprints anteriores) | Programador + PO |
| Setup do Android emulator local atrasa STORY-039/040 — primeira vez tocando `apps/webapp/android/` em fluxo de teste | média | médio | STORY-039 começa pelo runbook (instalar Android Studio, criar AVD, validar `flutter doctor`) antes de tocar config Patrol; passos documentados no `apps/webapp/README.md` e/ou runbook (STORY-040); PO aceita ajuste de tempo se setup do AVD virar item próprio | Programador |
| Ambiente local não tem macOS — STORY-040 iOS simulator fica fora do gate inicial | alta | baixo | IDR-010 §e prevê iOS condicional à disponibilidade de macOS; STORY-040 documenta caso macOS ausente como "Android-only obrigatório, iOS marcado como pendente em IDR-010 §e (gate fica condicional ao macOS aparecer)"; não bloqueia goal-atingido | Programador + PO |
| `pumpAndSettle()` trava em cenário com timer infinito (loading state, retry policy) — primeira execução pode revelar widget que não atinge quiescência | média | médio | Padrão IDR-011 §e prevê `pump(Duration)` quando justificado em comentário; programador escala se cenário específico exigir refator de widget; aceitar `pump` justificado é melhor que esperar quiescência forçada | Programador |
| Patrol Android falha em CI futuro mesmo passando local — sinal de drift se Patrol passar a ser gate em CI | baixa | médio | EPIC-007 fora-de-escopo explicita "suíte E2E rodando em CI" — não é problema desta sprint; risco fica para futura IDR de CI quando custo de manter gate local virar argumento | PO |
| Tempo de gate (`make e2e-webapp`) cresce >30% — fricção no dev local | média | médio | STORY-038 mede explicitamente: tempo atual da W25 (Playwright só) é o baseline; tempo do gate novo (integration_test + smoke) deve ser ≤ baseline ou justificado; se >+30%, escalar antes de aceitar | Programador + PO |
| Programador escolhe não renomear `rbac-login.spec.ts` (deixa Playwright legado convivendo) — dívida de cobertura duplicada | baixa | baixo | STORY-038 CA explícita: `rbac-login.spec.ts` é removido depois de `integration_test` estar verde; PO devolve PR se arquivo continuar; sem ginástica | Programador + PO |
| IDR-010/IDR-011 aceitas com pressa pelo PO porque "está no caminho da story" — viés de aceitação | média | médio | PO trata IDRs como leitura separada da execução da story; lê em sessão dedicada (mesmo agente, papel distinto); registra `decided_at` em commit isolado da story | Alexandro |
| EPIC-007 entra em conflito com `WAVE-2026-01` que tem como métrica "1 turno executado ponta a ponta por dia útil" — sprint exclusivamente técnica não move a métrica da wave | alta | baixo | Decisão consciente do PO: EPIC-007 reduz dívida e prepara para EPIC-002+ (que sim movem a métrica). Drift do epic_ids da wave resolvido na abertura da W26 (ver §Decisões). Métrica da wave continua sendo medida — só não avança nesta sprint | PO |

## Acompanhamento contínuo (PO)

- **Diário** (~10 min): olhar `index.json`, identificar o que está `in_progress` / `blocked` / `done`. Desbloquear o que pode.
- **Mid-sprint check D+5**: PO verifica se STORY-038 está em `in_review` ou `done`. Se ainda `in_progress`, conversar com programador — sinal de que a quebra deveria ter acontecido.
- **Mid-sprint check D+10**: PO verifica se STORY-039 e STORY-040 estão progredindo. Se STORY-040 travou no iOS por falta de macOS, soltar para o caminho Android-only conforme mitigação registrada.
- **Soft-cap check D+14**: se goal não bateu, decidir entre (a) seguir sem ajuste, (b) reduzir STORY-040 a Android-only, (c) renegociar L de STORY-038.

## Disciplina de processo (mantida da W25)

Regras mantidas:

1. **`sprint_id` no frontmatter** das 3 estórias atualizado no mesmo commit que adiciona ao `sprints[*].story_ids` do `index.json`. Aplicado na abertura desta sprint.
2. **Marcação de CA**: ao transicionar para `status: done`, todos os CAs atendidos no `.md` devem estar `[x]`. CA `[ ]` em estória `done` → PO devolve para `in_progress`.
3. **"Verdade de corredor" vira IDR/ADR antes**: se durante a execução uma estória citar decisão não registrada, o agente para, escala ao papel dono, só prossegue depois do registro. Particularmente relevante aqui: STORY-038 propõe IDR-010 e IDR-011 — qualquer ajuste material nas IDRs durante a execução vira commit de IDR antes de PR de story.
4. **Sync Designer↔Programador**: N/A nesta sprint (zero `requires_design: true`).
5. **Mid-sprint check ANTECIPADO** é comportamento esperado: PO olha `index.json` no fim de cada dia.

Regras novas para W26:

6. **STORY-038 aceita carry-over com aprendizado**: se o L estourar, programador escala antes de inflar; PO aceita quebra em sub-estórias (`38a` scaffolding + 5 cenários auth, `38b` 2 cenários funnel + IDRs aceitas + README/Makefile). Não há vergonha em quebrar — sinal de calibração de tamanho.
7. **IDR-010 e IDR-011 aceitas em sessão separada da execução da story** (regra nova): PO lê as duas IDRs em chat dedicado, sem o agente da STORY-038 presente. Aceitação registra `decided_at` em commit isolado. Evita viés de "está no caminho, aceito junto".
8. **Renomeação preventiva de stories futuras**: como reação à colisão STORY-034 detectada na abertura desta sprint, a próxima estória criada em qualquer épico **deve verificar `index.json`** antes de escolher número — convenção operacional registrada aqui até virar prática automática.

## Mudanças no escopo do sprint

> Toda alteração no conjunto de estórias após esta abertura registra aqui, com data e motivo.

| Data | O que mudou | Motivo | Custo (estória solta/movida) |
|---|---|---|---|
| 2026-05-31 | Abertura: 3 estórias no escopo (STORY-038/039/040, EPIC-007). Renomeação preventiva de STORY-034/035/036 → STORY-038/039/040 por colisão com STORY-034 worker (EPIC-001, done em W25). | Pedido do PO em chat: "criar uma sprint para implementarmos o EPIC-007". Renomeação necessária porque EPIC-001 STORY-034 já está `done` com IDR-016 e commits — colisão impede registro consistente em `index.json`. EPIC-007 stories nunca tinham sido indexadas, então rename é mais barato que renomear EPIC-001 STORY-034. | Sem deslocamento de outras estórias. Sprint EPIC-002 (sequência natural pós-EPIC-001) fica para SPRINT-2026-W27, dentro do compromisso da wave (target_completion 2026-08-31, folga preservada). |
| 2026-06-01 | **+STORY-043 (L)** no escopo: harness same-origin para `integration_test` no Web (cobrir área logada) + migração dos fluxos flaky restantes (welcome, validações de pré-cadastro) para `integration_test`; `app-update` fica como smoke Playwright; `tests/e2e/` reduzido ao smoke HTTP. Sizing 1L+2M → **2L+2M**. Closure-rule passa a exigir STORY-043 `done`. | Durante a STORY-038, o spike de 2026-06-01 provou que matar o flake **também na área logada** (chamadas autenticadas pós-login, ex.: welcome `welcome-visto`) exige um harness same-origin sob `flutter drive` — maior que o escopo da STORY-038 e tocando IDR-014/009. PO optou pela **solução de raiz** e incluiu a story de enabling nesta sprint, com o Caminho 1 (reverse-proxy + `--web-launch-url`) **já provado**. | Sem deslocamento de outras estórias. EPIC-002 segue para W27. STORY-043 paraleliza com STORY-039/040 (Web vs. nativo). Risco do novo L mitigado pela receita já provada. |
| 2026-06-01 | **−STORY-039 e −STORY-040 (2M)** saem do escopo e migram para o **EPIC-009 (backlog, mobile E2E nativo)**. Sizing **2L+2M → 2L** (só Web). Closure-rule re-escopada para Web-only (038+043). Sprint **fechada** (`achieved_rescoped`). EPIC-007 re-escopado para Web-only e marcado `done`. | Decisão de PO: **o MVP não terá mobile**. Ao iniciar a STORY-039 descobriu-se ainda que `apps/webapp/` é Web-only (sem `android/`/`ios/`) — montar a base nativa só para o smoke do Patrol seria investir numa superfície (gradle/Podfile/signing/minSdk) que o produto não usa hoje. Despriorizar mobile e fechar o épico na parte Web (já 100% entregue: 038+043 `done`, IDRs aceitas) é o corte honesto. | Sem deslocamento de estórias Web. STORY-039/040 preservadas (sem renúmero) no EPIC-009, reativáveis quando a 1ª release mobile entrar no roadmap. Trabalho não-commitado da 039 (deps Patrol + scaffolding `android/`/`ios/`) revertido — árvore limpa. |

## Aprendizados em curso (mid-sprint)

> Para registrar conforme acontecem; consolidados na seção "Fechamento do sprint" no fim.

_(seção vazia na abertura — preencher durante execução)_

## Fechamento do sprint

> Fechada em 2026-06-01 por PO (Alexandro / Claude). Resultado: **`achieved_rescoped`** — goal Web atingido; mobile despriorizado e movido para backlog.

### O que foi entregue

- **STORY-038** (`done`) — `integration_test` no WebApp Flutter Web; 7 cenários de RBAC/funnel migrados de Playwright para Dart, rodando em Chrome headless; Playwright reduzido a smoke HTTP; gate híbrido no Makefile. IDR-010 e IDR-011 propostas e aceitas.
- **STORY-043** (`done`) — harness same-origin (reverse-proxy + `--web-launch-url`) para `integration_test` cobrir a **área logada** sob `flutter drive` (cookie Sanctum funcionando); welcome e validações de pré-cadastro migrados para `integration_test`; `app-update` como smoke Playwright; `tests/e2e/` reduzido ao smoke HTTP. IDR-021 aceita.
- **IDR-010** e **IDR-011** em `accepted`. **IDR-006 §b** anotada como parcialmente superseded (desde 2026-06-01).
- **EPIC-007** re-escopado para **Web-only** e fechado (`done`).

### O que ficou para trás (e por quê)

- **STORY-039 (Patrol)** e **STORY-040 (gate mobile Android/iOS)** — **despriorizadas por decisão de PO: o MVP não terá mobile.** Migradas sem renúmero para o **EPIC-009 (backlog, mobile E2E nativo)**, com gatilho de reativação "1ª release mobile no roadmap". Não são carry-over para uma próxima sprint — são backlog sem sprint alvo.
- Implicação descoberta na execução: `apps/webapp/` é **Web-only** (sem `android/`/`ios/`). A base nativa teria de ser criada do zero (`flutter create --platforms=android,ios`), o que reforçou a decisão de não pagar esse custo agora. O scaffolding gerado durante a tentativa foi revertido — árvore limpa.

### Aprendizados

- **Sprint de fundação técnica fecha bem por goal-atingido**, mesmo com re-escopo no meio: a parte Web (038+043) já satisfazia o valor real (gate determinístico + área logada testável); a camada mobile era investimento antecipado para um alvo (mobile) que o MVP não tem. Cortar cedo evitou montar e manter `android/`+`ios/` sem produto que os use.
- **Validar a premissa "o app já tem as plataformas nativas" antes de planejar stories nativas.** O EPIC-007 assumia que o scaffolding Android/iOS existia (herança implícita da STORY-034); não existia. Stories de enablement mobile devem listar "gerar/validar plataforma nativa" como item próprio (registrado no EPIC-009).
- **Re-escopo é decisão de produto, não de execução**: o agente parou ao detectar o gap e escalou ao PO em vez de criar a base nativa por conta própria.

### Ajustes para o próximo sprint

- **SPRINT-2026-W27** abre o **EPIC-002** (vaga + feed + candidatura), conforme já previsto. Todas as stories novas do WebApp nascem em `integration_test` seguindo IDR-011 (padrão agora de pé).
- **EPIC-009** permanece em backlog até decisão de roadmap mobile; quando reativado, sua 1ª story trata o scaffolding nativo como item explícito.
