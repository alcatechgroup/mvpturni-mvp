---
epic_id: EPIC-004
type: validation-report
validated_at: 2026-06-09
validated_by: validador (claude-opus-4-8, sessão 2026-06-09)
verdict: rejected
checklist_source: epics/EPIC-004-avaliacao-reciproca/validation/checklist.md
---

# Relatório de Validação — EPIC-004 (avaliação recíproca e fechamento do ciclo)

## TL;DR

> **Veredito: REJECTED.**
> **Contagem**: 14 itens-bloco `pass`, 3 `pass com ressalva`, 1 `fail` (1 bloqueante, 0 não-bloqueante), 1 `n/a` justificado.
> **Bloqueante (resumo factual)**: a branch principal `main` está com o pipeline **CI vermelho** desde o commit `feat(STORY-088): marca turnos pendentes…` (follow-up rc.101) — uma violação de estilo Pint (`fully_qualified_strict_types`/`ordered_imports`) em `apps/api/tests/Feature/Turno/TurnosListaTest.php`, reproduzível localmente no HEAD `3e25b14`.

---

## Resumo executivo

O EPIC-004 entrega o fechamento do ciclo: após um turno `finalizado`, ambos os lados ficam com avaliação pendente, o gate bloqueia a próxima ação (candidatar/publicar) até avaliarem, e o motor recompõe XP/score/nível com depoimentos visíveis no perfil. **A funcionalidade do épico está implementada, testada e demonstrável ao vivo em homologação** — o ciclo ponta a ponta foi exercitado na própria homolog (rc.101): gate bloqueando (`pode_candidatar=False` com 3 turnos pendentes) → submissão das avaliações (HTTP 201×3) → gate destravando (`pode_candidatar=True`), com perfil mostrando score/nível/depoimentos e a assimetria LGPD (nominal sobre o profissional, anônimo sobre o contratante). A suíte api passa (1082 testes, cobertura total 94.6%, núcleo `MotorReputacao`/`NivelProfissional` 100%); a webapp passa (≈737 testes); o E2E de browser real do perfil+gate passa same-origin.

O único impedimento é de **higiene de pipeline**: a `main` está vermelha no workflow **CI** desde o follow-up rc.101 por uma violação de estilo (Pint) num arquivo de teste. O workflow de **Release/deploy** é verde e independente — por isso rc.101 subiu em homolog normalmente. A natureza do fail é cosmética (uso de `\App\Models\Avaliacao` inline em vez de `use`), mas, pela régua objetiva de `verdict-criteria.md`, **pipeline vermelho na branch principal é fail bloqueante** (entre outros motivos, mascara futuras falhas reais sob o vermelho preexistente).

---

## Checklist preenchido

### §1 — Critérios de aceite das estórias

| Item | Status | Evidência |
|---|---|---|
| 1.1 — STORY-083..088 `done`; 089 é esta validação | ✅ | `index.json`: 083–088 `status: done`; 089 `ready` (esta) |
| 1.2 — Cada CA exercido por teste/verificação | ✅ | Mapeamentos CA→teste nas "Notas do agente" 085–088; arquivos conferidos existem (ver A.1) e amostrados quanto a força de asserção (A.2) |
| 1.3 — Nenhuma `done` com CA `[ ]` | ✅ | 085 (8 CAs), 086 (6), 087 (7), 088 (7) todos `[x]` |
| 1.4 — Follow-ups rc.100/rc.101 refletidos | ✅ | rc.101 vivo em homolog; correção do `POST /api/login` que não devolvia `id` presente; pílula "Avaliar" testada |

### §2 — Modelo + imutabilidade + unicidade (STORY-085)

| Item | Status | Evidência |
|---|---|---|
| 2.1 — Migração reversível | ✅ | Migração `2026_06_09_120000_create_avaliacoes_table.php`; `AvaliacaoSchemaTest` + rollback/migrate na suíte (1082 verde) |
| 2.2 — Unicidade 1/direção/turno | ✅ | `AvaliacaoSchemaTest`; reenvio → 409 em `RegistrarAvaliacaoTest` |
| 2.3 — CHECK estrelas 1–5 + autor≠avaliado | ✅ | `AvaliacaoSchemaTest` (schema/constraints) |
| 2.4 — Imutável; comentário em branco → null | ✅ | `RegistrarAvaliacaoTest` |

### §3 — Motor XP/score/nível (núcleo)

