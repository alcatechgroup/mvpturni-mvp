---
sprint_id: SPRINT-2026-W25
wave: WAVE-2026-01
status: closed
start_date: 2026-05-30
end_date: 2026-06-01
soft_cap_date: 2026-06-19
opened_at: 2026-05-30
opened_by: "PO (Alexandro / Claude)"
closed_at: 2026-06-01
closed_by: "PO (Alexandro / Claude)"
closure_rule: "Fechamento por goal-atingido: encerra quando STORY-021, STORY-023, STORY-024 estiverem `done` e STORY-025 (validador) tiver emitido veredito em `validation/report.md` aceitável pelo PO (`approved` ou `approved_with_pending` que o PO assuma como goal-atingido). Soft-cap em 2026-06-19 (~21 dias corridos, espelhando a W24) serve como gatilho de reavaliação se goal não tiver batido — não é prazo de entrega."
goal: "Fechar o EPIC-001 — funil de identidade Turni completo em homolog: profissional (PF/MEI/PJ) e contratante percorrem pré-cadastro → aprovação → welcome → completar cadastro com AceiteEletronico imutável → `ativo`. E-mails transacionais ao vivo (aprovação concedida + lembrete de completar cadastro + reset de senha) com SPF/DKIM/DMARC configurados. Validador independente emite veredito em `validation/report.md` cobrindo a métrica primária do épico (cadastro fim a fim ≤ 5 min p/ usuário; aprovação visível ao admin ≤ 30s), imutabilidade do aceite em uso real, RBAC vivo, LGPD básica, observabilidade e acessibilidade."
goal_outcome: achieved
verdict_resolution: "6/6 estórias do escopo confirmado em `done` (021/023/024/025/034/037). Validador emitiu veredito `approved_with_pending` em `epics/EPIC-001-cadastro-e-aprovacao/validation/report.md` (commit validado `0e1e4068…`, rc.42): zero fails bloqueantes; 1 fail não-bloqueante (F-NB-1 alerta SLA>20h não observado) + 6 passes com ressalva + pendências de verificação viva (cookies autenticados, e-mail em inbox, cronometragem exata, lista LGPD, env Argon2id em homolog). PO aceitou o veredito em 2026-06-01 e marcou EPIC-001 como `done`; pendências viram carry-forward sob gestão do PO. Duração efetiva ~3 dias (2026-05-30 → 2026-06-01) vs. soft-cap 21d — encerramento ~18d antes do gatilho. Núcleo do épico observado: cadastro → aprovação → completar → ativo com AceiteEletronico imutável (PDR-012 central comprovado por teste CA-16 contra Postgres real), RBAC vivo nas duas interfaces, editor de templates, audit log imutável, e-mails transacionais ao vivo (SPF/DKIM/DMARC verdes), worker Cloud Run Job + Scheduler 1/min ENABLED, auto-update do WebApp Flutter funcionando no celular do PO."
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
| STORY-021 | E-mails transacionais (aprovação + lembrete completar cadastro + reset de senha) | EPIC-001 | implementation | programador | M       | sim     | **done** (2026-05-30) |
| STORY-023 | Completar cadastro de Profissional no WebApp + geração do AceiteEletronico     | EPIC-001 | implementation | programador | **L**   | sim     | **done** (2026-06-01, rc.41) |
| STORY-024 | Completar cadastro de Contratante no WebApp + geração do AceiteEletronico       | EPIC-001 | implementation | programador | M       | sim     | **done** (2026-06-01, rc.42) |
| STORY-025 | Validação final do EPIC-001 Cadastro e aprovação                                 | EPIC-001 | validation     | validador   | M       | não     | **done** (2026-06-01, `approved_with_pending`) |
| STORY-034 | Worker em Cloud Run Job + Cloud Scheduler (substitui GCE worker-vm)             | EPIC-001 | implementation | programador | M       | não     | **done** (2026-05-30) |
| STORY-037 | Auto-atualização do WebApp Flutter (consumidor do `version.json`) + versão visível na UI | EPIC-001 | implementation | programador | M       | sim     | **done** (2026-05-31) |

