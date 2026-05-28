---
sprint_id: SPRINT-2026-W23
wave: WAVE-2026-01
status: closed
start_date: 2026-05-27
end_date: 2026-05-28
closed_at: 2026-05-28
closed_by: PO (Alexandro / Claude)
soft_cap_date: 2026-06-14
closure_rule: "Fechamento por goal-atingido: a sprint encerra assim que STORY-011 entregar veredito `approved`. Soft-cap em 2026-06-14 (~18 dias corridos) serve só como gatilho de reavaliação se o goal ainda não tiver batido; não é prazo de entrega."
goal: "EPIC-000 fechado: hello world em ambas as homologações (WebApp + Backoffice) deployado por tag, pipelines verdes, e veredito `approved` da STORY-011 (Validador)."
goal_outcome: achieved
verdict_resolution: "approved_with_pending tratado como goal atingido — 0 fails bloqueantes, 1 fail não-bloqueante (migrate:rollback em homolog) carregado como pendência operacional para EPIC-001."
---

# SPRINT-2026-W23

## Objetivo do sprint

A SPRINT-2026-W22 fechou a fundação documental do EPIC-000 (9 ADRs aceitas + DDR-001 aceito + PDR-013 emergente + Design System vivo + screen spec ready). Esta sprint é o complemento: **transformar essa fundação em código que roda em homologação**, com pipelines duplos automáticos, hello world visível em WebApp e Backoffice, e veredito independente do Validador fechando o EPIC-000. É a **primeira sprint com código de produção** do projeto Turni — a régua de qualidade herdada (cobertura ≥ 80% geral / ≥ 98% núcleo, E2E em browser real, automação por padrão) entra em vigor a partir daqui sem exceção.

## Escopo e duração

- **Escopo**: 5 estórias — 2 de enablement (006 setup, 007 pipeline), 2 de implementation (008 WebApp, 009 Backoffice) e 1 de validation (011) — que juntas fecham o EPIC-000 Foundation.
- **Duração**: **aberta**, com fechamento por goal-atingido. Decisão deliberada do PO (alinhado com Alexandro), apoiada no precedente cunhado na W22: sprint cujo goal foi 100% atingido é fechada imediatamente em vez de manter calendário inerte.
- **Soft-cap em 2026-06-14** (~18 dias corridos): se nessa data o goal ainda não tiver batido, **não é prazo estourado** — é gatilho para o PO reavaliar (escopo realista, dependência aberta, sinal de mudança de plano). A reavaliação documenta no campo "Mudanças no escopo do sprint" e segue.

## Estórias incluídas

| ID | Título | Épico | Tipo | Papel | Tamanho | Status atual |
|---|---|---|---|---|---|---|
| STORY-006 | Setup do repositório e ambiente local em 1 comando | EPIC-000 | enablement | programador | M | ready |
| STORY-007 | Pipeline CI/CD com deploy automático para as duas homologações | EPIC-000 | enablement | programador | **L** | done |
| STORY-008 | "Hello world" no WebApp — rota raiz, health-check e identidade visual base | EPIC-000 | implementation | programador (+ designer em paralelo) | M | ready |
| STORY-009 | "Hello world" no Backoffice — rota raiz e health-check | EPIC-000 | implementation | programador | S | ready |
| STORY-011 | Validação final do EPIC-000 Foundation | EPIC-000 | validation | validador | M | ready |

**Sizing total**: 1 S + 3 M + 1 L. **Atenção ao L (STORY-007)** — única estória LARGE do sprint, candidata natural a estouro de sessão única. Critério de quebra está na própria estória; se na execução o agente sentir que não cabe em uma sessão, escala ao PO antes de inflar.

## Ordem de execução obrigatória (dependências do EPIC-000)

```
STORY-006 (ambiente local em 1 comando)
    │
    ▼
STORY-007 (pipeline CI/CD + deploy tag-based para as 2 homologações)
    │
    ├─► STORY-008 (hello world WebApp)   ──┐
    └─► STORY-009 (hello world Backoffice)─┤  podem rodar em paralelo
                                            │  (sessões distintas, mesma main)
                                            ▼
                                       STORY-011 (validação final do EPIC-000)
```

**Por que esta ordem.** É a única sequência respeitada pelos `blocked_by` registrados no `index.json`. Pular ordem força E2E impossível (não há ambiente para validar). O paralelismo legítimo está só entre 008 e 009, depois que 007 acabar — e mesmo lá depende do Designer ter feito o sync de 15 min com o Programador da STORY-008 (CA-14 da STORY-010 cobre isso, mas a entrega aconteceu na W22, então o sync acontece dentro da W23, no início de STORY-008).