| Item | Status | Evidência |
|---|---|---|
| 3.1 — Tabela XP (+30/+10/+3/0/−5) | ✅ | `MotorReputacaoTest` (parametrizado por estrela) |
| 3.2 — Score média, 1 casa | ✅ | `MotorReputacaoTest` (4.0, 4.67, borda 0.0); `PerfilReputacaoTest` |
| 3.3 — Nível 500/1000/3000, high-water-mark | ✅ | `NivelProfissionalTest` + `MotorReputacaoTest` (Elite mantido com XP 25) |
| 3.4 — Idempotência do motor | ✅ | `MotorReputacaoTest` (xp2==xp1, valor exato 73) |
| 3.5 — Cobertura núcleo ≥98% | ✅ | Relatório pest: `MotorReputacao` 100%, `NivelProfissional` 100% |

### §4 — Eventos + pendência derivada

| Item | Status | Evidência |
|---|---|---|
| 4.1 — `turno_finalizado` → 2 pendências, idempotente | ✅ | `NotificarAvaliacaoPendenteTest` |
| 4.2 — Pendência derivada (sem tabela) | ✅ | `AvaliacoesPendentes{Profissional,Contratante}` 100%; ADR-019 D2 |
| 4.3 — Template `avaliacao_pendente` seedado | ✅ | Log de seed na suíte (`avaliacao_pendente_email` sha256); `NotificacoesEmailTemplatesSeederTest` |

### §5 — Gate bloqueante (STORY-086)

| Item | Status | Evidência |
|---|---|---|
| 5.1 — Profissional bloqueado ao candidatar + turno_id | ✅ | `GateAvaliacaoTest`; **ao vivo homolog** `pode_candidatar=False` (A.4) |
| 5.2 — Contratante bloqueado ao publicar; editar/cancelar não | ✅ | `GateAvaliacaoTest` |
| 5.3 — Sem pendência, flui (sem regressão) | ✅ | `GateAvaliacaoTest` + suíte W26/W28 verde |
| 5.4 — Fail-secure | ✅ | `GateAvaliacaoFailSecureTest` (query que lança → bloqueia) |
| 5.5 — RBAC preservado | ✅ | `RegistrarAvaliacaoTest` (não-participante 403); `TurnosListaTest` (não vaza entre papéis) |

### §6 — Telas de avaliação (STORY-087)

| Item | Status | Evidência |
|---|---|---|
| 6.1 — Tela prof→contratante, estrela obrigatória | ✅ | `avaliar_turno_screen_test` (na suíte webapp verde) |
| 6.2 — Tela contratante→prof | ✅ | `avaliar_turno_screen_test` |
| 6.3 — No shell, responsiva, alcançável sem rota | ✅ | `turno_detalhe_screen_test` (CTA); `TurnoDetalheTest` (bloco `avaliacao`) |
| 6.4 — Erro recuperável; CTA some pós-envio | ✅ | `avaliar_turno_screen_test` + `turno_detalhe_screen_test` |
| 6.5 — RBAC fail-secure no front (403/404) | ✅ | `avaliar_turno_screen_test` + `avaliar_turno_service_test` |

### §7 — Perfil score/nível/XP/depoimentos (STORY-088 / DDR-004)

| Item | Status | Evidência |
|---|---|---|
| 7.1 — Perfil profissional completo | ✅ | `perfil_screen_test`; **ao vivo** score=4.7/Iniciante/6 turnos + depoimentos (A.3) |
| 7.2 — Perfil contratante (score+depoimentos, sem nível) | ✅ | `perfil_reputacao_service_test`; **ao vivo** score=4.7 sem nível (A.3) |
| 7.3 — Assimetria LGPD (nominal×anônimo) | ✅ | `PerfilReputacaoTest`; **ao vivo** nominal "Cantina da Praça" vs `autor_nome=None` (A.3) |
| 7.4 — XP só para o dono | ✅ | `PerfilReputacaoTest` |
| 7.5 — Estados vazio/erro/loading + selo Novo | ✅ | `perfil_screen_test` |

### §8 — UX do gate (STORY-088)

| Item | Status | Evidência |
|---|---|---|
| 8.1 — Mensagem + saída para turno pendente | ✅ | `candidatura_flow_test`/`vaga_detalhe_screen_test`; E2E `reputacao_e_gate` (A.5) |
| 8.2 — Reativo deep-link / proativo → Turnos | ✅ | `feed_screen_test`/`publicar_vaga_screen_test` |
| 8.3 — Pílula "Avaliar" na lista (rc.101) | ✅ | `TurnosListaTest` (avaliacao_pendente); **ao vivo** flag True em 3 turnos (A.4) |

