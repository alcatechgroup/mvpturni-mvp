---
story_id: STORY-028
slug: pagina-em-breve-com-identidade-visual
title: Página "Em breve" institucional com identidade visual da landing
epic_id: EPIC-006
sprint_id: SPRINT-2026-W24-LANDING
type: implementation
target_role: programador
requires_design: true
design_screen_id: SCREEN-STORY-028-em-breve
status: ready
owner_agent: null
created_at: 2026-05-28
updated_at: 2026-05-28
estimated_session_size: S
---

# STORY-028 — Página "Em breve" institucional

> **Para o agente que vai executar:** leia esta estória por inteiro antes de começar. Ela contém tudo o que você precisa. Se algo estiver ambíguo, registre a dúvida na seção "Notas do agente" no final e pause em vez de adivinhar.

## Contexto (por que esta estória existe)

O epic.md do EPIC-006 fixa: o apex `turni.com.br/` e `www.turni.com.br` servem uma página "Em breve" enquanto o comercial não autoriza exposição pública da landing completa. Esta página é o **primeiro artefato novo** do épico (todo o resto da landing é AS IS importado do protótipo). Precisa:

1. Carregar **rápido** (Performance Lighthouse ≥ 90 em mobile 3G) — é a única coisa que a maioria dos visitantes vai ver.
2. **Respeitar a identidade visual da landing** — cores, tipografia, mark TURN**I.** — para que o visitante que volta após o go-public sinta continuidade.
3. **Não vazar a existência** do path secreto ou da landing — sem links, sem hint no HTML, sem comentários.
4. **Não capturar nada** — sem formulário, sem analytics, sem cookies. Página puramente institucional ("estamos chegando").
5. **Ser indexável** pelo Google — é o que o mundo deve encontrar para `site:turni.com.br`.

A página é construída por **engenharia** (epic.md, PDR-015 STORY-027) reaproveitando os tokens visuais que já vivem em `docs/prototipo/index.html` (CSS variables, fonts, logo SVG/inline). O **Designer** entrega um screen spec leve definindo layout final (provavelmente uma única tela — logo centralizado, mensagem, fundo). Marketing/comercial podem pedir ajuste de copy via PR depois — mas a primeira versão sai com copy mínima default validada pelo PO.

- Épico: `docs/project-state/epics/EPIC-006-landing-institucional/epic.md`
- Documentos canônicos a ler ANTES de codificar:
  - `epic.md` do EPIC-006 (seções "Resultado esperado" e "Entregável visível" — especialmente o que a "Em breve" deve **não** ter)
  - `docs/project-state/decisions/adr/ADR-012-landing-gate-em-breve-path-secreto.md` (decisão de mecânica do gate — define se "Em breve" mora em `apps/landing/public/index.html` ou em site separado)
  - `docs/prototipo/index.html` (fonte dos tokens visuais — extrair CSS variables `--logo-green`, `--black`, `--text`, fontes `Bebas Neue`, `Inter`, logo TURN**I.**)
  - `docs/project-state/design/system/tokens.md` (DDR-001 — Design System)
  - `docs/project-state/design/screens/SCREEN-STORY-028-em-breve.md` (a ser criado pelo Designer — ver nota abaixo)
  - `docs/skills/programador/SKILL.md`

## O quê (objetivo desta estória)

Entregar a página "Em breve" como artefato estático em `apps/landing/public/index.html` (ou no path equivalente que ADR-012 definir), com:

1. **HTML mínimo** — single-file (HTML + CSS inline ou em `<style>` no `<head>`; zero JS desnecessário; se ADR-012 não exigir, sem `manifest.json` nem `sw.js`).
2. **Layout**: logo TURN**I.** centralizado (vertical e horizontalmente), mensagem curta abaixo ("Em breve." ou copy aprovada pelo PO — ver §3), fundo na cor `--black` ou `--bg-cream` (decisão do Designer).
3. **Copy default**: "Em breve." (ou variante aprovada). Sem CTAs, sem link, sem botão. Footer mínimo com `© Turni · ${ano}` (opcional, decisão do Designer).
4. **Tokens visuais herdados** da landing AS IS: variáveis CSS `--logo-green: #00A868`, `--black: #000000`, `--bg-cream: #FAFAF7`, `--text: #0F1B2D`; fontes `Bebas Neue` (logo) e `Inter` (corpo) carregadas com `display=swap` e `preconnect` (mesmo padrão da landing — performance mobile).
5. **Meta tags institucionais**:
   - `<title>Turni</title>`
   - `<meta name="description" content="Turni — em breve.">` (ou copy aprovada)
   - `<meta name="theme-color" content="#00A868">`
   - **Sem** `noindex` aqui — esta página é indexável (epic.md).
   - Open Graph mínimo (`og:title`, `og:description`, `og:type=website`) para preview de compartilhamento decente.
