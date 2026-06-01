---
id: SCREEN-STORY-023-completar-cadastro-profissional
story: STORY-023-completar-cadastro-profissional-com-aceite
epic: EPIC-001-cadastro-e-aprovacao
status: ready
created_at: 2026-06-01
updated_at: 2026-06-01
owner_designer: claude-opus-4-8
related_ddrs: [DDR-001, PDR-013]
related_idrs: [IDR-022]
ds_components_used: [brand.logo, button.primary, button.outline, link.text, field.text, field.section, chip.filter, checkbox, banner, contract.view, progress.steps]
exceptions_to_ds: [contract.view (renderizador markdown leve) é novo componente local em ds/components — texto jurídico do servidor; sem dependência externa]
viewports: [mobile, desktop]
---

# Spec de tela — SCREEN-STORY-023 — Completar cadastro de Profissional + aceite

> Referência: estória `STORY-023`. CAs e contexto vêm de lá — **não duplico**.
> Fundação visual: `DDR-001` + `docs/project-state/design/system/`.
> Princípios que guiaram: **#1** simplicidade (formulário → revisar → aceitar), **#2** mobile-first,
> **#3** tom profissional + confiança (coleta de dado sensível e ato jurídico), **#5** WCAG AA,
> **#7** todos os estados (loading, erro de campo, erro genérico/throttle/servidor, sucesso).

Tela que **fecha o funil** do profissional: coleta os dados pós-aprovação (documento, Pix,
documentos comprobatórios, atuação) e, no clique explícito de consentimento, gera o
`AceiteEletronico` imutável e transiciona o usuário para `ativo`. É a primeira coleta de **dado
sensível** e o **momento legal de consentimento** do MVP — o design tem de transmitir segurança
("fica criptografado", "leia o contrato por inteiro") sem fricção desnecessária.

---

## Tema e perfil

- Usuário **autenticado** → tema do **papel** (DDR-001): profissional = acento **verde**
  (`accentLight #2D5F3F` / `accentDark #5FA37C`). Marca `TURNI.` (`brand.green #00A868`) é
  comum; só o acento muda por papel.
- **Tema dual** (PDR-013): tokens claro/escuro; `contract.view` usa `textStrong*`/`surface*`
  por brilho do tema. Contrastes herdam tokens já auditados AA.

## Decisão de estrutura — fluxo em 2 fases (liberdade técnica da estória)

A estória recomenda multi-step; a decisão implementada é um **formulário único seccionado**
(fase 1) seguido de uma **fase de revisão + consentimento** (fase 2). Razão: o aceite precisa
de **todos** os dados juntos e o preview do contrato é o gesto que separa "preencher" de
"consentir" — duas fases mapeiam isso 1:1 sem o overhead de um wizard de N passos. Uma barra de
progresso `progress.steps` (1/2 → 2/2) dá orientação. Chave de tela: `completar-cadastro:screen`.

```
┌───────────────────────────────────────────────┐
│  Complete seu cadastro            ▰▰▱  1/2      │   Fase 1 — formulário
│  Falta pouco… Esses dados ficam protegidos.    │
│                                                 │
│  SEU DOCUMENTO (CPF)                            │   rótulo/máscara por tipo_pessoa
│   [ 000.000.000-00 ]  Usado no contrato. Cripto.│   (contexto: PF→CPF, MEI/PJ→CNPJ)
│  SUA ATUAÇÃO                                    │
│   Funções secundárias (opcional) [chips]        │
│   [ Raio km ]  [ Preço/hora R$ ]  [ Bio ]       │
│  RECEBIMENTO                                    │
│   [ Chave Pix ]  Você recebe por aqui. Cripto.  │
│  DOCUMENTO COMPROBATÓRIO                         │
│   ⬆ Anexar documento (JPG/PNG/PDF ≤10MB)        │
│                                                 │
│        [  Revisar contrato  ]                   │
└───────────────────────────────────────────────┘
┌───────────────────────────────────────────────┐
│  Revise e aceite o contrato       ▰▰▰  2/2      │   Fase 2 — revisão + consentimento
│  ┌───────────────────────────────────────────┐ │
│  │ # Contrato … (Seção 1 + Assinatura)        │ │  completar-cadastro:contrato (scroll, maxH 420)
│  │ Nome: **Maria Silva**  CPF: 111.444.777-35 │ │  dados do usuário renderizados (CA-7)
│  │ … — preenchido no momento do aceite —      │ │  carimbos pendentes (IDR-022)
│  └───────────────────────────────────────────┘ │
│  ☐ Li, entendi e aceito os termos do contrato.  │  completar-cadastro:aceite
│        [  Aceito e concluir cadastro  ]         │  habilita só com ☑ + preview (CA-8)
│        Voltar e editar os dados                 │
└───────────────────────────────────────────────┘
```

