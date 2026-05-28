---
epic_id: EPIC-001
type: validation-checklist
created_at: 2026-05-28
created_by: PO (Alexandro / Claude)
status: empty  # empty → in_progress (validador trabalhando) → filled
---

# Checklist de validação — EPIC-001 Cadastro e aprovação

> **Para o Validador da STORY-025**: preencha cada item com status (`pass` | `pass com ressalva` | `fail bloqueante` | `fail não-bloqueante` | `n/a`) e **evidência observável** (comando + saída, log, screenshot, query, URL de homolog testada). Não proponha estórias de correção; não sugira próximos passos; apenas fato + veredito. Aprendizado da rodada 1 da STORY-011 do EPIC-000.

---

## Pré-condições de início

- [ ] **PRE-1:** STORY-012 a STORY-024 com `status: done` no `index.json`.
- [ ] **PRE-2:** EPIC-001 com `status: in_review` no `index.json`.
- [ ] **PRE-3:** `app.homolog.turni.com.br` acessível e `admin.homolog.turni.com.br` (ou URL do Cloud Run conforme IDR-003) acessível ao admin.

---

## Bloco 1 — Critérios de aceite das estórias

### STORY-012 / STORY-013 / STORY-014 (Spikes do Arquiteto)
- [ ] **CA-B1-1:** ADR-009, ADR-010, ADR-011 existem em `decisions/adr/`, `status: accepted`, `approved_by: Alexandro` preenchido em todas. `index.json` reflete.

### STORY-015 (Texto-seed)
- [ ] **CA-B1-2:** Arquivos `docs/especificacao/contratos/template-pf-autonomo-eventual-v1.md` e `docs/especificacao/contratos/template-mei-pj-b2b-v1.md` existem, cobrem cláusulas materiais mínimas listadas, usam placeholders no formato de ADR-010, têm validação do Alexandro no rodapé.

### STORY-016 (RBAC vivo + login + funnel guard)
- [ ] **CA-B1-3:** Migração `role`/`status`/flags do funil aplicada em homolog; idempotente; reversível.
- [ ] **CA-B1-4:** `php artisan migrate:rollback` exercido em homolog (critério herdado F-NB-1 do EPIC-000) com evidência no runbook.
- [ ] **CA-B1-5:** Login admin no Backoffice em homolog funciona; cookie `httpOnly + Secure + SameSite=Lax` verificado.
- [ ] **CA-B1-6:** Login profissional no WebApp em homolog funciona; cookie SPA Sanctum correto.
- [ ] **CA-B1-7:** Admin tentando logar no WebApp é rejeitado com mensagem + link para admin.
- [ ] **CA-B1-8:** Não-admin tentando logar no Backoffice recebe 403 fail-secure.
- [ ] **CA-B1-9:** Fail-secure de host cruzado: cookie WebApp no host admin (ou vice-versa) é bloqueado.
- [ ] **CA-B1-10:** Funnel guard funciona: `liberado, welcome_visto=false` → `/welcome`; `liberado, welcome_visto=true, cadastro_completo=false` → `/completar-cadastro`; `ativo` → home.
- [ ] **CA-B1-11:** Audit log de admin recebe `admin.login` (sucesso e falha) na tabela. Verificação por query.
- [ ] **CA-B1-12:** Imutabilidade do audit log: tentativa de UPDATE/DELETE numa linha falha via psql.

### STORY-017 (Pré-cadastro Profissional)
- [ ] **CA-B1-13:** `/cadastro/profissional` em homolog renderiza com tema profissional; formulário válido.
- [ ] **CA-B1-14:** Os 3 tipos de pessoa (PF/MEI/PJ) podem ser registrados; usuário fica `pendente_aprovacao`.
- [ ] **CA-B1-15:** E-mail duplicado → erro genérico sem leak.
- [ ] **CA-B1-16:** Checkbox de aceite obrigatório bloqueia submit client + server.
- [ ] **CA-B1-17:** Pré-cadastro **não** coleta documento (CPF/CNPJ).
- [ ] **CA-B1-18:** Foto persistida com signed URL / path não enumerável.

### STORY-018 (Pré-cadastro Contratante)
- [ ] **CA-B1-19:** `/cadastro/contratante` em homolog renderiza com tema contratante; formulário válido.
- [ ] **CA-B1-20:** Submit cria contratante `pendente_aprovacao` sem CNPJ (coletado depois).
- [ ] **CA-B1-21:** Mesmas proteções de duplicidade, aceite, upload de STORY-017.

