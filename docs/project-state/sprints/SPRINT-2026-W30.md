---
sprint_id: SPRINT-2026-W30
wave: WAVE-2026-01
status: closed  # planned | active | closed
start_date: 2026-06-09
end_date: 2026-06-10  # fechamento por goal-atingido (EPIC-004 APPROVED + STORY-082 done)
opened_at: 2026-06-09
opened_by: "PO (Alexandro / Claude)"
activated_at: 2026-06-09
activated_by: "PO (Alexandro / chat)"
soft_cap_date: 2026-07-14  # ~35 dias — épico de feature transacional (mais pesado que a pausa de UX da W29)
closure_rule: "Fechamento por goal-atingido: encerra quando STORY-083..088 estiverem `done` E STORY-089 (validador) emitir veredito em `validation/report.md` aceitável pelo PO (`approved` ou `approved_with_pending` assumido como goal-atingido). STORY-082 (deflake cronômetro + housekeeping de índice) é ortogonal — carry-forward da W29; pode iniciar imediatamente e não bloqueia o goal. A dívida de a11y do EPIC-012 fica FORA desta sprint (decisão do dono em 2026-06-09)."
goal: "Fechar o ciclo do turno com avaliação recíproca obrigatória (EPIC-004): após cada turno `finalizado`, ambos os lados são bloqueados em nova ação até avaliarem (estrelas obrigatórias + comentário opcional); XP/score/nível atualizam automaticamente; score público e depoimentos visíveis no perfil — tudo demonstrável em homologação. Decisões em ADR-019 (modelo/eventos/gate) e DDR-004 (visibilidade de depoimentos). Ortogonal: STORY-082 quita a dívida da W28/W29 (deflake do E2E de sincronia do cronômetro + housekeeping de índice IDR-028/IDR-029 + SCREEN-077)."
---

# SPRINT-2026-W30

## Objetivo do sprint

A SPRINT-2026-W29 fechou o EPIC-012 (shell de navegação + pente fino de UX) por goal-atingido em 2026-06-09 — o WebApp agora é navegavelmente coerente nos dois papéis. Honrada a "pausa de UX" entre épicos transacionais, a W30 retoma a feature de produto que estava reservada para depois: o **EPIC-004 — Avaliação recíproca e fechamento do ciclo**.

O problema que esta sprint resolve: hoje o turno termina em `finalizado` e nada acontece — não há avaliação, o XP/score não acumula, a trilha de níveis não anda e o algoritmo de match perde sua principal entrada de qualidade. A avaliação recíproca obrigatória (PDR-005) é o **gatilho que faz o produto evoluir a cada turno**: força a reflexão antes da próxima ação e alimenta a confiança bilateral. Esta sprint entrega o ciclo completo (avaliação → XP/score/nível → gate bloqueante → reputação visível) dentro do shell entregue na W29.

## Escopo e duração

- **Escopo**: **8 estórias** — EPIC-004 inteiro (2 spikes de decisão + 4 implementação + 1 validação) + STORY-082 (carry-forward W29, ortogonal). Mix: **1 S + 6 M + 1 L**.
  - A **L** (STORY-085, backend modelo+motor) é candidata a quebra de sessão: se modelo+migração+motor+eventos não couber, separar (a) modelo+migração+evento de pendência de (b) motor de XP/score/nível. Escalar ao PO **antes** de inflar (padrão W28/W29).
- **Superfícies**: API (`apps/api`) para modelo/motor/gate; WebApp Contratante (desktop) + Profissional (mobile) para telas de avaliação e perfil. Backoffice fora.
- **Duração**: aberta, **fechamento por goal-atingido**. Soft-cap em **2026-07-14** (~35 dias) como gatilho de reavaliação, não prazo — folga maior por ser feature transacional.

## Estórias incluídas