**Sizing total**: 1 L + 5 M. **Atenção**: STORY-023 é L pelo número de campos × variação por `tipo_pessoa` × renderização do contrato + criação atômica do aceite. Critério de quebra está na própria estória (coleta vs. preview+aceite); se o agente sentir que não cabe em sessão única, escala ao PO antes de inflar — mesma régua de STORY-016 da W24. **STORY-034** entrou no escopo em 2026-05-30 (ver §Mudanças no escopo); na mesma data, depois de confirmar 5 gaps no GCE worker-vm, a escada Fase A foi descartada — vai direto para Fase B (Cloud Run Job + Scheduler), e **STORY-021 ficou formalmente `blocked` por STORY-034** até o worker novo estar de pé em homolog. É M porque toda a fiação (Direct VPC egress + `secret_env_vars` + `volumes.cloud_sql_instance`) já está provada pelo job `turni-migrate-homolog` (IDR-007) e pelo `cloud_run_api`. **STORY-037** entrou no escopo em 2026-05-30 (mesmo dia, ver §Mudanças no escopo): sem o consumidor do `version.json` no Flutter Web, a homologação pelo celular é **impossível** — qualquer release publicada fica pinada no dispositivo sem hard-reload manual, descaracterizando a validação mobile do EPIC-001 (STORY-021/023/024/025 só seriam testáveis pelo desktop). É M porque a infra do servidor já está pronta (`/version.json` publicado por IDR-002 + STORY-007; header `no-cache` em `firebase.json`; manifest e SW padrão por STORY-008 CA-11/12) — sobra apenas o lado cliente: polling + `SKIP_WAITING` + banner + label de versão em 3 telas. Diretriz já decidida em ADR-001 §"Auto-atualização do WebApp" (linhas 130-133) — STORY-037 implementa fielmente, não inventa.

**Sem estória stretch nesta sprint.** Justificativa: o objetivo é fechar EPIC-001 limpo; ampliar escopo introduz risco de o validador encontrar trabalho não previsto e abrir cauda. STORY-034 e STORY-037 foram absorvidas no escopo (não como stretch) por **destravarem fechamento do EPIC-001**: 034 destrava STORY-021 (worker), 037 destrava validação mobile do funil de identidade (sem auto-update, releases ficam invisíveis no celular). Se a velocidade da W25 surpreender (similar ao trio 019/020/022 da W24), o PO **não** puxa nada novo — usa o ganho para abrir SPRINT-2026-W26 com folga sobre EPIC-002.

## Ordem de execução obrigatória (dependências do EPIC-001)

```
                                                  ┌──► STORY-023 (completar PF) ─────────────┐
                                                  │                                          │
W24 entregue (012-020, 022)  ────────────────────►┼──► STORY-024 (completar PJ) ─────────────┤── (4/4 done) ──► STORY-025 (validação) ──► EPIC-001 done
                                                  │                                          │
                                                  ├──► STORY-034 (worker Cloud Run Job) ──► STORY-021 (e-mails) ──┘
                                                  │     [PRIORIDADE — destrava 021]              ▲ blocked até 034 done
                                                  │
                                                  └──► STORY-037 (auto-update WebApp) ── [paralelo, sem blocked_by]
                                                        [destrava validação mobile do funil]
```

**Justificativa da ordem**: respeita os `blocked_by` registrados no `index.json`. **STORY-021 ficou formalmente `blocked` por STORY-034** em 2026-05-30 (decisão PO — ver §Mudanças no escopo) após a confirmação dos 5 gaps no GCE worker-vm e a queda da escada Fase A. **STORY-037** entra em paralelo no dia 0 (sem `blocked_by`) porque destrava a validação mobile do EPIC-001 inteiro — sem ela, o smoke pelo celular do PO não é possível.

