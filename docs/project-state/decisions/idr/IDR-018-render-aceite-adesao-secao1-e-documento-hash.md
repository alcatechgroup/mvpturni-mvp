---
idr_id: IDR-018
slug: render-aceite-adesao-secao1-e-documento-hash
title: Motor de renderização do aceite de adesão (Seção 1) e hash determinístico do documento
status: accepted
decided_at: 2026-05-30
decided_by: programador
owner_agent: claude-opus-programador-designer-2026-05-30
related_story: STORY-023
related_adrs: [ADR-009, ADR-010]
related_idrs: [IDR-014]
supersedes: null
superseded_by: null
created_at: 2026-05-30
updated_at: 2026-05-30
---

# IDR-018 — Render do aceite de adesão (Seção 1) e hash determinístico do documento

## Contexto

STORY-023 gera o `AceiteEletronico` de **adesão** (EPIC-001, sem turno). ADR-010 (Decisão 3A) define o motor de renderização como substituição de placeholders por regex com **falha-dura** em placeholder ausente, e diz que "o motor omite a Seção 2 quando os placeholders de turno e contratante são nulos". Ao implementar, surgiram dois pontos não cobertos literalmente pelas ADRs:

1. **Como omitir a Seção 2 sem cair na falha-dura** e sem renderizar os blocos de **meta-autoria** (`## Histórico de validação`, `## Notas do PO`) que o texto-seed de STORY-015 carrega dentro do `conteudo` — esses blocos não fazem parte do documento jurídico apresentado ao usuário.
2. **Como enforçar a unicidade do documento (CA-3)** sobre um campo que fica **criptografado em repouso** (ADR-009 Decisão 5) — o ciphertext muda a cada IV, então `UNIQUE` direto é impossível.

## Decisão

> **Decidi (a) renderizar o aceite de adesão por seções de heading — mantendo apenas a "Seção 1 — Termos gerais" + "Assinatura eletrônica" e omitindo o resto; e (b) enforçar a unicidade do documento por uma coluna `documento_hash` = HMAC-SHA256(documento normalizado, APP_KEY) com índice UNIQUE.**

O `AceiteRenderer.renderAdesao()` fatia o `conteudo` pelos headings `## `, mantém o preâmbulo (título) e só as seções cujo título começa por `Seção 1` ou `Assinatura eletrônica`, depois aplica a substituição com falha-dura. Como a Seção 2 é removida antes da substituição, os placeholders de turno/contratante nunca disparam falha-dura — coerente com ADR-010. O EPIC-003 reutiliza `substituir()` com o documento completo.

O `documento_hash` é a estratégia já prevista em ADR-009 §"Sinais de revisão" ("hash determinístico para lookup"). Pepper = `APP_KEY` (secret estável por ambiente). O hash permite o `UNIQUE` e o pré-check anti-enumeração sem nunca expor o documento em claro.

## Por quê

- **Falha-dura preservada** (ADR-010): nenhum aceite nasce com placeholder não resolvido. A omissão por seção é determinística e auditável (marcador de heading), não "string vazia silenciosa".
- **Documento jurídico limpo**: o usuário assina Seção 1 + Assinatura, sem notas internas do PO — exatamente o escopo que a estória pede ("apenas seção Termos gerais").
- **Unicidade sobre dado cifrado** sem reabrir ADR-009: o hash determinístico é o mecanismo que o próprio ADR aponta como evolução. Sem ele, CA-3 seria impossível com Encrypted Cast.
- **KISS** (#1): split por heading + regex own; zero dependência nova.

## Alternativas consideradas

- **Renderizar o documento inteiro e confiar que a Seção 2 fica "vazia"**: cairia na falha-dura (placeholders de turno sem valor) e exibiria as notas do PO ao usuário. Descartada.
- **Omitir seção por "todos os placeholders ausentes"** (regra genérica do ADR): manteria os blocos sem placeholder (Histórico/Notas do PO), que não devem aparecer. Descartada em favor do allowlist de headings.
- **Unicidade por decriptar e comparar em memória**: O(n) por cadastro, sem constraint de banco, sujeito a corrida. Descartada — o `UNIQUE(documento_hash)` é a barreira mecânica.

## Impacto / sinais de revisão

- **Acoplamento ao texto do heading** (`## Seção 1…`, `## Assinatura eletrônica`): se o admin renomear esses headings no editor de templates, o render de adesão muda. Mitigação: os dois templates-seed usam esses marcadores; vale uma validação no editor (STORY futura) que avise se o template não tem "Seção 1". **Flag para o PO:** o `conteudo` seedado inclui `## Notas do PO` / `## Histórico de validação` — convém limpar o texto-seed para que o `conteudo` contenha só o documento jurídico (decisão de conteúdo do PO).
- **`documento_hash` com pepper = APP_KEY**: rotação de APP_KEY invalida os hashes (sem quebrar dados — só a busca por duplicidade). Se APP_KEY rotacionar, rodar job de recomputação do hash. Registrado como sinal de revisão, não bloqueante no MVP.