| ID        | Título                                                                                      | Épico    | Tipo           | Papel       | Tamanho | Status |
| --------- | ------------------------------------------------------------------------------------------- | -------- | -------------- | ----------- | ------- | ------ |
| STORY-083 | Spike Arquiteto — modelo + eventos + ponto do gate (ADR-019) + spec do fluxo                | EPIC-004 | spike          | arquiteto   | M       | done   |
| STORY-084 | Spike Designer — DDR-004 (depoimentos) + telas de avaliação + perfil + protótipo            | EPIC-004 | spike          | designer    | M       | done   |
| STORY-085 | Backend — modelo de avaliação + motor de XP/score + subida de nível + evento                | EPIC-004 | implementation | programador | L       | done   |
| STORY-086 | Backend — gate bloqueante (sem candidatar/publicar com avaliação pendente)                  | EPIC-004 | implementation | programador | M       | done   |
| STORY-087 | Frontend — telas de avaliação recíproca (estrelas + comentário) no shell                    | EPIC-004 | implementation | programador | M       | done   |
| STORY-088 | Frontend — perfil (score/nível/XP/depoimentos) + UX do gate bloqueante                      | EPIC-004 | implementation | programador | M       | done   |
| STORY-089 | Validação final do EPIC-004                                                                 | EPIC-004 | validation     | validador   | M       | done   |
| STORY-082 | Deflake cronômetro (F-B-1) + housekeeping índice (IDR-028/029 + SCREEN-077) — carry-forward | EPIC-003 | bugfix         | programador | S       | done   |

**Sizing total**: **1 S + 6 M + 1 L (8 estórias)**.

## Ordem de execução obrigatória

```
STORY-083 (Arquiteto — ADR-019: modelo + eventos + ponto do gate + spec do fluxo) ──┐
STORY-084 (Designer — DDR-004 + SCREENs avaliação/perfil + protótipo aprovado) ─────┤ (paralelo; ambos antes da implementação)
    │ ADR-019 accepted                                                               │ DDR-004 + protótipo "vai"
    ▼                                                                                ▼
STORY-085 (BE — modelo + motor XP/score/nível + evento de pendência)        STORY-087 (FE — telas de avaliação no shell)
    │ API viva                                                                       │ (dep 084 + 085)
    ├─► STORY-086 (BE — gate bloqueante)                                             └─► STORY-088 (FE — perfil + UX do gate)
    │                                                                                          │ (dep 087 + 085 + 086)
    └──────────────────────────────► 085..088 done ◄──────────────────────────────────────────┘
                                          ▼
                                   STORY-089 (validador — última)

STORY-082 (deflake cronômetro + housekeeping) — ORTOGONAL TOTAL, inicia a qualquer momento
```

**Por que esta ordem.** A decisão precede a implementação (lição W27/W28): ADR-019 fixa modelo/eventos/gate antes de qualquer código backend; DDR-004 + protótipo aprovado pelo humano antes de qualquer tela. Backend (085) destrava o gate (086) e alimenta o frontend (087/088). O perfil + UX do gate (088) depende das telas de captura (087) e da API (085/086). O validador (089) fecha. STORY-082 não toca nada do EPIC-004 — preenche janelas.

## Compromisso visível ao fim do sprint

**Em `app.homolog.turni.com.br` + API:**

- Após um turno `finalizado`, **profissional** vê a tela de avaliar o contratante (estrelas obrigatórias + comentário opcional) e **contratante** vê a de avaliar o profissional.
- **Profissional** tenta candidatar-se com avaliação pendente → **bloqueado** com mensagem clara + link para o turno pendente. **Contratante** idem ao publicar vaga.
- **XP/score/nível** atualizam após avaliação recebida; nível sobe automaticamente ao cruzar 500/1000/3000, visível no perfil em ≤1s.
- **Score público** (1 casa, ex. 4.9★) e **depoimentos** (até 3 mais recentes, conforme DDR-004) visíveis no perfil de profissional e contratante (reciprocidade).

**Decisões registradas:** ADR-019 (modelo de avaliação + eventos de domínio + ponto do gate), DDR-004 (visibilidade de depoimentos), `flows/avaliacao-reciproca.md`. IDR(s) eventuais de implementação.

**Dívida da W28/W29 quitada (ortogonal):** E2E de sincronia do cronômetro estável + índice reconciliado (IDR-028/IDR-029 indexados; SCREEN-STORY-077 `shipped`).

