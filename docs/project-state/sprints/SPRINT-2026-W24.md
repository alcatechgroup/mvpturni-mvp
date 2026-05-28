---
sprint_id: SPRINT-2026-W24
wave: WAVE-2026-01
status: open
start_date: 2026-05-28
end_date: null
soft_cap_date: 2026-06-18
closure_rule: "Fechamento por goal-atingido: encerra quando todas as 10 estórias estiverem `done` e a métrica primária da sprint (funil de identidade até welcome real, em homolog, com RBAC vivo e audit log imutável) for observada. Soft-cap em 2026-06-18 (~21 dias corridos) serve como gatilho de reavaliação se goal não tiver batido — não é prazo de entrega."
goal: "Funil de identidade Turni vivo em homolog até a tela real de welcome — profissional (PF/MEI/PJ) e contratante completam pré-cadastro, equipe Turni aprova no Backoffice (com audit log imutável capturando a ação), e o usuário aprovado loga no WebApp e vê a tela de welcome real personalizada. RBAC vivo nas duas interfaces (admin no Backoffice; profissional/contratante no WebApp; cruzados bloqueados fail-secure). Editor de templates contratuais no Backoffice com texto-seed v1 validado pelo Alexandro carregado como versão ativa nos 2 templates (PF + MEI/PJ). 3 ADRs novas aceitas (ADR-009/010/011). Critério herdado F-NB-1 do EPIC-000 (migrate:rollback em homolog) exercido na STORY-016."
goal_outcome: null
verdict_resolution: null
---

# SPRINT-2026-W24

## Objetivo do sprint

A SPRINT-2026-W23 fechou o EPIC-000 Foundation com hello world deployado nas duas homologações e veredito `approved_with_pending` da STORY-011 (0 fails bloqueantes, 1 não-bloqueante carregado como F-NB-1). Em 2026-05-28 o PO executou o Fluxo C do EPIC-001 e produziu 14 estórias em `status: ready` (STORY-012 a STORY-025). Esta sprint é o primeiro sprint de **valor de produto real**: para de ser "infra que sobe" e passa a ser "usuário que entra".

O recorte da W24 é o slice **mais largo** entre os 3 propostos: 10 estórias que entregam o funil de identidade até o gate do welcome real — sem incluir `completar cadastro + AceiteEletronico` (STORY-023/024) nem os e-mails transacionais consumindo o dispatch (STORY-021) nem a validação final (STORY-025). Esse corte é coerente porque:

1. Demonstra **RBAC vivo pela primeira vez** — a peça que faltava desde EPIC-000.
2. Materializa **PDR-012** (editor de templates editável pelo admin) com texto-seed v1 do PO validado pelo Alexandro carregado em homolog. O editor é o primeiro lugar onde a equipe Turni edita conteúdo jurídico sem release.
3. Entrega **a fila de aprovação operacional** — equipe Turni faz seu trabalho central no backoffice.
4. Entrega **welcome real** — primeira impressão do produto.
5. Mantém **AceiteEletronico fora do escopo desta sprint** — o aceite vive em STORY-023/024 (consumindo o desenho fixado em ADR-010 desta sprint), e gerar aceite com texto definitivo merece sessão dedicada na W25.

O e-mail de aprovação concedida **NÃO chega ao usuário** no fim desta sprint (STORY-021 fica para W25). O **dispatch** de envio é feito por STORY-019, mas o **consumo + entrega** dependem do adapter de e-mail que STORY-021 vai implementar. Durante a W24 em homolog, o admin **aprova** e o usuário **consegue logar** com sucesso (login direto via formulário), mas não há notificação automática avisando. Comunicar isso ao Alexandro nas Notas de aceitação do sprint: é uma lacuna de UX consciente, observável no Mailpit/inbox de teste apenas se STORY-021 vier antes. Recomendação PO: se a velocidade da W24 surpreender, **trazer STORY-021 como estória stretch** — ela é pequena (M), depende só de STORY-014/016/019 (todas no escopo), e fecha a comunicação ao usuário.

## Escopo e duração

