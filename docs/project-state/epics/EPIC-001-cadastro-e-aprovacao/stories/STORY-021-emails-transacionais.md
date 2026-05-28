---
story_id: STORY-021
slug: emails-transacionais
title: E-mails transacionais (aprovação concedida + lembrete completar cadastro + reset de senha)
epic_id: EPIC-001
sprint_id: null
type: implementation
target_role: programador
requires_design: true
design_screen_id: SCREEN-STORY-021-emails-transacionais
status: ready
owner_agent: null
created_at: 2026-05-28
updated_at: 2026-05-28
estimated_session_size: M
---

# STORY-021 — E-mails transacionais

> **Para o agente que vai executar:** leia esta estória por inteiro antes de começar. Ela contém tudo o que você precisa. Se algo estiver ambíguo, registre a dúvida na seção "Notas do agente" no final e pause em vez de adivinhar.

## Contexto (por que esta estória existe)

ADR-011 (STORY-014) escolheu o provedor de e-mail transacional, fixou a ACL e definiu as 3 mensagens canônicas do MVP. Esta estória **implementa o envio real** e entrega o conteúdo textual final. A trigger de `aprovacao_concedida` já foi enfileirada por STORY-019 (a fila de aprovação faz dispatch); aqui o conteúdo do e-mail é construído e renderizado, e os e-mails efetivamente chegam ao destinatário. Também ativa o lembrete de **completar cadastro** quando o usuário fica `liberado` por mais de N horas sem progredir (job agendado), e finaliza o fluxo Fortify de reset de senha que STORY-016 deixou como stub.

A estória é vertical mesmo sem UI dedicada — atravessa: job/queue (lembrete), ACL+adapter do provedor (envio), template visual do e-mail (HTML + texto plain), e a integração com inbox local em dev/teste E2E. O Designer entra para garantir que o template visual segue identidade do DDR-001 (logo, paleta clara/escura para clients de e-mail que respeitam).

- Épico: `docs/project-state/epics/EPIC-001-cadastro-e-aprovacao/epic.md`
- Documentos canônicos a ler ANTES de codificar:
  - `docs/project-state/decisions/adr/ADR-011-provedor-email-transacional-e-acl.md` (STORY-014)
  - `docs/project-state/decisions/adr/ADR-007-auth-base-e-roteamento.md` §f (Fortify reset de senha)
  - `docs/project-state/decisions/adr/ADR-008-observabilidade-minima.md` §mascaramento (e-mail destinatário não vai em log claro)
  - `docs/project-state/decisions/adr/ADR-004-hospedagem-iac-deploy.md` (Secret Manager para credencial do provedor)
  - `docs/especificacao/non-functional.md` §LGPD, §Segurança
  - `docs/project-state/design/screens/SCREEN-STORY-021-emails-transacionais.md` (Designer entrega — template visual de e-mail)
  - `docs/project-state/design/system/voice-and-tone.md`
  - `docs/skills/programador/SKILL.md`, `docs/skills/po/references/quality-standards.md`

## O quê (objetivo desta estória)

Implementar envio real das 3 mensagens canônicas:

1. **`aprovacao_concedida`** — disparado por STORY-019 quando admin aprova um cadastro.
   - Destinatário: o usuário aprovado (e-mail mascarado em logs).
   - Conteúdo: cumprimentar pelo nome; confirmar que o cadastro foi aprovado; explicar próximos passos ("complete seu cadastro para começar a usar"); CTA com **link assinado** que leva direto à rota `/welcome` no WebApp (gera login automático? — **não**, por segurança; usuário entra com e-mail+senha; o link apenas leva à URL pública de login com um identificador que pré-preenche o e-mail e direciona para `/welcome` após sucesso); rodapé com informação de contato e link da política de privacidade.
   - Versão **HTML** (com identidade DDR-001) e versão **texto plain** (acessibilidade + clients antigos).
   - Subject: "Seu cadastro Turni foi aprovado — vamos finalizar?" (alinhar voice-and-tone com Designer).

2. **`lembrete_completar_cadastro`** — job agendado que roda 1× por dia (sugestão: 09:00 horário Brasil — configurável):
   - Seleciona usuários `status = liberado, welcome_visto = true, cadastro_completo = false` com `aprovado_em < now() - 48h` e que **não receberam lembrete nas últimas 48h** (tabela auxiliar de envio para evitar spam).
   - Envia até **3 lembretes** total (48h, 5 dias, 14 dias após aprovação). Após 14 dias sem progresso, **para de enviar** e marca observação no audit log (`admin.user.cadastro_pendente_expirado` — para a equipe Turni poder olhar manualmente se quiser).
   - Conteúdo: tom amigável, lembra do CTA "completar cadastro"; sem chantagem.
   - Subject: "Falta pouco — complete seu cadastro Turni".