- **STORY-034** não tem `blocked_by`: toda a fiação (cloud-run, secrets, cloud-sql privado, IAM) já existe na `main`. **Entra no dia 0 com prioridade máxima** — destrava 021 (e por consequência 022/025).
- **STORY-037** não tem `blocked_by`: infra do servidor (`version.json` + header `no-cache` + SW padrão do Flutter) já é viva desde STORY-007/008. Entra em paralelo desde o dia 0 — sessão distinta do programador.
- **STORY-021** depende de 014 (ADR-011), 016 (RBAC), 019 (fila — dispatch já enfileirado) **+ STORY-034** (worker funcional para CA-13). As 3 primeiras estão `done` na W24; a quarta é dia 0–2 da W25. CAs 1–12, 14 podem ser concluídas localmente em paralelo; CA-13 só fecha após STORY-034 `done`. Status atual: `blocked`.
- **STORY-023** depende de 012/013/015/016/017/019/020/022. Todas `done` na W24. Pode entrar no dia 1.
- **STORY-024** depende de 012/013/015/016/018/019/020/022. Todas `done` na W24. Pode entrar no dia 1.
- **STORY-025** depende de todas as anteriores do épico (012–024) **mais STORY-034**. Só inicia quando 021+023+024+034 estiverem `done` — não há ginástica que pule essa porta (lição direta da STORY-011: validador pré-deploy é teatro).

