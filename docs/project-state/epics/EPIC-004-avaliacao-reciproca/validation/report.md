---
epic_id: EPIC-004
type: validation-report
validated_at: 2026-06-09
validated_by: validador (claude-opus-4-8, sessão 2026-06-09)
verdict: approved
verdict_history:
  - { verdict: rejected, at: 2026-06-09, reason: "1 bloqueante F-B-1 (CI vermelho na main por Pint)" }
  - { verdict: approved, at: 2026-06-09, reason: "F-B-1 sanado em 4e2dc83; re-verificado no HEAD 355bc09 (CI verde, Pint PASS)" }
revalidated_at: 2026-06-09
checklist_source: epics/EPIC-004-avaliacao-reciproca/validation/checklist.md
---

# Relatório de Validação — EPIC-004 (avaliação recíproca e fechamento do ciclo)

## TL;DR

> **Veredito atual: APPROVED** (re-validação 2026-06-09 — ver §Revalidação e A.9).
> **Veredito inicial: REJECTED** (mesma data) — preservado abaixo como registro honesto da 1ª passada.
> **Contagem (re-validação)**: 16 itens-bloco `pass`, 2 `pass com ressalva` (§9.3, §12.1), 0 `fail`, 1 `n/a` justificado. O único bloqueante da 1ª passada (F-B-1) foi sanado pelo Programador em `4e2dc83` e **re-verificado** no HEAD `355bc09`; a ressalva §13.3 (Trivy pulado) também caiu — o container scan voltou a rodar e passou.
> **Registro da 1ª passada (factual)**: a branch principal `main` esteve com o pipeline **CI vermelho** desde o commit `feat(STORY-088): marca turnos pendentes…` (follow-up rc.101) — violação de estilo Pint (`fully_qualified_strict_types`/`ordered_imports`) em `apps/api/tests/Feature/Turno/TurnosListaTest.php`, reproduzida no então-HEAD `3e25b14`.

---

## Resumo executivo

O EPIC-004 entrega o fechamento do ciclo: após um turno `finalizado`, ambos os lados ficam com avaliação pendente, o gate bloqueia a próxima ação (candidatar/publicar) até avaliarem, e o motor recompõe XP/score/nível com depoimentos visíveis no perfil. **A funcionalidade do épico está implementada, testada e demonstrável ao vivo em homologação** — o ciclo ponta a ponta foi exercitado na própria homolog (rc.101): gate bloqueando (`pode_candidatar=False` com 3 turnos pendentes) → submissão das avaliações (HTTP 201×3) → gate destravando (`pode_candidatar=True`), com perfil mostrando score/nível/depoimentos e a assimetria LGPD (nominal sobre o profissional, anônimo sobre o contratante). A suíte api passa (1082 testes, cobertura total 94.6%, núcleo `MotorReputacao`/`NivelProfissional` 100%); a webapp passa (≈737 testes); o E2E de browser real do perfil+gate passa same-origin.

O único impedimento é de **higiene de pipeline**: a `main` está vermelha no workflow **CI** desde o follow-up rc.101 por uma violação de estilo (Pint) num arquivo de teste. O workflow de **Release/deploy** é verde e independente — por isso rc.101 subiu em homolog normalmente. A natureza do fail é cosmética (uso de `\App\Models\Avaliacao` inline em vez de `use`), mas, pela régua objetiva de `verdict-criteria.md`, **pipeline vermelho na branch principal é fail bloqueante** (entre outros motivos, mascara futuras falhas reais sob o vermelho preexistente).

---

## Revalidação (2026-06-09) — F-B-1 sanado, veredito → APPROVED

A 1ª passada reprovou o épico por **um único bloqueante**: F-B-1 (CI vermelho na `main` por violação de estilo Pint em `TurnosListaTest.php` — não-funcional). Após o relatório, o Programador corrigiu o bloqueante em `4e2dc83` (`fix(IDR-021): … corrige Pint (F-B-1)`). Esta re-validação **apenas re-verifica** o estado do bloqueante no HEAD atual (`355bc09`) — o validador não consertou nada.

