---
id: SCREEN-STORY-019-fila-aprovacao
story: STORY-019-fila-aprovacao-backoffice
epic: EPIC-001-cadastro-e-aprovacao
status: ready
created_at: 2026-05-29
updated_at: 2026-05-29
owner_designer: Designer (claude-opus-4-8)
related_ddrs: [DDR-001]
ds_components_used: [sidebar.admin, stat-card, feedback-banner, panel, data-table, chip, btn.primary, btn.success, btn.danger, btn.outline, drawer-detail, dialog-confirm, toast]
exceptions_to_ds: [desktop-first (PDR-003) em vez de mobile-first; remoção destrutiva usa diálogo de confirmação dupla com digitação implícita por segundo clique]
viewports: [desktop, mobile]
prototype_path: STORY-019-fila-aprovacao/index.html
prototype_last_validated_at: 2026-05-29
---

# Spec de tela — Fila de aprovação (Backoffice)

> Referência: estória `STORY-019-fila-aprovacao-backoffice` (CAs e contexto vêm de lá — **não duplico**).
> Base visual: `docs/project-state/design/system/preview-backoffice.html` (shell admin já validado em DDR-001) e `tokens.md` (perfil **admin · azul-navy**).
> Princípios que conduziram decisões: **#1 Simplicidade radical** (uma tarefa: analisar e despachar um cadastro), **#7 todos os estados** (vazio/loading/erro/sem-permissão), **#2** adaptado: o Backoffice é **desktop-first por PDR-003** — registro a exceção na §8.

## Nota de plataforma (≠ resto do produto)

O Backoffice **não é Flutter** — é **Laravel + Livewire 4 + Blade + Tailwind**, desktop-first (PDR-003). Por isso este spec descreve componentes em termos de **Blade/Livewire** (não widgets Flutter) e os identificadores da §7 são `data-testid` (lidos pelo Playwright, não `Key()`). O Design System (tokens DDR-001) é o mesmo; muda só a tecnologia de render. O WebApp continua mobile-first/Flutter.

## 1. Objetivo da tela

Permitir ao **admin Turni** analisar um cadastro pendente e **despachá-lo com um veredito** — aprovar (libera o usuário no funil) ou remover (recusa implícita, PDR-001) — dentro do SLA público de 24h.

## 2. Fluxo

### Entrada

- **De onde chega:** item "Cadastros pendentes" na sidebar do Backoffice (rota `/aprovacoes`). É o primeiro item operacional da sidebar.
- **Pré-condições:** sessão `web` ativa **e** `role=admin` (middleware `AdminOnly`, STORY-016). Qualquer outro papel ou não-autenticado → 403 / redirect a `/login` (fail-secure, já garantido).

### Ações possíveis na tela

- **Primária:** abrir um cadastro → **Ver detalhes** (drawer lateral). A recomendação do PO (estória §Liberdade técnica) é que **aprovar só aconteça dentro do detalhe**, para forçar o admin a ver os dados antes. A lista **não** tem botão aprovar direto.
- **Dentro do detalhe:** **Aprovar** (botão primário/sucesso, com diálogo de confirmação) · **Remover** (botão destrutivo, com **confirmação dupla**).
- **Secundárias:** filtrar por papel (`todos | profissional | contratante`) e, para profissional, por `tipo_pessoa` (`PF | MEI | PJ`); paginar; fechar o detalhe (Esc / clique no backdrop / botão Fechar).
- **Saídas:** após aprovar/remover, o detalhe fecha, o item **sai da fila**, a lista e o contador agregado re-renderizam, e um **toast** confirma.

### Saída

- **Após aprovar:** detalhe fecha → toast "Cadastro aprovado. E-mail enviado a `f•••@dominio.com`." → item some da lista → contadores caem.
- **Após remover:** detalhe fecha → toast "Cadastro removido." → item some da lista.
- **Após cancelar (diálogo):** volta ao detalhe, nada muda.
- **Após erro recuperável (race — CA-6):** detalhe fecha → toast de erro "Este cadastro já foi processado por outro admin." → lista atualiza (o item já não está lá).

## 3. Layout

### Desktop (≥1024px) — layout primário (PDR-003)

