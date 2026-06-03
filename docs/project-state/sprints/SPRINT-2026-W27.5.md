---
sprint_id: SPRINT-2026-W27.5
wave: WAVE-2026-01
status: planned
start_date: null  # ativa quando SPRINT-2026-W27 fechar (STORY-054 done + veredito aceito)
end_date: null
soft_cap_date: 2026-06-07  # ~4 dias corridos a partir da provável ativação 2026-06-04; sprint deliberadamente curta — janela cirúrgica
opened_at: 2026-06-03
opened_by: "PO (Alexandro / Claude)"
closure_rule: "Fechamento por goal-atingido: encerra quando STORY-069, STORY-070, STORY-071 estiverem `done` E STORY-072 (validador) tiver emitido veredito em `validation/report.md` aceitável pelo PO (`approved` ou `approved_with_pending` que o PO assuma como goal-atingido). Soft-cap em 2026-06-07 (~4 dias corridos) serve como gatilho de reavaliação — não é prazo de entrega. SPRINT-2026-W28 NÃO ativa até esta sprint fechar."
goal: "Refatoração transversal para UUIDv7 nas chaves primárias de todas as entidades de domínio (15 tabelas × 2 apps Laravel + 1 webapp Flutter), com ADR-018 `accepted`, schema novo em homolog via `migrate:fresh --seed`, polimórficos coerentes (`uuidMorphs()` em `personal_access_tokens` e `audit_logs`), 14 models com `HasVersion7Uuids`, Flutter consumindo IDs como `String`, e validador re-rodando os fluxos de aceite dos EPIC-001 (cadastro/aprovação/welcome/AceiteEletronico) e EPIC-002 (publicar vaga, feed com match, candidatura, painel, edição material, notificações) sem regressão. Sprint cirúrgica entre W27 (em fechamento) e W28 (planned, EPIC-003 — Pagar.me) para honrar o desejo arquitetural original antes da janela fechar no commit da STORY-056."
---

# SPRINT-2026-W27.5

## Objetivo do sprint

A SPRINT-2026-W27 está fechando o EPIC-002 (primeiro encontro Turni vivo em homolog). A SPRINT-2026-W28 está planejada para abrir o EPIC-003 (Aceite, PIN, Pix via Pagar.me), o épico mais pesado e arriscado da WAVE-2026-01. Entre as duas, esta sprint **cirúrgica** abre uma janela curta para quitar um débito antigo que ficou para trás na execução das W22–W27: **os identificadores de entidade ainda são `bigint` auto-increment, contrariando o desejo arquitetural original do projeto** (UUID string, válido também no banco). O desejo nunca foi registrado em ADR — viveu como folclore técnico — e o tempo para corrigi-lo a baixo custo está se fechando.

Por que agora, em uma sprint dedicada:

1. **Janela aberta.** Hoje não há produção (zero dados), nenhuma integração externa armazena IDs do Turni, e o validador acabou de aprovar EPIC-001 e EPIC-002 — temos linhas de base de E2E para re-rodar em homolog após o refactor.
2. **Janela fechando.** STORY-056 da W28 implementa o adapter Pagar.me sandbox e passa a usar `external_reference` apontando para IDs de turno/candidatura. Depois desse commit, virar o tipo exige limpar sandbox e reemitir webhooks idempotentes — custo cresce de forma não-linear.
3. **Não inflar W28.** W28 já é a sprint mais pesada da onda (14 estórias, 2 L, abre PIN + Pagar.me + Pix). Empilhar refator estrutural dentro dela viola "uma razão para mudar por sprint" (disciplina W22-W27) e desloca o gatilho de reescopo de D+16.
4. **Disciplina herdada.** Não misturar refator estrutural com sprint em curso — W27 fecha limpa primeiro. Ato seguinte é abrir esta sprint e quitar o débito antes de W28 ativar.

O escopo é **deliberadamente curto e amarrado**: 1 spike de Arquiteto (decisão fina + 4 validações empíricas, produz ADR-018 `accepted`), 1 refator backend (api + admin), 1 refator frontend (webapp Flutter), 1 validação independente. Soft-cap de 4 dias corridos — sprint não é para descobrir nada novo de produto; é para pagar uma dívida estrutural conhecida.

A sprint **NÃO** abre frente nova fora do EPIC-010. EPIC-003 (W28) só começa após o veredito da STORY-072 ser aceito pelo PO.

## Escopo e duração

- **Escopo**: 4 estórias — EPIC-010 inteiro. Mix: **1 M (spike) + 1 L (refactor backend) + 1 M (refactor frontend) + 1 M (validação)**.
  - **STORY-070 (refactor backend, L)** é candidata natural a estouro de sessão única. Critério de quebra documentado na própria estória: separar **(a) `apps/api`** de **(b) `apps/admin`** em duas estórias se a sessão estourar.
- **Duração**: **aberta**, com fechamento por goal-atingido (padrão consolidado W22→W27). Soft-cap em **2026-06-07** (~4 dias corridos a partir da provável ativação em 2026-06-04). Sprint deliberadamente curta — escopo cirúrgico, sem descoberta de produto.
- **Pré-condição de ativação:** SPRINT-2026-W27 com STORY-053 e STORY-054 `done` e veredito do validador aceito pelo PO. Sem isso, W27.5 não abre.

## Estórias incluídas

### EPIC-010 — Refatoração transversal UUID

