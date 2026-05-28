---
story_id: STORY-022
slug: welcome-pos-aprovacao-webapp
title: Tela de welcome pós-aprovação no WebApp
epic_id: EPIC-001
sprint_id: SPRINT-2026-W24
type: implementation
target_role: programador
requires_design: true
design_screen_id: SCREEN-STORY-022-welcome
status: ready
owner_agent: null
created_at: 2026-05-28
updated_at: 2026-05-28
estimated_session_size: S
---

# STORY-022 — Tela de welcome pós-aprovação no WebApp

> **Para o agente que vai executar:** leia esta estória por inteiro antes de começar. Ela contém tudo o que você precisa. Se algo estiver ambíguo, registre a dúvida na seção "Notas do agente" no final e pause em vez de adivinhar.

## Contexto (por que esta estória existe)

O funil pós-aprovação descrito em `domain/usuario.md` exige que o usuário aprovado **veja a tela de welcome uma vez** antes de ir para completar cadastro. STORY-016 deixou a rota `/welcome` como placeholder funcional para o funnel guard. Esta estória substitui o placeholder pela tela real: boas-vindas com nome do usuário, explicação curta do que vem a seguir (completar cadastro = ~5 min, listar dados sensíveis a coletar), CTA primário "Vamos lá" que marca `welcome_visto = true` e leva a `/completar-cadastro`. É a primeira tela que o usuário recém-aprovado vê — primeira impressão "dentro do produto" — então merece cuidado de voice-and-tone.

Esta é uma estória S porque é uma tela simples, mas com lógica importante de transição de funil + diferenciação de tema por papel (profissional ou contratante).

- Épico: `docs/project-state/epics/EPIC-001-cadastro-e-aprovacao/epic.md`
- Documentos canônicos a ler ANTES de codificar:
  - `docs/especificacao/domain/usuario.md` §"Estados do usuário" (`welcome_visto` flag) e §"Atributos por papel"
  - `docs/project-state/decisions/adr/ADR-009-modelo-de-dados-identidade-epic-001.md`
  - STORY-016 (funnel guard + rota placeholder)
  - `docs/project-state/design/screens/SCREEN-STORY-022-welcome.md` (Designer entrega)
  - `docs/project-state/design/system/voice-and-tone.md`, `tokens.md`
  - `docs/skills/programador/SKILL.md`, `docs/skills/po/references/quality-standards.md`

## O quê (objetivo desta estória)

Entregar tela de welcome real:

1. Rota `/welcome` no WebApp Flutter substitui o placeholder de STORY-016.
2. **Conteúdo**:
   - Headline com nome do usuário ("Bem-vindo(a), {{nome}}!").
   - Parágrafo curto explicando o próximo passo ("Falta só completar seu cadastro — vai levar uns 5 minutos. Vamos pedir CPF/CNPJ, endereço, e [dados específicos do papel]").
   - Lista breve do que será pedido (3–5 bullets adaptados ao papel — profissional: documento, chave Pix, foto de comprovante; contratante: CNPJ, endereço, cultura, contatos).
   - CTA primário: "Vamos lá".
   - Link secundário discreto: "Fazer depois" → faz logout sem marcar `welcome_visto` (usuário vê welcome novamente no próximo login). **Não** é "skip" para `/completar-cadastro` — quer **forçar consciência** do checkpoint.
3. Tema aplicado por papel (profissional/contratante) via DDR-001. Voice-and-tone do Designer.
4. **Lógica de transição**:
   - Clique em "Vamos lá": chama `POST /api/usuarios/me/welcome-visto` (sua rota — sua decisão de naming, registrado em IDR se introduzir padrão); request marca `welcome_visto = true`; resposta inclui novo estado; cliente Flutter atualiza router para `/completar-cadastro`.
   - Acesso direto a `/welcome` por usuário `ativo` mostra mensagem "Você já está com cadastro completo. [link para home]".
   - Acesso direto a `/welcome` por usuário `pendente_aprovacao` ou não-autenticado: 403/redirect a login (já garantido pelo funnel guard de STORY-016, mas teste cobre).
5. **Idempotência**: tentar marcar `welcome_visto = true` quando já está `true` é no-op silencioso (não erra).

## Por quê (valor para o usuário)

Direto: primeira impressão "dentro do produto" — momento de afirmar tom e propósito (autonomia, suporte). Lista do que será pedido reduz fricção mental do completar cadastro. Indireto: marca `welcome_visto = true` que destrava `/completar-cadastro` no funnel guard; primeira mudança de estado **autodirigida pelo usuário** (até aqui, todas as transições foram triggered por admin).

## Critérios de aceite

