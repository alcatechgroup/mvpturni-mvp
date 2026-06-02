---
id: SCREEN-STORY-046-publicar-vaga
story: STORY-046-publicar-vaga-webapp-contratante
epic: EPIC-002-vaga-feed-e-candidatura
status: ready                # draft | ready | in_implementation | shipped | superseded
created_at: 2026-06-02
updated_at: 2026-06-02
owner_designer: claude-opus-4-8
related_ddrs: [DDR-001]
ds_components_used: [brand.logo, button.primary, button.outline, link.text, surface.card, field.text, field.textarea, field.section, dropdown.select, field.datetime, field.currency, field.stepper, banner]
exceptions_to_ds: [field.datetime (par data+hora via showDatePicker/showTimePicker do Material) e field.currency (TextFormField com máscara de moeda) e field.stepper (número de posições com − / +) são padrões compostos locais — descritos na seção 8; viram DDR se reaparecerem em STORY-052 (edição de vaga)]
viewports: [mobile, desktop]
prototype_path: SCREEN-STORY-046-publicar-vaga/index.html
prototype_last_validated_at: 2026-06-02  # aprovado por Alexandro em chat
---

# Spec de tela — SCREEN-STORY-046 — Publicar vaga (contratante)

> Referência: estória `STORY-046`. CAs e contexto vêm de lá — **não duplico**.
> Fundação visual: `DDR-001` + `docs/project-state/design/system/`.
> Modelo de dados / contrato: `ADR-013` (campos materiais da vaga, evento `vaga.criada`).
> Regra de bloqueio: `PDR-005` (avaliação recíproca obrigatória — gate de publicação).
> Domínio: `docs/especificacao/domain/vaga.md` (atributos, publicação, estados).
> Princípios que guiaram: **#1** simplicidade radical (um form curto, 6 campos, uma ação),
> **#2** mobile-first (contratante cobre falta pelo celular), **#3** tom profissional (gestor de
> operações, sem festa), **#5** WCAG AA, **#6** performance percebida (submit otimista com botão
> em loading), **#7** todos os estados (gate, loading, erro de campo, erro de servidor, sucesso,
> sem permissão).

Primeira tela de **escrita** do contratante autenticado. Ele publica uma oferta de turno
preenchendo 6 campos e clicando em **Publicar vaga**. Antes do formulário, um **gate** (PDR-005)
verifica se há turnos finalizados pendentes de avaliação — se houver, o formulário não aparece e o
contratante é levado a avaliar primeiro. Vaga publicada nasce `aberta` e passa a aparecer no feed
do profissional (STORY-048).

---

## Tema e perfil

- Usuário **autenticado** como **contratante** → tema do papel (DDR-001): acento **mostarda**.
  - **Claro:** CTA/botão `accent` `#9A6E25` (`on-accent` branco = 4.5:1 ✅); texto-link, ícones de
    acento, foco e seleção usam `accent.ink` `#6E4E12` (7.6:1 ✅). **Nunca** texto branco sobre o
    mostarda vibrante — esse fica só para chrome/realce grande.
  - **Escuro:** `accent` `#D4A95C` (`on-accent` `#0F1411` = 8.3:1 ✅) serve a botão e a texto-link.
- Marca `TURNI.` (`brand.green #00A868`) conduz no topo. A marca é única; só o **acento** muda
  por papel. **Tema dual** (PDR-013): tokens claro/escuro auditados AA (tokens.md §6).

---

## 1. Objetivo da tela

Permitir que o contratante **publique uma vaga** (oferta de um ou mais turnos idênticos) em um
formulário curto, com validação imediata, e veja a confirmação de que a vaga já começou a aparecer
para profissionais. Uma tela, uma tarefa, um botão primário.

---

## 2. Fluxo

### Entrada

- **Ponto de entrada (CA-1):** a partir da **home do contratante ativo** (`/`), pelo botão primário
  **"Publicar vaga"**. Hoje a home é um placeholder genérico (`AppShellScreen`); este spec define a
  home mínima do contratante = saudação curta + CTA primário "Publicar vaga". A rota do formulário é
  `/contratante/vagas/nova`.
  > **Nota de coexistência com STORY-047:** quando "Minhas vagas" (STORY-047) entrar, ela vira a
  > home real do contratante e hospeda o CTA "Publicar vaga" (FAB). Esta home mínima é o andaime
  > até lá — não construir lista de vagas aqui (fora de escopo).