**Paralelismo legítimo**:
- 023/024/034/037 em sessões distintas do programador desde o dia 0. STORY-021 segue em paralelo só no que **não** depende do worker (CAs 1–12, 14); CA-13 fica aguardando 034 `done`.
- Designer entrega 3 screen specs (SCREEN-021, SCREEN-023, SCREEN-024) em paralelo. STORY-034 **não requer design** (infra puro). STORY-037 **requer design leve** (banner discreto + label de versão em 4 telas) — coberto pelos tokens DDR-001 existentes, sem screen spec dedicada (sync ≤15 min entre Designer e Programador é suficiente).
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
| **STORY-034 é caminho único após queda da escada A** — qualquer falha empurra STORY-021/022/025 em cadeia | média | alto se acontecer | Soft-cap 2026-06-19 absorve com folga (~3 semanas); módulo `worker-vm` permanece no repo desabilitado para reversão emergencial; IDR-016 documenta gaps e decisão; PO acompanha 034 desde o dia 0 | Programador + PO |
| **STORY-034 primeiro `--stop-when-empty` + cron 1 min em Cloud Run Job** — primeira execução pode ter surpresa | média | médio | Reusa fiação 100% provada (`turni-migrate-homolog` IDR-007 + `cloud_run_api` `secret_env_vars`); CA-6 (smoke E2E) é critério explícito; Cloud Logging pega qualquer erro de execução; pausa do Scheduler é o kill-switch (CA-7 §runbook) | Programador |
| **Drift no `sql-scheduler` após remoção do worker GCE** — módulo ainda referencia `worker_instance_name`/`worker_zone` | baixa | baixo | CA-4 da STORY-034 exige `terraform plan` sem drift após remoção; revisão do plan no PR | Programador |
| **STORY-021 com CA-13 reaberta após destravo** — programador pode pular E2E pelo cansaço da espera | baixa | médio | PO marca explicitamente "validar CA-13 ao destravar 021" como passo de check de qualidade; sem isso, 021 não vai para `in_review` | PO |
| **STORY-037 banner percebido como intrusivo no mobile** — primeira vez exibindo notificação não-bloqueante em homolog | baixa | baixo | Microcopy fixo aprovado pelo PO ("Nova versão disponível"/"Atualizar agora"/"Depois"); IDR-017 prevê redução de frequência ou troca por badge silencioso como sinal de revisão; smoke CA-17 pelo PO no celular é o gate | Programador + PO |
| **STORY-037 SKIP_WAITING + reload invalida sessão Sanctum** — regressão em ADR-007 §F5 | baixa | alto se acontecer | CA-6 explícita exige que sessão sobreviva ao reload; E2E (login → forçar update → ver tela logada de novo) é critério de pronto; cookie same-site `app.homolog.turni.com.br` (já em produção) cobre o caso | Programador |

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
| 2026-05-30 | **STORY-034 colapsada para Fase B único** (escada Fase A descartada); **STORY-021 movida de `in_progress` → `blocked` por STORY-034** | Investigação aprofundada do programador revelou **5 gaps** no GCE worker-vm, não apenas 2: (1) sem socket Cloud SQL; (2) sem segredos no `docker run`; (3) **sem Cloud NAT** — VM sem IP público não tem egress para Artifact Registry / Docker Hub / Resend; (4) SA da VM sem `roles/artifactregistry.reader` (no Cloud Run quem puxa imagem é o Cloud Run Service Agent, e por isso o `cloud_run_api` roda hoje sem essa permissão); (5) `/root` read-only no COS limita tmpfs+env-file. Os gaps 3–5 **invalidaram a escada Fase A** — cobri-los exigiria Cloud NAT permanente (módulo Terraform que não desaparece com a VM) + IAM extra + workaround do COS, todo descartável quando a VM sair. Fase B (Cloud Run Job + Scheduler) elimina os 5 gaps de uma vez reusando IDR-007 + padrão de `secret_env_vars` do `cloud_run_api`. PO decidiu **bloquear STORY-021 formalmente até STORY-034 entregar** — sem trabalho-ponte. Aprovação: chat 2026-05-30 (Arquiteto + PO). | Custo de calendário: STORY-021 não fecha até STORY-034 `done` (estimativa: dia 0–2). Soft-cap 2026-06-19 absorve com folga. Nenhuma mudança no sizing total (continua 1L + 4M). STORY-034 fica como caminho único — sem fallback além da reversão para o módulo `worker-vm` (mantido no repo desabilitado). |
| 2026-05-30 | **+ STORY-037** (auto-atualização do WebApp Flutter + versão visível na UI) entra no escopo da W25 | Reportado pelo PO em chat: acessar `https://app.homolog.turni.com.br` pelo browser do mobile **nunca atualiza** o app após uma nova release — bundle Flutter Web + service worker padrão ficam pinados no dispositivo, e o usuário comum não faz hard-reload. **Sem isso, a homologação pelo celular é impossível** — STORY-021/023/024/025 só seriam testáveis pelo desktop, descaracterizando a métrica primária do EPIC-001 que assume uso real pelo usuário (mobile-first). Diretriz já decidida em **ADR-001 §"Auto-atualização do WebApp"** (linhas 130-133), aprovada por Alexandro em 2026-05-27 — STORY-037 só implementa fielmente: polling do `version.json` (já publicado por IDR-002 + STORY-007), banner "Nova versão disponível", `SKIP_WAITING` + reload, e label discreta de versão no rodapé das telas de login, cadastro PF, cadastro contratante e área logada (`app_shell`). Risco já registrado em STORY-001 §Riscos linha 159 ("padrão definido, precisa ser implementado fielmente"). Vira IDR-017, sem reabrir ADR. Aprovação: chat 2026-05-30 (PO Alexandro). | Sizing total da sprint: 1L + 4M → **1L + 5M**. Sem `blocked_by` — toda a infra do servidor já é viva (`version.json` publicado, header `no-cache` em `firebase.json`, manifest + SW padrão por STORY-008). Não desloca nenhuma estória do escopo confirmado; entra como sessão separada do programador. Trade-off aceito: o sprint amplia em uma estória M mas remove o bloqueio operacional que invalidaria a validação mobile do EPIC-001. |
| 2026-05-31 | **STORY-037 → done** (rc.31→rc.32; PO confirmou auto-update no celular após fix CA-17 em cache `immutable` + SW iOS) | Entregue conforme escopo: polling do `version.json`, banner discreto "Nova versão disponível"/"Atualizar agora"/"Depois", `SKIP_WAITING` + reload preservando sessão Sanctum (CA-6 verde), label de versão nas 4 telas. IDR-017 `accepted`. | Progresso D+1: **3/6 done** (021/034/037), 3/6 ready (023/024/025). |
| 2026-05-31 | **STORY-023 commitada como `done` (commit `3b61364`) e em seguida revertida byte-a-byte para `ready` (commit `690a252`)**; **STORY-024 (untracked no working tree) descartada**. Decisão PO: refazer do zero. | Após o PO percorrer o fluxo recém-commitado de STORY-023 (multi-step PF + preview de contrato em MarkdownLite + AceiteEletronico no clique), avaliação foi de que o resultado não atendia ao padrão pretendido para ser a primeira escrita real sobre a infra de Template/Versao/Aceite. Decisão: rollback completo e retomar com escopo limpo. **Preservado** (não é 023/024): fixes de homolog `SESSION_COOKIE`/`SESSION_DRIVER` (commits `4985e58`/`c6ffba5`) + IDR-019 (arquivo); `infra/` e `.github/` intactos; trabalho de processo do commit `4cb0b38` (wishlist + bugs + EPIC-008 PWA + endurecimento de skills). **Removido**: `Domain/Aceites/*`, `Http/Controllers/Usuario/CompletarCadastroController`, modelos `Template`/`TemplateVersao`/`AceiteEletronico`, migração `2026_05_30_completar_cadastro_profissional_e_aceites.php`, telas `completar_cadastro_screen.dart` + `cadastro_widgets`/`input_formatters` da PF, E2E `completar-cadastro.spec.ts`, `MarkdownLite`. Router/auth_service voltam ao placeholder. Aprovação: PO em chat 2026-05-31. | Sem mudança de escopo formal: STORY-023 e STORY-024 permanecem `ready` no escopo da W25, com mesmo sizing (1L + M). Custo de calendário: ~1 dia útil queimado em código que volta a zero — absorvível dentro do soft-cap 2026-06-19. Pendência operacional: reindexar `index.json` na seção `decisions.idr` (IDR-018/019/020 ainda fora do JSON; IDR-019 é a única efetivamente impactada pelo rollback — segue como arquivo). Sem impacto em STORY-021/034/037 (continuam `done`) nem em STORY-025 (continua `ready` aguardando 023/024). |

