---
sprint_id: SPRINT-2026-W24-LANDING
wave: WAVE-2026-01
status: open
start_date: 2026-05-28
end_date: null
soft_cap_date: 2026-06-11
parallel_to: SPRINT-2026-W24
closure_rule: "Fechamento por goal-atingido: encerra quando as 8 estórias do EPIC-006 estiverem `done` e a métrica primária (gate Em breve no apex respondendo + landing AS IS acessível via path secreto + pipeline isolado, tudo em `landing.homolog.turni.com.br`) for observada. Soft-cap em 2026-06-11 (~14 dias corridos) é gatilho de reavaliação, não prazo de entrega — sizing 3M+5S é folgado para 2 semanas se ADR-012 e PDR-015 fecharem cedo."
goal: "Landing institucional do Turni viva em homologação atrás de gate: `https://landing.homolog.turni.com.br/` responde 'Em breve' com identidade visual da landing; `https://landing.homolog.turni.com.br/<path-secreto>/` responde a landing AS IS importada de `docs/prototipo/`; `robots.txt` bloqueia indexação do path secreto; meta noindex no HTML da landing; pipeline GitHub Actions tag-based isolado do WebApp; rollback exercitado; runbook documentado cobrindo publicação, rollback, rotação de path e protocolo de go-public; site `turni-landing-prod` codificado em Terraform mas gated por `landing_prod_enabled=false` aguardando autorização comercial. 1 ADR nova aceita (ADR-012). 1 PDR novo aceito (PDR-015)."
goal_outcome: null
verdict_resolution: null
---

# SPRINT-2026-W24-LANDING

## Objetivo do sprint

Sprint paralela à SPRINT-2026-W24 (EPIC-001 Cadastro e Aprovação). Existe porque o time comercial precisa que `turni.com.br` deixe de resolver para nada — campanhas de pré-cadastro e materiais de imprensa começam a apontar para o domínio, e hoje cair em erro DNS é pior do que cair em "Em breve". Ao mesmo tempo, o comercial não autorizou ainda a exposição pública da landing completa: narrativa de lançamento sendo orquestrada, parcerias âncora em fechamento. A solução fixada pelo EPIC-006: apex e `www` servem página "Em breve" institucional; landing AS IS fica atrás de path secreto para parceiros/imprensa/investidores sob NDA.

A sprint é **factível em paralelo** porque o EPIC-006 não cruza com o EPIC-001 em domínio, código de aplicação ou dados:
- Sem migração de banco — landing é HTML estático.
- Sem alteração no WebApp Flutter ou no Backoffice Livewire.
- Sem dependência de auth, RBAC, audit log ou qualquer entidade de domínio.
- Toca **diferentes módulos Terraform** dos que EPIC-001 ainda vai mexer (EPIC-001 não toca infra Firebase Hosting nem DNS apex).
- Touch points compartilhados são raros e pequenos: `firebase.json` raiz (adiciona alvos `landing-*`), `.firebaserc` raiz (adiciona targets), `CODEOWNERS` raiz (adiciona regras para `apps/landing/`). Conflitos de merge são triviais.

O sprint roda majoritariamente com **agentes** (programador para 5 das 8 estórias). O input humano do Alexandro concentra em 2 pontos: (1) PDR-015 (STORY-027 — papel PO, decidir fronteira marketing×engenharia×comercial); (2) aprovação humana de ADR-012, PDR-015 e dos PRs com gate de revisão (Terraform apply, CODEOWNERS, workflow de deploy prod). Tempo humano estimado: 2-3h distribuídas no sprint, fora da janela ativa do EPIC-001.

## Escopo e duração

- **Escopo**: 8 estórias — 1 spike (026 ADR-012), 1 decision (027 PDR-015), 6 implementation (028/029/030/031/032 + 033 validador).
- **Duração**: aberta, com fechamento por goal-atingido. Padrão consolidado das sprints anteriores.
- **Soft-cap em 2026-06-11** (~14 dias corridos, 1 semana antes do soft-cap de W24 — sizing 3M+5S vs. 1L+7M+2S da W24). Se goal não bater nessa data, gatilho de reavaliação.
- **Sizing total**: 3M + 5S.

## Estórias incluídas

