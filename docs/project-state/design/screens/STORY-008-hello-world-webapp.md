---
id: SCREEN-STORY-008-hello-world-webapp
story: STORY-008-hello-world-webapp
epic: EPIC-000-foundation
status: ready
created_at: 2026-05-27
updated_at: 2026-05-27
owner_designer: claude-opus-designer-2026-05-27
related_ddrs: [DDR-001]
ds_components_used: [brand.logo, surface.card, link.text]
exceptions_to_ds: []
viewports: [mobile, desktop]
---

# Spec de tela — Página de boas-vindas do WebApp

> Referência: estória `STORY-008-hello-world-webapp` (CAs e contexto vêm de lá — **não duplico**). Fundação visual: `DDR-001` + `docs/project-state/design/system/`.
> Princípios que dirigiram: #1 (simplicidade radical — a tela faz **uma** coisa), #3 (tom profissional), #5 (acessibilidade), #6 (performance percebida — sem dado remoto, FCP rápido).

## 1. Objetivo da tela

Provar publicamente que **o WebApp do Turni está no ar**: identifica a marca, mostra a versão do build e oferece um caminho visível para o status do sistema (`/health`). É placeholder digno — não a UI final do produto.

**Tema e esquema (DDR-001):** rota **pré-login** → usa o **esquema neutro = perfil profissional (verde)**, como o login do protótipo. **Tema claro por padrão**, com suporte a escuro via `prefers-color-scheme` (o WebApp espelha o `initTheme()` do protótipo). O acento interativo (link) é o `accent` do esquema profissional: `#2D5F3F` no claro, `#5FA37C` no escuro.

## 2. Fluxo

### Entrada
- Usuário abre `app.homolog.turni.com.br/` (digitado, link, ou PWA instalado).
- Nada precisa ser verdade antes: **sem sessão, sem dado remoto**. A página é estática; versão vem do build (mecanismo de STORY-007).

### Ações possíveis na tela
- **Ação primária:** abrir o status do sistema — `link.text` "Ver status do sistema" → navega para `/health`.
- Secundárias: nenhuma nesta fase.

### Saída
- Após clicar no link: navega para `/health` (resposta JSON 200 — fora deste spec, é CA-6 da estória).
- Sem erro recuperável na própria tela (é estática); ver §4.4 para o caso de versão ausente.

## 3. Layout

### Mobile (≥360px)

```
+--------------------------------+
|                                |
|            (respiro)           |
|                                |
|         TURNI.                 |   ← brand.logo, display (≥48px)
|                                |
|   Hospitalidade on-demand      |   ← subtitle, text.muted
|                                |
|   Match · PIN · Pix em 15min   |   ← body-sm, text.muted (eyebrow opcional)
|                                |
|   ────────────────────────     |   ← divisor border.subtle
|                                |
|   Ver status do sistema  →     |   ← link.text (primary), alvo ≥48dp
|                                |
|                                |
|   versão v0.1.0-rc.3           |   ← caption/overline, text.muted (rodapé)
+--------------------------------+
```

- Componentes do DS: `brand.logo`, `link.text`. Container central opcional como `surface.card` em telas largas (ver desktop).
- Conteúdo **centralizado vertical e horizontalmente**, coluna única, largura máxima ~360–420px com padding lateral `space.lg`.
- Fundo `surface.page` (claro `#F7F4EC` / escuro `#0F1411`). Sem imagem pesada (orçamento 3G, CA-5).
- Alvo de toque do link ≥48dp (padding generoso, não só o texto).

### Desktop (≥1024px)

```
+----------------------------------------------------+
|                                                    |
|                                                    |
|              +--------------------------+          |
|              |                          |          |
|              |        TURNI.            |          |  ← surface.card opcional,
|              |  Hospitalidade on-demand |          |    centralizado, largura
|              |  Match · PIN · Pix 15min |          |    máx ~480px
|              |  ──────────────────────  |          |
|              |  Ver status do sistema → |          |
|              +--------------------------+          |
|                                                    |
|                   versão v0.1.0-rc.3               |  ← rodapé centralizado
+----------------------------------------------------+
```

- **Não é "mobile esticado":** o conteúdo **não** estica para a largura toda. Largura útil limitada (`bp.extraLarge` regra: não estique) — o respiro extra vira margem, não texto largo. Card central (`surface.card`, `elev.1`, `radius.lg`) dá foco.
- Mesmos componentes; a única diferença é o card e o respiro maior (`space.3xl` vertical).

### Tablet (≥600px)
- Sem comportamento novo relevante: herda mobile (coluna única centrada) ganhando o card a partir de ~768px. Não requer layout próprio.

## 4. Estados

> Tela estática, sem fetch remoto → o leque de estados é pequeno. Cubro os aplicáveis e declaro explicitamente os não-aplicáveis.

### 4.1. Caminho feliz (preenchido)
Marca + subtítulo + pilares + link + versão, conforme §3. Microcopy completo em §5.

### 4.2. Loading
- **Não aplicável como skeleton de dados** (não há dado remoto). A página é o primeiro paint. Meta: FCP ≤5s em 3G (CA-5).
- O **service worker** (CA-12) serve a casca em revisita (cache-first para assets). Sem spinner em tela branca em nenhum momento.

### 4.3. Vazio
- Não aplicável — não há lista/coleção.

### 4.4. Erro