### §9 — Ciclo ponta a ponta em homologação (métrica primária)

| Item | Status | Evidência |
|---|---|---|
| 9.1 — Turno finalizado → pendência dupla | ✅ | **Homolog**: 3 turnos `avaliacao_pendente=True` (lado profissional) (A.4) |
| 9.2 — Avaliação dupla aceita | ✅ | **Homolog**: submissão profissional→contratante HTTP 201×3 (A.4); depoimentos nominais/anônimos já presentes (A.3) |
| 9.3 — XP/score/nível recomputam; nível ≤1s | ✅ (ressalva) | **Homolog**: perfil reflete score/nível recomputados (A.3); recompute síncrono na transação. Latência ≤1s não cronometrada isoladamente — inferida do modelo síncrono + leitura sem cache |
| 9.4 — Score recíproco + depoimentos no perfil | ✅ | **Homolog**: A.3 (ambos os lados) |
| 9.5 — Gate fecha e destrava | ✅ | **Homolog**: `pode_candidatar` False→(avalia)→True (A.4) |
| 9.6 — Métrica primária (100% geram avaliação) | ✅ | **Homolog**: 3/3 turnos pendentes do profissional avaliados nesta validação (A.4) |

### §10 — Cobertura + suíte verde

| Item | Status | Evidência |
|---|---|---|
| 10.1 — api ≥80% novo / ≥98% núcleo | ✅ | `make test-api`: Total 94.6%; núcleo 100% |
| 10.2 — webapp ≥80% + críticas | ✅ | `make test-webapp`: "All tests passed!" (≈737) |
| 10.3 — admin ≥80% | 🚫 n/a | Épico não toca o admin (sem código de avaliação/reputação em `apps/admin`); deploy do admin é co-deploy |
| 10.4 — Suíte completa verde | ✅ | api **1082 passed** (6470 assertions); webapp verde |

### §11 — E2E browser real

| Item | Status | Evidência |
|---|---|---|
| 11.1 — E2E avaliar_turno por papel | ✅ | `web_test.dart` (entrypoint canônico, incl. `turnos/avaliar_turno`): **"All tests passed." exit 0** (A.6) |
| 11.2 — E2E perfil + gate | ✅ | `…perfil_test.dart`: **"All tests passed."** same-origin, Chrome pinado 148 (A.5) |
| 11.3 — 0-flake na run | ✅ | perfil_test + web_test cada um 1 run verde (A.5/A.6) |
| 11.4 — Smoke HTTP pós-deploy verde | ✅ | rc.101 Release: "Smoke pós-deploy (homolog)" ✓ (A.7) |

### §12 — Automação + deploy

| Item | Status | Evidência |
|---|---|---|
| 12.1 — `make setup` offline | ✅ (ressalva) | Não re-executado do zero nesta validação; ambiente local já provisionado rodou suítes/E2E offline. Sem regressão observada |
| 12.2 — Pipeline CI verde na main | ❌ | **F-B-1** — CI vermelho desde rc.101 (A.8) |
| 12.3 — Deploy homolog por tag; produção gated | ✅ | rc.101 Release todos os jobs ✓; produção pulada (gate humano) (A.7) |

### §13 — RBAC + segurança

| Item | Status | Evidência |
|---|---|---|
| 13.1 — Só participante avalia (403) | ✅ | `RegistrarAvaliacaoTest` |
| 13.2 — Não vaza turno alheio | ✅ | `TurnosListaTest`/`GateAvaliacaoTest`; **homolog** turnos escopados ao usuário |
| 13.3 — Scanner CI sem crítico novo | ✅ (ressalva) | gitleaks ✓ verde; Trivy/Container scan **pulado** nos últimos runs por depender do job de lint que falha (consequência de F-B-1) — não verificável no HEAD atual |

### §14 — LGPD + dados pessoais

| Item | Status | Evidência |
|---|---|---|
| 14.1 — Assimetria de depoimentos (DDR-004) | ✅ | `PerfilReputacaoTest`; **homolog** nominal×anônimo (A.3) |
| 14.2 — Sem PII em erro do gate/log | ✅ | Mensagens do gate genéricas ("Avalie seu último turno…"); sem id sensível |
| 14.3 — Migrações testadas e reversíveis | ✅ | §2.1 + migrate+seed (homolog) ✓ no rc.101 |

### §15 — Documentação

