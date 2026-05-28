---
id: SCREEN-STORY-016-login-e-rbac
story: STORY-016-rbac-vivo-login-roteamento-por-papel
epic: EPIC-001-cadastro-e-aprovacao
status: ready
created_at: 2026-05-28
updated_at: 2026-05-28
owner_designer: claude-sonnet-4-6-designer-2026-05-28
related_ddrs: [DDR-001]
ds_components_used: [brand.logo, button.primary, link.text, surface.card, input.text, input.password]
exceptions_to_ds: [input.text — definido neste spec pela primeira vez (componente no roadmap DDR-001); input.password — variante de input.text com toggle de visibilidade]
viewports: [mobile, desktop]
---

# Spec de tela — SCREEN-STORY-016 — Login e RBAC

> Referência: estória `STORY-016-rbac-vivo-login-roteamento-por-papel`. CAs e contexto vêm de lá — **não duplico**.
> Fundação visual: `DDR-001` + `docs/project-state/design/system/`.
> Princípios que guiaram: #1 (simplicidade — telas de login fazem uma coisa), #3 (tom profissional), #5 (acessibilidade WCAG AA), #4 (idiomático ao Flutter/Livewire — não invento padrão de form).

Este spec cobre **cinco vistas**:

| Tela | Interface | Rota |
|---|---|---|
| **A** — Login | WebApp (Flutter) | `/login` |
| **B** — Login | Backoffice (Livewire) | `/login` |
| **C** — Placeholder welcome | WebApp (Flutter) | `/welcome` |
| **D** — Placeholder completar cadastro | WebApp (Flutter) | `/completar-cadastro` |
| **E** — Stub recuperação de senha | WebApp (Flutter) | `/esqueci-minha-senha` |

---

## Decisão de tema e esquema (vale para todas as telas)

**Dimensão tema:** claro por padrão; escuro via `prefers-color-scheme` + toggle persistido (igual ao `initTheme()` do protótipo `app.html`). O tema escuro está fora do MVP em `non-functional.md`, mas a fundação DDR-001 define ambos — este spec cobre os dois temas de forma que o Programador não precise revisitar quando o dark entrar. O MVP **liga** apenas o claro; o toggle pode ser condicional por feature flag.

**Dimensão perfil:**

| Tela | Perfil | Razão |
|---|---|---|
| A (Login WebApp) | **`profissional` (verde)** | Pré-login — papel desconhecido. Esquema neutro/padrão conforme tokens.md §1. Pós-login, o WebApp atualiza o esquema para o papel real do usuário (`contratante` = mostarda, `profissional` = verde). |
| B (Login Backoffice) | **`admin` (azul-navy)** | Backoffice é exclusivo do papel admin; o esquema é admin desde a tela de entrada. |
| C, D, E (placeholders/stub) | **`profissional` (verde)** | Pré-ativo, mesmo esquema neutro do WebApp. |

---

## Componentes novos definidos neste spec

O `input.text` e o `input.password` estão no roadmap de `components.md` (EPIC-001+). Este é o primeiro spec que os materializa. Definição mínima e normativa:

### `input.text`

**Flutter:** `TextFormField` com `InputDecoration` preenchida (variant `filled`).

**Anatomia:**

| Elemento | Token / valor |
|---|---|
| Fundo do campo | `surface` |
| Borda inativa | `border.subtle` (1dp) |
| Borda focus | `accent` do perfil (2dp) |
| Borda erro | `error` (2dp) |
| Rótulo flutuante (`labelText`) | `text.muted`, transição para `caption`/`accent` ao focar |
| Texto digitado | `text.strong`, `body` |
| Helper/hint | `text.subtle`, `caption` |
| Texto de erro | `error`, `caption`, sempre com ícone de alerta à esquerda |
| Altura mínima | 48dp (touch target) |
| Raio | `radius.md` (12dp) |
| Padding interno | `space.md` horizontal, vertical para centralizar a linha de texto |

**Estados:** default · focused · filled · error · disabled (opacidade 38%).

**A11y:** `labelText` é o rótulo semântico (`semanticsLabel` se necessário). Não use apenas `hintText` como rótulo — o hint desaparece ao digitar. `errorText` anuncia o erro via `SemanticsProperties.liveRegion`.

### `input.password`

`input.text` com `obscureText: true` e sufixo `IconButton`:

