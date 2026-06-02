---
story_id: STORY-046
slug: publicar-vaga-webapp-contratante
title: Publicar vaga no WebApp — formulário do contratante + gate PDR-005
epic_id: EPIC-002
sprint_id: SPRINT-2026-W27
type: implementation
target_role: programador
requires_design: true  # tela nova — designer entrega SCREEN spec antes
design_screen_id: SCREEN-STORY-046-publicar-vaga
status: in_progress
owner_agent: claude-opus-4-8-programador-2026-06-02
created_at: 2026-06-01
updated_at: 2026-06-02
estimated_session_size: M
produces_idr: null
---

# STORY-046 — Publicar vaga no WebApp (contratante)

> **Para o agente:** primeira tela de **escrita** do contratante autenticado depois do funil de cadastro. Tem que coexistir com RBAC vivo (EPIC-001/STORY-016 — `contratante` só vê o que é dele). Leia o screen spec antes de codificar; o Designer entrega esta tela em paralelo no início da sprint.

## Contexto

Com o modelo Vaga em pé (STORY-044) e o algoritmo de Match disponível (STORY-045), o contratante precisa de uma porta de entrada para publicar a oferta. Sem isso, o profissional não tem nada para ver no feed (STORY-048) — esta estória é o primeiro passo do "encontro" que o EPIC-002 entrega.

- Épico: `epics/EPIC-002-vaga-feed-e-candidatura/epic.md`
- Documentos canônicos:
  - `docs/especificacao/domain/vaga.md` (seções Atributos, Publicação, Estados)
  - `docs/especificacao/business-rules.md` (Habitualidade, Cadastro/aprovação para o gate de avaliação)
  - PDR-005 — gate de avaliação bloqueia publicação nova
  - ADR-013 (modelo vaga) — STORY-044
  - DDR-001 — Design System (paleta, tipografia, spacing, raios)
  - SCREEN spec: `docs/project-state/design/screens/SCREEN-STORY-046-publicar-vaga.md` (entregue por Designer em paralelo)

## O quê

Implementar a tela `/contratante/vagas/nova` no WebApp Flutter, o endpoint `POST /api/vagas` no backend Laravel/Sanctum, e o gate PDR-005 que bloqueia o submit quando o contratante tem turno finalizado pendente de avaliação. Vaga publicada com sucesso entra em estado `aberta` e fica visível no feed do profissional via STORY-048.

## Por quê

Sem porta de publicação, não há feed; sem feed, não há candidatura; sem candidatura, não há aceite (EPIC-003). É o gargalo de oferta.

## Critérios de aceite

