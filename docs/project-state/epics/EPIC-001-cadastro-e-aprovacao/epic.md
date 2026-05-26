---
epic_id: EPIC-001
slug: cadastro-e-aprovacao
title: Cadastro e aprovação de profissional e contratante
wave: WAVE-2026-01
status: draft
owner_role: po
created_at: 2026-05-26
updated_at: 2026-05-26
target_completion: 2026-07-07  # estimativa orientativa
---

# EPIC-001 — Cadastro e aprovação

## Por que existimos (problema do usuário)

Sem usuários `ativo`, nenhum dos demais épicos funciona. Profissionais (PF, MEI ou PJ — PDR-001) e contratantes precisam conseguir entrar na plataforma de forma simples no front, com aprovação manual da equipe Turni no backoffice dentro do SLA público de 24h. O funil pós-aprovação (welcome → completar cadastro) é obrigatório para garantir que dados sensíveis e jurídicos só sejam coletados depois do filtro humano.

**Adicionalmente**: o primeiro turno real só pode acontecer com contrato eletrônico juridicamente defensável — mas a fonte e o ciclo de manutenção desse contrato **não** ficam sob responsabilidade do time de desenvolvimento. Por **PDR-012**, os templates contratuais (PF autônomo eventual e B2B PJ↔PJ) viram entidades editáveis pelo admin no backoffice, com versionamento. O EPIC-001 entrega o **texto-seed inicial** e a **interface de edição** — a evolução posterior do conteúdo jurídico fica com a equipe Turni (que pode contratar advogado externo a qualquer momento sem depender do dev). O spike jurídico/contábil **sai** do caminho crítico — vira validação posterior fora de sprint formal.

## Resultado esperado (outcome)

Ao fim deste épico, profissional (PF/MEI/PJ) e contratante (CNPJ) conseguem completar o funil `pré-cadastro → aprovação manual → welcome → completar cadastro → ativo` em homologação, com aceite eletrônico apropriado por tipo de pessoa registrado no momento da aprovação, e backoffice mínimo permitindo a equipe Turni operar a fila de aprovação dentro do SLA de 24h.

## Métrica de sucesso (como saberemos que funcionou)

- **Primária**: cadastro fim a fim em homologação (pré-cadastro → aprovação → completar → ativo) executável em ≤ 5 min para o usuário, com aprovação manual visível ao admin em ≤ 30s após submit.
- **Qualidade**: 100% dos novos cadastros aprovados geram aceite eletrônico corretamente versionado por tipo de pessoa (PF autônomo eventual ou MEI/PJ B2B↔B2B).
- **Compliance**: lista de campos coletados pré-aprovação vs pós-aprovação respeita classificação de dados (PDR-001 + `non-functional.md`).

## Entregável visível no fim do épico

- [ ] Profissional consegue se pré-cadastrar como PF, MEI ou PJ em `app.homolog.turni.com.br/cadastro`.
- [ ] Contratante consegue se pré-cadastrar em `app.homolog.turni.com.br/cadastro`.
- [ ] Admin vê fila de aprovação em `admin.homolog.turni.com.br/aprovacoes`, com filtros por tipo (profissional/contratante).
- [ ] Admin aprova com 1 clique; usuário recebe e-mail de notificação (template + provedor decidido em ADR).
- [ ] Usuário aprovado, ao logar, passa por welcome → completar cadastro → estado `ativo`.
- [ ] **Admin tem editor de templates contratuais em `admin.homolog.turni.com.br/templates`** com versionamento (PDR-012). Dois templates pré-populados com texto-seed inicial: `template_pf_autonomo_eventual` e `template_mei_pj_b2b`.
- [ ] **Aceite eletrônico anexado ao usuário no momento da aprovação referencia a versão específica do template vigente**, com placeholders renderizados (nome, documento, timestamp, IP, fingerprint).
- [ ] Mudanças posteriores no template criam nova versão; contratos passados continuam apontando para a versão original (imutabilidade do aceite).

## Fora de escopo (explicitamente)

- Login social (OAuth Google, Apple) — fica para evolução.
- Multi-fator de autenticação — fica para evolução.
- Recuperação de senha sofisticada (com perguntas de segurança, etc.) — versão simples (e-mail link) está dentro do escopo; refinamentos ficam fora.
- Edição de perfil pós-cadastro (mudança de dados, alteração de tipo de pessoa) — vira épico próprio na próxima onda.
- Multi-unidade para contratante (Enterprise) — fora do MVP.
- Validação automática de CPF/CNPJ contra Receita — PDR-001 exclui do MVP (manual pela equipe Turni).
- Exclusão de conta / LGPD direito ao esquecimento — fluxo manual no MVP (não tem UI no webapp).
- Recusa explícita pelo admin com motivo registrado — MVP apenas remove o usuário (PDR-001).
- **Spike jurídico/contábil externo (advogado + contador)** — sai do caminho crítico por PDR-012. Validação posterior é responsabilidade da equipe Turni e roda fora de sprint formal. Texto-seed inicial é escrito pelo PO com referências públicas e validado pelo Alexandro antes de produção.
- **Assinatura digital qualificada / ICP-Brasil no aceite eletrônico** — fora do MVP. O aceite registra IP + fingerprint + timestamp + versão do template, que é defensável como prova de aceite no contexto B2B / autônomo eventual brasileiro. Assinatura digital avançada vira evolução.