## Decisões de produto/arquitetura que entram em vigor agora

- **PDR-005** (avaliação recíproca obrigatória) — base do épico.
- **ADR-019** (a produzir na STORY-083), **DDR-004** (a produzir na STORY-084).
- **Vigentes respeitados**: ADR-015 (modelo Turno), ADR-017 (tempo real + geo), ADR-007 (RBAC), ADR-018 (UUID), DDR-001/002/003 (DS, pt-BR/24h, shell), IDR-010/011/021 (E2E).
- **Fora do MVP (do `epic.md`)**: decay de score/XP; motor de penalidade (PDR-007 — placeholder); moderação por UI; nível de contratante; push web.
- **Fora desta sprint (decisão do dono 2026-06-09)**: dívida de a11y do EPIC-012 (gate dedicado das telas pesadas + PIN/cronômetro + navegação por teclado). Permanece parqueada; candidata a estória própria em wave futura.

## Riscos identificados na abertura

| Risco | Probabilidade | Impacto | Mitigação | Owner |
|---|---|---|---|---|
| Spikes (083/084) viram gargalo de entrada — toda a implementação depende deles | alta | alto | São as primeiras e rodam em paralelo; PO prioriza a aprovação de ADR-019 e do protótipo no D1–D3; enquanto não fecham, 085+ ficam `blocked` — STORY-082 (ortogonal) preenche a janela | Arquiteto + Designer + PO |
| STORY-085 (L) estoura sessão única — modelo + migração + motor + eventos é bastante | média | médio | Gatilho de quebra documentado (modelo/evento vs motor XP/score/nível); ADR-019 entrega a decisão antes | Programador + PO |
| Idempotência do motor de XP — reprocesso de evento soma XP em dobro | média | alto | CA-5 de 085 exige idempotência por evento + testes de borda; núcleo ≥98% | Programador + Validador |
| Gate bloqueante regride candidatura/publicação (W26/W28) ou vaza entre papéis | baixa | alto | CA fail-secure + RBAC em 086; E2E cruzado herdado não pode regredir; PO verifica em homolog | Programador + Validador |
| Visibilidade de depoimentos (DDR-004) é decisão sensível (privacidade do autor) | média | médio | Decisão explícita do Designer com aprovação do humano; spec já sugere baseline (estabelecimento sim, autor individual não) | Designer + PO |
| STORY-082 (deflake) não estabiliza — flake estrutural de timing | média | médio | Permite re-especificar a medição (não só repetir o teste); se não estabilizar, PO renova como dívida explícita em vez de bloquear | Programador + PO |

## Acompanhamento contínuo (PO)

- **Diário (~10 min)**: olhar `index.json`; desbloquear sobretudo ADR-019 e o protótipo da STORY-084 (gargalos de entrada).
- **Mid-sprint check**: ADR-019 + DDR-004 fecharam? 085 destravou? Se 085 foi quebrada, avaliar sessão extra.
- **Antes da validação**: PO escreve `epics/EPIC-004-avaliacao-reciproca/validation/checklist.md` para a STORY-089.
- **Soft-cap check em 2026-07-14**: se goal não bateu, abrir "Mudanças no escopo" e decidir.

### Registro de acompanhamento