## Aprendizados em curso (mid-sprint)

> Para registrar conforme acontecem; consolidados na seção "Fechamento do sprint" no fim.

### Snapshot 2026-05-30 (D+0/D+1) — progresso parcial

- **Done (2/6)**: STORY-034 (worker Cloud Run Job + Scheduler) e STORY-021 (e-mails transacionais, CA-13 fechada em homolog com falha terminal real validada via alerta na rc.28).
- **Ready (4/6)**: STORY-023, STORY-024, STORY-037, STORY-025 (esta última segue dependente de 023/024 — sem mudança).
- **Velocidade**: 2 estórias M em ~1 dia útil, repetindo o padrão acelerado das W22/W23/W24. STORY-034 destravou STORY-021 conforme planejado; pré-cadastro→aprovação→welcome→e-mail real percorrido fim a fim em homolog.
- **Próximo gargalo**: design das SCREEN-023/024 e Designer/Programador entrando em dupla na sessão de STORY-023 (L). STORY-037 entra em paralelo (sem `blocked_by`).

### Snapshot 2026-05-31 (D+1/D+2) — pós-rollback de 023/024

- **Done (3/6)**: STORY-021, STORY-034, **STORY-037** (auto-update WebApp + label de versão, fechado em rc.32 com PO confirmando no celular; IDR-017 `accepted`).
- **Ready (3/6)**: **STORY-023**, **STORY-024** (ambas voltaram a `ready` após rollback byte-a-byte do trabalho da 023 e descarte da 024 untracked — decisão PO de refazer do zero); STORY-025 (segue aguardando 023/024).
- **Reset técnico verificado**: working tree limpo na `main`; nenhum resíduo de `Domain/Aceites`, controllers, modelos `Template/TemplateVersao/AceiteEletronico` ou migrations no `apps/api/`; nenhuma tela de completar-cadastro no `apps/webapp/lib/features/funnel/` além do placeholder; router e auth_service no estado pré-023. 3 commits locais ainda não pushados para `origin/main` (`4cb0b38` processo, `690a252` revert, `fd30cc2` `.claude/` ignorado).
- **Preservado**: STORY-021/034/037 inteiras; fixes `SESSION_COOKIE`/`SESSION_DRIVER` (IDR-019); ACL e-mail em `packages/domain` (IDR-015); welcome screen real (STORY-022). Spec da estória, screen spec (`SCREEN-STORY-023-completar-cadastro-profissional.md`) e seções `non-functional.md` correlatas voltaram ao estado pré-implementação — ponto de partida para a retomada.
- **Pendência de housekeeping (não bloqueia retomada)**: `decisions.idr` em `index.json` está desatualizado — IDR-010/011/013/015/018/019/020 existem como `.md` mas não estão no JSON. PO marcou como tarefa de reindexação separada no commit `690a252`.
- **Próximo passo**: retomar STORY-023 do zero, sem reproduzir mecânicas descartadas; STORY-024 entra em paralelo no mesmo critério. Designer pode reutilizar SCREEN-STORY-023 já entregue (preservada pelo revert). PO escolhe se a retomada começa por uma sub-estória menor (coleta multi-step antes de preview+aceite) ou se mantém o L original.

