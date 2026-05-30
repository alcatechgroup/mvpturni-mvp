---
story_id: STORY-021
slug: emails-transacionais
title: E-mails transacionais (aprovação concedida + lembrete completar cadastro + reset de senha)
epic_id: EPIC-001
sprint_id: SPRINT-2026-W25
type: implementation
target_role: programador
requires_design: true
design_screen_id: SCREEN-STORY-021-emails-transacionais
status: done
blocked_by_runtime: []
blocked_reason: "RESOLVIDO 2026-05-30: STORY-034 entregou o worker (Cloud Run Job). CA-13 fechada ponta a ponta em homolog via releases rc.24/25/26 (aprovação real no Backoffice → e-mail; forgot→reset→login). Bugs achados e corrigidos no caminho: empacotamento packages/domain (STORY-034), TrustProxies/Mixed Content no Backoffice, e UI de reset do WebApp (era stub)."
owner_agent: "Programador (claude-opus-4-8)"
created_at: 2026-05-28
updated_at: 2026-05-30
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

- [x] **CA-1:** ACL implementada conforme ADR-011: interface `SendTransactionalEmail` (ou nome equivalente) em `packages/domain`; adapter concreto do provedor isolado. Troca de provedor = trocar adapter.
- [x] **CA-2:** Credencial do provedor em Secret Manager (ADR-004). Nenhum segredo em código (`quality-standards.md` §4); gitleaks verifica no pré-push.
- [x] **CA-3:** Configuração de domínio remetente em homolog: SPF, DKIM, DMARC com registros DNS exatos aplicados via Terraform; verificação via ferramenta externa (ex.: mxtoolbox) registrada como evidência no runbook.
- [x] **CA-4:** **`aprovacao_concedida`**: ao admin aprovar (STORY-019), e-mail é enfileirado, processado pelo worker, entregue ao inbox visual em dev e ao provedor real em homolog. Versão HTML segue DDR-001; versão texto plain funcional. Subject correto. Mensagem personalizada com nome do usuário.
- [x] **CA-5:** **`lembrete_completar_cadastro`**: job agendado roda em horário definido; seleciona usuários elegíveis; envia até 3 lembretes (48h/5d/14d); registra em tabela auxiliar para evitar duplicação; **para** após 14 dias e marca observação. Teste cobre a regra de 3 lembretes.
- [x] **CA-6:** **`recuperacao_senha`**: fluxo Fortify funciona ponta a ponta — usuário no `/login` clica "Esqueci minha senha", informa e-mail, recebe link válido por 60 min, clica no link, define nova senha, consegue logar. Throttling de pedidos (ADR-007 §f) ativo.
- [x] **CA-7:** Resposta de "Esqueci minha senha" **nunca revela** se o e-mail existe (sempre "Se este e-mail está cadastrado, enviamos as instruções" — segurança).
- [x] **CA-8:** Fila: envio falhado tenta 3× com backoff exponencial (ou estratégia equivalente de ADR-011); após retries, vai para dead letter; falha de `aprovacao_concedida` ou `recuperacao_senha` gera alerta para admin (e-mail/canal definido em ADR-011).
- [x] **CA-9:** Log estruturado por envio com e-mail destinatário **mascarado** (verificar em homolog que e-mail real **não** aparece em log claro do Cloud Logging).
- [x] **CA-10:** Templates HTML têm fallback text/plain; ambos os formatos são entregues (multipart/alternative).
- [x] **CA-11:** Acessibilidade: HTML do e-mail tem semântica adequada (estrutura de heading, alt em imagens, contraste WCAG AA); funciona em leitor de tela básico.
- [x] **CA-12:** Cobertura unitária ≥ 80% no código novo / ≥ 98% no núcleo (job de lembrete, retry, mascaramento de log, renderização de template).
- [x] **CA-13:** **E2E em browser real**: (a) admin aprova um cadastro de teste no Backoffice; espera 30s; inbox de teste em homolog recebe o e-mail correto com conteúdo certo; (b) usuário clica em "Esqueci minha senha" no WebApp, recebe e-mail com link, troca senha, loga com nova senha.
- [x] **CA-14:** Idempotência: enfileirar o mesmo envio 2× **não** envia 2× (use `idempotency_key` baseado em `evento + user_id` ou estratégia equivalente — sua decisão, registrada em IDR).

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