## Compromisso visível ao fim do sprint

Diferente da W22, **esta sprint entrega coisas que o usuário externo consegue ver**:

- Duas URLs em homologação, acessíveis pelo browser:
  - WebApp em homologação (Flutter) servindo a tela hello world com identidade visual do DDR-001.
  - Backoffice em homologação (Livewire) servindo rota raiz + health-check.
- Pipeline CI/CD ativo no GitHub Actions: PR → testes verdes → build → deploy automático para homologação a cada tag aplicada na main. Três deploys consecutivos verdes em ≤ 10 min como CA herdado da STORY-007.
- Comando único de setup local funcionando para um novo agente/desenvolvedor: do `git clone` ao "está rodando" em ≤ 1 comando.
- `validation/report.md` da STORY-011 com veredito `approved` e evidências (logs, prints, link de homologação). Esse arquivo é o gatilho formal para marcar o EPIC-000 como `done`.

## Decisões de produto/arquitetura que entram em vigor agora

A fundação fechada na W22 não é decorativa. A partir desta sprint, os agentes operam sob:

- **ADR-001/002/003** — stack Laravel + Livewire + Flutter; monolito modular com api/admin/worker; monorepo poliglota único.
- **ADR-004** — hospedagem GCP (Cloud Run + Cloud SQL + Firebase Hosting); IaC Terraform; deploy promoção tag-based.
- **ADR-000** — PostgreSQL como banco principal.
- **ADR-007/008** — Sanctum + Argon2id + RBAC por coluna; log JSON estruturado em stdout + health-check padrão + métricas RED via log-based metrics no Cloud Monitoring.
- **ADR-005/006** — não entram nesta sprint (Pagar.me + habitualidade são para EPIC-003), mas ficam latentes para que STORY-006 não faça nada que conflite.
- **DDR-001 + PDR-013** — Design System vivo, dual-theme claro/escuro (padrão = claro), cor por perfil. STORY-008 consome o screen spec `SCREEN-STORY-008-hello-world-webapp` (status `ready`).

Programador e Designer carregam suas próprias skills + as ADRs/DDR vigentes antes de começar. Conflito real entre ADR vigente e necessidade da estória escala ao Arquiteto via nova ADR; não se ajusta silenciosamente no código.

## Riscos identificados na abertura

| Risco | Probabilidade | Impacto | Mitigação | Owner |
|---|---|---|---|---|
| Throughput de implementação muito menor do que o documental — sprint pode levar 2-3 semanas em vez de fechar rápido | **alta** | médio | Soft-cap em 2026-06-14 com reavaliação; PO não força calendário; aprende para sizing futuro | PO |
| STORY-007 (L) estoura sessão única — pipeline CI/CD + 2 deploys + tag-based é peça grande | alta | médio | Agente escala ao PO antes de inflar; quebra em sub-estórias documentadas se necessário; aceitar carry-over para W24 é exceção válida aqui | Programador + PO |
| Custo GCP em homologação sai do bolso do Alexandro e pode crescer sem alerta — ambientes ficam ligados 24×7 | média | médio | STORY-007 deve incluir alerta de orçamento básico (CA da própria estória); revisar custo diário durante a sprint | PO + Alexandro |
| Primeira interação real Designer ↔ Programador (STORY-008) — sync de 15 min nunca foi exercitado | média | médio | Designer faz disponibilidade prévia; sync registrado em "Notas do agente" da STORY-008; se descoberta de design emergir, vira DDR-002 imediato (não corrige no código) | Designer + Programador |
| STORY-011 reprova alguma estória anterior — validador independente pode achar gap não óbvio | média | alto (atrasa fechamento do EPIC-000) | Aceitar reprovação como sinal saudável; PO abre estórias de correção em mini-sprint W24; **não** pressiona Validador a aprovar | Validador + PO |
| Alexandro nos 5 papéis em sprint com mais código real — fadiga cognitiva maior do que na W22 | média | médio | Sessão dedicada por papel, troca declarada; PO faz check diário curto separado de execução; aceitar ritmo mais lento como dado, não como falha | Alexandro |
| Risco herdado da W22: throughput documental criou expectativa irrealista para implementação | alta | baixo (já mapeado) | Comunicado em "Aprendizados W22" e neste documento; PO não usa W22 como baseline | PO |