| ID        | Título                                                                          | Papel        | Tipo           | Tamanho | Bloqueada por           |
| --------- | ------------------------------------------------------------------------------- | ------------ | -------------- | ------- | ----------------------- |
| STORY-069 | Spike Arquiteto — variante UUID, polimórficos, plano (produz ADR-018 `accepted`) | arquiteto    | spike          | M       | W27 fechada             |
| STORY-070 | Refactor backend — schema, models, FKs, polimórficos, seeders, factories, testes (api + admin) | programador  | refactor       | **L**   | 069                     |
| STORY-071 | Refactor frontend — Flutter webapp: DTOs, services, telas, integration_test    | programador  | refactor       | M       | 069 (paralelo a 070)    |
| STORY-072 | Validação final EPIC-010 — re-run EPIC-001 + EPIC-002 + smoke `migrate:rollback` | validador    | validation     | M       | 070, 071                |

**Sizing total da sprint**: 1 L + 3 M. Mais leve que W27 e W28 por design — sprint cirúrgica.

## Ordem de execução obrigatória (dependências)

```
W27 fecha (STORY-053 + STORY-054 done + veredito aceito)
    │
    ▼
STORY-069 (spike Arquiteto + ADR-018 → accepted)
    │ ADR-018 accepted, plano de execução fechado
    │
    ├─► STORY-070 (refactor backend — api + admin)
    │        │
    │        └─────┐
    │              │
    ├─► STORY-071 (refactor Flutter webapp) ─── (paralelo a 070)
    │              │
    │   ┌──────────┘
    │   │
    │   ▼
    └─► STORY-072 (validação final EPIC-010)
              │ veredito aceito
              ▼
        SPRINT-2026-W28 ativa (EPIC-003)
```

**Paralelismo legítimo**:
- STORY-070 (backend) e STORY-071 (Flutter) rodam em paralelo após STORY-069 fechar. Tocam pastas distintas (`apps/api` + `apps/admin` vs `apps/webapp/lib`); zero overlap de merge.

**O que NÃO paralelizar**:
- Nada antes de STORY-069. ADR-018 precisa estar `accepted` antes que qualquer código mude — disciplina herdada da W27 (lição STORY-048: spike precede implementação, não é simultâneo).
- STORY-072 não roda antes de STORY-070 e STORY-071 estarem `done`. Validador valida estado final em homolog.

## Compromisso visível ao fim do sprint

Ao fim da sprint, em homologação:

1. Banco Postgres com coluna `id` do tipo `uuid` em todas as 15 tabelas de domínio (`users`, `profissional_profiles`, `contratante_profiles`, `admin_audit_log`, `funcoes`, `templates`, `template_versoes`, `aceites_eletronicos`, `cadastro_lembretes`, `vagas`, `vaga_versoes`, `candidaturas`, `audit_logs`, `notificacoes`, `passkeys`).
2. FKs idem (`foreignUuid`) — incluindo `personal_access_tokens.tokenable_id` e `audit_logs.target_id` como `uuidMorphs()`.
3. `apps/api` e `apps/admin` rodando o schema novo, seeders rodando, testes verdes em CI (Pest).
4. `apps/webapp` Flutter compilando, integration_test verde, IDs tipados como `String`.
5. Re-run dos fluxos canônicos do EPIC-001 (pré-cadastro PF/MEI/PJ → fila aprovação → welcome → completar cadastro → AceiteEletronico imutável) e do EPIC-002 (publicar vaga → feed com match → candidatura → painel → edição material + snapshot → notificações) verde em homolog.
6. `php artisan migrate:fresh --seed` e `php artisan migrate:rollback` exercidos com sucesso (F-NB-1 do EPIC-000 quitado para a base nova).
7. ADR-018 `accepted` por PO.

## Riscos identificados na abertura

| Risco | Probabilidade | Impacto | Mitigação | Owner |
|---|---|---|---|---|
| Spatie/Laravel-Passkeys não suportar User com PK UUID sem patch | baixa | médio | STORY-069 inclui validação empírica deste ponto (item 4 do spike); se inviável, considerar coluna `users.uuid` separada ou substituir lib | Arquiteto |
| Sanctum override de `personal_access_tokens.tokenable_id` quebrar fluxo de auth em homolog | baixa | alto | Migration de override é caminho documentado oficialmente; testes de auth do EPIC-001 re-rodam na STORY-072 e capturam regressão | Programador |
| Score breakdown JSON em `candidaturas` referenciando IDs string em formato inconsistente | média | médio | STORY-070 inclui varredura explícita do conteúdo do JSON (item de CA); se necessário, normalizar | Programador |
| Estouro de sessão única em STORY-070 (L) | média | médio | Quebra documentada: separar `apps/api` de `apps/admin` em estórias 070a/070b se necessário; agente escala ao PO antes de inflar | Programador |
| Premissa "zero produção" mudar entre aceite da ADR e execução | baixa | alto | STORY-070 abre com check explícito; se falsa, parar e reabrir Decisão 5 da ADR-018 (passar a estratégia 5B — migration de conversão) | Programador |
| Tempo apertado atrasa W28 | baixa | alto | Soft-cap em 4 dias é gatilho de reavaliação, não de entrega; se estourar, PO decide entre continuar ou suspender e abrir mini-sprint W27.6 dedicada ao item pendente | PO |

## Mudanças no escopo do sprint (preencher se houver mid-sprint changes)

| Data | O que mudou | Motivo | Custo |
|---|---|---|---|
| — | — | — | — |

## Fechamento do sprint (preencher no encerramento)

### O que foi entregue
- ...

### O que ficou para trás (e por quê)
- ...

### Aprendizados
- <produto>
- <processo>

### Ajustes para o próximo sprint
- ...