| ID        | Título                                                                                 | Épico    | Tipo           | Papel                   | Tamanho | Design?                             | Status                                                             |
| --------- | -------------------------------------------------------------------------------------- | -------- | -------------- | ----------------------- | ------- | ----------------------------------- | ------------------------------------------------------------------ |
| STORY-026 | Spike — gate Em breve + path secreto + topologia Firebase (ADR-012)                    | EPIC-006 | spike          | arquiteto               | M       | não                                 | **done**                                                           |
| STORY-027 | PO — PDR-015 Fronteira marketing × engenharia × comercial                              | EPIC-006 | decision       | po                      | S       | não                                 | **done**                                                           |
| STORY-028 | Página "Em breve" com identidade visual                                                | EPIC-006 | implementation | programador (+designer) | S       | **sim** (SCREEN-STORY-028-em-breve) | **in_progress** (Lighthouse local Perf 99/A11y 100 + ajuste ARIA OK; só falta curl-gate gated em 031) |
| STORY-029 | Terraform multi-site + DNS apex/www/landing.homolog                                    | EPIC-006 | implementation | programador             | M       | não                                 | **done**                                                           |
| STORY-030 | Scaffolding apps/landing/ + import AS IS + 4 adaptações + robots/404/README/CODEOWNERS | EPIC-006 | implementation | programador             | M       | não                                 | **done** (2026-05-29 — import AS IS em _lp/, 4 adaptações, CA-13 aprovado pelo PO) |
| STORY-031 | firebase.json com rotas explícitas + .firebaserc + workflow GitHub Actions tag-based   | EPIC-006 | implementation | programador             | M       | não                                 | ready                                                              |
| STORY-032 | Runbook operacional — publicar, rollback, rotação, go-public                           | EPIC-006 | implementation | programador             | S       | não                                 | ready                                                              |
| STORY-033 | Validação final do EPIC-006                                                            | EPIC-006 | validation     | validador               | S       | não                                 | ready                                                              |

**Sem stretch.** Sprint pequeno por construção; melhor entregar 8/8 do que arriscar carry-over.

## Ordem de execução (dependências do EPIC-006)

```
STORY-026 (ADR-012) ──────┐
STORY-027 (PDR-015) ──────┤
          /                │
            ┌─────────────┤
            │             │
            ▼             ▼
   STORY-028 (Em breve)   STORY-029 (Terraform)
            │             │
            └─────┬───────┘
                  │
                  ▼
   STORY-030 (scaffolding + import AS IS + CODEOWNERS)
                  │
                  ▼
   STORY-031 (firebase.json + workflow)
                  │
                  ▼
   STORY-032 (runbook)
                  │
                  ▼
   STORY-033 (validação) ──► sprint goal
```

**Justificativa da ordem** (respeita `blocked_by` no `index.json`):

- **026 e 027 em paralelo no D1**. 026 é spike do arquiteto (M); 027 é decisão do PO (S). Não dependem uma da outra. Ambas precisam estar `accepted` antes de 028+ começar.
- **028 e 029 em paralelo após 026 fechar.** 028 é página "Em breve" (programador + designer, S); 029 é Terraform (programador, M). Designer entrega `SCREEN-STORY-028-em-breve` em paralelo com a abertura de 026 (não é bloqueante para 026, mas precisa estar `ready` antes de 028 começar).
- **030 após 026 + 027 + 028.** Scaffolding precisa de: estrutura de pastas (ADR-012), CODEOWNERS (PDR-015), conteúdo da Em breve (STORY-028).
- **031 após 029 + 030.** firebase.json + workflow precisa dos sites Firebase (029) e do conteúdo em `apps/landing/public/` (030).
- **032 após 027 + 029 + 030 + 031.** Runbook documenta tudo o que veio antes.
- **033 após tudo.** Validador.

**Paralelismo legítimo**:
- D1: 026 (arquiteto) + 027 (PO) em sessões distintas.
- D3-D5: 028 (programador+designer) + 029 (programador) em sessões distintas.
- 030 e 031 em sequência (não paralelizam — 031 depende de 030).
- 032 quase paralelizável com 031 mas espera 031 para documentar comandos exatos.

## Compromisso visível ao fim do sprint