## Acompanhamento contínuo (PO)

- **Diário** (~10 min): olhar `index.json`, identificar o que está `in_progress` / `blocked` / `in_review`. Desbloquear o que pode.
- **Mid-sprint check em 2026-06-03 (quarta)**: PO verifica se 006+007 fecharam. Se 007 ainda estiver `in_progress` e já passou de 7 dias, considerar quebra e replanejamento.
- **Soft-cap check em 2026-06-14**: se goal não bateu, abrir seção "Mudanças no escopo do sprint" abaixo e decidir entre (a) seguir sem ajuste, (b) tirar STORY-011 e fazê-la em mini-sprint dedicada, (c) tirar STORY-009 (Backoffice) e fazer só WebApp ponta a ponta.

## Disciplina de processo nova (vinda das lições da W22)

Estes itens são **regras explícitas** a partir desta sprint — não dependem de boa vontade:

1. **`sprint_id` no frontmatter** da estória é atualizado no mesmo commit que adiciona a estória ao `sprints[*].story_ids` do `index.json`. Sem isso, a abertura está incompleta. *Já aplicado na abertura desta sprint nas 5 estórias.*
2. **Marcação de CA**: ao transicionar uma estória para `status: done` no frontmatter, todos os CAs atendidos no corpo do `.md` devem estar `[x]`. **Se houver `[ ]` em estória `done`, o PO devolve para `in_progress`.** Aplica a partir desta sprint sem retroatividade.
3. **"Verdade de corredor" vira PDR/ADR/DDR antes**: se uma estória citar uma decisão de produto/arquitetura/design sem registro associado, o agente para, escala ao papel dono e só prossegue depois do registro. PDR-013 mostrou que o custo é baixo.
4. **Sync Designer ↔ Programador na STORY-008**: ≤ 15 min, registrado em "Notas do agente" da estória, antes de qualquer linha de UI. Cobre CA-14 da STORY-010 que entregou DDR-001.

## Mudanças no escopo do sprint

> Toda alteração no conjunto de estórias após esta abertura registra aqui, com data e motivo.

| Data | O que mudou | Motivo | Custo (estória solta/movida) |
|---|---|---|---|
| 2026-05-28 | STORY-007 reaberta (`done` → `in_progress` → `done`) após 1ª rodada de validação | Validador identificou 8 fails bloqueantes (CI vermelho, IAM não propagado, E2E nunca rodou, métrica primária não verificada com código completo). Correções: lint, IAM propagado via terraform apply, E2E ajustado para URL dinâmica do Cloud Run, rollback exercido em homolog, tags rc.10/11/12 demonstram métrica primária. | Sem custo de calendário (no mesmo dia) — só re-trabalho de ~horas. Aprendizado abaixo. |
| 2026-05-28 | STORY-011 executada em duas rodadas | 1ª rodada: `rejected` (8 bloqueantes). 2ª rodada após correções do Programador: `approved_with_pending` (0 bloqueantes, 1 não-bloqueante). Skill do Validador foi corrigida no meio (1ª rodada extrapolou o papel sugerindo estórias de correção; 2ª rodada se ateve a evidência e veredito). | Sem custo — o ciclo "valida → reprova → corrige → revalida" é exatamente o desenho previsto. |

## Aprendizados em curso (mid-sprint)

Para registrar conforme acontecem; consolidados na seção "Fechamento do sprint" no fim.

- **2026-05-28 — Throughput de implementação caiu como previsto.** A W22 fechou em ~1 dia (6 estórias documentais). A W23 fechou em ~1 dia também (5 estórias de implementação, incluindo CI/CD complexo e validação dupla) — surpresa positiva, mas com diferença qualitativa: a W22 foi praticamente linear; a W23 teve reabertura de STORY-007 e ciclo de revalidação. **Sinal real de throughput** ainda não está calibrado — precisa de sprints com naturezas e tamanhos diferentes para amostra honesta. Sigo cauteloso no sizing da próxima.
- **2026-05-28 — Validador funcionou como projetado.** A 1ª rodada reprovou em 8 itens. A 2ª rodada aprovou. O PO **não pressionou** o validador a aprovar; o Programador corrigiu e reentregou. Esse circuito independente é o que torna o veredito confiável.
- **2026-05-28 — Skill do Validador precisou de correção em flight.** O 1º relatório extrapolou o papel (propôs estórias de correção, sugeriu próximos passos). O 2º relatório se ateve a evidência + veredito. Skill foi ajustada no meio do sprint. Lição: o limite do papel "validador" é factualidade — planejamento é do PO. Aplicar para futuras validações de épico.