- Ícone: `Icons.visibility_outlined` (senha oculta) / `Icons.visibility_off_outlined` (senha visível).
- Tooltip/semantics: "Mostrar senha" / "Ocultar senha".
- Alvo de toque do ícone ≥48dp.
- `textInputAction: TextInputAction.done` (ou `.next` se houver campo seguinte).

---

## Tela A — Login WebApp

### A.1. Objetivo

Usuário (`contratante` ou `profissional`) informa e-mail + senha e entra no WebApp. Administradores são redirecionados ao Backoffice. Senha nunca vaza em log ou response (ADR-008).

**Tema claro por padrão. Perfil `profissional` (verde).**

### A.2. Fluxo

**Entrada:** usuário navega para `app.homolog.turni.com.br/login` (direto ou redirecionado pelo funnel guard ao tentar acessar rota protegida sem sessão).

**Ações possíveis:**

1. Preencher e-mail + senha e clicar "Entrar".
2. Clicar "Esqueci minha senha" → navega para `/esqueci-minha-senha` (Tela E).
3. Toggle show/hide senha.

**Saídas por resultado de `POST /api/login`:**

| Resposta da API | Comportamento do WebApp |
|---|---|
| `role: contratante|profissional, status: ativo` | WebApp entra no app. Esquema de cor atualizado para o papel real. |
| `role: profissional|contratante, status: liberado, welcome_seen_at: null` | Redirecionado para `/welcome` (CA-10). |
| `role: profissional|contratante, status: liberado, welcome_seen_at: != null` | Redirecionado para `/completar-cadastro` (CA-10). |
| `role: profissional|contratante, status: pendente_aprovacao` | Exibe banner "Conta em análise" (§A.5 estado pendente). |
| `role: profissional|contratante, status: recusado` | Exibe banner "Cadastro não aprovado" (§A.5 estado recusado). |
| `role: admin` (autenticado com sucesso) | API retorna código específico; WebApp exibe banner com link para o Backoffice (CA-7). |
| Credencial inválida (401/422) | Banner de erro genérico (CA-3 — sem leak). |
| Throttle (429) | Banner de throttle (CA-3). |
| Erro de servidor (500+) | Banner "Não conseguimos entrar agora. Tentar de novo." |

### A.3. Layout

#### Mobile (≥360dp)

```
+-----------------------------+
|                             |
|     (respiro space.2xl)     |
|                             |
|         TURNI.              |  ← brand.logo display (≥48dp)
|                             |
|  (respiro space.xl)         |
|                             |
|  [E-mail                ]   |  ← input.text, teclado emailAddress
|                             |
|  [Senha            👁   ]   |  ← input.password
|  Esqueci minha senha        |  ← link.text alinhado à direita
|                             |
|  [       Entrar         ]   |  ← button.primary, full-width
|                             |
|  [banner de erro / aviso ]  |  ← visível só em estado de erro (§A.5)
|                             |
+-----------------------------+
```

- Conteúdo em coluna única, padding lateral `space.lg` (24dp).
- Largura máxima do conteúdo: 400dp, centralizado.
- Fundo `surface.page` (claro `#F7F4EC` / escuro `#0F1411`).
- Nenhum card em mobile — a tela **é** o form.
- `brand.logo` no topo: `display` (≥48dp), Bebas Neue, sem `surface.card`.

#### Desktop (≥840dp)

```
+---------------------------------------------------+
|                                                   |
|            +-------------------------+            |
|            |                         |            |
|            |         TURNI.          |            |  ← brand.logo display
|            |                         |            |
|            | [E-mail             ]   |            |  ← surface.card elev.1 radius.lg
|            |                         |            |    largura máx 420dp, padding space.xl
|            | [Senha          👁  ]   |            |
|            |  Esqueci minha senha    |            |
|            |                         |            |
|            | [      Entrar       ]   |            |
|            |                         |            |
|            | [banner de erro]        |            |
|            +-------------------------+            |
|                                                   |
+---------------------------------------------------+
```

- `surface.card` (`elev.1`, `radius.lg`) engloba **apenas o form** (não o logo).
- Logo acima do card, separado por `space.lg`.
- Centrado vertical e horizontal na tela. Respiro vertical total ≥ `space.3xl`.

### A.4. Detalhes dos campos

| Campo | Config |
|---|---|
| E-mail | `keyboardType: EmailAddress`, `textInputAction: next`, `autocomplete: email`, `autofocus: true` |
| Senha | `obscureText: true`, `textInputAction: done`, `autocomplete: current-password` |
| Botão "Entrar" | `type: submit`, aciona `Form.validate()` + `POST /api/login` |