- [ ] **CA-1:** Contratante autenticado e `ativo` acessa `/contratante/vagas/nova` no WebApp via menu (ponto exato definido pelo screen spec). Profissional autenticado tentando a mesma rota recebe 403 (RBAC herdado de STORY-016).
- [ ] **CA-2:** Formulário coleta os 6 campos obrigatórios do `domain/vaga.md` (função do Core FHP em dropdown, `data_inicio`, `data_fim`, `valor` em R$, `posicoes` ≥ 1, `observacoes` opcional). Validação client-side em tempo real; validação server-side espelhada nos mesmos critérios (FormRequest Laravel).
- [ ] **CA-3:** `data_fim > data_inicio` (regra do banco em CA-5 da STORY-044) é validada no client com mensagem clara antes do submit.
- [ ] **CA-4:** Dropdown "Função" carrega a lista canônica do Core FHP (já existe? se não, seeder estático em `database/seeders/FuncoesSeeder.php` com a lista fixa do MVP — confirmar com PO se já existe; senão, criar mínimo: `Garçom`, `Cozinheira`, `Bartender`, `Pizzaiolo`, `Auxiliar de Cozinha`, `Recepcionista`, `Hostess`).
- [ ] **CA-5:** Gate PDR-005: antes de exibir o formulário, o WebApp consulta `GET /api/avaliacoes/pendentes-do-contratante`; se houver turno finalizado sem avaliação, o formulário é substituído por um aviso ("Avalie seus turnos pendentes para publicar nova vaga") + botão CTA para a tela de avaliação pendente. Não há "publicar mesmo assim". Endpoint retorna `{ pending: int, turnos: [...] }`; quando `pending > 0`, formulário não renderiza.
- [ ] **CA-6:** Submit POST `/api/vagas` com payload validado retorna 201 + body da vaga criada (`{ id, estado: 'aberta', ... }`). Backend cria a linha em estado `aberta`, registra evento de audit log `vaga.criada` (herda padrão EPIC-001).
- [ ] **CA-7:** Após submit com sucesso, WebApp navega para a lista "Minhas vagas" (STORY-047) com toast de confirmação ("Vaga publicada — começou a aparecer para profissionais"). Se STORY-047 ainda não estiver done (carry-over), navega para o detalhe da vaga ou para uma página `/contratante/vagas/{id}` placeholder com `id` e `estado`.
- [ ] **CA-8:** Cobertura unitária do controller e FormRequest ≥ 95%. Cobertura dos widgets do formulário ≥ 80%. Testes cobrem: campos obrigatórios faltando, `data_fim ≤ data_inicio`, `posicoes < 1`, função fora da lista, gate PDR-005 disparando.
- [ ] **CA-9:** E2E em `integration_test` (padrão IDR-010/011 da W26): login como contratante seed → navega para `/contratante/vagas/nova` → preenche → submete → vaga existe no banco (verifica via API ou query). 0 flake em 3 runs no CI.
- [ ] **CA-10:** Telemetria: log JSON estruturado `vaga.publicada` com `vaga_id`, `contratante_id`, `funcao`, `posicoes`, `valor`. Sem PII além do `contratante_id` (que já é referenciado).

## Fora de escopo

- Cancelar vaga / lista "Minhas vagas" → STORY-047.
- Edição de vaga (PDR-009) → STORY-052.
- Notificação a candidatos pendentes → não aplica (vaga acabou de ser criada).
- Multi-unidade (Enterprise) — `estabelecimento_id` herda do contratante; sem seleção de unidade.

## Padrões de qualidade

- Cobertura unitária ≥ 95% no controller/FormRequest, ≥ 80% no resto.
- E2E em browser real cobrindo o caminho feliz.
- Sem código não testado.
- RBAC respeitado: profissional tentando rota recebe 403.

## Dependências

- **Bloqueada por:** STORY-044 (modelo Vaga), DDR Designer entregando SCREEN-STORY-046 (paralelo no início da sprint).
- **Bloqueia:** STORY-047 (lista minhas vagas — pode renderizar sem vagas, mas é estranho), STORY-048 (feed precisa ter alguma vaga real para ser observável end-to-end).
- **Pré-requisitos de ambiente:** RBAC vivo (STORY-016 done), contratante seed `ativo` em homolog.

## Decisões já tomadas

- ADR-013 (STORY-044): modelo Vaga, estados, audit log de `vaga.criada`.
- ADR-007: Sanctum SPA WebApp.
- PDR-005: gate de avaliação.
- DDR-001: Design System vivo.

## Liberdade técnica do agente

Você decide: estrutura de pastas no WebApp (`lib/features/contratante/vagas/`), gerenciamento de estado (Bloc/Riverpod/...) — alinhar com padrão já usado no WebApp se houver. Você NÃO decide: payload do endpoint (definido pela ADR-013 + screen spec), campos obrigatórios (vêm de `domain/vaga.md`).

## DoD

- [ ] CAs todos checados.
- [ ] Cobertura nos patamares exigidos.
- [ ] E2E verde no CI.
- [ ] Deploy de homolog mostra a tela funcional para um contratante seed.
- [ ] `index.json` atualizado.
- [ ] "Notas do agente" preenchida.

## Notas do agente

