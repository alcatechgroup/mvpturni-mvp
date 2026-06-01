---
idr_id: IDR-023
slug: template-proprio-de-adesao-do-contratante
title: Contratante adere a template próprio (termos_plataforma_contratante), não ao mei_pj_b2b
status: accepted
decided_at: 2026-06-01
decided_by: PO (Alexandro) + programador
owner_agent: claude-opus-4-8-programador-2026-06-01
related_story: STORY-024
related_adrs: [ADR-010]
related_idrs: [IDR-022]
related_pdrs: [PDR-004]
supersedes: null
superseded_by: null
created_at: 2026-06-01
updated_at: 2026-06-01
---

# IDR-023 — Template próprio de adesão do contratante

## Contexto

A STORY-024 (espelho da STORY-023 para o contratante) instruía, em CA-7/9/15, renderizar a **versão
ativa do template `mei_pj_b2b`, apenas Seção 1 ("Termos gerais")**, com os dados do contratante, e
anexar essa renderização ao `AceiteEletronico` gerado no clique final do completar cadastro.

Ao reler o **texto-seed real** de `mei_pj_b2b` (`docs/especificacao/contratos/template-mei-pj-b2b-v1.md`,
vendorado em `database/seeders/contracts/`), o programador encontrou uma divergência entre a estória
e o conteúdo do template:

- A **Seção 1** do `mei_pj_b2b` é o contrato do **Profissional** ("### 1. Identificação do Prestador
  (Profissional)"). Seus únicos placeholders de identidade são `{{profissional.nome}}`,
  `{{profissional.documento}}`, `{{profissional.endereco_completo}}`. **Não há placeholder do
  contratante na Seção 1.**
- A identidade do contratante (`{{contratante.razao_social}}`, `{{contratante.cnpj}}`,
  `{{contratante.endereco_completo}}`) e a **taxa Turni** existem só na **Seção 2 (turno-específico)**,
  que o `AceiteAdesaoRenderer` (IDR-022 a) **omite** no aceite de adesão.
- Logo, reusar `mei_pj_b2b` + renderer de adesão para o contratante (i) **falharia** com
  `RenderizacaoIncompletaException` (sem valores `profissional.*`), ou (ii) se forçássemos os dados do
  contratante nos placeholders `profissional.*`, o documento imprimiria o contratante como "Prestador
  (Profissional)" — **juridicamente incoerente**.
- `compliance.md` só descreve o aceite do contratante **por turno** (Seção 2, ao aprovar candidatura).
  A spec **não tinha** um texto de adesão de plataforma do lado do contratante — lacuna real.

Autoria de texto contratual é responsabilidade PO/jurídico (STORY-015), fora da alçada do
programador. O bloqueio foi escalado ao PO **antes** de qualquer código de contrato.

## Decisão

> **O contratante adere a um template próprio, `termos_plataforma_contratante` ("Termos de Adesão à
> Plataforma para Contratante"), com a taxa Turni 15% (PDR-004) como cláusula permanente — e NÃO ao
> `mei_pj_b2b`.**

- Novo `Template` (slug `termos_plataforma_contratante`) com v1 ativa, mesma infra de ADR-010 /
  STORY-020 (versionamento append-only, imutabilidade do aceite via IDR-022/migration de STORY-023).
- O **texto-seed** é escrito pelo PO (extensão de STORY-015), validado cláusula a cláusula antes do
  seed. Entrega em 24–48h a partir de 2026-06-01.
- CA-7, CA-9 e CA-15 da STORY-024 passam a referenciar `termos_plataforma_contratante` no lugar de
  `mei_pj_b2b`. CA-12 (transição `liberado → ativo`, plano `Member Start`) mantém.

## Por quê

- **Coerência jurídica:** a Seção 1 do `mei_pj_b2b` é o contrato do profissional; um contratante não
  é "Prestador". Reuso produziria documento incoerente — exatamente o tipo de dívida que o aceite
  eletrônico (prova jurídica) não pode carregar.
- **PDR-004:** a taxa Turni 15% é cobrada do contratante. Fixá-la como cláusula **permanente** no
  aceite de adesão dá prova do consentimento comercial independentemente de turno — o aceite por
  turno (EPIC-003) trata do escopo de cada alocação, não da relação de plataforma.
- **ADR-010 "dois usos distintos":** o próprio contexto da STORY-024 fala em validar o desenho do
  ADR-010 para PF profissional **e** PJ contratante. Isso só se concretiza com um template próprio do
  contratante — não reaproveitando o do profissional.
- **Fronteira de papel:** authoring de cláusula contratual é PO; o programador escala em vez de
  inventar texto (SKILL programador §"Você NÃO decide").

## Alternativas consideradas

- **Reusar `mei_pj_b2b` como está (renderizar Seção 1 com dados do contratante):** rejeitada — falha
  de renderização ou documento que chama o contratante de "Prestador (Profissional)". Incoerente.
- ** Adesão sem contrato (só re-registrar aceite dos Termos de Uso do pré-cadastro):** rejeitada — não
  satisfaz PDR-004 (consentimento comercial da taxa) nem os "dois usos" do ADR-010; esvaziaria CA-7/9.
- **Editar o `mei_pj_b2b` para incluir o contratante:** rejeitada — conteúdo de template é
  append-only/versionado (ADR-010) e o `mei_pj_b2b` é o contrato do profissional; misturar partes
  poluiria ambos os usos.

## Consequência

- **Bloqueio parcial da STORY-024:** preview (CA-7) e persistência do `AceiteEletronico` (CA-9) +
  E2E do aceite (CA-15) ficam atrás do texto-seed do PO. Tudo o mais (migration + colunas, validação
  CNPJ via `DocumentoValidator` reusado, integração CEP, upload de logo, `CompletarCadastroContratante`
  de campos + transição, UI multi-step, testes dessas partes) segue em paralelo.
- O `AceiteAdesaoRenderer` (IDR-022) é reusado sem mudança: o novo template é estruturado para que o
  corte de blocos (preâmbulo + Seção 1 + Assinatura) renderize o corpo de adesão do contratante; os
  carimbos `{{aceite.*}}` seguem a mesma regra preview-pendente vs. assinatura real.
- **Retrospectiva (input):** o seed de templates (STORY-015) foi pensado só do lado do profissional;
  a spec do contratante tinha lacuna de contrato de adesão. Sinalizar ao revisar futuros épicos que
  coletam consentimento.