- **Escopo**: 10 estórias — 3 de spike (012/013/014), 1 de enablement (015 texto-seed do PO), 6 de implementation (016/017/018/019/020/022). Dispositivo de validação (STORY-025) fica fora; entra junto com STORY-023/024 na próxima sprint.
- **Duração**: **aberta**, com fechamento por goal-atingido. Padrão consolidado nas duas sprints anteriores (W22 e W23 fecharam no dia do goal). Para W24 a expectativa realista é **2–3 semanas**, dado que: (a) é a primeira sprint com volume real de implementação após o EPIC-000; (b) tem 1 estória L (STORY-016) e 7 M; (c) Designer entrega 6 screen specs (016/017/018/019/020/022) — possível gargalo de design no início.
- **Soft-cap em 2026-06-18** (~21 dias corridos). Se o goal ainda não bateu nessa data, gatilho de reavaliação: (a) seguir sem ajuste, (b) tirar 020 ou 022 para mini-sprint W25, (c) renegociar o L da STORY-016 dividindo em duas.

## Estórias incluídas

| ID | Título | Épico | Tipo | Papel | Tamanho | Design? | Status |
|---|---|---|---|---|---|---|---|
| STORY-012 | Spike — modelo de identidade (ADR-009) | EPIC-001 | spike | arquiteto | M | não | **done** |
| STORY-013 | Spike — Template/Versao e AceiteEletronico imutável (ADR-010) | EPIC-001 | spike | arquiteto | S | não | **done** |
| STORY-014 | Spike — provedor de e-mail + ACL (ADR-011) | EPIC-001 | spike | arquiteto | S | não | **done** |
| STORY-015 | Texto-seed dos templates contratuais (PF + MEI/PJ v1) | EPIC-001 | enablement | po | M | não | **done** |
| STORY-016 | RBAC vivo — login + roteamento por papel + funnel guard | EPIC-001 | implementation | programador | **L** | sim | ready |
| STORY-017 | Pré-cadastro de Profissional (PF/MEI/PJ) no WebApp | EPIC-001 | implementation | programador | M | sim | ready |
| STORY-018 | Pré-cadastro de Contratante no WebApp | EPIC-001 | implementation | programador | M | sim | ready |
| STORY-019 | Fila de aprovação no Backoffice | EPIC-001 | implementation | programador | M | sim | ready |
| STORY-020 | Editor de templates contratuais no Backoffice | EPIC-001 | implementation | programador | M | sim | ready |
| STORY-022 | Tela de welcome pós-aprovação no WebApp | EPIC-001 | implementation | programador | S | sim | ready |

**Sizing total**: 1 L + 7 M + 2 S. **Atenção dupla**: (1) STORY-016 (L) é candidata natural a estouro de sessão única — critério de quebra está na própria estória; se o agente sentir que não cabe, escala ao PO antes de inflar. (2) STORY-015 é a primeira estória com `target_role: po` — o PO executa diretamente (não há agente programador envolvido); o ciclo de validação com Alexandro precisa rodar dentro do sprint.

**Estória stretch (não está em escopo confirmado; PO traz se a velocidade permitir)**:
- STORY-021 (E-mails transacionais) — fecharia a comunicação automática ao usuário aprovado. M; depende de 014/016/019 (todas no escopo).

## Ordem de execução obrigatória (dependências do EPIC-001)

```
STORY-012 (ADR-009) ──┐
STORY-014 (ADR-011) ──┤───────────────────► STORY-016 (RBAC vivo) ──┐
                      │                                              │
STORY-013 (ADR-010) ◄─┘                                              │
       │                                                             │
       ▼                                                             │
STORY-015 (texto-seed PO) ───────────────────────────────────────────┤
                                                                     │
                                                                     ▼
                                              ┌──► STORY-017 (pré-cad profissional) ─┐
                                              ├──► STORY-018 (pré-cad contratante) ──┤  podem rodar
                                              └──► STORY-022 (welcome) ──────────────┤  em paralelo
                                                                                     │
                                                                                     ▼
                                                       ┌──► STORY-019 (fila aprovação) ─┐
                                                       └──► STORY-020 (editor templates)─┤
                                                                                          │
                                                                                          ▼
                                                                                    sprint goal
```

