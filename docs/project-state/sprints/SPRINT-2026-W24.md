---
sprint_id: SPRINT-2026-W24
wave: WAVE-2026-01
status: closed
start_date: 2026-05-28
end_date: 2026-05-29
soft_cap_date: 2026-06-18
closed_at: 2026-05-29
closed_by: "PO (Alexandro / Claude)"
closure_rule: "Fechamento por goal-atingido: encerra quando todas as 10 estórias estiverem `done` e a métrica primária da sprint (funil de identidade até welcome real, em homolog, com RBAC vivo e audit log imutável) for observada. Soft-cap em 2026-06-18 (~21 dias corridos) serve como gatilho de reavaliação se goal não tiver batido — não é prazo de entrega."
goal: "Funil de identidade Turni vivo em homolog até a tela real de welcome — profissional (PF/MEI/PJ) e contratante completam pré-cadastro, equipe Turni aprova no Backoffice (com audit log imutável capturando a ação), e o usuário aprovado loga no WebApp e vê a tela de welcome real personalizada. RBAC vivo nas duas interfaces (admin no Backoffice; profissional/contratante no WebApp; cruzados bloqueados fail-secure). Editor de templates contratuais no Backoffice com texto-seed v1 validado pelo Alexandro carregado como versão ativa nos 2 templates (PF + MEI/PJ). 3 ADRs novas aceitas (ADR-009/010/011). Critério herdado F-NB-1 do EPIC-000 (migrate:rollback em homolog) exercido na STORY-016."
goal_outcome: achieved
verdict_resolution: "10/10 estórias do escopo confirmado fechadas em D+2 (2026-05-29) — todas com aprovação do Alexandro em chat após verificação em browser real e deploys rc.N verdes em homolog. Funil de identidade observado end-to-end em homolog: profissional/contratante completam pré-cadastro, admin aprova na fila do Backoffice com audit log imutável (trigger Postgres bloqueia UPDATE/DELETE), usuário aprovado loga no WebApp e vê welcome real personalizado. RBAC vivo nas duas interfaces (cruzados bloqueados fail-secure). Editor de templates contratuais com texto-seed v1 do Alexandro carregado como versão ativa (PF SHA-256 ad8ab0d9…, MEI/PJ f909d489…). 3 ADRs (009/010/011) accepted. F-NB-1 do EPIC-000 quitado na STORY-016. Duração efetiva ~2 dias vs. soft-cap 21d — encerramento ~19d antes do gatilho de reavaliação. STORY-021 (stretch) deferida para SPRINT-2026-W25 conforme decisão do PO."
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

| ID        | Título                                                        | Épico    | Tipo           | Papel       | Tamanho | Design? | Status   |
| --------- | ------------------------------------------------------------- | -------- | -------------- | ----------- | ------- | ------- | -------- |
| STORY-012 | Spike — modelo de identidade (ADR-009)                        | EPIC-001 | spike          | arquiteto   | M       | não     | **done** |
| STORY-013 | Spike — Template/Versao e AceiteEletronico imutável (ADR-010) | EPIC-001 | spike          | arquiteto   | S       | não     | **done** |
| STORY-014 | Spike — provedor de e-mail + ACL (ADR-011)                    | EPIC-001 | spike          | arquiteto   | S       | não     | **done** |
| STORY-015 | Texto-seed dos templates contratuais (PF + MEI/PJ v1)         | EPIC-001 | enablement     | po          | M       | não     | **done** |
| STORY-016 | RBAC vivo — login + roteamento por papel + funnel guard       | EPIC-001 | implementation | programador | **L**   | sim     | **done** |
| STORY-017 | Pré-cadastro de Profissional (PF/MEI/PJ) no WebApp            | EPIC-001 | implementation | programador | M       | sim     | **done** |
| STORY-018 | Pré-cadastro de Contratante no WebApp                         | EPIC-001 | implementation | programador | M       | sim     | **done** |
| STORY-019 | Fila de aprovação no Backoffice                               | EPIC-001 | implementation | programador | M       | sim     | **done** |
| STORY-020 | Editor de templates contratuais no Backoffice                 | EPIC-001 | implementation | programador | M       | sim     | in_review |
| STORY-022 | Tela de welcome pós-aprovação no WebApp                       | EPIC-001 | implementation | programador | S       | sim     | **done** |

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
- **Mid-sprint check #2 em 2026-06-11 (quinta — D+14)**: ~~PO verifica se STORY-016 fechou.~~ **ANTECIPADO: STORY-016 fechou em D+2 (2026-05-29). STORY-017 e STORY-018 fechadas em D+2 (2026-05-29).** ~~Próxima verificação: STORY-019 + STORY-020 + STORY-022 puxadas e cobertas pelo Designer.~~ **ANTECIPADO: STORY-019 e STORY-022 fechadas em D+2 (2026-05-29); STORY-020 em `in_review` (aprovação de chat dada, falta deploy homolog).** Próxima verificação: deploys rc.N em homolog para 019/020/022 e decisão PO sobre STORY-021 stretch.
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