Validação inline (no blur, não só no submit):
- E-mail: obrigatório + formato básico (`@` e `.`). Erro: "E-mail inválido."
- Senha: obrigatório. Erro: "Informe a senha."

### A.5. Estados

#### A.5.1. Caminho feliz
Form com logo, dois campos, link de recuperação e botão. Microcopy em §A.6.

#### A.5.2. Loading (durante submissão)
- Botão "Entrar" → estado `loading`: label substituído por `CircularProgressIndicator` na cor `on-accent`; botão desabilitado.
- Campos e link desabilitados durante a requisição.
- Duração esperada ≤ 500ms; sem skeleton.

#### A.5.3. Erro — credencial inválida
Banner inline abaixo do botão (não modal, não toast). Anatomia do banner:

```
+---------------------------------------+
|  ● E-mail ou senha incorretos.        |  ← ícone error + texto text.strong
|    Verifique e tente novamente.       |  ← text.muted, body-sm
+---------------------------------------+
```

- Fundo `error-soft` (`#FBE2E2` claro / `rgba(216,90,90,.14)` escuro).
- Borda `error` 1dp, `radius.md`.
- Ícone `Icons.error_outline` na cor `error` — nunca só cor.
- Não revela se o e-mail existe ou não (sem leak — CA-3).
- Anunciado por leitor de tela via `Semantics(liveRegion: true)`.

#### A.5.4. Erro — usuário admin tentando entrar no WebApp
Banner diferente (informativo, não de erro):

```
+---------------------------------------+
|  ℹ  Este usuário acessa o Backoffice. |  ← ícone info + texto
|     → Ir para o Backoffice            |  ← link.text com URL do admin
+---------------------------------------+
```

- Fundo `info-soft`. Cor `info`.
- URL do admin: `admin.homolog.turni.com.br` (ou Cloud Run URL conforme IDR-003 — o Programador injeta via env).
- Aparece **somente após autenticação bem-sucedida** com `role=admin` — nunca antes (CA-7: sem leak para tentativas inválidas).

#### A.5.5. Conta em análise (`status: pendente_aprovacao`)
```
+---------------------------------------+
|  ● Sua conta está em análise.         |
|    Você receberá um aviso quando      |
|    for aprovada.                      |
+---------------------------------------+
```

- Fundo `warning-soft`. Ícone `Icons.hourglass_top_outlined` em `warning`.
- Sessão **não** é iniciada; o usuário fica na tela de login.

#### A.5.6. Conta recusada (`status: recusado`)
```
+---------------------------------------+
|  ● Cadastro não aprovado.             |
|    Entre em contato com o suporte.    |
+---------------------------------------+
```

- Fundo `error-soft`. Ícone `Icons.cancel_outlined` em `error`.
- Sessão não iniciada.

#### A.5.7. Throttle (429)
```
+---------------------------------------+
|  ● Muitas tentativas.                 |
|    Aguarde alguns minutos antes       |
|    de tentar novamente.               |
+---------------------------------------+
```

- Fundo `error-soft`. Botão "Entrar" desabilitado por 60s com contador regressivo no label: "Aguardar (45s)".

#### A.5.8. Erro de servidor (500+)
```
+---------------------------------------+
|  ● Não conseguimos entrar agora.      |
|    Tentar de novo                     |  ← link.text que re-submete
+---------------------------------------+
```

- Fundo `error-soft`.

#### A.5.9. Validação de campo em blur
Mensagem de erro aparece abaixo do campo com `errorText` do `TextFormField`. Exemplos:

| Campo | Condição | Texto do erro |
|---|---|---|
| E-mail | vazio | "Este campo é obrigatório." |
| E-mail | formato inválido | "E-mail inválido." |
| Senha | vazia | "Informe a senha." |

### A.6. Microcopy