Shell idêntico ao `preview-backoffice.html`: **sidebar navy fixa (260px)** + **main**. O item "Cadastros pendentes" fica `active` com badge de contagem.

```
+-----------+-------------------------------------------------------------+
| TURNI.    | Backoffice · Admin                                          |
| Backoffice| Cadastros pendentes                                         |
|           | 12 aguardando análise · SLA público de 24h                  |
| [av] Nome |                                                             |
| Super Adm | [Pendentes 12][Profissionais 8][ • PF 3 MEI 4 PJ 1 ]        |
|           | [Contratantes 4]    (cards de contagem agregada — CA-8)     |
| OPERAÇÃO  |                                                             |
| ▸ Visão   | ⚠ 3 cadastros há mais de 20h — priorize p/ não estourar SLA |
| ● Penden. |                                                             |
|   12      | [Todos][Profissional][Contratante]  · tipo: [PF][MEI][PJ]   |
| ▸ Disputas| +---------------------------------------------------------+ |
|           | | Fila de análise                                         | |
| CADASTRO  | +---------------------------------------------------------+ |
| ▸ Profis. | | Foto  Nome / sub        Papel · tipo   Enviado   →      | |
| ▸ Contrat.| | (o)   Carlos H. Silva   Profissional   🔴 há 21h  Ver   | |
| ▸ Config. | |       MEI · Garçom                                       | |
|           | | (o)   Pizzaria Mooca    Contratante    🟡 há 14h  Ver   | |
| [Sair]    | | (o)   Diego Reis        Profissional   🟢 há 3h   Ver   | |
|           | |       PF · Iniciante                                     | |
|           | +---------------------------------------------------------+ |
|           | [‹ anterior]  página 1 de 2  [próxima ›]                   |
+-----------+-------------------------------------------------------------+
```

- Componentes DS: `sidebar.admin`, `stat-card` (contadores), `feedback-banner` (alerta SLA, `info-soft`), `panel` + `data-table`, `chip` (papel/SLA), `btn.outline.sm` ("Ver detalhes").
- **Hierarquia:** título da tela → contadores agregados (visão de backlog) → alerta de SLA (só aparece se houver item > 20h) → filtros → tabela. A ação por linha é **secundária** ("Ver detalhes", outline), nunca aprovar direto.
- **SLA por item** (CA-9/CA-10): coluna "Enviado" mostra ícone + cor + texto: 🟢 `≤12h` (success), 🟡 `12–20h` (warning), 🔴 `>20h` (error). A cor **nunca** é o único canal — sempre ícone + o texto "há Xh".

#### Detalhe — Drawer lateral (desktop)

Decisão técnica do Programador confirmada no sync: **drawer lateral à direita** (overlay sobre a lista, não troca de rota), porque mantém o contexto da fila e é o padrão Livewire mais simples (um componente `wire:model` de `selectedId`). Largura ~520px, scroll interno.

```
                          +--------------------------------------+
                          | Detalhe do cadastro            [✕]   |
                          +--------------------------------------+
                          |   ( foto 96px )   Carlos H. Silva    |
                          |                   Profissional · MEI |
                          |                   🔴 há 21h na fila   |
                          +--------------------------------------+
                          | E-mail     carlos@exemplo.com        |
                          | Telefone   (11) 9 9999-9999          |
                          | Cidade     São Paulo · Mooca         |
                          | Função     Garçom                    |
                          | Termos     aceitos em 28/05 14:32     |
                          | Contrato   MEI/PJ B2B · v1 (ativo) ↗  |
                          +--------------------------------------+
                          | [ Aprovar cadastro ]  (sucesso)      |
                          | [ Remover ]           (destrutivo)   |
                          +--------------------------------------+
```

- Exibe **todos** os campos do pré-cadastro do papel (CA-4). Para **profissional**: foto, nome, e-mail, telefone, cidade, bairro, função, `tipo_pessoa`, termos (timestamp), template aplicável. Para **contratante**: foto do responsável, nome, e-mail, telefone, cidade, nome do estabelecimento, tipo de operação, termos, template aplicável.
- **Template contratual aplicável** (CA-4): indicador textual `PF autônomo eventual · v1` (PF) ou `MEI/PJ B2B · v1` (MEI/PJ e contratante), com link para o template ativo. **Placeholder de leitura nesta estória** — o editor é STORY-020 e o modelo `TemplateVersao` ainda não existe (ADR-010 é spike). O link aponta para o texto-seed (`docs/especificacao/contratos/…`) enquanto STORY-020 não publica a versão no banco. Registrado como dependência na §10.

