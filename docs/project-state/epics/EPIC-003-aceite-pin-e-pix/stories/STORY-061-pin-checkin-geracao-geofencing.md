---
story_id: STORY-061
slug: pin-checkin-geracao-geofencing
title: PIN de check-in — geração pelo profissional + captura de geofencing (PDR-008)
epic_id: EPIC-003
sprint_id: SPRINT-2026-W28
type: implementation
target_role: programador
requires_design: true
design_screen_id: SCREEN-STORY-061-pin-checkin
status: ready
owner_agent: null
created_at: 2026-06-03
updated_at: 2026-06-03
estimated_session_size: M
produces_idr: null
---

# STORY-061 — PIN de check-in + captura de geofencing

## Contexto

Profissional chega ao local. Em `confirmado`, no horário próximo de início, ele gera um **PIN de 4 dígitos** que aparece em tela grande para ser lido pelo contratante. No momento da geração, o WebApp captura a geolocalização (PDR-008 alerta-e-registra — não bloqueia) e o backend calcula a distância via Haversine (decisão em ADR-017/STORY-057), gravando flag `geofencing_ok` + distância no evento.

- Épico: `epics/EPIC-003-aceite-pin-e-pix/epic.md`
- Documentos: `domain/turno.md` (transição `confirmado → aguardando_checkin`, atributos `check_in`, `geofencing_check_in`), PDR-008.

## O quê

Botão "Gerar PIN de check-in" no detalhe do turno (STORY-060) quando estado for `confirmado` e horário próximo de início. Geração cria PIN aleatório de 4 dígitos guardado server-side hasheado (não em plaintext nos logs); transita turno para `aguardando_checkin`; captura geolocalização do navegador e grava `geofencing_check_in: { ok, distancia_metros, capturado_em, razao? }` no turno.

## Por quê

PIN bilateral é um dos 3 pilares do produto. Sem geração, não há check-in. Geofencing é a peça que prova ao contratante que o profissional chegou de fato — sem isso, PDR-008 não está em vigor.

## Critérios de aceite

- [ ] **CA-1:** Botão "Gerar PIN de check-in" aparece **apenas** quando turno em `confirmado` E horário corrente está em [data_inicio - 30min, data_inicio + 2h] (janela configurável via env, default explícito). Fora dessa janela: botão desabilitado com microcopy explicando.
- [ ] **CA-2:** Clique solicita geolocalização ao navegador. Se concedida: WebApp envia `{ pin_solicitado: true, lat, lng, accuracy_m }`. Se negada/timeout/erro: WebApp envia `{ pin_solicitado: true, geo: null, razao: 'permissao_negada' | 'timeout' | 'erro_browser' }`.
- [ ] **CA-3:** Backend gera PIN aleatório de 4 dígitos (uniforme, com retry para evitar PINs trivais — repetidos/sequenciais — opcional; documentar decisão); guarda **hash + sal** server-side (nunca plaintext após resposta inicial); transita turno para `aguardando_checkin` em transação com gravação do `geofencing_check_in` (calculando distância via Haversine para coordenada do estabelecimento — reuso do helper `Support\Geo` da STORY-049/057).
- [ ] **CA-4:** Resposta retorna **PIN em plaintext** para a tela do profissional (única vez que aparece — refresh perde o PIN, profissional re-gera). PIN nunca aparece em logs JSON (só hash + flag de geração).
- [ ] **CA-5:** Tela do profissional mostra PIN em grande (tipografia ≥ 64pt; contraste AAA) com microcopy "Mostre este PIN ao contratante para validar a chegada". Botão "Não chegou ainda? Cancelar PIN" volta para `confirmado` (idempotente — geração nova invalida hash anterior).
- [ ] **CA-6:** `geofencing_ok` calculado contra raio do estabelecimento (default 100m, configurável por estabelecimento — registrar como follow-up se for muito; default 100m é o suficiente para o sprint). `geofencing_ok: false` **não bloqueia** o check-in (PDR-008) — só registra.
- [ ] **CA-7:** Audit log captura `turno.checkin_solicitado` com `geofencing_check_in` completo (snapshot).
- [ ] **CA-8:** RBAC: só o profissional do turno gera PIN; contratante recebe 403 ao tentar; admin não gera (papel do admin é diferente).
- [ ] **CA-9:** Cobertura ≥ 98% na geração de PIN (regra de negócio) e cálculo de geofencing; ≥ 80% no resto. E2E cobre os 3 caminhos de geo (concedida, negada, timeout).

## Fora de escopo

- Validação do PIN pelo contratante (STORY-062).
- Geofencing no check-out (STORY-064 traz).
- Raio configurável por estabelecimento — vira follow-up se reclamado.

## Padrões de qualidade

≥ 80% / ≥ 98% no núcleo (PIN + Haversine). E2E em `integration_test` cobre todos os caminhos de geo.

## Dependências

- **Bloqueada por:** STORY-057 (geolocalização decidida), STORY-060 (área de ações no detalhe).
- **Bloqueia:** STORY-062 (validação consome PIN gerado).
- **Pré-requisitos:** SCREEN-STORY-061 entregue.

## Decisões já tomadas

ADR-015, ADR-017, PDR-008, IDR-026.

## Liberdade técnica

Decide: algoritmo de hash (bcrypt/Argon2id — usar o já presente do EPIC-001), formato da janela de geração, microcopy do estado vazio.

NÃO decide: comportamento de geofencing (PDR-008 fixa); imutabilidade do snapshot (ADR-015 fixa).

## Definição de Pronto

- [ ] CAs marcados; deploy verificado.
- [ ] SCREEN-STORY-061 `shipped`.
- [ ] Alexandro testa em homolog (gera PIN, vê tela grande, geo capturada).
- [ ] `index.json` atualizado.
- [ ] "Notas do agente" preenchida.

## Protocolo

`docs/skills/po/references/agent-task-format.md`.

## Notas do agente

### Decisões tomadas
### Descobertas
### Bloqueios encontrados
### IDRs criados
### Cobertura final
- Unitários:
- E2E:
### Links de evidência
- PR:
- Pipeline:
- Deploy de homologação:
