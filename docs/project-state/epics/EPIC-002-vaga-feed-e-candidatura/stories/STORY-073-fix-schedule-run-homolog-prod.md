---
story_id: STORY-073
slug: fix-schedule-run-homolog-prod
title: Fix — `php artisan schedule:run` em homolog/prod (F-NB-1 do EPIC-002 — auto-retirada de candidatura em limbo)
epic_id: EPIC-002
sprint_id: SPRINT-2026-W28
type: bugfix
target_role: programador
requires_design: false
design_screen_id: null
status: in_progress
owner_agent: claude-opus-4-8-2026-06-06
created_at: 2026-06-03
updated_at: 2026-06-06
estimated_session_size: M
produces_idr: null  # possivelmente produz IDR de "Scheduler como Cloud Run Job + Cloud Scheduler"
renumbered_from: STORY-069  # numeração original colidiu com EPIC-010 STORY-069 (spike UUID/ADR-018) criada pelo Arquiteto no mesmo 2026-06-03 — renumerada para STORY-073 (próximo livre após 069..072 do EPIC-010)
---

# STORY-073 — Fix: `schedule:run` em homolog/prod (quita F-NB-1 do EPIC-002)

> **Para o agente programador:** este fix nasce do veredito `approved_with_pending` do EPIC-002 (STORY-054). O validador encontrou que o comando agendado `candidaturas:auto-retirar-apos-edicao` (STORY-052 CA-9) **nunca dispara** em homolog/prod porque o ambiente implantado só roda `queue:work` — não há ninguém invocando `php artisan schedule:run`. Comentário em `apps/api/routes/console.php:28-30` confirma a gap por escrito. O fix é de **infra + verificação**, não de regra de negócio.

## Contexto (por que esta estória existe)

PDR-009 desenha o ciclo de edição material em 4 passos: (1) notificar candidatos, (2) candidatura entra em `pendente_revisao_apos_edicao`, (3) candidato decide Manter/Retirar em até 24h, (4) sem decisão → auto-retirada. STORY-052 (W27) entregou os 4 passos no código — o passo 4 via `Schedule::command('candidaturas:auto-retirar-apos-edicao')->everyMinute()` em `apps/api/routes/console.php:22`.

Em homolog/prod, **só roda `queue:work`** (Cloud Run Job + Cloud Scheduler, módulo `infra/modules/worker-job/`). Nada invoca `php artisan schedule:run`. Consequência observada pelo validador: candidatura fica em `pendente_revisao_apos_edicao` **indefinidamente** quando o candidato ignora o e-mail — não vira `retirada`, não vira `confirmada`, fica em limbo. Contratante continua vendo aquele candidato como "em revisão" no painel.

A mesma gap afeta colateralmente:
- `Schedule::command('lembretes:cadastro')->dailyAt('09:00')` (STORY-021) — lembretes de completar cadastro nunca disparam.
- `Schedule::command('notificacoes:enviar-emails')->everyMinute()` (STORY-053, declaradamente "rede de segurança") — sweeper de backfill nunca roda (o caminho primário via fila funciona, então isso não causou problema visível, mas a rede de segurança estava desligada).

Esta estória **plumba o Scheduler do Laravel** no ambiente implantado e verifica que os 3 agendamentos passam a disparar.

- Épico originador: `epics/EPIC-002-vaga-feed-e-candidatura/epic.md`
- Documentos canônicos a ler ANTES de codificar:
  - `apps/api/routes/console.php` (3 `Schedule::command(...)` declarados; comentário linhas 28-30 admite a gap)
  - `apps/api/app/Console/Commands/AutoRetirarAposEdicaoCommand.php` (comando alvo do fix)
  - `infra/modules/worker-job/main.tf` (padrão Cloud Run Job + Cloud Scheduler — reusar)
  - `infra/modules/sql-scheduler/main.tf` (outro Cloud Scheduler em uso — referência)
  - `epics/EPIC-002-vaga-feed-e-candidatura/validation/report.md` (F-NB-1 que esta estória quita)
  - `decisions/pdr/PDR-009-edicao-de-vaga-pos-candidatura.md` (regra que justifica o passo 4)

## O quê (objetivo desta estória)

Provisionar invocação periódica de `php artisan schedule:run` em homolog e prod, fechando a F-NB-1 do EPIC-002 e ativando colateralmente todos os agendamentos declarados em `routes/console.php`.

## Por quê (valor para o usuário)

Contratante e candidato deixam de ficar em limbo quando candidato ignora notificação de edição material. PDR-009 passa a vigorar de fato em homolog/prod, não só em código.

## Critérios de aceite

Cada item é uma asserção testável. O agente DEVE escrever testes que cubram cada um.