6. **Acessibilidade WCAG AA**: contraste do texto ≥ 4.5:1; logo com `aria-label="Turni"`; navegação por teclado funciona (mesmo sem links interativos, foco visível se houver footer com link).
7. **Sem rastreamento**: sem GTM, sem Hotjar, sem pixel, sem cookies — declarado em `apps/landing/README.md` (STORY-030) e respeitado aqui.
8. **Performance**: Lighthouse Performance ≥ 90 em mobile 3G simulado (deve ser trivial dada a simplicidade — se não estiver, há algo errado).

## Por quê (valor para o usuário)

Direto: o visitante que digita `turni.com.br` no navegador vê uma página institucional bonita, em vez de erro DNS, página em branco, ou (pior) landing completa que o comercial ainda não liberou. Indireto: protege a narrativa de lançamento que o comercial está orquestrando; estabelece o tom visual antes mesmo da landing aparecer; sinaliza ao Google que `turni.com.br` é um site legítimo (não parking).

## Critérios de aceite

- [ ] **CA-1:** Arquivo `apps/landing/public/index.html` existe (ou no path equivalente decidido por ADR-012), self-contained, validado pelo W3C HTML validator (zero erros, warnings aceitáveis).
- [ ] **CA-2:** Renderiza visualmente conforme `SCREEN-STORY-028-em-breve.md`: logo TURN**I.** centralizado, mensagem aprovada pelo PO, fundo conforme decisão do Designer, tipografia `Bebas Neue` no logo e `Inter` no corpo.
- [ ] **CA-3:** Tokens CSS herdados da landing AS IS (`--logo-green`, `--black`, `--bg-cream`, `--text`) presentes; mudança de palette futura na landing reflete na "Em breve" sem refactor.
- [ ] **CA-4:** **Sem** referência a `<path-secreto>` no HTML servido (verificável com `grep -i '<path-secreto>' index.html` — zero matches). Nenhum link interno. Nenhum comentário HTML revelando estrutura.
- [ ] **CA-5:** **Sem** rastreamento: zero scripts de analytics, zero pixels, zero cookies setados, zero requisições para terceiros além das fontes do Google Fonts. Verificável com DevTools → Network e DevTools → Application → Cookies.
- [ ] **CA-6:** Meta tags institucionais presentes: `title`, `description`, `theme-color`, Open Graph mínimo. **Sem** `<meta name="robots" content="noindex">` (página é indexável).
- [ ] **CA-7:** Acessibilidade: Lighthouse Accessibility ≥ 95; contraste WCAG AA verificado nos elementos de texto; logo com `aria-label`; navegação por teclado funciona.
- [ ] **CA-8:** Performance: Lighthouse Performance ≥ 90 em mobile 3G simulado. Bundle total < 50KB (HTML + CSS inline + fontes — fontes preconnect/preload).
- [ ] **CA-9:** Tema funciona em claro/escuro respeitando `prefers-color-scheme` (decisão Designer: a página "Em breve" pode ter um único tema dark — coerente com o hero da landing AS IS que é preto — ou seguir DDR-001 dual; alinhar no sync).
- [ ] **CA-10:** Sync registrado em "Notas do agente": Designer entregou `SCREEN-STORY-028-em-breve.md` em `status: ready` antes da primeira linha de código; copy default aprovada pelo PO (Alexandro) antes do merge.

## Fora de escopo

- Routing/firebase.json/gate — STORY-031.
- Robots.txt e 404.html — STORY-030.
- Conteúdo da landing AS IS — STORY-030.
- Formulário de captura ("avisem-me quando lançar") — fora do EPIC-006 (epic.md marca em "fora de escopo").
- Analytics / GTM / pixel — fora do EPIC-006.
- Internacionalização — fora do EPIC-006.
- Animações sofisticadas, vídeo de background, partículas — fora; página é minimalista por construção.

## Padrões de qualidade exigidos