| Item | Status | Evidência |
|---|---|---|
| 15.1 — ADR-019 + DDR-004 `accepted` | ✅ | `index.json`: ADR-019, DDR-004, IDR-021 `accepted` |
| 15.2 — IDRs indexados | ✅ | IDR-021 `accepted` |
| 15.3 — Notas do agente preenchidas | ✅ | 085–088 com plano/decisões/descobertas/mapa CA→teste |
| 15.4 — README/runbook | 🚫 n/a | Épico não exigiu mudança de runbook (sem novo passo operacional) |

---

## Fails identificados

### Bloqueantes

#### F-B-1 — Pipeline CI vermelho na `main` (violação de estilo Pint em arquivo de teste)
- **Bloco**: §12.2 (e consequências em §13.3).
- **Critério esperado**: "Pipeline CI verde no branch principal nos deploys do épico."
- **O que verifiquei**:
  - `gh run list --workflow=CI --branch=main`: os 4 runs mais recentes estão `failure` — desde `feat(STORY-088): marca turnos pendentes de avaliação na lista` (follow-up rc.101); os runs anteriores estavam `success`.
  - Passo que falha: **"Lint (Pint — check mode)"** do app api → `433 files, 1 style issue` → `⨯ tests/Feature/Turno/TurnosListaTest.php fully_qualified_strict_types, ordered_imports`.
  - **Reproduzido localmente** no HEAD `3e25b14` (== origin/main): `docker compose exec -T api ./vendor/bin/pint --test` → `FAIL … 1 style issue` no mesmo arquivo.
  - Origem: commit `14e23e5` (rc.101) introduziu uso inline de `\App\Models\Avaliacao::factory()` (linhas 194 e 217) em vez de `use App\Models\Avaliacao;`.
- **Classificação**: **bloqueante** — `verdict-criteria.md`: "Pipeline está vermelho" é condição objetiva de fail bloqueante. Natureza factual adicional: é regra de **estilo** (não falha de teste/funcional); a suíte api passa (1082 verde) e o **deploy é verde** (workflow Release separado, rc.101 vivo). O vermelho persistente, porém, degrada o gate de qualidade da `main` e mascara futuras falhas reais sob o vermelho preexistente.
- **Evidência**: A.8.

### Não-bloqueantes

Nenhum.

---

## Passes com ressalva

- **§9.3** — Subida de nível reflete via recompute síncrono e leitura sem cache (verificado ao vivo que o perfil reflete os valores recomputados); a latência ≤1s **não foi cronometrada isoladamente** — é inferida do desenho síncrono na transação, não medida com timestamp dedicado.
- **§12.1** — `make setup` em máquina limpa **não foi re-executado** nesta validação; o ambiente local pré-existente rodou suítes e E2E offline sem regressão, mas o "um comando do zero" não foi re-provado nesta sessão.
- **§13.3** — gitleaks verde, porém **Trivy/Container scan está sendo pulado** nos runs recentes por depender do job de lint que falha (efeito colateral de F-B-1); logo, a varredura de container não é verificável no estado atual da `main`.

---

## Limitações da validação

- **Régua de homolog = banco/endpoint via API** (reference `e2e_homolog_asserir_via_api`), não Cloud Logging. O ciclo vivo foi exercitado no nível de API (Sanctum SPA stateful contra o Cloud Run de homolog), não percorrendo a UI manualmente no browser em homolog.
- **Mutação controlada em homolog**: para fechar a métrica primária (§9.5/9.6), submeti as 3 avaliações pendentes do profissional (HTTP 201) — isso consumiu a massa pendente seedada e adicionou 3 avaliações 5★ à reputação do contratante de teste. É reversível pelo re-seed do próximo deploy (job "Migrar + seed"). Não dispara e-mail (o e-mail de pendência ocorre no `turno_finalizado`, já consumido no seed).
- **Latência de subida de nível (§9.3)** não cronometrada isoladamente — ver ressalva.
- **Observação de consistência de índice**: o épico está com `status: ready` no `index.json` (não `in_review`). O workflow do validador espera `in_review`; como todas as estórias 083–088 estão `done` e o checklist existe, prossegui. Fato neutro registrado — a transição de status é decisão do PO.

---

## Apêndice A — Evidências detalhadas

