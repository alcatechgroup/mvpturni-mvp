# Caso de suporte — Firebase Hosting corrompido no `turni-prod` (channel órfão)

> ## ✅ RESOLVIDO — migração concluída em 2026-06-12
> O 409 do channel órfão **deixou de ocorrer** (criar/deletar sites no `turni-prod` voltou a
> funcionar — confirmado por probe). A landing de prod foi **migrada de volta para o `turni-prod`**:
> - Sites no `turni-prod`: **`turni-prod-landing`** (apex `turni.com.br`) e **`turni-prod-redirect`**
>   (redirect www → apex). **Gotcha:** os ids originais `turni-landing-prod`/`turni-redirect-prod`
>   ficaram **reservados globalmente** pelo Firebase após o delete no `turni-prod-web` (hold
>   pós-delete) — por isso os novos ids `turni-prod-*`.
> - Domínio `turni.com.br` reconectado (cert `PROJECT_GROUPED` **reaproveitado** — sem reemissão de
>   SSL; downtime ≈ 10 min, só conteúdo + recheck de posse). TXT do apex atualizado p/
>   `hosting-site=turni-prod-landing`; A apex segue `199.36.158.100`.
> - Secrets do GitHub Environment `landing-prod` repontados p/ `turni-prod` (WIF/SA do módulo `iam`,
>   já aplicado). CI: tag `landing-v0.1.1` publicou o conteúdo. `.firebaserc`/`firebase.json`/Terraform
>   de prod atualizados.
> - **Projeto `turni-prod-web` excluído** (`gcloud projects delete`, estado `DELETE_REQUESTED` —
>   recuperável por ~30 dias). **O caso de suporte abaixo NÃO precisou ser aberto.**
>
> O texto abaixo fica como histórico. Para o go-public via Terraform, ver o aviso de
> `terraform import` em [runbook-landing.md](runbook-landing.md) (sites/custom domain já existem).


> Cole o bloco em inglês abaixo no formulário de suporte do Firebase. O `turni-prod`
> está no plano **Blaze** (billing vinculado), então há direito a suporte do Firebase.
>
> **Onde abrir:** Firebase Console → projeto `turni-prod` → ⚙ → **Support** → *Contact support*
> (ou https://firebase.google.com/support/troubleshooter/contact). Categoria: **Hosting**.
>
> **Contexto interno:** isso bloqueia a landing de produção. Workaround temporário em
> produção: a landing vive no projeto dedicado `turni-prod-web` (ver `.firebaserc` e
> `runbook-setup-prod-e-stage.md`). Quando o suporte limpar o resíduo, migrar de volta —
> ver "Plano de migração de volta" no fim.

---

## Texto para o suporte (EN)

**Subject:** Firebase Hosting is unusable on project `turni-prod` — orphaned `live` channel for a non-existent default site (project was deleted then undeleted)

**Project ID:** `turni-prod`
**Project number:** `444870733440`
**Billing:** Blaze (linked)
**Product:** Firebase Hosting

**Summary:**
Every Firebase Hosting API call on this project fails with `409 ALREADY_EXISTS`,
referencing a `live` channel for a default site that does not exist. The project was
**deleted and later undeleted (restored)**, which we believe left the Hosting backend in
an inconsistent state. We cannot create any Hosting site (including a new named site), so
Hosting is completely unusable on this project. We need the orphaned channel/site record
cleaned up on the backend so we can create Hosting sites again.

**Exact, reproducible errors** (via REST, authenticated as a project Owner):

1. List sites — should succeed, returns 409:
   `GET https://firebasehosting.googleapis.com/v1beta1/projects/turni-prod/sites`
   → `409 ALREADY_EXISTS: Channel \`projects/444870733440/sites/turni-prod/channels/live\` already exists.`

2. Create a NEW named site — returns the same 409:
   `POST .../projects/turni-prod/sites?siteId=turni-landing-prod`
   → `409 ALREADY_EXISTS: Channel \`projects/444870733440/sites/turni-prod/channels/live\` already exists.`

3. Get the default site `turni-prod` — returns 404 (it does NOT exist):
   `GET .../projects/turni-prod/sites/turni-prod`
   → `404 NOT_FOUND: Requested entity was not found.`

4. Delete the orphaned `live` channel directly — returns 404 (it "doesn't exist" for delete):
   `DELETE .../projects/turni-prod/sites/turni-prod/channels/live`
   → `404 NOT_FOUND: Requested entity was not found.`

So the channel `sites/turni-prod/channels/live` is reported as **already existing** by any
create/list call, but as **not found** by GET/DELETE on the site and the channel. The
default site itself does not exist. This is a backend inconsistency we cannot resolve via
the public API.

**What we already tried (all unsuccessful):**
- Creating a different named site (`turni-landing-prod`) → same 409.
- Deleting the default site `turni-prod` → 404 (doesn't exist).
- Deleting the channel `live` directly → 404.
- Re-creating the default site `turni-prod` → 409.
- Disabling and re-enabling the `firebasehosting.googleapis.com` API on the project,
  then retrying → 409 persists.

**Request:** Please clean up the orphaned `live` channel / inconsistent default-site state
for project `turni-prod` (number `444870733440`) so that Firebase Hosting site creation
works again. We do not need any old Hosting content recovered — the project had no real
Hosting content; a clean Hosting state is all we need.

---

## Plano de migração de volta (quando o suporte resolver)

1. Confirmar que `GET .../projects/turni-prod/sites` lista normal e `create site` funciona.
2. Recriar no `turni-prod` os sites: `turni-landing-prod` (+ um de redirect; **evitar "www" no
   site_id** — o Firebase rejeita) — via Terraform (`landing_prod_enabled=true`, módulo firebase
   gateado) ou REST.
3. Conectar o custom domain `turni.com.br` ao site no `turni-prod` (gera o mesmo tipo de
   required DNS: A `199.36.158.100` + TXT ownership `hosting-site=...` + TXT `_acme-challenge`).
   Os registros já estão na zona apex do `turni-prod` — só ajustar o valor do TXT ownership
   (`hosting-site=<novo site>`) se o site_id mudar.
4. Reapontar o GitHub Environment `landing-prod` (GCP_PROJECT_ID/WIF/SA) de volta para `turni-prod`.
5. Reverter o bloco `turni-prod-web` no `.firebaserc` (voltar os targets `landing-prod`/
   `www-redirect-prod` para `turni-prod`).
6. Redeploy `landing-v0.1.x`; validar; **desligar/excluir** o `turni-prod-web`.
7. Atualizar `infra/envs/prod/variables.tf`: `firebase_apex_a_records` default = `["199.36.158.100"]`
   (o valor antigo `151.101.x.x` está desatualizado — o Firebase atual usa 199.36.158.100).

## Estado temporário atual (referência)
- Landing de prod: projeto **`turni-prod-web`** (nº 988219777185), site `turni-landing-prod`.
- `turni.com.br` apontado para esse site; DNS (A + 2 TXT) na zona apex do `turni-prod`.
- `turni-mvp` desvinculado da billing (liberou slot; estava morto). Re-vincular se precisar
  reativar algo dele antes da exclusão.
