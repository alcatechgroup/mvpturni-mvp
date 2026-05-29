---
story_id: STORY-030
slug: scaffolding-apps-landing-import-as-is-adaptacoes-minimas
title: Scaffolding apps/landing/ — import AS IS da landing + 4 adaptações mínimas + robots/404/README/CODEOWNERS
epic_id: EPIC-006
sprint_id: SPRINT-2026-W24-LANDING
type: implementation
target_role: programador
requires_design: false
status: done
owner_agent: claude-opus-4-8-programador-2026-05-29
created_at: 2026-05-28
updated_at: 2026-05-29
estimated_session_size: M
---

# STORY-030 — Scaffolding apps/landing/ + import AS IS + adaptações mínimas

> **Para o agente que vai executar:** leia esta estória por inteiro antes de começar. Ela contém tudo o que você precisa. Se algo estiver ambíguo, registre a dúvida na seção "Notas do agente" no final e pause em vez de adivinhar.

## Contexto (por que esta estória existe)

A landing AS IS vive hoje em `docs/prototipo/index.html` — dentro do diretório de protótipos, fora de qualquer pipeline de deploy. Esta estória traz a landing para a estrutura oficial do monorepo (`apps/landing/`), aplica as **4 adaptações mecânicas obrigatórias** declaradas no epic.md (e nunca mais — qualquer mudança posterior é responsabilidade do marketing via PR), e cria os arquivos institucionais que materializam a fronteira de PDR-015 (`CODEOWNERS`, `README.md`, `robots.txt`, `404.html`).

A estória é puramente mecânica em termos de transformação de arquivos, mas exige **disciplina cirúrgica**: qualquer adaptação além das 4 listadas é violação do contrato AS IS. Não "consertar typo", não "melhorar HTML semântico", não "atualizar imagens para WebP", não "adicionar lazy loading". Marketing é dono — engenharia importa e para.

A estória é **M** (não S) porque inclui o scaffolding completo da pasta `apps/landing/`, a árvore de assets da landing (manifest, sw.js, tour.css, tour.js, img/, turnioficial_files/), o `robots.txt`, o `404.html` institucional, o `README.md` da pasta explicando a fronteira, e o `CODEOWNERS` da raiz dividido conforme PDR-015. É volume mecânico, não complexidade.

- Épico: `docs/project-state/epics/EPIC-006-landing-institucional/epic.md`
- Documentos canônicos a ler ANTES de codificar:
  - `epic.md` do EPIC-006 (seções "Entregável visível" e "Adaptação mínima permitida" — fonte da verdade sobre o que pode e não pode mudar)
  - `docs/project-state/decisions/adr/ADR-012-landing-gate-em-breve-path-secreto.md` (decide estrutura de pastas: `apps/landing/public/<path-secreto>/` vs. subdomínio; decide destino do `sw.js`; decide política do CODEOWNERS)
  - `docs/project-state/decisions/pdr/PDR-015-fronteira-marketing-engenharia-comercial-landing.md` (acordo de processo que CODEOWNERS materializa)
  - `docs/prototipo/index.html` (fonte AS IS)
  - `docs/prototipo/` (árvore completa de assets — `manifest.json`, `sw.js`, `tour.css`, `tour.js`, `img/`, `turnioficial_files/`)
  - `docs/skills/programador/SKILL.md`

## O quê (objetivo desta estória)

Entregar a estrutura de `apps/landing/` pronta para o pipeline da STORY-031:

1. **Criar a estrutura de pastas** conforme decidido em ADR-012:
   - `apps/landing/public/index.html` (página "Em breve" — deve ter sido entregue por STORY-028 e movida/copiada para cá; coordenar com a STORY-028 se houver conflito de path).
   - `apps/landing/public/<path-secreto>/index.html` (landing AS IS).
   - `apps/landing/public/<path-secreto>/img/`, `apps/landing/public/<path-secreto>/turnioficial_files/` (assets referenciados pelo HTML).
   - `apps/landing/public/<path-secreto>/tour.css`, `apps/landing/public/<path-secreto>/tour.js` (se referenciados; verificar).
   - `apps/landing/public/<path-secreto>/manifest.json` (se referenciado e ADR-012 não decidiu remover).
   - `apps/landing/public/<path-secreto>/sw.js` (se ADR-012 decidiu manter; sem se decidiu remover).
   - `apps/landing/public/robots.txt` com `User-agent: *` + `Disallow: /<path-secreto>/`.
   - `apps/landing/public/404.html` institucional na identidade da landing (logo TURN**I.**, mensagem "página não encontrada", sem link para o path secreto — mesma identidade visual da "Em breve").
   - `apps/landing/README.md` explicando a fronteira (referenciando PDR-015).
2. **Importar a landing AS IS** copiando `docs/prototipo/index.html` para `apps/landing/public/<path-secreto>/index.html` e os assets referenciados para suas subpastas. **Não copiar** `docs/prototipo/app.html` (pertence ao protótipo do WebApp, fora de escopo).
3. **Aplicar as 4 adaptações mecânicas obrigatórias** ao HTML importado, e **apenas elas**:
   - **A1 — Reescrever CTAs:** todos os `href="app.html#/..."` viram `href="https://app.homolog.turni.com.br/#/..."` (ou via placeholder build-time se ADR-012 decidiu por substituição). Procurar com `grep -n 'href="app.html' apps/landing/public/<path-secreto>/index.html` antes e depois — esperado 0 matches do padrão antigo após a adaptação. Lista esperada (do mapeamento feito durante a redação do épico, 14 ocorrências em `docs/prototipo/index.html`): linhas 2497, 2498, 2604, 2623, 2920, 2966, 3192, 3212, 3232, 3242, 3544, 3562, 3580, 3592, 3692 do arquivo original. Validar que todas foram cobertas.
   - **A2 — Excluir referências a `app.html`:** confirmar que `app.html` não foi copiado e que nenhum asset da landing aponta para `./app.html` por caminho relativo.
   - **A3 — Injetar `<meta name="robots" content="noindex,nofollow">`** no `<head>` do `index.html` da landing AS IS. Posição: logo após `<meta name="viewport">` ou onde for menos intrusivo. Documentar a linha exata no diff.
   - **A4 — Headers de cache e segurança:** este item é executado em `firebase.json` na STORY-031, não aqui no HTML. Esta estória apenas **não bloqueia** A4 (não introduz nada que conflite com headers configuráveis).
4. **Criar `apps/landing/README.md`** com:
   - Propósito: "este diretório serve a landing institucional `turni.com.br`".
   - Estrutura: explicar `index.html` (Em breve, engenharia) vs. `<path-secreto>/` (landing AS IS, marketing) vs. `robots.txt` / `404.html` (engenharia).
   - Fronteira: referenciar PDR-015 e CODEOWNERS.
   - Como o marketing publica: PR + workflow tag-based (referenciar STORY-031/runbook STORY-032).
   - Como reportar problema: canal de comunicação acordado em PDR-015.
   - **Sem** vazar o `<path-secreto>` no README (se ADR-012 decidiu path não-commitado, README usa placeholder `<path-secreto>` literal).
5. **Atualizar `CODEOWNERS`** na raiz do monorepo conforme PDR-015 e ADR-012:
   - Path da landing AS IS → marketing (alias decidido em PDR-015).
   - `apps/landing/public/index.html`, `apps/landing/public/404.html`, `apps/landing/public/robots.txt`, `apps/landing/README.md`, `firebase.json`, `.firebaserc` → engenharia.
   - Workflow `.github/workflows/landing-deploy.yml` (criado em STORY-031) → engenharia.
   - Se path secreto não-commitado, usar wildcard `apps/landing/public/*/` ou estratégia equivalente decidida em ADR-012.