| Lugar | Texto |
|---|---|
| Rótulo logo | `TURNI.` (leitor de tela anuncia "Turni") |
| Label campo e-mail | E-mail |
| Placeholder e-mail | seunome@email.com |
| Label campo senha | Senha |
| Link recuperação | Esqueci minha senha |
| CTA primário | Entrar |
| CTA loading | `[spinner]` |
| Erro credencial (linha 1) | E-mail ou senha incorretos. |
| Erro credencial (linha 2) | Verifique e tente novamente. |
| Admin no WebApp (linha 1) | Este usuário acessa o Backoffice. |
| Admin no WebApp (link) | Ir para o Backoffice |
| Conta em análise (linha 1) | Sua conta está em análise. |
| Conta em análise (linha 2) | Você receberá um aviso quando for aprovada. |
| Conta recusada (linha 1) | Cadastro não aprovado. |
| Conta recusada (linha 2) | Entre em contato com o suporte. |
| Throttle (linha 1) | Muitas tentativas. |
| Throttle (linha 2) | Aguarde alguns minutos antes de tentar novamente. |
| Servidor indisponível (linha 1) | Não conseguimos entrar agora. |
| Servidor indisponível (link) | Tentar de novo |
| Erro campo obrigatório | Este campo é obrigatório. |
| Erro e-mail inválido | E-mail inválido. |
| Erro senha vazia | Informe a senha. |
| Show password tooltip | Mostrar senha |
| Hide password tooltip | Ocultar senha |

### A.7. Acessibilidade

- **Ordem de foco / leitura:** logo → campo e-mail → campo senha → link recuperação → botão Entrar → banner de erro (se presente). Ordem DOM = ordem visual.
- **Foco inicial:** logo (`<h1>` ou `Semantics(header: true)`) — não roubar foco para o campo imediatamente (usuário com leitor de tela precisa ouvir a marca e o contexto).
- **Logo:** `Semantics(label: 'Turni')` — não ler "T-U-R-N-I".
- **Campos:** `labelText` é rótulo semântico. `hintText` é suplementar. `errorText` usa `liveRegion: true`.
- **Banner de erro:** `Semantics(liveRegion: true)` — anunciado ao aparecer sem precisar de foco.
- **Botão loading:** `Semantics(label: 'Entrando…', enabled: false)` durante o loading.
- **Toggle show/hide:** `Semantics(button: true, label: 'Mostrar senha' / 'Ocultar senha')`.
- **Teclado:** Tab percorre e-mail → senha → link recuperação → botão. Enter no campo senha aciona o submit.
- **Contraste (claro):**
  - `text.strong` `#0F1B2D` / `surface.page` `#F7F4EC` = 15.7:1 ✅
  - `text.muted` `#42504A` / `surface.page` = 7.7:1 ✅
  - Botão: `on-accent` `#FFF` / `accent` `#2D5F3F` = 7.4:1 ✅
  - Link: `accent.ink` `#2D5F3F` / `surface` `#FFF` = 7.4:1 ✅
  - Erro: `error` `#B83A3A` / `surface` `#FFF` (ícone/UI) ≥ 3:1 ✅ (`#FFF`/`#B83A3A` = 5.7:1)
- **Contraste (escuro):**
  - `text.strong` `#ECEDE5` / `surface.page` `#0F1411` = 15.8:1 ✅
  - `text.muted` `#A8B2A8` / `surface.page` = 8.5:1 ✅
  - Botão: `on-accent` `#0F1411` / `accent` `#5FA37C` = 6.1:1 ✅
  - Link: `accent` `#5FA37C` / `surface` `#1A2018` = 5.6:1 ✅
- **`prefers-reduced-motion`:** sem animações de entrada ou transição obrigatórias. Transição de tema usa `motion.fast` (100ms) apenas se motion habilitado.

### A.8. Identificadores para teste (E2E — CA-13)

| Elemento | Identificador lógico |
|---|---|
| Raiz da tela | `screen-login-webapp` |
| Campo e-mail | `input-email` |
| Campo senha | `input-password` |
| Toggle show/hide senha | `btn-toggle-password` |
| Link recuperação | `link-forgot-password` |
| Botão Entrar | `btn-submit-login` |
| Banner de erro (genérico) | `banner-error` |
| Banner admin→WebApp | `banner-admin-redirect` |
| Banner conta em análise | `banner-pending` |
| Banner conta recusada | `banner-rejected` |
| Banner throttle | `banner-throttle` |

---

## Tela B — Login Backoffice

### B.1. Objetivo

Admin da equipe Turni autentica no Backoffice com guard `web` Laravel. Cookie de sessão é **distinto e não compartilhado** com o do WebApp (ADR-007 §b). `SESSION_LIFETIME` mais curto (sugestão: 120 min com expiração em inatividade). Todo login (sucesso e falha) grava `admin_audit_log` (CA-6, CA-8).