- [ ] **CA-1:** Cloud Run Job (ou solução equivalente decidida em IDR) executa `php artisan schedule:run` a cada **1 minuto** em homolog. Disparado por Cloud Scheduler (mesmo padrão de `infra/modules/worker-job/`). IaC em Terraform sob `infra/modules/` (novo módulo ou extensão do existente — decisão do agente).
- [ ] **CA-2:** O mesmo provisionamento existe (e está documentado) para o ambiente de **produção**, ainda que gated por aprovação manual; deploy em prod **não** é requerido fechar esta estória (homolog é o suficiente para quitar F-NB-1).
- [ ] **CA-3:** Verificação ao vivo em homolog do caminho original do bug — cenário do validador reproduzido com timestamps reais:
  - (a) Contratante edita materialmente uma vaga com candidato pendente; candidatura vai para `pendente_revisao_apos_edicao`.
  - (b) Aguardar > 24h **simuladas** (via `travel(25h)` em teste E2E backend) — ou aguardar a janela real em homolog se viável.
  - (c) Observar: candidatura transitou para `retirada` automaticamente; audit log capturou `candidatura.retirada_por_edicao_auto`; contratante não vê mais aquele candidato como "em revisão".
- [ ] **CA-4:** Logs JSON em homolog mostram `schedule:run` executando 1×/min nos últimos 60 minutos (extrair amostra; anexar à estória).
- [ ] **CA-5:** Pelo menos 1 execução real de `candidaturas:auto-retirar-apos-edicao` observada nos logs de homolog em janela onde havia ao menos 1 candidatura elegível (cenário seedado para isso; logs anexados).
- [ ] **CA-6:** Colateral — `lembretes:cadastro` (STORY-021) registrado disparando às 09:00 BRT no log de homolog do dia seguinte ao deploy (verificação simples — extrair log).
- [ ] **CA-7:** Custo GCP do novo Cloud Run Job estimado e anexado à estória (Cloud Scheduler 1/min + Cloud Run Job de execução curta ~5s deve ficar abaixo de US$ 5/mês em homolog; se passar disso, escalar ao PO antes do deploy de prod).
- [ ] **CA-8:** `runbook-homolog.md` atualizado com seção "Scheduler do Laravel": como verificar que está rodando, como pausar (kill-switch via Cloud Scheduler), como retomar.
- [ ] **CA-9:** Comentário em `apps/api/routes/console.php:28-30` removido ou atualizado para refletir que `schedule:run` passou a rodar em homolog/prod.
- [ ] **CA-10:** Cobertura ≥ 80% no código novo (provavelmente só helper de infra ou teste E2E adicional); ≥ 98% **não se aplica** (não há regra de negócio nova).

## Fora de escopo

- Migrar `queue:work` para o mesmo Cloud Run Job (separação `queue:work` vs `schedule:run` é desejada — kill-switch independente; uma falha não derruba a outra).
- Adicionar novos `Schedule::command(...)` — só os 3 já declarados em `routes/console.php`.
- UX para reativar candidatura `retirada` automaticamente — wishlist se reclamado.
- Refatorar o pattern do worker-job para um módulo genérico de "cron Cloud Run" — pode aparecer como IDR se o agente julgar valioso, mas não é requerido.

## Padrões de qualidade exigidos