| Tipo | Tratamento |
|---|---|
| **Versão indisponível** (build não injetou a tag) | A linha de versão exibe o fallback **"versão indisponível"** em `text.muted` — a página **não quebra** por isso. Não é erro de tela. |
| **Erro inesperado de render** | Fora do escopo de design: é página estática mínima; se nem isso renderiza, é falha de infra (coberta por `/health` não-200, CA-7), não um estado desta UI. |
| Erro de rede | Não aplicável — não há requisição na tela (o link para `/health` é navegação, não fetch inline). |

### 4.5. Sem permissão
- Não aplicável — rota pública, sem auth (ADR-007: `/` do WebApp é pública nesta fase).

### 4.6. Parcial / degradado
- Único caso: versão ausente → §4.4 (degrada com fallback, resto intacto).

### 4.7. Primeira vez vs recorrente
- Não aplicável — sem onboarding nesta fase.

## 5. Microcopy completo

| Lugar | Texto |
|---|---|
| Marca (logo) | `TURNI.` (logomarca — leitor de tela anuncia "Turni") |
| Subtítulo | Hospitalidade on-demand |
| Linha de pilares | Match · PIN · Pix em 15 min |
| Link primário | Ver status do sistema |
| Rodapé — versão (ok) | versão {versao}  (ex.: `versão v0.1.0-rc.3`) |
| Rodapé — versão (ausente) | versão indisponível |

- Tom: sóbrio, sem exclamação, sem emoji (voice-and-tone). "Ver status do sistema" descreve o destino — não "clique aqui" nem "/health" cru.
- `{versao}` é placeholder nomeado, preenchido pelo mecanismo de versão de STORY-007 (CA-1/CA-6). Formato exibido: `vX.Y.Z-rc.N`.
- Vocabulário do domínio preservado (Match, PIN, Pix).

## 6. Acessibilidade (notas específicas)

- **Ordem de foco / leitura:** logo (marca) → subtítulo → pilares → link "Ver status do sistema" → versão. Ordem do DOM = ordem visual.
- **Foco inicial:** topo do documento (`<h1>`/marca). Não roubar foco para o link.
- **Marca:** `brand.logo` envolvido em rótulo semântico "Turni" (`Semantics(label:'Turni')` / `aria-label`) — não ler "T-U-R-N-I" letra a letra.
- **Link:** alvo de toque ≥48dp; foco visível (anel `primary`); navegável por teclado (Tab + Enter) no Flutter Web.
- **Contraste (DDR-001 §6 — esquema profissional, ambos os temas):** todos os pares usados passam AA.
  - Claro: `text.strong`/`surface.page` 15.7:1 ✅ · `text.muted` (subtítulo/pilares/versão)/`surface.page` 7.7:1 ✅ · link `accent` `#2D5F3F`/`surface.page` 6.8:1 ✅ (sobre card `surface` → 7.4:1 ✅).
  - Escuro: `text.strong` `#ECEDE5`/`surface.page` `#0F1411` 15.8:1 ✅ · `text.muted` `#A8B2A8` 8.5:1 ✅ · link `accent` `#5FA37C`/`surface` 5.6:1 ✅.
- **Tamanho de texto:** subtítulo `subtitle` (16) e pilares `body-sm` (14) ≥ piso mobile (14px). Versão em `caption` (13) é secundária; em mobile usar `body-sm` (14) se for o único texto daquele tamanho. Nenhuma cor `text.subtle` do tema claro usada (evita o teto de contraste).
- **Sem dependência de cor isolada:** o link tem texto + sublinhado/seta, não só cor.
- `prefers-reduced-motion`: se houver qualquer transição de entrada, respeitar (sem animação obrigatória — a tela não precisa de motion).

## 7. Identificadores estáveis sugeridos para teste

Nomes lógicos; o Programador aplica como `Key('...')` no widget. Ancoram o E2E em browser real (CA-13).

| Elemento | Identificador lógico |
|---|---|
| Raiz da tela | `screen-welcome-webapp` |
| Logomarca | `screen-welcome-brand` |
| Texto da versão | `screen-welcome-version` |
| Link para `/health` | `screen-welcome-health-link` |

## 8. Exceções ao Design System

Nenhuma. A tela usa apenas tokens e componentes da fundação DDR-001.

| O que diverge | Por quê | Vira DDR? |
|---|---|---|
| — | — | — |

## 9. Dependências e premissas

- **Versão exibida:** vem do mecanismo padronizado de STORY-007 / IDR (CA-1) — não inventar segunda fonte. Spec só consome `{versao}`.
- **Sem API/endpoint** consumido pela tela; o link para `/health` é navegação de rota.
- **DDR-001 em `proposed`:** este spec está `ready` (estrutura, estados, microcopy, a11y completos e estáveis). A premissa é que a fundação DDR-001 seja aprovada por Alexandro **antes** do merge de STORY-008 (invariante 9/12 de `indexing.md` exigem screen spec `ready`; a estória STORY-008 já está `blocked_by` STORY-010). Se a aprovação ajustar algum token, o impacto neste spec é troca de valor de token (não de estrutura).

## 10. Histórico de mudanças

| Data | Mudança | Quem | Motivo |
|---|---|---|---|
| 2026-05-27 | criação em `ready` | designer | Fundação DDR-001 + spec da página de boas-vindas. Tela estática simples permitiu spec completo direto (sem fase intermediária `draft`). |
| 2026-05-27 | ajuste tema/esquema | designer | DDR-001 revisado (fonte = só `app.html`; dual-theme + esquema por perfil). Spec passou a declarar pré-login = esquema profissional (neutro), claro padrão + suporte a escuro; contraste verificado nos dois temas. Sem mudança de estrutura/layout. |
