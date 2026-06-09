---
story_id: STORY-085
slug: backend-modelo-motor-xp-score-nivel
title: "Backend — modelo de avaliação + motor de XP/score + subida de nível + evento de pendência"
epic_id: EPIC-004
sprint_id: SPRINT-2026-W30
type: implementation
target_role: programador
requires_design: false
design_screen_id: null
status: done
owner_agent: claude-opus-4-8-programador-2026-06-09
created_at: 2026-06-09
updated_at: 2026-06-09
estimated_session_size: L
produces_idr: null
---

# STORY-085 — Backend: modelo de avaliação + motor de XP/score/nível

> **Para o agente que vai executar:** leia a estória inteira. Implementa **ADR-019** (STORY-083). TDD: vermelho antes de verde. Migração reversível.

## Contexto (por que esta estória existe)

É o coração transacional do EPIC-004: persistir a avaliação recíproca e fazer o motor de XP/score/nível andar a cada evento. Sem isso, o ciclo do turno não fecha e a reputação não evolui.

- Decisão: ADR-019 (modelo, eventos, idempotência do motor).
- Spec: `domain/niveis-e-score.md` (tabela de XP, limites de nível 500/1000/3000, score como média com leve viés recente), `flows/avaliacao-reciproca.md`.

## O quê (objetivo desta estória)

- Migração + modelo de **avaliação** (estrelas 1–5 obrigatória, comentário opcional, direção, linkage com turno, timestamps; unicidade 1 por direção/turno) conforme ADR-019.
- Evento **`turno_finalizado`** cria as **duas pendências** de avaliação (uma por direção).
- Endpoint(s) de API para **submeter avaliação** (autenticado, RBAC, valida estrelas obrigatórias, idempotente por direção/turno).
- **Motor de XP/score/nível**: ao `avaliacao_recebida`, recalcula XP (tabela da spec), score (média com leve viés recente) e **sobe nível automaticamente** ao cruzar 500/1000/3000; XP pode ficar negativo sem rebaixar.
- Expor no perfil (API) score, nível, XP atual e XP até o próximo nível; depoimentos (comentários não-vazios) por direção.

## Por quê (valor para o usuário)

Faz a avaliação virar progressão real: XP sobe, nível sobe, score público atualiza — a evolução do produto a cada turno.

## Critérios de aceite

- [x] **CA-1:** Migração reversível cria o modelo de avaliação conforme ADR-019; unicidade 1 avaliação por direção/turno (tentativa duplicada rejeitada). — `AvaliacaoSchemaTest` + rollback/migrate verificados.
- [x] **CA-2:** `turno_finalizado` gera as 2 pendências de avaliação (idempotente — reprocessar não duplica). — pendência **derivada** (ADR-019 D2); listener notifica os 2 lados. `NotificarAvaliacaoPendenteTest`.
- [x] **CA-3:** Submeter avaliação valida estrelas obrigatórias (1–5), comentário opcional, RBAC (só quem participou do turno avalia, na direção correta), e persiste imutável. — `RegistrarAvaliacaoTest`.
- [x] **CA-4:** `avaliacao_recebida` recalcula XP conforme a tabela da spec (turno +30; 5★ +10; 4★ +3; 3★ 0; 1–2★ −5) e atualiza score (média; viés de recência é hook fora do MVP — ADR-019). — `MotorReputacaoTest`.
- [x] **CA-5:** Nível sobe automaticamente ao cruzar 500/1000/3000; XP negativo não rebaixa (spec). Idempotência: reprocessar o mesmo evento não soma XP em dobro. — `MotorReputacaoTest` + `NivelProfissionalTest`.
- [x] **CA-6:** API do perfil expõe score (1 casa), nível, XP atual, XP até o próximo nível e depoimentos por direção (comentário não-vazio, mais recentes primeiro; assimetria LGPD da DDR-004). — `PerfilReputacaoTest`.
- [x] **CA-7:** Cobertura ≥ 80% no código novo; **núcleo ≥ 98%** (MotorReputacao + NivelProfissional **100%**). Suíte completa **1052 verde**.
- [x] **CA-8:** Deploy homologação verificado — release `v0.1.0-rc.92`: jobs "Migrar + seed (homolog)" e "Smoke pós-deploy (homolog)" verdes.

