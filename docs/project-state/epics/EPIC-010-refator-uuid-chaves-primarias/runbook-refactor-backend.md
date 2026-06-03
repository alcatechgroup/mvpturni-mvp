# Runbook de execução — STORY-070 (refactor backend UUIDv7)

> Produzido pela STORY-069 (spike). Interface mecânica e **sem ambiguidade** entre o
> spike e a execução. Toda afirmação aqui foi validada empiricamente (ver evidências
> por CA na STORY-069 e notas na ADR-018). Onde houver "⚠️ correção de premissa", a
> ADR-018 (rascunho `proposed`) divergia do que o ambiente real exige — siga este
> runbook, ele é o que foi testado.

## 0. Pré-condições (checar ANTES de tocar em qualquer arquivo)

- [ ] **Premissa "zero produção" ainda vale?** Re-rodar o check do CA-4 (abaixo) contra
  homolog. Se aparecer usuário externo novo (não-seed, não-`xandroalmeida*`,
  não-`@homolog.local`), **PARAR** e reabrir a Decisão 5 da ADR-018 (vira 5B —
  migração de conversão). Em 2026-06-03 o PO confirmou os 20 usuários como descartáveis.
- [ ] Branch limpa a partir de `main`. Commit direto na main + push (workflow Turni).
- [ ] Ambiente local Docker no ar (`make up` / containers `api`, `admin`, `postgres`).

```bash
# Re-check CA-4 (premissa zero-produção) — roda contra o Cloud SQL privado de homolog
# via override de args no job existente, sem mutar a definição do job.
B64=$(printf '%s' '$total=DB::table("users")->count();
$susp=DB::table("users")
 ->where("email","not like","%@turni.local")
 ->where("email","not like","%turni-homolog@gmail.com")
 ->where("email","not like","%@homolog.local")
 ->where("email","not like","%xandroalmeida%")
 ->where("email","not like","%xandroalmenida%")
 ->pluck("email")->all();
echo "TOTAL=".$total." EXTERNOS=".count($susp)." :: ".implode(" ; ",$susp)."\n";' | base64 | tr -d '\n')
gcloud run jobs execute turni-migrate-homolog --region=southamerica-east1 --project=turni-mvp \
  --args='-c,php artisan tinker --execute="$(echo '"$B64"' | base64 -d)"' --wait
# Ler o resultado nos logs da execução (EXTERNOS deve ser 0).
```

---

## 1. Trait e tipo de chave (⚠️ correção de premissa)

**A ADR-018 referencia `HasVersion7Uuids` — esse trait NÃO existe no Laravel 13.12.**
O caminho correto, validado no CA-1:

- Usar **`Illuminate\Database\Eloquent\Concerns\HasUuids`** — no Laravel 13 ele **já gera
  UUIDv7 por padrão** (`newUniqueId()` retorna `(string) Str::uuid7()`).
- **NÃO** usar `HasVersion4Uuids` (esse gera v4 ordenado via `Str::orderedUuid()` — não é v7).
- **Não** é preciso declarar `$keyType = 'string'` nem `$incrementing = false` manualmente:
  o `HasUuids` (via `HasUniqueStringIds`) inicializa ambos. Confirmado empiricamente
  (CA-1/CA-2/CA-3): models que só fazem `use HasUuids` retornam `getKeyType() === 'string'`
  e geram v7. Adicione só o `use HasUuids;`.

### Models que recebem `use HasUuids;`