6. **Criar `apps/landing/public/404.html`** institucional: estilo similar à página "Em breve" (logo + mensagem "página não encontrada"), **sem** link para o `<path-secreto>`, **com** link de volta para `/` (apex).
7. **Criar `apps/landing/public/robots.txt`** mínimo:
   ```
   User-agent: *
   Disallow: /<path-secreto>/
   ```
   (Se ADR-012 decidiu mecânica diferente — ex.: subdomínio dedicado — adaptar; o robots.txt deve refletir a estrutura real.)
8. **Verificar não-leak**: `grep -rn "<path-secreto>" apps/landing/public/index.html apps/landing/public/404.html apps/landing/README.md` deve retornar 0 matches (página "Em breve", 404 e README **não** podem revelar o path real).
9. **Documentar a importação** em `apps/landing/CHANGELOG.md` (criar) com entrada datada: "Importação AS IS de docs/prototipo/index.html. 4 adaptações mecânicas aplicadas (A1 CTAs, A2 sem app.html, A3 noindex, A4 placeholder de headers). Linhas afetadas: ...".

## Por quê (valor para o usuário)

Indireto: cria a estrutura de pastas e arquivos institucionais que a STORY-031 vai deployar; materializa fisicamente a fronteira de PDR-015 (CODEOWNERS + README); garante que a landing AS IS migra para o monorepo **sem desvio do contrato AS IS** (qualquer engenheiro futuro que olhar o diff vê exatamente as 4 adaptações e nada mais).

Direto: nada de visível para o usuário final ainda — STORY-031 conecta isso ao Firebase Hosting e torna acessível em homolog.

## Critérios de aceite

- [x] **CA-1:** Estrutura de pastas `apps/landing/public/...` criada conforme listado em §1 do "O quê". `tree apps/landing/` mostra o resultado.
- [x] **CA-2:** `apps/landing/public/<path-secreto>/index.html` é cópia AS IS de `docs/prototipo/index.html` **+ as 4 adaptações**, nada mais. `diff` entre os dois mostra apenas: (a) reescrita dos 14 hrefs `app.html#/...`, (b) inserção da meta tag noindex, (c) zero mudanças de copy/CSS/JS/imagem. Diff anexado ao PR para revisão visual.
- [x] **CA-3:** Todos os assets referenciados no HTML importado existem no path correto. Validador: `curl-equivalente local` (ex: servir com `python -m http.server` em `apps/landing/public/<path-secreto>/`) e verificar zero 404 no Network tab do DevTools navegando a página.
- [x] **CA-4:** `app.html` **não** foi copiado: `ls apps/landing/public/<path-secreto>/app.html` retorna "no such file".
- [x] **CA-5:** Adaptação A1 verificada: `grep -n 'href="app.html' apps/landing/public/<path-secreto>/index.html` retorna 0 matches; `grep -n 'href="https://app.homolog.turni.com.br/#/' apps/landing/public/<path-secreto>/index.html` retorna 14 matches (ou número equivalente decidido em ADR-012 se foi placeholder).
- [x] **CA-6:** Adaptação A3 verificada: `<meta name="robots" content="noindex,nofollow">` presente no `<head>` do `index.html` da landing AS IS (e **não** presente na "Em breve" — CA-6 da STORY-028 cruza).
- [x] **CA-7:** `apps/landing/public/robots.txt` existe com conteúdo conforme §7 (ou equivalente decidido em ADR-012). `curl https://turni-landing-homolog.web.app/robots.txt` (após STORY-031 deployar) retornará o conteúdo.
- [x] **CA-8:** `apps/landing/public/404.html` existe, na identidade visual da landing, **sem** link para `<path-secreto>`, **com** link para `/`.
- [x] **CA-9:** `apps/landing/README.md` existe, descreve a estrutura, referencia PDR-015 e CODEOWNERS, **não** vaza o `<path-secreto>`.
- [x] **CA-10:** `CODEOWNERS` da raiz atualizado conforme PDR-015 + ADR-012. Patterns testáveis com `gh api ... codeowners` ou ferramenta equivalente.
- [x] **CA-11:** `apps/landing/CHANGELOG.md` criado com entrada datada da importação.
- [x] **CA-12:** Verificação não-leak: `grep -rn "<valor-real-do-path-secreto>" apps/landing/public/index.html apps/landing/public/404.html apps/landing/README.md apps/landing/CHANGELOG.md` retorna 0 matches.
- [x] **CA-13:** PR revisado pelo PO (e por marketing se PDR-015 exigir co-aprovação na importação inicial — verificar). Confirmar visualmente que o diff só contém as 4 adaptações declaradas.

