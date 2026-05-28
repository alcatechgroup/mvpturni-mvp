---
story_id: STORY-026
slug: spike-gate-em-breve-path-secreto-topologia-firebase
title: Spike Arquiteto — gate "Em breve" + path secreto + topologia Firebase para landing (ADR-012)
epic_id: EPIC-006
sprint_id: SPRINT-2026-W24-LANDING
type: spike
target_role: arquiteto
requires_design: false
status: ready
owner_agent: null
created_at: 2026-05-28
updated_at: 2026-05-28
estimated_session_size: M
---

# STORY-026 — Spike Arquiteto: gate "Em breve" + path secreto + topologia Firebase (ADR-012)

> **Para o agente que vai executar:** leia esta estória por inteiro antes de começar. Ela contém tudo o que você precisa. Se algo estiver ambíguo, registre a dúvida na seção "Notas do agente" no final e pause em vez de adivinhar.

## Contexto (por que esta estória existe)

EPIC-006 sobe a landing institucional em `turni.com.br`, mas o time comercial não autorizou exposição pública enquanto a narrativa de lançamento está sendo orquestrada. A solução fixada pelo PO: apex e `www` servem uma página "Em breve" minimalista; a landing completa AS IS fica atrás de um `<path-secreto>` configurável. Antes de qualquer estória de implementação começar, o **arquiteto** precisa decidir como esse gate é implementado tecnicamente, qual é a topologia Firebase resultante, e como o `<path-secreto>` é gerido — sem ADR cobrindo isso, as estórias 028 a 031 vão decidir ad-hoc no código e gerar refactor.

Por que **uma** ADR cobre as quatro decisões (mecânica do gate, política do path, política de 404, política de cache): formam um subsistema único de governança da landing — decidir o gate sem decidir o tratamento de 404 deixa lacuna que vira lateral leak; decidir o path sem decidir cache do `index.html` cria janelas em que push do marketing fica invisível ou path antigo vaza via cache. `story-craft.md` autoriza ADR coesa cobrindo subsistema único.

- Épico: `docs/project-state/epics/EPIC-006-landing-institucional/epic.md`
- Documentos canônicos a ler ANTES de deliberar:
  - `docs/project-state/decisions/adr/ADR-004-hospedagem-iac-deploy.md` (Firebase Hosting + Cloud DNS + pipeline tag-based — esta ADR herda)
  - `docs/project-state/decisions/adr/ADR-003-monorepo-vs-polirepo.md` (deploy independente por path filter)
  - `docs/project-state/decisions/pdr/PDR-003-duas-interfaces-webapp-e-backoffice.md` (landing é **terceira superfície pública**)
  - `infra/modules/firebase/main.tf` e `infra/modules/firebase/variables.tf` (módulo Firebase Hosting existente — vai precisar aceitar múltiplos sites)
  - `infra/modules/dns/main.tf` e `infra/modules/dns/variables.tf` (módulo Cloud DNS existente — vai precisar de apex A/AAAA, redirect www, CNAME landing.homolog)
  - `firebase.json` e `.firebaserc` na raiz (estrutura atual de hosting targets)
  - `docs/prototipo/index.html` (fonte da landing AS IS — observar referências a assets para entender a árvore que vai migrar)
  - `docs/prototipo/sw.js` (decidir se fica ou sai)
  - `docs/skills/arquiteto/SKILL.md` e `docs/skills/arquiteto/references/architecture-principles.md`

## O quê (objetivo desta estória)

Deliberar e propor **ADR-012 — Landing institucional: gate Em breve, path secreto, hosting dedicado, pipeline isolado**, em estado `proposed`, cobrindo num único artefato as quatro dimensões:

1. **Mecânica do gate "Em breve" + path secreto.** No mínimo 2 opções avaliadas:
   - (a) Site Firebase único com rotas explícitas em `firebase.json` (`/`, `/<path-secreto>/**`, `/robots.txt`, fallback 404), **sem** rewrite genérico `** → /index.html`.
   - (b) Dois sites Firebase separados — um servindo apex (apenas a página "Em breve"), outro servindo a landing num subdomínio dedicado (ex: `<path-secreto>.turni.com.br`).
   - (c) Site único com rewrite genérico + middleware/Cloud Function que faz o gate.
   Avaliar contra: simplicidade (#1), custo (#11 — Cloud Function adiciona linha de custo e latência), risco de leak (se rewrite genérico estiver ativo, qualquer 404 vira landing), e o requisito "deploy isolado" (alterar landing não toca WebApp). **Decidir e justificar.**

2. **Política do `<path-secreto>`.** No mínimo 2 opções avaliadas:
   - (a) Path commitado em `firebase.json` no repositório — qualquer pessoa com acesso ao repo conhece (default git → quem tem acesso ao git sabe).
   - (b) Path injetado em build-time via secret de deploy (`FIREBASE_LANDING_PATH` no GitHub Actions secret) — não aparece no repo, mas aparece no `firebase.json` deployado e em qualquer cópia local clonada após o deploy.
   - (c) Path duplo: alias estável commitado + sufixo rotacionável injetado em build (ex: `/preview-${SUFIXO}/`), permitindo rotação sem mexer no repo.
   Definir: valor inicial **sugerido** (sem fixar — comercial dá o final), procedimento de rotação se vazar, quem aprova rotação, log de quem tem acesso ao path corrente. Lembrar a "Honestidade sobre o gate" do epic.md: obfuscação, não segurança.

3. **Política de tratamento de 404.** No mínimo 2 opções avaliadas:
   - (a) Página 404 institucional na identidade da landing, **sem** link de volta para o path secreto (mensagem genérica "página não encontrada", logo TURN**I.**, link para apex/"Em breve").
   - (b) Redirect 302 de qualquer 404 para `/` ("Em breve"), escondendo a existência de estrutura.
   - (c) 404 do Firebase Hosting padrão (cru).
   Avaliar contra: experiência do usuário, indicador de "site quebrado" vs. "site existe mas página não", risco de esconder bug real.

4. **Política de cache do `index.html`.** Decidir: `no-cache` (zero TTL) para o "Em breve" e para o `index.html` da landing, garantindo que push aparece em ≤ 5 min; assets imutáveis (JS/CSS/imagens com hash) com `max-age=31536000`. Justificar pesando velocidade de propagação × custo de CDN miss.

5. **Decisão sobre o `sw.js` AS IS.** Verificar o que o service worker do protótipo cacheia. Decidir: (a) fica AS IS (risco aceito), (b) sai na importação (engenheiro remove do bundle), (c) fica mas com comportamento neutralizado (registra-se mas não cacheia). Documentar a decisão e o gatilho de remoção emergencial se causar problema.

6. **Como o redirect `www → apex` é implementado.** Decidir: (a) regra `redirects` no `firebase.json` do site da landing (apenas se o Firebase Hosting aceitar configurar `www` no mesmo site, o que requer adicionar `www.turni.com.br` como domínio customizado do site), (b) site Firebase dedicado para `www` que serve apenas a regra de redirect, (c) registro DNS via servidor de redirect externo. Justificar pesando latência adicional × complexidade.

7. **Como o swap de URL de CTA `homolog → prod` é feito no go-public futuro.** Decidir: (a) substituição build-time com placeholder `__WEBAPP_URL__` substituído pelo workflow, (b) PR manual do marketing trocando hardcoded strings, (c) redirect HTTP em `app.homolog → app.turni` quando prod subir. Justificar — esta decisão impacta o esforço do go-public e o quanto a landing AS IS muda entre homolog e prod.

8. **Topologia final dos sites Firebase Hosting.** Listar os sites resultantes (provavelmente `turni-landing-homolog` e `turni-landing-prod`; possivelmente um terceiro se a decisão de §1 for "dois sites separados"), o que cada um serve, e o impacto no módulo Terraform `infra/modules/firebase` (atualmente cria 1 site por chamada — vai precisar virar uma lista, ou ser chamado N vezes).

9. **Política de `CODEOWNERS`.** Decidir a estrutura concreta:
   - `apps/landing/public/<path-secreto>/**` → marketing.
   - `apps/landing/public/index.html` (Em breve), `firebase.json`, `404.html`, `robots.txt`, workflow de deploy → engenharia.
   Verificar como expressar isso em sintaxe `CODEOWNERS` sem vazar o `<path-secreto>` no arquivo (se a decisão de §2 for não commitar o path).

A ADR é aceita por Alexandro antes de qualquer estória de implementação do EPIC-006 abrir.

## Por quê (valor para o usuário)

Esta spike não entrega valor direto a usuários externos — entrega valor ao **time**. Sem ADR-012, a STORY-028 (página "Em breve") não sabe se está sendo construída para um site único ou para um site dedicado; a STORY-029 (Terraform) não sabe quantos sites Firebase criar; a STORY-030 (scaffolding) não sabe onde colocar o conteúdo AS IS; a STORY-031 (firebase.json + workflow) não sabe se escreve rotas explícitas ou se delega a um middleware. Bloqueio em cascata. Em especial, decidir 404 + cache + sw.js depois que o pipeline já está rodando vira refactor com ciclo de deploy + verificação a cada iteração.

## Critérios de aceite

Spike não produz código de produção; o critério é a **existência e qualidade do artefato ADR** + aderência ao processo arquitetural.

- [ ] **CA-1:** Existe `docs/project-state/decisions/adr/ADR-012-landing-gate-em-breve-path-secreto.md` em `status: proposed`, escrito conforme `docs/skills/arquiteto/templates/adr.md`, contendo: contexto, forças, opções consideradas, matriz comparativa quando útil, decisão, justificativa, diagrama (topologia Firebase + DNS resultante), consequências, plano de verificação.
- [ ] **CA-2:** A ADR decide **mecânica do gate** (§1 do "O quê") com no mínimo 2 opções avaliadas e justifica à luz de custo, simplicidade, risco de leak e isolamento de deploy.
- [ ] **CA-3:** A ADR decide **política do `<path-secreto>`** (§2) com no mínimo 2 opções, define procedimento de rotação, e declara honestamente a limitação ("obfuscação, não segurança").
- [ ] **CA-4:** A ADR decide **política de 404** (§3), **política de cache** (§4), **destino do `sw.js`** (§5), **redirect www→apex** (§6), **swap de CTA homolog→prod** (§7) — cada uma com no mínimo 2 opções avaliadas e justificativa explícita.
- [ ] **CA-5:** A ADR descreve a **topologia final** (§8): número de sites Firebase, o que cada um serve, impacto no módulo Terraform `infra/modules/firebase`. Diagrama presente.
- [ ] **CA-6:** A ADR descreve a **política de CODEOWNERS** (§9) com a estrutura concreta de patterns, considerando o impacto da decisão de §2 (se path não é commitado, o pattern usa wildcard).
- [ ] **CA-7:** A ADR registra explicitamente **o que NÃO está decidido aqui** (valor concreto do `<path-secreto>` — comercial define; copy da página "Em breve" — STORY-028 define com input do comercial; secret de deploy concreto — STORY-031 cria).
- [ ] **CA-8:** A ADR é aceita por Alexandro (`approved_by: Alexandro`, `status: accepted`, `decided_at` preenchido) **antes** de qualquer estória 028+ entrar em sprint. PR mergeado.
- [ ] **CA-9:** `index.json` reflete: ADR-012 com `status: accepted` no array de decisions; esta estória (STORY-026) com `status: done`.

## Fora de escopo

- Implementar a topologia decidida — STORY-029 (Terraform), STORY-031 (firebase.json + workflow).
- Escrever a página "Em breve" — STORY-028.
- Importar a landing AS IS — STORY-030.
- Definir o valor concreto do `<path-secreto>` — fica com o comercial; ADR define **como** rotacionar, não **qual** path usar.
- Definir a copy da página "Em breve" — STORY-028 com input do marketing/comercial.
- Definir fronteira de responsabilidade marketing × engenharia × comercial em termos de processo — STORY-027 (PDR-015).
- Decidir basic-auth/IP allowlist para proteção real — fora do EPIC-006 (epic.md já marca como ampliação separada se o comercial pedir).

## Padrões de qualidade exigidos

Esta estória segue `docs/skills/arquiteto/references/architecture-principles.md`:

- **Reversibilidade (#7):** decisões da ADR-012 não amarram o produto a Firebase de forma irrecuperável — Hosting de estáticos com configuração declarativa é portável.
- **Simplicidade (#1):** preferir o caminho com menos peças móveis em todas as decisões; caminhos com Cloud Function/middleware têm que justificar custo + latência adicional.
- **Custo (#11):** evitar opções que adicionem linha de custo recorrente sem benefício claro (ex.: Cloud Function por requisição de gate).
- **Honestidade arquitetural:** declarar explicitamente as limitações (obfuscação, não segurança; cache pode esconder push do marketing por X minutos).
- **Documentação canônica:** ADR escrita no template oficial; nada decidido fora dela durante a janela desta estória.

## Dependências

- **Bloqueada por:** nada bloqueante. Aproveita ADR-004 (Firebase + Terraform + GitHub Actions) e estrutura existente do monorepo (`infra/modules/firebase`, `infra/modules/dns`, `.firebaserc`, `firebase.json`).
- **Bloqueia:** STORY-028 (página Em breve precisa saber se mora num site ou em dois), STORY-029 (Terraform precisa da topologia decidida), STORY-030 (scaffolding precisa da estrutura de pastas decidida), STORY-031 (firebase.json + workflow precisam do mecanismo de gate decidido).
- **Não bloqueia (pode rodar em paralelo):** STORY-027 (PDR-015 é decisão de processo/responsabilidade, independente da mecânica técnica).

## Decisões já tomadas (não as reabra)

- **ADR-004** — Firebase Hosting + Terraform + GitHub Actions + tag-based + gate humano em prod. Esta ADR herda integralmente, só ajusta namespace e número de sites.
- **ADR-003** — monorepo + deploy independente por path filter. `apps/landing/**` ganha path filter próprio.
- **PDR-003** — duas interfaces (WebApp + Backoffice); landing é **terceira superfície pública**, isolada.
- **epic.md do EPIC-006** — gate "Em breve" no apex; landing AS IS atrás de path secreto; `noindex` + `robots.txt Disallow`; novo Hosting site no mesmo projeto GCP `turni-mvp`; CTAs apontam para WebApp homolog (swap no cutover).
- **Honestidade sobre o gate** — obfuscação, não segurança; proteção real fica como ampliação separada.

## Liberdade técnica do agente

Você (arquiteto) decide:
- Mecânica concreta do gate (rotas explícitas vs. dois sites vs. middleware) — desde que justificada contra os trade-offs listados em §1.
- Estrutura concreta do `<path-secreto>` (commitado, build-time, alias+sufixo) — desde que justificada em §2.
- Estrutura concreta do 404, cache, sw.js, redirect www, swap CTA — desde que cada uma tenha no mínimo 2 opções avaliadas.
- Como expressar `CODEOWNERS` sem vazar path se a decisão de §2 for path não-commitado.
- Se uma decisão de detalhe pode ficar para a estória de implementação (registrar como "decisão deferida a STORY-XXX").

Você (arquiteto) NÃO decide:
- Reabrir ADR-004 (provedor, IaC, pipeline base).
- Reabrir o epic.md do EPIC-006 (escopo, fronteira marketing×engenharia, fora-de-escopo).
- Adicionar basic-auth/IP allowlist sem PR explícito do PO/comercial (epic.md marca como fora).
- Decidir o valor concreto do `<path-secreto>` (é decisão do comercial, fora do papel do arquiteto).

Se durante a execução você perceber que o epic.md está com lacuna real (ex.: pressuposto sobre www que não fecha), registre em "Notas do agente" com `[ESCALONAMENTO]` e mude `status: blocked`. Não decida sozinho ampliar o escopo.

## Definição de Pronto (DoD)

- [ ] Todos os CAs (CA-1 a CA-9) passam, com evidência observável.
- [ ] ADR-012 mergeada no `main` com `status: accepted` e `approved_by: Alexandro`.
- [ ] `index.json` atualizado.
- [ ] "Notas do agente" preenchida.

## Protocolo do agente (obrigatório)

Siga `docs/skills/arquiteto/SKILL.md` e `docs/skills/po/references/agent-task-format.md`. Resumo:

1. Frontmatter desta estória: `status: in_progress`, `owner_agent`, `updated_at`. Atualize `index.json`.
2. Leia todos os documentos canônicos listados em "Contexto" antes de propor.
3. Escreva ADR-012 em `status: proposed` no template oficial. Abra PR.
4. Aguarde aprovação do Alexandro; ajuste se pedido; mergeie com `status: accepted`.
5. Atualize `index.json` (ADR-012 e esta estória) e marque `status: done`. Preencha "Notas".

## Notas do agente (preenchido durante/após execução)

### Entrada inicial
(a preencher)

### Decisões tomadas
(a preencher — registrar cada uma das 9 decisões da ADR com a justificativa-chave)

### Descobertas
(a preencher)

### Bloqueios encontrados
(a preencher)

### Pendências para fechar (in_review → done)
(a preencher)

### Links de evidência
(a preencher — PR da ADR, commit de merge)