3. **`recuperacao_senha`** — finaliza o stub deixado em STORY-016 com Fortify default:
   - Fluxo: usuário no `/login` clica "Esqueci minha senha", informa e-mail, submit → Fortify gera link assinado (TTL 60 min — ADR-007) e dispara via ACL.
   - Resposta sempre "Se este e-mail está cadastrado, enviamos as instruções" — sem leak (segurança).
   - Conteúdo: link de reset, validade, instruções de segurança ("se você não solicitou, ignore"), rodapé.
   - Subject: "Recuperação de senha — Turni".

**Camadas e infra**:

4. **ACL implementada** conforme ADR-011 (interface `SendTransactionalEmail` ou nome equivalente no domínio compartilhado). Adapter concreto do provedor escolhido. Credencial via Secret Manager.
5. **Fila** (`database` driver — ADR-002): todos os envios passam por job na fila, com retry/backoff/dead-letter conforme ADR-011.
6. **Inbox local em dev** (Mailpit ou equivalente conforme ADR-011) já no docker-compose; teste local pega e-mails no inbox visual.
7. **Configuração de domínio remetente** em homolog: SPF/DKIM/DMARC aplicados no DNS conforme ADR-011 (Terraform — `infra/envs/homolog/`).
8. **Log estruturado** (ADR-008) por envio: `email.sent` com tipo, destinatário **mascarado**, message_id do provedor, latência. **Nunca** loga corpo completo. Falha de envio: `email.failed` com causa, e nas falhas críticas (aprovação concedida, reset) gera alerta ao admin.
9. **Audit log** (ADR-009): nenhum evento novo nesta estória (envio de e-mail é operação de sistema, não ação de admin). Reset de senha pelo próprio usuário também não é audit log de admin.

## Por quê (valor para o usuário)

Direto: o profissional/contratante **recebe** a notícia de aprovação e consegue voltar à plataforma. Hoje (até STORY-019) a aprovação acontece em silêncio — o usuário não sabe que foi aprovado. Indireto: lembretes reduzem abandono pós-aprovação; reset de senha torna o login realmente recuperável (sem isso, perder a senha é perder a conta). Para a equipe Turni: o envio é assíncrono e robusto — falhas pontuais do provedor não derrubam o fluxo de aprovação (a fila retenta), e falhas persistentes geram alerta.

## Critérios de aceite

- [ ] **CA-1:** ACL implementada conforme ADR-011: interface `SendTransactionalEmail` (ou nome equivalente) em `packages/domain`; adapter concreto do provedor isolado. Troca de provedor = trocar adapter.
- [ ] **CA-2:** Credencial do provedor em Secret Manager (ADR-004). Nenhum segredo em código (`quality-standards.md` §4); gitleaks verifica no pré-push.
- [ ] **CA-3:** Configuração de domínio remetente em homolog: SPF, DKIM, DMARC com registros DNS exatos aplicados via Terraform; verificação via ferramenta externa (ex.: mxtoolbox) registrada como evidência no runbook.
- [ ] **CA-4:** **`aprovacao_concedida`**: ao admin aprovar (STORY-019), e-mail é enfileirado, processado pelo worker, entregue ao inbox visual em dev e ao provedor real em homolog. Versão HTML segue DDR-001; versão texto plain funcional. Subject correto. Mensagem personalizada com nome do usuário.
- [ ] **CA-5:** **`lembrete_completar_cadastro`**: job agendado roda em horário definido; seleciona usuários elegíveis; envia até 3 lembretes (48h/5d/14d); registra em tabela auxiliar para evitar duplicação; **para** após 14 dias e marca observação. Teste cobre a regra de 3 lembretes.
- [ ] **CA-6:** **`recuperacao_senha`**: fluxo Fortify funciona ponta a ponta — usuário no `/login` clica "Esqueci minha senha", informa e-mail, recebe link válido por 60 min, clica no link, define nova senha, consegue logar. Throttling de pedidos (ADR-007 §f) ativo.
- [ ] **CA-7:** Resposta de "Esqueci minha senha" **nunca revela** se o e-mail existe (sempre "Se este e-mail está cadastrado, enviamos as instruções" — segurança).
- [ ] **CA-8:** Fila: envio falhado tenta 3× com backoff exponencial (ou estratégia equivalente de ADR-011); após retries, vai para dead letter; falha de `aprovacao_concedida` ou `recuperacao_senha` gera alerta para admin (e-mail/canal definido em ADR-011).
- [ ] **CA-9:** Log estruturado por envio com e-mail destinatário **mascarado** (verificar em homolog que e-mail real **não** aparece em log claro do Cloud Logging).
- [ ] **CA-10:** Templates HTML têm fallback text/plain; ambos os formatos são entregues (multipart/alternative).
- [ ] **CA-11:** Acessibilidade: HTML do e-mail tem semântica adequada (estrutura de heading, alt em imagens, contraste WCAG AA); funciona em leitor de tela básico.
- [ ] **CA-12:** Cobertura unitária ≥ 80% no código novo / ≥ 98% no núcleo (job de lembrete, retry, mascaramento de log, renderização de template).
- [ ] **CA-13:** **E2E em browser real**: (a) admin aprova um cadastro de teste no Backoffice; espera 30s; inbox de teste em homolog recebe o e-mail correto com conteúdo certo; (b) usuário clica em "Esqueci minha senha" no WebApp, recebe e-mail com link, troca senha, loga com nova senha.
- [ ] **CA-14:** Idempotência: enfileirar o mesmo envio 2× **não** envia 2× (use `idempotency_key` baseado em `evento + user_id` ou estratégia equivalente — sua decisão, registrada em IDR).