### Mobile (≥360px) — fallback degradado

O Backoffice é **desktop-first** (PDR-003): a sidebar some abaixo de 1024px e exibe-se um aviso ("Backoffice é desktop-first — alargue a janela"), exatamente como o `preview-backoffice.html`. **Não há paridade mobile** porque a operação de aprovação acontece em mesa/desktop pela equipe Turni. A tabela colapsa para cards empilhados e o drawer vira full-screen, garantindo que a tela **não quebra** em telas estreitas — mas o uso pretendido é desktop. Isto é exceção consciente ao Princípio #2 (registrada na §8).

```
+----------------------------------+
| ⚠ Backoffice é desktop-first.    |
| Alargue a janela p/ shell completo|
+----------------------------------+
| Cadastros pendentes · 12          |
| [Todos][Prof.][Contrat.]          |
| +------------------------------+  |
| | (o) Carlos H. Silva          |  |
| |     Profissional · MEI       |  |
| |     🔴 há 21h     [Ver ›]     |  |
| +------------------------------+  |
| | (o) Pizzaria Mooca           |  |
| |     Contratante  🟡 há 14h    |  |
| +------------------------------+  |
+----------------------------------+
```

## 4. Estados

### 4.1. Caminho feliz (fila com itens)

Conforme §3. Lista FIFO (mais antigo no topo). Cada linha: foto (ou avatar com inicial se sem foto), nome, sub-linha (`tipo_pessoa · função` para profissional; `tipo_operação` para contratante), chip de papel, indicador de SLA, CTA "Ver detalhes".

### 4.2. Loading (primeiro fetch e após filtro)

Skeleton de **3–5 linhas** da tabela (barras `surface.muted`), **não** spinner em tela vazia. Os contadores mostram `—` enquanto carregam. Drawer ao abrir: skeleton dos campos por ~150ms (dado já em memória na maioria dos casos).

```
+---------------------------------------------+
| ░░░░░░░░░░░  ░░░░░░  ░░░░  ░░░░░░            |
| ░░░░░░░░░░░  ░░░░░░  ░░░░  ░░░░░░            |
| ░░░░░░░░░░░  ░░░░░░  ░░░░  ░░░░░░            |
+---------------------------------------------+
```

### 4.3. Vazio — sem pendências (estado de sucesso operacional)

Quando **não há** cadastros pendentes (a equipe zerou a fila): ilustração leve (✓ em círculo `success-soft`), título e instrução positivos. **Não** "Nenhum resultado." seco.

```
+---------------------------------------------+
|              ( ✓ )                          |
|     Fila zerada — nada para analisar        |
|     Novos cadastros aparecem aqui assim que |
|     profissionais e contratantes se         |
|     pré-cadastrarem.                         |
+---------------------------------------------+
```

### 4.4. Vazio por filtro — filtro sem resultado

Distinto do 4.3: há pendências, mas o filtro ativo não casa com nenhuma.

```
+---------------------------------------------+
|     Nenhum cadastro deste tipo na fila      |
|     Ajuste os filtros para ver outros.      |
|             [ Limpar filtros ]              |
+---------------------------------------------+
```

### 4.5. Erro

- **Erro de carregamento (rede/banco):** banner `error-soft` no topo do painel + botão **Tentar de novo** (`wire:click`). Não esconde a tabela anterior se houver cache.
- **Race condition na ação (CA-6):** o usuário-alvo já não está `pendente_aprovacao` (outro admin agiu). Toast de erro: "Este cadastro já foi processado por outro admin." → drawer fecha → lista re-renderiza (item sumiu). Fail-secure — nenhuma transição parcial.
- **Erro inesperado na ação:** toast genérico honesto "Não foi possível concluir a ação. Tente novamente." — sem stack trace; o detalhe técnico vai para o log estruturado (CA-14).

### 4.6. Sem permissão