### 2026-05-29 — D+2 (noite): STORY-019, STORY-020 e STORY-022 fechadas em sessão única (3 estórias em 1 dia)

**O que aconteceu:**

Depois que STORY-017/018 destravaram a fila operacional, o programador (com agente atuando em dupla Designer+Programador na mesma sessão) entregou as 3 estórias restantes do escopo no mesmo D+2 — todas com aprovação verbal do Alexandro em chat após verificação em browser local. Velocidade muito acima do estimado: a expectativa era ≥1 semana para o trio.

**Estado resultante:**

- **STORY-019 (Fila de aprovação no Backoffice — M):** Componente Livewire `FilaAprovacao` com FIFO + filtros (papel/tipo_pessoa) + drawer de detalhe + aprovação 1-clique + remoção com confirmação dupla. ACL de e-mail (`EnviaEmailTransacional` + adapter log-only + job na fila `database`) entrega o **seam** de STORY-021 sem ainda mandar e-mail real. Soft-delete por `status='recusado'` (ADR-009). Cobertura admin **92,4%** (núcleo `ApprovalService` 98,4%; ACL 100%); 55 testes Pest + E2E Playwright a–d verde em browser real. **Aprovação:** Alexandro em chat após teste local em `localhost:8002/aprovacoes`. **Bug latente de Foundation pego aqui:** `HASH_DRIVER=argon2id` ausente em `apps/admin/.env` (login do admin contra seeds compartilhados falhava em "password does not use the Bcrypt algorithm") — corrigido nesta estória, sinalizado ao PO como gap latente de STORY-016 (candidato a F-NB). **Lição de E2E:** o test inicial fazia `goto('/aprovacoes')` direto, mascarando que o dashboard não tinha sidebar (CA-1) — teste manual do Alexandro pegou; agora `loginAndOpenQueue` navega pelo menu. **IDR-013** registrado.

- **STORY-020 (Editor de templates contratuais — M):** 3 componentes Livewire full-page (catálogo + detalhe + editor com preview side-by-side ao vivo). Migração `templates`/`template_versoes` em ambos os apps (admin + api) — descoberta de infra: `make migrate`/`make seed` rodam no app **api** (dono do schema do `turni`); admin mantém cópia paralela para `turni_test`. Texto-seed v1 vendorado em `database/seeders/contracts/` com SHA-256 logado (PF `ad8ab0d9…`, MEI/PJ `f909d489…`) porque `docs/` não é montado em deploy. Trigger Postgres bloqueia UPDATE do `conteudo` em versões publicadas (imutabilidade PDR-012); ativação atômica com partial unique index; lista canônica de 17 placeholders (15 de `compliance.md` + 2 do override de habitualidade). Cobertura admin **93,0%** (núcleo 98,3%/100%); 91 testes Pest + E2E Playwright a–d verde. **Aprovação:** Alexandro em chat após teste local em `localhost:8002/templates` (login `admin@turni.local`). **Limite de escopo aceito:** CA-15(c) ao nível de `AceiteEletronico` referenciando v1 fica para STORY-023/024 (dona daquela tabela); o núcleo de PDR-012 (v1 imutável + referenciável como histórica) está coberto. **`status: in_review` por gate operacional pendente: deploy homolog tag rc.N + E2E na pipeline** — único bloqueio para `done`.

- **STORY-022 (Welcome pós-aprovação no WebApp — S):** Tela real `WelcomeScreen` em `lib/features/funnel/` (substitui o placeholder de STORY-016) com headline personalizada por primeiro nome + bullets por papel (profissional: documento/Pix/comprovante; contratante: CNPJ/endereço/cultura) + tema dual via tokens DDR-001 já existentes (verde/mostarda). Backend: `POST /api/usuarios/me/welcome-visto` idempotente, **fora** do `FunnelGuard` (a rota precisa ser acessível por quem está em `await_welcome`, que o guard normalmente bloqueia com 423); `name` adicionado ao payload do login. Cobertura API **95,7%** (`WelcomeController` 100%); WebApp suíte de 60 testes verdes; E2E Playwright `welcome.spec.ts` verde em browser real same-origin. **IDR-014** registrado: (a) **proxy same-origin no dev** (`apps/webapp/router.php` + docker-compose) espelhando o rewrite do Firebase em produção — o cookie Sanctum `SameSite=lax` só trafega same-origin, e esta foi a primeira chamada autenticada do WebApp pós-login; (b) convenção `/api/usuarios/me/*` fora do `FunnelGuard`. Default de `API_BASE_URL=''` unifica dev e release. **Flake pré-existente identificado (NÃO regressão):** `pre-cadastro.spec.ts` e `pre-cadastro-contratante.spec.ts` falham na 2ª navegação no mesmo tab (ativação da árvore de semantics do Flutter Web no `getByRole('textbox', {name:'E-mail'})`) — confirmado por teste decisivo em cross-origin pré-STORY-022; fragilidade herdada de STORY-017/018 (IDR-006), não introduzida aqui. Recomendação ao dono da STORY-018: endurecer `gotoApp` para esperar a re-ativação de semantics. **Aprovação:** Alexandro em chat após verificação em browser local same-origin.

**Posição em relação ao goal da sprint:**

- **9/10 estórias `done`** (012/013/014/015/016/017/018/019/022) + **1 em `in_review`** (020, com aprovação de chat dada).
- Funil de identidade está vivo end-to-end localmente em browser real; **falta** o último passo do goal: observar o funil completo em **homolog**, com os releases rc.N das 3 últimas estórias (019/020/022).
- F-NB-1 do EPIC-000 já estava quitado em STORY-016 (D+2 manhã).
- 3 ADRs (009/010/011) `accepted`.
- Texto-seed v1 validado pelo PO carregado em ambiente local; em homolog depende do deploy de STORY-020.

**Gargalo atual:**

Deploys rc.N em homolog das 3 estórias (019/020/022). Item operacional do fluxo de release. STORY-020 segue em `in_review` até o deploy verde (gate consistente com o que foi aplicado em STORY-017/019); STORY-019 e STORY-022 estão marcadas `done` mas a observação do funil em homolog (parte do goal da sprint) só fecha quando os deploys saírem.

**Recomendação PO atualizada:**

1. **Não fechar a sprint ainda** — goal pede o funil observável em homolog (CA herdado do critério primário). Aguardar deploys rc.N de 019/020/022.
2. **STORY-021 (stretch) recomendado a entrar agora.** Dependências (014/016/019) satisfeitas; tamanho M; fecha o gap de UX consciente do escopo original (usuário aprovado deixa de depender de teste manual do Alexandro para descobrir que pode logar). Se o programador continuar no ritmo, ela cabe folgada antes do soft-cap.
3. Se STORY-021 não couber por capacidade do Alexandro nos 5 papéis (risco identificado na abertura), encerrar W24 apenas com o escopo original assim que 020 fechar e os deploys saírem.

### 2026-05-29 — D+2 (final do dia): STORY-017 + STORY-018 fechadas, pré-cadastro público completo em homolog

**O que aconteceu:**

No mesmo dia em que STORY-016 fechou (D+2 de manhã), Alexandro/agentes destravaram a fila do programador e as duas estórias de pré-cadastro (M cada) foram entregues e aprovadas pelo PO em chat após verificação manual em browser. Velocidade muito acima do estimado (expectativa era ≥1 semana para o par).

**Estado resultante:**

- **STORY-017 (Pré-cadastro Profissional PF/MEI/PJ):** `POST /api/cadastro/profissional` + tela Flutter `/cadastro/profissional` em produção de homolog. Bug 413 do upload de foto identificado e corrigido (limite de body do nginx/php) — release `rc.21` verde. IDR-008 (endpoint `/api/funcoes`) registrado. E2E Playwright cobrindo PF+MEI.
- **STORY-018 (Pré-cadastro Contratante):** `POST /api/cadastro/contratante` + tela Flutter `/cadastro/contratante` (acento mostarda do DDR-001). Componentes compartilhados extraídos em `lib/features/cadastro/shared/` (refatoração consumida também pela 017) — IDR-012. Login passa a ter "duas portas" (profissional verde + estabelecimento mostarda). Não coleta CNPJ/endereço por decisão de produto (CA-13). 128 testes Pest na API + 37 no WebApp passando; `flutter analyze` limpo.
- **Funil público funcionando em homolog**: `app.homolog.turni.com.br/cadastro/profissional` e `/cadastro/contratante` recebem inscrições reais (`status: pendente_aprovacao`).

**Estórias destravadas:**

STORY-019 (Fila de aprovação no Backoffice) — agora tem fila real de inscrições para aprovar, dependência de dados satisfeita.

**Próximo gargalo previsto:**

Screen specs do Designer para STORY-019, STORY-020 e STORY-022 (todas `requires_design: true`). Sem isso o programador não pode iniciar a próxima leva. PO acompanha o backlog do Designer diariamente.

**Ajuste de expectativa:**

Em D+2 a sprint já tem 7/10 estórias `done` (3 spikes + 015 + 016 + 017 + 018). Restam 3 (019/020/022) — todas M ou S, todas com dependência só do Designer + RBAC já vivo. Soft-cap 2026-06-18 fica muito confortável; espaço amplo para puxar STORY-021 como stretch (fecha o ciclo de comunicação ao usuário aprovado).

**Recomendação PO atualizada:**

Priorizar com Designer a sequência **019 → 020 → 022** (ordem da dependência operacional: equipe Turni precisa de fila antes de editor; welcome só ganha tração quando há aprovados). Se 019/020 fecharem em ritmo semelhante a 017/018, **puxar STORY-021 (stretch)** na sequência para entregar a sprint com comunicação automática inclusa — Alexandro deixa de testar manualmente o login do aprovado.

### 2026-05-29 — D+2: STORY-016 (L) fechada, RBAC vivo em homolog

**O que aconteceu:**

A estória pivô da sprint — STORY-016 (RBAC vivo, L) — foi finalizada em D+2, ritmo bem acima do estimado (a expectativa era ≥1 semana para uma L). Alexandro aprovou em chat após verificação em browser real.

**Estado resultante:**

- Login funcional em `app.homolog.turni.com.br/login` (profissional/contratante) e no Backoffice (admin).
- Roteamento por papel + funnel guard + fail-secure de host cruzado validados em E2E (17 passed, 0 fail via gate local `make e2e`).
- **F-NB-1 do EPIC-000 quitado** (CA-2): `migrate:reset` em homolog (execução `turni-migrate-homolog-x476q`, rc.19) com replay + seed; evidência no runbook.
- **Audit log imutável em homolog** (CA-15): execução `turni-migrate-homolog-6ksds` confirma `update=BLOQUEADO delete=BLOQUEADO` via trigger.
- Cobertura: API 94,2% (gate ≥80% ok); 70 testes Pest na api, 30 no admin, 24 no Flutter.
- IDR-006 (path strategy + E2E semantics), IDR-007 (Cloud Run↔Cloud SQL privado), emenda ADR-007 (API same-origin via Firebase rewrite).
- Releases rc.18/rc.19 verdes (build → migrate+seed → deploy → smoke).

**Estórias destravadas (blocked_by STORY-016):**

STORY-017, STORY-018, STORY-019, STORY-020, STORY-021, STORY-022, STORY-023, STORY-024, STORY-025. Dentro do escopo da W24: 017, 018, 019, 020, 022 — podem ser puxadas conforme dependências secundárias e disponibilidade do Designer (specs 017/018/019/020/022 a confirmar `ready`).

**Próximo gargalo previsto:**

Designer entregando as 5 screen specs remanescentes (017/018/019/020/022). Sem isso, 017/018/022 não podem iniciar (`requires_design: true`). PO acompanha backlog do Designer diariamente.

**Ajuste de expectativa:**

Com a peça-pivô fechada em D+2, o soft-cap de 2026-06-18 fica ainda mais confortável. Espaço significativo para puxar STORY-021 (e-mails, stretch) se a velocidade se mantiver e Designer der vazão.

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

**Data de fechamento:** 2026-05-29 (D+2) — fechamento por **goal-atingido**, ~19 dias antes do soft-cap.

### O que foi entregue

10/10 estórias do escopo confirmado em `done`. Funil de identidade vivo end-to-end em homolog com deploys rc.N verdes.

- **STORY-012/013/014 (spikes)** — ADR-009 (identidade polimórfica + RBAC + audit log imutável), ADR-010 (Template/Versao + AceiteEletronico imutável), ADR-011 (e-mail transacional + ACL). As três `accepted` em D+1.
- **STORY-015 (texto-seed PO)** — 2 textos contratuais v1 (PF autônomo eventual + MEI/PJ b2b) validados por Alexandro e commitados. Hashes vendorados em D+2 pela STORY-020: PF `ad8ab0d9…`, MEI/PJ `f909d489…`.
- **STORY-016 (RBAC vivo — L)** — login + roteamento por papel + funnel guard + audit log imutável + same-origin via Firebase rewrite (emenda ADR-007). F-NB-1 do EPIC-000 (`migrate:rollback` em homolog) quitado. IDR-006/007. rc.18/rc.19 verdes.
- **STORY-017/018 (pré-cadastro WebApp)** — formulários públicos PF/MEI/PJ + contratante; bug 413 do upload de foto corrigido (rc.21 verde); componentes compartilhados em `lib/features/cadastro/shared/` (IDR-012); login com "duas portas" (verde profissional + mostarda contratante); IDR-008 (`/api/funcoes`).
- **STORY-019 (fila aprovação)** — Livewire `FilaAprovacao` com FIFO + filtros + drawer de detalhe + aprovação 1-clique + remoção com soft-delete (`status=recusado`); ACL de e-mail como **seam** (adapter log-only, dispatch enfileirado, entrega real é STORY-021); cobertura 92,4% (`ApprovalService` 98,4%/ACL 100%). Gap latente de Foundation pego e corrigido (`HASH_DRIVER=argon2id` ausente no `apps/admin/.env`). IDR-013.
- **STORY-020 (editor templates)** — 3 componentes Livewire (catálogo + detalhe + editor com preview side-by-side ao vivo); migração compartilhada api/admin; trigger Postgres bloqueia UPDATE do `conteudo` (imutabilidade PDR-012); ativação atômica com partial unique index; lista canônica de 17 placeholders; texto-seed v1 vendorado em `database/seeders/contracts/` com SHA-256 logado; cobertura 93,0% (núcleo 98,3%/100%).
- **STORY-022 (welcome real)** — `WelcomeScreen` real por papel/tema (substitui placeholder de STORY-016); endpoint idempotente `POST /api/usuarios/me/welcome-visto` **fora** do `FunnelGuard`; `name` no payload do login; cobertura API 95,7% (`WelcomeController` 100%). IDR-014: proxy same-origin no dev espelhando o rewrite Firebase + convenção `/me/*` fora do guard.

**Métricas observáveis em homolog:**
- Funil completo profissional/contratante exercido ponta a ponta em browser real.
- RBAC vivo: admin→Backoffice ok / admin→WebApp rejeitado com link / profissional→WebApp ok com funnel guard / profissional→Backoffice 403 fail-secure.
- Audit log de admin imutável validado via psql (UPDATE/DELETE bloqueados pelo trigger).
- Texto-seed v1 carregado como `versao=1` ativa nos 2 templates.
- Editor de templates cria nova versão e ativa atomicamente sem alterar histórica.

### O que ficou para trás (e por quê)

- **STORY-021 (E-mails transacionais — stretch)** deferida para SPRINT-2026-W25 conforme decisão do PO. O dispatch e o seam de ACL foram entregues em STORY-019; falta só plugar o adapter real (Mailpit/Resend) — gap de UX consciente: usuário aprovado em homolog não recebe notificação automática hoje; Alexandro segue como canal humano até W25.
- **STORY-023/024/025** — já estavam fora do escopo confirmado da W24 desde a abertura. Compõem o núcleo da W25 (completar cadastro + AceiteEletronico + validação final do EPIC-001).
- **CA-15(c) ao nível de `AceiteEletronico` na STORY-020** — diferido para STORY-023/024 (dona da tabela `aceites_eletronicos`). O núcleo de PDR-012 que sustenta a garantia (v1 imutável + referenciável como histórica) está coberto.
- **Flake pré-existente em `pre-cadastro.spec.ts` e `pre-cadastro-contratante.spec.ts`** (semantics Flutter Web em 2ª navegação no mesmo tab) — fragilidade herdada de STORY-017/018 (IDR-006), **não** regressão. Recomendação registrada para endurecer `gotoApp` na 2ª navegação.

### Aprendizados

1. **Velocidade extrema com dupla Designer+Programador na mesma sessão de agente.** STORY-019/020/022 fecharam no mesmo D+2, com Designer e Programador atuando como atos separados de um único agente. O sync `≤15 min` virou registro na própria seção "Notas do agente" (não-chat). Quando há clareza de spec de referência (DDR-001 + preview HTML) e o programador entende as duas pontas, o ritmo dobra. Padrão a reutilizar.
2. **Mid-sprint check ANTECIPADO duas vezes.** D+7 antecipado para D+1; D+14 antecipado para D+2. Lição operacional: o PO precisa olhar `index.json` no fim de cada dia em sprints com volume real, não esperar o ritmo de quinta-feira herdado de sprints documentais.
3. **Gap latente de Foundation pode aparecer na primeira estória que exercita o caminho.** STORY-019 expôs o `HASH_DRIVER=argon2id` ausente no admin — login contra seeds compartilhados não estava coberto por E2E executado de fato. O Validador da STORY-011 não tinha como pegar (era hello world). Aceitar que **E2E genuíno em homolog é o gate real**, não cobertura unitária.
4. **E2E que dá `goto()` direto na tela sob teste mascara problemas de navegação.** STORY-019 inicialmente passava em E2E sem sidebar no dashboard. Teste manual do Alexandro pegou. Padrão: E2E exercita o **ponto de entrada real** (login → menu → tela), não a tela isolada.
5. **Frontmatter de fixtures Markdown precisa de strip explícito.** STORY-020 descobriu que o frontmatter YAML dos textos-seed continha `{{namespace.campo}}` em `nota_rascunho` — o seeder teria quebrado a validação de placeholder (CA-5) se carregasse o arquivo cru. Vendor com strip + SHA-256 logado.
6. **Cookie Sanctum `SameSite=lax` exige same-origin no dev tanto quanto em produção.** STORY-022 introduziu proxy no `router.php` + docker-compose espelhando o rewrite do Firebase. Sem isso, a primeira chamada autenticada do WebApp pós-login não passaria. Convenção `/api/usuarios/me/*` fora do `FunnelGuard` para rotas que justamente precisam ser acessíveis em `await_welcome`.
7. **3 ADRs em paralelo NÃO cascataram retrabalho.** O risco identificado na abertura (pré-leitura cruzada, revisão conjunta pelo PO) funcionou — 0 reabertura entre 009/010/011.
8. **L (STORY-016) cabe em D+2 quando arquitetura está bem cristalizada nas ADRs.** A expectativa era ≥1 semana; fechou em 2 dias. Indicação de que estimativa de tamanho precisa recalibrar quando o caminho técnico está bem desenhado a priori. Não generalizar: STORY-016 era L pelo escopo (auth + RBAC + funnel guard), não pela ambiguidade.

### Ajustes para o próximo sprint

1. **STORY-021 entra no topo da W25** — entrega a comunicação automática ao usuário aprovado (fecha o gap de UX) e libera o Alexandro de virar correio humano em homolog.
2. **Núcleo da W25: completar cadastro + AceiteEletronico + validação final.** STORY-023 (completar cadastro Profissional), STORY-024 (completar cadastro Contratante), STORY-025 (validação final EPIC-001). Esse trio fecha o EPIC-001.
3. **Endurecer `gotoApp` em E2E do pré-cadastro** (dono: STORY-018) — flake pré-existente identificado na W24 não tratado.
4. **Recalibrar estimativa de tamanho** considerando o ritmo real observado: 3 estórias M/dia com dupla Designer+Programador. Aplicar com cautela — pode ser função de escopo bem cristalizado nas ADRs, não regra geral.
5. **F-NB carregado para o PO decidir**: gap de `HASH_DRIVER` no admin pego em STORY-019 — formalizar como F-NB-2 do EPIC-000 ou registrar como aprendizado operacional (decisão pendente do Alexandro).
6. **Convenção `/api/usuarios/me/*` fora do `FunnelGuard`** (IDR-014) vira referência para STORY-023/024 (completar cadastro também precisa ser acessível em `await_complete`).
