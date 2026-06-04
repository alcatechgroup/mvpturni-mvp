---
story_id: STORY-075
slug: banner-global-homolog-pagamentos-simulados
title: Banner global em homolog — "Ambiente de teste — pagamentos simulados" (PDR-017)
epic_id: EPIC-003
sprint_id: SPRINT-2026-W28
type: implementation
target_role: programador
requires_design: false  # microcopy + cor de aviso do DS — reuso sem nova SCREEN
design_screen_id: null
status: ready
owner_agent: null
created_at: 2026-06-04
updated_at: 2026-06-04
estimated_session_size: S
produces_idr: null
renumbered_from: STORY-074  # colisão #2 — EPIC-011 (geolocalização, spin-off de STORY-057) reservou STORY-074 no mesmo dia para "geocoding endereço estabelecimento"; renumerada para STORY-075 (próximo livre)
---

# STORY-075 — Banner global em homolog "Ambiente de teste — pagamentos simulados"

## Contexto

PDR-017 decidiu que o MVP usa **fake genérico** atrás da ACL de pagamento; integração Pagar.me real entra na próxima wave. Em homolog, o ciclo do turno fim a fim mostra "Pix enviado" para o profissional e "Pagamento confirmado" para o contratante — mas nada cai de verdade. **Sem indicação visível, qualquer demonstração externa (Alexandro, equipe Turni, parceiros, investidores) pode tomar o comportamento como real e gerar expectativa equivocada.**

A decisão do PDR-017 (item "Comunicação ao usuário" da AskUserQuestion de 2026-06-04) é: **banner global persistente em homolog** com microcopy clara, **não aparece em produção**.

- Épico: `epics/EPIC-003-aceite-pin-e-pix/epic.md`
- Decisão: `decisions/pdr/PDR-017-pagamento-via-fake-generico-no-mvp.md`
- Documentos: DDR-001 (Design System), DDR-002 (locale pt-BR + 24h).

## O quê

Banner global no topo de **toda tela autenticada** do WebApp Flutter (`apps/webapp`) e do Backoffice Livewire (`apps/admin`) quando o ambiente for `homolog`. Mensagem: **"Ambiente de teste — pagamentos simulados"**. Cor de aviso do DDR-001 (DS), persistente (não dispensável), altura mínima que não atrapalhe a UX mas seja claramente visível.

Em produção (`live`) e em landing (`apps/landing`) o banner **não aparece**.

## Por quê

Elimina ambiguidade demonstrativa do MVP. Risco real: Alexandro abre homolog para parceiro/investidor, fluxo do turno corre fim a fim com "Pix enviado" visível, e o parceiro acha que o produto está rodando pagamentos reais. Trade-off de UX (perda de polimento estético do "produto pronto") é amplamente compensado pelo ganho de honestidade.

## Critérios de aceite

- [ ] **CA-1:** Banner visível no topo de toda tela autenticada do WebApp quando `APP_ENV=homolog` (ou variável equivalente decidida pelo agente). Microcopy: "Ambiente de teste — pagamentos simulados". Espelhado no Backoffice.
- [ ] **CA-2:** Banner **não aparece** em `APP_ENV=production` nem em `APP_ENV=local` (dev local) — só em `homolog`. Decisão: dev local não precisa do banner porque o desenvolvedor sabe o que está rodando; em produção, comportamento é real.
- [ ] **CA-3:** Banner **não aparece** em `apps/landing` (não há fluxo de pagamento na landing — confusão impossível).
- [ ] **CA-4:** Banner **não aparece** em telas pré-autenticação (login, cadastro, reset de senha) — não há ação financeira nessas telas e o banner polui a primeira impressão. Excepção: se o agente julgar valioso aparecer também antes do login para deixar claro a parceiros antes de se autenticarem, escalar ao PO antes de implementar.
- [ ] **CA-5:** Banner não é dispensável (sem botão "fechar") — persistência é o ponto. Pode ser minimizado visualmente após scroll (decisão de UX do agente).
- [ ] **CA-6:** Cor + tipografia consumem tokens do DS (DDR-001) — uso da cor de aviso/atenção. Não inventar cor nova.
- [ ] **CA-7:** Acessibilidade — banner com `role="status"` ou equivalente; contraste AAA com o background; texto legível em telas pequenas (mobile-first).
- [ ] **CA-8:** Cobertura ≥ 80% no código novo (widget Flutter + componente Livewire); teste cobre os 3 cenários de visibilidade (homolog mostra; production/local não mostra; landing/pre-auth não mostra).

## Fora de escopo

- Banner em produção — não aparece (PDR-017 só removeu Pagar.me; quando voltar na próxima wave, banner desaparece de homolog também e nunca aparece em produção).
- Mecanismo de feature flag externa (LaunchDarkly, etc) — usar env var simples; over-engineering desnecessário.
- Diferentes microcopias por papel (profissional vs contratante vs admin) — mesma microcopy para todos; simplicidade.
- Banner em e-mail transacional (STORY-067) — e-mails podem mencionar "ambiente de teste" no rodapé, mas isso é decisão da própria STORY-067 (e-mails em homolog já têm assinatura Mailpit que indica isso).

## Padrões de qualidade

≥ 80%. Tests unitários cobrem os 3 cenários. Sem regressão visual no auto-update da STORY-037 (PWA continua instalável; banner não quebra layout de instalação).

## Dependências

- **Bloqueada por:** nenhuma — ortogonal ao caminho crítico do EPIC-003. Pode iniciar a qualquer momento da W28.
- **Bloqueia:** STORY-068 (validador verifica banner visível como CA do checklist).
- **Pré-requisitos:** `APP_ENV` ou variável equivalente já configurada por ambiente (herdada de STORY-007).

## Decisões já tomadas

- **PDR-017** — Pagamento via fake genérico no MVP; comunicação ao usuário em homolog via banner global (decisão de produto fixada).
- DDR-001 — Design System (tokens de cor).
- DDR-002 — Locale pt-BR (microcopy em português).

## Liberdade técnica

Você decide: nome exato da variável de ambiente, posição CSS do banner, altura, comportamento em mobile (sticky vs absolute), microcopy exata se julgar que a sugestão pode ser mais clara — escalar ao PO se quiser desviar.

Você NÃO decide: que o banner aparece em homolog (PDR-017 fixa); que não aparece em produção (PDR-017 fixa); que é não-dispensável (PDR-017 fixa — persistência é o ponto).

## Definição de Pronto

- [ ] CAs marcados; deploy em homolog verificado por Alexandro (banner visível em WebApp + Backoffice; ausente em landing).
- [ ] Pipeline verde com cobertura exigida.
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
### Links de evidência
- PR:
- Pipeline:
- Deploy de homologação (screenshot do banner):