### Documentos lidos
- Estória inteira; `domain/vaga.md`; ADR-013 (modelo Vaga + evento `vaga.criada` + snapshot v1 na publicação); PDR-005 (gate); DDR-001/tokens; SCREEN-STORY-046 (spec validado pelo humano 2026-06-02).
- Código: `Vaga`/`VagaVersao`/`AuditLog` models + `VagaEstado` enum + `VagasSeeder` (cria vaga + versão 1); `FuncaoController` (`GET /api/funcoes` já existe); padrão RBAC = `FormRequest::authorize()` + `abort_unless(...,403)` (sem Policy class); `CompletarCadastroContratante*` (controller/request/service/teste) como idioma; front: `cadastro_types.dart` (`cadastroApiBase`, result types), `completar_cadastro_contratante_service.dart`, `router.dart` (funnel guard go_router), `auth_service.dart` (sessão + role).

### Entendimento consolidado
- Tela de **escrita** do contratante: form de 6 campos → `POST /api/vagas` → vaga `aberta` + snapshot v1 + audit `vaga.criada` + telemetria `vaga.publicada`. Localização (`lat/lng/cidade/uf`) **derivada do contratante** (ADR-013), não coletada.
- Gate PDR-005 (CA-5): `GET /api/avaliacoes/pendentes-do-contratante` → `{pending,turnos}`. **Decisão do PO (Alexandro, chat 2026-06-02): stub-honesto** — turnos/avaliações são do EPIC-003; o endpoint retorna `pending:0` por um service isolado que o EPIC-003 preenche; UI do gate testada no front com `pending>0` mockado.
- RBAC (CA-1): profissional → 403 no back (authorize/abort) e estado "sem permissão" + guard no front.

### Plano
1. **Back (TDD):** `StoreVagaRequest` (CA-2/3) + `VagaController@store` + `PublicarVagaService` (cria vaga + versão 1 + audit + telemetria) ; `AvaliacoesPendentesController` + `AvaliacoesPendentesContratante` service (gate, CA-5) ; rotas protegidas (auth:web + WebAppOnly + FunnelGuard + StartSession).
2. **Front (TDD):** `VagaService` (POST + gate) ; `PublicarVagaScreen` + home contratante com CTA ; rotas `/contratante/vagas/nova` + sucesso ; guard RBAC ; widget tests.
3. **E2E** (CA-9) em `integration_test` same-origin (IDR-010/011/021).
4. Suíte completa verde + Pint + flutter analyze/format ; Notas finais + index.json.

### Mapeamento CA → testes (planejado)
- CA-1 RBAC: `back: profissional recebe 403 no POST e no GET do gate`; `front/e2e: guard mostra sem-permissão`.
- CA-2 campos obrigatórios + espelho server: `back: 422 por campo faltando (funcao/data_inicio/data_fim/valor/posicoes)`; `front: validação client`.
- CA-3 data_fim>data_inicio: `back: 422`; `front: errorText`.
- CA-4 dropdown funções: reusa `GET /api/funcoes` (já testado, STORY-017); `front: dropdown popula`.
- CA-5 gate: `back: GET retorna {pending:0,turnos:[]} p/ contratante; 403 p/ profissional`; `front: pending>0 → gate, pending=0 → form`.
- CA-6 201 + estado aberta + audit: `back: cria vaga aberta + versão 1 + audit_logs vaga.criada`.
- CA-7 navegação + toast: `front/e2e: após sucesso vai p/ /contratante/vagas + toast`.
- CA-8 cobertura: ≥95% controller/request, ≥80% widgets.
- CA-9 E2E: `integration_test: login contratante → form → submit → vaga no banco`.
- CA-10 telemetria: `back: Log vaga.publicada com vaga_id/contratante_id/funcao/posicoes/valor`.

### Decisões tomadas
- Gate PDR-005 = stub-honesto (acima). A localização da vaga vem do `contratanteProfile` (cidade/uf); `lat/lng` ficam null até o EPIC-003 (schema permite null).

### Descobertas
- `GET /api/funcoes` e a tabela/seed de funções já existem (STORY-017) → CA-4 satisfeito sem novo seeder.

### Bloqueios
- (nenhum)

### IDRs
- 
### Cobertura final
- Unitários: 
- E2E: 
### Links
- PR: 
- Pipeline: 
- Deploy: 