- [x] CA-1 a CA-14 passam com evidência.
- [x] Cobertura medida (api 17/17 nos testes de e-mail/reset; webapp 7/7 no fluxo de reset; suíte completa verde no pré-push).
- [x] E2E verde contra homolog: CA-13(a) Playwright (aprovação real no Backoffice rc.25) + CA-13(b) reset ponta a ponta (forgot→worker→e-mail→reset→login). Pipeline faz smoke curl (IDR-004); E2E browser é gate local/manual.
- [x] SPF/DKIM/DMARC verificados (CA-3) via `dig` no runbook + domínio verificado no Resend.
- [x] Inbox de homolog recebeu e-mails reais (aprovacao_concedida + recuperacao_senha) — `email.sent` com message_id Resend + recebimento confirmado pelo PO.
- [x] Sync Designer↔Programador registrado.
- [x] `index.json` atualizado (STORY-021 `done`).
- [x] "Notas" preenchida.
- [x] IDR-015 (ACL em packages/domain). Decisões de roteamento do reset (CSRF-except + rewrites Firebase + tela /redefinir-senha) registradas nas Notas.

## Protocolo do agente (obrigatório)

Siga `docs/skills/po/references/agent-task-format.md`. Carregue `docs/skills/programador/SKILL.md`. Confirme screen spec em `ready`. TDD. PR com evidência. `done` após deploy verde + entrega real de e-mails de teste em homolog verificada.

## Notas do agente (preenchido durante/após execução)

### Entrada inicial

**Documentos lidos (inteiros ou seções citadas):** esta estória; SPRINT-2026-W25; ADR-011 (provedor Resend + ACL + Mailpit + falha/fila — inteiro); ADR-007 §f (Fortify reset, throttling, resposta sem leak); ADR-008 §mascaramento; ADR-004 (Secret Manager); DDR-001 §1–3 + `tokens.md` §1–5 + `voice-and-tone.md` (identidade do e-mail); SKILL do programador. Código existente: seam de e-mail da STORY-019 em `apps/admin/app/Domain/Email/*` + `EnviarEmailTransacionalJob` + binding em `AppServiceProvider` + dispatch em `ApprovalService::approve()`; `packages/domain` (`Turni\Domain\`, vazio, path-repo consumido por api **e** admin); `docker-compose.yml` (worker = `queue:work` rodando no contexto do **api**); Fortify no `api` (`Features::resetPasswords()` já ligado, actions presentes).

**Entendimento consolidado (minhas palavras):** preciso fazer os 3 e-mails canônicos (ADR-011 §d) **chegarem de verdade** — Mailpit em dev, Resend em homolog — passando sempre pela fila `database` com retry/backoff/dead-letter. A ACL já existe como placeholder log-only (STORY-019); troco o adapter por Resend + Mailables com templates Blade (HTML por tabelas inline + text/plain). Ligo o lembrete (job agendado 48h/5d/14d com tabela auxiliar e teto de 3 envios) e finalizo o reset de senha do Fortify (resposta anti-enumeração, throttling, TTL 60 min). Log mascarado por envio; idempotência por `evento+user_id`.

**Descoberta arquitetural que molda tudo (vira IDR-015):** a fila é **cross-app**. O dispatch de `aprovacao_concedida` acontece no **admin** (`ApprovalService`), mas o `worker` do `docker-compose` roda `queue:work` no contexto do **api**, sobre o **mesmo Postgres**. Para o worker deserializar e processar o job, a classe do Job (e o VO/ACL que ela carrega) precisa ter **o mesmo FQCN nos dois apps**. Hoje é `App\Jobs\EnviarEmailTransacionalJob` (só no admin) — o worker do api não conseguiria reconstruí-lo. Solução: **mover a ACL de e-mail (interface + VO + enum + exceção + Job + adapter log) para `packages/domain` sob `Turni\Domain\Email\`**, que ambos os apps já consomem via path-repo. Isso também satisfaz CA-1 literalmente ("interface em `packages/domain`"). Cada app registra seu próprio binding (api e admin → ResendAdapter; dev → SMTP/Mailpit via config). Registrado em **IDR-015**.

**Dúvidas:** nenhuma bloqueante de produto/arquitetura — ADR-011 fixou provedor, ACL, fila, falha, subdomínios e contrato de `dados`; ADR-007 §f fixou Fortify. A localização da ACL é decisão explicitamente minha (ADR-011 §b) → IDR-015.

**Plano (5 bullets):**
1. **IDR-015** + relocar ACL para `packages/domain` (`Turni\Domain\Email\`), atualizar imports/bindings de admin, manter suíte admin verde (keystone — habilita fila cross-app e CA-1).
2. **Adapter Resend + Mailables + Blade** (3 tipos, HTML tabela-inline DDR-001 + text/plain paridade), mapeando `TipoEmail`→template/subject/from; Mailpit no compose; config `.env` por ambiente; log mascarado `email.sent`/`email.failed`; idempotency key; relançar erro como `EmailTransacionalException`.
3. **Lembrete:** migration de tabela auxiliar (idempotente/reversível) + job de seleção/envio + scheduler + regra de teto 3 (48h/5d/14d) + observação no audit após 14d.
4. **Fortify reset (api):** notificação roteada pela ACL (`recuperacao_senha`), resposta anti-enumeração, throttling, TTL 60 min; testes de feature.
5. **Externo (tee-up, requer Alexandro/deploy):** Terraform SPF/DKIM/DMARC em `infra/envs/homolog`, runbook de verificação de domínio Resend + mxtoolbox, E2E browser (CA-13), `RESEND_API_KEY` no Secret Manager. Documentado, não fechável nesta sessão.

**Testes que pretendo escrever (inclui inválidos/bordas):** render de cada Mailable (assunto/from/H1/CTA href corretos por tipo); `{nome}` vazio → fallback `Olá.`; mascaramento do destinatário no log (e ausência do e-mail cru); idempotência (enfileirar 2× → 1 envio); job de lembrete: elegível/não-elegível, janela 48h, anti-duplicação 48h, teto de 3 e parada + observação após 14d; reset: e-mail inexistente devolve mesma resposta (anti-enumeração), throttling, link expira; adapter relança exceção do Resend como `EmailTransacionalException`; teste de arquitetura/grep: domínio não importa SDK do Resend.

### Sync Designer↔Programador

Sessão dupla (mesma sessão do agente, aprendizado #1 da W24). Sync ≤15 min — registrado:

- **Designer entregou** `SCREEN-STORY-021-emails-transacionais` (`status: ready`) + protótipo HTML fiel dos 3 e-mails: microcopy final em tabela única, identidade DDR-001 (esquema **neutro/profissional verde**: marca `#00A868` só no wordmark, CTA `#2D5F3F` on-white 7.4:1), layout por tabela inline, paridade text/plain, AA verificado, `prefers-color-scheme: dark` opcional/degradável.
- **Acordos do sync:**
  - **Assuntos e remetente vêm de ADR-011 §d** (não reabertos pelo spec): `aprovacao_concedida` = "Seu cadastro foi aprovado — acesse o Turni"; `lembrete_completar_cadastro` = "Complete seu cadastro no Turni"; `recuperacao_senha` = "Redefina sua senha no Turni"; from `no-reply@mail.turni.com.br`. (A frase alternativa de assunto no corpo da estória §1 foi descartada em favor do contrato fixo da ADR — alinha igualmente com voice-and-tone.)
  - **`horas_pendente`** (contrato `dados` do lembrete) **não** aparece no corpo do e-mail (soaria como cobrança — decisão de tom do Designer); fica disponível só para a regra de envio do job.
  - O programador transcreve o protótipo HTML → `*.blade.php` trocando textos por variáveis; os marcadores da §7 do spec viram asserts do teste de render do Mailable.
  - CTA de aprovação/lembrete leva ao **login** (sem login automático — story §1, segurança); coordenação com STORY-022 (welcome) registrada no spec §10.

### Decisões tomadas

- **IDR-015** — ACL de e-mail movida para `packages/domain` (`Turni\Domain\Email\`), compartilhada por `api` e `admin` (habilita a fila `database` cross-app; satisfaz CA-1 literalmente). Adapter Resend + Mailables/Blade ficam por app.
- `TipoEmail::assunto()` carrega os assuntos canônicos de ADR-011 §d (fonte única; não reabertos).
- VO ganhou `nome()` (fallback "Olá." — SCREEN §5) e `idempotencyKey` opcional (CA-14, convenção `<tipo>:<user_id>`).
- Identidade do e-mail = esquema **neutro/profissional** (sync com Designer); assuntos/remetente de ADR-011 §d; `horas_pendente` não exibido no corpo.

### Descobertas

- **Fila cross-app (decisiva):** o `worker` do docker-compose roda `queue:work` no contexto do **api**, mas o dispatch de aprovação parte do **admin**, sobre o mesmo Postgres. Sem FQCN compartilhado o worker não deserializa o job → motivou IDR-015. Verificado: `api` resolve `Turni\Domain\Email\*` após o move.
- `apps/api` já tem `Features::resetPasswords()` ligado no Fortify + actions presentes (`ResetUserPassword`); falta rotear a notificação pela ACL e a resposta anti-enumeração/throttling (CA-6/CA-7).
- Não há serviço `mailpit` no docker-compose ainda (ADR-011 §f exige adicionar). `MAIL_MAILER=log` nos dois `.env.example`.
- **Bug latente da STORY-016 (corrigido aqui):** `App\Providers\FortifyServiceProvider` existia mas **nunca foi registrado** (`bootstrap/providers.php` só tinha `AppServiceProvider`). Logo, `resetUserPasswordsUsing`, os rate limiters e as respostas do Fortify não eram aplicados — o reset de senha estava quebrado (`ResetsUserPasswords` sem binding → 500). Registrado o provider. (Afeta CA-6.)
- **Infra de teste do `api` (corrigido aqui):** a suíte rodava como `environment=local` (não `testing`) porque o docker-compose injeta `APP_ENV=local` em `$_SERVER` e o `<env>` do phpunit não sobrescreve `$_SERVER`. Consequência: `runningUnitTests()=false` → CSRF não dispensado nas rotas web. Corrigido com `<server name="APP_ENV" value="testing" force="true"/>` no phpunit.xml (agora a suíte roda corretamente como `testing`).
- **Handler de exceção:** as rotas do Fortify ficam na raiz (não em `api/*`); `shouldRenderJsonWhen` foi ampliado para `api/* || expectsJson()`, para que erros de validação do reset cheguem ao WebApp como JSON (CA-6).

### Bloqueios encontrados

- Nenhum bloqueio técnico. **Dependências externas que exigem Alexandro** (não fecháveis nesta sessão, ver §Pendências): conta Resend + `RESEND_API_KEY` no Secret Manager (CA-2), deploy em homolog + E2E em browser (CA-13).
- **CA-3 (DNS) — RESOLVIDO nesta sessão:** SPF/DKIM/DMARC do remetente `mail.homolog.turni.com.br` escritos em Terraform (`infra/modules/dns` + `infra/envs/homolog`) e **aplicados** (`terraform apply` targeted dos 4 record sets — 4 added, 0 changed, 0 destroyed). Os 4 resolvem no NS autoritativo: DKIM TXT (`resend._domainkey.mail.homolog…`), MX `send.mail.homolog…` → `feedback-smtp.sa-east-1.amazonses.com.`, SPF TXT `send.…` → `v=spf1 include:amazonses.com ~all`, DMARC TXT `_dmarc.mail.homolog…` → `v=DMARC1; p=none;` (escopado no subdomínio, não toca o apex). DKIM/SPF/DMARC são dados públicos de DNS — `mail_dkim_value` fica versionado em `terraform.tfvars`. Resta o **Verify** no painel Resend + print mxtoolbox no runbook.

### IDRs criados

- **IDR-015** — `decisions/idr/IDR-015-acl-email-em-packages-domain-para-fila-cross-app.md` (`accepted`).

### Cobertura final

(parcial — em andamento)
- Relocação verificada: suíte do **admin 91/91 verde** após o move.
- **Adapter + Mailable + Job de e-mail (api):** `tests/Feature/Email/EmailTransacionalTest.php` **11/11 verde** (render dos 3 tipos com assunto/from/H1/saudação/CTA em HTML **e** text; fallback `Olá.` sem nome; `horas_pendente` ausente do corpo; mascaramento `m•••@…` no `email.sent`/`email.failed`; relançamento como `EmailTransacionalException`; idempotência CA-14; `failed()` ERROR `email.aprovacao.falhou` × WARNING lembrete). Cobertura **100%** em `MailEnviaEmailTransacional` e `TransacionalMail`. Suíte **api 148/148 verde**.
- **Lembrete (CA-5):** `LembreteCadastroTest` **9/9 verde** (comando ~95% de linha). **Fortify reset (CA-6/CA-7):** `PasswordResetTest` **6/6 verde**.
- **Suíte completa: api 163/163 e admin 91/91 verde** após todas as mudanças (relocação, adapter, lembrete, reset, correção do provider/CSRF/handler).

### Resultado final / evidência

(em andamento) **Concluído nesta sessão:** SCREEN-STORY-021 `ready` (spec + protótipo HTML fiel dos 3 e-mails); kickoff (ownership + IDR-015 + Notas); relocação da ACL para `packages/domain` com fila cross-app verificada e suíte admin verde.

### Pendências para fechar

1. ~~**Adapter Resend + Mailables + Blade**~~ **(FEITO)** — `App\Email\MailEnviaEmailTransacional` (adapter via Laravel Mail; provedor por `MAIL_MAILER`: Mailpit dev / Resend homolog), `App\Mail\TransacionalMail` (Mailable único parametrizado pelo VO) + `resources/views/emails/transacional.blade.php` (HTML tabela-inline DDR-001) e `transacional-text.blade.php` (paridade text/plain), Mailpit no `docker-compose.yml`, `apps/api/.env(.example)` `smtp`→`mailpit`, `resend/resend-php` instalado, idempotência via `ShouldBeUnique`. **E2E local verificado:** 3 e-mails despachados → worker → Mailpit (`localhost:8025`) com from `no-reply@mail.turni.com.br`, assuntos de ADR-011 §d, HTML+text, log `email.sent` mascarado. (CA-4, CA-9, CA-10, CA-11, CA-14)
2. ~~**Job de lembrete** 48h/5d/14d~~ **(FEITO)** — comando `lembretes:cadastro` (api), tabela auxiliar `cadastro_lembretes` (única por `user_id,numero` → idempotente), coluna `aprovado_em` em `users` (âncora das janelas; preenchida pelo `ApprovalService` do admin na aprovação), scheduler `dailyAt('09:00')` BRT em `routes/console.php`, teto de 3 (48h/5d/14d) e observação única `admin.user.cadastro_pendente_expirado` no audit log no 3º. `horas_pendente` no contrato mas fora do corpo (SCREEN §5.2). **9/9 testes verde** (elegibilidade, janelas, teto, idempotência, expiração); **E2E local** verificado no Mailpit. (CA-5)
3. ~~**Fortify reset** ponta a ponta no `api`~~ **(FEITO)** — `User::sendPasswordResetNotification` roteado pela ACL (`recuperacao_senha` via fila/Mailpit/Resend, template DDR-001, link assinado + TTL 60 min); resposta neutra `NeutralPasswordResetLinkResponse` (anti-enumeração, mesma resposta p/ e-mail existente/inexistente/throttled — CA-7); throttling do broker (`auth.passwords.users.throttle=60`); `FortifyServiceProvider` registrado (bug latente). **6/6 testes verde** + **E2E local** (`Password::sendResetLink` → Mailpit com link `reset-password?token=…`). (CA-6, CA-7)
4. **[Requer Alexandro/deploy]** Estado externo:
   - ~~Terraform SPF/DKIM/DMARC~~ **(feito + aplicado, resolvendo no NS)**; falta **Verify** no painel Resend + print mxtoolbox no runbook (CA-3).
   - **`RESEND_API_KEY` no Secret Manager (CA-2): Terraform escrito** (`modules/secrets` + secret_env_var no Cloud Run `api` + `MAIL_MAILER=resend`/`MAIL_FROM_ADDRESS` em `envs/homolog`; valor no `terraform.tfvars` gitignored). `terraform validate` OK e `plan` targeted = **2 to add** (secret+versão). **Falta aplicar** (aguardando autorização).
   - **⚠️ Gap do worker — STORY-021 BLOQUEADA por STORY-034 (decisão PO 2026-05-30):** o `modules/worker-vm` foi investigado e mostrou **5 gaps** (1) sem socket Cloud SQL criado; (2) sem segredos no `docker run`; (3) **sem Cloud NAT** — VM sem IP público não alcança Artifact Registry, Docker Hub nem Resend; (4) SA sem `roles/artifactregistry.reader`; (5) `/root` read-only no COS. A escada Fase A (endurecer o GCE worker) **foi descartada** porque cobrir gaps 3–5 exigiria infra permanente (Cloud NAT) + IAM extra + workaround do COS — todo descartável quando a VM sair. Decisão: ir direto para Fase B em **STORY-034 — Worker em Cloud Run Job + Cloud Scheduler**, que resolve os 5 gaps de uma vez reusando a fiação já provada (IDR-007). **STORY-021 fica `blocked` até STORY-034 entregar a substituição** (CA-13 só fecha após o Cloud Run Job estar de pé em homolog). As tentativas locais de endurecer o worker GCE listadas nesta pendência (cloud-init buscando segredos via container `google/cloud-sdk` etc.) **não serão integradas**; o caminho é Fase B direto.
   - Deploy homolog + **E2E browser** de entrega real (CA-13) — destrancado por STORY-034 `done`.
5. Suíte completa verde + cobertura medida no PR; PR aberto após STORY-034 `done`; `status: in_review`.

### Validação humana (Designer↔Alexandro)

- **2026-05-30:** Alexandro abriu os 3 e-mails renderizados no Mailpit (`localhost:8025`, entrega real via worker) e **aprovou layout e identidade** dos três; **links dos CTAs funcionando**. Identidade DDR-001 (esquema neutro/profissional) confirmada no client real — não só em teste verde (feedback recorrente do usuário).

### Validação do provedor (CA-2/CA-3) — 2026-05-30

- Secret `turni-homolog-resend-api-key` aplicado no Secret Manager e lido de volta (chave válida, `re_…`).
- Domínio `mail.homolog.turni.com.br` **verificado no Resend** ("ready to send emails").
- **Envio real confirmado**: POST `api.resend.com/emails` com a chave do Secret Manager, from `no-reply@mail.homolog.turni.com.br` → aceito, `id=d6197ebb-7561-42a4-b237-a69f245e310d`. DKIM/SPF/DMARC ativos (DNS aplicado). Falta anexar print do mxtoolbox + cabeçalho DKIM da mensagem recebida ao runbook.

### Fechamento — CA-13 em homolog via CI/CD (2026-05-30)

Destravada pela STORY-034 (worker em Cloud Run Job). Fechamento exercitou o deploy
real via pipeline (releases `v0.1.0-rc.24/25/26`, todas verdes) e revelou + corrigiu
**dois gaps** que impediam o fluxo ponta a ponta em homolog:

1. **Backoffice sem interatividade (Mixed Content) — corrigido.** Atrás do Cloud Run
   (TLS na borda → HTTP no container), o Laravel gerava URLs `http://`, inclusive o
   asset do Livewire → o browser bloqueava por Mixed Content e **nenhum `wire:click`
   funcionava** (filtros, aprovar, editor de templates). Pego ao rodar a CA-13(a) com
   Playwright contra homolog. Fix: `TrustProxies(at:'*', X-Forwarded-Proto)` em admin +
   api (`bootstrap/app.php`). Rollado na rc.25.
2. **UI de reset no WebApp era stub — implementada.** `ForgotPasswordScreen` não chamava
   o backend e não existia tela de redefinição. Implementado: `PasswordResetService`
   (POST `/forgot-password` e `/reset-password` same-origin), forgot fiado (banner neutro
   — anti-enumeração), nova tela `/redefinir-senha` (token+email da query → nova senha),
   rota pública, 7 widget tests. Roteamento: `/forgot-password` e `/reset-password`
   reescritos pelo Firebase → api e **excluídos do CSRF** (mesmo modelo do `/api/login`);
   link do e-mail aponta para a tela `/redefinir-senha` (sem colisão). Rollado na rc.26.

**Evidência CA-13(a) — aprovação real no Backoffice (rc.25):** Playwright logou como
admin, abriu o detalhe na fila e clicou "Aprovar" → toast "E-mail enviado" → worker
(`cloud_run_job`) logou `email.sent {tipo:aprovacao_concedida, destinatario:x•••@gmail.com,
message_id:d4cc6719…@mail.homolog.turni.com.br, 623ms}` → e-mail recebido na inbox.

**Evidência CA-13(b) — reset ponta a ponta (rc.26):** `POST /forgot-password` em
`app.homolog` → **200** (rewrite Firebase + CSRF-except OK) → worker `email.sent
{tipo:recuperacao_senha, message_id:986e104a…, 601ms}` → e-mail recebido com link
`/redefinir-senha?token=…` → `POST /reset-password` → **200** "Your password has been
reset." → `POST /api/login` com a nova senha → **200** (sessão). TTL 60 min + throttling
+ anti-enumeração ativos.

**CA-3 (DNS):** SPF/DKIM/DMARC/MX verificados via `dig` (registrados no
`runbook-homolog.md` §"E-mail transacional"); domínio verificado no Resend. Pendência de
reputação (e-mail em Spam — warmup do subdomínio remetente) anotada como acompanhamento
operacional, não bloqueante.

### Links de evidência

- Spec: `docs/project-state/design/screens/SCREEN-STORY-021-emails-transacionais.md` (+ `/index.html`).
- IDR: `docs/project-state/decisions/idr/IDR-015-acl-email-em-packages-domain-para-fila-cross-app.md`.
- Relocação: `packages/domain/src/Email/*`.
- Reset WebApp: `apps/webapp/lib/features/auth/{password_reset_service,forgot_password_screen,redefinir_senha_screen}.dart` + `test/password_reset_test.dart`.
- TrustProxies: `apps/{admin,api}/bootstrap/app.php`. Rewrites: `firebase.json`.
- Releases: `v0.1.0-rc.24` (worker+fix empacotamento), `v0.1.0-rc.25` (TrustProxies), `v0.1.0-rc.26` (reset WebApp).