| Data | Check | Situação |
|---|---|---|
| 2026-06-09 | Abertura da sprint (PO) | W30 aberta logo após o fechamento da W29 (EPIC-012 done). EPIC-004 decomposto em 8 estórias (`draft`→`ready`); STORY-082 carry-forward. Próximo passo: agentes Arquiteto (STORY-083 → ADR-019) e Designer (STORY-084 → DDR-004 + protótipo) executam em paralelo; humano aprova ADR e protótipo antes da implementação. a11y do EPIC-012 fica fora por decisão do dono. |
| 2026-06-09 | STORY-087 done — frontend telas de avaliação (programador) | T1+T2 da SCREEN-084 no shell. `TurniRatingInput` (input.rating: estrela cheia/vazia por ícone não-só-cor, helper "Ruim".."Ótimo", ≥48dp); `AvaliarTurnoService` (POST avaliar → 201/409/422/403/erro); `AvaliarTurnoScreen` (copy por papel, estados loading/form/encerrado/sem-permissão/erro-carga, erro de envio recuperável que mantém o preenchido — CA-4, mobile rodapé / desktop card centrado). Rota `/turnos/:id/avaliar` + CTA "Avaliar turno" no detalhe do turno finalizado pendente (some pós-envio). **Costura BE aditiva** (sinalizada): `GET /turnos/{id}` ganha `avaliacao{pendente,direcao}` em estados avaliáveis (derivado do estado; régua das AvaliacoesPendentes*) — exigida por CA-3/CA-4; controller 91.8%, sem decisão de produto/arq. Seed E2E determinístico (`*.aval087.seed`, 1 turno finalizado resetado p/ pendente a cada seed). Testes: rating (4 cat.), service (201/409/422/403/rede/500), screen (copy por papel, bloqueio sem estrela, recuperável, 409/422/403/404, desktop), detalhe (CTA presente/ausente), `TurnoDetalheTest` (bloco avaliacao). **api 1076 verde + cobertura ≥80%; webapp 690 verde; E2E 2 papéis verdes (Chrome 148 same-origin)**; pint/analyze/format limpos. Deploy homolog **rc.98** (run 27232188315 verde: migrate+seed + 3 deploys + smoke). Descoberta indexada: entrypoint E2E top-level precisa inicializar o binding (erro recorrente). **Destrava STORY-088** (perfil + UX do gate parte daqui). |
| 2026-06-09 | STORY-086 done — gate bloqueante (programador) | Fecha o lado server do ciclo: a pendência **derivada do estado** (ADR-019 D2) agora barra ação nos dois papéis (ADR-019 D5). Profissional — `GateAvaliacao` consome `AvaliacoesPendentesProfissional::turnoPendente` (turno avaliável sem avaliação na direção dele, **mais antigo**) → 422 `gate_avaliacao` + `detalhe.turno_id` (deep-link). Contratante — `AvaliacoesPendentesContratante::para` conta a pendência real; `PublicarVagaService` aborta com `PublicacaoBloqueadaPorAvaliacao` **antes** da transação e `VagaController` traduz p/ 422 na mesma forma do gate de candidatura. **Fail-secure** nos dois (erro de consulta → bloqueia, sem `turno_id`); **sem vazamento** entre papéis/contratantes; RBAC inalterado. Não toca Editar/Cancelar vaga (gate é só sobre **publicar nova**). Suíte api **1070 verde**; código novo 100% (PublicarVagaService/GateAvaliacao/AvaliacoesPendentes*); total 94.5%; pint limpo. Deploy homolog via **rc.97** (migrate+seed + smoke pós-deploy verdes; produção pulada — gate humano). **Destrava STORY-088** (UX do gate) e STORY-089 (validação). Ajuste herdado: o teste CA-2 da STORY-050 (`CandidaturaTest`) passou a mockar `turnoPendente` e asserir `turno_id` real (contrato evoluiu). |
| 2026-06-09 | STORY-084 done — DDR-004 accepted (Designer) | Segundo gargalo de entrada resolvido — agora os **dois** spikes fecharam. DDR-004 ratificado pelo dono em chat: visibilidade de depoimentos **assimétrica** (estabelecimento nominal sobre profissional; profissional anônimo sobre contratante — LGPD) + score com **selo "Novo" até 3 avaliações** + ordenação/quantidade (3)/sem-comentário-não-é-depoimento. SCREEN-STORY-084-avaliacao-e-perfil (`ready`) cobre as 4 superfícies (2 telas de avaliação + perfil score/nível/XP/depoimentos + UX do gate) com todos os estados, dentro do shell; protótipo HTML navegável mobile/desktop. DS ganhou 6 componentes + `pattern.gate-avaliacao` (sem exceções). **Destrava STORY-087/088** (telas e perfil). Anotado para o back (085/088): contrato de leitura de depoimentos do contratante não pode trafegar nome do profissional (assimetria LGPD). Protótipo **aprovado pelo dono em 2026-06-09** (sem ajustes) — `prototype_last_validated_at` registrado. 087/088 destravadas. |
| 2026-06-09 | STORY-085 done — backend avaliação recíproca (programador) | Coração transacional do EPIC-004 entregue numa sessão (a L **não** precisou ser quebrada). Implementa ADR-019 por TDD (vermelho→verde por CA): tabela `avaliacoes` (UNIQUE direção/turno + CHECK estrelas 1–5/autor≠avaliado + índice de cobertura), `xp`→signed, `score` do contratante; `MotorReputacao` por recomputação idempotente + nível high-water-mark (núcleo **100%** de cobertura); evento `AvaliacaoRegistrada` síncrono na transação + listener do motor; `TurnoFinalizado` passa a notificar os 2 lados (`avaliacao_pendente`, pendência **derivada** — não materializada); `POST /turnos/{turno}/avaliar` (RBAC por papel, 403/422/409); `GET /perfil/{user}` (score 1 casa/nível/XP só p/ dono/depoimentos com **assimetria LGPD** da DDR-004 — anônimo sobre o contratante). Suíte completa **1052 verde**, pint limpo. Deploy homolog via **rc.92** (migração + smoke pós-deploy verdes). **Destrava STORY-086** (gate — costuras `AvaliacoesPendentes*` agora têm o modelo derivável) e alimenta 087/088. Descoberta: XP não fica negativo via avaliações no MVP (líquido por turno ≥ +25); o negativo só viria das penalidades placeholder (PDR-007). |
| 2026-06-10 | **Fechamento da sprint (PO)** | W30 encerrada por **goal-atingido**. EPIC-004 `done` (083..089, validador **APPROVED** após F-B-1 = CI vermelho por Pint sanado em `4e2dc83`/re-verificado em `355bc09`). STORY-082 (carry-forward) `done`: cronômetro deflakado 20/20 (IDR-031), índice reconciliado, checkout deflakado 7/7 (fora do gate por decisão do PO). 8/8 estórias `done`. Seção "Fechamento" preenchida. Próximo épico/sprint (W31) adiado para definição do dono. |
| 2026-06-09 | STORY-083 done — ADR-019 accepted (Arquiteto) | Primeiro gargalo de entrada resolvido. ADR-019 aprovada pelo dono em chat: tabela `avaliacoes` separada (UNIQUE por direção/turno) divergindo do esboço jsonb de turno.md; pendência derivada do estado; eventos síncronos na transação (reuso de `TurnoFinalizado` p/ notificação + novo `AvaliacaoRegistrada` p/ motor); motor de reputação por recomputação idempotente + nível high-water-mark (`xp`→signed, contratante ganha `score`, enum `NivelProfissional` recomendado); gate no service layer fail-secure reusando as costuras `AvaliacoesPendentes*` (profissional já ligado; falta ligar `PublicarVagaService`). Spec `flows/avaliacao-reciproca.md` escrita. **Destrava STORY-085/086** (que ainda dependem do protótipo da STORY-084). Risco de idempotência (motor) mitigado por construção. Próximo gargalo: aprovação do protótipo da STORY-084. |

