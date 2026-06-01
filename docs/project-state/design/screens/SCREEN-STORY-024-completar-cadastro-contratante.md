---
id: SCREEN-STORY-024-completar-cadastro-contratante
story: STORY-024-completar-cadastro-contratante-com-aceite
epic: EPIC-001-cadastro-e-aprovacao
status: ready
created_at: 2026-06-01
updated_at: 2026-06-01
owner_designer: claude-opus-4-8
related_ddrs: [DDR-001, PDR-013]
related_idrs: [IDR-022, IDR-023]
ds_components_used: [brand.logo, button.primary, button.outline, link.text, field.text, field.textarea, field.section, dropdown.select, checkbox, banner, contract.view, progress.steps, repeater.row]
exceptions_to_ds: [contract.view (renderizador markdown leve) reusado da SCREEN-023; repeater.row (lista dinâmica de contatos adicionais) é padrão composto local — Wrap de field.text + button.outline "Adicionar"/"Remover", sem dependência externa]
viewports: [mobile, desktop]
---

# Spec de tela — SCREEN-STORY-024 — Completar cadastro de Contratante + aceite

> Referência: estória `STORY-024`. CAs e contexto vêm de lá — **não duplico**.
> **Espelha** `SCREEN-STORY-023-completar-cadastro-profissional` (mesma família: completar cadastro
> com preview de contrato + aceite imutável). Onde o comportamento é **idêntico**, este spec
> **referencia a 023** em vez de repetir. As diferenças do contratante estão marcadas com **⚑**.
> Fundação visual: `DDR-001` + `docs/project-state/design/system/`.
> Princípios que guiaram: **#1** simplicidade (passos curtos → revisar → aceitar), **#2** mobile-first,
> **#3** tom profissional + confiança (coleta de CNPJ/endereço e ato jurídico), **#5** WCAG AA,
> **#7** todos os estados (loading, erro de campo, erro genérico/throttle/servidor, sucesso).

Tela que **fecha o funil** do contratante: coleta os dados de pós-aprovação do estabelecimento
(CNPJ, endereço completo, perfil operacional, cultura, contatos, logo) e, no clique explícito de
consentimento, gera o `AceiteEletronico` imutável referenciando `termos_plataforma_contratante`
(IDR-023) e transiciona o usuário para `ativo` com plano `Member Start`. É a primeira coleta de
**CNPJ + endereço** e o **momento legal de consentimento comercial** (taxa Turni 15% — PDR-004) — o
design transmite seriedade ("CNPJ fica criptografado", "leia os termos por inteiro") sem fricção.

---

## ⚑ Tema e perfil

- Usuário **autenticado** → tema do **papel** (DDR-001): contratante = acento **mostarda**.
  - **Claro:** CTA/botão `accent` `#9A6E25` (`on-accent` branco = 4.5:1 ✅); texto-link, ícones de
    acento, seleção ativa, anel de foco usam `accent.ink` `#6E4E12` (7.6:1 ✅). **Nunca** texto branco
    sobre o mostarda vibrante `#B8842F` (reprova AA) — esse fica para chrome/realce grande.
  - **Escuro:** `accent` `#D4A95C` (`on-accent` `#0F1411` = 8.3:1 ✅) serve a botão e a texto-link.
- Marca `TURNI.` (`brand.green #00A868`) conduz no topo — a marca é única; só o **acento** muda por
  papel.
- **Tema dual** (PDR-013): tokens claro/escuro; `contract.view` usa `textStrong*`/`surface*` por
  brilho do tema. Contrastes herdam tokens já auditados AA (tokens.md §6).

## ⚑ Decisão de estrutura — wizard de 3 passos + fase de revisão/aceite