**apps/api/app/Models/** (14): `User`, `ProfissionalProfile`, `ContratanteProfile`,
`AdminAuditLog`, `Funcao`, `Template`, `TemplateVersao`, `AceiteEletronico`,
`CadastroLembrete`, `Vaga`, `VagaVersao`, `Candidatura`, `AuditLog`, `Notificacao`.

**apps/admin/app/Models/** (7): `User`, `ProfissionalProfile`, `ContratanteProfile`,
`AdminAuditLog`, `Funcao`, `Template`, `TemplateVersao`.

> Hoje **nenhum** model usa `HasUuids`/`keyType` (confirmado por grep). Não há remoção, só
> adição do trait.

---

## 2. Ordem de reescrita das migrations

A estratégia é **reset** (Decisão 5) — reescrevemos os arquivos de migration existentes
in-place (não criamos migrations de conversão). A ordem não importa para o resultado final
(o `migrate:fresh` recria do zero), mas **a ordem de criação das tabelas e suas FKs deve
continuar consistente** — uma tabela referenciada por `constrained()` precisa existir antes.
A ordem atual já satisfaz isso (prefixos de data); preserve-a.

### 2.1 PK: `$table->id()` → `$table->uuid('id')->primary()`

**apps/api** — trocar nestas 14 migrations (tabela de domínio):

| Migration | Tabela |
|---|---|
| `0001_01_01_000000_create_users_table.php` | `users` |
| `2026_05_28_200001_create_profissional_profiles_table.php` | `profissional_profiles` |
| `2026_05_28_200002_create_contratante_profiles_table.php` | `contratante_profiles` |
| `2026_05_28_200003_create_admin_audit_log_table.php` | `admin_audit_log` |
| `2026_05_29_100000_create_funcoes_table.php` | `funcoes` |
| `2026_05_29_130000_create_templates_and_template_versoes_table.php` | `templates`, `template_versoes` |
| `2026_06_01_120000_completar_cadastro_profissional_e_aceites.php` | `aceites_eletronicos` |
| `2026_05_30_120001_create_cadastro_lembretes_table.php` | `cadastro_lembretes` |
| `2026_06_02_100000_create_vagas_table.php` | `vagas` |
| `2026_06_02_100001_create_vaga_versoes_table.php` | `vaga_versoes` |
| `2026_06_02_100002_create_candidaturas_table.php` | `candidaturas` |
| `2026_06_02_100003_create_audit_logs_table.php` | `audit_logs` |
| `2026_06_03_120000_create_notificacoes_table.php` | `notificacoes` |

**apps/admin** — trocar nestas migrations: `create_users_table` (users),
`create_profissional_profiles_table`, `create_contratante_profiles_table`,
`create_admin_audit_log_table`, `create_funcoes_table`,
`create_templates_and_template_versoes_table` (templates + template_versoes).

> **`admin_audit_log` e `audit_logs`**: o comentário "GENERATED ALWAYS AS IDENTITY garante
> que o app nunca injeta ID" deixa de valer — com UUID o app **gera** o id na aplicação
> (`HasUuids`). A imutabilidade continua garantida pela trigger + `REVOKE UPDATE,DELETE`,
> não pela identidade. Ajustar o comentário; manter trigger/revoke intactos.

### 2.2 Tabelas que NÃO mudam de PK

- `passkeys` → **PK fica bigint** (CA-3). `Laravel\Passkeys\Passkey` estende `Model` puro,
  PK incremental int; nenhuma FK de domínio aponta para `passkeys.id`. **Não tocar a
  migration `create_passkeys_table` no PK.** (⚠️ a ADR-018 listava `passkeys` entre as 15
  tabelas que viram UUID — refinado pelo spike: só o FK `user_id` muda, e isso é automático,
  ver 2.3.)
- `personal_access_tokens` → **PK fica bigint** (Sanctum default, Decisão 4). Só `tokenable`
  muda (ver 2.4).
- `cache`, `cache_locks`, `jobs`, `failed_jobs`, `password_reset_tokens` → **não mudam**
  (Decisão 3).
- `sessions` → fica como o framework entrega **EXCETO `user_id`** (ver 2.3, item crítico).

### 2.3 FKs: `foreignId(...)` → `foreignUuid(...)`

Cada `foreignId('x')->constrained(...)` vira `foreignUuid('x')->constrained(...)`
(mantendo os mesmos `->nullable()`, `->cascadeOnDelete()`, `->restrictOnDelete()`,
`->nullOnDelete()`, `->after(...)`). Lista completa **apps/api**:

| Migration | Coluna FK | Aponta para |
|---|---|---|
| `…profissional_profiles_table` | `user_id` | users |
| `…contratante_profiles_table` | `user_id` | users |
| `add_pre_cadastro_columns_to_profissional_profiles` | `funcao_id` | funcoes |
| `…templates_and_template_versoes` | `template_id` | templates |
| `…templates_and_template_versoes` | `criado_por_admin_id` | users |
| `completar_cadastro_profissional_e_aceites` | `template_versao_id` | template_versoes |
| `completar_cadastro_profissional_e_aceites` | `user_id` | users |
| `create_cadastro_lembretes_table` | `user_id` | users |
| `create_vagas_table` | `contratante_id` | users |
| `create_vagas_table` | `funcao_id` | funcoes |
| `create_vaga_versoes_table` | `vaga_id` | vagas |
| `create_vaga_versoes_table` | `editado_por` | users |
| `create_candidaturas_table` | `vaga_id` | vagas |
| `create_candidaturas_table` | `profissional_id` | users |
| `create_candidaturas_table` | `vaga_versao_id` | vaga_versoes |
| `create_audit_logs_table` | `actor_id` | users |
| `create_admin_audit_log_table` | `actor_id` | users |
| `create_notificacoes_table` | `destinatario_id` | users |
| `create_notificacoes_table` | `vaga_id` | vagas |
| `create_notificacoes_table` | `candidatura_id` | candidaturas |

**apps/admin** (mesmo padrão): `profissional_profiles.user_id`,
`contratante_profiles.user_id`, `add_pre_cadastro…profissional.funcao_id`,
`templates.criado_por_admin_id` (e `template_id` em template_versoes),
`admin_audit_log.actor_id`.

#### ⚠️ CRÍTICO — `sessions.user_id` (api E admin)

A migration `0001_01_01_000000_create_users_table.php` (de ambos os apps) cria a tabela
`sessions` com `$table->foreignId('user_id')->nullable()->index()`. O `SESSION_DRIVER` é
**`database`** em homolog. Quando `users.id` vira UUID, o handler de sessão grava
`Auth::id()` (agora string) em `sessions.user_id`. Se a coluna ficar bigint → **erro de
INSERT (`invalid input syntax for type bigint`) e login quebra**.

→ Trocar para: `$table->foreignUuid('user_id')->nullable()->index();` (sem `constrained` —
o original não tinha FK rígida; manter assim). **Não esquecer o app admin.**

#### `passkeys.user_id` — NENHUMA mudança (automático)

`create_passkeys_table` usa `$table->foreignIdFor(Passkeys::userModel(), 'user_id')`. O
`Blueprint::foreignIdFor()` (Laravel 13) adapta o tipo conforme o `keyType` do User: como
`User` passa a ter `keyType='string'`, a coluna vira `uuid` **automaticamente**. Validado no
CA-3. **Deixe a migration de passkeys intocada** (PK bigint, FK auto-uuid).

### 2.4 Polimórficos

- **`personal_access_tokens` (Sanctum)** — `create_personal_access_tokens_table`:
  trocar `$table->morphs('tokenable');` → `$table->uuidMorphs('tokenable');`.
  Validado no CA-2 (token emitido e resolvido; `tokenable_id` gravado como `uuid` nativo).
  PK `$table->id()` da própria tabela **continua bigint**.
- **`audit_logs.target_id`** e **`admin_audit_log.target_id`** — hoje são colunas **manuais**
  (`$table->unsignedBigInteger('target_id')->nullable();`), **não** `morphs()`. Trocar para
  `$table->uuid('target_id')->nullable();`. Manter `target_type string(100)` e o
  `$table->index(['target_type','target_id'])`. (apps/api tem `audit_logs` e
  `admin_audit_log`; apps/admin tem `admin_audit_log`.)

---

## 3. Seeders, factories e código de domínio a auditar

- [ ] **Seeders** (`apps/api/database/seeders/`, `apps/admin/database/seeders/`): varrer por
  **IDs numéricos hardcoded** (ex.: `'funcao_id' => 1`, `->find(1)`, `whereId(1)`). Com UUID
  esses literais quebram. Onde houver, capturar o id retornado por `create()` em variável e
  reusar (`$funcao->id`). Referências a `->id` em si continuam válidas (retornam string).
  Atenção a `PainelCandidatosSeeder`, `VagasStressSeeder` (citado no `phpunit.xml`) e qualquer
  seeder que monte FK por número.
- [ ] **Factories** (`database/factories/`): `definite()` que seta `*_id` por número, ou
  `->state(['x_id' => 1])`. Trocar por relação/factory (`Funcao::factory()`), que gera o uuid.
- [ ] **`idempotency_key`** de e-mail/notificação: convenção `<tipo>:<id>` continua válida com
  id string (fica mais limpa). Sem mudança de lógica — só confirmar que nada faz cast do id
  para int ao montar a chave.
- [ ] **Casts de model**: confirmar que nenhum model tem `'id' => 'integer'` em `casts()` (grep
  rápido — hoje não há). Não adicionar cast no id (Eloquent trata uuid como string nativamente).
- [ ] **`score_breakdown` (JSON de candidaturas)** — **sem impacto** (CA-7): o shape
  (`MatchScore::toArray()`) só tem inteiros, labels de estado e prosa; **nenhum ID embutido**.
  Não precisa varrer nem ajustar formato.

---

## 4. Testes a auditar e re-rodar

- [ ] **Suíte Pest (api + admin)**: `php artisan test` em ambos. Procurar asserções e fixtures
  com id numérico (`->assertJsonPath('id', 1)`, `assertSame(1, $x->id)`, `factory ... id=1`,
  rotas `/vagas/1`). Trocar por captura do id real (string) ou regex de uuid.
- [ ] Os dois testes criados pelo spike **ficam no repo como regressão** e devem seguir verdes:
  - `apps/api/tests/Unit/UuidV7GenerationTest.php` (CA-1 — versão 7, ordenação, zero colisão).
  - `apps/api/tests/Feature/SanctumUuidTokenableTest.php` (CA-2 — uuidMorphs do Sanctum).
  - `apps/api/tests/Feature/PasskeysUuidUserTest.php` (CA-3 — foreignIdFor auto-uuid).
  > Esses três são auto-contidos (criam/derrubam tabelas temporárias `ca2_*`/`ca3_*`); não
  > dependem do schema real virar UUID. Mantê-los validando o mecanismo.
- [ ] **Smoke F-NB-1** (CI já roda): `php artisan migrate` + `php artisan migrate:rollback`
  simétricos. Conferir que todo `down()` reescrito reverte o `up()` (especialmente as
  triggers de `audit_logs`/`admin_audit_log`, que já têm down simétrico).

---

## 5. Deploy em homolog (reset) — sequência exata

> ⚠️ **Atenção ao mecanismo de CD atual**: o `release.yml` roda
> `php artisan migrate --force && php artisan db:seed --force` (aditivo). Como vamos
> **reescrever migrations já aplicadas** no banco persistente de homolog, um `migrate` comum
> **não altera** as tabelas existentes (elas já constam como "ran"). É preciso `migrate:fresh`
> **uma vez** para dropar e recriar com o tipo novo.

1. **Mergear STORY-070 na main** (api + admin com migrations/models reescritos, testes verdes
   em CI).
2. **Reset único em homolog** — rodar via Cloud Run Job (mesmo mecanismo do CA-4), com
   `migrate:fresh --seed --force` em vez de `migrate --force`:
   ```bash
   gcloud run jobs execute turni-migrate-homolog --region=southamerica-east1 --project=turni-mvp \
     --args='-c,php artisan migrate:fresh --seed --force' --wait
   ```
   (Recria todo o schema em UUID + reaplica o seed. Apaga os 20 usuários descartáveis —
   premissa confirmada no CA-4.)
3. **Smoke de simetria** (F-NB-1) contra homolog, logo após:
   ```bash
   gcloud run jobs execute turni-migrate-homolog … --args='-c,php artisan migrate:rollback --force && php artisan migrate:fresh --seed --force' --wait
   ```
4. **Reseed invalida sessões** — qualquer aba logada em homolog cairá em 401 (memória
   `reseed-invalida-sessao-browser`); relogar em `/login`. O hook de pré-push também
   reseta o banco local.
5. **CD subsequente**: depois do reset único, o passo `migrate --force` do `release.yml` volta
   a ser suficiente (não há mais troca de tipo). **Não** deixar `migrate:fresh` fixo no
   pipeline — só o reset desta entrega precisa dele.

> **Admin**: o banco real `turni` é do app `api` (memória `backoffice-db-ownership`); o admin
> só replica para teste. Garantir que as migrations do admin foram reescritas **iguais** às do
> api nas tabelas compartilhadas, senão o schema de teste do admin diverge.

---

## 6. Checklist de saída (entregar para STORY-072 validar)

- [ ] `grep -rn '\$table->id()' apps/{api,admin}/database/migrations` só retorna
  `passkeys`, `personal_access_tokens`, `jobs`, `failed_jobs` (e nenhuma tabela de domínio).
- [ ] `grep -rn 'foreignId(' apps/{api,admin}/database/migrations` retorna **vazio** (tudo virou
  `foreignUuid`), exceto o `foreignIdFor` de passkeys.
- [ ] `grep -rn 'unsignedBigInteger.*target_id' …` retorna vazio (virou `uuid`).
- [ ] Suíte Pest verde (api + admin) + os 3 testes do spike verdes.
- [ ] `migrate` + `migrate:rollback` simétricos em CI.
- [ ] Homolog em UUID demonstrado (job de reset + smoke de rollback verdes).
</content>
</invoke>
