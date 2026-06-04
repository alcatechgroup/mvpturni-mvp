---
sprint_id: SPRINT-2026-W28
wave: WAVE-2026-01
status: active
start_date: 2026-06-03  # ativada após SPRINT-2026-W27.5 fechar por goal-atingido (EPIC-010 done, STORY-072 approved)
activated_by: "PO (Alexandro / chat)"
end_date: null
soft_cap_date: 2026-07-04  # ~31 dias corridos a partir da provável ativação; folga maior que W24/W25/W27 (21d) porque é o épico mais pesado da onda
opened_at: 2026-06-03
opened_by: "PO (Alexandro / Claude)"
blocked_by_sprint: SPRINT-2026-W27.5  # ADR-018 accepted exige refator UUID antes de o EPIC-003 começar (STORY-056 Pagar.me usa external_reference apontando para IDs do Turni — janela cirúrgica para virar o tipo se fecha nesse commit)
closure_rule: "Fechamento por goal-atingido: encerra quando STORY-055..067 + STORY-073 estiverem `done` E STORY-068 (validador) tiver emitido veredito em `validation/report.md` aceitável pelo PO (`approved` ou `approved_with_pending` que o PO assuma como goal-atingido). Soft-cap em 2026-07-04 (~31 dias corridos) serve como gatilho de reavaliação — não é prazo de entrega. Se até 2026-06-20 (D+16) o caminho até `ativo` não estiver vivo em homolog, abrir mini-sprint W29 dedicada ao check-out + captura + Pix em vez de inflar a W28. STORY-073 (fix `schedule:run`) é ortogonal e pode iniciar imediatamente — quita F-NB-1 do EPIC-002 carregada da W27."
goal: "Ciclo do turno vivo em homolog (EPIC-003): contratante aceita candidatura no Backoffice → Pagar.me sandbox pré-autoriza `total_contratante` → turno em `confirmado` → profissional gera PIN de check-in (4 dígitos) com flag de geofencing capturada → contratante valida o PIN → turno transita para `ativo` com cronômetro bilateral vivo em tempo real nos dois lados (latência ≤ 2s) → profissional gera PIN de check-out → contratante valida → turno transita para `finalizado` → Pagar.me sandbox captura o valor pré-autorizado → Pix sandbox cai na chave do profissional em ≤ 15 min. Habitualidade (PDR-002) aplicada nos 4 cenários no momento do aceite (PF bloqueia 3ª, PJ alerta+override registrado no AceiteEletronico). Geofencing (PDR-008) alerta-e-registra sem bloquear. Cancelamento antes do check-in libera a pré-autorização; `no_show_pro` por timeout libera também (PDR-007 mínimo, sem motor de penalidade). 3 ADRs novas aceitas (ADR-015 modelo Turno + AceiteEletronico, ADR-016 ACL Pagar.me sandbox + idempotência + webhook, ADR-017 tempo real cronômetro + geolocalização). Validador independente (STORY-068, 4ª aparição após STORY-011/025/054) emite veredito do EPIC-003."
---

# SPRINT-2026-W28

## Objetivo do sprint

A SPRINT-2026-W27 está fechando o EPIC-002 (primeiro encontro Turni vivo em homolog: vaga publicada → feed ranqueado → candidatura em 1 toque → painel de candidatos → edição material PDR-009 → notificações). Em **2026-06-03 (D+2 da W27)** o EPIC-002 já está com **9/9 estórias de implementação `done`**; restam apenas STORY-053 (notificações deployadas, faltam CA-9 SLA e CA-12 E2E Mailpit homolog) e STORY-054 (validador).

Esta sprint **abre o épico mais pesado e mais arriscado da WAVE-2026-01** — EPIC-003 (Aceite, PIN bilateral e Pix via Pagar.me). É o **coração da promessa pública do Turni**: dois dos três pilares do produto (PIN Bilateral e Pix em 15 min) materializam aqui pela primeira vez. Sem isso, o produto vira "publicar vaga + candidatar-se em app". A WAVE-2026-01 só fecha sua hipótese central depois desta sprint.