- [ ] **CA-1:** Rota `/welcome` em homolog renderiza tela real (não placeholder) para usuário `liberado, welcome_visto=false` autenticado.
- [ ] **CA-2:** Headline personalizada com nome do usuário; bullets do que será pedido adaptados ao papel.
- [ ] **CA-3:** Tema aplicado conforme papel (profissional / contratante) seguindo DDR-001 + PDR-013 (claro/escuro).
- [ ] **CA-4:** CTA "Vamos lá" chama API correta, marca `welcome_visto = true`, redireciona a `/completar-cadastro` (que ainda é placeholder até STORY-023/024 fecharem — após elas, leva à tela real).
- [ ] **CA-5:** Link "Fazer depois" faz logout limpo, retorna a `/login`, **não** marca `welcome_visto`. Próximo login mostra `/welcome` de novo (testar).
- [ ] **CA-6:** Acesso a `/welcome` por usuário `ativo` mostra mensagem informativa com link para home.
- [ ] **CA-7:** Acesso a `/welcome` por não-autenticado redireciona ao login.
- [ ] **CA-8:** Idempotência da marcação: chamar 2× não erra (no-op no servidor).
- [ ] **CA-9:** Acessibilidade WCAG 2.1 AA; tema dual.
- [ ] **CA-10:** Cobertura ≥ 80% / ≥ 98% núcleo (transição de funil, mensagem por papel, idempotência).
- [ ] **CA-11:** **E2E em browser real**: seed cria usuário de teste `role=profissional, status=liberado, welcome_visto=false`; usuário loga no WebApp → cai em `/welcome` → clica "Vamos lá" → redireciona a `/completar-cadastro`; segundo login no mesmo usuário (já com `welcome_visto=true, cadastro_completo=false`) → cai direto em `/completar-cadastro` (sem passar pelo welcome).
- [ ] **CA-12:** Log estruturado: evento `user.welcome_seen` com `user_id, role, timestamp` (sem dado pessoal claro).

## Fora de escopo

- Tela de completar cadastro — STORY-023/024.
- Onboarding multi-passo / tutorial interativo — fora do MVP.
- Personalização avançada do welcome (dicas por persona) — fora do MVP.

## Padrões de qualidade exigidos

`quality-standards.md`. Em particular:

- **Cobertura ≥ 80% / ≥ 98% núcleo** (transição de funil, mensagens por papel, idempotência).
- **E2E em browser real** cobrindo CA-11.
- **TDD** nas regras.
- **Segurança (§4)**: rota protegida pelo funnel guard; CSRF Sanctum.
- **Acessibilidade (§5)**: WCAG 2.1 AA; tema dual.

## Dependências

- **Bloqueada por:** STORY-016 (funnel guard + auth). STORY-012 (ADR-009 — estado e flag). Designer entrega `SCREEN-STORY-022-welcome` em `ready`.
- **Bloqueia:** STORY-023/024 (a tela de completar cadastro precisa que welcome esteja real para o E2E completo do funil), STORY-025 (validação).
- **Pré-requisitos:** STORY-006, STORY-007.

## Decisões já tomadas (não as reabra)

- **`domain/usuario.md`** — funil obrigatório welcome → completar cadastro.
- **ADR-009** — flag `welcome_visto`.
- **DDR-001 + PDR-013** — tema dual, cor por perfil.
- **STORY-016** — funnel guard infra.

## Liberdade técnica do agente

Você decide:
- Endpoint exato (`POST /api/usuarios/me/welcome-visto` vs equivalente).
- Estrutura concreta da tela Flutter (componentes do DDR-001).
- Texto exato dos bullets (com Designer).
- Como detectar papel para escolher bullets (do estado de sessão já carregado pelo router).

Você NÃO decide:
- Suprimir o link "Fazer depois" (PO quer manter controle do usuário).
- Reabrir esquema de funil.

## Definição de Pronto (DoD)

- [ ] CA-1 a CA-12 passam.
- [ ] Cobertura medida.
- [ ] E2E verde.
- [ ] Sync Designer↔Programador registrado.
- [ ] `index.json` atualizado.
- [ ] "Notas" preenchida.
- [ ] IDR se houve decisão técnica relevante.

## Protocolo do agente (obrigatório)

Siga `docs/skills/po/references/agent-task-format.md`. Carregue `docs/skills/programador/SKILL.md`. Confirme screen spec em `ready`. TDD. PR com evidência. `done` após deploy verde.

## Notas do agente (preenchido durante/após execução)

### Entrada inicial
(a preencher)

### Sync Designer↔Programador
(a preencher)

### Decisões tomadas
(a preencher)

### Cobertura final
(a preencher)

### Resultado final / evidência
(a preencher)

### Links de evidência
(a preencher)