- **URLs públicas em homolog**:
  - `https://landing.homolog.turni.com.br/` → 200 com página "Em breve" institucional (logo TURN**I.**, copy aprovada pelo PO, identidade visual da landing).
  - `https://landing.homolog.turni.com.br/<path-secreto>/` → 200 com landing AS IS (import fiel de `docs/prototipo/index.html`, 4 adaptações mecânicas aplicadas: CTAs reescritos para `app.homolog.turni.com.br`, exclusão de `app.html`, meta robots noindex, headers de cache/segurança via firebase.json).
  - `https://landing.homolog.turni.com.br/robots.txt` → contém `Disallow: /<path-secreto>/`.
  - Paths aleatórios (`/foo/`, `/admin/`, `/xyz/`) → 404 institucional na identidade da landing (ou redirect para apex, conforme ADR-012) — **nunca** vazam o conteúdo da landing.

- **Pipeline isolado**:
  - Workflow `.github/workflows/landing-deploy.yml` com path filter em `apps/landing/**`.
  - Tag `landing-vX.Y.Z-rc.N` deploya homolog automaticamente.
  - Tag `landing-vX.Y.Z` (sem `-rc`) exige aprovação humana no GitHub Environment `landing-prod`.
  - Smoke test pós-deploy (5 checks); falha = rollback automático.
  - Deploy da landing não dispara workflow do WebApp; site `app.homolog.turni.com.br` permanece na revisão anterior.

- **Terraform multi-ambiente**:
  - Sites Firebase `turni-landing-homolog` aplicado em homolog; `turni-landing-prod` codificado mas gated por `landing_prod_enabled=false`.
  - `terraform plan` em prod mostra 0 changes para landing (gate funcionando).
  - DNS: `landing.homolog.turni.com.br` CNAME → Firebase Hosting; apex A/AAAA + www redirect codificados para prod.

- **Decisões aceitas**:
  - **ADR-012** (`accepted`) — mecânica do gate, política do `<path-secreto>`, política de 404, política de cache, destino do sw.js, redirect www→apex, swap CTA homolog→prod, topologia Firebase resultante, política de CODEOWNERS.
  - **PDR-015** (`accepted`) — fronteira de responsabilidade marketing × engenharia × comercial; SLA de resposta; protocolo de rotação do path secreto se vazar; protocolo de go-public.

- **Runbook operacional** (`docs/operacao/runbook-landing.md`) com 7 procedimentos: publicar conteúdo, rollback emergencial, rotacionar path secreto, trocar/adicionar domínio, remover sw.js de emergência, go-public, verificações periódicas. Pelo menos um procedimento (P2 rollback) exercitado em homolog.

- **Fronteira de propriedade codificada**: `CODEOWNERS` da raiz dividido por path conforme PDR-015 (`apps/landing/public/<path-secreto>/**` → marketing; resto da pasta + infra → engenharia).

- **Validação aprovada**: relatório do validador (STORY-033) com veredito `approved` ou `approved_with_pending` (este último com pendências não-bloqueantes documentadas, padrão consolidado a partir da STORY-011 do EPIC-000).

## Decisões de produto/arquitetura que entram em vigor agora

- **ADR-012** vira `accepted` no início do sprint. Todas as estórias subsequentes do EPIC-006 consomem como fundação. Padrão de "site estático em Firebase Hosting com gate via rotas explícitas + path secreto obfuscado" passa a ser referência para futuras superfícies institucionais (blog, docs públicas, status page).
- **PDR-015** vira `accepted` no início do sprint. Estabelece fronteira de 3 stakeholders (marketing × engenharia × comercial) e protocolo de go-public. Será referenciado por épicos futuros que adicionarem superfícies operadas por marketing.
- **ADR-004** consumida pela primeira vez para uma segunda superfície (até então só WebApp). Confirma que o padrão tag-based + gate humano em prod + WIF se replica sem refactor.
- **Honestidade arquitetural declarada**: gate de path secreto é **obfuscação, não segurança**. Se comercial precisar de proteção real (basic-auth, IP allowlist), vira ampliação separada. Declarado em ADR-012 e no epic.md do EPIC-006.

## Riscos identificados na abertura