Recorte deliberado do PO em chat de 2026-06-03 com Alexandro: **EPIC-003 inteiro em uma única sprint** (14 estórias), assumindo o throughput observado nas últimas 4 sprints (W22 6 estórias em 1d; W23 5 em 1d; W24 10 em 2d; W25 6 em 3d; W26 Web-only em 1d; W27 11/13 em 2d). O pedido explícito do PO foi "pode fazer ela pesada que o time de programadores está dando conta" — esta sprint **honra** o pedido, mas codifica um **gatilho de reescopo cedo** (2026-06-20, D+16): se o caminho até `ativo` (até STORY-063, cronômetro vivo) não estiver demonstrável em homolog até lá, o PO abre mini-sprint W29 dedicada a check-out + captura + Pix em vez de inflar a W28.

A composição respeita 3 disciplinas herdadas:

1. **Spike antes de implementação** (lição W27 — STORY-048 L cabe em 1 sessão quando o spike precede de verdade). 3 spikes do Arquiteto na base (modelo Turno + máquina de estados, ACL Pagar.me, tempo real + geolocalização) destravam as 10 estórias de implementação.
2. **Sequência por dependência dura** (máquina de estados do `domain/turno.md`). O caminho `confirmado → aguardando_checkin → ativo → aguardando_checkout → finalizado → Pix` é linear; ortogonais legítimos são cancelamento (STORY-066, sai de `confirmado`) e notificações (STORY-067, consome eventos emitidos pelas demais).
3. **Validação como última estória** (padrão W23/W25/W27 — STORY-068 só roda com tudo em homolog e o validador se atém a evidência + veredito).

A sprint **NÃO** abre frente nova fora do EPIC-003. EPIC-004 (avaliação recíproca) só começa após o veredito do EPIC-003 ser aceito pelo PO.

## Escopo e duração

- **Escopo**: **15 estórias** — EPIC-003 inteiro (14) + STORY-073 (bugfix carry-forward do EPIC-002 — quita F-NB-1 da STORY-054). Mix: **1 S + 12 M + 2 L**.
  - As **duas L** (STORY-056 Pagar.me e STORY-063 cronômetro bilateral) são candidatas naturais a estouro de sessão única. Gatilho de quebra documentado na própria estória; agente escala ao PO **antes** de inflar. Critérios de quebra:
    - STORY-056 → separar `adapter mock em container` (back-end) de `contract test contra sandbox real no CI noturno` (CI/IaC) em duas estórias.
    - STORY-063 → separar `canal de tempo real + backend de eventos` (back-end) de `UI bilateral consumindo o canal` (front-end) em duas estórias.
- **Duração**: **aberta**, com fechamento por goal-atingido (padrão consolidado W22→W27). Soft-cap em **2026-07-04** (~31 dias corridos a partir da provável ativação em 2026-06-04) — folga **deliberadamente maior** que W24/W25/W27 (21d) porque é o épico mais pesado da onda.
- **Gatilho de reescopo cedo em 2026-06-20 (D+16)**: se o caminho `confirmado → aguardando_checkin → ativo` (até STORY-063 cronômetro vivo) não estiver demonstrável em homolog, abrir mini-sprint W29 dedicada a check-out + captura + Pix (STORY-064 + STORY-065 + STORY-068). Decisão do PO documentada em "Mudanças no escopo do sprint" no momento.

## Estórias incluídas

| ID        | Título                                                                                   | Épico    | Tipo           | Papel                    | Tamanho | Status atual |
| --------- | ---------------------------------------------------------------------------------------- | -------- | -------------- | ------------------------ | ------- | ------------ |
| STORY-055 | Spike Arquiteto — modelo Turno + AceiteEletronico imutável + máquina de estados          | EPIC-003 | spike          | arquiteto                | M       | ready        |
| STORY-056 | Spike Arquiteto — ACL Pagar.me + adapter sandbox/mock + idempotência + webhook           | EPIC-003 | spike          | arquiteto                | **L**   | ready        |
| STORY-057 | Spike Arquiteto — tempo real cronômetro bilateral + geolocalização Haversine             | EPIC-003 | spike          | arquiteto                | M       | ready        |
| STORY-058 | Aceitar candidatura no Backoffice + AceiteEletronico imutável + pré-autorização Pagar.me | EPIC-003 | implementation | programador              | M       | ready        |
| STORY-059 | Lista "Meus turnos" (profissional) + "Vagas confirmadas" (contratante) no WebApp         | EPIC-003 | implementation | programador (+ designer) | S       | ready        |
| STORY-060 | Detalhe do turno (ambos os lados) + timeline + trilha de auditoria visível               | EPIC-003 | implementation | programador (+ designer) | M       | ready        |
| STORY-061 | PIN de check-in — geração pelo profissional + captura de geofencing (PDR-008)            | EPIC-003 | implementation | programador (+ designer) | M       | ready        |
| STORY-062 | Validação do PIN de check-in pelo contratante + transição para `ativo`                   | EPIC-003 | implementation | programador (+ designer) | M       | ready        |
| STORY-063 | Cronômetro bilateral vivo em tempo real (latência ≤ 2s)                                  | EPIC-003 | implementation | programador (+ designer) | **L**   | ready        |
| STORY-064 | PIN de check-out — geração + validação + transição para `finalizado`                     | EPIC-003 | implementation | programador (+ designer) | M       | ready        |
| STORY-065 | Captura Pagar.me + Pix sandbox + alerta admin em falha (PDR-010)                         | EPIC-003 | implementation | programador              | M       | ready        |
| STORY-066 | Cancelamento antes do check-in + `no_show_pro` + liberação da pré-autorização            | EPIC-003 | implementation | programador (+ designer) | M       | ready        |
| STORY-067 | Notificações in-app + e-mail dos eventos do turno (8 templates via STORY-020)            | EPIC-003 | implementation | programador              | M       | ready        |
| STORY-068 | Validação final do EPIC-003                                                              | EPIC-003 | validation     | validador                | M       | ready        |
| STORY-073 | Fix — `php artisan schedule:run` em homolog/prod (quita F-NB-1 do EPIC-002)              | EPIC-002 | bugfix         | programador              | M       | ready        |

**Sizing total**: 1 S + 12 M + 2 L (15 estórias). Mais pesada que W27 (2 S + 10 M + 1 L) por **4 estórias-medidas**: 1 spike a mais (3 vs 2 da W27), 1 L a mais (2 vs 1), e 1 bugfix carry-forward (STORY-073). A STORY-073 é ortogonal ao EPIC-003 e cabe em qualquer janela da sprint.

## Ordem de execução obrigatória (máquina de estados do turno)

```
STORY-055 ──┐
STORY-056 ──┤ 3 spikes em paralelo (sessões distintas)
STORY-057 ──┘
    │ todos done
    ▼
STORY-058 (aceitar candidatura + pré-autorização Pagar.me sandbox)
    │ turno em `confirmado` em homolog
    ├─► STORY-059 (listas — pode rodar em paralelo com 060)
    ├─► STORY-060 (detalhe + trilha de auditoria)
    │       │
    │       └─► STORY-061 (PIN check-in + geofencing)  → `aguardando_checkin`
    │               │
    │               └─► STORY-062 (validação check-in)  → `ativo`
    │                       │
    │                       └─► STORY-063 (cronômetro bilateral vivo)
    │                               │
    │                               └─► STORY-064 (PIN check-out)  → `aguardando_checkout` → `finalizado`
    │                                       │
    │                                       └─► STORY-065 (captura Pagar.me + Pix sandbox)
    │
    └─► STORY-066 (cancelamento + no_show_pro) — ortogonal, consome só 055/056/058
    └─► STORY-067 (notificações) — ortogonal, consome eventos das demais
                                                    │
                                                    ▼
                                             STORY-068 (validador independente — última)
```

**Por que esta ordem.** A máquina de estados do `docs/especificacao/domain/turno.md` é linear no caminho feliz; cada transição (`confirmado → aguardando_checkin → ativo → aguardando_checkout → finalizado`) depende da anterior estar operante. Paralelismo legítimo:

- STORY-055/056/057 entre si (3 spikes em sessões distintas, mesma main, sem cruzamento de domínio).
- STORY-059 e STORY-060 entre si (uma é lista, outra é detalhe — telas distintas que consomem o mesmo modelo da STORY-058).
- STORY-066 (cancelamento + no_show) é ortogonal ao caminho feliz e pode rodar a partir de quando STORY-058 fechar.
- STORY-067 (notificações) consome eventos emitidos por todas as demais; pode iniciar a partir de quando STORY-062 fechar (já há eventos suficientes para wiring inicial).