## Fora de escopo

- `firebase.json` com rotas explícitas (gate em si) — STORY-031.
- Workflow GitHub Actions de deploy — STORY-031.
- Página "Em breve" (construção) — STORY-028. Esta estória recebe ela pronta.
- Sites Firebase ou DNS — STORY-029.
- Runbook — STORY-032.
- Qualquer melhoria, refator ou "limpeza" do HTML/CSS/JS/imagem da landing — proibido pelo contrato AS IS.
- Otimização de imagens (WebP, compressão) — proibido AS IS.
- Lazy loading, intersection observers, refactor de JS — proibido AS IS.

## Padrões de qualidade exigidos

Esta estória segue `docs/skills/po/references/quality-standards.md`, **mas com particularidade**:

- **Cobertura de teste:** **isenta** — esta estória copia conteúdo de terceiros (marketing) sem lógica de negócio. Teste é a verificação manual dos CAs e o diff revisado.
- **CI verde:** linter mínimo de HTML (W3C validator ou `htmlhint`) roda no PR e deve estar verde (ou warnings só nas partes AS IS, documentadas como "herdadas do marketing").
- **LGPD/segurança:** o HTML AS IS pode ter scripts/recursos externos (Google Fonts, possivelmente analytics se já estava no protótipo). Esta estória não muda isso — registra em "Notas do agente" o que foi observado para PDR/ADR futura tratar se necessário.
- **Disciplina AS IS:** a maior qualidade desta estória é o que ela **não** faz. Diff cirúrgico é o entregável de qualidade.

## Dependências

- **Bloqueada por:** STORY-026 (ADR-012 decide estrutura de pastas, destino do sw.js, política de CODEOWNERS), STORY-027 (PDR-015 define CODEOWNERS materializado aqui), STORY-028 (página "Em breve" recebida pronta — se ainda não estiver, esta estória cria placeholder e STORY-028 substitui em sequência).
- **Bloqueia:** STORY-031 (workflow precisa do conteúdo em `apps/landing/public/` para deployar), STORY-032 (runbook documenta a estrutura criada aqui), STORY-033 (validador verifica fronteira efetiva).

## Decisões já tomadas (não as reabra)

- **epic.md do EPIC-006** — 4 adaptações mínimas declaradas; landing AS IS intocável além delas; marketing dono do conteúdo; engenharia dona da infra/Em breve/CODEOWNERS.
- **ADR-012** — estrutura de pastas, destino do sw.js, mecânica do CODEOWNERS.
- **PDR-015** — acordo de fronteira (CODEOWNERS materializa).
- **STORY-016** (EPIC-001) — WebApp em `app.homolog.turni.com.br` é o destino dos CTAs.

## Liberdade técnica do agente

Você (programador) decide:
- Ordem dos commits (sugestão: 1 commit por adaptação para diff revisável).
- Ferramenta de import (cp manual, script bash, etc.) — desde que reproduzível.
- Formato exato do CHANGELOG (markdown simples).
- Posição exata da meta robots no `<head>` — desde que justificada (logo após viewport é razoável).
- Como expressar wildcard em CODEOWNERS se path não-commitado.

