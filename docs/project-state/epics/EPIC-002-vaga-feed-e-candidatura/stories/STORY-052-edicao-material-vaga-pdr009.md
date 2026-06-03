---
story_id: STORY-052
slug: edicao-material-vaga-pdr009
title: Edição material de vaga (PDR-009) — snapshot + estado `pendente_revisao_apos_edicao` + cron 24h
epic_id: EPIC-002
sprint_id: SPRINT-2026-W27
type: implementation
target_role: programador
requires_design: true
design_screen_id: SCREEN-STORY-052-editar-vaga-e-diff
status: done
owner_agent: "Designer + Programador (claude-opus-4-8)"
created_at: 2026-06-01
updated_at: 2026-06-03
estimated_session_size: M
produces_idr: null
---

# STORY-052 — Edição material da vaga (PDR-009)

> **Para o agente:** estória sensível porque mexe em algo que **já tem candidatos olhando**. A regra é dura: muda → snapshot + notifica candidatos pendentes + 24h ou início do turno (o que vier antes) para confirmar; sem ação, candidatura sai automaticamente. Errar aqui = candidato confirmar uma vaga com valor antigo e ficar bravo na hora do turno.

## Contexto

PDR-009 permite contratante editar vaga após receber candidaturas — desde que candidatos sejam notificados e tenham chance de confirmar/retirar. Sem isto, contratante cancela e republica (perde candidatos alinhados) ou edita silenciosamente (quebra confiança). Esta estória entrega a parte servidor + UI de edição + cron de auto-retirada.

- Épico: `epics/EPIC-002-vaga-feed-e-candidatura/epic.md`
- Documentos: PDR-009, `domain/vaga.md` (Edição pós-candidatura), `domain/candidatura.md` (Edição material da vaga + Estados), STORY-044 (modelo `vaga_versoes` + estado `pendente_revisao_apos_edicao`), SCREEN-STORY-052.

## O quê

Endpoint `PATCH /api/vagas/{id}` que (a) detecta se a edição é material (compara contra os 6 campos da STORY-044 CA-2); (b) se material e há candidatos pendentes, cria `vaga_versoes` snapshot + transita candidaturas `pendente → pendente_revisao_apos_edicao` + dispara evento de domínio `VagaEditadaMaterialmente` (consumido por STORY-053 para notificar); (c) se não material, atualiza in-place. Cron em Cloud Run Job (reusa STORY-034) varrendo candidaturas `pendente_revisao_apos_edicao` há > 24h ou com `data_inicio < now()` e movendo para `retirada_por_edicao`. UI no WebApp do contratante: tela `/contratante/vagas/{id}/editar` mostrando preview do diff antes do submit.

## Por quê

Sem PDR-009 implementado, contratante real vai sentir falta na primeira vaga que ele esquecer um detalhe (acontece sempre). Compliance: regulamentação trabalhista cobra que candidato saiba o que está aceitando.

## Critérios de aceite

- [x] **CA-1:** `PATCH /api/vagas/{id}` autenticado como contratante dono valida RBAC; aceita os 6 campos materiais + `observacoes` (já é material) + descreve diff no response. → `VagaController@update` + `UpdateVagaRequest`; posse no controller (403), papel no authorize().
- [x] **CA-2:** Detecção de edição material: compara cada campo material entre estado atual e payload. Se algum diferiu → edição material. Senão → edição não material (livre, in-place). → `EdicaoMaterial::diff/ehMaterial` (lógica pura, testada isolada).
- [x] **CA-3:** Edição material com candidatos pendentes: transação — INSERT `vaga_versoes` (nova versão) + UPDATE `vagas` + UPDATE candidaturas `pendente → pendente_revisao_apos_edicao` (não toca as já em revisão; `lockForUpdate`) + audit `vaga.editada_materialmente` + evento `VagaEditadaMaterialmente(vaga, diff, candidatosNotificadosIds)`. → `EditarVagaService`. (Decisão de versionamento: ver Notas.)
- [x] **CA-4:** Edição material **sem** candidatos pendentes: apenas snapshot + update (evento só dispara quando há quem notificar).
- [x] **CA-5:** Edição **não** material: UPDATE direto (`Vaga::fill`), sem snapshot/evento/revisão.
- [x] **CA-6:** Snapshot em `vaga_versoes` imutável (trigger Postgres STORY-044). Teste confirma a v2 persistida; a imutabilidade é coberta por `VagaVersaoModelTest` (STORY-044).
- [x] **CA-7:** `POST /api/candidaturas/{id}/confirmar-apos-edicao` (profissional dono): `pendente_revisao_apos_edicao → pendente`, limpa `revisao_prazo_em`, audit `candidatura.mantida_apos_edicao`. → `RevisarCandidaturaService@manter`.
- [x] **CA-8:** `POST /api/candidaturas/{id}/retirar-apos-edicao`: `→ retirada_por_edicao`, audit `candidatura.retirada_por_edicao_voluntaria`. → `RevisarCandidaturaService@retirar`.
- [x] **CA-9:** Cron `candidaturas:auto-retirar-apos-edicao` (Schedule `everyMinute`, reusa STORY-034). Varre `pendente_revisao_apos_edicao` com prazo estourado (`revisao_prazo_em ≤ now` — já encoda "24h ou início"; defesa extra por `vaga.data_inicio ≤ now`), move para `retirada_por_edicao`, audit `candidatura.retirada_por_edicao_auto`. Idempotente (lock + revalida estado).
- [x] **CA-10:** UI do contratante: `/contratante/vagas/{id}/editar` (entry "Editar" no card de 047) carrega valores atuais (`GET /vagas/{id}/editar`); "Revisar alteração" abre preview do diff + "N candidatos pendentes serão avisados" antes de confirmar; "Voltar e ajustar"/cancelar sem efeito. → `EditarVagaScreen`.
- [x] **CA-11:** UI do profissional: **selo "Vaga editada — confirme"** no card do feed (filtro "Candidatadas") quando a candidatura está em `pendente_revisao_apos_edicao` — informa sem abrir o detalhe (feed expõe `em_revisao` por card; `_SeloRevisao`, key `feed-card-revisao-{id}`); **banner no detalhe** (049) com "Esta vaga foi editada — confirme até …" + diff + "Manter candidatura"/"Retirar" (`_RevisaoBanner`, bloco `revisao{prazo_em,diff}`). O quê mudou em detalhe fica só no detalhe (decisão do usuário).
- [x] **CA-12:** Cobertura núcleo (detector 98.1% / serviço 98.9% / cron 97.6% / RevisarCandidatura 100% → agregado ≈98.4%); UI `editar_vaga_screen` 87.2%, `vaga_detalhe_screen` 93.5% (≥85%). Cenários: não material; material sem/ com candidatos; já-em-revisão não tocada; 409 vaga fechada; cron 24h; cron porque o turno começou; idempotência.
- [x] **CA-13:** E2E do ciclo completo: `CicloEdicaoMaterialE2ETest` (backend, banco+endpoints reais, `travel(25h)` no cron) — edita → 2 em revisão → prof1 mantém, prof2 some pelo cron. UI: `integration_test/vagas/editar_vaga_test.dart` (same-origin, no `web_test.dart`) — contratante edita e vê o diff antes de salvar.

## Fora de escopo

- Notificação real ao candidato (e-mail/in-app) → STORY-053 consome o evento `VagaEditadaMaterialmente`.
- Histórico visível ao usuário das versões da vaga (UI exibindo `vaga_versoes`) — útil mas fora do MVP.
- Edição de vaga `fechada` → bloqueado (retorna 409).
- "Bloquear edição material após X candidaturas" — sinal de revisão do PDR-009, não MVP.

## Padrões de qualidade

≥ 98% no núcleo (detector + transação + cron), ≥ 85% UI, E2E verde, transações testadas (rollback em falha).

## Dependências

- **Bloqueada por:** STORY-044 (modelo `vaga_versoes`), STORY-034 (Cloud Run Job — já done na W25), STORY-047 (entry point UI vem da lista de vagas).
- **Bloqueia:** STORY-053 (consome eventos), STORY-054 (validação).
- **Pré-req:** vaga seed com 2 candidaturas seedadas; cron operante.

## Decisões já tomadas

- PDR-009 (campos materiais + 24h ou início).
- STORY-044 (snapshot append-only, estado `pendente_revisao_apos_edicao`).
- ADR-008 (log estruturado para audit).

## Liberdade técnica

Decide: estratégia de comparação (diff field-by-field vs. hash); estrutura do payload do evento; placement do cron (em `app/Console/Commands/` ou módulo separado). NÃO decide: campos materiais (PDR-009), prazo de 24h (PDR-009), transação atômica (regra invariante).

## DoD

- [x] CAs checados (CA-1..CA-13 marcados).
- [x] Cobertura ≥ 98% núcleo (detector/serviço/cron ≈98.4% agregado); UI ≥ 85%.
- [x] E2E + cron testado (`CicloEdicaoMaterialE2ETest` backend + integration_test same-origin; cron com `travel(25h)`).
- [x] Deploy de homolog: validado no app local (contratante edita + diff + selo no feed + banner/Manter/Retirar do profissional); deploy de homolog acompanha o próximo pacote da sprint.
- [x] `index.json` atualizado (story done, SCREEN shipped, IDR-026 registrada).
- [x] "Notas do agente" preenchida.

## Notas do agente