- **Pré-condições:** sessão ativa (`status = ativo`), papel = `contratante`. O funnel guard
  (STORY-016) já garante sessão ativa em `/`.
- **RBAC (CA-1):** `profissional` autenticado que navegue direto para `/contratante/vagas/nova`
  **não** vê o formulário — vê o estado **Sem permissão** (§4.5) no front, e o backend responde
  **403** a qualquer chamada (`GET` do gate ou `POST /api/vagas`). RBAC herdado de STORY-016.
- **Gate PDR-005 (CA-5):** ao abrir `/contratante/vagas/nova`, antes de montar o formulário, a tela
  consulta `GET /api/avaliacoes/pendentes-do-contratante`. Enquanto carrega → §4.2 (loading).
  Se `pending > 0` → §4.8 (gate bloqueante) no lugar do formulário. Se `pending == 0` → formulário.

### Ações possíveis na tela

- **Ação primária:** **Publicar vaga** (submit). Habilitada só quando os 6 campos obrigatórios são
  válidos. Em loading durante o POST.
- **Ações secundárias:** **Voltar** (descarta o rascunho e volta para a home; se houver algo
  digitado, confirma o descarte — §4.x). No gate: **Avaliar turnos pendentes** (CTA que leva à tela
  de avaliação pendente — alvo definido pelo EPIC-003; por ora `/contratante/avaliacoes/pendentes`).
- **Saídas:** sucesso → "Minhas vagas" (STORY-047) ou, se ainda não existir, detalhe/placeholder da
  vaga `/contratante/vagas/{id}` (CA-7). Cancelar/Voltar → home `/`.

### Saída

- **Após sucesso (CA-7):** navega para `/contratante/vagas` (Minhas vagas, STORY-047) com **toast**
  de confirmação. Carry-over: se STORY-047 não estiver pronta, navega para
  `/contratante/vagas/{id}` (placeholder com `id` + `estado`), mantendo o mesmo toast.
- **Após cancelar:** volta para `/`. Se havia rascunho digitado, confirma o descarte primeiro.
- **Após erro recuperável:** permanece na tela; erro de campo fica junto ao campo (§4.4); erro de
  servidor/rede vira `banner` no topo do form com retry pelo próprio botão Publicar.

---

## 3. Layout

### Mobile (≥360px)

Formulário em coluna única, rolável, dentro de um `surface.card` sobre `surface.page`. CTA primário
**fixo no rodapé** (acima do teclado), para não exigir rolagem até o fim. AppBar com Voltar + título.

```
+------------------------------------------+
| ←  Publicar vaga                         |  AppBar (Voltar + título)
+------------------------------------------+
|                                          |
|  FUNÇÃO                                   |  field.section (label de seção)
|  [ Selecione a função ............ ▾ ]    |  dropdown.select (lista do Core FHP)
|                                          |
|  QUANDO                                   |
|  Início                                   |
|  [ 12/06/2026 ]   [ 18:00 ]              |  field.datetime (data | hora)
|  Fim                                      |
|  [ 12/06/2026 ]   [ 23:00 ]              |  field.datetime (data | hora)
|  ⓘ A vaga dura ~5h.                       |  hint derivado (valor_hora/duração)
|                                          |
|  PAGAMENTO E POSIÇÕES                      |
|  Valor por turno                          |
|  [ R$ 150,00 ]                            |  field.currency
|  Quantas pessoas?                         |
|  [ −  1  + ]                              |  field.stepper (min 1)
|                                          |
|  OBSERVAÇÕES (opcional)                    |
|  [ Dress code, instruções...        ]     |  field.textarea (multiline, opcional)
|  [                                  ]     |
|                                          |
+------------------------------------------+
| [        Publicar vaga        ]          |  button.primary fixo (full width)
+------------------------------------------+
```

- Componentes do DS: `surface.card`, `field.section`, `dropdown.select`, `field.datetime`,
  `field.currency`, `field.stepper`, `field.textarea`, `button.primary`, `banner`.
- Largura do card: 100% menos `TurniSpacing.md` de cada lado. Campos full width. Data e hora lado a
  lado (`Row` com `Expanded`) — colapsa para coluna < 360px se necessário.