## Campos (fase 1)

| Campo | Componente | Validação client | Observação |
|---|---|---|---|
| Documento (CPF/CNPJ) | `field.text` (`completar-cadastro:documento`) | obrigatório; nº de dígitos por tipo | rótulo/hint conforme `documento_tipo` do contexto; dígitos verificadores no servidor |
| Funções secundárias | seletor buscável (`completar-cadastro:funcoes-add` abre modal com busca + checklist; selecionadas viram chips removíveis `completar-cadastro:funcao-chip-{id}`) | — (opcional) | exclui a função primária; multi-seleção; escala p/ catálogo grande sem quebrar layout |
| Raio máx. (km) | `field.text` (`completar-cadastro:raio`) | inteiro 1–500 | |
| Preço/hora (R$) | `field.text` (`completar-cadastro:preco`) | numérico ≥1 | aceita vírgula |
| Bio | `field.text` (`completar-cadastro:bio`) | ≤500 chars | opcional |
| Chave Pix | `field.text` (`completar-cadastro:pix`) | obrigatório | formato validado no servidor |
| Documentos | `button.outline` (`completar-cadastro:anexar`) + lista | ≥1; ext JPG/PNG/PDF; ≤10 MB | `file_picker`; lista em `completar-cadastro:documentos-lista` |

Botão `completar-cadastro:revisar` valida o formulário e busca o preview (POST `/completar/preview`).

## Fase 2 — revisão + consentimento

- `completar-cadastro:contrato`: contrato renderizado pelo servidor (Seção 1 + Assinatura; Seção 2 de turno
  e notas internas omitidas — IDR-022) via `contract.view` (markdown leve, texto **selecionável**).
- `completar-cadastro:aceite`: consentimento explícito do **contrato** (distinto do aceite de Termos/Política
  do pré-cadastro).
- `completar-cadastro:concluir` ("Aceito e concluir cadastro"): **desabilitado** até o checkbox marcado (o preview
  já foi exibido por construção — só se chega à fase 2 após o preview). POST `/completar` →
  201 gera o aceite e transiciona para `ativo`.
- `completar-cadastro:voltar`: retorna à fase 1 preservando os dados.

## Estados

- **Loading:** spinner no botão ativo (`completar-cadastro:revisar` / `completar-cadastro:concluir`).
- **Erro de campo:** `field.text` mostra `errorText` (client e 422 por campo do servidor).
- **Erro de documento duplicado / genérico / throttle / servidor:** `banner` (com retry).
- **Erro de validação no aceite:** volta à fase 1 e revalida os campos.
- **Sucesso:** vista `completar-cadastro:sucesso` ("Cadastro concluído!" + ícone) → `completar-cadastro:continuar` leva à
  home (`/`); a sessão vira `active` e o funnel guard libera (CA-12).

## Acessibilidade (WCAG 2.1 AA)

- Cabeçalhos com `Semantics(header: true)`; barra de progresso com `Semantics(label: 'Passo X de 2')`.
- Campos com label + helper; foco e `errorMaxLines` herdados de `field.text`.
- Contraste AA pelos tokens; contrato em texto selecionável com escala/spacing legíveis.
- Botão de aceite com estado desabilitado perceptível; toda ação alcançável por teclado.

## Sync Designer↔Programador

Projeto solo (Alexandro em todos os papéis). Spec recriada **após** o revert da implementação
anterior, refletindo fielmente a UI construída nesta estória (fase 1 + fase 2). Sem componente de
DS novo além de `contract.view` (local, sem dependência). Promovida a `ready` em 2026-06-01.