## Fechamento do sprint

**Encerrado em 2026-06-01 — `goal_outcome: achieved`** (3 dias corridos vs. soft-cap 21d; ~18d antes do gatilho de reavaliação).

### O que foi entregue

**6/6 estórias do escopo confirmado em `done`** (1L + 5M — sizing total respeitado):

- **STORY-021** (M) — E-mails transacionais ao vivo em homolog: `aprovacao_concedida`, `lembrete_completar_cadastro` (gatilhos 48h/5d/14d, máx 3 lembretes), `recuperacao_senha`. SPF/DKIM/DMARC aplicados via Terraform e verificados (runbook §e-mail). CA-13 destravada após STORY-034 ficar `done`. Done em 2026-05-30 (rc.28).
- **STORY-023** (L) — Fluxo multi-step de completar cadastro de Profissional no WebApp + preview de contrato + AceiteEletronico imutável atômico. PO confirmou ao vivo na rc.41 em 2026-06-01 após o rollback byte-a-byte de 2026-05-31 e a retomada do zero. Casts `encrypted` (CPF/CNPJ, chave Pix), `DocumentoValidator` 97%, `ChavePixValidator` 100%, `AceiteAdesaoRenderer` 100%.
- **STORY-024** (M) — Fluxo multi-step do Contratante (wizard 3 passos + revisão/aceite, tema mostarda), seed real de `termos_plataforma_contratante`, busca CEP via ViaCEP fail-soft (`CepLookup` 100%, IDR-024), template próprio do contratante (IDR-023), métrica + alerta de cadastros completados. PO validou ao vivo no mobile na rc.42 em 2026-06-01.
- **STORY-025** (M, validation) — Validador percorreu o checklist do EPIC-001 contra commit `0e1e4068…` (rc.42) e emitiu veredito **`approved_with_pending`** em `epics/EPIC-001-cadastro-e-aprovacao/validation/report.md`. **Zero fails bloqueantes**. PO aceitou em 2026-06-01 e marcou EPIC-001 como `done`. Evidências em `validation/evidence/` (cobertura api/admin/webapp, E2E local, Lighthouse a11y).
- **STORY-034** (M) — Worker em Cloud Run Job + Cloud Scheduler 1/min ENABLED substituiu o GCE `worker-vm` (Fase B colapsada após queda da escada Fase A em D+0). IDR-016 `accepted`. Reusou 100% da fiação de `turni-migrate-homolog` (IDR-007) + `secret_env_vars` do `cloud_run_api`. Destravou STORY-021 CA-13 conforme planejado. Done em 2026-05-30.
- **STORY-037** (M) — Auto-atualização do WebApp Flutter (polling do `version.json` + banner discreto "Nova versão disponível"/"Atualizar agora"/"Depois" + `SKIP_WAITING` + reload preservando sessão Sanctum) + label de versão nas 4 telas. CA-17 fechada com fix em cache `immutable` + SW iOS. PO confirmou no celular. IDR-017 `accepted`. Done em 2026-05-31 (rc.32).