## Fora de escopo

- Gate bloqueante (STORY-086). Telas (STORY-087/088). Motor de penalidade/decay (PDR-007).

## Padrões de qualidade exigidos

`quality-standards.md`. ≥80% geral / ≥98% núcleo; migração reversível e testada; TDD; sem PII em log.

## Dependências

- **Bloqueada por:** STORY-083 (ADR-019 `accepted`).
- **Bloqueia:** STORY-086 (gate consulta pendência), STORY-087/088 (telas consomem API), STORY-089 (validação).

## Decisões já tomadas (não as reabra)

- ADR-019, ADR-015 (Turno), ADR-007 (RBAC), ADR-018 (UUID), PDR-005. Valores de XP da spec (ajustáveis em operação — o que importa é o motor existir).

## Liberdade técnica do agente

Decide: estrutura do service/motor, listeners, design dos testes, forma do cálculo do viés recente (dentro da spec). NÃO decide: campos do modelo (ADR-019), valores de XP/limites (spec), CAs.

## Definição de Pronto (DoD)

- [x] CAs passam; testes verdes; cobertura atingida; migração reversível.
- [x] Pipeline verde; deploy homolog verificado (rc.92).
- [x] `index.json` atualizado: status = `done`. "Notas do agente" preenchida.

## Protocolo do agente (obrigatório)

`docs/skills/po/references/agent-task-format.md` + skill `programador`.

## Notas do agente (preenchido durante/após execução)

### Entrada inicial (2026-06-09, programador) — leitura + plano antes de codar

**Documentos lidos:** estória inteira; ADR-019 (5 decisões — blueprint direto); `domain/niveis-e-score.md` (tabela XP, limiares 500/1000/3000, "sobe nunca desce", reciprocidade); `flows/avaliacao-reciproca.md`; SPRINT-2026-W30 (nota de quebra da L no boundary `AvaliacaoRegistrada`; anotação LGPD da DDR-004: leitura de depoimentos do contratante NÃO trafega nome do profissional — assimetria); skill `programador` + `agent-task-format.md`. Código existente: stubs `AvaliacoesPendentes{Profissional,Contratante}`, evento `TurnoFinalizado` + `NotificarTurnoFinalizado`/`TurnoFinalizadoListener`, `AppServiceProvider` (discovery off, registro explícito), `NotificarEventoTurnoService`/`NotificacaoTipo`, migração `turnos` (enum nativo + trigger + down simétrico), `create_profissional_profiles` (xp `unsignedInteger`, score decimal(5,2), nivel string), `ValidarCheckoutService` (transação + dispatch pós-commit), `ValidarCheckoutController` (RBAC + `$request->validate`), `TurnoFactory`/`ProfissionalProfileFactory`, `User` (isProfissional/isContratante).

**Entendimento consolidado (minhas palavras):** preciso (1) criar o agregado `avaliacoes` (1 linha/direção/turno, UNIQUE(turno_id,direcao), CHECK estrelas 1–5 + autor≠avaliado, índice de cobertura (avaliado_id, created_at DESC)); (2) endpoint de submissão (RBAC: só quem participou do turno, na direção certa; estrelas obrigatórias; idempotente por UNIQUE; insere + dispara `AvaliacaoRegistrada` na transação); (3) `MotorReputacao` que **recomputa do zero** a reputação do avaliado (score = média das estrelas recebidas; xp = 30×turnos_realizados + Σ bônus por estrela; nível = high-water-mark) — idempotente por construção; (4) listener novo em `TurnoFinalizado` notificando os DOIS lados ("avalie seu turno"); (5) API de perfil expondo score/nível/xp/xp-até-próximo + depoimentos por direção. Pendência é **derivada** (não há tabela). Schema: `xp` vira `integer` signed; `contratante_profiles` ganha `score`.