### STORY-019 (Fila de aprovação no Backoffice)
- [ ] **CA-B1-22:** `/aprovacoes` lista pendentes em FIFO com filtros (papel, tipo_pessoa) e contador agregado.
- [ ] **CA-B1-23:** Detalhe exibe todos os campos do pré-cadastro + template aplicável + versão ativa.
- [ ] **CA-B1-24:** "Aprovar" transiciona estado, grava `admin.user.approved` no audit log, dispara e-mail.
- [ ] **CA-B1-25:** "Remover" com confirmação dupla apaga o usuário (PDR-001) e grava `admin.user.removed`.
- [ ] **CA-B1-26:** Race condition: 2 admins aprovando o mesmo cadastro em abas distintas — segundo recebe erro claro.
- [ ] **CA-B1-27:** Indicador de SLA (verde/amarelo/vermelho) renderiza; não depende apenas de cor (WCAG).

### STORY-020 (Editor de templates)
- [ ] **CA-B1-28:** `/templates` lista os 2 templates com versão ativa, autor, data.
- [ ] **CA-B1-29:** Detalhe mostra versão ativa + histórico em ordem decrescente.
- [ ] **CA-B1-30:** Criar nova versão com placeholder inválido bloqueia.
- [ ] **CA-B1-31:** Ativação atômica: versão alvo `ativa=true` E anterior `ativa=false` ou nada muda.
- [ ] **CA-B1-32:** Audit log recebe `admin.template.version_created` e `admin.template.version_activated`.
- [ ] **CA-B1-33:** UPDATE/DELETE em `template_versoes` falha via psql.
- [ ] **CA-B1-34:** Seed inicial idempotente: rodar 2× → mesmos 2 templates com versão 1.

### STORY-021 (E-mails transacionais)
- [ ] **CA-B1-35:** SPF/DKIM/DMARC configurados em homolog; verificação externa (ex.: mxtoolbox) no runbook.
- [ ] **CA-B1-36:** `aprovacao_concedida` chega ao inbox de teste/provedor real em homolog.
- [ ] **CA-B1-37:** Job de lembrete envia até 3 e para após 14 dias; tabela auxiliar evita duplicação.
- [ ] **CA-B1-38:** Fluxo Fortify de reset de senha funciona ponta a ponta sem leak de existência.
- [ ] **CA-B1-39:** Logs mascarados (e-mail destinatário não em texto claro em Cloud Logging).

### STORY-022 (Welcome)
- [ ] **CA-B1-40:** `/welcome` renderiza tela real, personalizada pelo nome e papel.
- [ ] **CA-B1-41:** "Vamos lá" marca `welcome_visto = true` e redireciona a `/completar-cadastro`.
- [ ] **CA-B1-42:** "Fazer depois" faz logout sem marcar; próximo login mostra welcome de novo.
- [ ] **CA-B1-43:** Idempotência da marcação (no-op no servidor).

### STORY-023 (Completar cadastro Profissional + AceiteEletronico)
- [ ] **CA-B1-44:** `/completar-cadastro` renderiza para `liberado, welcome_visto=true`.
- [ ] **CA-B1-45:** Validação CPF (PF) / CNPJ (MEI/PJ) com dígitos verificadores; documento único.
- [ ] **CA-B1-46:** Chave Pix validada por tipo.
- [ ] **CA-B1-47:** Upload de documentos comprobatórios com MIME server-side e signed URLs.
- [ ] **CA-B1-48:** Dados sensíveis criptografados em repouso (psql não retorna texto claro).
- [ ] **CA-B1-49:** Preview do contrato com placeholders substituídos; checkbox + botão final habilitado só após preview.
- [ ] **CA-B1-50:** Aceite gerado: `template_versao_id` correto, `conteudo_renderizado` igual ao preview, transação atômica.
- [ ] **CA-B1-51:** Aceite imutável (UPDATE/DELETE em `aceites_eletronicos` falha via psql).
- [ ] **CA-B1-52:** Após aceite, usuário fica `ativo, cadastro_completo=true`.
- [ ] **CA-B1-53 (CENTRAL — PDR-012):** Cenário de imutabilidade após nova versão: criar aceite → admin ativa nova versão de template → aceite original ainda referencia versão original e renderiza texto original.

### STORY-024 (Completar cadastro Contratante + AceiteEletronico)
- [ ] **CA-B1-54:** Mesma régua de STORY-023, adaptada ao contratante (CNPJ obrigatório, endereço, segmento, cultura, contatos, logo opcional).
- [ ] **CA-B1-55:** Busca de CEP funciona; falha externa não bloqueia (degrada para entrada manual).
- [ ] **CA-B1-56:** Aceite usa versão ativa de `mei_pj_b2b`; transação atômica; imutável.
- [ ] **CA-B1-57:** Plano `Member Start` registrado na ativação.

---

## Bloco 2 — Cobertura de testes

- [ ] **CA-2-1:** Cobertura unitária geral ≥ 80% no código novo do EPIC-001 (medida por componente: api, admin, webapp, domain).
- [ ] **CA-2-2:** Cobertura ≥ 98% nos núcleos identificados (máquina de estado do usuário, ownership/policies, audit log writer, transação atômica do aceite, validação de tipo_pessoa/documento, renderização de template, mascaramento).
- [ ] **CA-2-3:** E2E em browser real cobrindo cenários canônicos do EPIC-001 verde na pipeline de homolog.