`docs/skills/po/references/quality-standards.md`. Como é fix de infra, foco é: (a) provisionamento por IaC (princípio #4 — sem clique manual no Console GCP), (b) verificação observável em homolog (logs anexados), (c) runbook atualizado. Sem teste novo de regra de negócio porque a regra já é testada nos 444 testes da STORY-052 com `$this->artisan('candidaturas:auto-retirar-apos-edicao')->assertSuccessful()`.

## Dependências

- **Bloqueada por:** nenhuma. Pode iniciar imediatamente — não depende de nenhuma estória da W28.
- **Bloqueia:** nenhuma direta. **Quita F-NB-1 do EPIC-002** (carry-forward).
- **Pré-requisitos de ambiente:** Cloud Run Job + Cloud Scheduler operantes (já existem para `worker-job`); credenciais Terraform/gcloud (herdadas da STORY-007).

## Decisões já tomadas (não as reabra)

- ADR-002 — Topologia (api + admin + worker; **o "worker" agora se subdivide em queue:work e schedule:run**).
- ADR-004 — Hospedagem GCP + IaC Terraform + Cloud Run.
- ADR-008 — Log JSON em stdout + log-based metrics.
- PDR-009 — Edição de vaga pós-candidatura (regra que esta estória honra).

## Liberdade técnica do agente

Você (programador) decide:
- Reusar o módulo `infra/modules/worker-job/` (extensão ou cópia) vs. criar módulo novo `infra/modules/scheduler-job/`.
- Nome exato do Cloud Run Job e do Cloud Scheduler.
- Política de tolerância: o que fazer se uma execução de `schedule:run` demora mais de 60s (provavelmente nada — `withoutOverlapping` no PHP já cuida).
- Forma exata da verificação do CA-4 (log query, dashboard simples, etc).

Você NÃO decide:
- Que o fix é via `schedule:run` (alternativa "cronar cada comando direto no Cloud Scheduler" foi descartada implicitamente pelo padrão Laravel já adotado — `Schedule::command(...)` em `routes/console.php` é a fonte de verdade).
- Que rodada de 1/min é a granularidade correta (definida na própria declaração de `everyMinute()` da STORY-052).
- Que `notificacoes:enviar-emails` continua sendo entregue **primariamente** pela fila (STORY-053) — esta estória só ativa o sweeper de segurança.

Se durante a execução perceber que precisa propor IDR (ex: "scheduler-job: padrão genérico para cron Cloud Run") por reuso futuro, **registre** em `decisions/idr/`. Não é requerido, mas é aceito.

## Definição de Pronto (DoD)

- [ ] Todos os CAs marcados.
- [ ] Pipeline CI verde.
- [ ] Deploy em homolog verificado (Alexandro confirma em chat — extrato de log + observação manual do cenário do CA-3).
- [ ] Runbook atualizado.
- [ ] Comentário em `routes/console.php` atualizado.
- [ ] `index.json` atualizado: STORY-073 `done`, F-NB-1 do EPIC-002 marcado como `quitada_por: STORY-073`.
- [ ] EPIC-002 `validation/report.md` (ou anexo) recebe nota "F-NB-1 quitada por STORY-073 em 2026-MM-DD".
- [ ] "Notas do agente" preenchida.

## Protocolo do agente (obrigatório)

`docs/skills/po/references/agent-task-format.md`.

## Notas do agente (preenchido durante/após execução)

### Entrada inicial (2026-06-06, antes de codar)

**Documentos lidos:** estória inteira; `apps/api/routes/console.php` (agora são **4** agendamentos — STORY-066 adicionou `turnos:detectar-no-show` everyMinute, também dependente desta estória); `infra/modules/worker-job/{main,variables,outputs}.tf`; `infra/envs/homolog/main.tf` (bloco `module "worker_job"`); `infra/envs/prod/main.tf` (scaffolded, ainda usa `worker-vm`, "NÃO aplicar antes do EPIC-006"); `.github/workflows/release.yml` (passo "Atualizar imagem do worker job"); `validation/report.md` F-NB-1; `runbook-homolog.md` §worker.

**Entendimento consolidado:** o ambiente implantado só roda `queue:work` (Cloud Run Job `turni-worker-job-homolog` + Cloud Scheduler 1/min). Nenhum processo invoca `php artisan schedule:run`, então os 4 `Schedule::command()` declarados nunca disparam. O fix é provisionar um segundo Cloud Run Job + Cloud Scheduler (mesmo padrão IDR-016) rodando `schedule:run` 1/min, separado do worker (kill-switch independente — explicitamente fora de escopo unificar).

**Plano (5 bullets):**
1. Parametrizar nomes do módulo `worker-job` (vars com default preservando os nomes atuais → zero churn de estado no worker existente) e instanciar `module "scheduler_job"` em homolog com `command = ["php","artisan","schedule:run"]`.
2. Espelhar em `envs/prod/main.tf` (CA-2 — documentado, gated; prod não é aplicado nesta estória).
3. `release.yml`: atualizar imagem do scheduler job a cada release (igual ao worker job).
4. CA-8/CA-9: runbook + comentário do `console.php`. CA-7: estimativa de custo.
5. Apply homolog + verificação ao vivo (CA-3..CA-6) com logs anexados.

**Mapeamento CA → verificação** (estória de infra — sem regra de negócio nova; a regra já é coberta pelos testes da STORY-052, ex. `CicloEdicaoMaterialE2ETest` com `travel(25h)`):
- CA-1/CA-2 → `terraform fmt -check` + `terraform validate` + `terraform plan` (homolog e prod) com saída esperada; revisão do diff.
- CA-3 → cenário real em homolog (editar vaga materialmente com candidato pendente; observar transição automática p/ `retirada` + audit `candidatura.retirada_por_edicao_auto`).
- CA-4 → log query `resource.labels.job_name="turni-scheduler-job-homolog"` na janela de 60 min; amostra anexada.
- CA-5 → log de execução real de `candidaturas:auto-retirar-apos-edicao` com candidatura elegível seedada.
- CA-6 → log do `lembretes:cadastro` às 09:00 BRT do dia seguinte.
- CA-7 → memória de cálculo anexada (abaixo).
- CA-8/CA-9 → diff do runbook e do `console.php`.
- CA-10 → não há código de app novo; cobertura existente inalterada (suíte completa roda antes do push).

**Dúvidas/ambiguidades:** nenhuma que bloqueie. Atenção operacional: Cloud SQL de homolog desliga sáb+dom (scheduler de economia) — hoje é sábado 2026-06-06; para a verificação ao vivo vou ligar a instância (`activation-policy=ALWAYS`) e devolver ao normal depois, como o `release.yml` já faz.

### Decisões tomadas
- 

### Descobertas
- Entrada da STORY-073 estava **ausente** de `stories[]` no `index.json` (presente só nas listas de sprint/épico e em `addressed_by` da F-NB-1). Criada ao assumir a estória.
- `routes/console.php` agora tem **4** agendamentos (a estória citava 3): STORY-066 adicionou `turnos:detectar-no-show` everyMinute, que também passa a disparar com este fix (o índice já anotava essa dependência).

### Bloqueios encontrados
- 

### IDRs criados
- 

### Cobertura final
- Unitários: <%>
- Verificação observável: <link para amostra de log + screenshot do painel>

### Links de evidência
- PR:
- Pipeline:
- Deploy de homologação:
