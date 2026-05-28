---
story_id: STORY-033
slug: validacao-final-epic-006
title: Validação final do EPIC-006 Landing institucional
epic_id: EPIC-006
sprint_id: SPRINT-2026-W24-LANDING
type: validation
target_role: validador
requires_design: false
status: ready
owner_agent: null
created_at: 2026-05-28
updated_at: 2026-05-28
estimated_session_size: S
---

# STORY-033 — Validação final do EPIC-006

> **Para o agente que vai executar:** leia esta estória por inteiro antes de começar. Ela contém tudo o que você precisa. Se algo estiver ambíguo, registre a dúvida na seção "Notas do agente" no final e pause em vez de adivinhar. **Limite de papel:** você é o Validador. Você produz **fato + veredito**. **Não** propõe estórias de correção, **não** sugere próximos passos, **não** planeja. Planejamento é do PO. (Aprendizado da skill após rodada 1 de STORY-011.)

## Contexto (por que esta estória existe)

EPIC-006 entrega a landing institucional `turni.com.br` atrás de gate "Em breve" + path secreto, com pipeline isolado e fronteira de propriedade marketing × engenharia × comercial. Antes do épico fechar como `done`, o **validador independente** percorre o checklist, verifica evidências, e produz veredito factual em `validation/report.md`. Sem isso, o PO não marca o épico como concluído (princípio não-negociável #5 — estado registrado).

A validação aprende com STORY-011 (EPIC-000) e STORY-025 (EPIC-001): 2 rodadas se necessário; validador se atém a fato + veredito; PO trata o relatório como gatilho de planejamento.

EPIC-006 tem particularidade: **prod não está no ar** ao final do épico (PDR-015 atribui go-public ao comercial, em momento separado). Validador verifica que o **mecanismo está pronto** para go-public, não que ele aconteceu. Especificamente: site `turni-landing-prod` codificado em Terraform mas gated por `landing_prod_enabled = false`; workflow tem job de deploy prod com gate humano; runbook P6 documenta go-public. Verificação de prod efetivo (`https://turni.com.br/` retornando "Em breve") fica para validação separada quando comercial autorizar.

- Épico: `docs/project-state/epics/EPIC-006-landing-institucional/epic.md`
- Documentos canônicos a ler ANTES de validar:
  - `validation/checklist.md` deste épico (criado pelo PO junto com este épico)
  - Todas as STORYs 026–032 deste épico (estados, evidências, "Notas do agente")
  - Todos os ADRs/PDRs aceitos referenciados (ADR-012, ADR-004, ADR-003, PDR-015, PDR-003)
  - `docs/project-state/epics/EPIC-006-landing-institucional/epic.md`
  - `docs/operacao/runbook-landing.md` (criado em STORY-032)
  - `docs/skills/validador/SKILL.md`
  - `docs/skills/po/references/quality-standards.md`

## O quê (objetivo desta estória)

Executar o checklist de validação do EPIC-006 e produzir relatório com veredito.

1. Verificar **pré-condições** (STORY-026 a STORY-032 com `status: done` no `index.json`; EPIC-006 com `status: in_review`).
2. Executar o checklist em `epics/EPIC-006-landing-institucional/validation/checklist.md`. Cada item tem **status** (`pass`, `pass com ressalva`, `fail bloqueante`, `fail não-bloqueante`, `n/a`) e **evidência observável** (comando rodado + saída, screenshot, log, URL testada).
3. **Métrica primária do épico**: `https://landing.homolog.turni.com.br/` responde 200 com "Em breve" verificável; `https://landing.homolog.turni.com.br/<path-secreto>/` responde 200 com landing AS IS verificável; `robots.txt` bloqueia path secreto; sem leak; deploy isolado do WebApp. Verificar **com último deploy do épico aplicado** em homolog.
4. **Validar gate**: `curl` em paths aleatórios (`/qwertyuiop/`, `/foo/`, `/admin/`, `/api/`) retorna o comportamento decidido em ADR-012 (404 institucional ou redirect para apex) — **nunca** vaza o conteúdo da landing.
5. **Validar não-indexação**: `robots.txt` tem `Disallow: /<path-secreto>/`; HTML da landing tem `<meta name="robots" content="noindex,nofollow">`. Verificar com Google Search Console se possível (validador sem acesso pode pular; registrar como `n/a` justificado).
6. **Validar não-leak**: grep no HTML servido da página "Em breve" (`curl /`) por menções ao `<path-secreto>` real → 0 matches. grep no `404.html` servido → 0 matches. grep no `apps/landing/README.md` (commitado) → 0 matches (apenas placeholder literal `<path-secreto>`).
7. **Validar fronteira CODEOWNERS**: simular PR tocando `apps/landing/public/<path-secreto>/index.html` e verificar que `CODEOWNERS` exige aprovação de marketing; simular PR tocando `apps/landing/public/index.html` e verificar exigência de engenharia. Usar `gh api repos/{owner}/{repo}/codeowners` ou ferramenta equivalente.
8. **Validar isolamento de deploy**: triggerar deploy da landing em homolog; verificar que site WebApp `app.homolog.turni.com.br` continua na revisão anterior (timestamp inalterado no Firebase Hosting console). Verificar que workflow do WebApp **não** disparou em paralelo (GitHub Actions run history).
9. **Validar pipeline tag-based + gate humano em prod**:
   - Tag `landing-v*-rc.*` dispara deploy homolog sem gate.
   - Tag `landing-v*` (sem `-rc`) **NÃO** deploya sem aprovação manual no GitHub Environment `landing-prod`.
   - GitHub Environment `landing-prod` tem revisor obrigatório configurado.
10. **Validar rollback**: comando `firebase hosting:rollback` documentado no runbook P2 e exercitado pelo programador (verificar evidência em STORY-031 ou STORY-032).
11. **Validar Terraform multi-ambiente**: `terraform plan` em prod mostra 0 changes para landing (gate `landing_prod_enabled = false` funcionando); mecanismo de go-public é flip de variável + apply + tag (verificar coerência com runbook P6).
12. **Validar Lighthouse**:
    - Página "Em breve": Performance ≥ 90, Accessibility ≥ 95 (mobile 3G simulado).
    - Landing AS IS no path secreto: Performance ≥ 70, Accessibility ≥ 80 (linha-base, não-bloqueante).
13. **Validar headers de segurança**: `curl -sI` em homolog mostra HSTS, X-Content-Type-Options, X-Frame-Options, CSP presentes conforme ADR-012 / STORY-031.
14. **Validar runbook**: `docs/operacao/runbook-landing.md` existe, cobre os 7 procedimentos (P1-P7), tem comandos exatos, não vaza path secreto, pelo menos um procedimento exercitado.
15. **Produzir `validation/report.md`** em `epics/EPIC-006-landing-institucional/validation/report.md` com veredito final.

**Vereditos possíveis** (mesma régua de STORY-011 e STORY-025):
- `approved`: zero fails (bloqueantes ou não); épico pronto para `done`.
- `approved_with_pending`: zero fails bloqueantes, fails não-bloqueantes presentes. PO decide se trata como goal atingido ou carry forward.
- `rejected`: ≥ 1 fail bloqueante. PO abre estória(s) de correção em mini-sprint dedicada; épico permanece `in_review`.

## Por quê (valor para o usuário)

Direto: garantia que o gate "Em breve" + path secreto funciona como prometido — apex não vaza, path secreto serve a landing, robots não-indexa, fronteira CODEOWNERS efetiva, pipeline isolado, runbook executável. Sem essa garantia, comercial não tem confiança para autorizar o go-public; engenharia não tem evidência de que pode entregar swap em minutos. Indireto: terceira aplicação do ciclo "valida → reprova → corrige → revalida" no projeto — calibra o desenho do papel validador para épicos maiores à frente.

## Critérios de aceite

- [ ] **CA-1:** `epics/EPIC-006-landing-institucional/validation/report.md` existe com `verdict` preenchido (`approved` | `approved_with_pending` | `rejected`).
- [ ] **CA-2:** Cada item do `validation/checklist.md` tem status registrado e evidência (comando + saída, screenshot, query, URL).
- [ ] **CA-3:** Métrica primária verificada com **último deploy do épico** aplicado em homolog (lição STORY-011).
- [ ] **CA-4:** Gate validado em paths aleatórios — nenhum vaza landing.
- [ ] **CA-5:** Não-indexação validada (robots + meta tag).
- [ ] **CA-6:** Não-leak validado (grep em "Em breve", 404, README).
- [ ] **CA-7:** CODEOWNERS efetivo validado (simulação de PR).
- [ ] **CA-8:** Isolamento de deploy validado (WebApp inalterado durante deploy da landing).
- [ ] **CA-9:** Pipeline tag-based + gate humano em prod validado (sem deploy prod sem aprovação).
- [ ] **CA-10:** Rollback comandado documentado e exercitado.
- [ ] **CA-11:** Terraform prod mostra 0 changes (gate funcional).
- [ ] **CA-12:** Lighthouse rodado e metas comparadas (status registrado).
- [ ] **CA-13:** Headers de segurança presentes.
- [ ] **CA-14:** Runbook completo com os 7 procedimentos.
- [ ] **CA-15:** `index.json` atualizado: `epics[EPIC-006].validation_report` aponta para o relatório com `verdict` e `validated_at`; status da própria estória STORY-033 transiciona para `done` ao final.

## Fora de escopo

- Decidir o que fazer com o veredito — PO planeja (aprende com STORY-011/025).
- Validar prod efetivo (`https://turni.com.br/`) — fora porque prod não está no ar ao final do épico (PDR-015 separa go-public). Vira validação separada quando comercial autorizar.
- Validar basic-auth/IP allowlist — fora; epic.md declara explicitamente como ampliação fora do EPIC-006.
- Reabrir decisões de ADR-012 / PDR-015 (validador audita, não reabre).
- Propor stories de correção ou ampliação (papel do PO).

## Padrões de qualidade exigidos

Esta estória segue `docs/skills/validador/SKILL.md`:

- **Fato + veredito:** zero sugestões, zero "talvez fosse melhor". Apenas o que foi observado e o veredito.
- **Evidência observável:** cada item do checklist com comando + saída, screenshot, query, URL.
- **2 rodadas se necessário:** se primeiro relatório for `rejected`, PO abre correções, validador revisa do zero (não incrementalmente). Padrão de STORY-011.
- **Sem extrapolação de papel:** se notar algo fora do escopo do épico (ex.: ideia para basic-auth), registrar em "Notas do agente" mas **não** colocar no relatório.

## Dependências

- **Bloqueada por:** STORY-026 a STORY-032 — todas devem estar `done`. EPIC-006 com `status: in_review`.
- **Bloqueia:** fechamento do EPIC-006 (`status: done`).

## Decisões já tomadas (não as reabra)

- **epic.md do EPIC-006** — escopo e fora-de-escopo fixados.
- **ADR-012** — mecânica do gate.
- **PDR-015** — fronteira e protocolos.
- **ADR-004** — pipeline tag-based + gate humano em prod.
- **Limite de papel validador** — fato + veredito; sem propor planejamento.

## Liberdade técnica do agente

Você (validador) decide:
- Ordem de verificação dos itens (sugestão: seguir ordem do checklist).
- Ferramenta de cada verificação (curl, dig, gh CLI, browser DevTools, Lighthouse CLI).
- Como capturar evidência (texto, screenshot, link de log do CI).
- Veredito final com base nos fails encontrados.

Você (validador) NÃO decide:
- Reabrir ADR-012 / PDR-015 / epic.md.
- Propor stories de correção (papel do PO).
- Aprovar com fails bloqueantes presentes.
- Suprimir itens do checklist sem justificativa (`n/a` precisa ser justificado).

## Definição de Pronto (DoD)

- [ ] Todos os CAs (CA-1 a CA-15) passam.
- [ ] `validation/report.md` mergeado.
- [ ] `index.json` atualizado.
- [ ] "Notas do agente" preenchida.

## Protocolo do agente (obrigatório)

Siga `docs/skills/validador/SKILL.md`. Resumo:

1. Frontmatter desta estória: `status: in_progress`, `owner_agent`, `updated_at`. Atualize `index.json`.
2. Verifique pré-condições (STORYs 026-032 `done`, EPIC-006 `in_review`).
3. Percorra o checklist; capture evidência item a item.
4. Escreva `validation/report.md` com veredito.
5. Abra PR; mergeie.
6. Atualize `index.json` (EPIC-006.validation_report + esta estória). Marque `status: done`.

## Notas do agente (preenchido durante/após execução)

### Entrada inicial
(a preencher)

### Pré-condições verificadas
(a preencher — lista de STORYs e status confirmado)

### Itens do checklist
(a preencher — uma linha por item com status + evidência)

### Descobertas
(a preencher — observações que não viram fail mas merecem registro)

### Bloqueios encontrados
(a preencher)

### Veredito
(a preencher — `approved` | `approved_with_pending` | `rejected` com justificativa)

### Pendências para fechar
(a preencher)

### Links de evidência
(a preencher — PR do report, screenshots, logs)
