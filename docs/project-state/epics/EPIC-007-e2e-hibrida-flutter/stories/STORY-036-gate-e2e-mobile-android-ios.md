---
story_id: STORY-036
slug: gate-e2e-mobile-android-ios
title: Gate E2E mobile local — Android emulator + iOS simulator, runbook e política
epic_id: EPIC-007
sprint_id: null
type: enablement
target_role: programador
requires_design: false
status: draft
owner_agent: null
created_at: 2026-05-29
updated_at: 2026-05-29
estimated_session_size: M
---

# STORY-036 — Gate E2E mobile (Android + iOS), runbook e política

> **Para o agente que vai executar:** leia esta estória por inteiro antes de começar. Esta estória **só faz sentido depois de STORY-034 e STORY-035**. Aqui o objetivo é fechar o ciclo: rodar os `integration_test` existentes (UI Flutter) em Android emulator e iOS simulator, decidir e documentar quando esse gate é obrigatório, e deixar o runbook escrito para quem for replicar o setup. **Não** é tornar o gate mobile obrigatório no MVP — é deixá-lo pronto e documentado.

## Contexto (por que esta estória existe)

Os `integration_test` da STORY-034 foram escritos para Web (rodam em Chrome headless), mas o ponto do EPIC-007 é exatamente que o mesmo código Dart roda em Android e iOS sem reescrever. Patrol da STORY-035 entrega cobertura nativa adicional (diálogos do SO). Falta o gate: como o time roda esses testes em mobile, em que situação isso é obrigatório, e quem mantém o setup.

A política do gate hoje é local pré-tag (IDR-004). Esta story propõe:

- **Curto prazo (MVP, antes da primeira release mobile):** rodar `integration_test` em Android emulator e iOS simulator é **opcional** — quem mexer em código que afeta mobile (algo nativo, plugin específico, layout dependente de viewport mobile real) roda; rotina padrão continua sendo Chrome headless.
- **A partir da primeira release mobile (STORY-XXX a definir):** rodar em Android emulator passa a ser **obrigatório** antes de tag mobile-rc. iOS simulator depende de macOS disponível — se não houver, fica como pendência ou como gate para o operador que tiver o ambiente.
- **CI**: continua fora do escopo (IDR-004 não muda nesta story). Decisão sobre mobile em CI / Firebase Test Lab fica para uma IDR separada quando custo de manter o gate local virar argumento.

- Épico: `docs/project-state/epics/EPIC-007-e2e-hibrida-flutter/epic.md`
- Documentos canônicos a ler ANTES de codificar:
  - `docs/project-state/decisions/idr/IDR-004-e2e-local-pipeline-smoke-curl.md` — política de gate local.
  - `docs/project-state/decisions/idr/IDR-010-e2e-hibrida-integration-test-playwright-patrol.md` — modelo híbrido.
  - `docs/project-state/decisions/idr/IDR-011-padrao-teste-flutter-keys-mocks-helpers.md` — padrão herdado.
  - `Makefile` — onde adicionar os novos targets.
  - `docs/operacao/` — pasta onde o runbook deve viver.

## O quê (objetivo desta estória)

1. **Makefile** — novos targets:
   - `make e2e-webapp-android` — roda `flutter test integration_test -d <android-device-id>` contra Android emulator/AVD configurado.
   - `make e2e-webapp-ios` — equivalente para iOS simulator (em macOS).
   - Ambos validam pré-requisitos (emulator rodando, device id detectado) e dão mensagem de erro acionável se não estiverem prontos.
2. **Runbook** em `docs/operacao/e2e-mobile-runbook.md`:
   - Setup Android: Android Studio, instalar SDK, criar AVD (qual API level, qual device), iniciar emulator via CLI (`emulator -avd <name>`).
   - Setup iOS: Xcode, simulator (qual device, qual iOS version), `open -a Simulator`.
   - Como rodar `make e2e-webapp-android` / `make e2e-webapp-ios`.
   - Como rodar `make e2e-webapp-patrol-android` (já entregue em STORY-035) — referência cruzada.
   - Troubleshooting comum: `flutter doctor` falhando, emulator não detectado, device id, Gradle daemon travado, simulator com versão errada.
   - Tempo esperado: documentar wall-time de uma execução completa em Android e iOS (vs. Chrome headless).
