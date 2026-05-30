---
id: SCREEN-STORY-022-welcome
story: STORY-022-welcome-pos-aprovacao-webapp
epic: EPIC-001-cadastro-e-aprovacao
status: ready
created_at: 2026-05-29
updated_at: 2026-05-29
owner_designer: claude-opus-4-8
related_ddrs: [DDR-001]
ds_components_used: [brand.logo, button.primary, link.text, banner]
exceptions_to_ds: [tema por papel aplicado em tela de conteúdo (não-chrome) pela 1ª vez pós-login — usa accent profissional (verde) ou contratante (mostarda) conforme tokens.dart; sem componente novo]
viewports: [mobile, desktop]
---

# Spec de tela — SCREEN-STORY-022 — Welcome pós-aprovação

> Referência: estória `STORY-022-welcome-pos-aprovacao-webapp`. CAs e contexto vêm de lá — **não duplico**.
> Fundação visual: `DDR-001` + `docs/project-state/design/system/` (tokens, voice-and-tone).
> Princípios que guiaram: **#1** simplicidade (uma tela, uma decisão: "Vamos lá"), **#2** mobile-first, **#3** tom profissional (primeira impressão dentro do produto), **#5** acessibilidade WCAG AA, **#7** todos os estados (padrão, loading, erro, já-ativo).

Esta é a **primeira tela que o usuário recém-aprovado vê** — primeira impressão "dentro do produto". O job: afirmar tom (autonomia + suporte), reduzir a fricção mental do completar cadastro listando o que será pedido, e mover o usuário adiante com **uma** ação primária. É também a primeira mudança de estado **autodirigida** pelo usuário (`welcome_seen_at` passa a `now()`).

---

## Decisão de tema e perfil (vale para todas as vistas)

- **Perfil:** o usuário **já está autenticado** — o tema segue o **papel da sessão** (DDR-001, esquema de cor por perfil):
  - **Profissional** → acento **verde** (`accentLight #2D5F3F` / `accentDark #5FA37C`).
  - **Contratante** → acento **mostarda** (`contratanteAccentLight #9A6E25` CTA / `contratanteAccentInkLight #6E4E12` texto-link / `contratanteAccentDark #D4A95C`).
- A **marca** (`brand.green #00A868`, logo `TURNI.`) é única e conduz no topo, igual em todas as telas — só o **acento** muda por papel.
- **Tema claro/escuro** (PDR-013): tokens definidos para os dois; MVP liga só o claro. Contrastes em §6.

## Decisão de estrutura (local desta tela)

**Coluna única, centrada, sem card no mobile; card no desktop** — espelha o padrão já materializado em `/info` (`WelcomeScreen` informativa) e no login. Razão: conteúdo curto, leitura linear (saudação → o que vem → o que será pedido → ação). Não há formulário, não há dado a carregar da API na entrada — então **sem skeleton**; a tela pinta pronta com dados que já vêm da sessão.

---

## Fluxo

**Entrada:**
- Funnel guard (STORY-016) roteia para `/welcome` quando `status=liberado` e `welcome_seen_at=null`. Também via redirect pós-login (`login_screen.dart` → `FunnelState.awaitWelcome`).
- Acesso direto a `/welcome`:
  - **`status=ativo`** → tela mostra **mensagem informativa** "já está com cadastro completo" + link para home (não o welcome real). **CA-6.**
  - **`pendente_aprovacao` / `recusado` / não-autenticado** → o guard redireciona a `/login` antes de renderizar. **CA-7.**

**Ações possíveis:**
- **CTA primário "Vamos lá"** → marca `welcome_seen_at` (chama `POST /api/usuarios/me/welcome-visto`), atualiza a sessão local e navega a `/completar-cadastro`. **CA-4.**
- **Link secundário "Fazer depois"** → **logout limpo**, volta a `/login`, **sem** marcar `welcome_seen_at` (no próximo login o usuário vê o welcome de novo). **Não** é atalho para `/completar-cadastro` — força consciência do checkpoint. **CA-5.**