**EPIC-001 fechado**: cadastro → aprovação → completar → ativo com AceiteEletronico imutável vivo em homolog. RBAC vivo nas duas interfaces. PDR-012 central (aceite mantém versão original após nova ativação de template) comprovado por teste CA-16 contra Postgres real. Audit log e aceite imutáveis por trigger Postgres + REVOKE. Observabilidade: métricas RED + 3 políticas de alerta ENABLED. Acessibilidade amostrada (admin /login Lighthouse 100; WebApp /login 88, /cadastro 92).

### O que ficou para trás (e por quê)

**Carry-forward sob gestão do PO** (não entram na W26 como estória — viram pendências do EPIC-001 monitoradas pelo PO conforme decisão registrada em `validation/report.md` Histórico 2026-06-01):

- **F-NB-1 (não-bloqueante)** — Alerta dedicado a "cadastro pendente > 20h / risco de SLA" não observado em homolog (3 políticas ENABLED cobrem falha de e-mail crítico, indisponível e taxa de erro 5xx; SLA>20h ausente). Lacuna de observabilidade.
- **Verificações vivas não percorridas pelo Validador** (decisão de escopo da sessão, não falha): cronometragem exata da métrica primária (≤5min usuário / ≤30s admin — PO validou ao vivo o caminho funcional); flags do cookie de sessão autenticada (httpOnly/Secure/SameSite); entrega real de e-mail em inbox de provedor (render testado); lista LGPD de dados pessoais (documento não localizado nesta sessão); env efetivo de Argon2id em homolog (`.env.example` ok); RBAC cross-host ao vivo; indicador SLA WCAG; foto signed URL não enumerável.
- **Passes com ressalva carregados**: webapp cobertura 76,8% app-inteiro (< 80%, sem gate — código novo do épico coberto por 121 widget tests + integration_test); `DocumentoValidator` 97% (< 98% do alvo de núcleo); CI não roda testes/cobertura/E2E (gates locais por IDR-004 — verificação local executada verde); admin Cloud Run cold start (1ª chamada 502 antes de estabilizar em 200).
- **Decisão pendente do PO sobre F-NB-2 (HASH_DRIVER no admin)** — herdada da W24, não fechada nesta sprint. Tratada como `pass com ressalva` (CA-5-3).
- **Pendência de housekeeping**: `decisions.idr` no `index.json` ficou desatualizado em alguns IDRs (010/011/013/015/018/019/020 existem como `.md` — registrado no fechamento da W26 anterior; PO marcou como tarefa de reindexação separada).

### Aprendizados

