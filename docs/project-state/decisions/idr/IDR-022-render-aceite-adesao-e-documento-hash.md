---
idr_id: IDR-022
slug: render-aceite-adesao-e-documento-hash
title: Renderização do aceite de adesão (omissão de Seção 2 + notas internas), preview vs. assinatura, e documento_hash para unicidade
status: accepted
decided_by: claude-opus-4-8-programador-2026-06-01
related_stories: [STORY-023, STORY-024]
related_adrs: [ADR-009, ADR-010]
related_pdrs: [PDR-001]
created_at: 2026-06-01
updated_at: 2026-06-01
---

# IDR-022 — Renderização do aceite de adesão, preview e documento_hash

## Contexto

STORY-023 gera o `AceiteEletronico` de **adesão** (sem turno) no clique de "Aceito e concluir
cadastro". O motor de renderização é o da ADR-010 (substituição `{{ns.campo}}` via regex, falha
dura em placeholder ausente). Ao implementar do zero (revert de `690a252`), três pontos de baixo
nível precisaram de decisão com impacto na STORY-024 (espelho do contratante) e no EPIC-003
(aceite por turno). Registrados aqui.

## Decisão

### (a) Corpo do contrato de adesão = preâmbulo + Seção 1 + Assinatura; Seção 2 e notas internas são omitidas

O `conteudo` da `TemplateVersao` (texto-seed STORY-015) contém, além do contrato:
`## Seção 2 — Termos do turno específico` (placeholders de turno/contratante/habitualidade) e
blocos de **metadados de autoria** (`## Histórico de validação`, `## Notas do PO`, dúvidas
jurídicas). No aceite de adesão **não há turno** e essas notas **não são parte do contrato**
exibido/assinado pelo profissional.

O renderer de adesão extrai o corpo por blocos de cabeçalho `## `: mantém o preâmbulo (título +
introdução) e **descarta** qualquer bloco cujo cabeçalho comece com `Seção 2`,
`Histórico de validação` ou `Notas do PO`. Resultado: título + Seção 1 (cláusulas gerais) +
Assinatura eletrônica. Isso concretiza a nota do próprio texto-seed ("o motor omite a Seção 2
quando os placeholders de turno/contratante são nulos") e evita expor notas internas/dúvidas
jurídicas ao usuário. A abordagem por blocos é robusta a reordenação e degrada com segurança: se
um marcador mudar, placeholders de turno remanescentes causam **falha dura** (nenhum aceite
incompleto é gerado), nunca texto silenciosamente vazio.

### (b) Campos de assinatura (`aceite.*`) só existem no momento do aceite — preview usa marcador pendente

`{{aceite.timestamp}}`, `{{aceite.ip}}` e `{{aceite.fingerprint}}` são, por natureza, conhecidos
apenas **no ato de assinar**. O **preview** (mostrado antes do clique) renderiza o documento
idêntico, mas substitui esses três placeholders por um marcador fixo
("— preenchido no momento do aceite —"). No **accept**, o servidor re-renderiza com os valores
reais e persiste isso como `conteudo_renderizado`. O corpo contratual (preâmbulo + Seção 1 + bloco
de assinatura com rótulos) é **idêntico** entre preview e persistido; só os três valores de carimbo
de assinatura passam de marcador → valor real. É o equivalente digital de um contrato em papel cujo
preview mostra a linha de assinatura/data em branco, preenchida ao assinar. CA-9 ("igual ao
preview") é satisfeito para todo o corpo contratual; a diferença é exatamente o ato de assinar.

### (c) `profissional.endereco_completo` é composto de `bairro, cidade`

O perfil do profissional coleta `cidade` e `bairro` (pré-cadastro), não logradouro completo (não
está na lista de campos da STORY-023 §O quê). O placeholder `{{profissional.endereco_completo}}`
da Seção 1 é resolvido como `"{bairro}, {cidade}"`. Sem novo campo de endereço — escopo respeitado.

### (d) Unicidade do documento via `documento_hash` determinístico

`documento_encrypted` (Eloquent Encrypted Cast, ADR-009 Decisão 5A) é **não-determinístico** (IV
por gravação) — não permite `UNIQUE` nem lookup. Para a CA-3 ("documento único no sistema") adoto
a evolução prevista na própria ADR-009 §trade-offs: coluna `documento_hash` =
`hash_hmac('sha256', <apenas dígitos>, APP_KEY)`, com índice **único**. A verificação de duplicidade
compara hashes; o erro é **genérico** (não revela a quem pertence o documento). O valor em claro
permanece só em `documento_encrypted`.

## Consequência

- STORY-024 (contratante) reusa o mesmo renderer/estrutura; o contratante é sempre PJ (CNPJ) e seu
  template `mei_pj_b2b`/equivalente segue o mesmo corte de Seção 2 + notas.
- EPIC-003 (aceite por turno) **não** corta a Seção 2: passará o contexto de turno/contratante e
  manterá a Seção 2; o renderer de adesão e o de turno divergem só na seleção de blocos + contexto.
- O `documento_hash` é por-ambiente (depende de APP_KEY); rotação de APP_KEY exige recomputar
  hashes (job futuro) — aceitável no MVP, alinhado à mesma premissa de rotação da ADR-009.

## Alternativas descartadas

- **Renderizar o `conteudo` inteiro** (com Seção 2 e notas do PO): exporia notas internas e
  cláusulas de turno em branco ao usuário — rejeitado.
- **Editar o texto-seed para remover as notas**: conteúdo de template é STORY-015/append-only
  (ADR-010); fora do escopo desta estória e versionado — rejeitado.
- **UNIQUE direto em `documento_encrypted`**: impossível (ciphertext não-determinístico).