Esta estória segue `docs/skills/po/references/quality-standards.md`:

- **Acessibilidade (§5):** WCAG 2.1 AA mínimo. Lighthouse Accessibility ≥ 95.
- **Performance:** orçamento mobile 3G (alinhado com o que a landing AS IS já persegue — preconnect, display=swap, fontes críticas).
- **Privacidade:** sem coleta, sem cookies, sem rastreamento. Declarado e verificável.
- **Segurança:** CSP básica configurada no firebase.json (STORY-031); HTML não precisa de `<script>` arbitrário.
- **Verificação visual:** screenshot anexado na "Notas do agente" para PO conferir antes do merge.

## Dependências

- **Bloqueada por:** STORY-026 (ADR-012 decide onde mora o `index.html` — site único ou separado). Designer precisa de `SCREEN-STORY-028-em-breve.md` em `status: ready` antes da primeira linha de UI.
- **Bloqueia:** STORY-030 (scaffolding precisa do `index.html` da Em breve pronto para colocar na estrutura final), STORY-031 (firebase.json roteia para essa página no apex).
- **Pré-requisitos de ambiente:** nenhum (HTML estático, abrir em browser).

## Decisões já tomadas (não as reabra)

- **epic.md do EPIC-006** — "Em breve" é minimalista, sem CTAs, sem formulário, sem rastreamento; indexável; identidade visual herdada da landing AS IS.
- **DDR-001** — tokens do Design System (cores, tipografia).
- **PDR-013** — tema dual claro/escuro (decisão de aplicação na "Em breve" fica com o Designer).
- **PDR-015** — fronteira: engenharia é dona da Em breve; marketing pode pedir ajuste via PR.

## Liberdade técnica do agente

Você (programador) decide:
- Estrutura concreta do HTML (single-file vs. CSS externo — recomendação single-file dado tamanho).
- Se a fonte vem de Google Fonts ou self-hosted (Google Fonts é o padrão da landing AS IS — herdar).
- Como inline o logo (SVG inline vs. PNG vs. font-based como a landing AS IS faz — verificar e herdar).
- Mecanismo de centralização (flexbox vs. grid).
- Se inclui um footer minimalista (`© Turni · 2026`) ou não — decisão Designer.

Você (programador) NÃO decide:
- Adicionar formulário, CTA, link interno (epic.md proíbe).
- Adicionar rastreamento (PDR-015 implícito).
- Mudar copy sem aprovação do PO.
- Suprimir `<meta name="description">` ou Open Graph (necessário para indexação decente).

## Definição de Pronto (DoD)

- [ ] Todos os CAs (CA-1 a CA-10) passam.
- [ ] Lighthouse mobile rodado e screenshot anexado (Performance ≥ 90, Accessibility ≥ 95).
- [ ] Screenshot da página em mobile e desktop anexado para PO conferir.
- [ ] Sync Designer↔Programador registrado.
- [ ] `index.json` atualizado: status `in_review` ao abrir PR; `done` após merge.
- [ ] "Notas do agente" preenchida.

## Protocolo do agente (obrigatório)

Siga `docs/skills/programador/SKILL.md`. Resumo:

1. Frontmatter desta estória: `status: in_progress`, `owner_agent`, `updated_at`. Atualize `index.json`.
2. Confirme que `SCREEN-STORY-028-em-breve.md` existe em `docs/project-state/design/screens/` em `status: ready`. Se não, **PARE** e escale ao Designer.
3. Sync ≤15 min com Designer antes da primeira linha de UI.
4. Confirme copy default com PO (Alexandro) antes do merge.
5. Implemente, rode Lighthouse, capture screenshots, abra PR.
6. Ao mergear: `status: done`, "Notas" preenchidas, `index.json` atualizado.

## Notas do agente (preenchido durante/após execução)

### Entrada inicial
(a preencher)

### Sync Designer↔Programador
(a preencher — duração, decisões de UI, copy confirmada com PO)

### Decisões tomadas
(a preencher)

### Descobertas
(a preencher)

### Bloqueios encontrados
(a preencher)

### Resultado final / evidência
- Lighthouse mobile: (Performance / Accessibility / Best Practices / SEO)
- Screenshots: (mobile + desktop, claro + escuro se aplicável)
- URL de homolog: (após STORY-031 estar verde)

### Pendências para fechar
(a preencher)

### Links de evidência
(a preencher — commit, PR, run de Lighthouse)