**Anti-paralelismo**: STORY-063 (cronômetro) **não** começa antes de STORY-062 (transição para `ativo`); STORY-064 (check-out) **não** começa antes de STORY-063 (cronômetro vivo é pré-requisito visual); STORY-065 (captura + Pix) **não** começa antes de STORY-064 (transição para `finalizado` é o gatilho da captura).

## Compromisso visível ao fim do sprint

Esta sprint entrega o **ciclo do turno ponta a ponta** em homolog com Pagar.me sandbox — primeira vez que a promessa pública do Turni vira observável.

**Em `app.homolog.turni.com.br` (WebApp Flutter):**

- Profissional `ativo` consegue:
  - Ver "Meus turnos" agrupados por estado (`confirmado`, `aguardando_checkin`, `ativo`, `aguardando_checkout`, `finalizado`, terminais).
  - Abrir um turno e ver detalhe + timeline (audit log simplificado).
  - Em `confirmado` e no horário de início, gerar **PIN de check-in de 4 dígitos** (visível em tela grande, alta legibilidade — contexto de rua).
  - No momento da geração, o WebApp captura a geolocalização e calcula a distância para o estabelecimento (PDR-008 — alerta-e-registra; flag `geofencing_ok` true/false anexada ao evento).
  - Em `ativo`, ver o **cronômetro bilateral vivo** em tempo real (latência ≤ 2s entre o que o profissional vê e o que o contratante vê).
  - Em `ativo`, gerar **PIN de check-out de 4 dígitos**.
  - Em `finalizado`, ver "Pix enviado" com confirmação sandbox.
  - Cancelar um turno em `confirmado` (registra `cancelado_pro`, libera pré-autorização).
- Contratante `ativo` consegue:
  - Ver "Vagas confirmadas" agrupadas por estado dos turnos correspondentes.
  - Abrir um turno e ver detalhe + timeline.
  - Validar o **PIN de check-in** digitando os 4 dígitos no campo; se `geofencing_ok: false`, ver **aviso destacado** com a distância antes de validar.
  - Ver o **cronômetro bilateral vivo** em tempo real.
  - Validar o **PIN de check-out**; turno transita para `finalizado`.
  - Cancelar um turno em `confirmado` (registra `cancelado_emp`, libera pré-autorização).
- Notificações in-app + e-mail funcionando nos 8 eventos do turno: `turno_confirmado`, `checkin_solicitado`, `turno_ativo`, `checkout_solicitado`, `turno_finalizado`, `pix_enviado`, `turno_cancelado`, `no_show_pro`.

**Em `admin.homolog.turni.com.br` (Backoffice Livewire):**

- Editor de templates (STORY-020) ganha 8 templates novos relacionados a turno (carregados como `TemplateVersao` ativa, mesmo padrão do EPIC-001/EPIC-002).
- Equipe Turni aceita candidatura no painel de candidatos (STORY-051) com 1 clique → turno criado em `confirmado` → AceiteEletronico imutável anexado (cláusula override PJ se 3ª alocação semanal — PDR-002) → pré-autorização Pagar.me sandbox disparada de forma idempotente.
- Audit log captura todas as ações novas: `turno.criado`, `aceite_eletronico.emitido`, `pagamento.pre_autorizado`, `turno.checkin_solicitado`, `turno.checkin_validado`, `turno.checkout_solicitado`, `turno.checkout_validado`, `pagamento.capturado`, `pix.enviado`, `pix.falhou` (alerta destacado na fila operacional), `turno.cancelado`, `turno.no_show_pro` (imutável por trigger Postgres herdado do EPIC-001).
- Fila operacional do admin destaca Pix com falha (PDR-010 — uma tentativa, sem retry automático, tratamento manual pela equipe Turni).

**Métricas primárias verificadas pelo validador (STORY-068) em homolog:**