**Dúvidas:** nenhuma bloqueante — ADR-019 fixa todas as decisões de modelo/motor/eventos; valores de XP e média-simples-sem-viés já decididos na ADR (viés de recência é hook fora do MVP).

**Decisões locais que vou tomar (dentro da latitude do programador):** enum `App\Enums\NivelProfissional` dono dos limiares + `nivelPara()` + ordem p/ o `max`; enum `App\Enums\AvaliacaoDirecao`; service `RegistrarAvaliacaoService`; `MotorReputacao` como domain service puro (sem relógio); novos `NotificacaoTipo` (`avaliacao_pendente`, `avaliacao_recebida`). Notificação "subiu de nível" e e-mail de "você foi avaliado" ficam fora do caminho crítico (avalio se cabe).

**Plano (TDD, ordem):**
1. Migração `avaliacoes` (enum direção + tabela + constraints + índices) + ALTER `xp`→integer + ADD `contratante_profiles.score`. Teste de schema/constraints PRIMEIRO (vermelho).
2. Model `Avaliacao` + `AvaliacaoFactory` + enums `AvaliacaoDirecao`/`NivelProfissional`.
3. `MotorReputacao` (núcleo ≥98%) — unit: feliz, bordas (limiares, xp negativo não rebaixa, 1–2★), idempotência (reprocesso não dobra).
4. Evento `AvaliacaoRegistrada` + `RecalcularReputacaoListener` (registro no AppServiceProvider).
5. `RegistrarAvaliacaoService` + FormRequest + Controller + rota (feature: feliz, RBAC, direção errada, estrela inválida, duplicata).
6. Listener `NotificarAvaliacaoPendente` em `TurnoFinalizado` (2 lados, idempotente) + novos `NotificacaoTipo`.
7. API perfil (score/nível/xp/xp-até-próximo + depoimentos por direção; assimetria LGPD na leitura do contratante).
8. Suíte completa verde + pint + análise; deploy homolog.

**Mapeamento CA → teste (planejado):**
- CA-1 (modelo/UNIQUE/CHECK) → `AvaliacaoSchemaTest` (migração cria; rejeita 2ª na mesma direção; estrela fora 1–5; autor=avaliado) + `migrate:fresh`/`rollback`.
- CA-2 (TurnoFinalizado → 2 notificações, idempotente) → `NotificarAvaliacaoPendenteTest` (2 lados; reprocesso não duplica).
- CA-3 (submit valida estrelas/RBAC/direção/imutável-por-unique) → `RegistrarAvaliacaoTest` (feliz; sem estrelas; estrela fora faixa; não-participante 403; direção errada; duplicata rejeitada).
- CA-4 (XP/score por avaliacao_recebida) → `MotorReputacaoTest` (tabela XP: 5★/4★/3★/1–2★; score = média) + `RecalcularReputacaoListenerTest`.
- CA-5 (nível sobe 500/1000/3000; xp negativo não rebaixa; idempotente) → `MotorReputacaoTest` (limiares; high-water-mark; reprocesso idempotente) + `NivelProfissionalTest`.
- CA-6 (perfil expõe score 1 casa/nível/xp/xp-até-próximo + depoimentos por direção) → `PerfilReputacaoTest` (campos; depoimentos só comentário não-vazio, mais recentes 1º; assimetria LGPD).
- CA-7 (cobertura ≥80% geral / ≥98% núcleo) → relatório pest --coverage.
- CA-8 (deploy homolog) → smoke pós-push.

### Decisões / Descobertas / Bloqueios

