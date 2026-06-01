---
id: WISH-001
slug: consulta-cep
title: Consultar CEP e preencher logradouro, cidade e estado
status: new
origin: Alexandro (sessão 2026-05-31)
tags: [integracao, ux, cadastro, endereco]
spec_link: null
rejected_reason: null
created_at: 2026-05-31
updated_at: 2026-05-31
---

# WISH-001 — Consultar CEP e preencher logradouro, cidade e estado

## One-liner

Em qualquer formulário de endereço (cadastro de profissional, de estabelecimento, criação de vaga com local de trabalho), quando o usuário digita um CEP válido o sistema consulta uma API pública e preenche automaticamente logradouro, bairro, cidade e UF — restando ao usuário apenas o número e complemento.

## Problema / necessidade

Hoje o protótipo coleta endereço campo-a-campo. Em mobile (principal canal do Turni), digitar logradouro completo + cidade + UF é fricção alta e fonte de erro (typo no nome da rua, UF errada). Persona profissional preenche cadastro no celular, muitas vezes a pé; persona contratante cadastra estabelecimentos e cria vagas em múltiplos endereços. Reduzir digitação aumenta taxa de conclusão de cadastro e qualidade do dado de localização (que alimenta o Match IA).

## Valor esperado

- **Conclusão de cadastro:** menos campos para digitar = menor abandono nas telas de cadastro PF/PJ (EPIC-001) e em criação de vagas (épicos futuros).
- **Qualidade do dado:** endereços normalizados pela base oficial reduzem inconsistência em busca por proximidade (insumo do Match IA).
- **UX percebida:** comportamento esperado por qualquer usuário brasileiro acostumado com e-commerce; ausência é estranheza.

## Referências

- Protótipo: `docs/prototipo/app.html` — fluxos de cadastro de profissional e de contratante (telas com campo de endereço).
- Spec: `docs/especificacao/domain/usuario.md`, `docs/especificacao/screens/` (cadastros).
- Estórias relacionadas em sprint atual: STORY-023 (completar cadastro PF), STORY-024 (completar cadastro PJ).
- ADRs vigentes que podem impactar: nenhuma específica sobre integrações externas — provavelmente exigirá ADR nova (cache, fallback, timeout) ao ser specada.

## Restrições conhecidas

- **LGPD:** CEP isolado não é dado pessoal sensível, mas o conjunto CEP+número+complemento + nome do titular é. Base legal já coberta pelo cadastro do próprio usuário (execução de contrato).
- **Integração externa:** APIs públicas comuns para CEP no Brasil (ViaCEP, BrasilAPI, Correios). Decisão de qual usar é técnica (Arquiteto) — PO exige: disponibilidade aceitável, fallback se API cair (degrada para preenchimento manual sem bloquear o cadastro), cache do lado servidor para CEPs já consultados.
- **Acessibilidade:** preenchimento automático precisa anunciar mudança via aria-live para leitores de tela.
- **Edge cases:** CEP inexistente, CEP genérico de cidade (sem logradouro), CEP de localidade rural.

## Notas / histórico

- `2026-05-31` — Captura inicial. Origem: Alexandro pediu na criação da wishlist. Status `new`, ainda sem triagem.