## Fora de escopo

- Notificações push/Slack ao usuário — fora do MVP.
- Notificação SMS — fora do MVP.
- Templates de e-mail para outros eventos (match, candidatura, check-in, disputa) — fora do EPIC-001; chegam nos épicos respectivos consumindo a mesma ACL.
- Editor de templates de e-mail no backoffice — fora do MVP; textos ficam em código.
- A/B test de subject — fora do MVP.

## Padrões de qualidade exigidos

`quality-standards.md`. Em particular:

- **Cobertura ≥ 80% / ≥ 98% núcleo** (job lembrete, retry, mascaramento, idempotência, renderização).
- **E2E em browser real** cobrindo CA-13 na pipeline de homolog.
- **TDD** nas regras.
- **Segurança (§4)**: credencial em Secret Manager; nenhum segredo em código; resposta de "Esqueci minha senha" sem leak; throttling Fortify ativo; gitleaks verde no pré-push.
- **LGPD**: e-mail destinatário e nome no corpo são dado pessoal; logs mascarados; lembrete pode ser interpretado como comunicação operacional necessária (não marketing).
- **Observabilidade (§3)**: log estruturado por envio; métricas: taxa de envio, taxa de falha, latência p95; alertas em falha de mensagem crítica (aprovação, reset).
- **Banco**: tabela auxiliar de lembretes idempotente e reversível.

## Dependências

- **Bloqueada por:** STORY-014 (ADR-011 `accepted` — provedor e ACL). STORY-016 (Fortify ligado; tabela de usuários funcional). STORY-019 (trigger de `aprovacao_concedida` enfileira por lá — o dispatch existe ao final dela; o consumo real do dispatch e a entrega visual final é desta estória). Designer entrega `SCREEN-STORY-021-emails-transacionais` em `ready`.
- **Bloqueia:** STORY-022 (welcome consome o link assinado do e-mail de aprovação concedida — verificar coordenação), STORY-025 (validação).
- **Pré-requisitos:** STORY-006, STORY-007.

## Decisões já tomadas (não as reabra)

- **ADR-011** — provedor escolhido, ACL, configuração de domínio remetente.
- **ADR-007** — Fortify para reset; throttling; resposta sem leak.
- **ADR-008** — log estruturado com mascaramento.
- **ADR-004** — Secret Manager.
- **PDR-001** — usuário removido **não** recebe e-mail.
- **ADR-002** — fila `database`.

## Liberdade técnica do agente

Você decide:
- Engine de template de e-mail (Blade do Laravel é caminho idiomático; sua decisão se diferente).
- Estrutura HTML responsiva (sugestão: tabelas inline — clients de e-mail antigos ainda usam tabelas).
- Identificador exato do `idempotency_key`.
- Frequência exata do job de lembrete (cron string).
- Estratégia de marcação "já enviou lembrete" (tabela auxiliar dedicada vs flag em users — recomendação: tabela auxiliar, mais flexível).

Você NÃO decide:
- Trocar provedor (ADR-011).
- Suprimir cobertura, E2E, mascaramento, SPF/DKIM/DMARC, ou throttling.
- Adicionar evento ao audit log de admin para envios automáticos (não são ação de admin).

## Definição de Pronto (DoD)

- [ ] CA-1 a CA-14 passam com evidência.
- [ ] Cobertura medida no PR.
- [ ] E2E verde na pipeline de homolog.
- [ ] SPF/DKIM/DMARC verificados (CA-3) com print de ferramenta externa no runbook.
- [ ] Inbox de homolog recebeu e-mails reais de teste — capturas no PR.
- [ ] Sync Designer↔Programador registrado.
- [ ] `index.json` atualizado.
- [ ] "Notas" preenchida.
- [ ] IDR se houve decisão técnica relevante.

## Protocolo do agente (obrigatório)

Siga `docs/skills/po/references/agent-task-format.md`. Carregue `docs/skills/programador/SKILL.md`. Confirme screen spec em `ready`. TDD. PR com evidência. `done` após deploy verde + entrega real de e-mails de teste em homolog verificada.

## Notas do agente (preenchido durante/após execução)

### Entrada inicial
(a preencher)

### Sync Designer↔Programador
(a preencher)

### Decisões tomadas
(a preencher)

### Descobertas
(a preencher)

### Bloqueios encontrados
(a preencher)

### IDRs criados
(a preencher)

### Cobertura final
(a preencher)

### Resultado final / evidência
(a preencher)

### Pendências para fechar
(a preencher)

### Links de evidência
(a preencher)
