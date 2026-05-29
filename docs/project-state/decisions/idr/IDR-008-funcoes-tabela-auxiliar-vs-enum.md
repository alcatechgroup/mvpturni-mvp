---
idr_id: IDR-008
slug: funcoes-tabela-auxiliar-vs-enum
title: Funções pretendidas do profissional como tabela auxiliar com seed (em vez de enum hard-coded)
status: accepted
decided_at: 2026-05-29
decided_by: programador
owner_agent: claude-opus-programador
related_story: STORY-017
related_adrs: [ADR-009]
related_idrs: []
supersedes: null
superseded_by: null
created_at: 2026-05-29
updated_at: 2026-05-29
---

# IDR-008 — Funções do profissional como tabela auxiliar com seed

## Contexto

O pré-cadastro de profissional (STORY-017) pede a "função primária pretendida" num
`select`. Não existia tabela de funções no projeto. A própria estória deixou a escolha
ao agente (§Liberdade técnica): tabela auxiliar com seed **ou** enum hard-coded, com
recomendação explícita pela tabela, antecipando uso por STORY-019 (fila de aprovação) e
por filtros de busca futuros.

## Decisão

> **Decidi criar uma tabela auxiliar `funcoes` (`id, slug, nome, ativo, timestamps`) com
> seed das funções pivotais do Turni, e referenciá-la por FK `funcao_id` em
> `profissional_profiles`.**

## Por quê

- A lista de funções é **dado de domínio que muda sem deploy**: a equipe Turni vai
  adicionar/desativar funções pelo backoffice. Enum no código exigiria migração + deploy
  a cada ajuste — atrito desnecessário (princípio KISS aplicado ao ciclo de vida real do dado).
- FK dá **integridade referencial nativa** (Postgres-first, ADR-009/ADR-000): não há como
  gravar uma função inexistente.
- STORY-019 e a busca de profissionais vão **filtrar/agrupar por função** — com tabela,
  isso é um JOIN simples e indexável; com enum, seria string solta.
- `ativo` permite **descontinuar** uma função sem apagar histórico de quem a escolheu.

## Alternativas consideradas

- **Enum hard-coded (PHP enum ou CHECK constraint):** descartado — toda mudança de lista
  vira deploy; não suporta gestão pela equipe; não há `ativo`/soft-disable.
- **String livre no perfil:** descartado — sem integridade, gera variações ("Garçom" vs
  "garcom" vs "Garcon") que quebram filtro e relatório.

## Consequências

### Para outros agentes
- A lista de funções é **fonte de dados**, não código: leiam de `funcoes` (use o model
  `App\Models\Funcao`). Não recriem enum de funções em outro lugar.
- A validação de `funcao_id` deve exigir `ativo = true` (ver `StoreProfissionalPreCadastroRequest`).
- O CRUD de funções no backoffice é trabalho futuro (não há tela ainda); a manutenção
  hoje é via seed idempotente (`FuncaoSeeder`).

### Para o projeto
- +1 tabela pequena e +1 seed idempotente. Custo desprezível.

### Trade-offs aceitos
- Um JOIN a mais para exibir o nome da função (irrelevante no volume do MVP — ADR-009 §F7).

## Como verificar

- `funcao_id` em `profissional_profiles` é FK para `funcoes` (migração
  `2026_05_29_100001_*`), com `nullOnDelete`.
- Seed reaplicável sem duplicar (`updateOrCreate` por `slug`).
- Se aparecer um segundo lugar no código com lista de funções hard-coded, esta decisão
  foi violada.