Não chega a renderizar: `AdminOnly` devolve **403** (autenticado não-admin) ou redireciona a `/login` (não autenticado), reusando a tela `errors/403.blade.php` da STORY-016. Sem caminho de UI próprio nesta tela.

### 4.7. Parcial / degradado

Se a foto não carrega (path quebrado/objeto ausente no storage), cai para **avatar com inicial do nome** sobre `accent.soft` — a análise não bloqueia por falta de foto. Se o template ativo não puder ser referenciado, mostra "Template: v1 (referência indisponível)" sem quebrar o detalhe.

## 5. Microcopy completo

| Lugar | Texto |
|---|---|
| Breadcrumb | `Backoffice · Admin` |
| Título da tela | `Cadastros pendentes` |
| Subtítulo | `{n} aguardando análise · SLA público de 24h` |
| Card contador — pendentes | `Pendentes` / valor `{n}` |
| Card contador — profissionais | `Profissionais` / `{n}` + sub `PF {a} · MEI {b} · PJ {c}` |
| Card contador — contratantes | `Contratantes` / `{n}` |
| Banner SLA (só se houver > 20h) | `{k} cadastro(s) há mais de 20h na fila — priorize para não estourar o SLA.` |
| Filtro papel | `Todos` · `Profissional` · `Contratante` |
| Filtro tipo (só profissional) | `PF` · `MEI` · `PJ` |
| Cabeçalho do painel | `Fila de análise` |
| Colunas | `Cadastro` · `Papel` · `Enviado` · (ações sem rótulo) |
| Sub-linha profissional | `{tipo_pessoa} · {função}` |
| Sub-linha contratante | `{tipo_operação}` |
| Chip SLA verde | `há {h}h` |
| Chip SLA amarelo | `há {h}h` |
| Chip SLA vermelho | `há {h}h` |
| CTA por linha | `Ver detalhes` |
| Paginação | `‹ Anterior` · `Página {x} de {y}` · `Próxima ›` |
| Detalhe — título | `Detalhe do cadastro` |
| Detalhe — fechar (aria) | `Fechar detalhe` |
| Detalhe — tempo na fila | `há {h}h na fila` |
| Detalhe — labels | `E-mail` · `Telefone` · `Cidade` · `Bairro` · `Função` · `Estabelecimento` · `Tipo de operação` · `Termos` · `Contrato aplicável` |
| Detalhe — termos | `aceitos em {dd/mm} {hh:mm}` |
| Detalhe — contrato PF | `PF autônomo eventual · v1 (ativo)` |
| Detalhe — contrato MEI/PJ/contratante | `MEI/PJ B2B · v1 (ativo)` |
| CTA primário (detalhe) | `Aprovar cadastro` |
| CTA destrutivo (detalhe) | `Remover` |
| Diálogo aprovar — título | `Confirmar aprovação?` |
| Diálogo aprovar — corpo | `{nome} poderá acessar o Turni e completar o cadastro. Um e-mail de aprovação será enviado.` |
| Diálogo aprovar — confirmar | `Aprovar` |
| Diálogo aprovar — cancelar | `Cancelar` |
| Diálogo remover — título | `Remover este cadastro?` |
| Diálogo remover — corpo | `Esta ação não pode ser desfeita. O cadastro de {nome} será removido da plataforma e não receberá aviso.` |
| Diálogo remover — confirmar | `Remover definitivamente` |
| Diálogo remover — cancelar | `Cancelar` |
| Toast — aprovado | `Cadastro aprovado. E-mail enviado a {email_mascarado}.` |
| Toast — removido | `Cadastro removido.` |
| Toast — race (erro) | `Este cadastro já foi processado por outro admin.` |
| Toast — erro genérico | `Não foi possível concluir a ação. Tente novamente.` |
| Estado vazio (fila zerada) — título | `Fila zerada — nada para analisar` |
| Estado vazio (fila zerada) — instrução | `Novos cadastros aparecem aqui assim que profissionais e contratantes se pré-cadastrarem.` |
| Estado vazio (filtro) — título | `Nenhum cadastro deste tipo na fila` |
| Estado vazio (filtro) — instrução | `Ajuste os filtros para ver outros.` |
| Estado vazio (filtro) — CTA | `Limpar filtros` |
| Erro de carregamento | `Não foi possível carregar a fila.` + CTA `Tentar de novo` |
| Aviso mobile | `Backoffice é desktop-first (≥1024px). Alargue a janela para ver o shell completo.` |

