---
id: IDR-005
title: Multi-site Firebase via var.additional_sites (Opção A), não N chamadas do módulo (Opção B)
status: accepted
decided_at: 2026-05-28
decided_by: programador
source_story: STORY-029
supersedes: nada
superseded_by: nada
---

# IDR-005 — Firebase multi-site: `additional_sites` no módulo (Opção A) em vez de N chamadas (Opção B)

## Contexto

A STORY-029 estende o módulo `infra/modules/firebase` (que hoje cria **um** site,
`turni-webapp-${env}`, com um domínio customizado) para suportar os novos sites da landing
institucional (`turni-landing-{homolog,prod}` e, no go-public, o micro-site de redirect
`turni-www-redirect-prod`). ADR-012 §8 **recomenda** "parametrizar o módulo e chamá-lo N vezes"
(Opção B) mas **defere explicitamente** o detalhe de implementação (lista interna vs. N chamadas)
a esta estória. A própria STORY-029 diz: se a ADR não fixar, escolher B e justificar em IDR — o que
torna esta decisão obrigatória de registrar, já que escolhi **A**.

- **Opção A** — adicionar `var.additional_sites` (map de `{ site_id, custom_domain }`) ao módulo
  existente; cria o WebApp + N sites adicionais na mesma chamada.
- **Opção B** — extrair o site para um módulo genérico e chamá-lo N vezes do `envs/*/main.tf`
  (uma por site: webapp, landing, www-redirect).

## Decisão

**Opção A.** O módulo `firebase` ganha `var.additional_sites` (default `{}`); o WebApp e seu domínio
permanecem com os mesmos endereços de recurso de antes (`google_firebase_hosting_site.webapp`,
`google_firebase_hosting_custom_domain.webapp[0]`). Os sites adicionais entram via `for_each` em
`google_firebase_hosting_site.additional` + `google_firebase_hosting_custom_domain.additional`.

## Por quê (Opção A vence Opção B aqui)

1. **`google_firebase_project` é singleton por projeto GCP.** O módulo cria
   `google_firebase_project.default` (habilita o Firebase no projeto `turni-mvp`). Em N chamadas
   (Opção B), cada instância do módulo tentaria criar esse recurso → conflito. Resolver exigiria
   **extrair** o `google_firebase_project` para fora do módulo (env-level ou flag `create_project`),
   adicionando peças móveis e lógica condicional — o oposto do ganho de "explicitude" que B promete.

2. **Zero movimentação de estado para o WebApp em produção (CA-10, CA-11).** A Opção B renomearia
   os endereços de estado do site e domínio do WebApp já no ar
   (`module.firebase.google_firebase_hosting_site.webapp` → `module.firebase_webapp...this`),
   exigindo `moved` blocks. Os `moved` são seguros *quando corretos*, mas...

3. **Não posso rodar `terraform apply` nesta sessão para verificar os moves.** O CA-12 impõe gate
   humano: o PO revisa o `terraform plan` **antes** de qualquer `apply`. Sem poder aplicar, prefiro o
   desenho que **só adiciona recursos** (plan = puro `+`, nenhum `~`/`-`/move sobre o WebApp vivo) ao
   desenho que depende de moves que eu não consigo validar até o apply gated. Menor raio de explosão
   sobre infra em produção é a escolha responsável aqui.

4. **A "lógica condicional no módulo" que a STORY-029 cita como contra de A é mínima:** um `for_each`
   sobre um map (default vazio) e um `for_each` filtrando `custom_domain != null`. Não há ramificação
   por tipo de site; o módulo continua coeso (um projeto Firebase + sites de hosting).

O trade-off aceito: o módulo deixa de ser "um site por chamada" e passa a "WebApp + N adicionais por
chamada". Para o tamanho do projeto (poucos sites por ambiente, todos no mesmo projeto GCP) isso é
mais simples que orquestrar N módulos + extração do singleton + moves de estado.

## Topologia resultante (ADR-012 §8)

| Ambiente | Chamada | Sites criados | Domínios |
|---|---|---|---|
| homolog | `module.firebase` | `turni-webapp-homolog` (principal) + `turni-landing-homolog` (additional) | `app.homolog` (CNAME), `landing.homolog` (CNAME) |
| prod | `module.firebase` | `turni-webapp-prod` (principal) + *(gated)* `turni-landing-prod`, `turni-www-redirect-prod` | apex `turni.com.br` (A/AAAA), `www` (CNAME→redirect) |

Sites e registros de prod ficam codificados mas gated por `var.landing_prod_enabled` (default `false`):
`additional_sites = {}` e o módulo `dns_landing` com `count = 0` → `terraform plan` em prod mostra
**0 changes** referentes à landing (CA-9). Go-public = virar a flag via PR do PO/comercial.

## Consequências

- **Positiva:** WebApp intocado no plan/apply (sem moves); singleton Firebase preservado; prod
  totalmente gated; reversível (`for_each` vazio remove os sites).
- **Negativa / dívida:** se um dia a landing precisar de um módulo Firebase realmente independente
  (ex: outro projeto GCP, pipeline próprio de TF), migrar de A para B exigirá os `moved` blocks que
  evitei agora. Aceitável: improvável no escopo do EPIC-006, e a migração seria mecânica.
- **Aberta (não-bloqueante):** os IPs do apex (`firebase_apex_a_records`, default `199.36.158.100`)
  precisam ser confirmados no go-public a partir do `required_dns_updates` do
  `google_firebase_hosting_custom_domain` / console Firebase. Como prod é gated e não aplicado nesta
  estória, o valor não é verificável agora — documentado aqui e no runbook (STORY-032).

## Verificação

- `terraform validate` em homolog e prod: **Success** (rodado nesta estória, `-backend=false` em prod).
- `terraform fmt -check -recursive`: **OK**.
- `terraform plan` homolog (gate CA-12, antes do apply): deve mostrar apenas adição de
  `google_firebase_hosting_site.additional["landing"]`, seu custom domain e o CNAME `landing.homolog`
  — nenhuma mudança sobre os recursos do WebApp.
