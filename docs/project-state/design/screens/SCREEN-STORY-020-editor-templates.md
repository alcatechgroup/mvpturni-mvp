---
id: SCREEN-STORY-020-editor-templates
story: STORY-020-editor-templates-contratuais-backoffice
epic: EPIC-001-cadastro-e-aprovacao
status: ready
created_at: 2026-05-29
updated_at: 2026-05-29
owner_designer: Designer (claude-opus-4-8)
related_ddrs: [DDR-001]
ds_components_used: [sidebar.admin, stat-card, panel, data-table, chip, btn.primary, btn.success, btn.outline, btn.ghost, dialog-confirm, toast, code-block, feedback-banner]
exceptions_to_ds: [desktop-first (PDR-003) em vez de mobile-first; editor side-by-side (novo padrão "author + preview", candidato a DDR se repetir); chip de placeholder (novo átomo visual derivado de chip)]
viewports: [desktop, mobile]
prototype_path: SCREEN-STORY-020-editor-templates/index.html
prototype_last_validated_at: 2026-05-29
---

# Spec de tela — Editor de templates contratuais (Backoffice)

> Referência: estória `STORY-020-editor-templates-contratuais-backoffice` (CAs e contexto vêm de lá — **não duplico**).
> Base visual: `docs/project-state/design/system/preview-backoffice.html` (shell admin DDR-001) + `tokens.md` (perfil **admin · azul-navy**), reusando 1:1 o que a `SCREEN-STORY-019` já estabeleceu (sidebar, panel, data-table, chip, dialog, toast).
> Decisões canônicas que restringem este spec: **PDR-012** (edição substitui release; versão ativa imutável; aceites passados imutáveis), **ADR-010** (esquema + lista finita de placeholders + motor de substituição simples, **sem execução de código**).
> Princípios que conduziram o desenho: **#1 Simplicidade radical** (textarea + preview, sem WYSIWYG — escopo da estória), **#3 Tom profissional** (documento jurídico, não app lúdico), **#5 Acessibilidade** (editor 100% por teclado), **#7 Todos os estados** (a ativação é alta-sensibilidade — confirmação dupla que explica a consequência jurídica).

## Nota de plataforma (≠ resto do produto)

O Backoffice **não é Flutter** — é **Laravel + Livewire 4 + Blade**, desktop-first (PDR-003). Componentes descritos em termos de **Blade/Livewire**; identificadores da §7 são `data-testid` (Playwright/Pest), não `Key()`. O Design System (tokens DDR-001 admin) é o mesmo da `SCREEN-STORY-019`.

## 1. Objetivo da tela

Permitir ao **admin Turni** editar os contratos eletrônicos **sem release de código**: ver o catálogo dos 2 templates do MVP, abrir um template, navegar o histórico de versões, **criar uma nova versão** (editando a partir da ativa) e **ativá-la** — com a garantia, comunicada na própria UI, de que **aceites já firmados não mudam** (apontam para a versão original). A tarefa é juridicamente sensível: o desenho prioriza **clareza da consequência** sobre velocidade.

## 2. Fluxo

```
/templates (catálogo)
   │  "Abrir"
   ▼
/templates/{slug} (detalhe: versão ativa renderizada + histórico)
   │                                   │  "Ativar versão N" (em versão histórica)
   │  "Criar nova versão"              ▼
   ▼                              [diálogo de confirmação dupla] ──► ativa N, toast
/templates/{slug}/nova-versao (editor + preview side-by-side)
   │  "Salvar nova versão"  → valida → cria versão N+1 (ativa=false)
   ▼
volta a /templates/{slug} com a nova versão no topo do histórico (toast)
```

### Entrada

- **De onde chega:** novo item de sidebar **"Templates contratuais"** (seção *Cadastro*), rota `/templates`.
- **Pré-condições:** sessão `web` + `role=admin` (middleware `AdminOnly`, STORY-016). Qualquer outro papel → 403; não-autenticado → `/login` (fail-secure, já garantido). **CA-1.**

### Ações possíveis

- **Catálogo:** `Abrir` um template (vai ao detalhe). Sem criar/excluir template (catálogo é fixo — PDR-001).
- **Detalhe:** `Criar nova versão` (primária); em cada versão **histórica**, `Ativar esta versão` (inclui "voltar para versão anterior" — CA-11); `Ver completa` (expande o conteúdo de uma versão do histórico).
- **Editor:** digitar Markdown; ver `Preview` ao vivo ao lado; `Salvar nova versão`; `Cancelar` (descarta, volta ao detalhe — confirma se houver alterações).
- **Ativação:** sempre passa por **diálogo de confirmação dupla** que explica a consequência (CA-8).