1. **Rollback byte-a-byte em D+1 é decisão de PO saudável quando o resultado não atende ao padrão pretendido** (STORY-023 commitada como `done` no `3b61364` e revertida no `690a252`, STORY-024 untracked descartada). Custo: ~1 dia útil queimado, absorvido pelo soft-cap. Ganho: a retomada do zero produziu o fluxo que o PO aprovou ao vivo (rc.41/rc.42) — código que ele teria que conviver pelos próximos meses não ficou abaixo da linha. **Régua para futuro**: PO percorrer o fluxo ao vivo em rc.* **antes** de aceitar `done`, não depois.
2. **Escada A→B no mesmo sprint cai quando os gaps se revelam estruturais** (STORY-034: 5 gaps no GCE worker-vm — 3 dos quais exigiriam infra descartável; escada virou caminho único Fase B com STORY-021 formalmente `blocked`). Régua: ao primeiro gap descobrir-se estrutural (não cosmético), colapsar a escada antes de investir em código-ponte que vai morrer.
3. **Validador como sessão separada funcionou** (regra nova 6 da W25): o veredito `approved_with_pending` saiu como fato + classificação, sem deslizar para planejamento. PO recebeu o relatório e decidiu o tratamento das pendências como ato distinto, sem contaminar a produção do veredito — repetição do aprendizado da STORY-011 em ambiente mais carregado (épico inteiro, não estória única).
4. **Decisão "AceiteEletronico só nasce no clique de Aceito e concluir cadastro" sobreviveu à primeira escrita real** (PDR-012 central comprovado por teste CA-16 contra Postgres real — aceite mantém versão original após admin ativar nova versão). A infra de Template/Versao/Aceite entregue na W24 como leitura passou no teste de uso de escrita sem retrabalho de fundação — sinal de que o sequenciamento (definir → exercitar leitura → exercitar escrita) protegeu o épico.
5. **Auto-update do WebApp em homolog é pré-condição da métrica mobile-first** (STORY-037): sem ele, qualquer release fica pinada no celular do PO e descaracteriza a validação primária do EPIC-001. Régua: nas próximas waves, qualquer estória que dependa de validação mobile do PO entra com `blocked_by` no auto-update vivo. ADR-001 §Auto-atualização do WebApp continua sendo o contrato.
6. **6 estórias em 3 dias com 1 rollback no meio** repete o padrão acelerado das W22/W23/W24 — capacidade calibrada de **~2 estórias M/dia** com dupla Designer+Programador na mesma sessão e ADRs estruturantes já aceitas. PO continua não puxando escopo extra ao perceber folga — usa o ganho para abrir W26 com gordura em vez de afogar a sprint corrente (decisão repetida em W22, W23, W24 e W25 = padrão consolidado).

### Ajustes para o próximo sprint

- **Sprint W26 já foi aberta e fechada em 2026-06-01** (re-escopada Web-only): EPIC-007 entregue na parte Web (STORY-038 + STORY-043 done, IDR-010/011 aceitas, IDR-006 §b anotada). STORY-039/040 (Patrol/mobile) de-escopadas para EPIC-009 (backlog). **Sprint seguinte** (a abrir): EPIC-002 (vaga + feed + candidatura).
- **EPIC-002 começa após este encerramento** — `approved_with_pending` aceito pelo PO assume goal-atingido do EPIC-001; nenhuma pendência de carry-forward bloqueia a abertura do EPIC-002.
- **Régua nova para sprint do EPIC-002**: o PO percorre o fluxo ao vivo em rc.* **antes** de aceitar `done` na estória (lição #1). Critério de pronto da estória de implementação ganha a linha explícita "PO percorreu o fluxo em rc.N" como evidência separada do "código + testes verdes".
- **Carry-forward F-NB-1** (alerta SLA>20h) entra na lista de pendências do PO e é endereçado em sprint dedicado à observabilidade ou colado a uma estória de EPIC-002 que toque o mesmo módulo de monitoring — decisão do PO ao abrir o EPIC-002.
- **Reindexação do `index.json`** (IDRs 010/011/013/015/018/019/020 fora do JSON) entra na lista de housekeeping do PO — não precisa de sprint dedicada.
- **Pendência F-NB-2 (HASH_DRIVER no admin)** continua na fila do PO; pode ser fechada em qualquer sprint subsequente sem custo de escopo.