| Risco | Probabilidade | Impacto | Mitigação | Owner |
|---|---|---|---|---|
| **Conflito de merge com SPRINT-2026-W24** em `firebase.json`, `.firebaserc`, `CODEOWNERS` da raiz | baixa | baixo | PRs pequenos e atômicos; revisão visual antes do merge; coordenação entre branches via PO daily | Programador + PO |
| Designer entrega `SCREEN-STORY-028-em-breve` simultaneamente aos 6 specs da W24 — possível gargalo no Designer | média | baixo | "Em breve" é tela trivial (logo + texto centralizado); spec pode ser rascunho ASCII de 10min, não precisa de Figma elaborado; Designer paraleliza fácil | Designer + PO |
| **ADR-012 demora a fechar** porque arquiteto está engajado em decisões do EPIC-001 (W24) | média | médio | ADR-012 é spike isolado de subsistema único (gate + path + topologia Firebase) — sem cruzamento com ADRs do EPIC-001. Pode rodar em sessão dedicada de arquiteto enquanto W24 sessions seguem | Arquiteto + PO |
| **PDR-015 demora porque PO está consumido por W24** | média | médio | PDR-015 é decisão de fronteira que o Alexandro pode redigir em janela curta (S, ~30-60min de escrita após pré-conversa com marketing/comercial); pode rodar fora do horário ativo da W24 | PO |
| **Comercial demora a definir valor inicial do `<path-secreto>`** | média | médio | ADR-012 decide **como** rotacionar, não **qual** path usar. STORY-029/030/031 podem usar placeholder commitado (ex: `/preview-mvp/`) em homolog e comercial define o valor real antes do go-public. Não bloqueia o sprint | PO + Comercial |
| **Marketing pede alterações na landing AS IS durante o sprint** — viola contrato AS IS | baixa | baixo | epic.md declara explícito que landing é AS IS; PDR-015 reforça. Se marketing pedir mudança, abre PR após STORY-030 mergeada — não impacta este sprint | Marketing + PO |
| Service worker (`sw.js`) AS IS cacheia versão antiga e esconde push novo — vazamento de UX | baixa | baixo | ADR-012 decide destino do sw.js no início; se decidir manter, STORY-031 prepara remoção emergencial via runbook P5. Risco mitigado pelo procedimento documentado | Programador |
| **Headers de segurança (CSP) bloqueiam algum asset legítimo da landing AS IS** (Google Fonts, externalmente carregado) | média | baixo | CSP base permite Google Fonts (landing AS IS usa); STORY-031 inclui smoke test pós-deploy que falha se algum asset crítico não carrega; rollback automático | Programador |
| Workflow GitHub Actions colide com workflow do WebApp (path filter mal-escrito) | baixa | médio | STORY-031 inclui CA explícito (CA-10) de isolamento testado; PO valida diff de path filter no PR | Programador + PO |
| Validador (STORY-033) reprova por critério não previsto | média | baixo | Checklist de 15 blocos já redigido junto com o épico; particularidades (prod fora do ar = `n/a` justificado) explícitas. Risco de surpresa é baixo | Validador |
| **Alexandro nos 5 papéis em DUAS sprints paralelas — fadiga** | **alta** | médio | Carga humana real desta sprint é pequena (≈2-3h espalhadas: redigir PDR-015 + aprovar ADR-012 + aprovar 3-4 PRs com gate). Agente cobre as 5 implementation stories. PO faz check semanal cruzado entre as duas sprints, não diário | Alexandro |

## Acompanhamento contínuo (PO)

- **Daily integrado com W24** (~5 min adicional, total ~15 min para as duas sprints): olhar `index.json`, identificar o que está `in_progress` / `blocked` / `in_review` nas duas sprints. Desbloquear o que pode.
- **Mid-sprint check em 2026-06-04 (D+7)**: PO verifica se ADR-012 e PDR-015 estão `accepted`; se STORY-028 e STORY-029 estão `in_progress` ou `done`. Se ADR-012 ou PDR-015 ainda não fecharam, é o gargalo — escala.
- **Soft-cap check em 2026-06-11**: se goal não bateu, abrir seção "Mudanças no escopo" abaixo e decidir entre (a) seguir sem ajuste, (b) carregar STORY-033 (validador) para um mini-sprint dedicado, (c) deferir STORY-032 (runbook) para depois — landing funciona sem runbook, apenas sem documentação operacional.