Você (programador) NÃO decide:
- Aplicar uma adaptação que não está nas 4 listadas (escalar como `[ESCALONAMENTO]` se acreditar que precisa).
- Mudar copy, CSS, JS, imagem da landing AS IS.
- Mudar nomes de arquivos da árvore importada (preservar AS IS — `manifest.json`, `sw.js`, `tour.css`, etc.).
- Decidir o valor concreto do `<path-secreto>` (comercial define).
- Mergeear sem revisão visual do PO no diff (CA-13).

## Definição de Pronto (DoD)

- [x] Todos os CAs (CA-1 a CA-13) passam.
- [x] Diff cirúrgico revisado; PO confirmou visualmente (no diff e na landing servida) que só as 4 adaptações estão lá (2026-05-29).
- [x] Tree `apps/landing/` registrado em "Notas".
- [x] CODEOWNERS aplicado (11 regras, ADR §9 + aliases PDR-015).
- [x] `index.json` atualizado: `done` (workflow Turni: commit direto na main = merge; sem PR).
- [x] "Notas do agente" preenchida.

## Protocolo do agente (obrigatório)

Siga `docs/skills/programador/SKILL.md`. Resumo:

1. Frontmatter desta estória: `status: in_progress`, `owner_agent`, `updated_at`. Atualize `index.json`.
2. Confirme ADR-012 + PDR-015 `accepted`; confirme STORY-028 entregue (ou crie placeholder).
3. Importação + 4 adaptações em commits separados.
4. CODEOWNERS, README, robots.txt, 404.html, CHANGELOG em commits separados.
5. Abra PR; aguarde revisão visual do PO; mergeie.
6. Atualize `index.json`. Marque `status: done`.

## Notas do agente (preenchido durante/após execução)

### Entrada inicial
Lidos: esta estória inteira; `epic.md` do EPIC-006; **ADR-012** (accepted — fixa estrutura `_lp/`, destino do sw.js, CTA via `__WEBAPP_URL__`, CODEOWNERS por placeholder); **PDR-015** (accepted — fronteira marketing×engenharia×comercial, aliases `@turni/marketing`/`@turni/engenharia`); `docs/prototipo/index.html` + árvore de assets; `docs/skills/programador/SKILL.md`.

Reconciliação importante com ADR-012 (a estória previa deferir): o enunciado original falava em `<path-secreto>` e em reescrever CTAs para `https://app.homolog...`. ADR-012 §2(b) decidiu **pasta-placeholder neutra `_lp/`** (path real injetado em build-time, nunca commitado) e §7 decidiu **CTA via placeholder `__WEBAPP_URL__`** (não host hardcoded). Segui ADR-012, como a própria estória manda (A1 linha 54 e CA-5 deferem ao ADR).

### Decisões tomadas
- **`manifest.json` dropado** (+ remoção da `<link rel="manifest">`): é o manifest PWA do WebApp (`start_url`/shortcuts → `app.html`); a landing não é PWA (ADR-012 §5). Tratado dentro da **A2** (eliminar refs a `app.html`). **Aprovado pelo PO Alexandro em 2026-05-29.**
- **Não copiados** (artefatos do WebApp): `app.html`, `sw.js` (ADR §5; o `index.html` da landing não registrava SW — remoção = só não-cópia), `tour.css`/`tour.js` (não referenciados pelo `index.html`).
- **Assets copiados verbatim**: `img/` (52) e `turnioficial_files/` (8) inteiros — garante paridade total com o protótipo, sem depender de enumeração perfeita de `url()` em CSS.
- **Posição da meta robots (A3):** logo após `<meta name="viewport">` (head, menos intrusivo).
- **`robots.txt` template** com token `__LANDING_PATH__` (build injeta o secret) — não vaza path.
- **CTA placeholder:** `app.html#/...` → `__WEBAPP_URL__/#/...` (ADR §7).
- **CODEOWNERS** na raiz, patterns da ADR §9 + aliases PDR-015. Comentário registra que os times do GitHub podem não existir ainda (vira documentação de intenção até serem criados — não-bloqueante por PDR-015).
- **Import reproduzível** via `cp` + `perl -pi` (registrado no CHANGELOG).