## Fechamento do sprint (encerrado em 2026-05-28)

> Sprint fechada pelo PO em **2026-05-28**, um dia depois da abertura (2026-05-27). Goal atingido em janela de horas, **17 dias antes do soft-cap** (2026-06-14). Padrão de fechamento por goal-atingido cunhado na W22 se confirma na W23 — duas sprints consecutivas fechando no dia em que o goal bate, em vez de aguardar calendário. Próximo passo é abrir o planejamento do **EPIC-001 (Cadastro e aprovação)**, que vai exigir Fluxo C (decompor o épico em estórias) antes da abertura da SPRINT-2026-W24.

### O que foi entregue

**Estórias (5/5 `done`):**
- **STORY-006** — Setup do repositório com `make setup` ~34s, hook pré-push instalado, job agendado `scheduled-setup-test.yml` verde, comando único do `git clone` ao "está rodando".
- **STORY-007** — Pipeline CI/CD dupla (CI em PR + release tag-based), deploy automático nas 2 homologações, 3 deploys consecutivos sob ≤ 10 min (rc.10 3:34 / rc.11 3:39 / rc.12 4:12), rollback exercido em homolog (Cloud Run + Firebase Hosting), IaC completo em `infra/`, runbook documentado. IDR-002 (versioning) + IDR-003 (admin homolog ingress) registradas.
- **STORY-008** — `app.homolog.turni.com.br` HTTP 200 v0.1.0-rc.12, `/health` payload ADR-008, PWA manifesto + service worker, cobertura WebApp 85.5%, E2E em browser real ✅ na pipeline.
- **STORY-009** — Backoffice em homolog HTTP 200 v0.1.0-rc.12 via Cloud Run URL (`turni-admin-homolog-dnj2tcr2xa-rj.a.run.app`; DNS customizado bloqueado por constraint regional do Cloud Run em `southamerica-east1`, documentado em IDR-003), `/health` payload ADR-008, logs com `request_id` rastreável, E2E ✅ via URL dinâmica.
- **STORY-011** — Validação final em 2 rodadas. 1ª: `rejected` (8 bloqueantes — relatório preservado como histórico). 2ª: `approved_with_pending` (0 bloqueantes, 1 não-bloqueante).

**Métrica primária atingida com evidência observada por terceiros:** tag dispara deploy em ambas as homologações em ≤ 10 min, repetível 3× sem intervenção, health-check verde, E2E ✅ — rc.10/rc.11/rc.12 documentadas no `validation/report.md`.

**Decisões registradas no sprint:** IDR-002 (versioning e exposição de versão runtime) + IDR-003 (admin homolog ingress all para viabilizar E2E no CI por constraint regional do Cloud Run).

**Subprodutos não previstos no goal mas valiosos:**
- Runbook de operação `docs/operacao/runbook-homolog.md` com seções de setup, rollback e evidência de execução real em 2026-05-28.
- 5 CI runs consecutivos verdes na main pós-correção (incluindo Trivy api + admin, gitleaks, lint PHP/Flutter, smoke builds).
- E2E adaptado para usar URL dinâmica do Cloud Run via `gcloud run services describe` — padrão reutilizável quando DNS customizado não é viável.

### O que ficou para trás (e por quê)

**Pendência operacional carregada para a próxima fase** (não bloqueia o EPIC-000):
- **`php artisan migrate:rollback` não executado em homolog.** As 3 migrações atuais são Laravel-default (users, cache, jobs) com `down()` declarado; risco operacional baixo. O exercício real do rollback deve acontecer na primeira migração com lógica de negócio — provavelmente STORY-1 do EPIC-001 (criação de tabela `profissionais` ou equivalente). Registro técnico em `report.md` (F-NB-1) e o PO vai exigir a evidência de execução do `migrate:rollback` no momento de fechar essa estória. **Não vira estória própria** — vira critério de aceite herdado.

**Itens fora do escopo** que continuam pendentes (esperado):
- DNS de `admin.homolog.turni.com.br` — constraint regional do Cloud Run em `southamerica-east1` documentada em IDR-003. Reavaliar quando a Google liberar Domain Mapping na região, ou aceitar definitivamente operar o admin via URL do Cloud Run em homolog (em produção há ingress controlado pelo Cloud Load Balancer e o caminho é outro).