## Referências da especificação

- `docs/especificacao/glossary.md` — termos canônicos (tipo de pessoa, pré-cadastro, aprovação, funil, aceite eletrônico).
- `docs/especificacao/domain/usuario.md` — estados, atributos por papel, regras do funil.
- `docs/especificacao/domain/compliance.md` — aceite eletrônico por tipo de pessoa.
- `docs/especificacao/flows/cadastro-e-aprovacao.md` — fluxo ponta a ponta (a escrever durante este épico).
- `docs/especificacao/flows/welcome-e-completar-cadastro.md` — funil pós-aprovação (a escrever).
- `docs/especificacao/non-functional.md` — SLA de 24h, classificação de dados, LGPD básica.
- `docs/project-state/decisions/pdr/PDR-001-tipos-de-pessoa-aceitos.md` — base do épico.
- `docs/project-state/decisions/pdr/PDR-003-duas-interfaces-webapp-e-backoffice.md` — fila de aprovação nasce aqui.
- `docs/project-state/decisions/pdr/PDR-012-templates-contratuais-editaveis-no-backoffice.md` — define que templates são editáveis pelo admin; impacta direto o escopo deste épico.

## Dependências

- **Bloqueia**: EPIC-002, EPIC-003, EPIC-004, EPIC-005 (sem usuários `ativo`, nada acontece).
- **Bloqueado por**: EPIC-000 (Foundation) concluído.
- **Decisões arquiteturais necessárias** (cada uma vira ADR ou IDR durante o épico):
  - Modelo de dados do usuário polimórfico (`tipo_pessoa` + documento variável + atributos por papel).
  - Modelo de dados de **Template + TemplateVersao** (PDR-012): catálogo de templates com versionamento append-only; placeholders para renderização no momento do aceite.
  - Estratégia de **renderização do aceite eletrônico**: substituição de placeholders do template com dados do usuário/turno; armazenamento do resultado renderizado + ponteiro para `template_versao_id`.
  - Estratégia de aceite eletrônico (prova de timestamp, IP, fingerprint; imutabilidade após criação).
  - Provedor de e-mail transacional + ACL (segue padrão `integration-architecture.md`).
- **Não há mais spike externo bloqueante** (PDR-012 removeu essa dependência). Texto-seed dos templates é produzido pelo PO durante o épico com referências públicas + validação do Alexandro antes de produção.

## Estórias

> A decompor via Fluxo B quando o épico entrar em sprint. Sequência prevista (esboço):

- Spike Arquiteto: modelo de dados de usuário polimórfico + modelo de Template/TemplateVersao + ACL de e-mail transacional — `type: spike`.
- Texto-seed dos templates contratuais (`template_pf_autonomo_eventual` v1, `template_mei_pj_b2b` v1) — escrito pelo PO, validado pelo Alexandro — `type: enablement`.
- Editor de templates no backoffice (listar, ver versões, criar nova versão, marcar versão ativa) — paralelismo Designer↔Programador, `requires_design: true`.
- Pré-cadastro de profissional (webapp): formulário público com `tipo_pessoa`.
- Pré-cadastro de contratante (webapp): formulário público.
- Backoffice mínimo: fila de aprovação + ação aprovar/recusar.
- Geração do aceite eletrônico no momento da aprovação (renderização do template vigente com dados do usuário; armazenamento imutável).
- Funil pós-aprovação: tela welcome.
- Completar cadastro do profissional (dados sensíveis + chave Pix + documento).
- Completar cadastro do contratante (CNPJ + endereço + cultura + contatos).
- E-mails transacionais (aprovado, recusado, lembrete de completar cadastro).
- Validação final do épico (Validador).

## Validação final

Critérios em `validation/checklist.md` (a criar). Relatório do validador em `validation/report.md`.

**Definição de épico concluído**: cadastro fim a fim funcionando em homologação para os 3 tipos de pessoa do profissional + contratante; backoffice mínimo operacional (fila de aprovação **+ editor de templates contratuais**); texto-seed dos templates validado pelo Alexandro; aceite eletrônico renderizado e anexado ao usuário no momento da aprovação, com referência à versão vigente do template; relatório do validador `approved`.

## Histórico

- 2026-05-26 — criado por PO durante planejamento da WAVE-2026-01.
- 2026-05-26 — ajustado por PO após PDR-012: spike jurídico/contábil sai do caminho crítico; entra estória de editor de templates no backoffice + texto-seed inicial.
