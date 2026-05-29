# apps/landing — Landing institucional `turni.com.br`

Este diretório serve a **landing institucional** do Turni em `turni.com.br` (e em
`landing.homolog.turni.com.br` na homologação). É um site **estático** servido por
Firebase Hosting, com deploy isolado do WebApp/API/Admin (ADR-003, ADR-004, ADR-012).

## Estrutura

```
apps/landing/
├── public/
│   ├── index.html        → página "Em breve" (apex /).  Dono: ENGENHARIA
│   ├── 404.html          → 404 institucional.            Dono: ENGENHARIA
│   ├── robots.txt        → template (path injetado no build). Dono: ENGENHARIA
│   └── _lp/              → landing AS IS completa.        Dono: MARKETING
│       ├── index.html
│       ├── img/
│       └── turnioficial_files/
├── README.md             → este arquivo.                 Dono: ENGENHARIA
└── CHANGELOG.md          → histórico de importação/adaptações. Dono: ENGENHARIA
```

> **Sobre `_lp/`:** é uma pasta-placeholder **estável e neutra**. O `<path-secreto>`
> real **não é commitado** — o workflow de deploy renomeia `_lp/` para o valor do
> secret `$FIREBASE_LANDING_PATH` em build-time (ADR-012 §2). Nem o repositório nem
> os clones locais contêm o path real. O `robots.txt` é gerado no build a partir do
> mesmo secret.

## Fronteira de propriedade (PDR-015 + CODEOWNERS)

A divisão de responsabilidade é materializada no `CODEOWNERS` da raiz e regida por
**PDR-015** (acordo de processo) sobre **ADR-012 §9** (mecânica):

| Caminho | Dono | O que pode mudar |
| --- | --- | --- |
| `public/_lp/**` | **Marketing** (`@turni/marketing`) | HTML/CSS/JS/copy/imagens da landing AS IS, sem revisão técnica de engenharia. |
| `public/index.html` ("Em breve"), `public/404.html`, `public/robots.txt`, `README.md`, `CHANGELOG.md`, `firebase.json`, `.firebaserc`, workflow de deploy, módulos Terraform | **Engenharia** (`@turni/engenharia`) | Página "Em breve", gate, infra de routing, pipeline. |

**A engenharia não modifica o conteúdo da landing AS IS** (`_lp/`), com duas exceções
declaradas em PDR-015 §1:

1. As **4 adaptações mecânicas** da importação inicial — aplicadas **uma vez** (ver
   `CHANGELOG.md`) e nunca mais.
2. **Remediação emergencial** (rollback / remoção de `sw.js`) se um push do marketing
   derrubar a landing ou criar risco de leak — restaurando o último estado bom, sem
   reescrever conteúdo. Toda intervenção é registrada (commit + nota no runbook).

## Como o marketing publica

O conteúdo de `_lp/` é editado pelo marketing via **PR** (aprovação por CODEOWNERS).
O deploy é **tag-based e isolado** (não dispara o pipeline do WebApp):

- Tag `landing-vX.Y.Z-rc.N` → deploy automático em homolog.
- Tag `landing-vX.Y.Z` (sem `-rc`) → exige aprovação humana no GitHub Environment
  `landing-prod`.

Detalhes do pipeline em **STORY-031**; procedimentos operacionais (publicar, rollback,
rotação de path, go-public) no **runbook** `docs/operacao/runbook-landing.md` (STORY-032).

## Como reportar um problema

Pelo canal combinado do time (PDR-015 §4/§7). Informe **o quê** quebrou e a **gravidade**
percebida (apex fora do ar ≠ um asset torto numa seção interna). SLA: **best-effort**,
sem on-call fora do horário de trabalho — o risco é estruturalmente baixo porque o deploy
é isolado, o rollback é um comando e a "Em breve" no apex não depende do conteúdo AS IS.

## Privacidade / rastreamento

A página **"Em breve"** (`public/index.html`) não captura nada: sem formulário, sem
analytics, sem cookies, sem rastreamento (EPIC-006). A landing AS IS (`_lp/`) carrega
fontes do Google Fonts e um ícone de `unpkg` (dns-prefetch); qualquer adição de
rastreamento ali é decisão de marketing/produto fora do escopo do EPIC-006.

## Decisões de referência

- **ADR-012** — gate "Em breve", path secreto, topologia Firebase, cache, `sw.js`, CODEOWNERS.
- **PDR-015** — fronteira marketing × engenharia × comercial; SLA; rotação; go-public.
- **EPIC-006** — `docs/project-state/epics/EPIC-006-landing-institucional/epic.md`.