Vocabulário do glossário do PO: "Profissional", "Contratante", "Vaga", "Turno" — não rebatizo. "Remover" (não "Recusar") alinha com PDR-001 e o texto da estória (a `preview-backoffice.html` dizia "Recusar" — **divergência resolvida a favor da estória**, §8).

## 6. Acessibilidade (notas específicas — WCAG 2.1 AA, CA-10/CA-11)

Além do piso geral:

- **Indicador de SLA não depende só de cor** (CA-10): ícone (●/▲/■ ou similar) + cor + texto "há Xh". Os três tons (`success`/`warning`/`error`) sobre `*-soft` passam AA (tabela §6 de `tokens.md`).
- **Navegação por teclado** (CA-11): Tab percorre filtros → linhas → "Ver detalhes". Enter/Espaço abre o detalhe. No drawer, foco move para o título ao abrir; **focus trap** dentro do drawer; **Esc** fecha e devolve o foco à linha de origem.
- **Diálogos de confirmação**: `role="alertdialog"`, foco inicial no botão **Cancelar** (evita aprovação/remoção acidental por Enter), focus trap, Esc cancela.
- **Live region** para mudanças da lista após aprovar/remover (CA-11): container da tabela com `aria-live="polite"` anuncia "Cadastro aprovado, 11 pendentes". Toasts em `aria-live="assertive"` (erro) / `polite` (sucesso).
- **Foto** com `alt` = `Foto de {nome}`; avatar-fallback com `aria-hidden` na inicial e `aria-label` no container.
- **Alvos de clique** ≥ 40×40px (desktop; ≥44 em mobile-fallback).
- **Contraste**: todos os tokens usados são pares sancionados em `tokens.md §6` para os dois temas.

## 7. Identificadores estáveis sugeridos para teste (`data-testid` — Playwright/Pest)

| Elemento | Identificador |
|---|---|
| Container da tela | `screen-aprovacoes` |
| Contador pendentes | `aprovacoes-count-pendentes` |
| Contador profissionais (com breakdown) | `aprovacoes-count-profissionais` |
| Contador contratantes | `aprovacoes-count-contratantes` |
| Banner SLA | `aprovacoes-sla-banner` |
| Filtro papel (grupo) | `aprovacoes-filter-papel` |
| Filtro papel opção | `aprovacoes-filter-papel-{todos\|profissional\|contratante}` |
| Filtro tipo_pessoa opção | `aprovacoes-filter-tipo-{pf\|mei\|pj}` |
| Tabela / lista | `aprovacoes-list` |
| Linha de item | `aprovacoes-item-{userId}` |
| Indicador SLA do item | `aprovacoes-item-{userId}-sla` |
| CTA ver detalhes | `aprovacoes-item-{userId}-ver` |
| Drawer de detalhe | `aprovacoes-detail` |
| Detalhe — fechar | `aprovacoes-detail-close` |
| Botão Aprovar (detalhe) | `aprovacoes-detail-aprovar` |
| Botão Remover (detalhe) | `aprovacoes-detail-remover` |
| Diálogo aprovar — confirmar | `dialog-aprovar-confirm` |
| Diálogo aprovar — cancelar | `dialog-aprovar-cancel` |
| Diálogo remover — confirmar | `dialog-remover-confirm` |
| Diálogo remover — cancelar | `dialog-remover-cancel` |
| Toast | `aprovacoes-toast` |
| Estado vazio | `aprovacoes-empty` |
| Estado vazio (filtro) | `aprovacoes-empty-filter` |

## 8. Exceções ao Design System