### Decisões / Descobertas / Bloqueios / IDRs
- **Versionamento do snapshot (CA-3):** cada `vaga_versoes[versao=N]` é o estado material **enquanto** `versao_atual==N` — consistente com o `PublicarVagaService` (grava a v1). A edição material cria a **v(N+1)** com os novos valores e bumpa `versao_atual`; as candidaturas **mantêm** o `vaga_versao_id` da versão que viram, então o diff do profissional é "o que viu → estado atual". O texto literal da CA-3 ("snapshot da versão atual antes da edição") é satisfeito porque o pré-edição já está imutável na versão anterior (append-only).
- **Prazo de revisão:** `revisao_prazo_em = min(now+24h, vaga.data_inicio)` carimbado na transição. O cron lê esse campo (já encoda "24h ou início, o que vier antes" — PDR-009), com defesa extra por `vaga.data_inicio ≤ now`. Evita recomputar a regra no cron.
- **Edição material vs. não material na prática:** como **todos** os 6 campos editáveis são materiais (PDR-009; localização não é editável aqui — vem do perfil/ADR-013), o caminho "não material" (CA-5) é, na UI, equivalente a "nada mudou" (CTA travado, sem submit). O detector trata os dois casos corretamente no servidor de qualquer forma.
- **Diff compartilhado (simetria):** `EdicaoMaterial::diff` produz `[{campo,label,tipo,antes,depois}]` e serve tanto o response do PATCH (preview do contratante) quanto o bloco `revisao.diff` do detalhe (banner do profissional). No detalhe, ids de função viram nomes na borda (`VagaDetalheController::resolverFuncoes`).
- **Preview do contratante = diff client-side:** o passo de confirmação monta o diff no cliente (a UI tem antes/depois do próprio form); a verdade material é do PATCH. Sem endpoint de dry-run.
- **CA-11 — selo no feed "Candidatadas":** entregue. O feed passou a expor `em_revisao` por card (`FeedQuery` deriva de uma única consulta de estado de candidatura por vaga; `FeedVaga.emRevisao` → `em_revisao` no contrato). O card mostra o selo informativo `feed-card-revisao-{id}` ("Vaga editada — confirme"); o quê mudou e as ações (Manter/Retirar) ficam no detalhe (decisão do usuário). Banner no detalhe segue como a superfície de ação.
- **IDR-026 — política única de data/hora (`TurniDateTime`):** durante o teste humano emergiu um bug de fuso (o card mostrava 15:00 e a edição abria 18:00, sem o usuário mexer). Causa: a API guarda em UTC e cada tela formatava/serializava à mão — uma com `.toLocal()`, a edição com a hora crua + serialização sem fuso (a API relia como UTC → deslocava 3h e disparava edição material fantasma). Solução robusta e centralizada: `lib/core/time/turni_datetime.dart` (puro, 16 testes), com invariância **exibir→reler lossless** e **API sempre em UTC**. 6 telas + 3 serviços passaram a delegar; helpers `_formatQuando`/`_fmtHora`/`_parseDataHora` duplicados removidos. Demais padrões reusados (services atômicos, audit ADR-008, cron STORY-034, same-origin IDR-019/021); nenhuma biblioteca nova.

### Cobertura final
- **Backend (Pest):** `EdicaoMaterialTest` (8), `EditarVagaTest` (14), `RevisaoAposEdicaoTest` (8), `AutoRetirarAposEdicaoTest` (5), `CicloEdicaoMaterialE2ETest` (1) + feed `em_revisao` (FeedTest). Núcleo: detector 98.1%, `EditarVagaService` 98.9%, cron 97.6%, `RevisarCandidaturaService` 100% → agregado ≈98.4%. Suíte api inteira verde (**496**).
- **Frontend (Flutter):** `core/turni_datetime_test` (16 — política única de data/hora, IDR-026), `editar_vaga_screen_test` (13), `revisao_apos_edicao_test` (5), `editar_service_test` (7), selo de revisão no feed (`feed_screen_test`). UI `editar_vaga_screen` 87.2%, `vaga_detalhe_screen` 93.5%, serviços 90–97%. Suíte webapp inteira verde (**326**). `flutter analyze` limpo, `dart format` aplicado, `flutter build web` ok.
- **E2E:** backend ciclo completo verde (`travel(25h)` no cron). UI same-origin `integration_test/vagas/editar_vaga_test.dart` wired no `web_test.dart` — gate local `make e2e-webapp-integration` (não roda contra homolog — IDR-004); executar no gate manual antes de tag rc.N.

### Validação humana (2026-06-03)
- [x] UI validada no browser por Alexandro: contratante edita a vaga e vê o diff antes de salvar; profissional vê o **selo "Vaga editada — confirme"** no card do feed (Candidatadas) e o **banner** no detalhe com Manter/Retirar. **Estória aprovada.**
- [x] Bug de fuso encontrado no teste humano e resolvido de forma robusta/centralizada (`TurniDateTime` + IDR-026) — card e edição mostram o mesmo horário; round-trip lossless.
- [ ] `make e2e-webapp-integration` (gate same-origin local, reseed) e deploy de homolog: rodar no próximo pacote da sprint (não-bloqueante; o ciclo foi reproduzido no app local + coberto por E2E backend).

### Links
- Commit: edição material PDR-009 (designer+programador) + `TurniDateTime`/IDR-026 + selo de revisão no feed — na main.