**Decisões locais (dentro da latitude do programador):**
- Enum `App\Enums\NivelProfissional` (limiares + `nivelPara` + `ordem`/`maiorEntre` + `xpAteProximoNivel`) e `App\Enums\AvaliacaoDirecao` (espelha o enum nativo `avaliacao_direcao`).
- `MotorReputacao` como domain service puro (sem relógio); `RegistrarAvaliacaoService` (insere + dispara `AvaliacaoRegistrada` **dentro** da transação — ADR-019 D3); `PerfilReputacaoQuery` monta o payload de reputação.
- Exceções de domínio (`TurnoNaoAvaliavelException` 422, `NaoParticipanteDoTurnoException` 403, `AvaliacaoJaRegistradaException` 409). Mapeadas no controller.
- Submit num único endpoint compartilhado `POST /turnos/{turno}/avaliar` — direção/avaliado **derivados do papel do autor** no turno (fonte única de RBAC; não duplico checagem no controller).
- Perfil em `GET /perfil/{user}`: **XP só para o dono** (visibilidade — niveis-e-score.md); demais campos públicos. Score exibido com 1 casa; depoimentos limitados a 3 (DDR-004); selo `Novo` < 3 avaliações.
- Novo `NotificacaoTipo::AvaliacaoPendente` + template seed vendorado (`database/seeders/emails/avaliacao_pendente_email.md`) — segue o padrão STORY-067.
- Guard defensivo no motor: profissional sem profile = no-op (não derruba a transação por uma denormalização). Listener defensivo: avaliado/turno desconhecido = no-op.

**Descobertas:**
- **XP não fica negativo via avaliações no MVP**: cada avaliação recebida vem de um turno finalizado (+30) e o pior bônus é −5 (1–2★), logo o líquido por turno é ≥ +25. O negativo só viria das penalidades placeholder (cancelamento/no-show — PDR-007, fora do MVP). O que o CA-5 exige do motor é a coluna **signed tolerante** (coberta por `NivelProfissional::nivelPara(-50)`) e o **high-water-mark** que não rebaixa — ambos testados.
- `unsignedInteger` no Postgres já é `integer` (sem unsigned nativo); a migração de tipo é semanticamente um no-op no PG, mantida para documentar intenção e portabilidade.
- `created_at` não é fillable em `Avaliacao` — testes que precisam datar depoimentos setam o atributo direto + `save()` (bypassa mass-assignment).
- O `NotificacaoTurnoEmailWiringTest` (STORY-067) passou a renderizar também o e-mail `avaliacao_pendente` (trava do contrato payload⇆template) — contagens ajustadas 9→11 notificações / 8→9 tipos.

**Mapeamento CA → teste (final, todos verdes):**
- **CA-1** → `tests/Feature/Avaliacao/AvaliacaoSchemaTest.php` (UNIQUE direção/turno; CHECK estrelas 1–5; NOT NULL; CHECK autor≠avaliado; UUIDv7; relations) + migração reversível verificada (`migrate:rollback`/`migrate`).
- **CA-2** → `tests/Feature/Avaliacao/NotificarAvaliacaoPendenteTest.php` (2 lados; idempotente; chave por destinatário; turno desconhecido no-op) + `NotificacoesEmailTemplatesSeederTest` (13→14).
- **CA-3** → `tests/Feature/Avaliacao/RegistrarAvaliacaoTest.php` (feliz nos 2 papéis; comentário em branco→null; evento; estrelas ausente/fora-de-faixa/comentário>1000→422; não-participante→403; estado inválido→422; reenvio→409; 2 direções coexistem).
- **CA-4** → `tests/Unit/Avaliacao/MotorReputacaoTest.php` (tabela XP 5/4/3/2/1★; score=média; turnos_realizados; finalizado_ajustado) + `tests/Unit/Avaliacao/RecalcularReputacaoListenerTest.php`.
- **CA-5** → `MotorReputacaoTest` (limiar 500; high-water-mark não rebaixa; idempotência) + `tests/Unit/Avaliacao/NivelProfissionalTest.php` (limiares; xp negativo; ordem; xpAteProximoNivel).
- **CA-6** → `tests/Feature/Avaliacao/PerfilReputacaoTest.php` (score 1 casa; nível; xp + xp_proximo_nivel só p/ dono; Elite→null; depoimentos não-vazios mais recentes 1º; nominal sobre profissional / **anônimo sobre contratante — LGPD**; selo Novo).
- **CA-7** → suíte completa **1052 verde**, `--min=80` ok; núcleo `MotorReputacao` e `NivelProfissional` **100%**.
- **CA-8** → push → CI → deploy homolog (em verificação).

**Bloqueios:** nenhum.