**Justificativa da ordem**: respeita os `blocked_by` registrados no `index.json`. As 3 spikes podem entrar em paralelo no dia 1 (012 e 014 sem dependência; 013 depende de 012 mas o esboço pode começar). STORY-015 (texto-seed do PO) começa em paralelo às spikes mas só fecha após ADR-010 (STORY-013) fixar o formato dos placeholders. STORY-016 (RBAC vivo) é a peça-pivô — sem ela, nenhuma das 5 estórias seguintes pode entregar resultado observável.

**Paralelismo legítimo**:
- Spikes 012/013/014 em sessões distintas do arquiteto (ou agente arquiteto distinto por spike).
- 017/018/022 em sessões distintas do programador após STORY-016 fechar.
- 019/020 em sessões distintas após 017/018 (019) e 020 (depende só de 013+015+016).

## Compromisso visível ao fim do sprint

Diferente da W23, esta sprint entrega **usuário real entrando no produto**:

- **URLs públicas em homolog**:
  - `app.homolog.turni.com.br/cadastro/profissional` — formulário público funcional para PF/MEI/PJ.
  - `app.homolog.turni.com.br/cadastro/contratante` — formulário público funcional.
  - `app.homolog.turni.com.br/login` — login real para profissional/contratante; admin é rejeitado com link para o admin.
  - `app.homolog.turni.com.br/welcome` — tela real personalizada, primeiro passo do funil pós-aprovação.

- **URLs admin em homolog** (via URL do Cloud Run conforme IDR-003):
  - `/login` do admin — autenticação real do admin com guard web + audit log.
  - `/aprovacoes` — fila operacional FIFO com filtros, aprovação 1-clique, remoção com confirmação dupla.
  - `/templates` — catálogo dos 2 templates com versão ativa, editor de nova versão com preview, ativação atômica.

- **3 ADRs novas em `accepted`**: ADR-009 (identidade + RBAC + audit log), ADR-010 (Template/Versao + AceiteEletronico imutável), ADR-011 (provedor de e-mail + ACL).

- **Texto-seed v1 validado por Alexandro** carregado em homolog como `versao = 1` ativa nos 2 templates.

- **RBAC vivo demonstrado por E2E na pipeline**:
  - Admin → Backoffice (sucesso).
  - Admin → WebApp (rejeitado com link).
  - Profissional → WebApp (sucesso + funnel guard).
  - Profissional → Backoffice (403 fail-secure).
  - Funnel guard redireciona `liberado, welcome_visto=false` → `/welcome`.

- **Audit log de admin imutável em homolog**: tentativa de UPDATE/DELETE direto via psql numa linha falha; evidência no runbook.

- **F-NB-1 do EPIC-000 quitado**: `php artisan migrate:rollback` exercido em homolog na STORY-016 (primeira migração com lógica de negócio: `role`, `status`, flags do funil) com evidência no runbook.

## Decisões de produto/arquitetura que entram em vigor agora

- **ADR-009 / ADR-010 / ADR-011** — viram `accepted` durante o sprint. A partir daí, todas as estórias subsequentes (incluindo as do EPIC-002+) consomem essas ADRs como fundação.
- **PDR-012 ativa pela primeira vez em código**: editor de templates editável pelo admin; aceites imutáveis referenciando versão (mesmo que o primeiro aceite só apareça em STORY-023/024 da W25, a infra está pronta).
- **Decisão PO embutida nas estórias**: AceiteEletronico é gerado no clique de "Aceito e concluir cadastro" no fim do completar cadastro (STORY-023/024 — fora desta sprint), **não na aprovação do admin**. Aprovação do admin é o gate operacional; o ato de consentimento informado é o clique do usuário com texto integral à vista. Essa decisão **opera silenciosamente nesta sprint** (não há aceite gerado aqui) mas precisa estar bem entendida pelo programador da STORY-019 (não tenta criar AceiteEletronico na aprovação por engano).
- **DDR-001 + PDR-013** — Design System vivo (tokens, voice-and-tone, dual-theme) consumido por 6 telas novas (016/017/018/019/020/022).
- **ADR-007** — Sanctum SPA cookie + guard web finalmente entra em uso real (até EPIC-000 era infra montada sem cliente).
- **Lições da STORY-011 da W23 aplicadas**: STORY-025 (validador) NÃO está nesta sprint — ela só entra quando STORY-023/024 também estiverem prontas. Princípio: validação no estado final do épico, não em estado intermediário.

