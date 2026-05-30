---
sprint_id: SPRINT-2026-W25
wave: WAVE-2026-01
status: active
start_date: 2026-05-30
end_date: null
soft_cap_date: 2026-06-19
opened_at: 2026-05-30
opened_by: "PO (Alexandro / Claude)"
closure_rule: "Fechamento por goal-atingido: encerra quando STORY-021, STORY-023, STORY-024 estiverem `done` e STORY-025 (validador) tiver emitido veredito em `validation/report.md` aceitável pelo PO (`approved` ou `approved_with_pending` que o PO assuma como goal-atingido). Soft-cap em 2026-06-19 (~21 dias corridos, espelhando a W24) serve como gatilho de reavaliação se goal não tiver batido — não é prazo de entrega."
goal: "Fechar o EPIC-001 — funil de identidade Turni completo em homolog: profissional (PF/MEI/PJ) e contratante percorrem pré-cadastro → aprovação → welcome → completar cadastro com AceiteEletronico imutável → `ativo`. E-mails transacionais ao vivo (aprovação concedida + lembrete de completar cadastro + reset de senha) com SPF/DKIM/DMARC configurados. Validador independente emite veredito em `validation/report.md` cobrindo a métrica primária do épico (cadastro fim a fim ≤ 5 min p/ usuário; aprovação visível ao admin ≤ 30s), imutabilidade do aceite em uso real, RBAC vivo, LGPD básica, observabilidade e acessibilidade."
---

# SPRINT-2026-W25

## Objetivo do sprint

A SPRINT-2026-W24 fechou em D+2 (2026-05-29) com 10/10 estórias do escopo confirmado em `done`, deixando o funil de identidade vivo em homolog até a tela de welcome real, RBAC vivo nas duas interfaces, audit log imutável, editor de templates carregado com texto-seed v1 do Alexandro, e ADR-009/010/011 `accepted`. STORY-021 (e-mails transacionais) foi deferida como stretch para esta sprint e STORY-023/024/025 já estavam fora do escopo confirmado da W24 desde a abertura.

Esta sprint **fecha o EPIC-001**. É o primeiro sprint Turni com expectativa explícita de **épico completo no fim** — e por consequência, com o validador independente (STORY-025) entrando em ação pela segunda vez (após STORY-011 no EPIC-000). Recorte:

1. **STORY-021** liga a comunicação automática ao usuário aprovado — fecha o gap de UX consciente da W24 e libera o Alexandro de virar correio humano em homolog. Também finaliza o reset de senha que STORY-016 deixou como stub Fortify e ativa lembretes de completar cadastro (48h/5d/14d).
2. **STORY-023 + STORY-024** levam profissional e contratante ao estado `ativo` — coletando documentos sensíveis (CPF/CNPJ, chave Pix, fotos) com criptografia em repouso (ADR-009) e **gerando o AceiteEletronico imutável** no clique de "Aceito e concluir cadastro". É a **primeira escrita real** sobre a infra de Template/Versao/Aceite que a W24 entregou apenas como leitura.
3. **STORY-025** percorre o checklist do EPIC-001 e produz veredito factual. Aprendizado herdado da STORY-011: validador fala fato + veredito; planejamento é do PO; reprovação é sinal saudável.

O sprint **NÃO** abre frente nova: tudo é fechamento do EPIC-001. EPIC-002 (vaga + feed + candidatura) só começa após o veredito do EPIC-001 ser `approved` (ou `approved_with_pending` que o PO assuma como goal-atingido, com pendências carregadas como F-NB-N).

## Escopo e duração

- **Escopo confirmado**: 4 estórias — 3 de implementation (021/023/024) + 1 de validation (025). Sem spike, sem enablement, sem stretch.
- **Duração**: **aberta**, com fechamento por goal-atingido. Histórico recente: W22, W23 e W24 fecharam todas no dia do goal-atingido bem antes do soft-cap. Para W25 a expectativa realista é **1–2 semanas**, dado que: (a) capacidade do EPIC-001 já calibrada (3 estórias M/dia com dupla Designer+Programador no fim da W24); (b) ADRs 009/010/011 estão `accepted` e foram exercitadas em código real na W24 — caminho técnico cristalizado; (c) STORY-023 é L (mesma classe de STORY-016) e precisa de respeito.
- **Soft-cap em 2026-06-19** (~21 dias corridos, espelhando a régua da W24). Se o goal ainda não bateu nessa data, gatilho de reavaliação: (a) seguir sem ajuste, (b) tirar STORY-024 (contratante) para mini-sprint W26 mantendo STORY-023 + STORY-025 (PF + validação) como núcleo, (c) renegociar o L de STORY-023 dividindo em sub-estórias (coleta vs. preview+aceite).