### Aprendizados

**Aprendizados de produto:**

- **Métrica primária do EPIC-000 só foi observável após o código completo do épico estar deployado.** A 1ª rodada do Validador reprovou em parte porque as tags anteriores (rc.9 e abaixo) não tinham o código completo de STORY-008+009 no mesmo deploy. Lição: critério de aceite "métrica X verificada em homolog" só conta como cumprido quando o **último merge do épico** estiver deployado e a métrica observada no estado final, não em estados intermediários. Aplicar isso explicitamente no checklist de validação de futuros épicos.
- **Constraint regional do Cloud Run virou decisão de produto disfarçada de infraestrutura.** A impossibilidade de Domain Mapping em `southamerica-east1` empurrou o admin para uma URL técnica em homologação. Não chegou a virar PDR porque a decisão é "aceitar restrição em ambiente não-produtivo" — registrada em IDR-003. Vigiar se isso vira problema quando a primeira pessoa não-técnica precisar usar o admin em homolog.

**Aprendizados de processo:**

- **Ciclo "valida → reprova → corrige → revalida" funcionou exatamente como projetado** e provou seu valor no primeiro uso real. A 1ª rodada pegou problemas reais (CI vermelho, IAM não propagado, E2E nunca rodando, métrica não verificada com código completo) que **o autor não tinha visto sozinho**. O custo do circuito (~horas de correção + 2ª rodada) é amplamente compensado pela qualidade do veredito final. Reforça a regra: Validador é independente, PO não pressiona por aprovação, ciclo é saudável.
- **Skill do Validador extrapolou o papel na 1ª rodada.** Propôs estórias de correção, sugeriu próximos passos, fez planejamento. Foi corrigida no meio do sprint para se ater a evidência + veredito. A 2ª rodada cumpriu o limite. Lição: papéis com fronteiras estreitas (validador, designer, programador) precisam de skill que enuncie explicitamente o que **não** fazem, além do que fazem.
- **Reabertura de estória em sprint funcionou sem custo de calendário.** STORY-007 passou por `done → in_progress → done` no mesmo dia. O frontmatter aceitou a retornar — boa propriedade do estado descrito como dado, não como evento. Manter o padrão.
- **Validação tem custo de tempo real (não só de calendário).** O Validador independente exige seu próprio bloco de trabalho. Em estimativas futuras, a estória de validação não é "trivial" — é M legítimo, especialmente em épicos grandes.
- **Marcação de CA dos `[x]` melhorou em relação à W22.** STORY-006/007/008/009 fecharam com CAs marcados (vs. 4/6 com `[ ]` na W22). Disciplina nova surtiu efeito sem precisar de hook automático. Manter a vigília mas não criar ferramental ainda.
- **PWA Flutter web caiu na conta na hora certa.** STORY-008 entregou PWA mínimo (manifesto + service worker) — barato porque o Flutter gera por default. Resolveu um requisito não-funcional sem virar discussão.
- **`sprint_id` no frontmatter foi aplicado desde a abertura.** Disciplina nova da W23 funcionou — nenhuma estória da W23 saiu com `sprint_id: null`. Padrão consolidado.

### Ajustes para o próximo sprint

- **Critério de aceite "métrica em homolog" deve ser observada no estado final do épico**, não em estados intermediários. Incluir essa observação no checklist genérico de validação (em `docs/skills/po/templates/validation-checklist.md` ou equivalente).
- **`migrate:rollback` em homolog vira critério herdado** para a primeira estória do EPIC-001 que crie migração com lógica de negócio. Não vira estória própria.
- **Próximo passo é Fluxo C do EPIC-001 (Cadastro e aprovação)**, não abertura imediata de SPRINT-2026-W24. EPIC-001 ainda está em `status: draft` no `index.json` — primeiro escrever as estórias em `ready`, depois abrir a sprint. Padrão observado na W22 (Fluxo C antes da abertura) é o saudável.
- **Sessão dedicada do PO para escrever o EPIC-001 e suas estórias** antes de qualquer próxima sprint. Inclui contexto novo (cadastro PF/MEI/PJ, fluxo de aprovação no backoffice, RBAC vivo pela primeira vez) que merece deliberação sem pressa.
- **Manter disciplina de skill enxuta para o Validador**: ao executar STORY-011 do próximo épico, validador se atém a evidência + veredito. PO planeja.