### A.1 — Arquivos de teste do épico (existência)
`apps/api/tests/{Feature,Unit}/Avaliacao/` — `AvaliacaoSchemaTest`, `RegistrarAvaliacaoTest`, `GateAvaliacaoTest`, `NotificarAvaliacaoPendenteTest`, `PerfilReputacaoTest`, `MotorReputacaoTest`, `NivelProfissionalTest`, `RecalcularReputacaoListenerTest`, `GateAvaliacaoFailSecureTest`. webapp: `avaliar_turno_screen_test`, `avaliar_turno_service_test`, `perfil_screen_test`, `perfil_reputacao_service_test`, `reputacao_views_test`, `rating_input_test`; integration_test `turnos/avaliar_turno_test.dart`, `perfil/reputacao_e_gate_test.dart`.

### A.2 — Força de asserção (amostragem)
- `MotorReputacaoTest`: score média 4.67; high-water-mark (Elite mantido com XP 25); idempotência (xp2==xp1==73); bordas (lista vazia 0.0, sem profile no-op).
- `GateAvaliacaoFailSecureTest`: query que lança exceção → `bloqueado=true` / `podeCandidatar=false`.
- `PerfilReputacaoTest`: depoimento sobre profissional nominal ("Restaurante do Zé") × sobre contratante anônimo.

### A.3 — Smoke de avaliação recíproca em homolog (perfil + LGPD)
`scripts/story085-homolog-smoke.sh` contra `turni-api-homolog-…run.app` (Origin app.homolog). Profissional: `score=4.7 nivel=Iniciante turnos=6` + depoimentos nominais ("Cantina da Praça"). Contratante: `score=4.7` + depoimentos `autor_nome=None` (anônimo — LGPD).

### A.4 — Ciclo do gate ao vivo (métrica primária)
Login `profissional.avaliacao@turni.local` (HTTP 200). `GET /api/profissional/turnos`: 3 turnos `finalizado` com `avaliacao_pendente=True`. `GET /api/feed`: `pode_candidatar=False` (ANTES). `POST /api/turnos/{id}/avaliar` (5★) nos 3 → HTTP **201/201/201**. `GET /api/feed`: `pode_candidatar=True` (DEPOIS). → gate bloqueia e destrava ao avaliar.

### A.5 — E2E perfil + gate (browser real)
`make e2e-webapp-pinned E2E_TARGET=integration_test/perfil_test.dart` (Chrome-for-Testing 148, same-origin, proxy reverso): seed `AvaliacaoSeeder` + **"All tests passed."**

### A.6 — E2E avaliar_turno (browser real)
Tentativa 1 (`E2E_TARGET=integration_test/turnos_test.dart`) **inválida**: o entrypoint `turnos_test.dart` e seus leaves (incl. `turnos/avaliar_turno_test.dart`) **não inicializam o binding** (`IntegrationTestWidgetsFlutterBinding.ensureInitialized` ausente em todo `turnos/`); standalone trava em "Debug service listening…" sem progresso (gotcha `e2e_binding_init_entrypoint`). Run abortado. Re-executado pelo entrypoint canônico `E2E_TARGET=integration_test/web_test.dart` (inicializa o binding via auth/app_shell antes de `turnos.main()` → `avaliar_turno`): **"All tests passed." / exit 0** (suíte completa same-origin, Chrome pinado 148). Observação: o runner `-d web-server` não emite progresso por-teste no stdout (vai ao console do browser); só o sumário final — distinto do hang do standalone, que para em "Debug service listening" sem terminar.

### A.7 — Release rc.101 (deploy homolog)
`gh run view 27240552466`: Build api/admin/web ✓, Migrar+seed (homolog) ✓, Deploy WebApp/API/Admin → homolog ✓, **Smoke pós-deploy (homolog) ✓**, Deploy → PRODUÇÃO pulado (gate humano). `version.json` da WebApp homolog = `v0.1.0-rc.101`.

### A.8 — CI vermelho na main (F-B-1)
`gh run view 27241489911` (e 3 runs anteriores): job "PHP lint & audit (api)" → "Lint (Pint — check mode)" exit 1; `433 files, 1 style issue`; `⨯ tests/Feature/Turno/TurnosListaTest.php fully_qualified_strict_types, ordered_imports`. Reprodução local (HEAD `3e25b14`): `docker compose exec -T api ./vendor/bin/pint --test` → mesmo FAIL. Primeiro run vermelho: `feat(STORY-088): marca turnos pendentes…` (CI 27240458232); commits anteriores verdes.

---

## Histórico

- 2026-06-09 — relatório inicial submetido por validador (claude-opus-4-8). Veredito: REJECTED (1 fail bloqueante: F-B-1).