## Estórias incluídas

| ID        | Título                                                                          | Épico    | Tipo           | Papel       | Tamanho | Design? | Status atual |
| --------- | ------------------------------------------------------------------------------- | -------- | -------------- | ----------- | ------- | ------- | ------------ |
| STORY-021 | E-mails transacionais (aprovação + lembrete completar cadastro + reset de senha) | EPIC-001 | implementation | programador | M       | sim     | in_progress  |
| STORY-023 | Completar cadastro de Profissional no WebApp + geração do AceiteEletronico     | EPIC-001 | implementation | programador | **L**   | sim     | ready        |
| STORY-024 | Completar cadastro de Contratante no WebApp + geração do AceiteEletronico       | EPIC-001 | implementation | programador | M       | sim     | ready        |
| STORY-025 | Validação final do EPIC-001 Cadastro e aprovação                                 | EPIC-001 | validation     | validador   | M       | não     | ready        |
| STORY-034 | Worker em Cloud Run Job + Cloud Scheduler (substitui GCE worker-vm) + escada A   | EPIC-001 | implementation | programador | M       | não     | ready        |

**Sizing total**: 1 L + 4 M. **Atenção**: STORY-023 é L pelo número de campos × variação por `tipo_pessoa` × renderização do contrato + criação atômica do aceite. Critério de quebra está na própria estória (coleta vs. preview+aceite); se o agente sentir que não cabe em sessão única, escala ao PO antes de inflar — mesma régua de STORY-016 da W24. **STORY-034** entrou no escopo em 2026-05-30 (ver §Mudanças no escopo) para destravar a CA-13 da STORY-021 e pagar dívida estrutural do worker; é M porque toda a fiação (Direct VPC egress + `secret_env_vars` + Cloud SQL socket) já está provada pelo job `turni-migrate-homolog` (IDR-007) e pelo `cloud_run_api`.

**Sem estória stretch nesta sprint.** Justificativa: o objetivo é fechar EPIC-001 limpo; ampliar escopo introduz risco de o validador encontrar trabalho não previsto e abrir cauda. Se a velocidade da W25 surpreender (similar ao trio 019/020/022 da W24), o PO **não** puxa nada novo — usa o ganho para abrir SPRINT-2026-W26 com folga sobre EPIC-002.

## Ordem de execução obrigatória (dependências do EPIC-001)

```
                                                  ┌──► STORY-021 (e-mails) ─────────────────┐
                                                  │      ▲ (op-bloqueada por 034 Fase A)    │
                                                  │      │                                  │
W24 entregue (012-020, 022)  ────────────────────►┼──► STORY-023 (completar PF) ────────────┤── (4/4 done) ──► STORY-025 (validação) ──► EPIC-001 done
                                                  │                                          │
                                                  ├──► STORY-024 (completar PJ) ─────────────┤
                                                  │                                          │
                                                  └──► STORY-034 (worker Cloud Run Job) ─────┘
                                                        ├ Fase A (escada) ─► destrava CA-13 da 021
                                                        └ Fase B (entrega) ─► substitui worker-vm
```

**Justificativa da ordem**: respeita os `blocked_by` registrados no `index.json` e o `operationally_blocked_by` recém-adicionado da STORY-021.

- **STORY-021** depende de 014 (ADR-011), 016 (RBAC), 019 (fila — dispatch já enfileirado). Todas `done` na W24. Pode entrar no dia 1. **CA-13 só fecha quando a Fase A da STORY-034 estiver deployada em homolog** — coordenação operacional registrada no campo `operationally_blocked_by` (não é dependência de código, é de infra).
- **STORY-023** depende de 012/013/015/016/017/019/020/022. Todas `done` na W24. Pode entrar no dia 1.
- **STORY-024** depende de 012/013/015/016/018/019/020/022. Todas `done` na W24. Pode entrar no dia 1.
- **STORY-034** não tem `blocked_by`: toda a fiação (cloud-run, secrets, cloud-sql privado, IAM) já está na `main`. Pode entrar no **dia 0** com prioridade alta — Fase A antes do fim do dia 1 destrava CA-13 de STORY-021; Fase B em sessão separada antes de STORY-025.
- **STORY-025** depende de todas as anteriores do épico (012–024) **mais STORY-034**. Só inicia quando 021+023+024+034 estiverem `done` — não há ginástica que pule essa porta (lição direta da STORY-011: validador pré-deploy é teatro).