3. **Política de gate** documentada — adicionar seção ao `apps/webapp/README.md` (subseção "Quando rodar o gate mobile") **e** registrar a regra em IDR-010 (atualização inline, não nova IDR):
   - MVP / pré-mobile: opcional, recomendado quando tocar em código mobile-sensível.
   - Pós-1ª release mobile: Android obrigatório, iOS condicional a macOS.
   - CI: fora do escopo desta onda.
4. **Atualizar IDR-010** com a seção "Política de gate mobile" descrita acima. Inclui critério explícito de virada (quando o gate mobile vira obrigatório).
5. **Smoke test do setup** — rodar `make e2e-webapp-android` localmente uma vez com sucesso, registrar evidência em "Notas do agente". Em ambiente macOS, idem para `make e2e-webapp-ios`. Em ambiente não-macOS, registrar que iOS não foi validado e marcar como pendência operacional para o primeiro operador macOS.

## Por quê (valor para o time)

Sem este gate documentado, "rodar E2E em mobile" vira ritual que cada dev descobre sozinho — quando alguém eventualmente quebrar algo mobile-específico (layout sob viewport pequeno, plugin que se comporta diferente, deep link que só Android resolve), o feedback chega tarde. Com runbook + Makefile, o custo cognitivo de rodar localmente cai para "1 comando depois de subir o emulator". É preparação direta para a virada nativa do WebApp.

## Critérios de aceite

### Makefile

- [ ] **CA-1:** `make e2e-webapp-android` existe, detecta device Android conectado/emulator rodando, falha com mensagem acionável se nenhum dispositivo for detectado.
- [ ] **CA-2:** `make e2e-webapp-android` roda `flutter test integration_test` no device detectado, sai 0 quando todos os 7 cenários (entregues por STORY-034) passam.
- [ ] **CA-3:** `make e2e-webapp-ios` existe e tem comportamento equivalente em macOS. Em Linux/Windows, imprime mensagem orientando o operador (não falha silencioso).
- [ ] **CA-4:** Targets ficam fora do `make e2e-webapp` principal (gate de pré-tag continua sendo Chrome headless + smoke Playwright — IDR-004 + IDR-010).

### Runbook

- [ ] **CA-5:** `docs/operacao/e2e-mobile-runbook.md` existe e cobre: setup Android (Studio, SDK, AVD), setup iOS (Xcode, simulator), comandos, troubleshooting de pelo menos 4 falhas comuns.
- [ ] **CA-6:** Runbook tem seção "Tempos de referência" com wall-time medido pelo agente em Android emulator local. iOS pode ficar com placeholder se não houver macOS disponível na execução desta story.
- [ ] **CA-7:** Runbook referencia STORY-035 / Patrol como complemento (cenários nativos via `make e2e-webapp-patrol-*`).

### Política e IDR-010

- [ ] **CA-8:** `apps/webapp/README.md` ganha subseção "Quando rodar o gate mobile" descrevendo a política (opcional no MVP / obrigatório pós-1ª release mobile / CI fora do escopo).
- [ ] **CA-9:** IDR-010 atualizada com seção "Política de gate mobile" alinhada com README. Inclui gatilho explícito de virada (e.g., "a partir da primeira tag mobile-rc.N gerada no pipeline, Android emulator passa a ser pré-condição local"). PO assina a atualização.

### Validação prática

- [ ] **CA-10:** `make e2e-webapp-android` rodou verde local pelo menos 1x. Logs ou evidência em "Notas".
- [ ] **CA-11:** Em macOS: `make e2e-webapp-ios` rodou verde local pelo menos 1x. Em não-macOS: pendência operacional carregada para a primeira execução em ambiente macOS.

## Fora de escopo