## Mudanças no escopo do sprint

> Toda alteração no conjunto de estórias após esta abertura registra aqui, com data e motivo.

| Data | O que mudou | Motivo | Custo |
|---|---|---|---|
| — | — | — | — |

## Fechamento do sprint (preencher no encerramento)

> Encerrada em **2026-06-10** por **goal-atingido**. Condição da `closure_rule` satisfeita: STORY-083..088 `done` + STORY-089 (validador) com veredito **APPROVED**. STORY-082 (ortogonal) também concluída. 8/8 estórias `done`.

### O que foi entregue
- **EPIC-004 — Avaliação recíproca e fechamento do ciclo (goal):** após um turno `finalizado`, pendência **derivada do estado** nos dois lados; **gate bloqueante** fail-secure barra candidatar/publicar até avaliar (deep-link para o turno pendente); `MotorReputacao` recompõe **XP/score/nível** por recomputação idempotente (nível high-water-mark); perfil com score público (1 casa), nível, XP (só p/ o dono) e **depoimentos com assimetria LGPD** (nominal sobre o profissional, anônimo sobre o contratante — DDR-004) + selo "Novo" até 3 avaliações. Decisões: **ADR-019** (modelo/eventos/gate) e **DDR-004** (visibilidade) accepted; `flows/avaliacao-reciproca.md`. Vivo em homolog **rc.101**: ciclo ponta a ponta exercitado (gate bloqueando com 3 pendentes → 201×3 → gate destravando). Suíte api **1082** (cobertura 94.6%, núcleo MotorReputacao/NivelProfissional 100%), webapp **≈737**, E2E perfil+gate same-origin verde.
- **STORY-082 (carry-forward, ortogonal):** deflake do E2E de sincronia do cronômetro (F-B-1 da W28) por re-especificação da medição (**IDR-031** — skew modo-comum + diferença de medianas), **20/20** estável; `index.json` reconciliado (IDR-028/029 indexados, SCREEN-STORY-077 `shipped`, IDR-031 indexado); e, como bônus, o `checkout_test` deflakado dos 3 flakes (pendura por `pumpAndSettle`+timer, colisão de Hero do SnackBar, "PIN inválido" por seleção de card por estado sobre turnos leftover) — **7/7**, mantido FORA do gate por decisão do PO (custo).

### O que ficou para trás (e por quê)
- **Dívida de a11y do EPIC-012** (gate das telas pesadas + PIN/cronômetro + navegação por teclado) — deliberadamente **fora da W30** (decisão do dono 2026-06-09); permanece parqueada para wave futura.
- **`checkout_test` fora do gate E2E padrão** — deflakado e estável, mas custa ~2-3 min; o PO optou por mantê-lo sob demanda (gate já longo). Pronto para reativar (descomentar no `turnos_test.dart`).
- **Fora do MVP (do `epic.md`):** decay de score/XP; motor de penalidade (PDR-007 placeholder); moderação por UI; nível de contratante; push web.

### Aprendizados de produto
- **Assimetria de visibilidade de depoimentos é decisão de produto sensível** (LGPD): estabelecimento nominal sobre o profissional, profissional anônimo sobre o contratante — resolvida explicitamente na DDR-004 com aprovação do dono, não no código.
- **Pendência derivada do estado** (não materializada) provou-se suficiente para o gate e a notificação — menos uma fonte de inconsistência.

### Aprendizados de processo
- **Pipeline vermelho na `main` é bloqueante mesmo quando cosmético.** O F-B-1 da W30 foi um Pint (`fully_qualified_strict_types`/`ordered_imports`) num arquivo de teste que deixou o workflow **CI** vermelho enquanto o **Release** seguia verde (deploy subiu). A régua objetiva reprovou; lição: CI vermelho mascara falhas reais futuras — corrigir antes de fechar. (Não confundir com o F-B-1 da W28, do cronômetro.)
- **Deflake faithful > repetir o teste:** o cronômetro estabilizou re-especificando a medição (sincronia bilateral como quantidade modo-comum, IDR-031), não afrouxando tolerância.
- **Em E2E sobre par seed exclusivo, fixe o turno pelo ID, nunca por rótulo de estado.** O seeder `seedTurnoNaJanela` acumula turnos leftover; `find.ancestor(of: find.text('Em andamento'), …).first` é não-determinístico — causou o "PIN inválido" intermitente do checkout. **O audit do Postgres fechou o diagnóstico onde a leitura de código não bastou** (a 1ª hipótese — PIN efêmero — estava errada).

### Ajustes para o próximo sprint
- **W31 / próximo épico:** decisão de planejamento adiada pelo dono (a definir em outro momento). Candidata conhecida: dívida de a11y do EPIC-012.
- **Gate E2E está longo** (sinalizado pelo PO) — vale uma revisão de tempo total sem perder cobertura; a janela de amostragem do cronômetro (~60s) é o maior item.
- **Higiene do seeder (não-bloqueante):** `seedTurnoNaJanela` deixa turnos leftover em `ativo`/`aguardando_checkout` a cada run interrompido; o teste já é imune (fix por id), mas limpar/terminalizar leftovers manteria a base de teste enxuta — candidato a chore.