- Alvos de toque ≥48dp: dropdown, pickers, stepper (− / +), CTA. CTA com altura ≥48dp.

### Desktop (≥1024px)

Form centralizado, largura máxima ~640px (não esticar — princípio #2). Sem nav lateral neste épico
(o menu do contratante é roadmap pós-047). CTA primário ao final do card, alinhado à direita, com
**Cancelar** (button.outline) à esquerda. As seções "Quando" e "Pagamento e posições" podem ocupar
duas colunas para usar o espaço sem inflar.

```
+--------------------------------------------------------------+
|                      TURNI.                                  |
|                  Publicar vaga                               |
|   +------------------------------------------------------+   |
|   |  FUNÇÃO                                               |   |
|   |  [ Selecione a função ........................... ▾ ] |   |
|   |                                                       |   |
|   |  QUANDO                                               |   |
|   |  Início                          Fim                  |   |
|   |  [ 12/06/2026 ] [ 18:00 ]        [ 12/06/2026 ][23:00]|   |
|   |  ⓘ A vaga dura ~5h.                                    |   |
|   |                                                       |   |
|   |  PAGAMENTO E POSIÇÕES                                  |   |
|   |  Valor por turno                 Quantas pessoas?     |   |
|   |  [ R$ 150,00 ]                   [ −  1  + ]          |   |
|   |                                                       |   |
|   |  OBSERVAÇÕES (opcional)                                |   |
|   |  [ Dress code, instruções...                       ]  |   |
|   +------------------------------------------------------+   |
|              [ Cancelar ]        [ Publicar vaga ]           |
+--------------------------------------------------------------+
```

- Diferença vs. mobile: campos pareados em 2 colunas, CTA não fixo (fica no fluxo), Cancelar
  explícito. Hover/focus visíveis (Flutter Web). Enter no último campo **não** submete sozinho
  (evita publicação acidental) — só o clique/Enter no botão Publicar com foco nele.

### Tablet (768px)

Herda o desktop (form centralizado ~640px). Sem comportamento próprio — omitido.

---

## 4. Estados

### 4.1. Caminho feliz (preenchido)

Os 6 campos válidos; botão **Publicar vaga** habilitado (acento sólido). Ao clicar → 4.2b (submit
loading) → sucesso (toast + navegação, CA-7). Microcopy completo na §5.

### 4.2. Loading

**(a) Gate carregando (primeiro fetch).** Enquanto `GET /api/avaliacoes/pendentes-do-contratante`
não responde, a área do formulário mostra **skeleton** dos campos (não spinner em tela vazia).

```
+------------------------------------------+
| ←  Publicar vaga                         |
+------------------------------------------+
|  ░░░░░░░░                                |
|  ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░          |
|  ░░░░░░░░     ░░░░░░░░                   |
|  ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░          |
+------------------------------------------+
```

**(b) Submit em andamento.** Após clicar Publicar: botão entra em estado **loading** (spinner inline
+ texto "Publicando…"), campos desabilitados, sem segundo clique (idempotência visual — CA da borda
de clique duplo no back).

### 4.3. Vazio

Não se aplica como "lista vazia" — esta é uma tela de criação. O estado inicial é o formulário em
branco com placeholders (caminho feliz a preencher). O equivalente a "vazio" é o **gate** (§4.8),
que substitui o formulário quando o contratante precisa avaliar antes.

### 4.4. Erro — validação de campo (client-side, tempo real — CA-2/CA-3)

Validação ao sair do campo (onBlur) e ao tentar submeter. Erro **associado ao campo** (`errorText`),
nunca global. O botão Publicar fica desabilitado enquanto houver campo inválido.

| Campo | Regra | Mensagem (errorText) |
|---|---|---|
| Função | obrigatória, da lista | "Escolha a função do turno." |
| Início (data/hora) | obrigatório | "Informe quando o turno começa." |
| Fim (data/hora) | obrigatório | "Informe quando o turno termina." |
| Fim > Início (CA-3) | `data_fim > data_inicio` | "O fim precisa ser depois do início." |
| Valor | obrigatório, > 0 | "Informe o valor por turno." |
| Posições | inteiro ≥ 1 | "Pelo menos 1 posição." |

> Validação **server-side espelhada** (FormRequest, CA-2): se algum erro escapar do client (ex.:
> relógio do cliente adiantado), o back devolve 422 com erros por campo e a tela reflete cada um no
> seu campo (mesma microcopy quando possível).

### 4.5. Sem permissão (CA-1 — profissional)

Profissional autenticado em `/contratante/vagas/nova` não vê o formulário. Tela curta + saída.

```
+------------------------------------------+
|              🔒                          |
|  Esta área é do contratante               |
|  Publicar vagas é uma ação de quem        |
|  contrata. Sua conta é de profissional.   |
|              [ Voltar ao início ]         |
+------------------------------------------+
```

> O backend responde **403** a `GET` do gate e a `POST /api/vagas` para papel ≠ contratante
> (RBAC STORY-016). O front também impede a navegação (guard de rota) e mostra esta tela.

### 4.6. Parcial / degradado

Se o `GET /funcoes` (lista de funções do dropdown) falhar mas o gate passar: o dropdown mostra
estado de erro com **"Não foi possível carregar as funções. Tentar de novo"** (retry local) e o
restante do form permanece desabilitado até as funções carregarem (função é obrigatória).

### 4.7. Erro — servidor / rede (no submit)

Falha do `POST /api/vagas` por rede ou 5xx → `banner` de erro no topo do form (não toast — o usuário
precisa reler e reagir), o rascunho é **preservado**, e o botão volta ao estado normal para retry.

```
+------------------------------------------+
| ⚠ Não foi possível publicar agora.       |
|   Verifique sua conexão e tente de novo.  |
+------------------------------------------+
|  (formulário preservado abaixo)          |
```

### 4.8. Gate PDR-005 (turnos pendentes de avaliação — CA-5)

Quando `GET /api/avaliacoes/pendentes-do-contratante` retorna `pending > 0`, o **formulário não
renderiza**. No lugar, um `banner`/card de aviso + CTA para avaliar. Não há "publicar mesmo assim".

```
+------------------------------------------+
| ←  Publicar vaga                         |
+------------------------------------------+
|              📋                          |
|  Avalie seus turnos pendentes             |
|  para publicar uma nova vaga              |
|                                          |
|  Você tem 2 turnos finalizados            |
|  aguardando sua avaliação. Avaliar        |
|  mantém o histórico de todos justo.       |
|                                          |
|  [   Avaliar turnos pendentes   ]         |  button.primary → tela de avaliação
+------------------------------------------+
```

- Contagem (`2`) vem de `pending` da resposta. Texto pluraliza ("1 turno finalizado" / "N turnos
  finalizados").
- O CTA leva à tela de avaliação pendente (EPIC-003; por ora rota `/contratante/avaliacoes/pendentes`
  — alvo confirmado quando aquela tela existir).

---

## 5. Microcopy completo

| Lugar | Texto |
|---|---|
| Home — CTA de entrada | Publicar vaga |
| Home — saudação | Olá! Pronto para cobrir um turno? |
| Título da tela | Publicar vaga |
| Seção 1 (label) | FUNÇÃO |
| Dropdown função (placeholder) | Selecione a função |
| Erro função (obrigatório) | Escolha a função do turno. |
| Seção 2 (label) | QUANDO |
| Label início | Início |
| Label fim | Fim |
| Placeholder data | dd/mm/aaaa |
| Placeholder hora | --:-- |
| Hint duração | A vaga dura ~{N}h. |
| Erro início (obrigatório) | Informe quando o turno começa. |
| Erro fim (obrigatório) | Informe quando o turno termina. |
| Erro fim ≤ início (CA-3) | O fim precisa ser depois do início. |
| Seção 3 (label) | PAGAMENTO E POSIÇÕES |
| Label valor | Valor por turno |
| Placeholder valor | R$ 0,00 |
| Hint valor | O quanto o profissional recebe por este turno. |
| Erro valor (obrigatório/zero) | Informe o valor por turno. |
| Label posições | Quantas pessoas? |
| Hint posições | Quantos profissionais você precisa para este turno. |
| Erro posições (< 1) | Pelo menos 1 posição. |
| Seção 4 (label) | OBSERVAÇÕES (opcional) |
| Placeholder observações | Dress code, instruções, ponto de encontro… |
| CTA primário | Publicar vaga |
| CTA primário (loading) | Publicando… |
| CTA secundário (desktop) | Cancelar |
| Confirmação de descarte (título) | Descartar esta vaga? |
| Confirmação de descarte (corpo) | Você ainda não publicou. As informações serão perdidas. |
| Confirmação de descarte (confirmar) | Descartar |
| Confirmação de descarte (cancelar) | Continuar editando |
| Toast de sucesso (CA-7) | Vaga publicada — começou a aparecer para profissionais. |
| Erro de servidor/rede (banner) | Não foi possível publicar agora. Verifique sua conexão e tente de novo. |
| Erro ao carregar funções (banner do dropdown) | Não foi possível carregar as funções. |
| Retry carregar funções | Tentar de novo |
| Sem permissão (título) | Esta área é do contratante |
| Sem permissão (corpo) | Publicar vagas é uma ação de quem contrata. Sua conta é de profissional. |
| Sem permissão (CTA) | Voltar ao início |
| Gate (título) | Avalie seus turnos pendentes para publicar uma nova vaga |
| Gate (corpo, plural) | Você tem {N} turnos finalizados aguardando sua avaliação. Avaliar mantém o histórico de todos justo. |
| Gate (corpo, singular) | Você tem 1 turno finalizado aguardando sua avaliação. Avaliar mantém o histórico de todos justo. |
| Gate (CTA) | Avaliar turnos pendentes |

Vocabulário: `docs/skills/po/references/glossary.md` (Vaga, Turno, Profissional, Contratante). Tom:
`references/tone-and-voice.md` — direto, profissional, sem "Ops!"/emoji no corpo (ícones só como
sinalização leve nos estados).

---

## 6. Acessibilidade (notas específicas)

- **Foco inicial** ao abrir o form: dropdown de Função (primeiro campo). No gate: o CTA "Avaliar".
- **Ordem de foco:** Função → Início (data → hora) → Fim (data → hora) → Valor → Posições (−, campo,
  +) → Observações → Publicar. (Cancelar antes de Publicar no desktop.)
- **Erros vinculados ao campo** via `TextFormField.validator`/`errorText` — anunciados por leitor de
  tela, não só borda vermelha (`errorLight`/`errorDark`).
- **Banner de erro de servidor e toast de sucesso** como `Semantics(liveRegion: true)` para
  anúncio assíncrono.
- **Stepper de posições:** botões − / + com `Semantics(label: 'Diminuir posições' / 'Aumentar
  posições')`; o número tem label "Número de posições: N".
- **Pickers de data/hora:** usar `showDatePicker`/`showTimePicker` do Material (acessíveis por
  padrão); o campo que abre o picker é um `InkWell`/`button` com label semântico (ex.: "Data de
  início").
- **Contraste:** todos os tokens usados são os auditados AA do tema contratante (tokens.md §6).
  CTA mostarda `#9A6E25` on-white branco = 4.5:1 ✅. Texto-link/ink `#6E4E12` = 7.6:1 ✅.
- **Alvos de toque ≥48dp:** dropdown, campos de data/hora, − / +, CTA. ✅

---

## 7. Identificadores estáveis sugeridos para teste

| Elemento | Identificador lógico sugerido |
|---|---|
| Home — CTA Publicar vaga | `contratante-home-publicar-vaga-btn` |
| Tela (raiz) | `publicar-vaga-screen` |
| Dropdown função | `publicar-vaga-funcao-dropdown` |
| Data início | `publicar-vaga-data-inicio` |
| Hora início | `publicar-vaga-hora-inicio` |
| Data fim | `publicar-vaga-data-fim` |
| Hora fim | `publicar-vaga-hora-fim` |
| Valor | `publicar-vaga-valor` |
| Posições (stepper) | `publicar-vaga-posicoes` |
| Observações | `publicar-vaga-observacoes` |
| CTA Publicar | `publicar-vaga-submit-btn` |
| CTA Cancelar (desktop) | `publicar-vaga-cancelar-btn` |
| Banner de erro servidor | `publicar-vaga-erro-banner` |
| Toast de sucesso | `publicar-vaga-sucesso-toast` |
| Gate (card) | `publicar-vaga-gate` |
| Gate — CTA avaliar | `publicar-vaga-gate-avaliar-btn` |
| Sem permissão (card) | `publicar-vaga-sem-permissao` |

> Nomes lógicos — o Programador aplica como `Key('...')`/`ValueKey('...')` para widget tests e o
> integration test (CA-9) ancorarem sem fragilidade.

---

## 8. Exceções ao Design System

| O que diverge | Por quê | Vira DDR? |
|---|---|---|
| `field.datetime` — par data+hora abrindo `showDatePicker`/`showTimePicker` do Material | DS ainda não tem campo de data/hora; é o primeiro form com data. Reusar widgets nativos do Material (acessíveis, localizáveis pt-BR) antes de inventar custom (princípio #4). | Sim, se STORY-052 (edição) reusar — então promove a `field.datetime` no DS. |
| `field.currency` — `TextFormField` com máscara R$ (centavos) | DS não tem campo monetário. Máscara local com formatação pt-BR (vírgula decimal). | Sim, se reaparecer (edição de vaga / repasses). |
| `field.stepper` — número de posições com − / + e campo central | Mais usável que digitar para "quantas pessoas" (1–N pequeno) na persona não-técnica; reduz erro de digitação. | Sim, se reaparecer. |

Nenhuma exceção viola token de cor/contraste — todas usam os tokens auditados do tema contratante.

---

## 9. Protótipo HTML fiel (validação humana)

- **Localização:** `SCREEN-STORY-046-publicar-vaga/index.html` (mesma pasta deste spec).
- **Cobertura:** seletor de viewport (mobile/desktop) + seletor de estado (`?state=` / chips):
  `form` (caminho feliz vazio), `preenchido`, `erro-campo` (fim ≤ início), `gate` (PDR-005),
  `sem-permissao`, `loading` (skeleton do gate), `submit` (botão publicando), `erro-servidor`,
  `sucesso` (toast + navegação simulada).
- **Fidelidade:** tokens reais do tema contratante (mostarda) claro; microcopy = §5 palavra por
  palavra; identificadores da §7 aplicados como `data-testid`.
- **Restrições:** HTML/CSS/JS vanilla, sem rede, abre clicando. Mock inline. Comentário no topo:
  "protótipo de validação, não código de produção".

### Checklist antes de marcar spec `ready`

- [ ] `SCREEN-STORY-046-publicar-vaga/index.html` abre sem erro.
- [ ] Todos os estados da §4 acessíveis pelo protótipo.
- [ ] Viewports mobile e desktop navegáveis.
- [ ] Microcopy bate palavra por palavra com a §5.
- [ ] Identificadores da §7 presentes no HTML.
- [ ] Caminho feliz percorrível (home → form → sucesso).
- [ ] Tokens reais do DS aplicados.
- [ ] Protótipo apresentado ao humano e sinal de validação capturado.

---

## 10. Dependências e premissas

- **Endpoints (contrato — não duplico; ADR-013 + estória CA-5/CA-6):**
  - `GET /api/funcoes` — lista canônica do Core FHP (já existe, STORY-017). Popula o dropdown.
  - `GET /api/avaliacoes/pendentes-do-contratante` → `{ pending: int, turnos: [...] }` — gate
    PDR-005. **Premissa de escopo:** turnos/avaliações são do EPIC-003 e ainda não existem; até lá o
    endpoint responde `pending: 0` (nenhum turno finalizado), e a UI do gate é exercitada via teste
    (front mocka `pending > 0`). **Questão para o PO/Programador** registrada nas Notas da estória.
  - `POST /api/vagas` — cria a vaga `aberta`, retorna `{ id, estado, ... }` (CA-6).
- **Permissões:** papel `contratante` + `status = ativo`. Profissional → 403 / estado §4.5.
- **Premissa de back:** o `estabelecimento_id`/localização (`lat/lng/cidade/uf`) é derivado do
  contratante autenticado no servidor (ADR-013) — o form **não** coleta endereço.
- **Sem DDR pendente** — spec opera dentro de DDR-001.

---

## 11. Histórico de mudanças

| Data | Mudança | Quem | Motivo |
|---|---|---|---|
| 2026-06-02 | criação (spec completo + protótipo v1) | claude-opus-4-8 (designer) | rabisco inicial não necessário — story bem especificada; spec + protótipo entregues juntos para validação humana |
| 2026-06-02 | validação humana — aprovado | Alexandro | protótipo/spec aprovados em chat; `status: ready`; gate PDR-005 confirmado como stub-honesto (pending:0 até EPIC-003) |
