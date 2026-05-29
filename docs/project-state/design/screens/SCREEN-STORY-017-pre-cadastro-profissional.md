---
id: SCREEN-STORY-017-pre-cadastro-profissional
story: STORY-017-pre-cadastro-profissional-webapp
epic: EPIC-001-cadastro-e-aprovacao
status: ready
created_at: 2026-05-29
updated_at: 2026-05-29
owner_designer: claude-opus-designer
related_ddrs: [DDR-001]
ds_components_used: [brand.logo, button.primary, link.text, surface.card, input.text, input.password, input.select, input.checkbox, segmented, banner]
exceptions_to_ds: [input.photo — componente novo materializado neste spec (upload de foto de perfil); input.select/input.checkbox/segmented — primeira materialização normativa do roadmap de components.md]
viewports: [mobile, desktop]
---

# Spec de tela — SCREEN-STORY-017 — Pré-cadastro de Profissional

> Referência: estória `STORY-017-pre-cadastro-profissional-webapp`. CAs e contexto vêm de lá — **não duplico**.
> Fundação visual: `DDR-001` + `docs/project-state/design/system/` (tokens, componentes, voice-and-tone).
> Contrato de back já implementado: `POST /api/cadastro/profissional` (ver §9). Coordene com as Notas do agente da estória.
> Princípios que guiaram: **#1** simplicidade (um form, uma tarefa — entrar na fila), **#2** mobile-first, **#3** tom profissional, **#5** acessibilidade WCAG AA, **#7** todos os estados, **#4** idiomático ao Flutter (Form/TextFormField/SegmentedButton/DropdownMenu — não invento padrão de form).

Este spec cobre **duas vistas + uma emenda**:

| Vista | Interface | Rota | Observação |
|---|---|---|---|
| **A** — Formulário de pré-cadastro | WebApp (Flutter) | `/cadastro/profissional` (**pública**, sem auth) | CA-1, CA-2, CA-6 |
| **B** — Recebido (sucesso pós-submit) | WebApp (Flutter) | estado interno da Vista A (sem rota própria) | CA-7 |
| **Emenda** — banner "em análise" no login | WebApp (Flutter) | `/login` (SCREEN-016 §A.5.5) | CA-8 — ver §10 |

---

## Decisão de tema e perfil (vale para todas as vistas)

- **Perfil:** **`profissional` (verde)** — é pré-login, papel ainda não autenticado, mas o cadastro **é** do profissional. Acento verde (`accent` do perfil profissional). A marca (`brand.green`) conduz no topo, igual ao login (SCREEN-016).
- **Tema:** claro por padrão; escuro definido (DDR-001) para não retrabalhar. MVP liga só o claro. Contrastes verificados nos dois temas em §6, usando os pares já sancionados em `tokens.md §6.1/§6.2`.

## Decisão de estrutura do formulário (local desta tela)

**Formulário único, rolável e seccionado** — **não** wizard/`Stepper`. Razão:

- O pré-cadastro é evento **único** e curto; um wizard adicionaria navegação back/next e estado entre passos para benefício marginal (Princípio #1 — simplicidade).
- Seções com título curto dão o chunking cognitivo que o não-técnico precisa **sem** fragmentar em telas.
- `Form` + `TextFormField`/`SegmentedButton`/`DropdownMenu` num `ListView`/`SingleChildScrollView` é o caminho idiomático do Flutter (Princípio #4) e o mais simples para validação client-side e E2E.

> **Paridade futura:** STORY-018 (pré-cadastro de Contratante) deve **espelhar** este padrão (form único seccionado). Se um terceiro cadastro surgir com o mesmo padrão, promover a **DDR** ("cadastro inicial = form único seccionado, nunca wizard") pela regra de três. Por ora é decisão local registrada aqui.

---

## Componentes novos / primeira materialização

`input.select`, `input.checkbox` e `segmented` estão no **roadmap** de `components.md` (EPIC-001+). `input.photo` é **novo**. Definições mínimas e normativas (o Programador implementa; o Designer leva ao DS via DDR na próxima sessão):

### `input.select` — seleção de função
- **Flutter:** `DropdownButtonFormField` (ou `DropdownMenu` M3) com `InputDecoration` `filled`, mesma anatomia visual do `input.text` (SCREEN-016): fundo `surface`, borda `border.subtle` 1dp, borda focus `accent` 2dp, raio `radius.md`, altura ≥48dp, `labelText` flutuante.
- **Itens:** vêm da API (`funcoes`, `ativo=true`) — ver §9. Ordenar alfabeticamente pelo `nome`.
- **Estados:** default · focused · selected · error · disabled.
- **A11y:** `labelText` é o rótulo semântico; opções navegáveis por teclado; seleção anunciada.

### `segmented` — tipo de pessoa (PF / MEI / PJ)
- **Flutter:** `SegmentedButton<String>` (M3), 3 segmentos, seleção **única** (`multiSelectionEnabled: false`), sem `showSelectedIcon` para caber em mobile estreito.
- **Visual:** segmento selecionado usa `accent.soft` de fundo + `accent.ink` de texto + borda `accent`; não-selecionado `surface` + `text.muted`. Altura ≥48dp.
- **Quebra mobile (≥360dp):** três segmentos "PF | MEI | PJ" cabem lado a lado (labels curtos). Se faltar largura, `SegmentedButton` já rola/encolhe; não empilhar.
- **A11y:** comporta-se como **radiogroup** — `Semantics` de grupo com label "Tipo de pessoa", cada segmento é uma opção selecionável anunciada como selecionada/não-selecionada. Navegável por teclado (setas).

### `input.checkbox` — aceite dos termos
- **Flutter:** `CheckboxListTile` (ou `Row` com `Checkbox` + `Text.rich`) com área de toque ≥48dp.
- **Conteúdo:** rótulo com **dois links inline** (`link.text`) para Termos de Uso e Política de Privacidade.
- **Estado de erro:** quando submetido sem marcar, exibe `errorText` abaixo, em `error` + ícone (não só cor).
- **A11y:** `Semantics(checked: ..., label: 'Li e aceito os Termos de Uso e a Política de Privacidade')`; os links são focáveis independentemente do checkbox.

### `input.photo` — foto de perfil (**componente novo — exceção ao DS**)
- **Flutter:** botão/área de upload usando `image_picker` (galeria/câmera em mobile; seletor de arquivo em web). **A escolha da lib é do Programador** (registrar em IDR se transversal) — o spec define só comportamento e visual.
- **Anatomia (vazio):** área quadrada (avatar) `radius.full` ou card `radius.lg` com ícone `Icons.add_a_photo_outlined` em `accent`, borda tracejada `border.strong`, label "Adicionar foto" e hint de formato. Alvo ≥48dp.
- **Anatomia (selecionada):** preview circular da imagem (ratio 1:1 sugerido), com ação "Trocar foto" (`link.text`) ao lado/abaixo.
- **Estados:** vazio · selecionada (preview) · erro (tipo/tamanho — §4.4) · enviando (parte do loading geral do submit).
- **A11y:** botão com `Semantics(button: true, label: 'Adicionar foto')`; após selecionar, `Semantics(label: 'Foto selecionada. Trocar foto.')`.

---

## Vista A — Formulário de pré-cadastro

### A.1. Objetivo

Profissional (Diego — PF, ou MEI/PJ) preenche os dados mínimos, escolhe o tipo de pessoa, aceita os Termos e **envia o cadastro para a fila de aprovação**. Não loga — fica aguardando aprovação (SLA 24h). **Uma** tarefa: entrar na fila.

### A.2. Fluxo

**Entrada:**
- Link público da landing / divulgação → `app.homolog.turni.com.br/cadastro/profissional`.
- Link "Cadastre-se" a partir do `/login` (sugestão de melhoria — ver §10, não-bloqueante).
- Rota **pública**: adicionar `/cadastro/profissional` ao conjunto `publicRoutes` do `router.dart` (hoje `{'/', '/login', '/esqueci-minha-senha', '/health'}`). Sem funnel guard.

**Ações possíveis:**
1. Preencher os campos e tocar **"Enviar cadastro"** (ação primária — uma só).
2. Selecionar/trocar a foto.
3. Alternar tipo de pessoa (PF/MEI/PJ).
4. Mostrar/ocultar senha.
5. Abrir Termos de Uso / Política de Privacidade (links — abrem em nova aba/rota estática; placeholder OK no MVP).
6. "Já tem conta? Entrar" → `/login` (`link.text`).

**Saídas por resultado de `POST /api/cadastro/profissional`:**

| Resposta da API | Comportamento do WebApp |
|---|---|
| `201 { success: true, message }` | Troca para a **Vista B (Recebido)** na mesma rota. **Não** inicia sessão. |
| `422` com `errors` de validação (campos) | Marca os campos com `errorText` específico (§A.5.9). Foca o primeiro campo inválido. |
| `422 { code: 'cadastro_nao_concluido', message, hint }` (e-mail já existe / falha genérica — CA-4) | Banner genérico **sem revelar enumeração** + link "Entrar" (§A.5.4). |
| `429` (throttle anti-bot) | Banner de throttle (§A.5.5). |
| `5xx` / falha de rede | Banner de erro recuperável com "Tentar de novo" (§A.5.6). |

### A.3. Layout

#### Mobile (≥360dp)

```
+----------------------------------+
|  ← Já tem conta? Entrar           |  ← link.text topo-direita (32dp toque)
|                                   |
|         TURNI.                    |  ← brand.logo display (≥48dp)
|  Criar conta de profissional      |  ← headline
|  Leva 2 minutos. A equipe Turni   |  ← body-sm, text.muted
|  revisa em até 24h.               |
|                                   |
|  ── Seus dados ──                 |  ← título de seção (overline/label)
|  [Nome completo              ]    |  ← input.text
|  [E-mail                     ]    |  ← input.text (emailAddress)
|  [Telefone                   ]    |  ← input.text (phone)
|                                   |
|  ── Onde você atua ──             |
|  [Cidade                     ]    |  ← input.text
|  [Bairro                     ]    |  ← input.text
|  [Função pretendida        ▾ ]    |  ← input.select
|                                   |
|  ── Tipo de cadastro ──           |
|  [  PF  |  MEI  |  PJ  ]           |  ← segmented (radiogroup)
|  Você envia seu documento depois  |  ← hint, text.muted, caption
|  da aprovação.                    |
|                                   |
|  ── Sua foto ──                   |
|   (•) Adicionar foto              |  ← input.photo (vazio)
|   JPG ou PNG, até 5 MB.           |  ← hint
|                                   |
|  ── Sua senha ──                  |
|  [Senha                  👁  ]    |  ← input.password
|  Use 10+ caracteres, com letras   |  ← hint
|  maiúsculas, minúsculas e números.|
|  [Confirmar senha        👁  ]    |  ← input.password
|                                   |
|  [✓] Li e aceito os Termos de Uso |  ← input.checkbox + links
|      e a Política de Privacidade. |
|                                   |
|  [       Enviar cadastro       ]  |  ← button.primary full-width
|                                   |
|  [ banner de erro/aviso ]         |  ← só em estado de erro (§A.5)
+----------------------------------+
```

- Coluna única, padding lateral `space.lg` (24dp), `SingleChildScrollView`.
- Largura máx do conteúdo: 480dp, centralizado.
- Fundo `surface.page`. **Sem card** em mobile — a tela **é** o form (igual ao login).
- Títulos de seção: `label`/`overline` em `text.muted`, com `space.xl` acima de cada seção. São **rótulos visuais de agrupamento**, não campos.
- CTA "Enviar cadastro": full-width, `button.primary` (pílula `radius.full`, altura ≥48dp). Pode usar `bottomSheet`/sticky se a rolagem for longa — **opcional**; o aceitável mínimo é o botão ao fim do form.

#### Desktop (≥840dp)

```
+------------------------------------------------------+
|                              Já tem conta? Entrar     |
|              +-----------------------------+          |
|              |        TURNI.               |          |
|              |  Criar conta de profissional|          |
|              |  Leva 2 minutos…            |          |
|              | ─────────────────────────── |          |
|              |  Seus dados                 |          |
|              |  [Nome completo          ]  |          |  surface.card
|              |  [E-mail                 ]  |          |  elev.1, radius.lg
|              |  [Telefone               ]  |          |  max-width 560dp
|              |  Onde você atua             |          |  padding space.xl
|              |  [Cidade      ] [Bairro  ]  |  ← 2 col |
|              |  [Função pretendida    ▾ ]  |          |
|              |  Tipo de cadastro           |          |
|              |  [ PF | MEI | PJ ]          |          |
|              |  Sua foto                   |          |
|              |   (•) Adicionar foto        |          |
|              |  Sua senha                  |          |
|              |  [Senha     👁][Conf.   👁] |  ← 2 col |
|              |  [✓] Li e aceito os Termos… |          |
|              |  [     Enviar cadastro    ] |          |
|              |  [banner]                   |          |
|              +-----------------------------+          |
+------------------------------------------------------+
```

- `surface.card` (`elev.1`, `radius.lg`) engloba o form; logo + título dentro do card (diferente do login, que mantém logo fora — aqui o conteúdo é maior e o card ancora tudo). Max-width do card **560dp**, centralizado, respiro vertical ≥ `space.3xl`.
- **Espaço extra com propósito** (não "mobile esticado"): pares de campos curtos em 2 colunas — **Cidade + Bairro** e **Senha + Confirmar senha**. Nome, E-mail, Função e Tipo permanecem largura plena. Use `Wrap`/`Row` com `Expanded` e colapso para 1 coluna abaixo de `bp.expanded` (840dp).
- Link "Já tem conta? Entrar" no topo-direito da viewport.

#### Tablet (600–840dp)

Herda o mobile (coluna única) dentro de um container `maxWidth: 480dp` centralizado; **sem** as 2 colunas do desktop (não há largura confortável). Sem card até 840dp.

### A.4. Detalhes dos campos

| Campo | Config Flutter | Validação client-side (espelha o back — §9) |
|---|---|---|
| Nome completo | `textCapitalization: words`, `textInputAction: next`, `autofocus` (só desktop) | obrigatório; 3–120 chars |
| E-mail | `keyboardType: emailAddress`, `autocorrect: false`, `next` | obrigatório; formato `@` + `.` |
| Telefone | `keyboardType: phone`, `next`; máscara BR sugerida (não obrigatória) | obrigatório; DDD + 8–9 dígitos |
| Cidade | `textCapitalization: words`, `next` | obrigatório |
| Bairro | `textCapitalization: words`, `next` | obrigatório |
| Função pretendida | `input.select`, itens da API | obrigatório; valor da lista |
| Tipo de pessoa | `segmented` PF/MEI/PJ, seleção única | obrigatório; default **nenhum** selecionado (força escolha consciente) |
| Foto | `input.photo` | obrigatório; JPG/PNG; ≤5 MB |
| Senha | `input.password`, `next`, `autocomplete: new-password` | obrigatório; ≥10, maiúscula+minúscula+número |
| Confirmar senha | `input.password`, `done`, `onFieldSubmitted → submit` | obrigatório; **igual** à senha |
| Aceite dos Termos | `input.checkbox` | obrigatório; deve estar marcado |

**Quando validar:** no **blur** de cada campo (`autovalidateMode: onUserInteraction`) **e** no submit (`Form.validate()`). Mensagens citam o campo e dizem o que corrigir (Princípio voice-and-tone; CA-2).

### A.5. Estados

#### A.5.1. Caminho feliz (preenchível)
Form completo conforme §A.3. CTA habilitado. Microcopy em §A.6.

#### A.5.2. Loading (durante o submit)
- CTA "Enviar cadastro" → estado `loading`: label vira `CircularProgressIndicator` (`on-accent`); botão e campos desabilitados.
- Sem skeleton (não há fetch de tela; só a submissão). Duração esperada inclui upload da foto — manter o spinner até a resposta. Se > 1.5s, manter o botão em loading (sem texto extra).

#### A.5.3. Sucesso → **Vista B (Recebido)**
Ver §B. Transição `motion.base` (200ms) de fade/replace do conteúdo do form pela mensagem de recebido. **Não** navega para rota nova nem inicia sessão.

#### A.5.4. Erro genérico de cadastro (CA-4 — e-mail já existe / falha)
Banner inline acima/abaixo do CTA (não modal, não toast):

```
+-----------------------------------------+
|  ● Não foi possível concluir o cadastro.|  ← ícone error + text.strong
|    Verifique os dados e tente novamente.|  ← text.muted, body-sm
|    Já tem conta? Entrar                 |  ← link.text → /login
+-----------------------------------------+
```

- Fundo `error-soft`, borda `error` 1dp, `radius.md`, ícone `Icons.error_outline` em `error`.
- **Não revela** se o e-mail já existe (mensagem idêntica a qualquer falha genérica — proteção contra enumeração, CA-4).
- `Semantics(liveRegion: true)`.

#### A.5.5. Throttle (429)
```
+-----------------------------------------+
|  ● Muitas tentativas.                   |
|    Aguarde alguns minutos antes de      |
|    tentar novamente.                    |
+-----------------------------------------+
```
- Fundo `error-soft`. CTA desabilitado temporariamente (espelha o padrão do login).

#### A.5.6. Erro de servidor / rede (5xx, offline)
```
+-----------------------------------------+
|  ● Não conseguimos enviar agora.        |
|    Tentar de novo                       |  ← link.text re-submete
+-----------------------------------------+
```
- Fundo `error-soft`. Os dados do form **permanecem preenchidos** (não limpar em erro recuperável).

#### A.5.7. Foto inválida (tipo/tamanho — CA-6)
Erro **associado ao componente da foto**, não banner global:
- Tipo não permitido: "A foto deve ser JPG ou PNG."
- Acima de 5 MB: "A foto deve ter no máximo 5 MB."
- Texto em `error` + ícone, abaixo da área de foto. A imagem inválida **não** é anexada.

#### A.5.8. Sem permissão / offline ao abrir
Rota **pública** — não há estado "sem permissão". Offline ao abrir: a tela é estática (form), renderiza normalmente; o erro só aparece no submit (§A.5.6).

#### A.5.9. Validação de campo (blur/submit)

| Campo | Condição | Texto do erro |
|---|---|---|
| Nome completo | vazio | Informe seu nome completo. |
| Nome completo | < 3 | O nome deve ter ao menos 3 caracteres. |
| E-mail | vazio | Informe seu e-mail. |
| E-mail | formato inválido | Informe um e-mail válido (ex.: nome@dominio.com). |
| Telefone | vazio | Informe seu telefone. |
| Telefone | formato inválido | Informe um telefone válido com DDD (ex.: (11) 91234-5678). |
| Cidade | vazia | Informe sua cidade. |
| Bairro | vazio | Informe seu bairro. |
| Função | não selecionada | Selecione a função pretendida. |
| Tipo de pessoa | não selecionado | Selecione o tipo de cadastro: PF, MEI ou PJ. |
| Foto | ausente | Adicione uma foto. |
| Senha | vazia / fraca | A senha deve ter ao menos 10 caracteres, com maiúscula, minúscula e número. |
| Confirmar senha | diferente | As senhas não conferem. |
| Termos | não marcado | É necessário aceitar os Termos de Uso e a Política de Privacidade. |

### A.6. Microcopy

| Lugar | Texto |
|---|---|
| Link topo "já tenho conta" | Já tem conta? Entrar |
| Logo | `TURNI.` (leitor anuncia "Turni") |
| Título da tela | Criar conta de profissional |
| Subtítulo | Leva 2 minutos. A equipe Turni revisa em até 24h. |
| Seção 1 | Seus dados |
| Label nome | Nome completo |
| Placeholder nome | Ex.: Diego Almeida |
| Label e-mail | E-mail |
| Placeholder e-mail | seunome@email.com |
| Label telefone | Telefone |
| Placeholder telefone | Ex.: (11) 91234-5678 |
| Hint telefone | Use o número com DDD que recebe WhatsApp. |
| Seção 2 | Onde você atua |
| Label cidade | Cidade |
| Label bairro | Bairro |
| Label função | Função pretendida |
| Placeholder/hint função | Escolha a principal |
| Seção 3 | Tipo de cadastro |
| Segmentos | PF · MEI · PJ |
| Hint tipo de pessoa | Você envia seu documento depois da aprovação. |
| Seção 4 | Sua foto |
| Foto (vazio) | Adicionar foto |
| Hint foto | JPG ou PNG, até 5 MB. |
| Foto (selecionada) | Trocar foto |
| Seção 5 | Sua senha |
| Label senha | Senha |
| Hint senha | Use 10+ caracteres, com letras maiúsculas, minúsculas e números. |
| Label confirmar | Confirmar senha |
| Checkbox termos | Li e aceito os {Termos de Uso} e a {Política de Privacidade}. |
| Link Termos | Termos de Uso |
| Link Política | Política de Privacidade |
| CTA primário | Enviar cadastro |
| CTA loading | `[spinner]` |
| Erro genérico (linha 1) | Não foi possível concluir o cadastro. |
| Erro genérico (linha 2) | Verifique os dados e tente novamente. |
| Erro genérico (link) | Já tem conta? Entrar |
| Throttle (linha 1) | Muitas tentativas. |
| Throttle (linha 2) | Aguarde alguns minutos antes de tentar novamente. |
| Erro servidor (linha 1) | Não conseguimos enviar agora. |
| Erro servidor (link) | Tentar de novo |
| Show/Hide senha | Mostrar senha / Ocultar senha |

> Os textos de validação por campo estão em §A.5.9. Mensagens batem com as `messages()` do `FormRequest` do back (§9), com pequenas diferenças aceitáveis de tom — quando divergirem, **o texto deste spec prevalece** na UI (o back é defesa em profundidade).

### A.7. Acessibilidade

- **Ordem de foco / leitura:** link "Entrar" → logo (header) → título → seções na ordem visual (nome → e-mail → telefone → cidade → bairro → função → tipo de pessoa → foto → senha → confirmar → termos → links dos termos → CTA → banner). Ordem DOM = ordem visual.
- **Foco inicial:** logo (`Semantics(header: true)`); **não** roubar foco para o primeiro campo no mobile (deixar autofocus só no desktop, igual ao login).
- **`segmented`** = radiogroup: `Semantics` de grupo "Tipo de pessoa"; navegação por setas; estado selecionado anunciado.
- **`input.checkbox`**: estado `checked` anunciado; os dois links são focáveis e descrevem o destino ("Termos de Uso", "Política de Privacidade") — nunca "clique aqui".
- **`input.photo`**: botão com label; após anexar, anuncia "Foto selecionada".
- **Erros de campo**: `errorText` do `TextFormField`/wrapper, anunciados via `liveRegion`. Erro **associado ao campo**, nunca só borda vermelha.
- **Banners**: `Semantics(liveRegion: true)` — anunciados ao surgir.
- **Teclado:** Tab percorre na ordem acima; Enter em "Confirmar senha" aciona o submit. Toggle de senha e checkbox acionáveis por teclado.
- **Alvos de toque ≥48dp**: campos, toggles, segmentos, checkbox, área de foto, CTA.
- **Contraste (claro — perfil profissional, pares sancionados `tokens.md §6.1`):**
  - `text.strong` `#0F1B2D` / `surface.page` `#F7F4EC` = 15.7:1 ✅ · / `surface` `#FFF` = 17.3:1 ✅
  - `text.muted` `#42504A` / `surface.page` = 7.7:1 ✅ (hints, subtítulo, títulos de seção)
  - CTA: `on-accent` `#FFF` / `accent` `#2D5F3F` = 7.4:1 ✅
  - Link/segmento ativo: `accent.ink` `#2D5F3F` / `surface` = 7.4:1 ✅
  - Erro: `#FFF` / `error` `#B83A3A` = 5.7:1 ✅ (ícone/UI ≥3:1)
- **Contraste (escuro — `tokens.md §6.2`):** `text.strong` `#ECEDE5`/`#0F1411` 15.8:1 ✅; `text.muted` `#A8B2A8`/`surface` 7.6:1 ✅; CTA `on-accent` `#0F1411`/`accent` `#5FA37C` 6.1:1 ✅.
- **`prefers-reduced-motion`:** sem animações obrigatórias; transição form→sucesso usa `motion.base` só se motion habilitado.

### A.8. Identificadores para teste (E2E — CA-9 / widget tests — CA-11)

Nomes lógicos; o Programador aplica como `Key('...')`/`ValueKey('...')`.

| Elemento | Identificador lógico |
|---|---|
| Raiz da tela | `screen-cadastro-profissional` |
| Campo nome | `input-nome` |
| Campo e-mail | `input-email` |
| Campo telefone | `input-telefone` |
| Campo cidade | `input-cidade` |
| Campo bairro | `input-bairro` |
| Select função | `input-funcao` |
| Segmented tipo de pessoa | `segmented-tipo-pessoa` |
| Opção PF / MEI / PJ | `segment-pf` · `segment-mei` · `segment-pj` |
| Área de foto | `input-foto` |
| Botão trocar foto | `btn-trocar-foto` |
| Campo senha | `input-password` |
| Campo confirmar senha | `input-password-confirm` |
| Toggle mostrar/ocultar senha | `btn-toggle-password` (× 2 — usar sufixo no confirmar) |
| Checkbox termos | `check-termos` |
| Link Termos de Uso | `link-termos` |
| Link Política | `link-privacidade` |
| CTA enviar | `btn-submit-cadastro` |
| Banner erro genérico | `banner-cadastro-erro` |
| Banner throttle | `banner-throttle` |
| Banner erro servidor | `banner-servidor` |
| Painel de sucesso (Vista B) | `panel-cadastro-recebido` |
| CTA voltar à home (Vista B) | `btn-voltar-home` |

---

## Vista B — Recebido (sucesso pós-submit) — CA-7

### B.1. Objetivo
Confirmar o recebimento do cadastro, reforçar o SLA de 24h e oferecer uma saída sem login.

### B.2. Layout (mobile e desktop — mesma estrutura centrada)

```
+----------------------------------+
|                                  |
|         TURNI.                   |  ← brand.logo display
|                                  |
|         ✓                        |  ← ícone success (Icons.check_circle_outline)
|  Cadastro recebido.              |  ← headline
|                                  |
|  Em até 24h a equipe Turni       |  ← body, text.muted
|  revisa seu cadastro e envia     |
|  uma notificação por e-mail.     |
|                                  |
|  [     Voltar à home     ]       |  ← button.primary → '/'
|                                  |
+----------------------------------+
```

- Substitui o conteúdo do form na **mesma rota** `/cadastro/profissional` (sem rota própria → ninguém cai no sucesso por deep-link sem ter enviado).
- Ícone de sucesso em `success` (claro `#2D7A4F` / escuro `#5FA37C`) — discreto, **sem** emoji, sem confete (Princípio #3 / voice-and-tone: "Sucesso celebra com discrição").
- Coluna única centralizada, `maxWidth` 400dp, padding `space.lg`.

### B.3. Microcopy

| Lugar | Texto |
|---|---|
| Logo | `TURNI.` |
| Título | Cadastro recebido. |
| Corpo | Em até 24h a equipe Turni revisa seu cadastro e envia uma notificação por e-mail. |
| CTA | Voltar à home |

> O corpo reflete a `message` do back (`Cadastro recebido. Em até 24h a equipe Turni revisa e envia notificação por e-mail.`). Pode-se exibir diretamente a `message` da API **ou** o texto deste spec — ambos equivalentes; preferir o deste spec por tom.

### B.4. Acessibilidade
- Foco move para o título de sucesso ao aparecer (`Semantics(liveRegion: true)` no painel) — o leitor anuncia "Cadastro recebido."
- Ícone de sucesso tem `Semantics(label: 'Sucesso')` — nunca cor sozinha.

---

## §10. Emenda ao SCREEN-016 — banner "em análise" no login (CA-8)

CA-8 da STORY-017 pede que o usuário em `status: pendente_aprovacao` que tente logar veja uma mensagem clara **com o SLA de 24h**. Esse estado **já existe** (SCREEN-016 §A.5.5 / `login_screen.dart` `_BannerState.pending()` / key `banner-pending`), porém o texto atual é:

> "Sua conta está em análise. Você receberá um aviso quando for aprovada."

**Mudança consciente (refino de microcopy) para satisfazer CA-8:**

> **"Seu cadastro está em análise. Em até 24h enviaremos uma notificação por e-mail."**

- **Onde:** `apps/webapp/lib/features/auth/login_screen.dart` → `_BannerState.pending()`. Sem mudança de layout, ícone (`hourglass_top_outlined`, `warning`) ou key (`banner-pending`).
- **Por quê:** alinha a promessa pública do SLA de 24h entre o cadastro (Vista B) e o retorno no login. Coerência de tom e de prazo.
- **Impacto:** trivial (uma string). O widget test de `banner-pending` da STORY-016, se asserta o texto literal, precisa atualizar a expectativa. Registrar nas Notas do agente da STORY-017.

---

## §11. Exceções ao Design System

| O que diverge | Por quê | Vira DDR? |
|---|---|---|
| `input.photo` componente novo | Upload de foto de perfil não existe no DS; primeira necessidade real. Definição mínima aqui. | **Sim** — Designer leva a `components.md` via DDR na próxima sessão; Programador registra a lib escolhida em IDR. |
| `input.select` / `input.checkbox` / `segmented` materializados | Estavam no roadmap de `components.md`; primeira materialização normativa. | Sim — atualização de `components.md` por DDR junto com a do SCREEN-016 (input.text/password). |
| Card no desktop engloba logo + título (login mantém logo fora) | O conteúdo do cadastro é maior; o card ancora a leitura. Divergência local justificada. | Não. |
| Form único seccionado (não wizard) | Decisão local desta tela (§"Decisão de estrutura"). Candidata a DDR se STORY-018 + um terceiro repetirem (regra de três). | Talvez (futuro). |

---

## §12. Dependências e premissas

- **Contrato de API (já implementado):** `POST /api/cadastro/profissional` (rota pública, no grupo stateful/CSRF do Sanctum). Campos: `name, email, telefone, cidade, bairro, funcao_id, tipo_pessoa (PF|MEI|PJ), foto (multipart, JPG/PNG ≤5MB), password, password_confirmation, termos_aceitos`. Respostas em §A.2. **Não** retorna sessão (sem auto-login).
- **Lista de funções:** precisa de um endpoint **GET** para popular o `input.select` a partir de `funcoes (ativo=true)`. **Hoje não existe** um `GET /api/funcoes` — ver §13 (ponto de sync com o Programador). Enquanto não houver, o `input.select` pode consumir uma lista injetada/estática espelhando o seed, mas o caminho correto é o endpoint.
- **CSRF:** submit público segue o padrão Sanctum (obter cookie `/sanctum/csrf-cookie` antes do POST) — detalhe de implementação do Programador.
- **Páginas estáticas de Termos/Política:** placeholders no MVP; manter URL aberta (decisão do PO/Turni). O link só precisa abrir algo — conteúdo definitivo é responsabilidade futura.
- **DDR-001:** tokens, esquema profissional como pré-login, dual theme.
- **SCREEN-016:** padrões de `input.text`/`input.password`/banner reutilizados aqui (mesma anatomia, mesmas keys onde fizer sentido).
- **Tema escuro:** definido; MVP liga só o claro (igual ao login).

## §13. Sincronismo Designer↔Programador (≤15 min) — pontos a alinhar antes da UI

1. **Endpoint de funções (`GET /api/funcoes`):** confirmar se o Programador cria o endpoint para o `input.select` (recomendado) ou se a lista entra estática espelhando o seed no MVP. **Decisão de implementação do Programador** — registrar a escolha nas Notas. (O Designer recomenda o endpoint, por coerência com IDR-008.)
2. **Lib de upload de foto** (`image_picker` ou equivalente) e como o `multipart` é montado no Flutter Web — Programador decide e registra em IDR se transversal.
3. **Rota pública:** adicionar `/cadastro/profissional` ao `publicRoutes` do `router.dart`.
4. **CA-8 (emenda §10):** refino do texto do `banner-pending` no login — confirmar e ajustar o widget test correspondente.
5. **Máscara de telefone:** opcional; se não houver, validação por regex já cobre. Programador decide.

---

## §14. Histórico de mudanças

| Data | Mudança | Quem | Motivo |
|---|---|---|---|
| 2026-05-29 | Criação em `ready` | designer (claude-opus) | Spec completo para STORY-017: form de pré-cadastro (Vista A) + tela de recebido (Vista B) + emenda CA-8 no login. Materializa `input.select`, `input.checkbox`, `segmented` e o novo `input.photo`. Backend já implementado — spec alinhado ao contrato existente. |
