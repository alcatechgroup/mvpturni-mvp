---
id: SCREEN-STORY-018-pre-cadastro-contratante
story: STORY-018-pre-cadastro-contratante-webapp
epic: EPIC-001-cadastro-e-aprovacao
status: ready
created_at: 2026-05-29
updated_at: 2026-05-29
owner_designer: claude-opus-designer
related_ddrs: [DDR-001]
ds_components_used: [brand.logo, button.primary, link.text, surface.card, input.text, input.password, input.select, input.checkbox, banner]
exceptions_to_ds: [input.photo — reusa o componente materializado em SCREEN-STORY-017; tema contratante (mostarda) aplicado pela primeira vez fora de chrome — usa accent #9A6E25 (botão) / accent.ink #6E4E12 (texto-link), conforme tokens.md §6]
viewports: [mobile, desktop]
mirrors: SCREEN-STORY-017-pre-cadastro-profissional
---

# Spec de tela — SCREEN-STORY-018 — Pré-cadastro de Contratante

> Referência: estória `STORY-018-pre-cadastro-contratante-webapp`. CAs e contexto vêm de lá — **não duplico**.
> **Espelha** `SCREEN-STORY-017-pre-cadastro-profissional` (form único seccionado, Vista A + Vista B). Onde o comportamento é **idêntico**, este spec **referencia a 017** em vez de repetir. As diferenças do contratante estão marcadas com **⚑**.
> Fundação visual: `DDR-001` + `docs/project-state/design/system/` (tokens, componentes, voice-and-tone).
> Princípios que guiaram: **#1** simplicidade (um form, uma tarefa — entrar na fila), **#2** mobile-first, **#3** tom profissional, **#4** idiomático ao Flutter, **#5** acessibilidade WCAG AA, **#7** todos os estados.

Este spec cobre **duas vistas**:

| Vista | Interface | Rota | Observação |
|---|---|---|---|
| **A** — Formulário de pré-cadastro | WebApp (Flutter) | `/cadastro/contratante` (**pública**, sem auth) | CA-1, CA-2, CA-6 |
| **B** — Recebido (sucesso pós-submit) | WebApp (Flutter) | estado interno da Vista A (sem rota própria) | CA-7 |

> **CA-8 (aguardando aprovação no login):** já satisfeito. O `banner-pending` do `/login` (SCREEN-016 §A.5.5) é **agnóstico de papel** e seu texto já traz o SLA de 24h (`"Seu cadastro está em análise. Em até 24h enviaremos uma notificação por e-mail."`, ajustado na STORY-017 §10). Contratante em `pendente_aprovacao` cai no **mesmo** caminho do funnel guard, com o **mesmo** banner. **Sem mudança de login nesta estória.**

---

## ⚑ Decisão de tema e perfil (vale para todas as vistas)

- **Perfil:** **`contratante` (mostarda)** — é pré-login, papel ainda não autenticado, mas o cadastro **é** do contratante (DDR-001 — esquema de cor por perfil). A marca (`brand.green` `#00A868`) conduz no topo (logo `TURNI.`), **igual ao profissional** — a marca é única; o **acento** é que muda por perfil.
- **Acento (regra de uso de token — tokens.md §6.1/§6.2):**
  - **Claro:** CTA/botão usa `accent` `#9A6E25` (`on-accent` branco = 4.5:1 ✅). Texto-link, ícones de acento, segmento/seleção ativa usam `accent.ink` `#6E4E12` (7.6:1 ✅). **Nunca** texto branco sobre o mostarda vibrante `#B8842F` (reprova AA) — esse fica para chrome/realce grande, que aqui **não** ocorre.
  - **Escuro:** `accent` `#D4A95C` (`on-accent` `#0F1411` = 8.3:1 ✅) serve tanto a botão quanto a texto-link.
- **Tema:** claro por padrão; escuro definido (DDR-001) para não retrabalhar. MVP liga só o claro. Contrastes nos dois temas em §A.7.

## Decisão de estrutura do formulário (local desta tela)

**Formulário único, rolável e seccionado** — **idêntico à 017** (§"Decisão de estrutura"). Razões iguais: pré-cadastro é evento único e curto; seções dão chunking sem fragmentar; `Form` + `TextFormField`/`DropdownButtonFormField` é o caminho idiomático do Flutter.

> **Regra de três (paridade):** 017 (profissional) e 018 (contratante) agora **repetem** o padrão "cadastro inicial = form único seccionado, nunca wizard". Isso fecha a regra de três da 017 §"Decisão de estrutura". **Recomendação ao próximo ciclo de design:** promover esse padrão a **DDR** ("cadastro inicial público = form único seccionado"). Registrado aqui como pendência de DDR; não-bloqueante para esta estória.

---

## Componentes reusados (sem novidade de DS nesta tela)

Tudo já materializado pela SCREEN-016/017. Esta tela **não cria componente novo**:

- `input.text`, `input.password` — anatomia da SCREEN-016.
- `input.select` — `DropdownButtonFormField` (anatomia da 017 §"input.select"). ⚑ **Diferença:** os itens **não** vêm da API — são uma **lista estática** de tipos de operação (ver §A.4). Não há `GET` equivalente ao `/api/funcoes`.
- `input.checkbox` — aceite dos Termos (idêntico à 017).
- `input.photo` — foto do responsável (idêntico à 017 §"input.photo"; mesma lib `image_picker`, IDR-009).
- `banner` — erro genérico / throttle / servidor (idêntico à 017 §A.5).
- ⚑ **Não há `segmented`** — contratante **não tem `tipo_pessoa`** (é sempre PJ; CNPJ só no completar cadastro — STORY-024). A seção "Tipo de cadastro" da 017 **não existe** aqui.

---

## Vista A — Formulário de pré-cadastro

### A.1. Objetivo

⚑ **Maria** (sócia de bar — persona da landing) preenche os dados mínimos do **responsável + do estabelecimento**, aceita os Termos e **envia o cadastro para a fila de aprovação**. Não loga — fica aguardando aprovação (SLA 24h). **Uma** tarefa: entrar na fila.

### A.2. Fluxo

**Entrada:**
- Link público da landing / divulgação → `app.homolog.turni.com.br/cadastro/contratante`.
- ⚑ Rota **pública**: adicionar `/cadastro/contratante` ao conjunto `publicRoutes` do `router.dart` (que já contém `/cadastro/profissional`). Sem funnel guard.

**Ações possíveis:** idênticas à 017 §A.2 (preencher + "Enviar cadastro"; selecionar/trocar foto; mostrar/ocultar senha; abrir Termos/Política; "Já tem conta? Entrar" → `/login`). ⚑ **Sem** alternância de tipo de pessoa.

**Saídas por resultado de `POST /api/cadastro/contratante`:** idênticas à 017 §A.2 (201 → Vista B; 422 com `errors` → erros de campo; 422 genérico `cadastro_nao_concluido` → banner sem enumeração; 429 → throttle; 5xx/rede → erro recuperável). Mensagem de sucesso ⚑ adaptada ao contratante (ver §B.3).

### A.3. Layout

#### Mobile (≥360dp)

```
+----------------------------------+
|  ← Já tem conta? Entrar           |  ← link.text topo-direita (accent.ink)
|                                   |
|         TURNI.                    |  ← brand.logo (verde — marca única)
|  Criar conta de estabelecimento   |  ← headline ⚑
|  Leva 2 minutos. A equipe Turni   |  ← body-sm, text.muted
|  revisa em até 24h.               |
|                                   |
|  ── Seus dados ──                 |  ← título de seção
|  [Nome do responsável        ]    |  ← input.text ⚑
|  [E-mail                     ]    |  ← input.text (emailAddress)
|  [Telefone                   ]    |  ← input.text (phone)
|                                   |
|  ── Seu estabelecimento ──        |  ⚑
|  [Nome do estabelecimento    ]    |  ← input.text ⚑
|  [Tipo de operação         ▾ ]    |  ← input.select (estático) ⚑
|  [Cidade                     ]    |  ← input.text
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
|  [       Enviar cadastro       ]  |  ← button.primary (accent mostarda) full-width
|                                   |
|  [ banner de erro/aviso ]         |  ← só em estado de erro (§A.5)
+----------------------------------+
```

- Estrutura/medidas **idênticas à 017 §A.3 mobile** (coluna única, padding `space.lg`, max 480dp, `surface.page`, sem card, títulos de seção `label`/`overline` em `text.muted`, CTA full-width pílula ≥48dp). **Só muda o acento (mostarda) e os campos.**

#### Desktop (≥840dp)

⚑ Idêntico à 017 §A.3 desktop (`surface.card`, `elev.1`, `radius.lg`, max-width **560dp**, logo+título dentro do card), com **um par em 2 colunas**:

- **Tipo de operação + Cidade** lado a lado (ambos curtos). Nome do responsável, E-mail, Telefone, Nome do estabelecimento permanecem largura plena. Senha + Confirmar senha em 2 colunas (igual 017).
- Colapso para 1 coluna abaixo de `bp.expanded` (840dp). `Wrap`/`Row` com `Expanded`.

#### Tablet (600–840dp)

Herda o mobile (coluna única) em container `maxWidth: 480dp`; sem 2 colunas; sem card até 840dp. **Idêntico à 017.**

### A.4. Detalhes dos campos ⚑

| Campo | Config Flutter | Validação client-side (espelha o back — §A.9) |
|---|---|---|
| Nome do responsável | `textCapitalization: words`, `next`, `autofocus` (só desktop) | obrigatório; 3–120 chars |
| E-mail | `keyboardType: emailAddress`, `autocorrect: false`, `next` | obrigatório; formato `@` + `.` |
| Telefone | `keyboardType: phone`, `next`; máscara BR sugerida (não obrigatória) | obrigatório; DDD + 8–9 dígitos |
| Nome do estabelecimento | `textCapitalization: words`, `next` | obrigatório; 2–200 chars |
| Tipo de operação | `input.select`, **lista estática** (abaixo) | obrigatório; valor da lista |
| Cidade | `textCapitalization: words`, `next` | obrigatório; ≤120 |
| Foto | `input.photo` | obrigatório; JPG/PNG; ≤5 MB |
| Senha | `input.password`, `next`, `autocomplete: new-password` | obrigatório; ≥10, maiúscula+minúscula+número |
| Confirmar senha | `input.password`, `done`, `onFieldSubmitted → submit` | obrigatório; **igual** à senha |
| Aceite dos Termos | `input.checkbox` | obrigatório; deve estar marcado |

**⚑ Lista estática de "Tipo de operação"** (valor enviado → rótulo exibido). Ordem por relevância de operação de hospitalidade:

| valor (`tipo_operacao`) | rótulo exibido |
|---|---|
| `restaurante` | Restaurante |
| `bar` | Bar |
| `hotel` | Hotel / Pousada |
| `evento` | Eventos |
| `catering` | Catering / Buffet |
| `outro` | Outro |

> **Por que estático e não tabela:** diferente de `funcoes` (IDR-008), o tipo de operação é um conjunto **pequeno, fechado e estável** definido em `domain/usuario.md`. Hard-coded como enum no back + lista no front evita um endpoint e uma tabela para 6 valores. O Programador registra a decisão em **IDR** (ver §A.12).

**Quando validar:** no **blur** (`autovalidateMode: onUserInteraction`) **e** no submit (`Form.validate()`). **Idêntico à 017 §A.4.**

### A.5. Estados

Todos **idênticos** à 017 §A.5 (caminho feliz, loading no submit, sucesso → Vista B, erro genérico CA-4 sem enumeração, throttle 429, erro servidor/rede 5xx, foto inválida CA-6, validação de campo no blur/submit). ⚑ **Diferenças:**

- **Não há** estado de erro do `segmented` (campo inexistente).
- **Acento dos elementos interativos** = mostarda (`accent.ink` claro / `accent` escuro), não verde.
- Os **banners de erro** continuam em `error` (vermelho) — feedback semântico **nunca** vira identidade de perfil (tokens.md §"sobreposição de hue").

#### A.5.9. Validação de campo (blur/submit) ⚑

| Campo | Condição | Texto do erro |
|---|---|---|
| Nome do responsável | vazio | Informe o nome do responsável. |
| Nome do responsável | < 3 | O nome deve ter ao menos 3 caracteres. |
| Nome do responsável | > 120 | O nome deve ter no máximo 120 caracteres. |
| E-mail | vazio | Informe seu e-mail. |
| E-mail | formato inválido | Informe um e-mail válido (ex.: nome@dominio.com). |
| Telefone | vazio | Informe seu telefone. |
| Telefone | formato inválido | Informe um telefone válido com DDD (ex.: (11) 91234-5678). |
| Nome do estabelecimento | vazio | Informe o nome do estabelecimento. |
| Nome do estabelecimento | < 2 | O nome do estabelecimento deve ter ao menos 2 caracteres. |
| Tipo de operação | não selecionado | Selecione o tipo de operação. |
| Cidade | vazia | Informe a cidade. |
| Foto | ausente | Adicione uma foto. |
| Senha | vazia / fraca | A senha deve ter ao menos 10 caracteres, com maiúscula, minúscula e número. |
| Confirmar senha | diferente | As senhas não conferem. |
| Termos | não marcado | É necessário aceitar os Termos de Uso e a Política de Privacidade. |

### A.6. Microcopy ⚑ (só o que difere da 017)

| Lugar | Texto |
|---|---|
| Link topo "já tenho conta" | Já tem conta? Entrar |
| Logo | `TURNI.` |
| Título da tela | Criar conta de estabelecimento |
| Subtítulo | Leva 2 minutos. A equipe Turni revisa em até 24h. |
| Seção 1 | Seus dados |
| Label nome | Nome do responsável |
| Placeholder nome | Ex.: Maria Souza |
| Label e-mail | E-mail |
| Placeholder e-mail | seunome@email.com |
| Label telefone | Telefone |
| Placeholder telefone | Ex.: (11) 91234-5678 |
| Hint telefone | Use o número com DDD que recebe WhatsApp. |
| Seção 2 | Seu estabelecimento |
| Label estabelecimento | Nome do estabelecimento |
| Placeholder estabelecimento | Ex.: Bar do Porto |
| Label tipo de operação | Tipo de operação |
| Placeholder/hint tipo | Escolha o que melhor descreve |
| Label cidade | Cidade |
| Seção 3 | Sua foto |
| Foto (vazio) | Adicionar foto |
| Hint foto | JPG ou PNG, até 5 MB. |
| Foto (selecionada) | Trocar foto |
| Seção 4 | Sua senha |
| Label senha | Senha |
| Hint senha | Use 10+ caracteres, com letras maiúsculas, minúsculas e números. |
| Label confirmar | Confirmar senha |
| Checkbox termos | Li e aceito os {Termos de Uso} e a {Política de Privacidade}. |
| CTA primário | Enviar cadastro |
| Erro genérico (linha 1) | Não foi possível concluir o cadastro. |
| Erro genérico (linha 2) | Verifique os dados e tente novamente. |
| Erro genérico (link) | Já tem conta? Entrar |
| Throttle / Erro servidor | iguais à 017 §A.6 |

> Mensagens batem com as `messages()` do `FormRequest` do back (§A.9). Quando divergirem, **o texto deste spec prevalece** na UI.

### A.7. Acessibilidade ⚑

- **Ordem de foco/leitura:** link "Entrar" → logo → título → nome do responsável → e-mail → telefone → nome do estabelecimento → tipo de operação → cidade → foto → senha → confirmar → termos → links dos termos → CTA → banner. Ordem DOM = ordem visual.
- Demais regras **idênticas à 017 §A.7** (foco inicial no logo, `input.checkbox` com `checked` anunciado e links focáveis, `input.photo` com label, erros associados ao campo via `liveRegion`, banners `liveRegion`, Tab + Enter no confirmar aciona submit, alvos ≥48dp).
- **⚑ Contraste (claro — perfil contratante, pares sancionados `tokens.md §6.1`):**
  - `text.strong` `#0F1B2D` / `surface.page` `#F7F4EC` = 15.7:1 ✅ · / `surface` `#FFF` = 17.3:1 ✅
  - `text.muted` `#42504A` / `surface.page` = 7.7:1 ✅
  - CTA: `on-accent` `#FFF` / `accent` `#9A6E25` = **4.5:1 ✅**
  - Link/seleção ativa: `accent.ink` `#6E4E12` / `surface` = **7.6:1 ✅**
  - Erro: `#FFF` / `error` `#B83A3A` = 5.7:1 ✅ (ícone/UI ≥3:1)
- **⚑ Contraste (escuro — `tokens.md §6.2`):** `text.strong` `#ECEDE5`/`#0F1411` 15.8:1 ✅; `text.muted` `#A8B2A8`/`surface` 7.6:1 ✅; CTA/link `on-accent` `#0F1411`/`accent` `#D4A95C` 8.3:1 ✅; `accent` `#D4A95C`/`surface` (texto) 7.6:1 ✅.
- **`prefers-reduced-motion`:** igual à 017.

### A.8. Identificadores para teste (E2E — CA-9 / widget tests — CA-11) ⚑

Nomes lógicos; o Programador aplica como `Key('...')`/`ValueKey('...')`. **Espelham a 017 com o slug `contratante`.**

| Elemento | Identificador lógico |
|---|---|
| Raiz da tela | `screen-cadastro-contratante` |
| Campo nome do responsável | `input-nome` |
| Campo e-mail | `input-email` |
| Campo telefone | `input-telefone` |
| Campo nome do estabelecimento | `input-estabelecimento` |
| Select tipo de operação | `input-tipo-operacao` |
| Campo cidade | `input-cidade` |
| Área de foto | `input-foto` |
| Botão trocar foto | `btn-trocar-foto` |
| Campo senha | `input-password` |
| Campo confirmar senha | `input-password-confirm` |
| Toggle mostrar/ocultar senha | `input-password-toggle` / `input-password-confirm-toggle` |
| Checkbox termos | `check-termos` |
| Link Termos de Uso | `link-termos` |
| Link Política | `link-privacidade` |
| CTA enviar | `btn-submit-cadastro` |
| Banner erro genérico | `banner-cadastro-erro` |
| Banner throttle | `banner-throttle` |
| Banner erro servidor | `banner-servidor` |
| Painel de sucesso (Vista B) | `panel-cadastro-recebido` |
| CTA voltar à home (Vista B) | `btn-voltar-home` |

> ⚑ **Sem** `segmented-tipo-pessoa`, `segment-*`, `input-funcao` (campos inexistentes no contratante). As keys de campos comuns (nome, e-mail, telefone, cidade, foto, senha, termos, banners, sucesso) são **as mesmas** da 017 — útil para os helpers de teste compartilhados.

---

## Vista B — Recebido (sucesso pós-submit) — CA-7 ⚑

**Idêntica à 017 §B em estrutura/acessibilidade** (logo `TURNI.`, ícone `check_circle_outline` em `success`, título, corpo, CTA "Voltar à home" → `/`, sem rota própria, sem confete). **Só muda:**

- **Acento do CTA** = mostarda (`accent` claro `#9A6E25` / escuro `#D4A95C`).
- **Microcopy adaptado ao contratante:**

| Lugar | Texto |
|---|---|
| Título | Cadastro recebido. |
| Corpo | Em até 24h a equipe Turni revisa seu cadastro e envia uma notificação por e-mail. |
| CTA | Voltar à home |

> O corpo reflete a `message` do back. Texto deste spec prevalece por tom (idêntico ao da 017 — coerência entre os dois cadastros).

---

## §A.9. Dependências e premissas (contrato de API)

- **Endpoint (a implementar pelo Programador nesta estória):** `POST /api/cadastro/contratante` (rota pública, no grupo stateful/CSRF do Sanctum — mesmo padrão da 017). Campos: `name, email, telefone, nome_estabelecimento, tipo_operacao (restaurante|bar|hotel|evento|catering|outro), cidade, foto (multipart, JPG/PNG ≤5MB), password, password_confirmation, termos_aceitos`. Respostas em §A.2. **Não** retorna sessão (sem auto-login). Cria `User(role=contratante, status=pendente_aprovacao)` + `ContratanteProfile`.
- **⚑ Sem endpoint de lista:** o `input.select` de tipo de operação usa a **lista estática** de §A.4 (não há `GET /api/tipos-operacao`).
- **CSRF:** submit público segue o padrão Sanctum (cookie `/sanctum/csrf-cookie` antes do POST) — mesmo helper da 017.
- **Páginas estáticas de Termos/Política:** placeholders no MVP (igual 017).
- **DDR-001:** tokens, **esquema contratante (mostarda) como pré-login**, dual theme.
- **SCREEN-016/017:** padrões de `input.text`/`input.password`/`input.select`/`input.checkbox`/`input.photo`/banner/sucesso reutilizados aqui — **recomenda-se reuso de componentes Flutter compartilhados** (a 017 §"Liberdade técnica" pede `lib/cadastro/shared/`; este spec dá keys e microcopy compatíveis para viabilizar).

## §A.10. Exceções ao Design System

| O que diverge | Por quê | Vira DDR? |
|---|---|---|
| Tema contratante (mostarda) fora de chrome — usado em CTA e links pré-login | Primeira tela de perfil contratante pré-login; DDR-001 já prevê o esquema por perfil. Regra de uso de token (botão `#9A6E25`, texto `#6E4E12`) aplicada conforme tokens.md §6. | Não (já coberto por DDR-001). |
| Tipo de operação como lista estática (não tabela como `funcoes`) | Conjunto pequeno/fechado/estável (6 valores) de `domain/usuario.md`. | Decisão de implementação → **IDR** do Programador (§A.12). |
| Card no desktop engloba logo + título | Mesma justificativa da 017. | Não. |
| Form único seccionado (não wizard) | Repete a 017 → fecha regra de três. Candidata a **DDR** no próximo ciclo. | Talvez (futuro — ver topo). |

## §A.11. Sincronismo Designer↔Programador (registrado)

Pontos alinhados para esta estória (sem bloqueio):

1. **Tipo de operação estático** (não endpoint): confirmado — lista de §A.4, valores hard-coded no back (enum/`Rule::in`) + IDR.
2. **Reuso de componentes:** Designer entrega keys/microcopy **compatíveis** com a 017 para o Programador extrair `lib/cadastro/shared/` (campos comuns, foto, termos, sucesso, banner). Decisão de extração e granularidade é do Programador (IDR se transversal).
3. **Tema contratante no `tokens.dart`:** hoje `tokens.dart` só tem o acento profissional (verde). O Programador adiciona os tokens de acento **contratante** (`#9A6E25` / `#6E4E12` / claro, `#D4A95C` / escuro) conforme tokens.md §6 — decisão de implementação; valores já sancionados pelo DS.
4. **Rota pública:** adicionar `/cadastro/contratante` ao `publicRoutes` do `router.dart`.
5. **Máscara de telefone:** opcional (igual 017).
6. **CA-8:** nenhuma mudança no login — o `banner-pending` já cobre contratante.

## §A.12. Pendências de DS / IDR a registrar

- **IDR (Programador):** `tipo_operacao` como enum estático vs tabela auxiliar (decisão: estático).
- **IDR (Programador), se a extração for transversal:** componentes compartilhados de cadastro em `lib/cadastro/shared/`.
- **DDR (próximo ciclo de Designer):** "cadastro inicial público = form único seccionado" (regra de três fechada por 017+018).

---

## §A.14. Vocabulário público: "estabelecimento" (não "contratante")

Decisão de microcopy (Designer): nas **telas públicas de entrada** (login + título do cadastro),
o termo voltado ao usuário é **"estabelecimento"**, não "contratante". Razão (princípio #3,
anti-jargão): a persona Maria se reconhece como "tenho um bar/estabelecimento", não como
"sou um contratante". **`contratante` continua sendo o termo de domínio/role** (glossário do
PO, `role=contratante` no banco, fila do admin, specs) — só a **superfície pública** usa
"estabelecimento". Aplicado em: headline da Vista A ("Criar conta de estabelecimento") e no
atalho do login (§A.15).

## §A.15. Emenda ao SCREEN-016 — duas portas de criar conta no login

O login (SCREEN-016) tinha um único atalho "Não tem conta? Cadastre-se" → `/cadastro/profissional`.
Com a STORY-018, passam a existir **duas** portas públicas. Mudança consciente:

```
        Não tem conta?
[Criar conta de profissional]  [Criar conta de estabelecimento]
```

- **Onde:** `apps/webapp/lib/features/auth/login_screen.dart` (seção de criar conta).
- **Comportamento:** `Wrap` centralizado (lado a lado no desktop, empilha no mobile estreito),
  dois `TextButton`, **cada um no acento do seu perfil** (DDR-001): profissional em **verde**
  (`accent` claro `#2D5F3F` / escuro `#5FA37C`) e estabelecimento em **mostarda**
  (`accent.ink` claro `#6E4E12` / `accent` escuro `#D4A95C`). Keys: `link-criar-conta`
  (profissional, preservada) e `link-criar-conta-contratante`.
- **Por quê acento por perfil:** as duas portas são uma **escolha de identidade** — usar a cor
  do perfil antecipa visualmente o tema da tela de destino e ajuda a diferenciar as opções. O
  texto/fundo do login segue neutro; só os dois links de criar conta carregam a cor do perfil.
  Contraste sobre `surface`: verde 7.4:1 ✅, mostarda ink 7.6:1 ✅ (ambos AA).
- **Impacto em teste:** widget test e E2E (`rbac-login.spec.ts`) ajustados para os dois links.

## §A.13. Histórico de mudanças

| Data | Mudança | Quem | Motivo |
|---|---|---|---|
| 2026-05-29 | Criação em `ready` | designer (claude-opus) | Spec de pré-cadastro de contratante: espelha a 017 (form único seccionado, Vista A + B), tema contratante (mostarda, tokens.md §6), campos do responsável + estabelecimento, `tipo_operacao` como lista estática, **sem** `tipo_pessoa`/`funcao`/`bairro`. CA-8 já coberto pelo `banner-pending` agnóstico de papel. |
| 2026-05-29 | Emenda: login com duas portas + vocábulo "estabelecimento" | designer (claude-opus) | §A.14 (microcopy pública "estabelecimento" vs role "contratante") e §A.15 (atalho do login passa a oferecer profissional **e** estabelecimento). Título da Vista A alinhado para "Criar conta de estabelecimento". |