- ≥ 95% das tentativas no caminho feliz completam o ciclo `confirmado → finalizado → Pix sandbox`.
- Pix sandbox cai em ≤ 15 min em ≥ 95% dos turnos completados.
- Validação de PIN executa em ≤ 500ms p95.
- Cronômetro bilateral sincroniza em ≤ 2s.
- Habitualidade (PDR-002) testada nos 4 cenários: PF 0/1/2 alocações libera; PF 3ª bloqueia (mensagem clara em ambos os lados); PJ 3ª alerta + override registrado no AceiteEletronico; transição de semana reseta.

**Decisões registradas (3 ADRs):**

- **ADR-015** — Modelo de Turno + AceiteEletronico imutável + máquina de estados (refina `domain/turno.md` em schema concreto Postgres + invariantes de transição + trigger de imutabilidade do AceiteEletronico espelhando ADR-010).
- **ADR-016** — Implementação concreta da ACL Pagar.me em alto nível decidida em ADR-005: estrutura do adapter, esquema de idempotência (chave + tabela), formato do webhook entrante validado, formato do mock em container + contract test consumer-driven contra sandbox real no CI noturno.
- **ADR-017** — Tempo real do cronômetro bilateral (escolha entre WebSocket, SSE ou polling) + estratégia de geolocalização no check-in (browser API + Haversine vs PostGIS); ambas as decisões cabem na mesma ADR porque são "estratégias técnicas de runtime" com superfície disjunta mas afinidade de timing.

## Decisões de produto/arquitetura que entram em vigor agora

A sprint **respeita** todas as decisões já aceitas e **adiciona** 3 ADRs novas. Os agentes operam sob:

- **ADRs vigentes** (todas aceitas em EPIC-000/EPIC-001/EPIC-002 + EPIC-010): ADR-000 (Postgres), ADR-001/002/003 (stack), ADR-004 (GCP), ADR-005 (Pagar.me alto nível — STORY-056 vai refinar em ADR-016), ADR-006 (habitualidade — STORY-058 consome), ADR-007/008 (Sanctum + Argon2id + log JSON + health), ADR-009 (modelo identidade), ADR-010 (template imutável — espelhado em AceiteEletronico do turno), ADR-011 (provedor e-mail — STORY-067 consome), ADR-012 (landing — não afeta), ADR-013 (modelo Vaga + Candidatura — STORY-058 consome), ADR-014 (algoritmo Match — não afeta esta sprint), **ADR-018 (UUIDv7 em PKs — aplicado pela SPRINT-2026-W27.5 antes desta sprint ativar; todas as 14 estórias do EPIC-003 já citam ADR-018 em "Decisões já tomadas"; modelo Turno + AceiteEletronicoTurno + pagamento_operacoes têm `id` uuid; `external_reference` Pagar.me carrega UUID string; URLs RESTful aceitam UUID; DTOs Flutter tipam `id` como `String`)**.
- **PDRs vigentes que afetam esta sprint**: PDR-001 (PF/MEI/PJ — diferenciação no AceiteEletronico), PDR-002 (habitualidade no aceite), PDR-003 (duas interfaces), PDR-004 (Taxa Turni — base do cálculo de pré-autorização), PDR-005 (gate avaliação — não afeta esta sprint, EPIC-004), PDR-006 (disputa via admin — não afeta esta sprint, EPIC-005), PDR-007 (cancelamento — versão mínima sem motor de penalidade), PDR-008 (geofencing alerta-e-registra), PDR-010 (refresh Pix fora MVP — uma tentativa, alerta admin em falha), PDR-012 (editor de templates — usado para os 8 templates novos), PDR-013 (dual-theme), PDR-015 (fronteira landing — não afeta), PDR-016 (formatação de entradas).
- **DDR-001 + DDR-002** — Design System vivo + locale pt-BR + horário 24h. Telas novas (lista de turnos, detalhe + timeline, PIN check-in/out, cronômetro, alerta geofencing, cancelamento) consomem tokens. Designer entrega 6 SCREEN specs em paralelo no início da sprint (telas das STORY-059, 060, 061, 062, 064, 066 — 8 espera-se que sejam suficientes para cobrir, pois 062 e 061 podem compartilhar componentes).
- **IDR-010/011 + IDR-026** (W26/W27) — modelo híbrido E2E + padrão Flutter de testes + `TurniDateTime` (política única de data/hora). Todos os E2E desta sprint usam `integration_test` em Chrome headless; Playwright só para smoke HTTP. Cronômetro consome `TurniDateTime` (UTC na API, local na UI, round-trip lossless).
- **IDR-020 + IDR-025** (W27) — instalação PWA + restauração de sessão. Telas novas não regridem nenhum dos dois.

