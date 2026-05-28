---
story_id: STORY-030
slug: scaffolding-apps-landing-import-as-is-adaptacoes-minimas
title: Scaffolding apps/landing/ — import AS IS da landing + 4 adaptações mínimas + robots/404/README/CODEOWNERS
epic_id: EPIC-006
sprint_id: SPRINT-2026-W24-LANDING
type: implementation
target_role: programador
requires_design: false
status: ready
owner_agent: null
created_at: 2026-05-28
updated_at: 2026-05-28
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

- [ ] **CA-1:** Estrutura de pastas `apps/landing/public/...` criada conforme listado em §1 do "O quê". `tree apps/landing/` mostra o resultado.
- [ ] **CA-2:** `apps/landing/public/<path-secreto>/index.html` é cópia AS IS de `docs/prototipo/index.html` **+ as 4 adaptações**, nada mais. `diff` entre os dois mostra apenas: (a) reescrita dos 14 hrefs `app.html#/...`, (b) inserção da meta tag noindex, (c) zero mudanças de copy/CSS/JS/imagem. Diff anexado ao PR para revisão visual.
- [ ] **CA-3:** Todos os assets referenciados no HTML importado existem no path correto. Validador: `curl-equivalente local` (ex: servir com `python -m http.server` em `apps/landing/public/<path-secreto>/`) e verificar zero 404 no Network tab do DevTools navegando a página.
- [ ] **CA-4:** `app.html` **não** foi copiado: `ls apps/landing/public/<path-secreto>/app.html` retorna "no such file".
- [ ] **CA-5:** Adaptação A1 verificada: `grep -n 'href="app.html' apps/landing/public/<path-secreto>/index.html` retorna 0 matches; `grep -n 'href="https://app.homolog.turni.com.br/#/' apps/landing/public/<path-secreto>/index.html` retorna 14 matches (ou número equivalente decidido em ADR-012 se foi placeholder).
- [ ] **CA-6:** Adaptação A3 verificada: `<meta name="robots" content="noindex,nofollow">` presente no `<head>` do `index.html` da landing AS IS (e **não** presente na "Em breve" — CA-6 da STORY-028 cruza).
- [ ] **CA-7:** `apps/landing/public/robots.txt` existe com conteúdo conforme §7 (ou equivalente decidido em ADR-012). `curl https://turni-landing-homolog.web.app/robots.txt` (após STORY-031 deployar) retornará o conteúdo.
- [ ] **CA-8:** `apps/landing/public/404.html` existe, na identidade visual da landing, **sem** link para `<path-secreto>`, **com** link para `/`.
- [ ] **CA-9:** `apps/landing/README.md` existe, descreve a estrutura, referencia PDR-015 e CODEOWNERS, **não** vaza o `<path-secreto>`.
- [ ] **CA-10:** `CODEOWNERS` da raiz atualizado conforme PDR-015 + ADR-012. Patterns testáveis com `gh api ... codeowners` ou ferramenta equivalente.
- [ ] **CA-11:** `apps/landing/CHANGELOG.md` criado com entrada datada da importação.
- [ ] **CA-12:** Verificação não-leak: `grep -rn "<valor-real-do-path-secreto>" apps/landing/public/index.html apps/landing/public/404.html apps/landing/README.md apps/landing/CHANGELOG.md` retorna 0 matches.
- [ ] **CA-13:** PR revisado pelo PO (e por marketing se PDR-015 exigir co-aprovação na importação inicial — verificar). Confirmar visualmente que o diff só contém as 4 adaptações declaradas.

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

- [ ] Todos os CAs (CA-1 a CA-13) passam.
- [ ] Diff cirúrgico anexado ao PR; PO confirma visualmente que só as 4 adaptações estão lá.
- [ ] Tree `apps/landing/` anexado em "Notas".
- [ ] CODEOWNERS testado.
- [ ] `index.json` atualizado: `in_review` ao abrir PR; `done` após merge.
- [ ] "Notas do agente" preenchida.

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
(a preencher)

### Decisões tomadas
(a preencher — ex: posição da meta robots, formato do CODEOWNERS)

### Descobertas
(a preencher — ex: assets externos detectados no HTML AS IS; comportamento atual do sw.js)

### Bloqueios encontrados
(a preencher)

### Resultado final / evidência
- `tree apps/landing/`: (saída)
- Diff resumido: (linhas afetadas pelas 4 adaptações)
- `grep` de não-leak: (saídas)
- CODEOWNERS testado: (link/output)

### Pendências para fechar
(a preencher)

### Links de evidência
(a preencher — commits, PR)