**Saídas por resultado de `POST /api/usuarios/me/welcome-visto`:**
- **200** → sessão atualizada (`welcome_visto=true`), navega a `/completar-cadastro`.
- **erro de rede / 5xx** → banner recuperável "Não conseguimos seguir agora. Tentar de novo." (estado §5.3); o usuário permanece em `/welcome` e pode tentar de novo. `welcome_seen_at` **não** muda.
- **idempotência (já marcado)** → 200 no-op; mesmo caminho do happy path (o usuário nunca vê erro por isso). **CA-8.**

---

## Layout

### Mobile (≥360dp)

```
+------------------------------------+
|                                    |
|         TURNI.                     |  ← brand.logo (verde — marca única)
|                                    |
|  Bem-vindo(a), Diego!              |  ← headline (display, text.strong)
|                                    |
|  Tudo certo, seu cadastro foi      |  ← body (text.strong/muted)
|  aprovado. Falta só completar      |
|  seu perfil — leva uns 5 minutos.  |
|                                    |
|  Vamos pedir:                      |  ← label de seção (text.muted)
|   •  Seu documento (CPF ou CNPJ)   |  ← bullets adaptados ao papel
|   •  Sua chave Pix para receber    |     (lista §4)
|   •  Uma foto de comprovante       |
|                                    |
|  [          Vamos lá          ]    |  ← button.primary (accent do papel) full-width
|                                    |
|         Fazer depois               |  ← link.text discreto (centro, text.muted)
|                                    |
|  [ banner de erro ]                |  ← só em estado de erro (§5.3)
+------------------------------------+
```

- Coluna única, `padding: space.lg`, `maxWidth: 480dp`, fundo `surface.page`, sem card.
- Logo `TURNI.` no topo (display 48, `brand.green`), `semanticsLabel: 'Turni'`.
- Headline em display/`headlineMedium` (≈28–32, w600, `text.strong`). Saudação com nome do usuário (placeholder `{nome}` — vem da sessão; fallback sem nome em §4).
- Parágrafo body (16, `text.muted`/`text.strong`).
- "Vamos pedir:" como `label`/overline curto em `text.muted`; bullets em body com marcador `•` no acento do papel (ícone decorativo, `excludeSemantics`).
- CTA full-width, pílula (`StadiumBorder`), altura 52, ≥48dp.
- "Fazer depois" como `TextButton` centralizado, `text.muted` (discreto, mas alvo ≥48dp).

### Desktop (≥840dp)

Idêntico em conteúdo; o miolo entra num `surface.card` (`elev.1`, `radius.lg`, `maxWidth: 480dp`), centrado vertical e horizontalmente — mesmo tratamento do login/`/info` desktop. Logo + headline + bullets + CTA + link dentro do card. Sem 2 colunas (conteúdo curto, não justifica).

### Tablet (600–840dp)

Herda o mobile (coluna única, sem card) em container `maxWidth: 480dp`.

---

## 4. Conteúdo por papel (bullets do que será pedido)

Os bullets antecipam o que a STORY-023/024 vai coletar no completar cadastro (fonte: `domain/usuario.md` §"Atributos por papel" → "Adicionados no completar cadastro"). 3 bullets, em linguagem do usuário (não jargão):

| Papel | Headline | Bullets ("Vamos pedir:") |
|---|---|---|
| **profissional** | Bem-vindo(a), {nome}! | • Seu documento (CPF ou CNPJ) · • Sua chave Pix para receber · • Uma foto de comprovante |
| **contratante** | Bem-vindo(a), {nome}! | • O CNPJ do estabelecimento · • O endereço completo · • Um pouco da cultura do lugar |

- **`{nome}`**: primeiro nome do usuário (da sessão). Fallback quando vazio: headline sem vírgula → "Boas-vindas!" (raro; o seed/cadastro sempre tem nome).
- **Acento por papel** aplicado só no marcador do bullet e no CTA — texto do bullet é `text.strong`/`muted` neutro.

---

## 5. Estados

### 5.1. Padrão — welcome real (CA-1, CA-2, CA-3)
`status=liberado, welcome_seen_at=null`. Tela cheia conforme layout, headline com nome, bullets do papel, CTA "Vamos lá", link "Fazer depois". Acento = papel. Pinta pronta (sem loading de entrada).

### 5.2. Loading no CTA (CA-4)
Ao tocar "Vamos lá": botão entra em estado loading (spinner, `onPressed=null`, texto oculto) enquanto a chamada à API está em voo. Link "Fazer depois" desabilitado durante a chamada (evita corrida logout × marcar). Feedback ≤100ms (estado pressed → loading).

### 5.3. Erro ao marcar (rede/5xx)
Falha na chamada → banner recuperável abaixo do CTA: ícone `error_outline` em `error`, **"Não conseguimos seguir agora. Tentar de novo."** Botão volta ao estado normal (o próprio CTA é o "tentar de novo"). `welcome_seen_at` permanece `null`. Banner é `liveRegion`.

### 5.4. Já ativo (acesso direto por `status=ativo`) — CA-6
Quando o usuário `ativo` chega em `/welcome` (digitou a URL): **não** mostra o welcome real. Mostra bloco informativo (banner `info`): **"Você já está com o cadastro completo."** + link **"Ir para a home"** → `/`. Sem CTA "Vamos lá", sem "Fazer depois".

### 5.5. Não-autenticado / pendente / recusado — CA-7
Coberto pelo funnel guard (STORY-016) **antes** de renderizar: redireciona a `/login`. Esta tela não precisa tratar — o teste E2E/widget confirma o redirect.

> **Sem estado vazio** (não há lista de dados) e **sem offline dedicado** além do banner de erro recuperável de §5.3.

---

## 6. Acessibilidade (CA-9)

- **Hierarquia semântica:** logo `Semantics(header:true, label:'Turni')`; headline como cabeçalho (`Semantics(header:true)`); bullets como lista legível (texto real, marcador `•` decorativo com `excludeSemantics`/`ExcludeSemantics`).
- **Ordem de foco/leitura:** logo → headline → parágrafo → "Vamos pedir" + bullets → CTA "Vamos lá" → "Fazer depois" → banner (quando houver). Ordem DOM = ordem visual.
- **Alvos de toque:** CTA 52dp; "Fazer depois" com padding garantindo ≥48dp; link "Ir para a home" (estado já-ativo) ≥48dp.
- **Foco visível:** mantém o indicador do Material (não remover).
- **Banner de erro / info:** `Semantics(liveRegion:true)` para o leitor anunciar.
- **Contraste (claro):**
  - `text.strong #0F1B2D` / `surface.page #F7F4EC` = 15.7:1 ✅ · / `surface #FFF` = 17.3:1 ✅
  - `text.muted #42504A` / `surface.page` = 7.7:1 ✅
  - **Profissional:** CTA `on-accent #FFF` / `accent #2D5F3F` = 7.4:1 ✅; link/marcador `accent` / `surface` = 7.4:1 ✅
  - **Contratante:** CTA `on-accent #FFF` / `accent #9A6E25` = 4.5:1 ✅; texto-link/marcador `accent.ink #6E4E12` / `surface` = 7.6:1 ✅
  - Erro: `#FFF` / `error #B83A3A` = 5.7:1 ✅
- **Contraste (escuro):** `text.strong #ECEDE5`/`#0F1411` 15.8:1 ✅; `text.muted #A8B2A8`/`surface` 8.5:1 ✅; profissional `accent #5FA37C` 5.6:1 ✅; contratante `accent #D4A95C` (on `#0F1411`) 8.3:1 ✅.
- **`prefers-reduced-motion`:** transições ≤300ms; nenhuma animação essencial.

---

## 7. Microcopy (tabela única)

| Lugar | Texto |
|---|---|
| Logo | `TURNI.` |
| Headline (com nome) | Bem-vindo(a), {nome}! |
| Headline (fallback s/ nome) | Boas-vindas! |
| Parágrafo | Tudo certo, seu cadastro foi aprovado. Falta só completar seu perfil — leva uns 5 minutos. |
| Label da lista | Vamos pedir: |
| Bullets — profissional | Seu documento (CPF ou CNPJ) · Sua chave Pix para receber · Uma foto de comprovante |
| Bullets — contratante | O CNPJ do estabelecimento · O endereço completo · Um pouco da cultura do lugar |
| CTA primário | Vamos lá |
| Link secundário | Fazer depois |
| Erro ao marcar (linha) | Não conseguimos seguir agora. Tentar de novo. |
| Já-ativo (texto) | Você já está com o cadastro completo. |
| Já-ativo (link) | Ir para a home |

