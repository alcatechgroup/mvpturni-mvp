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

## Refinamento 2026-05-28 — Terraform como fonte de verdade do binding allUsers

**Contexto:** A service account do CI (`turni-github-ci`) tem apenas `roles/run.developer`,
que **não inclui** `run.services.setIamPolicy`. Por isso `gcloud run deploy --allow-unauthenticated`
emitia warning e **não criava** o binding `allUsers → roles/run.invoker`. Admin homolog
retornava 403 em 100% das requisições.

**Decisão (PO):** Terraform é a única source-of-truth do binding allUsers. A SA do CI não ganha
`run.services.setIamPolicy`. O binding é criado via `terraform apply` (que usa credenciais com
permissão suficiente) através do recurso `google_cloud_run_v2_service_iam_member.public` já
existente em `infra/modules/cloud-run/main.tf` (ativado quando `allow_unauthenticated = true`,
que já está em `infra/envs/homolog/main.tf` para o admin).

**Impacto em release.yml:** `--allow-unauthenticated` removido do step "Deploy Cloud Run — admin
(homolog)". O deploy apenas atualiza a imagem; o binding IAM é gerenciado exclusivamente pelo
Terraform. Mantido `--ingress=all` (o deploy pode sobrescrever a propriedade de ingress, mas não
o IAM binding).

## Refinamento 2026-05-28b — justificativa original esvaziada por IDR-004

**Contexto:** IDR-004 removeu o job `e2e-homolog` do `release.yml` — E2E em browser real virou
gate LOCAL antes da tag, e o pipeline pós-deploy passou a fazer apenas smoke curl. **O motivo
que criou este IDR (runner do GitHub Actions precisando alcançar o admin externamente para
rodar Playwright) deixou de existir.**

**Decisão:** Este IDR **NÃO é revogado nesta PR**. Mantido temporariamente para preservar
acesso externo manual ao admin homolog (smoke do PO / inspeção visual) enquanto IAP não está
configurado. Marcado como **"a revogar quando IAP entrar em EPIC-001"**.

**Plano de revogação (atrelado a EPIC-001):** quando a estória de configuração de IAP (no
EPIC-001) for executada, esta decisão será supersedida por um novo IDR que:
1. Restaura `ingress = INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER` em `infra/envs/homolog/main.tf`.
2. Restaura `allow_unauthenticated = false` no módulo Cloud Run para admin.
3. Remove o `--ingress=all` do step de deploy do admin em `release.yml`.
4. Documenta que admin homolog passa a ser acessado via LB externo + IAP (mesmo caminho da
   produção, ambiente compartilhado de aprendizado operacional).

Até lá, este IDR fica `accepted` com a anotação `to-revoke-on: EPIC-001 (IAP)`.