- Mobile em CI — IDR-004 não muda. Decisão fica para futuro.
- Firebase Test Lab / BrowserStack / EAS — fora.
- Cenários nativos de produto (image_picker real, push, deep link de e-mail) — entram com as stories de produto correspondentes via Patrol.
- Refatoração dos `integration_test` da STORY-034 — só executam em outro device. Se algum cenário precisar de ajuste device-specific, escalar.
- Otimização de tempo de boot do emulator — pode entrar no runbook como dica, mas não como engenharia desta story.

## Padrões de qualidade exigidos

- Runbook precisa ter o "happy path" testável por um operador que nunca rodou E2E mobile antes (assume Android Studio instalado, mas não assume saber qual AVD criar).
- Targets do Makefile precisam falhar cedo e com mensagem acionável (não "exit 1" silencioso).
- IDR-010 precisa ter critério de virada **objetivo** — não "quando o time achar que é hora", mas algo verificável.

## Dependências

- **Bloqueada por:** STORY-034 (`integration_test` no Web e padrão IDR-011) e STORY-035 (Patrol configurado — runbook referencia).
- **Bloqueia:** nada diretamente. Habilita a primeira story do native a entrar com gate pronto.
- **Pré-requisitos de ambiente:** Android SDK + 1 AVD funcional para CA-10. macOS + Xcode + simulator para CA-11 em ambiente macOS.

## Decisões já tomadas (não as reabra)

- **CI continua fora** — IDR-004 vigente. Esta story não move mobile para pipeline.
- **Patrol já está em uso** — runbook referencia, não reconfigura.
- **Gate mobile opcional no MVP** — decisão deste épico. Não tentar reabrir como "vamos tornar obrigatório já".

## Liberdade técnica do agente

Você decide:

- Detalhes do AVD recomendado no runbook (qual API level, qual device — escolha um par sensato para a base instalada do Turni futuro).
- Estrutura interna do runbook (subseções, ordem).
- Detalhes dos targets Makefile (como detectar device, qual filtro `-d`).

Você **não** decide:

- Mover o gate mobile para dentro do `make e2e-webapp` principal.
- Adicionar mobile a CI.
- Tornar gate mobile obrigatório no MVP.

## Definição de Pronto (DoD)

- [ ] CA-1 a CA-10 atendidos. CA-11 atendido em macOS ou marcado como pendência operacional.
- [ ] Runbook revisado por um segundo agente / operador (mesmo informalmente) — clareza checada.
- [ ] IDR-010 anotada com política de gate mobile e PO assinou a atualização.
- [ ] README do WebApp atualizado.
- [ ] `index.json` atualizado: `status: done`.
- [ ] "Notas do agente" preenchidas.

## Protocolo do agente (obrigatório)

Segue `docs/skills/po/references/agent-task-format.md`. Particular:

1. **Ao iniciar:** confirmar STORY-034 e STORY-035 em `done`. Confirmar com PO que política proposta (opcional no MVP / obrigatória pós-1ª release mobile) está alinhada antes de escrever IDR-010 update — política é decisão de PO, não de agente.
2. **Durante:** medir tempos (boot emulator + execução suíte) e registrar. TaskList interna.
3. **Se travar em setup de emulator:** escalar se passar de 2h. Caso comum: Hyper-V vs HAXM no Windows, KVM no Linux. Documentar workaround usado.
4. **Ao terminar:** `status: in_review`, PR aberto, IDR-010 update revisada pelo PO.

## Notas do agente (preenchido durante/após execução)

### Decisões tomadas
- _A preencher._

### Descobertas
- _A preencher._

### Bloqueios encontrados
- _A preencher._

### IDRs criados
- Nenhuma esperada. IDR-010 atualizada.

### Cobertura final
- `make e2e-webapp-android` verde local (1x mínimo, idealmente 3x).
- `make e2e-webapp-ios` verde local (se macOS) ou pendência declarada.
- Wall-time Android: _a preencher_.
- Wall-time iOS: _a preencher_.

### Links de evidência
- _A preencher._