### Saída

- **Após salvar versão:** editor fecha → volta ao detalhe → toast `Versão {N} criada como rascunho. Ative quando quiser publicá-la.` → nova versão aparece no topo do histórico como `histórica` (ativa=false). **CA-6.**
- **Após ativar versão:** diálogo fecha → toast `Versão {N} ativada. Novos cadastros passam a usar esta versão.` → catálogo/detalhe re-renderizam apontando para a nova ativa. **CA-7.**
- **Após erro de validação:** permanece no editor; banner de erro acionável citando o placeholder problemático (CA-5); foco vai ao banner.
- **Após cancelar:** volta ao detalhe sem criar nada.

## 3. Layout

Shell idêntico ao `preview-backoffice.html`: **sidebar navy fixa (260px)** + **main**. Item "Templates contratuais" `active`.

### 3.1 Catálogo — `/templates` (desktop ≥1024px)

```
+-----------+-------------------------------------------------------------+
| TURNI.    | Backoffice · Admin                                          |
| Backoffice| Templates contratuais                                       |
|           | Edite os contratos sem precisar de deploy. Cada edição cria |
| [av] Nome | uma nova versão; a ativa vale para novos cadastros.         |
| OPERAÇÃO  |                                                             |
| ▸ Visão   | +---------------------------------------------------------+ |
| ▸ Penden. | | Template            Slug          Versão ativa  ...   → | |
| CADASTRO  | +---------------------------------------------------------+ |
| ● Templ.  | | Contrato PF —       pf_autonomo_  ▣ v3 · ativa  [Abrir]| |
|           | | Autônomo eventual   eventual      desde 28/05          | |
| [Sair]    | |                                   por Alexandro        | |
|           | | Contrato MEI/PJ —   mei_pj_b2b    ▣ v1 · ativa  [Abrir]| |
|           | | B2B PJ↔PJ                         desde 28/05           | |
|           | +---------------------------------------------------------+ |
+-----------+-------------------------------------------------------------+
```

- Componentes DS: `panel` + `data-table`, `chip` (versão ativa, tom `accent-soft`), `btn.outline` (`Abrir`). Colunas: **Template** (nome amigável), **Slug** (`mono`), **Versão ativa** (chip `v{n} · ativa`), **Ativada em** (data + autor), ação `Abrir`. **CA-2.**
- Sem cards de contadores (não há backlog) — a tela é um catálogo curto e estável.

### 3.2 Detalhe — `/templates/{slug}` (desktop)

```
+-----------+-------------------------------------------------------------+
|  sidebar  | Backoffice · Admin · Templates                              |
|           | ‹ Voltar ao catálogo                                        |
|           | Contrato PF — Autônomo eventual        [ Criar nova versão ]|
|           | pf_autonomo_eventual · ativa: v3                            |
|           |                                                             |
|           | +--- Versão ativa (v3) --------------------------------+    |
|           | | (conteúdo renderizado em Markdown; placeholders como  |    |
|           | |  ⟦contratante.razao_social⟧ destacados como chips)    |    |
|           | |  ## Seção 1 — Termos gerais ...                       |    |
|           | +-------------------------------------------------------+    |
|           |                                                             |
|           | Histórico de versões                                        |
|           | +-------------------------------------------------------+    |
|           | | ▣ v3 · ativa     28/05 14:10 · Alexandro   [Ver compl.]|   |
|           | | ○ v2 · histórica 27/05 09:30 · Alexandro   [Ver][Ativar]| |
|           | | ○ v1 · histórica 26/05 11:00 · Alexandro   [Ver][Ativar]| |
|           | +-------------------------------------------------------+    |
+-----------+-------------------------------------------------------------+
```

- **Versão ativa renderizada** (CA-3): o Markdown é renderizado para HTML; **placeholders permanecem visíveis e destacados** como *chips de placeholder* (`⟦namespace.campo⟧`, fundo `accent-soft`, fonte `mono`) — o admin enxerga onde os dados entram, sem que o placeholder "suma".
- **Histórico desc** (CA-3): versão no topo = mais nova. Cada linha: ícone de status (▣ ativa / ○ histórica), `v{n}`, data, autor, status textual, `Ver completa` (expande inline), e — só em históricas — `Ativar esta versão` (CA-9/CA-11).
- **CTA primário** `Criar nova versão` no header do detalhe (CA-4).