### Descobertas
- **`index.html` da landing NÃO registra service worker** (grep `serviceWorker|register(` = 0); o `sw.js` só é usado pelo `app.html`. Remover o SW (ADR §5) é trivial: não copiar o arquivo.
- **`manifest.json` aponta para `app.html`** (`start_url: "./app.html"` + 2 shortcuts) — é o manifest do WebApp, não da landing.
- **`tour.css`/`tour.js`** não são referenciados pelo `index.html` (são do onboarding do WebApp).
- **Recursos externos AS IS**: Google Fonts (`fonts.googleapis.com`/`fonts.gstatic.com` via `turnioficial_files/fonts.css` com `@font-face`), `dns-prefetch` para `unpkg.com` (sem load efetivo), `lucide.js` local. Nenhum analytics/pixel; sem cookies setados pelo HTML. Registrado p/ a CSP da STORY-031.
- **Trailing newline**: o protótipo não terminava com `\n`; o processamento de texto adicionou um `\n` no EOF do `_lp/index.html`. Byte benigno, não-conteúdo, documentado no CHANGELOG.

### Bloqueios encontrados
- Decisão do `manifest.json` (5ª adaptação? ou dentro da A2?) — escalada ao PO; resolvida (dropar, dentro da A2).

### Resultado final / evidência
- **`tree apps/landing/`:** `public/index.html` (Em breve, STORY-028), `public/404.html`, `public/robots.txt`, `public/_lp/{index.html,img/ (52),turnioficial_files/ (8)}`, `README.md`, `CHANGELOG.md`, `firebase.json` (stub STORY-029); `CODEOWNERS` na raiz.
- **CA-2 diff cirúrgico:** com os 15 hrefs A1 revertidos, o diff `_lp/index.html` vs `docs/prototipo/index.html` mostra **só** A3 (`+<meta robots noindex>`) e A2 (`-<link rel=manifest>`) — o resto é byte-idêntico. Provado.
- **CA-5 (A1):** `grep 'href="app.html'` = 0; `grep 'href="__WEBAPP_URL__/#/'` = 15 (3 `/cadastro`, 5 `/cadastro/emp`, 5 `/cadastro/wkr`, 2 `/login`).
- **CA-6 (A3):** `<meta name="robots" content="noindex,nofollow">` presente no `_lp/index.html`; **ausente** no `public/index.html` (Em breve) — cruza com CA-6 da STORY-028.
- **CA-3:** servido com `python -m http.server`; todos os 6 refs locais únicos → 200 (zero 404). Assets copiados verbatim.
- **CA-4:** `ls _lp/app.html` → no such file.
- **Render real (Playwright/Chromium):** landing completa renderiza fiel ao protótipo (hero split, seções narrativas, planos, depoimentos, parceiros, footer; fontes/imagens/ícones OK) em desktop 1280 e mobile 390 (full-page 390×10580). 404 renderiza na identidade da landing (a11y 100, contraste PASS, link `/`).
- **CA-12 não-leak:** path real nunca commitado (pasta `_lp/`); `index.html`/`404.html` sem refs a `_lp`.
- **CA-10 CODEOWNERS:** 11 regras; padrão da ADR §9.
- **CA-13:** revisão visual do PO (Alexandro) na landing servida localmente — **aprovado em 2026-05-29**.

### Pendências para fechar
- [x] Revisão visual do PO no diff + na landing renderizada (CA-13) — aprovado 2026-05-29.
- [ ] Validação `curl` do gate/robots/404 contra URL servida pelo Firebase — gated em STORY-031 (workflow + firebase.json com rotas explícitas) e absorvida pela STORY-033.

### Links de evidência
(commit a preencher no fechamento)
