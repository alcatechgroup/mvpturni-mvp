---
pdr_id: PDR-001
slug: tipos-de-pessoa-aceitos
title: Profissional pode ser PF, MEI ou PJ; sem validação automática contra Receita
status: accepted
decided_at: 2026-05-26
decided_by: PO (Alexandro / Claude)
supersedes: null
superseded_by: null
related_epics: []
related_adrs: []
---

# PDR-001 — Profissional pode ser PF, MEI ou PJ; sem validação automática contra Receita

## Contexto

O protótipo navegável foi construído assumindo que todo profissional é MEI (campo `mei: true` no seed). A landing page reforça o modelo "B2B PJ↔PJ". No primeiro alinhamento de produto, ficou claro que essa restrição exclui um público relevante: profissionais qualificados que ainda não abriram MEI mas querem começar a operar pela plataforma (Diego, persona iniciante) e profissionais já constituídos como PJ pura (não MEI). Adicionalmente, validar documento contra Receita Federal é trabalho técnico, custo e ponto de falha que não cabem no MVP — operacionalmente, a equipe Turni valida cadastros manualmente em até 24h.

## Opções consideradas

### Opção 1 — Manter restrição "só MEI"
- Descrição: Cadastro só aceita CNPJ MEI, validação manual humana.
- Prós: Menor exposição a risco trabalhista; contrato eletrônico único (B2B PJ↔PJ); copy da landing já alinhado.
- Contras: Exclui Diego e similares; força profissionais a regularizar antes de ganhar, o oposto da promessa de autonomia; perde adoção inicial.

### Opção 2 — Aceitar PF, MEI e PJ, sem validação automática
- Descrição: Cadastro com campo `tipo_pessoa: PF | MEI | PJ`. PF informa CPF; MEI/PJ informam CNPJ. Equipe Turni valida documento manualmente em até 24h. Regras de compliance e contrato eletrônico variam por tipo.
- Prós: Inclui profissional iniciante; amplia base; alinha com promessa de autonomia; protótipo bate com realidade do mercado.
- Contras: Dois templates de contrato (autônomo eventual para PF; B2B PJ↔PJ para MEI/PJ); regra de habitualidade mais estrita para PF (ver PDR-002); copy da landing precisa ajuste; risco operacional aumenta se a habitualidade não for bem aplicada.

### Opção 3 — Aceitar PF, MEI e PJ, com validação automática Receita
- Descrição: Cadastro aceita os três, mas plataforma consulta CPF/CNPJ via API Receita no cadastro.
- Prós: Reduz risco de cadastro falso; reduz carga manual da equipe.
- Contras: Custo de integração, tempo de implementação, ponto de falha extra; não destrava o MVP — fica para evolução.

## Decisão

> **Optamos pela Opção 2.**

A plataforma aceita profissionais como PF, MEI ou PJ. Validação de documento é manual pela equipe Turni dentro do SLA público de 24h. Não há consulta automática à Receita no MVP.

## Justificativa

A Opção 2 amplia a base do profissional sem comprometer a governança — desde que combinada com a regra de habitualidade mais estrita para PF definida em PDR-002. A validação automática (Opção 3) é trabalho técnico que não cabe no MVP e pode ser evolução. Manter "só MEI" (Opção 1) ignora o segmento iniciante que é parte explícita da promessa de autonomia da plataforma.

## Consequências

### Positivas
- Profissionais iniciantes (PF) entram na plataforma e podem migrar para MEI conforme cresce.
- Base ampliada nas primeiras ondas de aquisição.
- Aceite eletrônico fica mais simples de auditar (dois templates fixos).

### Negativas / trade-offs aceitos
- Risco trabalhista para PF é maior que para PJ — mitigado por habitualidade estrita (PDR-002).
- Carga operacional manual de validação na equipe Turni (limita escala antes da automação).
- Spike jurídico necessário para definir o template do contrato de autônomo eventual para PF.
- Copy da landing ("B2B PJ↔PJ") precisa ajuste.
- Tributação do contratante muda ao contratar PF (possível retenção de IRRF e INSS); plataforma deve fornecer relatório fiscal por período.

### Para o time técnico
- ADRs prováveis: modelo de dados do usuário com `tipo_pessoa` + documento variável (CPF ou CNPJ); estratégia de aceite eletrônico com template dinâmico.
- Impacto em épicos: EPIC de cadastro de profissional (precisa contemplar três tipos); EPIC de compliance (precisa aplicar regra distinta para PF); épico ou estória de spike jurídico antes do primeiro cadastro real.

## Sinais de revisão

- Se a equipe Turni virar gargalo (SLA de 24h descumprido em mais de 20% dos cadastros), reavaliar a validação automática.
- Se mais de 5% dos cadastros forem falsos / fraudulentos detectados pós-aprovação, reavaliar consulta automática à Receita.
- Se PF se mostrar segmento residual (< 5% dos profissionais ativos após 6 meses), reconsiderar simplificar para "só MEI/PJ".