### 3.3 Editor — `/templates/{slug}/nova-versao` (desktop, side-by-side)

```
+-----------+-------------------------------------------------------------+
|  sidebar  | Backoffice · Templates · Nova versão                        |
|           | Nova versão de "Contrato PF — Autônomo eventual"            |
|           | Partindo da v3 (ativa). Salvar cria a v4 como rascunho.     |
|           | ┌─ Editor (Markdown) ───────┐  ┌─ Pré-visualização ──────┐ |
|           | │ ## Seção 1 — Termos gerais│  │ Seção 1 — Termos gerais  │ |
|           | │ Nome: {{profissional.nome}}│ │ Nome: ⟦profissional.nome⟧│ |
|           | │ ...                        │  │ ...                      │ |
|           | │ (textarea mono, full-h)    │  │ (render + chips)         │ |
|           | └────────────────────────────┘  └──────────────────────────┘ |
|           | ⓘ Use Markdown. Placeholders no formato {{namespace.campo}}.|
|           |   Disponíveis: contratante.* · profissional.* · turno.* ·   |
|           |   aceite.* · habitualidade.*   [ver lista completa]         |
|           | [ Cancelar ]                          [ Salvar nova versão ]|
+-----------+-------------------------------------------------------------+
```

- **Two-pane** (CA-4): esquerda `textarea` monoespaçada de altura cheia (fonte `JetBrains Mono`); direita preview ao vivo (render Markdown + chips de placeholder). Em telas 1024–1279px as duas colunas encolhem; <1024px empilham (aviso desktop-first).
- **Ajuda contextual** sob os painéis: formato do placeholder + namespaces disponíveis + link `ver lista completa` (abre `dialog` com os ~17 placeholders canônicos — ADR-010). Preview atualiza com `wire:model.live.debounce.300ms` (percepção de tempo real — princípio #6) ou via Alpine local para latência zero; programador confirma no sync.

### 3.4 Mobile (≥360px) — fallback degradado

Backoffice é desktop-first (PDR-003). Abaixo de 1024px: sidebar some, aviso `Backoffice é desktop-first…`, catálogo/histórico viram cards empilhados, e o **editor empilha** (textarea em cima, preview embaixo) — funciona mas o uso pretendido é desktop. Exceção consciente ao Princípio #2 (§8), idêntica à `SCREEN-STORY-019`.

## 4. Estados

### 4.1 Catálogo
- **Loaded (CA-2):** 2 linhas. Caminho padrão.
- **Loading:** skeleton de 2 linhas (barras `muted`).
- **Catálogo não semeado (degradado):** se por algum motivo as versões ativas não existirem, a linha mostra `— sem versão ativa` em `warning` com dica `Rode o seed (php artisan db:seed).` — não quebra a tela. (Não deve ocorrer em homolog; CA-12 garante o seed.)
- **Sem permissão:** 403 via `AdminOnly` (sem UI própria).

### 4.2 Detalhe
- **Loaded (CA-3):** versão ativa renderizada + histórico desc.
- **Loading:** skeleton do bloco de conteúdo + 3 linhas de histórico.
- **Slug desconhecido:** 404 (`errors/404`) — o slug não está no catálogo fixo.
- **Uma só versão (v1):** histórico com uma linha (`v1 · ativa`), sem botão "Ativar" (já é a ativa). É o estado pós-seed inicial.

### 4.3 Editor
- **Editando (default):** textarea **pré-carregada com o conteúdo da versão ativa** (CA-4) — o admin parte do existente, não do zero.
- **Preview ao vivo:** render contínuo; placeholders viram chips.
- **Erro de validação — placeholder fora da lista (CA-5):** banner `error-soft` no topo do editor: `O placeholder {{xxx}} não existe. Use apenas os placeholders da lista (contratante.*, profissional.*, turno.*, aceite.*, habitualidade.*).` — cita **o placeholder exato** e **não salva**. O chip do placeholder inválido no preview fica em tom `error` (`⟦xxx⟧` vermelho).
- **Aviso soft — seção faltando (CA / validador soft):** se faltar `## ...Termos gerais...` ou `## ...Termos do turno...`, banner `warning-soft` **não-bloqueante**: `Aviso: não encontrei a seção "Termos gerais" / "Termos do turno específico". Confira a estrutura antes de ativar.` — salva mesmo assim.
- **Conteúdo vazio:** botão `Salvar` desabilitado + ajuda `O conteúdo não pode ficar vazio.`
- **Salvando:** botão em estado `loading` (spinner curto), demais controles bloqueados.

### 4.4 Ativação (diálogo de confirmação dupla — CA-8)
`role="alertdialog"`, foco inicial em **Cancelar**. Texto explica explicitamente que **aceites passados não mudam**:

```
+------------------------------------------------------+
| Ativar a versão 4?                                   |
|                                                      |
| A partir de agora, novos cadastros aprovados usarão  |
| a versão 4 deste contrato.                           |
| Os aceites já assinados continuam apontando para a   |
| versão que estava ativa quando foram firmados —      |
| eles NÃO mudam.                                      |
|                              [ Cancelar ] [ Ativar ] |
+------------------------------------------------------+
```

### 4.5 Erro inesperado
Toast honesto `Não foi possível concluir a ação. Tente novamente.` — sem stack trace; detalhe vai ao log estruturado (CA-14 / observabilidade).

## 5. Microcopy completo

| Lugar | Texto |
|---|---|
| Item de sidebar | `Templates contratuais` |
| Breadcrumb catálogo | `Backoffice · Admin` |
| Título catálogo | `Templates contratuais` |
| Subtítulo catálogo | `Edite os contratos sem precisar de deploy. Cada edição cria uma nova versão; a ativa vale para novos cadastros.` |
| Colunas catálogo | `Template` · `Slug` · `Versão ativa` · `Ativada em` · (ação) |
| Chip versão ativa | `v{n} · ativa` |
| Sub "ativada em" | `desde {dd/mm} · por {autor}` |
| CTA abrir | `Abrir` |
| Catálogo sem seed (degradado) | `— sem versão ativa · rode o seed (php artisan db:seed)` |
| Breadcrumb detalhe | `Backoffice · Admin · Templates` |
| Voltar | `‹ Voltar ao catálogo` |
| Título detalhe | `{nome amigável}` |
| Sub detalhe | `{slug} · ativa: v{n}` |
| CTA criar versão | `Criar nova versão` |
| Cabeçalho bloco ativa | `Versão ativa (v{n})` |
| Cabeçalho histórico | `Histórico de versões` |
| Linha histórico — ativa | `v{n} · ativa · {dd/mm hh:mm} · {autor}` |
| Linha histórico — histórica | `v{n} · histórica · {dd/mm hh:mm} · {autor}` |
| Ação ver | `Ver completa` |
| Ação ver (recolher) | `Recolher` |
| Ação ativar (histórica) | `Ativar esta versão` |
| Título editor | `Nova versão de "{nome amigável}"` |
| Sub editor | `Partindo da v{n} (ativa). Salvar cria a v{n+1} como rascunho.` |
| Label editor | `Editor (Markdown)` |
| Label preview | `Pré-visualização` |
| Ajuda placeholder | `Use Markdown. Placeholders no formato {{namespace.campo}}.` |
| Ajuda namespaces | `Disponíveis: contratante.* · profissional.* · turno.* · aceite.* · habitualidade.*` |
| Link lista placeholders | `ver lista completa` |
| Diálogo lista — título | `Placeholders disponíveis` |
| Diálogo lista — nota | `Use exatamente estes. Qualquer outro bloqueia o salvamento.` |
| CTA salvar | `Salvar nova versão` |
| CTA cancelar | `Cancelar` |
| Cancelar com alterações — diálogo | `Descartar esta versão? O que você escreveu não será salvo.` / `Continuar editando` / `Descartar` |
| Erro vazio | `O conteúdo não pode ficar vazio.` |
| Erro placeholder inválido (CA-5) | `O placeholder {{ {placeholder} }} não existe. Use apenas os placeholders da lista (contratante.*, profissional.*, turno.*, aceite.*, habitualidade.*).` |
| Aviso seção faltando | `Aviso: não encontrei a seção "{seção}". Confira a estrutura antes de ativar.` |
| Diálogo ativar — título | `Ativar a versão {n}?` |
| Diálogo ativar — corpo | `A partir de agora, novos cadastros aprovados usarão a versão {n} deste contrato. Os aceites já assinados continuam apontando para a versão que estava ativa quando foram firmados — eles não mudam.` |
| Diálogo ativar — confirmar | `Ativar` |
| Diálogo ativar — cancelar | `Cancelar` |
| Toast — versão criada | `Versão {n} criada como rascunho. Ative quando quiser publicá-la.` |
| Toast — versão ativada | `Versão {n} ativada. Novos cadastros passam a usar esta versão.` |
| Toast — erro genérico | `Não foi possível concluir a ação. Tente novamente.` |
| Aviso mobile | `Backoffice é desktop-first (≥1024px). Alargue a janela para ver o shell completo.` |

Vocabulário do glossário (PO): "Contratante", "Profissional", "Turno", "Cadastro". Termo "versão **ativa**" (não "publicada"/"vigente") e "**histórica**" (não "antiga"/"arquivada") padronizados nesta tela. Mensagens com efeito jurídico (diálogo de ativação) — **validadas pelo PO** antes de produção (fronteira fuzzy de microcopy do Designer).

## 6. Acessibilidade (WCAG 2.1 AA — CA-13)

- **Editor 100% por teclado:** `textarea` recebe foco com Tab; Tab dentro dela insere tabulação? Não — preserva navegação (Tab sai do campo); ajuda explica formato. Botões `Salvar`/`Cancelar` na ordem de foco.
- **Preview com live region:** o painel de preview é `aria-live="polite"` + `aria-atomic="false"` para anunciar atualização sem spam (debounce). Rótulo `aria-label="Pré-visualização do contrato"`.
- **Chips de placeholder** têm texto real (`⟦profissional.nome⟧`) — não dependem só de cor; o chip inválido usa cor `error` **e** ícone/título `placeholder inválido` (não só vermelho).
- **Diálogo de ativação:** `role="alertdialog"`, foco inicial em **Cancelar** (evita ativação acidental por Enter), focus-trap, Esc cancela.
- **Status de versão** (ativa/histórica) comunicado por **ícone + texto**, nunca só cor.
- **Tema dual** claro/escuro (toggle do shell) — todos os pares de cor sancionados em `tokens.md §6`. **CA-13.**
- **Contraste** do código/textarea: `mono` sobre `sunken` passa AA nos dois temas.

## 7. Identificadores estáveis (`data-testid` — Playwright/Pest)

| Elemento | Identificador |
|---|---|
| Tela catálogo | `templates-catalogo` |
| Linha do catálogo | `templates-catalogo-item-{slug}` |
| Chip versão ativa (item) | `templates-catalogo-item-{slug}-ativa` |
| CTA abrir | `templates-catalogo-item-{slug}-abrir` |
| Tela detalhe | `template-detalhe` |
| Voltar ao catálogo | `template-detalhe-voltar` |
| Bloco versão ativa | `template-detalhe-ativa` |
| CTA criar versão | `template-detalhe-criar-versao` |
| Lista histórico | `template-detalhe-historico` |
| Linha de versão | `template-versao-{n}` |
| Status da versão | `template-versao-{n}-status` |
| Ver completa | `template-versao-{n}-ver` |
| Ativar versão | `template-versao-{n}-ativar` |
| Tela editor | `template-editor` |
| Textarea | `template-editor-textarea` |
| Painel preview | `template-editor-preview` |
| Banner erro validação | `template-editor-erro` |
| Banner aviso seção | `template-editor-aviso` |
| Link lista placeholders | `template-editor-placeholders-link` |
| Diálogo lista placeholders | `template-editor-placeholders-dialog` |
| Salvar | `template-editor-salvar` |
| Cancelar | `template-editor-cancelar` |
| Diálogo ativar — confirmar | `dialog-ativar-confirm` |
| Diálogo ativar — cancelar | `dialog-ativar-cancel` |
| Toast | `templates-toast` |

## 8. Exceções ao Design System

| O que diverge | Por quê | Vira DDR? |
|---|---|---|
| **Desktop-first** (Princípio #2) | PDR-003: Backoffice é ferramenta de mesa. Igual `SCREEN-STORY-019`. | Não — coberto por PDR-003 + DDR-001. |
| **Editor side-by-side** (author + preview ao vivo) | Padrão novo no produto; útil sempre que houver "edição com render". | **Candidato a DDR** se reaparecer (ex.: editor de e-mail/avisos). Registro aqui; não formalizo no MVP de 1 uso. |
| **Chip de placeholder** (`⟦ns.campo⟧` mono, accent-soft / error quando inválido) | Átomo visual novo derivado de `chip`; comunica "dado dinâmico" no texto jurídico. | Entra no `components.md` como variante de chip se o editor seguir vivo. |
| **Confirmação dupla na ativação** com cópia explicando consequência jurídica | PDR-012 §Consequências exige clareza de "aceites passados não mudam". | Reusa o padrão "ação sensível" já visto em `SCREEN-STORY-019` (remover). |

## 9. Protótipo HTML fiel (validação humana)

- **Localização:** `SCREEN-STORY-020-editor-templates/index.html` (mesma pasta deste spec).
- **Cobertura:** estados da §4 via seletor de tela/estado no topo: `catalogo`, `detalhe`, `detalhe-v1` (pós-seed), `editor`, `editor-erro-placeholder`, `editor-aviso-secao`, `dialog-ativar`, `toast-criada`, `toast-ativada`, `catalogo-loading`. Toggle de tema claro/escuro (admin navy). Viewport desktop (primário) + estreito (fallback).
- **Fidelidade:** tokens reais do DDR-001 (mesmas variáveis CSS do `preview-backoffice.html`). Microcopy = §5 palavra por palavra. `data-testid` da §7 aplicados.
- **Restrições:** HTML/CSS/JS vanilla, sem rede/build. Declara no topo "protótipo de validação, não código de produção".

### Checklist antes de `ready`

- [x] `index.html` existe e abre sem erro.
- [x] Todos os estados da §4 acessíveis.
- [x] Desktop + fallback estreito.
- [x] Microcopy do protótipo = §5.
- [x] `data-testid` da §7 presentes.
- [x] Tokens reais do DS (DDR-001 admin).
- [x] **Apresentado ao humano (Alexandro) e validação capturada** — aprovado em chat em 2026-05-29 (login `admin@turni.local`, tela real em `localhost:8002/templates`).

## 10. Dependências e premissas

- **Esquema (back):** `templates` + `template_versoes` conforme **ADR-010** (partial unique index de versão ativa; trigger de imutabilidade do conteúdo). Migração + seed são do Programador nesta estória (CA-12/CA-16).
- **Lista canônica de placeholders (ADR-010 / `compliance.md`)** — o validador (CA-5) usa exatamente: `contratante.razao_social|cnpj|endereco_completo`, `profissional.nome|documento|endereco_completo`, `turno.funcao|data_inicio|data_fim|valor|taxa_turni|total_contratante`, `aceite.timestamp|ip|fingerprint`, `habitualidade.override_aceito|clausula_adicional`. **Importante:** o texto-seed (STORY-015) usa `{{namespace.campo}}` **apenas no frontmatter YAML** (`nota_rascunho`) — o seeder **deve descartar o frontmatter** e carregar só o corpo, senão a validação/seed quebra. Confirmado no sync.
- **Renderização do preview:** Markdown → HTML + destaque de placeholders. **Não executa código** (ADR-010 / §4 segurança): o motor só substitui/realça `{{...}}`, nunca avalia expressões. Programador escolhe a lib de Markdown (ex.: CommonMark) — decisão técnica, não de design.
- **Audit log (ADR-009):** `admin.template.version_created` (salvar) e `admin.template.version_activated` (ativar). Eventos já canônicos.
- **Permissões:** `AdminOnly` (STORY-016).
- **Bloqueia:** STORY-023/024 (precisam da versão ativa carregada para renderizar o aceite).

## 11. Histórico de mudanças

| Data | Mudança | Quem | Motivo |
|---|---|---|---|
| 2026-05-29 | criação do spec completo + protótipo v1 | Designer (claude-opus-4-8) | rabisco→spec na mesma sessão do Programador (trabalho paralelo); base no `preview-backoffice.html` (DDR-001) e na `SCREEN-STORY-019` |
| 2026-05-29 | validação humana | Alexandro | aprovado em chat após implementação testada (login `admin@turni.local`, tela real em `localhost:8002/templates`) |

> Sync Designer↔Programador desta sessão registrado nas "Notas do agente" da `STORY-020`. Mudanças após o código começar entram aqui com data e motivo.
