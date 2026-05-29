---
id: IDR-013
title: Fila de aprovação — seam da ACL de e-mail no Backoffice, soft-delete por status, lock otimista e paridade de migração
status: proposed
decided_at: null
decided_by: null
source_story: STORY-019
supersedes: nada
refines: nada
superseded_by: nada
---

# IDR-013 — Decisões técnicas da fila de aprovação (STORY-019)

## Contexto

STORY-019 implementa a fila de aprovação no Backoffice (Livewire). Quatro decisões de implementação têm impacto além desta estória e ficam registradas aqui. Nenhuma reabre ADR (009/011 vigentes); todas operam **dentro** delas.

## Decisões

### a) Estratégia de remoção = soft-delete via `status='recusado'` (não hard delete)

A estória cita PDR-001 ("recusa = remoção") e manda **seguir o ADR-009** para a estratégia. ADR-009 §Consequências/Neutras resolve a tensão: `status='recusado'` é **soft-delete lógico** — o registro permanece para o `admin_audit_log` referenciá-lo por `target_id` (FK `nullOnDelete` perderia a trilha em hard delete). O hard delete (direito ao esquecimento, LGPD) fica para um **job de retenção fora do MVP**.

`ApprovalService::remove()` faz `UPDATE users SET status='recusado'` e grava `admin.user.removed` com `previous_status`. Sem e-mail, sem motivo textual (PDR-001).

### b) Race condition = lock otimista por UPDATE condicional em `status`

Aprovar/remover usam `User::whereKey(id)->where('status','pendente_aprovacao')->update(...)` e checam as **linhas afetadas**. Zero linhas ⇒ outro admin já processou ⇒ `CadastroJaProcessadoException`, sem efeito colateral (sem audit log, sem e-mail). Escolhido sobre `SELECT FOR UPDATE` pessimista por ser mais simples, atômico no Postgres e suficiente para o volume do MVP (CA-6).

### c) Seam da ACL de e-mail no Backoffice — interface + VO + job + adapter log-only

CA-7 exige **dispatch** de `aprovacao_concedida` "via ACL de ADR-011", mas STORY-014 foi spike (só ADR) e a entrega real é STORY-021. STORY-019 cria o **mínimo da ACL** no app admin (`app/Domain/Email/`): interface `EnviaEmailTransacional`, VO `EmailTransacional` (com mascaramento de PII para log — ADR-008), enum `TipoEmail`, e um **adapter log-only** (`LogEnviaEmailTransacional`) ligado no container. O despacho é um job (`EnviarEmailTransacionalJob`) na **fila `database`** (ADR-011 §g: 3 tentativas, backoff 30s/5min/30min). O job resolve a ACL e delega.

**Fronteira com STORY-021:** STORY-021 implementa o adapter Resend + Mailables e **troca só o binding** no `AppServiceProvider` — sem tocar `ApprovalService`, o job ou o chamador. A localização canônica da interface (`packages/domain` vs app) continua decisão de STORY-021 (ADR-011 §b); STORY-019 a mantém local ao admin para não antecipar essa escolha. Quando STORY-021 mover, atualiza o import.

### d) Paridade de migração entre apps que compartilham o banco `turni`

API e Backoffice apontam para o mesmo Postgres e mantêm **migrações com nome de arquivo byte-idêntico** para as tabelas compartilhadas — o runner do Laravel deduplica por nome (a 2ª app vê a migração como já aplicada e pula). STORY-019 copiou para o admin as 3 migrações de pré-cadastro que a API havia adicionado (`funcoes`, colunas de pré-cadastro em `profissional_profiles`/`contratante_profiles`), mantendo a convenção — sem isso, o banco de teste isolado do admin (`turni_test`) não teria as colunas que a fila lê.

## Consequência operacional descoberta (fora do escopo, corrigida)

Durante a verificação em browser, o login do admin com dados semeados pela API dava **500 "password does not use the Bcrypt algorithm"**: a API escreve hashes **Argon2id** (`HASH_DRIVER=argon2id`, ADR-007), mas o Backoffice não declarava `HASH_DRIVER` e caía no default **bcrypt**, falhando o `Hash::check`. Faltava em `apps/admin/.env(.example)` o `HASH_DRIVER=argon2id` que ADR-007 manda configurar em **ambas** as apps (STORY-006). Corrigido nesta estória (`.env.example` + `.env` dev). **É um gap latente de STORY-016/Foundation** — sinalizado ao PO para registro no DoD de auth (login do admin contra seeds compartilhados não estava coberto por E2E rodando de fato).

## Verificação

- Coberto por testes Pest (núcleo `ApprovalService` 98.4%; ACL de e-mail 100%) e E2E Playwright CA-13 (a–d) verde em browser real contra localhost:8002.