## Coordenação com SPRINT-2026-W24

Como esta sprint roda em paralelo, regras explícitas de coordenação:

1. **PRs separados por sprint**: cada PR menciona qual sprint serve no título (`[W24]` ou `[W24-LANDING]`). Facilita revisão e auditoria.
2. **Touchpoints compartilhados** (`firebase.json`, `.firebaserc`, `CODEOWNERS`, módulos Terraform `firebase`/`dns`): coordenar via PO se houver dois PRs abertos simultaneamente nesses arquivos. Rebase imediato após qualquer merge para evitar conflitos de N PRs.
3. **Branches por sprint** seguindo padrão consolidado (`epic-006/story-NNN-slug`); merge para `main` via PR.
4. **Tags isoladas**: W24 (EPIC-001) usa tags `v0.X.Y-rc.N`; W24-LANDING (EPIC-006) usa tags `landing-vX.Y.Z-rc.N`. Workflows escutam tags distintas — zero cruzamento.
5. **Reviews humanas**: Alexandro revisa PRs das duas sprints; idealmente em janelas dedicadas separadas (manhã W24, tarde W24-LANDING — ou ritmo que funcionar) para evitar context-switch.
6. **Daily único integrado**: relatório diário cobre as duas sprints com seções separadas.

## Disciplina de processo (vinda de W22/W23/W24)

Regras herdadas:

1. **`sprint_id` no frontmatter** atualizado no mesmo commit que adiciona a estória ao `sprints[*].story_ids` do `index.json`. Aplicado na abertura desta sprint nas 8 estórias.
2. **Marcação de CA**: ao transicionar para `status: done`, todos os CAs atendidos no `.md` devem estar `[x]`. CA `[ ]` em estória `done` → PO devolve para `in_progress`.
3. **"Verdade de corredor" vira PDR/ADR/DDR antes**: se durante a execução uma estória citar decisão não registrada, o agente para, escala ao papel dono, só prossegue depois do registro.
4. **Sync Designer↔Programador (≤15 min)**: registrado em "Notas do agente" antes da primeira linha de UI de STORY-028 (única `requires_design: true` desta sprint).

Regras específicas para W24-LANDING:

5. **Contrato AS IS é inviolável**: STORY-030 só aplica as 4 adaptações mecânicas declaradas. Qualquer "melhoria" no HTML/CSS/JS do AS IS → PO devolve para `in_progress`. Validação especial: diff cirúrgico anexado ao PR antes do merge.
6. **`<path-secreto>` não vaza em arquivo commitado**: README, CHANGELOG, runbook, "Em breve" e 404 usam **placeholder literal** `<path-secreto>`. Grep no PR antes do merge confirma.
7. **Smoke test pós-deploy é não-negociável**: STORY-031 entrega smoke test ativo no workflow; failure dispara rollback automático. Não há "deploy verde" sem smoke test verde.

## Mudanças no escopo do sprint

> Toda alteração no conjunto de estórias após esta abertura registra aqui, com data e motivo.

| Data | O que mudou | Motivo | Custo (estória solta/movida) |
|---|---|---|---|
| 2026-05-28 | Abertura: 8 estórias do EPIC-006 (026-033) | Sprint paralelo a W24 aberto para destravar `turni.com.br` enquanto narrativa de lançamento do comercial está sendo orquestrada. Sizing 3M+5S; soft-cap 2026-06-11. Sem stretch (épico pequeno, melhor entregar 8/8). | — |

## Aprendizados em curso (mid-sprint)

> Para registrar conforme acontecem; consolidados na seção "Fechamento do sprint" no fim.

### 2026-05-28 — D+1: ADR-012, PDR-015 e Terraform fechados; "Em breve" implementada (validação gated em 031)

**O que aconteceu:**

Quatro estórias avançaram no D1 — bem acima do estimado (esperado: 026 e 027 fecharem; 028/029 começarem):

