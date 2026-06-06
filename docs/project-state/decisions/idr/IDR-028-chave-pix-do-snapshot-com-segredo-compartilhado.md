---
idr_id: IDR-028
slug: chave-pix-do-snapshot-com-segredo-compartilhado
title: Chave Pix do snapshot de pix_falhas cifrada com segredo dedicado compartilhado api+admin
status: accepted  # aprovado por Alexandro em chat (2026-06-06) na decisão da STORY-065
decided_at: 2026-06-06
decided_by: programador
owner_agent: claude-opus-4-8-2026-06-06
related_story: STORY-065
related_adrs: [ADR-009, ADR-016]
related_idrs: []
supersedes: null
superseded_by: null
created_at: 2026-06-06
updated_at: 2026-06-06
---

# IDR-028 — Chave Pix do snapshot de `pix_falhas` cifrada com segredo dedicado compartilhado api+admin

## Contexto

A fila "Pix com falha" do Backoffice (STORY-065 CA-5/CA-8, PDR-010) precisa exibir a
**chave Pix do profissional** — o admin faz o Pix manualmente fora da plataforma. A chave
mora em `profissional_profiles.chave_pix_encrypted` com o cast `encrypted` nativo, que usa
a `APP_KEY` — e **cada app tem a sua** (api ≠ admin, local e homolog). O Backoffice não
consegue descriptografar o dado da api.

A ADR-009 (Decisão 5A) previa "chave de criptografia distinta da APP_KEY, no Secret
Manager" para os campos sensíveis, mas a implementação de EPIC-001 usou o cast nativo
(APP_KEY). Re-criptografar todos os campos de EPIC-001 agora seria escopo de estória
própria — **gap apontado ao Arquiteto** (ver "Pendência" abaixo).

## Decisão

> **Decidi cifrar a chave Pix do snapshot de `pix_falhas` com um segredo DEDICADO e
> COMPARTILHADO entre `api` e `admin` (`PIX_FALHA_CHAVE_KEY`), via cast custom
> `ChavePixCompartilhada` espelhado nos dois apps.**

- A `api` grava o snapshot no registro do caso (momento da falha); o `admin` decifra só
  para exibir/copiar. Em repouso, nunca em claro (ADR-016 g).
- Segredo distinto das duas APP_KEYs (espírito da ADR-009 5A): vazar a APP_KEY de um app
  não expõe as chaves Pix, e vice-versa.
- Dev/CI: default fixo em `config/services.php` (mesmo racional do `sk_mock`/`whsec_mock`
  — ambiente local sem internet). Homolog: secret novo no Secret Manager (Terraform),
  injetado em `api`, `worker` e `admin`.
- Junto: o caso carrega **snapshot operacional** (profissional, função, estabelecimento,
  valor) — o Backoffice lê uma tabela só, sem replicar `turnos`/`vagas`/`funcoes` nas
  migrações de teste do admin, e o caso preserva o estado do instante da falha.

## Alternativas consideradas

1. **Compartilhar a APP_KEY entre apps** — rejeitada: entrelaça sessões/cookies/tokens dos
   dois apps; vazamento cruzado (o que a ADR-009 quis evitar).
2. **Implementar a ADR-009 5A por inteiro agora** (chave dedicada + re-criptografia de
   todos os campos de EPIC-001 nos 2 apps) — rejeitada para esta estória: escopo grande;
   apontada como pendência ao Arquiteto.
3. **Chave mascarada no admin** — rejeitada: viola o CA-5 (o admin precisa da chave para o
   Pix manual).

## Consequências

- Dois arquivos `ChavePixCompartilhada` (api e admin) devem permanecer em sincronia.
- Rotação do segredo exige re-criptografia das linhas abertas de `pix_falhas` (volume
  esperado ≈ 0–poucas; job artisan trivial se preciso).
- **Pendência ao Arquiteto:** alinhar a implementação dos casts de EPIC-001 à ADR-009 5A
  (chave dedicada geral) — quando isso acontecer, este IDR pode ser superseded e o campo
  migrado para o mecanismo unificado.