> Tom: saudação calorosa **sem** exclamação fabricada além do "Bem-vindo(a), {nome}!" (uma marca de boas-vindas legítima, não festiva). Sem emoji, sem gíria. "Vamos lá" = convite direto e respeitoso (voice-and-tone.md). "Fazer depois" é neutro, não punitivo.

---

## 8. Identificadores para teste (widget + E2E)

Nomes lógicos; o Programador aplica como `Key('...')`. Distintos do placeholder (`screen-placeholder-welcome`) e da tela informativa `/info` (`screen-welcome-webapp`).

| Elemento | Identificador lógico |
|---|---|
| Raiz da tela | `screen-welcome` |
| Logo | `welcome-brand` |
| Headline (saudação) | `welcome-headline` |
| Lista de bullets | `welcome-bullets` |
| CTA "Vamos lá" | `btn-vamos-la` |
| Link "Fazer depois" | `link-fazer-depois` |
| Banner de erro ao marcar | `banner-welcome-erro` |
| Bloco já-ativo (info) | `banner-already-active` |
| Link "Ir para a home" (já-ativo) | `link-home` |

---

## 9. Dependências e premissas (contrato de API)

- **Endpoint (a implementar pelo Programador):** `POST /api/usuarios/me/welcome-visto` — protegido por sessão (`auth:web` + `WebAppOnly`), **fora** do `FunnelGuard` (que retorna 423 para não-ativos; quem precisa marcar welcome está justamente em `await_welcome`). Marca `welcome_seen_at = now()` se ainda `null` (idempotente: no-op se já marcado). Resposta 200 com o novo estado (`{role, status, welcome_visto, cadastro_completo, name}`). Log estruturado `user.welcome_seen` (`user_id`, `role`, `timestamp`; **sem** PII clara — CA-12).
- **Nome do usuário na sessão:** o `POST /api/login` hoje **não** devolve `name`. Para a headline personalizada, o Programador adiciona `name` ao payload de login e à `UserSession` (Flutter). Decisão de implementação (CA permite).
- **Tema por papel:** tokens já existem em `tokens.dart` (profissional verde, contratante mostarda — STORY-018). Sem novo token.
- **Seed E2E (CA-11):** usuário `profissional, status=liberado, welcome_seen_at=null` em dev/homolog (Programador adiciona ao `AdminUserSeeder`).
- **Rota:** `/welcome` já existe no `router.dart` (placeholder). O Programador troca o builder pela `WelcomeScreen` real; o guard já permite acesso de `await_welcome`.

## 10. Exceções ao Design System

| O que diverge | Por quê | Vira DDR? |
|---|---|---|
| Tema por papel em tela de conteúdo pós-login (não só chrome) | DDR-001 já prevê esquema por perfil; primeira tela pós-login a aplicá-lo no corpo. Tokens sancionados. | Não (coberto por DDR-001). |
| Card no desktop engloba logo + conteúdo | Mesma justificativa do login/`/info`. | Não. |

## 11. Sincronismo Designer↔Programador (registrado)

1. **`name` no login + sessão:** confirmado — Programador adiciona `name` ao payload de `/api/login` e à `UserSession`/`_saveSession`. Headline usa o **primeiro nome**.
2. **Endpoint fora do FunnelGuard:** confirmado — `welcome-visto` precisa ser acessível por `await_welcome`; usa `auth:web` + `WebAppOnly`, sem `FunnelGuard`.
3. **Idempotência:** marcar 2× = 200 no-op (sem erro visível). UI nunca mostra erro por re-marcação.
4. **"Fazer depois" = logout sem marcar:** confirmado (não é skip para completar cadastro).
5. **Bullets por papel:** texto desta tabela (§4/§7) prevalece na UI.
6. **Seed E2E:** Programador cria `bemvindo.profissional@turni.local` (`liberado, welcome_visto=false`) no seed dev/homolog.

## 12. Histórico de mudanças

| Data | Mudança | Quem | Motivo |
|---|---|---|---|
| 2026-05-29 | Criação em `ready` | designer (claude-opus-4-8) | Spec da tela de welcome pós-aprovação: saudação personalizada, bullets do que será pedido por papel, CTA "Vamos lá" (marca `welcome_seen_at` → `/completar-cadastro`), link "Fazer depois" (logout sem marcar), estados padrão/loading/erro/já-ativo, tema por papel (verde/mostarda), a11y WCAG AA dual-theme. |