Agente programador, arquiteto e designer carregam suas próprias skills + as decisões vigentes antes de começar. Conflito real entre decisão vigente e necessidade da estória escala ao papel dono (Arquiteto via nova ADR, PO via novo PDR, Designer via novo DDR) — não se ajusta silenciosamente no código.

## Riscos identificados na abertura

| Risco | Probabilidade | Impacto | Mitigação | Owner |
|---|---|---|---|---|
| **Pagar.me sandbox é o risco técnico nº 1 da onda** — adapter mock pode divergir do real e quebrar a captura/Pix só em homolog | **alta** | **alto** | STORY-056 entrega adapter + mock em container + contract test consumer-driven contra sandbox real no CI noturno (Opção A da ADR-005); divergência notifica o canal do ADR-008; STORY-065 inclui CA explícito de "Pix observado em sandbox via painel Pagar.me" | Arquiteto + Programador |
| Sprint mais pesada do projeto (14 estórias, 2 L) — pode estourar o soft-cap pela primeira vez | **alta** | médio | Soft-cap deliberadamente maior (~31d vs 21d das demais); gatilho de reescopo cedo em 2026-06-20 (D+16) — se até lá o caminho até `ativo` não estiver vivo, abrir W29 dedicada a check-out+captura+Pix | PO |
| STORY-056 (Pagar.me, L) estoura sessão única — ACL + mock + contract test + webhook é peça grande | **alta** | alto | Critério de quebra documentado na própria estória (adapter+mock em uma; contract test+webhook em outra); agente escala ao PO **antes** de inflar | Arquiteto + PO |
| STORY-063 (cronômetro, L) estoura sessão única — tempo real em 2 lados é tecnicamente novo | **alta** | médio | Critério de quebra documentado (backend de eventos+canal em uma; UI bilateral em outra); ADR-017 entrega a decisão de canal antes de a estória começar | Programador + PO |
| Cronômetro bilateral tem dois clocks divergentes (cliente vs servidor) — pode mostrar números diferentes | **alta** | médio | ADR-017 fixa "servidor é fonte de verdade do tempo decorrido; clientes só consomem"; cronômetro consome `TurniDateTime` (IDR-026); CA de aceite verifica sincronia ≤ 2s entre os 2 lados | Arquiteto + Programador |
| Geolocalização do browser falha (permissão negada, GPS off, indoor) — check-in pode ficar sem coordenada | **média** | médio | PDR-008 é alerta-e-registra (não bloqueia); CA-3 da STORY-061 documenta o cenário "sem coordenada" como `geofencing_ok: false` com `distancia_metros: null` + razão (`permissao_negada`, `timeout`, etc); contratante vê o aviso e decide | Programador + PO |
| Habitualidade (PDR-002) interage mal com a 3ª candidatura PJ — override pode ser registrado sem cláusula no AceiteEletronico | média | alto (jurídico) | STORY-058 CA explícito: 3ª alocação PJ aprovada com override gera AceiteEletronico com cláusula adicional (placeholder `{{habitualidade.override_aceito}}`); ADR-015 fixa imutabilidade; teste cobrindo os 4 cenários de PDR-002 | Programador + Validador |
| Pix sandbox demora > 15 min em janela de pico do Pagar.me — quebra a métrica primária no caminho feliz | média | alto | PDR-010 trata como "alerta admin, sem retry automático"; STORY-068 (validador) verifica ≥ 95% em ≤ 15 min com seed de N turnos (não 100%); se observação em homolog quebrar o SLA repetidamente, abrir PDR registrando ajuste da promessa pública | PO + Validador |
| Webhook entrante do Pagar.me em ambiente local não dispara — desenvolvedor não consegue testar fluxo completo offline | média | médio | STORY-056 inclui o **mock em container** emitindo o webhook de volta (Opção A da ADR-005); `make setup` continua funcionando 100% local sem internet (princípio #6 herdado de STORY-006) | Arquiteto + Programador |
| Cancelamento e `no_show_pro` (STORY-066) ficam órfãos no fim do sprint por estarem ortogonais ao caminho feliz | média | baixo | STORY-066 pode iniciar logo após STORY-058 fechar (dependência mínima); PO inclui no mid-sprint check de 2026-06-10 (D+6) "se 066 não iniciou, alocar agente"; cancelamento + no_show são parte do critério de fechamento, não opcionais | PO + Programador |
| 8 templates de e-mail/in-app da STORY-067 ficam sem texto-seed v1 do PO no momento certo — repete o gargalo da STORY-053 | média | médio | PO entrega texto-seed em sessão dedicada nos primeiros 5 dias da sprint (espelhar disciplina W27 STORY-053); STORY-067 só fecha com `TemplateVersao` ativa carregada para os 8 (CA explícito) | PO |
| 6+ SCREEN specs do Designer (STORY-059, 060, 061, 062, 064, 066) não ficam prontos a tempo — Designer vira gargalo | alta | alto | Designer prioriza no D1-D4 entregando 6 specs antes da semana 2; PO faz sync diário com Designer nos 4 primeiros dias; estórias com `requires_design: true` ficam `blocked` se o screen spec não estiver `ready`; SCREEN pode ser wireframe textual em primeira passada se sinalizado | Designer + PO |
| Custo GCP em homolog cresce com worker de notificações + worker de captura/Pix + webhook + seed mais realista | média | médio | Alerta de orçamento herdado da STORY-007; revisar custo diário a partir do D+7; aceitar trade-off "ambiente mais realista = mais caro" | PO + Alexandro |
| Pagar.me sandbox tem janela de manutenção não anunciada — testes ficam intermitentes | baixa | alto | Mock em container é o ambiente padrão de dev e CI (rápido + determinístico); sandbox só entra no CI noturno (contract test) + na validação manual em homolog (STORY-068); falha de sandbox não bloqueia desenvolvimento | Arquiteto + Programador |
| Alexandro nos 5 papéis em sprint **maior ainda** que a W27 — fadiga cognitiva real | **alta** | médio | Sessão dedicada por papel; PO faz check diário curto (~10 min) separado de execução; aceitar ritmo mais devagar como dado; **planejar pausa explícita entre EPIC-003 e EPIC-004** | Alexandro |

## Acompanhamento contínuo (PO)

- **Diário (~10 min)**: olhar `index.json`, identificar o que está `in_progress` / `blocked` / `in_review`. Desbloquear o que pode (especialmente SCREEN specs do Designer e texto-seed dos 8 templates).
- **Mid-sprint check formal em 2026-06-10 (quarta, D+6)**: PO verifica se STORY-055+056+057 fecharam e se STORY-058 destravou. Se 056 ainda estiver `in_progress` ou foi quebrada, considerar contratação de uma sessão extra de Arquiteto.
- **Gatilho de reescopo cedo em 2026-06-20 (D+16)**: PO verifica se STORY-063 (cronômetro vivo) está demonstrável em homolog. Se **não**, abrir mini-sprint W29 dedicada a STORY-064+065+068 e fechar W28 com escopo reduzido (até `ativo`). Documentar decisão em "Mudanças no escopo do sprint" abaixo.
- **Soft-cap check em 2026-07-04 (~31d)**: se goal não bateu, abrir seção "Mudanças no escopo" e decidir entre seguir, deferir STORY-068 para mini-sprint dedicada, ou redesenhar o épico.

## Disciplina herdada das sprints anteriores (aplicada sem nova negociação)

1. **`sprint_id` no frontmatter** atualizado no mesmo commit que altera `sprints[*].story_ids` no `index.json`. *Já aplicado na abertura desta sprint nas 14 estórias.*
2. **Marcação de CA `[x]`** ao transicionar estória para `status: done`. **Se houver `[ ]` em estória `done`, o PO devolve para `in_progress`.**
3. **"Verdade de corredor" vira PDR/ADR/DDR antes do código.** Decisão de produto/arquitetura/design sem registro associado pausa a estória.
4. **Métrica primária do épico observada no estado final** (aprendizado W23) — validador (STORY-068) só verifica métrica com o último merge do épico deployado.
5. **Validador se atém a evidência + veredito** (aprendizado W23/W25/W27) — não planeja correções, não sugere próximos passos.
6. **Spike antes de implementação** (aprendizado W27 STORY-048) — 3 spikes nesta sprint (055/056/057) precedem todas as 10 estórias de implementação.
7. **Snapshot de payload explicável nasce na estória que cria o dado** (aprendizado W27 STORY-051) — STORY-058 emite AceiteEletronico com payload renderizado completo e imutável; STORY-061 emite evento de check-in com geofencing completo (não só flag); STORY-065 emite evento de captura com `charge_id` do Pagar.me e timestamp do Pix.
8. **Bug que aparece numa estória pode ser sintoma de regra transversal** (aprendizado W27 STORY-052 → IDR-026) — antes de corrigir local, perguntar se vira IDR/DDR/PDR.
9. **F-NB-N do veredito anterior endereçado na sprint seguinte** (padrão consolidado W23 → W27): F-NB-1 do EPIC-002 (auto-retirada de candidatura em limbo porque `schedule:run` não roda em homolog/prod) é endereçada nesta sprint pela STORY-073 (bugfix infra). Ortogonal ao EPIC-003; pode iniciar imediatamente.

## Mudanças no escopo do sprint

> Toda alteração no conjunto de estórias após esta abertura registra aqui, com data e motivo.

| Data | O que mudou | Motivo | Custo (estória solta/movida) |
|---|---|---|---|
| 2026-06-03 | **Sprint deixou de ativar imediatamente após W27 fechar.** Status voltou de `active` para `planned` e ganhou `blocked_by_sprint: SPRINT-2026-W27.5`. | Arquiteto abriu em paralelo a SPRINT-2026-W27.5 (cirúrgica, EPIC-010 refator UUID) com closure_rule explícita "SPRINT-2026-W28 NÃO ativa até esta sprint fechar". ADR-018 já `accepted`. Janela cirúrgica para virar tipo da PK a baixo custo fecha no commit da STORY-056 (Pagar.me `external_reference`). | Zero — W28 não tinha começado nenhuma estória; só o status pulou. |
| 2026-06-03 | **STORY-069 renumerada para STORY-073** (colisão com EPIC-010). | EPIC-010 reservou STORY-069..072 antes (mesmo dia, mas com ADR-018 já em proposed → accepted). | Zero — só renumeração de arquivo + frontmatter + referências. |
| 2026-06-03 | **14 estórias do EPIC-003 (055..068) revisadas** para refletir ADR-018: STORY-055 e STORY-056 com edições materiais (schema PK uuid, FKs foreignUuid, `external_reference` UUID string); STORY-057..068 com ADR-018 adicionada em "Decisões já tomadas" com nota específica sobre o impacto local (URL/DTO/canal/payload/idempotência). | ADR-018 `accepted` por Alexandro implica que toda escrita nova de schema/payload/URL no EPIC-003 deve usar UUID. Revisão preventiva evita retrabalho do agente programador. | Zero — só atualização das instruções; nenhuma estória adicionada/removida. |
| 2026-06-04 | **STORY-056 (Pagar.me, L) QUEBRADA** no gatilho documentado: **056-A** (CA-1..7, 9-10 — ACL completa: interface `GatewayPagamento`, adapter, mock em container devolvendo webhook, idempotência `pagamento_operacoes`, webhook HMAC, observabilidade; ADR-016 `proposed`; núcleo+adapter 100% cobertura; 648 testes verdes; smoke em container real) e **056-B** (CA-8 — contract test consumer-driven contra o sandbox no CI noturno + alerta de divergência). | Decisão do PO em chat (2026-06-04): o adapter+mock+idempotência+webhook cabem numa sessão M, mas o **contract test exige credenciais Pagar.me sandbox que Alexandro ainda não proveu** — separar destrava 056-A agora sem inflar a sessão (exatamente o caminho de exceção previsto no risco "STORY-056 estoura sessão única"). | +1 estória (056-B, S) e bloqueio explícito por credencial; zero retrabalho — 056-A já entrega o desenho inteiro em ADR-016. |

## Fechamento do sprint (preencher no encerramento)

### O que foi entregue
-

### O que ficou para trás (e por quê)
-

### Aprendizados de produto
-

### Aprendizados de processo
-

### Ajustes para o próximo sprint
-
