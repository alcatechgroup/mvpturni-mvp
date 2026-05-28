---
id: IDR-003
title: Admin em homolog com INGRESS_TRAFFIC_ALL + allow_unauthenticated para viabilizar E2E no CI
status: accepted
decided_at: 2026-05-28
decided_by: programador
source_story: STORY-011 (bloqueio 3)
---

# IDR-003 — Admin em homolog com INGRESS_TRAFFIC_ALL + allow_unauthenticated

## Contexto

O Backoffice (admin) em homologação foi provisionado com
`INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER` + `allow_unauthenticated = false`.
Essa configuração é adequada para produção (admin atrás de IAP + LB externo),
mas impede que os testes E2E Playwright rodados nos runners do GitHub Actions
(infraestrutura externa) acessem o serviço.

STORY-011 (validação EPIC-000) exige que os E2E de STORY-009 "rodem verdes na
pipeline de homologação" (CA-10). Sem acesso externo, o job de E2E falha ao
tentar alcançar a URL do admin.

## Decisão

Para o **ambiente de homologação** do EPIC-000 Foundation:

- `ingress = INGRESS_TRAFFIC_ALL` — permite tráfego externo (runners do CI)
- `allow_unauthenticated = true` — remove exigência de Bearer token

A alteração é feita em `infra/envs/homolog/main.tf` E propagada pelo job de
deploy via `gcloud run deploy --ingress=all --allow-unauthenticated` (self-healing:
cada deploy garante que o ingress está no estado correto mesmo sem terraform apply).

## Justificativa

- Homolog é um ambiente de testes sem usuários reais e sem dados sensíveis.
- O hello world do admin não expõe rotas nem dados além de texto estático.
- A autenticação real (sessão cookie + CSRF) entra em EPIC-001.
- A proteção do admin em **produção** continuará sendo
  `INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER` + IAP (configurado via LB externo).

## Consequências

- CI consegue executar `npx playwright test` contra a URL do Cloud Run admin.
- Terraform drift zero: `main.tf` reflete o estado aplicado pelo pipeline.
- Produção **não é afetada**: `infra/envs/prod/main.tf` mantém
  `INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER` + `allow_unauthenticated = false`.
- Quando IAP for configurado no EPIC-001 (via LB externo), este IDR será
  supersedido e o ingress do admin em homolog pode voltar a ser interno.