**Resultado da re-verificação (evidência em A.9):**

| Item | 1ª passada | Re-validação (HEAD `355bc09`) |
|---|---|---|
| §12.2 — CI verde na `main` | ❌ F-B-1 | ✅ run `27243459408` — **10/10 jobs `success`** |
| §13.3 — Container scan (Trivy) | ⚠️ pulado (efeito de F-B-1) | ✅ Trivy api+admin **rodou e passou** |
| Pint (api) local | ❌ 1 style issue | ✅ **433 files PASS**, 0 issues |
| `TurnosListaTest` | (verde, mas Pint reprovava) | ✅ **18 passed (46 assertions)** |
| Guard anti-recorrência (webapp) | — | ✅ `All tests passed!` (novo teste do `4e2dc83`) |

Nenhum outro item do checklist foi reaberto: a funcionalidade do épico não mudou entre o relatório inicial e a correção (o `diff` de `4e2dc83` toca apenas estilo de import num teste, inicialização de binding em leaves de E2E e um teste-guard — nada de domínio). Os 14 `pass` e o `n/a` da 1ª passada seguem válidos; das 3 ressalvas, a §13.3 caiu, restando §9.3 e §12.1 (ambas não-bloqueantes).

**Veredito atualizado: APPROVED.** 0 fails. O veredito inicial `rejected` fica preservado neste documento como registro honesto da 1ª passada (`verdict_history` no front-matter).

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
| 12.2 — Pipeline CI verde na main | ✅ (re-valid.) | 1ª passada: ❌ **F-B-1** (A.8). Sanado em `4e2dc83`; HEAD `355bc09` CI **verde, 10/10 jobs success** — run `27243459408` (A.9) |
| 12.3 — Deploy homolog por tag; produção gated | ✅ | rc.101 Release todos os jobs ✓; produção pulada (gate humano) (A.7) |

### §13 — RBAC + segurança

| Item | Status | Evidência |
|---|---|---|
| 13.1 — Só participante avalia (403) | ✅ | `RegistrarAvaliacaoTest` |
| 13.2 — Não vaza turno alheio | ✅ | `TurnosListaTest`/`GateAvaliacaoTest`; **homolog** turnos escopados ao usuário |
| 13.3 — Scanner CI sem crítico novo | ✅ (re-valid.) | gitleaks ✓; com F-B-1 sanado, **Container scan (Trivy — api/admin) voltou a rodar e passou** no HEAD `355bc09` (run `27243459408`, A.9) — ressalva da 1ª passada (Trivy pulado) caiu |

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

> **Estado pós-re-validação (2026-06-09):** o único fail bloqueante (F-B-1) foi **sanado** e re-verificado — ver §Revalidação e A.9. A descrição abaixo é o registro factual da 1ª passada.

### Bloqueantes

#### F-B-1 — Pipeline CI vermelho na `main` (violação de estilo Pint em arquivo de teste) — ✅ SANADO (re-validação)
- **Bloco**: §12.2 (e consequências em §13.3).
- **Critério esperado**: "Pipeline CI verde no branch principal nos deploys do épico."
- **O que verifiquei**:
  - `gh run list --workflow=CI --branch=main`: os 4 runs mais recentes estão `failure` — desde `feat(STORY-088): marca turnos pendentes de avaliação na lista` (follow-up rc.101); os runs anteriores estavam `success`.
  - Passo que falha: **"Lint (Pint — check mode)"** do app api → `433 files, 1 style issue` → `⨯ tests/Feature/Turno/TurnosListaTest.php fully_qualified_strict_types, ordered_imports`.
  - **Reproduzido localmente** no HEAD `3e25b14` (== origin/main): `docker compose exec -T api ./vendor/bin/pint --test` → `FAIL … 1 style issue` no mesmo arquivo.
  - Origem: commit `14e23e5` (rc.101) introduziu uso inline de `\App\Models\Avaliacao::factory()` (linhas 194 e 217) em vez de `use App\Models\Avaliacao;`.