- **STORY-026 (ADR-012) done** — gate "Em breve" + path secreto + topologia Firebase fixados. Decisão chave: site único + página em `apps/landing/public/index.html`, sem rewrite genérico, HTML `no-cache`, `sw.js` removido.
- **STORY-027 (PDR-015) done** — fronteira marketing × engenharia × comercial estabelecida.
- **STORY-029 (Terraform multi-site + DNS) done** — infra aplicada em homolog (apex/www/landing.homolog); IDR-004/005 registrados.
- **STORY-028 (Em breve) in_progress** — `apps/landing/public/index.html` implementado e commitado (`db4a238`); 3.4 KB de HTML, render Playwright OK mobile/desktop, copy "Em breve." aprovada por Alexandro. **Pendências para fechar são gated em STORY-031** (Lighthouse mobile precisa de URL servida pelo Firebase + smoke curl do gate).

**Estado resultante (4/8):**

- 3 done (026, 027, 029), 1 in_progress validação-gated (028).
- 4 ready: 030 (agora destravada — tem 026 + 027 + 028 atendidos para o código que precisa, mesmo com 028 pendente de Lighthouse), 031, 032, 033.

**Gargalo atual:**

STORY-030 (scaffolding + import AS IS + adaptações) é o caminho crítico. Destrava 031 e 032; 031 destrava o fechamento de 028 (Lighthouse contra URL real). Sem 030, fica tudo parado.

**Decisão de fluxo:**

028 fica `in_progress` formalmente (Disciplina §2 — CA-7/CA-8/CA-10 com pendência observável) até STORY-031 servir a URL e o Lighthouse rodar. Não devolvido para `ready` porque o código está pronto e aprovado; só falta evidência externa que depende de outra estória.

**Ajuste de expectativa:**

Sprint passou de 1/8 para 4/8 em D1. Soft-cap 2026-06-11 (~14 dias) muito confortável — 4 estórias restantes (030/031/032/033) podem fechar em sequência rápida. Coordenação com W24 (paralela) sem conflitos até aqui.

### 2026-05-29 — STORY-030 done; STORY-028 com Lighthouse local verde

**O que aconteceu:**

- **STORY-030 (scaffolding + import AS IS) done.** Landing importada para `apps/landing/public/_lp/` com as **4 adaptações mecânicas** e nada mais (diff cirúrgico provado: A1 15 CTAs → `__WEBAPP_URL__`, A2 sem `app.html`/`manifest.json`, A3 `noindex`; A4 fica em 031). `robots.txt` (template `__LANDING_PATH__`), `404.html` institucional, `README.md`, `CHANGELOG.md` e `CODEOWNERS` (raiz, ADR §9 + aliases PDR-015) criados. CA-13: PO revisou o diff **e** a landing renderizada no browser — aprovado.
  - Decisão de execução: `manifest.json` dropado (+ `<link rel=manifest>`) por ser artefato PWA do WebApp (`start_url`→`app.html`); tratado dentro da A2, aprovado pelo PO. `sw.js`/`tour.*` não copiados (do WebApp).
- **STORY-028:** Lighthouse mobile local rodado (Perf 99 / A11y 100 / SEO 100, contraste PASS); corrigido um achado real de ARIA (`role="img"` inválido no `<h1>` → removido, mantido `aria-label`; a11y 99→100, heading restaurado). PO decidiu manter 028 `in_progress` — reconfirmação na URL de homolog é não-bloqueante, absorvida pela 033.

**Estado resultante (5/8):** 4 done (026, 027, 029, 030), 1 in_progress validação-gated (028), 3 ready (031, 032, 033).

**Gargalo atual:** STORY-031 (firebase.json rotas explícitas + .firebaserc + workflow tag-based + build step `_lp→path` / `__WEBAPP_URL__` / `__LANDING_PATH__`). 031 serve a URL real → fecha o Lighthouse de homolog da 028 e destrava 032/033.

(próximo check em 2026-06-04 — D+7)

## Fechamento do sprint

> Preencher quando o goal bater (ou no soft-cap se reavaliar antes).

### O que foi entregue
(a preencher)

### O que ficou para trás (e por quê)
(a preencher)

### Aprendizados sobre rodar sprints em paralelo
(a preencher — primeira vez no projeto; calibra para futuros paralelos)

### Aprendizados sobre fronteira marketing × engenharia × comercial
(a preencher — calibra PDR-015 na prática)

### Ajustes para o próximo sprint
(a preencher)