**Desktop-first (≥1024dp). Perfil `admin` (azul-navy).**

### B.2. Fluxo

**Entrada:** admin navega para `/login` do Backoffice.

**Ações:** e-mail + senha → "Entrar". Link "Esqueci minha senha" (Fortify).

**Saídas:**

| Resultado | Comportamento |
|---|---|
| Credencial válida, `role: admin` | Redireciona para `/` (dashboard do Backoffice). Grava `admin.login` no audit log. |
| Credencial inválida | Banner de erro genérico. Grava `admin.login_failed` no audit log. |
| Credencial válida, `role != admin` | 403 fail-secure. Banner genérico "Acesso não autorizado." Grava `admin.login_attempt_non_admin` no audit log. |
| Throttle (429) | Banner de throttle + botão desabilitado com contador. |

### B.3. Layout (desktop-first ≥1024dp)

```
+---------------------------------------------------+
|                                                   |
|       +-----------------------------+             |
|       |   TURNI.   Backoffice       |             |  ← logo + tag
|       |   ─────────────────────    |             |
|       |                             |             |
|       |  [E-mail                ]   |             |  ← surface.card, largura 420dp
|       |                             |             |    padding space.xl
|       |  [Senha                 ]   |             |    elev.2, radius.lg
|       |   Esqueci minha senha        |             |
|       |                             |             |
|       |  [       Entrar         ]   |             |
|       |                             |             |
|       |  [banner de erro]           |             |
|       +-----------------------------+             |
|                                                   |
+---------------------------------------------------+
```

- Fundo: `surface.page` (claro `#F7F4EC` / escuro `#0B1018` — o escuro do admin é ligeiramente diferente, puxado para o azul conforme `preview-backoffice.html`).
- Card central: `surface` (`#FFFFFF` claro / `#141B26` escuro), `elev.2`, `radius.lg`, largura 420dp, padding `space.xl`.
- **Sem sidebar** na tela de login — sidebar só aparece após autenticação.
- Logo: `brand.logo` size `lg` (24–28dp), inline com tag "Backoffice" em fonte mono `overline`, cor `text.subtle`. Separado do form por `border.subtle` (divisor horizontal, 1dp).
- Para responsivo (abaixo de 1024dp): aviso "Backoffice é desktop-first. Alargue a janela." — sem formulário funcional em mobile (alinhado com PDR-003 e `preview-backoffice.html`).

### B.4. Detalhes dos campos

Idênticos à Tela A (§A.4), exceto:
- Sem `autofocus` condicional — desktop pode ter autofocus no e-mail.
- `SESSION_LIFETIME` é configuração de servidor, não visual.

### B.5. Estados

Idênticos à Tela A com as diferenças:

| Estado | Diferença vs Tela A |
|---|---|
| Erro — credencial inválida | Mesmo banner. Audit log grava `admin.login_failed`. |
| Não-admin tentando entrar | Banner "Acesso não autorizado." (genérico — não revela que o papel é errado antes de auth; mas após auth o CA-8 especifica retorno 403). Audit log grava `admin.login_attempt_non_admin`. |
| Throttle | Mesmo padrão. |

### B.6. Microcopy

| Lugar | Texto |
|---|---|
| Logo | `TURNI.` |
| Tag do Backoffice | BACKOFFICE |
| Label e-mail | E-mail |
| Placeholder e-mail | admin@turni.com.br |
| Label senha | Senha |
| Link recuperação | Esqueci minha senha |
| CTA | Entrar |
| Erro genérico (linha 1) | E-mail ou senha incorretos. |
| Erro genérico (linha 2) | Verifique e tente novamente. |
| Acesso não autorizado | Acesso não autorizado. |
| Throttle (linha 1) | Muitas tentativas. |
| Throttle (linha 2) | Aguarde alguns minutos antes de tentar novamente. |

### B.7. Acessibilidade

- **Ordem de foco:** logo → e-mail → senha → link recuperação → botão.
- **Contraste claro (admin):**
  - `text.strong` `#0F1B2D` / `surface` `#FFF` = 17.3:1 ✅
  - Botão: `on-accent` `#FFF` / `accent` `#2A4D8F` = 8.2:1 ✅
  - Link: `accent.ink` `#2A4D8F` / `surface` `#FFF` = 8.2:1 ✅