A SCREEN-023 (profissional, ~7 campos) coube num **form único seccionado**. O contratante tem o
**dobro de campos** (CNPJ, 6 campos de endereço, apelido, segmento, ano, faixa de funcionários,
turnos, cultura, redes/site, lista dinâmica de contatos, logo). Form único viraria uma parede de
rolagem que sufoca a persona não-técnica (princípio #1). Por isso, e seguindo a recomendação
explícita da estória, a coleta é um **wizard de 3 passos** (`Stepper` — horizontal em web,
vertical/compacto em mobile), seguido de uma **fase de revisão + consentimento** idêntica à 023.

A barra de progresso `progress.steps` orienta (1/3 → 2/3 → 3/3 → Revisão). Cada passo valida só os
**próprios** campos ao avançar (erro cedo, perto do campo). "Voltar" preserva tudo (rascunho em
memória entre passos). Chave de tela: `completar-cadastro:screen` (mesma rota `/completar-cadastro`;
o router decide a tela pelo papel — coordenado com a 023).

```
┌───────────────────────────────────────────────┐
│  Complete o cadastro do seu negócio  ▰▱▱ 1/3   │  Passo 1 — Identidade do Estabelecimento
│  Esses dados ficam protegidos.                 │
│                                                 │
│  CNPJ                                           │
│   [ 00.000.000/0000-00 ]  Criptografado.        │  máscara CNPJ; dígitos verificados no servidor
│  ENDEREÇO                                       │
│   [ CEP ]  🔄 buscar     [ UF ]                 │  CEP autocompleta logradouro/bairro/cidade/UF
│   [ Logradouro ............ ] [ Nº ]            │
│   [ Bairro ] [ Cidade ] [ Complemento (opc.) ] │
│  IDENTIFICAÇÃO                                  │
│   [ Apelido do estabelecimento (opcional) ]     │
│                                  [ Continuar ]  │
└───────────────────────────────────────────────┘
┌───────────────────────────────────────────────┐
│  Como seu negócio opera             ▰▰▱ 2/3    │  Passo 2 — Operação
│   [ Segmento ]            [ Ano de fundação ]   │
│   [ Funcionários ▾ 1–10 | 11–50 | 51–200 | 200+]│  dropdown.select (faixa)
│   [ Turnos de operação típicos (opcional) ]     │
│                       [ Voltar ]  [ Continuar ] │
└───────────────────────────────────────────────┘
┌───────────────────────────────────────────────┐
│  Cultura e contatos                 ▰▰▰ 3/3    │  Passo 3 — Cultura & Contatos
│   [ Cultura e valores-chave (textarea, opc.) ]  │
│   [ Site (opcional) ] [ Instagram (opcional) ]  │
│   CONTATOS ADICIONAIS (opcional)                │  repeater.row — ≥0 linhas
│   ┌ [Nome] [Função] [Telefone]      [ Remover ]│
│   └ [ + Adicionar contato ]                     │
│   LOGO (opcional)  ⬆ Anexar (JPG/PNG ≤5MB)      │
│                  [ Voltar ]  [ Revisar termos ] │
└───────────────────────────────────────────────┘
┌───────────────────────────────────────────────┐
│  Revise e aceite os termos          ✔ Revisão  │  Fase de revisão + consentimento (= 023 fase 2)
│  ┌───────────────────────────────────────────┐ │
│  │ # Termos de Adesão à Plataforma — Contratante│ contract.view (scroll, maxH 420, selecionável)
│  │ Estabelecimento: **Bar do Zé**             │ │  dados do contratante renderizados (CA-7)
│  │ CNPJ: 11.222.333/0001-81 · Taxa Turni: 15% │ │  taxa Turni como cláusula permanente (IDR-023)
│  │ … — preenchido no momento do aceite —      │ │  carimbos pendentes (IDR-022 b)
│  └───────────────────────────────────────────┘ │
│  ☐ Li, entendi e aceito os Termos de Adesão.    │  completar-cadastro:aceite
│        [  Aceito e concluir cadastro  ]         │  habilita só com ☑ + preview exibido (CA-8)
│        Voltar e editar os dados                 │
└───────────────────────────────────────────────┘
```

## ⚑ Campos por passo

**Passo 1 — Identidade do Estabelecimento** (`completar-cadastro:step-identidade`)

| Campo | Componente (key) | Validação client | Observação |
|---|---|---|---|
| CNPJ | `field.text` (`completar-cadastro:cnpj`) | obrigatório; máscara `00.000.000/0000-00`; 14 dígitos | dígitos verificadores no servidor (CA-3); único no sistema; hint "Criptografado." |
| CEP | `field.text` (`completar-cadastro:cep`) | obrigatório; 8 dígitos `00000-000` | dispara busca ao completar (CA-4) |
| Buscar CEP | `button.outline` (`completar-cadastro:cep-buscar`) | — | preenche logradouro/bairro/cidade/UF; **falha não bloqueia** (entrada manual) |
| Logradouro | `field.text` (`completar-cadastro:logradouro`) | obrigatório | autopreenchível pelo CEP |
| Número | `field.text` (`completar-cadastro:numero`) | obrigatório | sempre manual (CEP não traz) |
| Bairro | `field.text` (`completar-cadastro:bairro`) | obrigatório | autopreenchível |
| Cidade | `field.text` (`completar-cadastro:cidade`) | obrigatório | autopreenchível |
| UF | `dropdown.select` (`completar-cadastro:uf`) | obrigatório; 27 UFs | autopreenchível |
| Complemento | `field.text` (`completar-cadastro:complemento`) | — (opcional) | |
| Apelido | `field.text` (`completar-cadastro:apelido`) | ≤60 chars (opcional) | usado em UI compacta |

**Passo 2 — Operação** (`completar-cadastro:step-operacao`)

| Campo | Componente (key) | Validação client | Observação |
|---|---|---|---|
| Segmento | `field.text` (`completar-cadastro:segmento`) | obrigatório; ≤120 | texto livre (ex.: "Restaurante italiano") |
| Ano de fundação | `field.text` (`completar-cadastro:ano-fundacao`) | obrigatório; inteiro 1900–ano atual | |
| Funcionários | `dropdown.select` (`completar-cadastro:qtd-funcionarios`) | obrigatório | faixa: `1-10`/`11-50`/`51-200`/`200+` |
| Turnos de operação | `field.textarea` (`completar-cadastro:turnos`) | — (opcional) | texto livre (ex.: "Almoço e jantar") |

**Passo 3 — Cultura & Contatos** (`completar-cadastro:step-cultura`)

| Campo | Componente (key) | Validação client | Observação |
|---|---|---|---|
| Cultura e valores | `field.textarea` (`completar-cadastro:cultura`) | ≤1000 (opcional) | |
| Site | `field.text` (`completar-cadastro:site`) | URL válida (opcional) | |
| Instagram | `field.text` (`completar-cadastro:rede-instagram`) | URL/handle (opcional) | mapeado em `redes_sociais` |
| Contatos adicionais | `repeater.row` (`completar-cadastro:contato-{i}-nome|funcao|telefone`, `completar-cadastro:contato-add`, `completar-cadastro:contato-{i}-remover`) | ≥0 linhas; numa linha preenchida, nome+função obrigatórios | gerente/chef/sommelier etc. |
| Logo | `button.outline` (`completar-cadastro:logo-anexar`) + preview | opcional; JPG/PNG; ≤5 MB | MIME validado no servidor; signed URL (CA-5) |

Botão `completar-cadastro:revisar` (rótulo "Revisar termos") valida o passo 3 e busca o preview
(POST `/completar/preview`).

## Fase de revisão + consentimento (idêntica à SCREEN-023 §"Fase 2", ⚑ exceto o texto)

- `completar-cadastro:contrato`: termos renderizados pelo servidor via `contract.view` (markdown
  leve, **selecionável**). ⚑ Template é `termos_plataforma_contratante` (IDR-023), não `mei_pj_b2b`;
  corpo = preâmbulo + cláusulas gerais + assinatura (Seção de turno e notas internas omitidas pelo
  renderer — IDR-022 a). A **taxa Turni 15%** aparece como cláusula permanente.
- `completar-cadastro:aceite`: consentimento explícito dos **Termos de Adesão** (distinto do aceite de
  Termos/Política do pré-cadastro STORY-018).
- `completar-cadastro:concluir` ("Aceito e concluir cadastro"): **desabilitado** até o checkbox marcado
  (o preview já foi exibido por construção — só se chega aqui após o preview). POST `/completar` →
  201 gera o aceite, grava plano `Member Start` e transiciona para `ativo` (CA-12).
- `completar-cadastro:voltar`: retorna ao passo 3 preservando os dados.

## Estados

- **Loading:** spinner no botão ativo (`...:continuar`/`...:revisar`/`...:concluir`); CEP em busca
  mostra spinner inline em `completar-cadastro:cep-buscar`.
- **Erro de campo:** `field.text`/`dropdown.select` mostram `errorText` (client e 422 por campo).
- ⚑ **Erro/timeout da busca de CEP:** `banner` informativo não-bloqueante ("Não encontramos esse CEP
  agora — preencha o endereço manualmente.") + log de falha de integração no servidor (CA-4). O
  submit **não** é bloqueado.
- **Erro de CNPJ duplicado / genérico / throttle / servidor:** `banner` (com retry); CNPJ duplicado
  usa erro genérico sem leak ("Não foi possível usar este CNPJ.") — CA-3.
- **Erro de validação no aceite:** volta ao passo correspondente e revalida.
- **Sucesso:** vista `completar-cadastro:sucesso` ("Cadastro concluído! Em breve você poderá publicar
  vagas." — CA item 7) → `completar-cadastro:continuar-home` leva ao placeholder interno; a sessão
  vira `active` e o funnel guard libera (CA-12).

## Paridade mobile / desktop

- **Mobile (≥360px):** `Stepper` vertical compacto (passo atual expandido, demais colapsados); campos
  em coluna única; `repeater.row` de contatos empilha nome/função/telefone; CTA primário fixo no rodapé.
- **Desktop (≥1024px):** `Stepper` horizontal no topo; endereço em grade (logradouro largo + número
  estreito; bairro/cidade/UF na mesma linha); `repeater.row` em linha; largura de conteúdo limitada
  (~720px) para não esticar campos de texto.

## Acessibilidade (WCAG 2.1 AA)

- Cabeçalho de cada passo com `Semantics(header: true)`; `progress.steps` com
  `Semantics(label: 'Passo X de 3')`.
- Campos com label + helper; `errorText` associado ao campo (não só borda). Foco visível com anel
  `accent.ink` do contratante.
- `dropdown.select` (UF, faixa de funcionários) navegável por teclado; opções com rótulo legível.
- `repeater.row`: botões "Adicionar"/"Remover" com `Semantics(label:)` ("Adicionar contato",
  "Remover contato N"); alvo ≥48dp.
- Contraste AA pelos tokens do contratante (tokens.md §6.1/§6.2); contrato em texto selecionável.
- Botão de aceite com estado desabilitado perceptível (não só cor); toda ação alcançável por teclado.

## Sync Designer↔Programador

Projeto solo (Alexandro em todos os papéis). Spec espelha a SCREEN-023 (mesma família) com as
diferenças do contratante marcadas **⚑**. Reuso de DS: `contract.view` (já materializado na 023) e o
padrão composto `repeater.row` (Wrap de `field.text` + `button.outline`, sem dependência externa) —
sem componente de DS realmente novo. Ajuste de template (`termos_plataforma_contratante`) decidido em
IDR-023 com o PO. Promovida a `ready` em 2026-06-01, na mesma régua da 023 (spec fiel, sem diretório
de protótipo HTML separado neste fluxo solo).
