---
pdr_id: PDR-008
slug: geofencing-alerta-e-registra
title: Geofencing no check-in alerta e registra, não bloqueia
status: accepted
decided_at: 2026-05-26
decided_by: PO (Alexandro / Claude)
supersedes: null
superseded_by: null
related_epics: []
related_adrs: []
---

# PDR-008 — Geofencing alerta-e-registra

## Contexto

O protótipo apresenta um geofencing de 100m no check-in como parte da promessa de presença real. A pergunta de produto: o que acontece quando o profissional gera PIN fora do raio? Bloquear é técnico e estrito mas falha em casos legítimos (endereço cadastrado impreciso, GPS oscilando em ambiente fechado, primeiro turno em estabelecimento novo). Não detectar é perder a garantia.

## Decisão

> **Geofencing no check-in alerta e registra, mas não bloqueia.**

Comportamento:

- Profissional gera PIN de check-in mesmo se estiver fora do raio de 100m.
- O **evento de check-in carrega a flag `geofencing_ok: true | false`** e a **distância medida** no momento do PIN.
- Quando `geofencing_ok = false`, a UI do contratante apresenta o aviso destacado antes de validar o PIN ("profissional fora do raio do estabelecimento por X metros — verifique se a posição faz sentido").
- O evento é registrado na trilha de auditoria do turno, disponível para o admin em caso de disputa.

## Justificativa

Bloquear cria falsos negativos que prejudicam profissionais legítimos. Não registrar perde sinal. Alertar e registrar dá ao contratante o poder de decidir com informação completa e cria trilha de auditoria útil para disputa, sem criar atrito desnecessário no caso comum.

## Consequências

### Positivas
- Profissionais legítimos não bloqueados por GPS impreciso.
- Contratante tem informação para decidir.
- Trilha de auditoria existe para casos de disputa.
- A promessa de presença real é preservada (registro existe; basta o contratante validar com atenção).

### Negativas / trade-offs aceitos
- Profissional malicioso pode tentar fraudar check-in remoto — contratante é a barreira.
- Operação Turni pode precisar agir em casos de padrão suspeito (vários check-ins fora do raio do mesmo profissional → investigação).

### Para o time técnico
- ADRs prováveis: estratégia de captura de localização (precisão, fallback, permissão negada); modelo de dados do evento check-in com geofencing.
- Impacto em épicos: EPIC de check-in/check-out; EPIC de backoffice (admin precisa filtrar por eventos `geofencing_ok: false`).

## Sinais de revisão

- Se padrão de fraude (check-in remoto bem-sucedido) for detectado, abrir variação por nível (Elite/Destaque sem bloqueio; Iniciante com bloqueio até consolidar histórico).
- Se a taxa de `geofencing_ok: false` em check-ins legítimos for alta (> 15%), reabrir como problema de UX/medição, não de regra.