- **Contraste escuro (admin):**
  - `text.strong` `#ECEDE5` / `surface` `#141B26` = 14.1:1 ✅
  - Botão: `on-accent` `#0E1626` / `accent` `#5B8DEF` = 5.8:1 ✅
  - Link: `accent` `#5B8DEF` / `surface` `#141B26` = 5.2:1 ✅
- Teclado: Enter no campo senha aciona submit. Tab fluindo normalmente.

### B.8. Identificadores para teste (E2E — CA-13)

| Elemento | Identificador lógico |
|---|---|
| Raiz da tela | `screen-login-backoffice` |
| Campo e-mail | `input-email` |
| Campo senha | `input-password` |
| Botão Entrar | `btn-submit-login` |
| Banner de erro | `banner-error` |
| Banner não autorizado | `banner-unauthorized` |

---

## Tela C — Placeholder `/welcome` (WebApp)

### C.1. Objetivo

Rota destino do funnel guard para `status=liberado, welcome_seen_at=null`. Não é a tela real (STORY-022 entrega isso) — é um destino mínimo para que o guard tenha onde redirecionar e o E2E valide o redirecionamento. Deve existir como rota protegida (requer sessão); usuário `ativo` que acesse diretamente vê aviso leve, não bloqueio.

**Perfil `profissional` (verde). Tema do usuário (já logado).**

### C.2. Layout

```
+-----------------------------+
|                             |
|   (respiro space.2xl)       |
|                             |
|       TURNI.                |  ← brand.logo lg
|                             |
|   (respiro space.xl)        |
|                             |
|   A tela de boas-vindas     |
|   chega na STORY-022.       |  ← body, text.muted
|                             |
|   [    Sair    ]            |  ← button.primary (logout)
|                             |
|   [ banner "já ativo" ]     |  ← visível só se status=ativo (§C.3)
|                             |
+-----------------------------+
```

- Coluna única centralizada, padding `space.lg`, max-width 400dp.
- Nenhum card.
- Botão "Sair" chama `POST /api/logout` (invalida sessão no servidor — CA-4).

### C.3. Estado especial — `status=ativo` acessando diretamente

Banner informativo leve (não bloqueio):

```
+---------------------------------------+
|  ℹ  Você já completou o cadastro.     |
|     Continue para o aplicativo.  →    |  ← link para / do app
+---------------------------------------+
```

### C.4. Microcopy

| Lugar | Texto |
|---|---|
| Logo | `TURNI.` |
| Corpo | A tela de boas-vindas chega em breve. |
| Botão | Sair |
| Banner já ativo (linha 1) | Você já completou o cadastro. |
| Banner já ativo (link) | Continuar |

### C.5. Identificadores para teste

| Elemento | Identificador lógico |
|---|---|
| Raiz da tela | `screen-placeholder-welcome` |
| Botão Sair | `btn-logout` |
| Banner já ativo | `banner-already-active` |

---

## Tela D — Placeholder `/completar-cadastro` (WebApp)

### D.1. Objetivo

Rota destino do funnel guard para `status=liberado, welcome_seen_at!=null, cadastro_completed_at=null`. Mesmo padrão da Tela C — destino mínimo; tela real vem em STORY-023/024.

### D.2. Layout

Idêntico à Tela C, com texto diferente e sem o banner "já ativo" (quem está aqui ainda não é `ativo`).

```
+-----------------------------+
|         TURNI.              |
|                             |
|   A tela para completar     |
|   seu cadastro chega        |
|   em breve.                 |
|                             |
|   [    Sair    ]            |
|                             |
+-----------------------------+
```

### D.3. Microcopy

| Lugar | Texto |
|---|---|
| Logo | `TURNI.` |
| Corpo | A tela para completar seu cadastro chega em breve. |
| Botão | Sair |

### D.4. Identificadores para teste

| Elemento | Identificador lógico |
|---|---|
| Raiz da tela | `screen-placeholder-completar-cadastro` |
| Botão Sair | `btn-logout` |

---

## Tela E — Stub recuperação de senha (WebApp)

### E.1. Objetivo

Destino do link "Esqueci minha senha" da Tela A. Rota `/esqueci-minha-senha`. Conforme CA-5 da STORY-016: stub funcional que chama o endpoint Fortify de reset. A tela real com e-mail transacional vem em STORY-021.

### E.2. Layout