---

## Bloco 3 — Automação

- [ ] **CA-3-1:** Pipeline CI/CD verde nos últimos commits do EPIC-001 em main.
- [ ] **CA-3-2:** Deploy automático em homolog após tag rc verde, com código completo do épico.
- [ ] **CA-3-3:** Migrações idempotentes e reversíveis (não houve hotfix manual em homolog).
- [ ] **CA-3-4:** Job de lembrete agendado funcionando em homolog (cron + worker observados).

---

## Bloco 4 — Funcionalidade observável (Métrica primária)

- [ ] **CA-4-1 (MÉTRICA PRIMÁRIA):** Cadastro fim a fim em homologação executável em ≤ 5 min pelo usuário, com aprovação manual visível ao admin em ≤ 30s após submit. Verificar percorrendo o fluxo manualmente em homolog com código completo deployado + E2E na pipeline.
- [ ] **CA-4-2:** Os 3 tipos de pessoa do profissional + contratante completam o ciclo `pré-cadastro → aprovação → welcome → completar cadastro → ativo` com aceite eletrônico anexado em cada caso.
- [ ] **CA-4-3:** Backoffice operacional: admin acessa fila, aprova, vê audit log; admin acessa editor de templates, cria versão, ativa.
- [ ] **CA-4-4:** Texto-seed dos templates carregado em homolog como `versao = 1` ativa em cada template.

---

## Bloco 5 — Qualidade transversal

- [ ] **CA-5-1:** Gitleaks verde em todos os CI runs do EPIC-001.
- [ ] **CA-5-2:** Composer audit + Trivy verdes nos últimos releases do EPIC-001.
- [ ] **CA-5-3:** Argon2id ativo (`HASH_DRIVER=argon2id`); senha nunca em log/response.
- [ ] **CA-5-4:** Defesa contra enumeração de e-mails: cadastro/login/reset retornam mensagens genéricas.
- [ ] **CA-5-5:** Throttling Fortify ativo no login e no reset de senha.
- [ ] **CA-5-6:** Cookies de sessão verificados em homolog (`httpOnly + Secure + SameSite=Lax` para ambos; escopo de domínio correto).
- [ ] **CA-5-7:** Dados pessoais coletados estão registrados em lista (LGPD básica); dados sensíveis criptografados em repouso.
- [ ] **CA-5-8:** Audit log de admin imutável em homolog.
- [ ] **CA-5-9:** AceiteEletronico imutável em homolog (CA-B1-53 é a evidência central).
- [ ] **CA-5-10:** Critério herdado F-NB-1 do EPIC-000: `migrate:rollback` em homolog exercido na primeira migração com lógica de negócio (STORY-016) com evidência no runbook.

---

## Bloco 6 — Observabilidade e acessibilidade

- [ ] **CA-6-1:** Log JSON estruturado com `request_id` rastreável em todas as ações do épico.
- [ ] **CA-6-2:** Métricas: cadastros recebidos, cadastros aprovados, cadastros completos, tempo médio na fila (SLA 24h), e-mails enviados, taxa de falha — observáveis no Cloud Monitoring.
- [ ] **CA-6-3:** Alerta ativo quando há cadastro pendente há > 20h (risco de SLA); alerta em falha de envio crítico (aprovação concedida, reset).
- [ ] **CA-6-4:** WCAG 2.1 AA verificada nas telas principais (amostragem com Lighthouse ou axe) — telas de login, cadastro público, fila de aprovação, editor de templates, welcome, completar cadastro. Tema dual claro/escuro respeitado.

---

## Bloco 7 — Documentação

- [ ] **CA-7-1:** Runbook `docs/operacao/runbook-homolog.md` atualizado com seções de: rollback de migração (F-NB-1), verificação de imutabilidade (audit log + aceite), verificação de SPF/DKIM/DMARC.
- [ ] **CA-7-2:** `index.json` reflete estado real do EPIC-001 (estórias `done`, ADRs `accepted`, validação).
- [ ] **CA-7-3:** Notas dos agentes preenchidas em cada estória, com evidência.

---

## Resumo do veredito

> Preencher após executar todos os blocos.

- **Total de itens**: __
- **Pass**: __
- **Pass com ressalva**: __
- **Fail não-bloqueante**: __
- **Fail bloqueante**: __
- **N/A**: __

**Veredito final**: `approved` | `approved_with_pending` | `rejected`

**Fails bloqueantes** (se houver — listar com evidência factual; **sem** propor solução):
- (a preencher)

**Fails não-bloqueantes** (se houver — listar com evidência; serão decididos pelo PO se viram carry-forward ou estória de correção):
- (a preencher)