- **Classificação**: **bloqueante** — `verdict-criteria.md`: "Pipeline está vermelho" é condição objetiva de fail bloqueante. Natureza factual adicional: é regra de **estilo** (não falha de teste/funcional); a suíte api passa (1082 verde) e o **deploy é verde** (workflow Release separado, rc.101 vivo). O vermelho persistente, porém, degrada o gate de qualidade da `main` e mascara futuras falhas reais sob o vermelho preexistente.
- **Evidência**: A.8.
- **Sanado (re-validação 2026-06-09)**: Programador corrigiu em `4e2dc83` (`use App\Models\Avaliacao;` substituindo o uso inline). Re-verificado no HEAD `355bc09`: `pint --test` (api) → **433 files PASS, 0 issues**; `TurnosListaTest` → **18 passed (46 assertions)**; CI da `main` **verde, 10/10 jobs** (run `27243459408`). Detalhe em **A.9**.

### Não-bloqueantes

Nenhum.

---

## Passes com ressalva

- **§9.3** — Subida de nível reflete via recompute síncrono e leitura sem cache (verificado ao vivo que o perfil reflete os valores recomputados); a latência ≤1s **não foi cronometrada isoladamente** — é inferida do desenho síncrono na transação, não medida com timestamp dedicado.
- **§12.1** — `make setup` em máquina limpa **não foi re-executado** nesta validação; o ambiente local pré-existente rodou suítes e E2E offline sem regressão, mas o "um comando do zero" não foi re-provado nesta sessão.
- **§13.3** — *(1ª passada)* gitleaks verde, porém **Trivy/Container scan pulado** por depender do job de lint que falha (efeito colateral de F-B-1). **Resolvido na re-validação**: com F-B-1 sanado, o Container scan (Trivy — api/admin) voltou a rodar e passou no HEAD `355bc09` (A.9) — não é mais ressalva.

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

### A.9 — Re-verificação do F-B-1 (re-validação 2026-06-09, HEAD `355bc09`)
Correção do Programador em `4e2dc83` (`fix(IDR-021): … corrige Pint (F-B-1)`): troca o uso inline de `\App\Models\Avaliacao` por `use App\Models\Avaliacao;` em `TurnosListaTest.php` (mudança de estilo, semanticamente idêntica), além de inicializar o binding nos leaves de `integration_test/turnos/` + um guard anti-recorrência (IDR-021).
- **CI da `main` no HEAD `355bc09`** (`gh run view 27243459408`): **10/10 jobs `success`** — Secret scan (gitleaks), PHP lint & audit (api), PHP lint & audit (admin), Commit lint, Flutter lint & analyze, Smoke build (api/admin/Flutter web), **Container scan (Trivy — api)**, **Container scan (Trivy — admin)**. O run imediatamente anterior verde é exatamente `fix(IDR-021): … corrige Pint (F-B-1)` (`27243201697`); o último run vermelho foi o relatório inicial (`27242718028`), onde "PHP lint & audit (api)" = `failure` e Smoke build/Container scan = `skipped`.
- **Local (HEAD)** — `docker compose run --rm --no-deps api ./vendor/bin/pint --test` → `PASS — 433 files`, 0 style issues.
- **Local (HEAD)** — `pest tests/Feature/Turno/TurnosListaTest.php` → `PASS … 18 passed (46 assertions)`.
- **Local (HEAD)** — webapp `flutter test test/integration_test_binding_guard_test.dart` (guard que assegura `ensureInitialized` em todo leaf de `integration_test/`) → `All tests passed!`.

---

## Histórico

- 2026-06-09 — relatório inicial submetido por validador (claude-opus-4-8). Veredito: REJECTED (1 fail bloqueante: F-B-1).
- 2026-06-09 — **re-validação** (validador, claude-opus-4-8). F-B-1 sanado pelo Programador em `4e2dc83`; re-verificado no HEAD `355bc09` (CI verde 10/10, Pint PASS, testes verdes — A.9). Ressalva §13.3 (Trivy pulado) caiu. **Veredito atualizado: APPROVED** (0 fails; 2 ressalvas remanescentes §9.3/§12.1, ambas não-bloqueantes). Sem conserto pelo validador — apenas re-verificação com evidência.