## Riscos identificados na abertura

| Risco | Probabilidade | Impacto | Mitigação | Owner |
|---|---|---|---|---|
| STORY-016 (L) estoura sessão única — auth+RBAC+funnel guard é peça grande | **alta** | médio | Agente escala ao PO antes de inflar; quebra em sub-estórias se necessário (16a login, 16b RBAC, 16c funnel guard); aceitar carry-over é exceção válida | Programador + PO |
| Designer entrega 6 screen specs antes do início das implementações — gargalo possível | alta | médio | Designer começa o lote 016/017/018/019/020/022 imediatamente; sync ≤15 min por estória registrado em "Notas do agente"; PO acompanha o backlog do Designer diariamente | Designer + PO |
| 3 ADRs em paralelo podem cascatear retrabalho se uma reabrir outra (ex.: ADR-009 muda esquema de audit log → ADR-010 ajusta) | média | médio | Arquiteto faz pré-leitura cruzada antes de propor cada ADR; PO/Alexandro revisa as 3 em conjunto na hora da aprovação humana | Arquiteto + PO |
| Texto-seed (STORY-015) trava se ADR-010 demorar a fechar — formato de placeholder depende | média | baixo | Rascunho começa em paralelo com placeholder hipotético `{{namespace.campo}}`; revisão final só após ADR-010 `accepted`; impacto baixo porque revisão é local | PO |
| F-NB-1 (`migrate:rollback` em homolog) descumprido na STORY-016 — pendência viraria fail bloqueante na futura validação | baixa | alto se acontecer | Critério herdado declarado explícito no `index.json` da STORY-016 e no checklist; runbook tem espaço para evidência; PO verifica antes de marcar STORY-016 `done` | Programador + PO |
| AceiteEletronico inadvertidamente implementado em STORY-019 (engano por leitura desatualizada do epic.md) | baixa | médio | Decisão PO documentada em STORY-019 §Decisões já tomadas e em STORY-023 §Contexto; PO valida no PR | PO |
| E-mail de aprovação concedida não chega ao usuário em homolog (STORY-021 fora do escopo) — UX gap visível | **alta** (esperado) | baixo | Comunicado neste documento; Alexandro testando manualmente em homolog sabe disso; W25 fecha o gap | PO |
| Imutabilidade do audit log + AceiteEletronico (mecanismo escolhido em ADR-009/010) introduz complexidade no Postgres (triggers, REVOKEs) que pode atrasar STORY-016 ou STORY-020 | média | médio | Arquiteto escolhe mecanismo simples e reversível no ADR; teste de imutabilidade via psql é critério explícito; falha = volta para `in_progress` | Programador + Arquiteto |
| Alexandro nos 5 papéis em sprint com volume real de implementação — fadiga maior que W22/W23 | alta | médio | Sessões dedicadas por papel; PO faz check diário curto separado de execução; ritmo mais lento aceito como dado | Alexandro |

## Acompanhamento contínuo (PO)

- **Diário** (~10 min): olhar `index.json`, identificar o que está `in_progress` / `blocked` / `in_review`. Desbloquear o que pode. Observar se Designer está mantendo ritmo com as 6 screen specs.
- **Mid-sprint check em 2026-06-04 (quinta — D+7)**: ~~PO verifica se as 3 spikes e a STORY-015 fecharam.~~ **ANTECIPADO: as 4 estórias fecharam em D+1 (2026-05-28).** Verificar se STORY-016 já está em andamento. Se não, o gargalo é o Designer (screen spec 016 pendente).
- **Mid-sprint check #2 em 2026-06-11 (quinta — D+14)**: PO verifica se STORY-016 fechou. Se não, considerar quebra em sub-estórias. PO conversa com Alexandro sobre soft-cap e priorização de carry-over.
- **Soft-cap check em 2026-06-18**: se goal não bateu, abrir seção "Mudanças no escopo do sprint" abaixo e decidir entre (a) seguir sem ajuste, (b) tirar STORY-022 (welcome) — completar cadastro existe sem ela, vira placeholder; (c) tirar STORY-020 (editor) — operável com seed direto no DB, sem UI editora ainda.