**Paralelismo legítimo**:
- 021/023/024/034 em sessões distintas do programador desde o dia 0 (sem dependência cruzada entre elas; cada uma tem seu seam claro). **STORY-034 Fase A** é prioridade — destrava 021 CA-13.
- Designer entrega 3 screen specs (SCREEN-021, SCREEN-023, SCREEN-024) em paralelo. STORY-034 **não requer design** (infra puro).
- SCREEN-021 é a mais leve (template HTML de e-mail); 023 e 024 são as mais pesadas (multi-step + preview de contrato). PO acompanha backlog do Designer diariamente.
- Mesma régua da W24: dupla Designer+Programador na mesma sessão do agente continua sendo padrão a reutilizar (aprendizado #1 da W24).

## Compromisso visível ao fim do sprint

- **URLs públicas em homolog**:
  - `app.homolog.turni.com.br/completar-cadastro` — fluxo multi-step real (substitui placeholder de STORY-016) para profissional **e** contratante (router decide pelo papel). Preview do contrato renderizado com dados do usuário antes do aceite. Após "Aceito e concluir cadastro", usuário transiciona para `ativo` em transação atômica.
  - `app.homolog.turni.com.br/login` — fluxo "Esqueci minha senha" funcional ponta a ponta (link assinado, TTL 60 min, throttling, anti-enumeração).

- **E-mails reais entregues em homolog**:
  - `aprovacao_concedida` — chega ao usuário aprovado em ≤ 30s após admin clicar "Aprovar" no Backoffice. HTML com identidade DDR-001 + texto plain. Subject correto.
  - `lembrete_completar_cadastro` — job agendado dispara nos gatilhos 48h/5d/14d para usuários `liberado, welcome_visto=true, cadastro_completo=false`. Para após 3 lembretes.
  - `recuperacao_senha` — link reset funciona ponta a ponta.

- **Configuração de domínio remetente em homolog**: SPF/DKIM/DMARC aplicados via Terraform; verificação externa (mxtoolbox ou equivalente) registrada como evidência no runbook.

- **AceiteEletronico imutável em uso real**:
  - Profissional PF aceita → linha em `aceites_eletronicos` com `template_versao_id` da v1 ativa de `pf_autonomo_eventual`, `conteudo_renderizado` igual ao preview, `ip`, `fingerprint`, `timestamp`.
  - Profissional MEI/PJ aceita → mesma linha referenciando v1 ativa de `mei_pj_b2b`.
  - Contratante aceita → mesma linha referenciando v1 ativa de `mei_pj_b2b` (mesmo template, uso distinto).
  - **Cenário-prova de imutabilidade**: admin ativa nova versão do template aplicável (via STORY-020); aceites existentes continuam renderizando o texto **original** — verificado em E2E ou integração.
  - Trigger Postgres bloqueia UPDATE/DELETE direto na tabela.

- **Veredito do validador em `epics/EPIC-001-cadastro-e-aprovacao/validation/report.md`**: `verdict: approved` | `approved_with_pending` | `rejected`, com evidência por item do checklist. EPIC-001 passa a `status: done` (ou `in_review` carregando pendência, decisão do PO).

- **Métrica primária do EPIC-001 observada com código completo deployado** (lição STORY-011): cadastro fim a fim em ≤ 5 min para o usuário; aprovação visível ao admin ≤ 30s após submit.

## Decisões de produto/arquitetura que entram em vigor agora

- **ADR-009/010/011 deixam de ser leitura e viram escrita real**: até a W24 a infra existia (tabelas, triggers, editor) mas nenhuma linha de `aceites_eletronicos` tinha sido criada via fluxo real. STORY-023 e STORY-024 fazem a primeira escrita real, e STORY-025 a valida em uso.
- **Decisão PO confirmada e materializada**: AceiteEletronico é gerado **no clique de "Aceito e concluir cadastro"** ao fim do completar cadastro (STORY-023/024) — **não** na aprovação do admin. Já estava embutida na STORY-019 da W24 como "decisão PO silenciosa"; aqui sai do papel. Programador da 023/024 não toca em STORY-019; STORY-025 (validador) verifica que o aceite só nasce nesse ponto e nunca antes.
- **Convenção `/api/usuarios/me/*` fora do `FunnelGuard` (IDR-014)** vira referência para STORY-023/024: o `POST /api/usuarios/me/completar-cadastro` (ou nome equivalente) precisa ser acessível em `await_complete` — o estado em que o usuário está quando submete. Programador entra na 023/024 sabendo desta convenção e não tem que descobrir do zero.
- **PDR-012 ganha cobertura completa**: o ciclo "editar template no Backoffice → ativar nova versão → aceites históricos continuam referenciando versão original" só fica realmente demonstrado quando STORY-023/024 + STORY-025 fecharem.
- **ADR-011 deixa de ser stub**: STORY-019 entregou o seam de envio (ACL + adapter log-only + job na fila); STORY-021 troca o adapter por um provedor real configurado em homolog (SPF/DKIM/DMARC, Secret Manager para credencial, alerta em falha persistente).
- **Decisão pendente do Alexandro (carregada da W24)**: gap latente de `HASH_DRIVER=argon2id` no admin (pego em STORY-019) — formalizar como F-NB-2 do EPIC-000 **ou** como aprendizado operacional. STORY-025 verifica o estado atual (admin login funciona) e registra a decisão **se** Alexandro tiver dado o veredito a tempo; senão fica como `n/a` no checklist + nota explícita.

## Riscos identificados na abertura

| Risco | Probabilidade | Impacto | Mitigação | Owner |
|---|---|---|---|---|
| STORY-023 (L) estoura sessão única — multi-step + preview + aceite atômico é peça grande | **alta** | médio | Agente escala ao PO antes de inflar; quebra em sub-estórias se necessário (23a coleta multi-step, 23b preview+aceite atômico); aceitar carry-over é exceção válida (mesma régua de STORY-016) | Programador + PO |
| Designer entrega 3 screen specs (SCREEN-021/023/024) — gargalo possível no dia 1 | alta | médio | Designer começa o lote imediatamente; sync ≤15 min por estória registrado em "Notas do agente"; padrão de dupla Designer+Programador na mesma sessão (aprendizado #1 da W24) reduz o gargalo | Designer + PO |
| SPF/DKIM/DMARC em DNS de homolog (STORY-021 CA-3) — primeira vez tocando DNS do domínio em código; pode atrasar devido a propagação | média | médio | Programador aplica via Terraform no início da estória; verificação via mxtoolbox em D+1 (propagação típica ≤24h); CA-3 pode ficar `in_review` enquanto demais CAs fecham | Programador + PO |
| Criptografia em repouso (STORY-023/024 CA-6) — primeira implementação em uso real do mecanismo escolhido em ADR-009 pode revelar gap | média | médio | Arquiteto pré-leitura do mecanismo antes do programador começar; query psql validando texto-cifra é critério explícito; se mecanismo se mostrar insuficiente, escalar para emenda em ADR-009 (não reabertura completa) | Programador + Arquiteto |
| AceiteEletronico imutável em uso real (STORY-023/024 + CA de imutabilidade) — trigger Postgres da STORY-020 só foi testado contra "tabela vazia"; primeira escrita real pode revelar falsos positivos | média | alto se acontecer | Teste de imutabilidade via psql é critério explícito por estória; STORY-025 CA-4 cobre cenário-prova com ativação de nova versão pós-aceite; falha = volta para `in_progress` | Programador + Validador |
| Validador encontra fail bloqueante (rejected) em STORY-025 — replanejamento do sprint necessário | média | alto | Aprendizado da STORY-011 incorporado: rejeição é informação saudável; PO planeja mini-sprint de correção (sem culpar validador); soft-cap 2026-06-19 dá folga; estórias de correção entram em SPRINT-2026-W26 | PO |
| Decisão pendente do PO sobre F-NB-2 (HASH_DRIVER no admin) não fechada antes de STORY-025 — item do checklist fica em limbo | média | baixo | STORY-025 trata como `n/a` ou `pass com ressalva` se a decisão não tiver saído; PO documenta a decisão em curto prazo (separado do sprint) | PO |
| Alexandro nos 5 papéis com validador entrando em ação (cuja prática real só rodou 1× em STORY-011) — fadiga + risco de auto-validação relaxada | alta | médio | Validador atua como sessão separada do PO (mesmo agente, papel distinto); STORY-025 SKILL.md explicita limite: fato + veredito, sem planejamento; PO trata relatório como gatilho sem pressionar a aprovação | Alexandro |
| Lembretes de completar cadastro (STORY-021 CA-5) — primeira regra de envio com janelas (48h/5d/14d) + tabela auxiliar pode produzir duplicação ou spam | baixa | médio | Teste cobre a regra de 3 lembretes explicitamente; idempotency_key (CA-14) bloqueia duplicação; ambiente local com Mailpit permite inspeção visual antes de homolog | Programador |
| **STORY-034 Fase A não destrava CA-13 da 021 a tempo** — escada usa cloud-init bespoke (gcloud secrets versions access + tmpfs) que pode falhar no primeiro deploy | média | alto se acontecer | Fase A é deliberadamente reversível (`module.worker` continua intacto até Fase B); se falhar, programador escala ao PO e Fase B sobe direto (custa ~1-2 dias a mais, mas dentro do soft-cap); IDR-016 documenta a tentativa | Programador + Arquiteto |
| **STORY-034 Fase B introduz Cloud Scheduler + Job novos** — primeira execução com `--stop-when-empty` + cron 1 min pode ter surpresa | média | médio | Reusa fiação 100% provada (`turni-migrate-homolog` IDR-007 + `cloud_run_api` `secret_env_vars`); CA-7 (smoke E2E) é critério explícito; Cloud Logging pega qualquer erro de execução; pausa do Scheduler é o kill-switch (CA-8) | Programador |
| **Drift no `sql-scheduler` após remoção do worker GCE** — módulo ainda referencia `worker_instance_name`/`worker_zone` | baixa | baixo | CA-5 da STORY-034 exige `terraform plan` sem drift após remoção; revisão do plan no PR | Programador |

## Acompanhamento contínuo (PO)

- **Diário** (~10 min): olhar `index.json`, identificar o que está `in_progress` / `blocked` / `in_review`. Desbloquear o que pode. Observar progresso do Designer nas 3 screen specs.
- **Mid-sprint check em 2026-06-05 (sexta — D+6)**: PO verifica se 021/023/024 estão progredindo. Se algo travou no Designer ou no programador, agir.
- **Mid-sprint check #2 em 2026-06-12 (sexta — D+13)**: PO verifica se 021/023/024 estão `done` ou `in_review`. Se sim, destrava STORY-025; se não, reavalia a quebra de STORY-023.
- **Pré-validação check em D+x (quando 021+023+024 ficarem `done`)**: PO confirma que `epics/EPIC-001-cadastro-e-aprovacao/validation/checklist.md` está completo e atualizado antes de aceitar `STORY-025` como `in_progress`. Validador não pode ser solto sem checklist íntegro (lição STORY-011).
- **Soft-cap check em 2026-06-19**: se goal não bateu, abrir seção "Mudanças no escopo do sprint" abaixo e decidir entre (a) seguir sem ajuste, (b) tirar STORY-024 (contratante) — profissional fechado já entrega metade do EPIC-001 e desbloqueia EPIC-002 parcialmente; (c) tirar STORY-021 — comunicação automática volta a ser manual.

## Disciplina de processo (vinda de W22/W23/W24)

Regras mantidas:

1. **`sprint_id` no frontmatter** das 4 estórias atualizado no mesmo commit que adiciona ao `sprints[*].story_ids` do `index.json`. Aplicado na abertura desta sprint.
2. **Marcação de CA**: ao transicionar para `status: done`, todos os CAs atendidos no `.md` devem estar `[x]`. CA `[ ]` em estória `done` → PO devolve para `in_progress`.
3. **"Verdade de corredor" vira PDR/ADR/DDR antes**: se durante a execução uma estória citar decisão não registrada, o agente para, escala ao papel dono, só prossegue depois do registro.
4. **Sync Designer↔Programador (≤15 min)**: registrado em "Notas do agente" antes da primeira linha de UI de cada estória `requires_design: true`. Esta sprint tem 3 syncs (021/023/024).
5. **Mid-sprint check ANTECIPADO é comportamento esperado** (aprendizado #2 da W24): PO olha `index.json` no fim de cada dia, não espera quinta-feira herdada de sprints documentais.

Regras novas para W25:

6. **Validador atua como sessão separada** (mesmo agente, papel distinto): conversa com Alexandro como PO acontece em chat separado de conversa com Alexandro como Validador. Evita contaminação de planejamento na hora de produzir veredito factual.
7. **STORY-025 só inicia com checklist íntegro**: PO confirma antes que `epics/EPIC-001-cadastro-e-aprovacao/validation/checklist.md` está atualizado refletindo o estado real do épico pós-W24. Lição: validador genérico contra checklist desatualizado é ruído, não validação.
8. **AceiteEletronico só nasce no clique de "Aceito e concluir cadastro"** (decisão PO confirmada): lembrete ativo no PR de STORY-023 e STORY-024. PO devolve se o programador estiver gerando aceite em outro ponto.
9. **Convenção `/api/usuarios/me/*` fora do `FunnelGuard`** (IDR-014): programador da 023/024 entra com a referência. PO valida no PR que o endpoint de completar cadastro segue a convenção.
10. **Endurecer `gotoApp` em E2E do pré-cadastro** (carry-over W24 — flake pré-existente em `pre-cadastro.spec.ts` e `pre-cadastro-contratante.spec.ts`): se o programador da 023/024 (que usa muitos componentes herdados de 017/018) sentir que o flake atrapalha o E2E novo, trata como sub-tarefa de endurecimento dentro da própria estória; PO aceita como melhoria oportunística sem criar estória dedicada.

## Mudanças no escopo do sprint

> Toda alteração no conjunto de estórias após esta abertura registra aqui, com data e motivo.

| Data | O que mudou | Motivo | Custo (estória solta/movida) |
|---|---|---|---|
| 2026-05-30 | Abertura: 4 estórias no escopo (021/023/024/025) | Fechamento do EPIC-001 conforme recomendação PO atualizada da W24 (§Fechamento do sprint → Ajustes para o próximo sprint). Sem estória stretch — foco em épico limpo. | — |
| 2026-05-30 | **+ STORY-034** (worker em Cloud Run Job + Cloud Scheduler — substitui GCE worker-vm) entra no escopo da W25 | Descoberta do programador durante STORY-021 em execução: o `module.worker-vm` hoje não conecta ao Cloud SQL (sem socket criado, sem proxy) nem carrega segredos (sem `APP_KEY`/`DB_PASSWORD`/`RESEND_API_KEY`) — **nenhum job da fila funciona em homolog**. Isso bloqueia operacionalmente a CA-13 de STORY-021, e por consequência STORY-022/025 e a métrica primária do EPIC-001. Decisão de topologia (Cloud Run Job + Scheduler) já está **pré-aprovada no ADR-004** §Negativas (linha 190) + §Sinais de revisão (linha 215) — vira IDR-016, sem reabrir ADR. Estória adota escada **A→B no mesmo sprint**: Fase A endurece o GCE worker o suficiente para destravar a CA-13 (DB por IP privado + 3 segredos via Secret Manager no startup); Fase B entrega o Cloud Run Job + Scheduler e remove o `worker-vm`. M (não L) porque toda a fiação já é provada por `turni-migrate-homolog` (IDR-007) e pelo `cloud_run_api`. Aprovação: chat 2026-05-30 (Arquiteto + PO). | Custo de calendário: ≤ 1-2 dias paralelos às demais (sem `blocked_by`); Fase A no dia 0/1 destrava STORY-021 CA-13. Sizing total da sprint: 1L + 3M → **1L + 4M**. Sem deslocar nenhuma estória do escopo confirmado. |

## Aprendizados em curso (mid-sprint)

> Para registrar conforme acontecem; consolidados na seção "Fechamento do sprint" no fim.

## Fechamento do sprint

> Preencher no encerramento.

### O que foi entregue

### O que ficou para trás (e por quê)

### Aprendizados

### Ajustes para o próximo sprint
