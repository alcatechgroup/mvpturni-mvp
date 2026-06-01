---
id: WISH-002
slug: consulta-cnpj
title: Consultar CNPJ em API específica e preencher dados da empresa
status: new
origin: Alexandro (sessão 2026-05-31)
tags: [integracao, cadastro, compliance, pj]
spec_link: null
rejected_reason: null
created_at: 2026-05-31
updated_at: 2026-05-31
---

# WISH-002 — Consultar CNPJ em API específica e preencher dados da empresa

## One-liner

Quando o usuário digita um CNPJ no cadastro de contratante PJ (ou profissional MEI/PJ), o sistema consulta uma API específica de CNPJ e traz razão social, nome fantasia, situação cadastral, CNAE principal e endereço — usuário apenas confirma.

## Problema / necessidade

PDR-001 já decidiu que o profissional pode ser PF, MEI ou PJ **sem validação automática da Receita**. Esta wishlist propõe **retomar** a integração — não como bloqueio, mas como auxílio ao cadastro (autopreenchimento + sinal de situação cadastral). Hoje o contratante PJ teria que digitar razão social, fantasia, endereço da empresa manualmente; erro de digitação em razão social degrada documentos contratuais (template MEI/PJ-B2B-v1).

Persona contratante PJ frequentemente representa hotel/restaurante com cadastro complexo; persona profissional PJ/MEI é minoria mas precisa do mesmo carinho. Captura na origem reduz divergência em contratos futuros e melhora confiança ("o sistema sabe quem eu sou").

## Valor esperado

- **Qualidade do contrato:** razão social fiel à base oficial elimina rework e divergência no template MEI/PJ-B2B-v1.
- **Onboarding mais rápido:** menos digitação no cadastro PJ = menos atrito = mais conclusões.
- **Sinal de risco precoce:** situação cadastral diferente de "ATIVA" pode disparar UX informativa (sem bloquear, respeitando PDR-001) — útil para o contratante decidir se segue.

## Referências

- PDR vigente que restringe: PDR-001 (`decisions/pdr/PDR-001-tipos-de-pessoa-aceitos.md`) — sem validação automática **bloqueante**; consulta só para autopreenchimento e sinal informativo.
- Protótipo: `docs/prototipo/app.html` — telas de cadastro contratante e cadastro profissional MEI/PJ.
- Spec: `docs/especificacao/domain/usuario.md`, `docs/especificacao/contratos/template-mei-pj-b2b-v1.md`.
- Estória relacionada em sprint atual: STORY-024 (completar cadastro PJ).
- ADRs: nenhuma vigente sobre essa integração — exigirá ADR ao ser specada (qual provedor, cache, custo, fallback).

## Restrições conhecidas

- **LGPD:** CNPJ é público (Receita Federal); razão social, situação cadastral e endereço comercial idem. Sem complicação adicional além das gerais do cadastro PJ.
- **Custo / provedor:** APIs gratuitas (BrasilAPI, ReceitaWS) têm rate limit e disponibilidade variável. APIs pagas (CNPJa, Casa dos Dados, Serpro) cobram por consulta. PO exige análise de custo no spec; decisão de provedor é técnica (Arquiteto).
- **PDR-001 inviolável:** consulta CNPJ **não pode** se tornar gate de cadastro. Falha de API ou CNPJ não encontrado degrada para preenchimento manual.
- **Cache:** dados de CNPJ mudam raramente; cache server-side longo é viável e desejável.
- **Edge cases:** CNPJ baixado/suspenso/inapto — UX precisa decidir se mostra alerta informativo, e como redigi-lo sem virar bloqueio (alinhar com PDR-001).

## Notas / histórico

- `2026-05-31` — Captura inicial. Origem: Alexandro pediu na criação da wishlist. Status `new`, ainda sem triagem. Atenção: precisa conversar com PDR-001 antes de promover (uso permitido = autopreenchimento + sinal, não bloqueio).