## Disciplina de processo (vinda de W22/W23)

Regras explícitas mantidas:

1. **`sprint_id` no frontmatter** atualizado no mesmo commit que adiciona a estória ao `sprints[*].story_ids` do `index.json`. Aplicado na abertura desta sprint nas 10 estórias.
2. **Marcação de CA**: ao transicionar para `status: done`, todos os CAs atendidos no `.md` devem estar `[x]`. CA `[ ]` em estória `done` → PO devolve para `in_progress`.
3. **"Verdade de corredor" vira PDR/ADR/DDR antes**: se durante a execução uma estória citar decisão não registrada, o agente para, escala ao papel dono, só prossegue depois do registro.
4. **Sync Designer↔Programador (≤15 min)**: registrado em "Notas do agente" antes da primeira linha de UI de cada estória `requires_design: true`. Para esta sprint são 6 syncs (016/017/018/019/020/022) — Designer programa disponibilidade.

Regras novas para W24:

5. **3 spikes em paralelo precisam de coerência cruzada**: cada ADR cita as outras 2 da sprint nas suas referências. Alexandro revisa as 3 numa única sessão para garantir coerência antes do `accepted`.
6. **F-NB-1 é critério explícito da STORY-016**: PO **não marca STORY-016 `done`** sem evidência registrada de `migrate:rollback` em homolog.
7. **Decisão PO sobre AceiteEletronico (gerado no clique do usuário, não na aprovação)**: lembrete ativo no PR de STORY-019 — se o programador estiver criando AceiteEletronico ali por engano, PO devolve.

## Mudanças no escopo do sprint

> Toda alteração no conjunto de estórias após esta abertura registra aqui, com data e motivo.

| Data | O que mudou | Motivo | Custo (estória solta/movida) |
|---|---|---|---|
| 2026-05-28 | Abertura: 10 estórias no escopo (012/013/014/015/016/017/018/019/020/022) | Slice "mais largo" escolhido pelo PO (Alexandro / Claude) sobre os 3 cortes propostos pós-Fluxo C. STORY-021 fica como stretch; STORY-023/024/025 ficam para SPRINT-2026-W25. | — |

## Aprendizados em curso (mid-sprint)

> Para registrar conforme acontecem; consolidados na seção "Fechamento do sprint" no fim.

### 2026-05-28 — D+1: todas as 4 estórias preparatórias fechadas

**O que aconteceu:**

As 3 ADRs (012/013/014) e a STORY-015 (texto-seed PO) foram concluídas no mesmo dia da abertura da sprint. Velocidade muito acima da estimada: o mid-sprint check de D+7 foi antecipado para D+1.

**Estado resultante:**

- 3 ADRs aceitas: ADR-009 (identidade + RBAC + audit log), ADR-010 (Template/TemplateVersao + AceiteEletronico), ADR-011 (e-mail transacional + ACL).
- Texto-seed v1 dos dois templates contratuais (PF e MEI/PJ) produzido, validado pelo Alexandro e commitado.
- Caminho crítico para STORY-016 (RBAC vivo, L) totalmente desbloqueado — nenhuma dependência técnica pendente.

**Gargalo atual identificado:**

STORY-016 (`requires_design: true`) não pode iniciar sem a screen spec do Designer. O risco identificado na abertura — "Designer entrega 6 screen specs antes das implementações — gargalo possível" — é agora o **único bloqueio ativo**. PO aciona Designer para priorizar a spec da 016 imediatamente.

**Ajuste de expectativa:**

Se o Designer entregar a spec de 016 ainda nesta semana (até 2026-05-30), a sprint pode acelerar significativamente — o programador pode entrar na STORY-016 antes do D+7 previsto originalmente. O soft-cap de 2026-06-18 parece confortável dado o ritmo do D+1.

## Fechamento do sprint

> Preencher quando o goal bater (ou no soft-cap se reavaliar antes).

### O que foi entregue
(a preencher)

### O que ficou para trás (e por quê)
(a preencher)

### Aprendizados
(a preencher)

### Ajustes para o próximo sprint
(a preencher)