| O que diverge | Por quê | Vira DDR? |
|---|---|---|
| **Desktop-first** em vez de mobile-first (Princípio #2) | PDR-003 define o Backoffice como ferramenta de mesa da equipe Turni; o `preview-backoffice.html` já assume ≥1024px. Mobile é fallback que não quebra, não paridade. | Não — já coberto por PDR-003 + DDR-001 (preview admin). |
| Botão **Remover** (não "Recusar") | A `preview-backoffice.html` rotulava "Recusar"; a estória + PDR-001 definem "remoção = recusa implícita". Alinho o microcopy à estória. | Não — correção de microcopy, não padrão novo. |
| **Confirmação dupla** na remoção (diálogo destrutivo com cópia forte + foco em Cancelar) | Ação irreversível (CA-8) sem histórico (PDR-001). | Candidato a virar **padrão DS** "ação destrutiva irreversível" se repetir em Disputas/Config. |
| Template contratual como **link de leitura placeholder** | `TemplateVersao` não existe (ADR-010 é spike; editor é STORY-020). | Não — placeholder temporário; vira referência real quando STORY-020 publicar versão. |

## 9. Protótipo HTML fiel (validação humana)

- **Localização:** `STORY-019-fila-aprovacao/index.html` (mesma pasta deste spec).
- **Cobertura:** todos os estados da §4 alcançáveis por chips no topo (`?state=` ou seletor visível): `lista`, `loading`, `vazio`, `vazio-filtro`, `erro`, `detalhe-prof`, `detalhe-contrat`, `dialog-aprovar`, `dialog-remover`, `toast-aprovado`, `toast-race`. Toggle de tema claro/escuro (admin navy). Viewport desktop (primário) + estreito (fallback com aviso).
- **Fidelidade:** tokens reais do DDR-001 (mesmas variáveis CSS do `preview-backoffice.html`). Microcopy = exatamente a tabela §5. `data-testid` da §7 aplicados.
- **Restrições:** HTML/CSS/JS vanilla, sem rede, sem build; abre clicando. Declara no topo "protótipo de validação, não código de produção".

### Checklist antes de `ready`

- [x] `index.html` existe e abre sem erro.
- [x] Todos os estados da §4 acessíveis.
- [x] Desktop + fallback estreito navegáveis.
- [x] Microcopy do protótipo = §5 palavra por palavra.
- [x] `data-testid` da §7 presentes.
- [x] Tokens reais do DS (DDR-001 admin) aplicados.
- [x] **Apresentado ao humano (Alexandro) e validação capturada** — aprovado em chat em 2026-05-29 após teste local da tela real.

## 10. Dependências e premissas

- **Dados:** lê `users` (`status=pendente_aprovacao`, `role`, `created_at`) + `profissional_profiles` / `contratante_profiles` (campos do pré-cadastro: telefone, cidade, bairro, função, foto_path, termos_aceitos_at) + `funcoes`. Schema de ADR-009 + migrações pré-cadastro STORY-017/018.
- **Ações (back):** `ApprovalService.approve()` / `.remove()` — transição de estado + audit log (`admin.user.approved` / `admin.user.removed`, ADR-009) + dispatch de e-mail (`aprovacao_concedida` via ACL ADR-011, fila `database`). Detalhe de contrato em STORY-019 (Programador).
- **Permissões:** `AdminOnly` (STORY-016).
- **Premissa do back:** remoção é **soft-delete via `status='recusado'`** (ADR-009 §Consequências — mantém registro para o audit log referenciar `target_id`; hard delete é job de retenção futuro). Confirmado no sync.
- **Pendência de DDR/dependência:** `TemplateVersao` (ADR-010/STORY-020) — enquanto não existe, o "contrato aplicável" é placeholder de leitura. Não bloqueia o `ready` deste spec (a estória CA-4 permite placeholder).

## 11. Histórico de mudanças

| Data | Mudança | Quem | Motivo |
|---|---|---|---|
| 2026-05-29 | criação + protótipo v1 | Designer (claude-opus-4-8) | rabisco→spec completo pós-sync com Programador na mesma sessão; base no `preview-backoffice.html` (DDR-001) |
| 2026-05-29 | estados completos + microcopy + a11y + protótipo navegável | Designer | cobre vazio (2x)/loading/erro/race/sem-permissão; SLA com ícone+cor+texto; drawer de detalhe |
| 2026-05-29 | validação humana | Alexandro | aprovado em chat após teste local da tela real no Backoffice (`localhost:8002/aprovacoes`) |

> Sync Designer↔Programador desta sessão registrado nas "Notas do agente" da `STORY-019`. Mudanças após o código começar entram aqui com data e motivo.