```
+-----------------------------+
|  ← Voltar para login        |  ← link.text para /login
|                             |
|       TURNI.                |
|                             |
|  Informe seu e-mail e       |
|  enviaremos um link para    |
|  redefinir sua senha.       |  ← body, text.muted
|                             |
|  [E-mail                ]   |  ← input.text
|                             |
|  [  Enviar link         ]   |  ← button.primary
|                             |
|  [banner sucesso/erro]      |
+-----------------------------+
```

### E.3. Estados

**Sucesso** (Fortify envia o e-mail): não revelar se e-mail existe. Sempre mostrar:

```
+---------------------------------------+
|  ✓ Se este e-mail estiver cadastrado, |
|    você receberá um link em instantes.|
+---------------------------------------+
```

Fundo `success-soft`. Botão "Enviar link" desabilitado após envio para evitar reenvio acidental.

**Erro de servidor:** banner "Não conseguimos enviar agora. Tentar de novo."

### E.4. Microcopy

| Lugar | Texto |
|---|---|
| Link voltar | Voltar para login |
| Logo | `TURNI.` |
| Instrução | Informe seu e-mail e enviaremos um link para redefinir sua senha. |
| Label e-mail | E-mail |
| CTA | Enviar link |
| Sucesso (linha 1) | Se este e-mail estiver cadastrado, |
| Sucesso (linha 2) | você receberá um link em instantes. |
| Erro servidor | Não conseguimos enviar agora. Tentar de novo. |

### E.5. Identificadores para teste

| Elemento | Identificador lógico |
|---|---|
| Raiz | `screen-forgot-password` |
| Campo e-mail | `input-email` |
| Botão Enviar | `btn-submit-forgot` |
| Banner sucesso | `banner-forgot-success` |

---

## Exceções ao Design System

| O que diverge | Por quê | Vira DDR? |
|---|---|---|
| `input.text` definido neste spec | Primeiro uso — componente estava no roadmap de `components.md` (EPIC-001+). Definição mínima e normativa aqui para o Programador ter o suficiente para implementar. | Sim — o IDR da STORY-016 deve registrar a materialização; DDR atualizará `components.md` na próxima sessão do Designer. |
| `input.password` variante de `input.text` | Extensão direta com toggle show/hide. Não é componente novo, é comportamento de `input.text`. | Entra junto no IDR. |
| Tela de login Backoffice sem sidebar | Login pré-autenticação; sidebar só existe pós-login. Padrão natural — não conflita com `preview-backoffice.html` (que mostra o estado pós-login). | Não. |

---

## Dependências e premissas

- **`preview-backoffice.html`** — referência visual do chrome do Backoffice pós-login. A tela de login do Backoffice usa a mesma paleta (admin azul-navy) mas sem sidebar.
- **ADR-007** — Sanctum SPA cookie para WebApp; guard web para Backoffice; cookies distintos; SESSION_LIFETIME 120 min no admin.
- **ADR-009** — schema `users` com `role`, `status`, `welcome_seen_at`, `cadastro_completed_at`. Lógica do funnel guard definida lá.
- **DDR-001** — tokens, esquema profissional como pré-login neutro, dual theme.
- **Tema escuro (DDR-001):** este spec define ambos os temas. O MVP liga apenas o claro. Quando o Programador implementar, o toggle de tema pode ser condicional por feature flag até o PO confirmar que o dark entra no MVP.
- **URL do admin em homolog:** a URL do Cloud Run (sem DNS customizado — IDR-003) deve ser injetada via variável de ambiente no WebApp para o link "Ir para o Backoffice" na Tela A, estado A.5.4.
- **Sincronismo Designer↔Programador (≤15 min):** pontos a alinhar antes da primeira linha de UI:
  1. Confirmação do tema base/neutral para login WebApp (profissional/verde) — aprovado neste spec.
  2. URL do admin para o link de redirecionamento — Programador injeta via env.
  3. Tratamento de `status=pendente_aprovacao` e `status=recusado` no login WebApp — coberto em A.5.5 e A.5.6.
  4. Stub recuperação de senha = chamar endpoint Fortify diretamente, sem tela customizada — coberto na Tela E.

---

## Histórico de mudanças

| Data | Mudança | Quem | Motivo |
|---|---|---|---|
| 2026-05-28 | Criação em `ready` | designer | Spec completo para STORY-016: 5 vistas (Login WebApp, Login Backoffice, placeholders welcome/completar-cadastro, stub recuperação de senha). Primeira materialização de `input.text` e `input.password` do roadmap DDR-001. |
