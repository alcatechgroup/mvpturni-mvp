---
adr_id: ADR-021
slug: hospedagem-vps-unica-cloudflare
title: Hospedagem em VPS única por ambiente no projeto FoodHub, com Cloudflare na borda e subdomínios achatados
status: proposed  # proposed | accepted | superseded | rejected | deferred
decided_at: null  # YYYY-MM-DD quando virar accepted
decided_by: arquiteto
approved_by: null
supersedes: ADR-004
superseded_by: null
related_adrs: [ADR-002, ADR-004, ADR-008, ADR-011, ADR-012, ADR-016]
related_pdrs: [PDR-003, PDR-011, PDR-015, PDR-017]
related_epics: []
created_at: 2026-07-31
updated_at: 2026-07-31
---

# ADR-021 — Hospedagem em VPS única por ambiente, com Cloudflare na borda

## Contexto

A ADR-004 escolheu GCP com Cloud Run + Cloud SQL + Firebase Hosting, sustentada
explicitamente por dois pilares: **os ~US$2.000 em créditos da parceria Google** (F1,
peso alto) e a promessa de operação gerenciada para um time minúsculo (F2). Ela mesma
registrou os sinais de revisão: *"se a parceria/créditos Google terminarem e o custo
recorrente superar as alternativas → reabrir provedor"* e *"se o `worker` na VM se
mostrar frágil/oneroso → migrar"*.

Três fatos mudaram o terreno desde então:

1. **Os projetos morreram.** `turni-homol` e `turni-prod` foram para `DELETE_REQUESTED`
   no spin-off de 2026-07-31. Não há ambiente no ar para preservar — o que estamos
   decidindo é **onde recriar**, não como migrar sem downtime. O custo de mudança,
   normalmente o maior freio, é aqui praticamente zero.
2. **O contexto organizacional mudou.** Os ambientes passam a viver no projeto
   **FoodHub** (`foodhub-87e0c`), **compartilhado com outras aplicações**. Isso cria um
   requisito que a ADR-004 não tinha: saber, dentro do projeto, o que é do Turni.
3. **O domínio passou para a Cloudflare.** `turni.com.br` já está lá, com outra
   aplicação da casa (`fhp.`, `fhp-api.`) usando a mesma zona.

A ADR-004 também deixou um asterisco confesso: o `worker` (`queue:work` contínuo,
ADR-002) **não cabe no Cloud Run**, que exige servidor HTTP. Isso custou uma VM à
parte no desenho original e, na prática, virou Cloud Run Job + Cloud Scheduler
(IDR-016) depois que a VM nunca funcionou em homolog — cinco lacunas de infra. O
scheduler do Laravel exigiu um **terceiro** Job (STORY-073). Ou seja: três peças
gerenciadas para rodar dois processos que qualquer máquina Linux roda como serviço.

Some-se o acidental acumulado: o cookie de sessão precisou virar `__session` porque o
Firebase Hosting descarta os demais (IDR-019); o `PAGARME_WEBHOOK_TARGET` virou um
apply em duas fases por causa de um ciclo entre URLs de Cloud Run; o Cloud SQL ganhou
um agendador de liga/desliga só para não sangrar custo em homologação.

### Forças desta decisão

- **F1 — Custo recorrente sem créditos:** peso **alto**. Sem os US$2K, o piso do Cloud
  SQL passa a ser o item dominante da conta de um MVP pré-receita (princípio #11).
- **F2 — Menos peças móveis:** peso **alto**. Time de 1–3 pessoas (princípio #1). Cada
  serviço gerenciado a mais é uma superfície de configuração, IAM e depuração.
- **F3 — Identificação dentro de um projeto compartilhado:** peso **alto**. Requisito
  novo: reconhecer o que é do Turni entre recursos de outras apps da FoodHub.
- **F4 — Ausência de exposição direta do origin:** peso **alto**. O intuito original
  era não ter IP público; ver §b para como isso foi resolvido.
- **F5 — IaC e recriação do zero:** peso **alto**. Inalterado desde a ADR-004
  (`quality-standards` 2.3).
- **F6 — Fit dos processos contínuos (worker, scheduler):** peso **médio**. O asterisco
  da ADR-004.
- **F7 — Limite de certificado da Cloudflare:** peso **médio**. Restrição dura, não
  negociável no plano atual (ver §c).

## Opções consideradas

### Opção A — VPS única por ambiente no FoodHub, Cloudflare na borda — **escolhida**
Uma instância Compute Engine `e2-small` por ambiente rodando Caddy, api, admin, worker,
scheduler, WebApp, landing e **Postgres em container**, com disco de dados persistente.
Cloudflare como DNS + proxy; TLS no origin via Caddy com desafio DNS-01.

- **Custo:** ~US$20/mês em homologação, contra ~US$40–60 da topologia anterior sem
  créditos (o Cloud SQL sozinho era a maior linha).
- **Peças:** de sete serviços gerenciados (Cloud Run ×2, Cloud Run Jobs ×2, Cloud SQL,
  Firebase Hosting ×2, Cloud DNS, Cloud Scheduler) para **uma VM + dois buckets**.
- **Worker e scheduler:** viram containers comuns. O asterisco da ADR-004 desaparece.
- **Contras assumidos:** capacidade e disponibilidade passam a ser nossas — um e2-small
  hospeda tudo, então **memória e disco viram modo de falha de sistema inteiro** (daí
  os alertas dedicados no módulo `monitoring`); backup do Postgres passa a ser script
  nosso, não point-in-time recovery gerenciado; e não há mais escala automática.

### Opção B — Manter Cloud Run + Cloud SQL no FoodHub
Recriar a topologia da ADR-004 no projeto novo.
- **Prós:** nada a reprojetar; escala automática; backup gerenciado.
- **Contras:** paga o custo integral **sem os créditos** que justificaram a escolha;
  mantém as três peças para dois processos; mantém o acidental (`__session`, apply em
  duas fases, agendador de liga/desliga do Cloud SQL).
- **Razão de não ser escolhida:** o pilar que a sustentava (F1 via créditos) não existe
  mais, e a complexidade que ela cobrava continua.

### Opção C — VPS com Cloudflare Tunnel, sem IP público
Idêntica à A, mas com ingress via `cloudflared` e **nenhum** endereço externo.
- **Prós:** superfície de rede mínima; era a intenção inicial.
- **Contra decisivo:** sem IP externo a VM não tem saída para a internet, e ela precisa
  (Artifact Registry, apt, API do Resend). A saída exigiria **Cloud NAT — ~US$32/mês**,
  mais caro que a própria VPS e que todo o resto do ambiente somado.
- **Razão de não ser escolhida:** o custo do egress inverteria o principal ganho da
  decisão. Ver §b para o que foi feito no lugar.

### Opção D — Voltar para AWS/Fly.io (alternativas registradas na ADR-004)
- **Razão de não serem escolhidas:** o repositório, o pipeline e o IaC já falam GCP, e
  o restante da operação da casa está no FoodHub. Trocar de provedor agora paga um
  custo de migração para resolver um problema que a Opção A resolve sem sair do lugar.
  Seguem registradas como saída, se a operação da VPS se mostrar cara em tempo de time.

## Decisão

> **Cada ambiente do Turni é uma VPS no projeto GCP FoodHub, com a Cloudflare na
> borda.** A ADR-004 fica **superseded**.

**(a) Topologia.** Uma instância `e2-small` por ambiente (`e2-medium` em produção),
região `southamerica-east1`. Nela, via Docker Compose: Caddy (borda), api, admin,
worker, scheduler, WebApp (estático), landing (estático), Postgres e — só em
homolog/staging — o fake de pagamento. Disco de dados separado do boot, com
`prevent_destroy`, guardando Postgres, uploads, logs e certificados. **A ADR-002 não
muda**: continuam os mesmos três artefatos de entrega mais o worker; muda apenas onde
executam.

**(b) Exposição de rede.** A VPS tem IP externo estático, mas **não é alcançável**:

- o firewall aceita 80/443 **exclusivamente das faixas do proxy da Cloudflare**;
- SSH não tem porta aberta — entra pelo **túnel do IAP**, autorizado por IAM, com OS
  Login (sem chave em metadata);
- uma regra explícita nega todo o resto.

O IP existe pela razão registrada na Opção C: sem ele, a saída para a internet custaria
mais que o ambiente inteiro. A troca é consciente — **superfície de ingresso
equivalente à do túnel, ao custo de US$3/mês em vez de US$32**.

**(c) Subdomínios achatados.** O Universal SSL da Cloudflare cobre o apex e **um** nível
de subdomínio (`*.turni.com.br`), não dois. `app.homolog.turni.com.br` ficaria sem
certificado; cobri-lo exigiria Advanced Certificate Manager, pago. Portanto:

| Papel | homolog | staging | produção |
|---|---|---|---|
| WebApp | `app-homolog.turni.com.br` | `app-staging.` | `app.turni.com.br` |
| Backoffice | `admin-homolog.` | `admin-staging.` | `admin.turni.com.br` |
| API | `api-homolog.` | `api-staging.` | `api.turni.com.br` |
| Landing | `homolog.turni.com.br` | `staging.turni.com.br` | `turni.com.br` (apex) |
| Remetente | `mail-homolog.` | `mail-staging.` | `mail.turni.com.br` |

O padrão já é praticado na zona por outra aplicação da casa (`fhp.`, `fhp-api.`).

**(d) TLS.** Caddy no origin, certificado da Let's Encrypt por **desafio DNS-01** com o
token da Cloudflare. HTTP-01 não serviria: a Let's Encrypt não alcança um origin que só
aceita tráfego da Cloudflare. Com certificado público válido no origin, a zona fica em
**Full (strict)** — e não no modo "Flexible", que deixaria o último hop em claro.

**(e) Same-origin do WebApp.** O Caddy serve o bundle Flutter e encaminha `/api`,
`/sanctum`, `/forgot-password` e `/reset-password` para o container da api **no mesmo
host**. É o que o rewrite do Firebase Hosting fazia (STORY-016) e o que mantém o cookie
de sessão do Sanctum same-site. **Consequência boa:** o `SESSION_COOKIE=__session`
(IDR-019) deixa de ser necessário — era imposição do Firebase Hosting, que descartava
todo cookie exceto aquele nome.

**(f) Nomenclatura e labels.** Num projeto compartilhado, identificação é requisito:
`turni-<env>-<recurso>` para recursos de ambiente, `turni-<recurso>` para
compartilhados, e as labels `app=turni`, `env`, `component`, `managed-by=terraform` em
tudo que as aceita. Buckets levam o `project_id` como sufixo (namespace global).
Detalhe em `infra/README.md`.

**(g) Segredos.** Secret Manager, como na ADR-004 §f. A VPS os lê **em runtime**, com a
identidade da instância, e escreve um `.env` 600/root recriado a cada boot e a cada
deploy. Nenhum segredo trafega pelo bucket de configuração, pelo git ou pelos metadados
da VM. O acesso é concedido segredo a segredo: a VPS de homolog não enxerga segredo de
produção.

**(h) Deploy.** Tag `vX.Y.Z-rc.N` → homolog automático; `vX.Y.Z` → produção com gate
humano de 1 clique (GitHub Environment) — **inalterado** (`quality-standards` 2.2). O
pipeline publica imagens no Artifact Registry compartilhado e executa **um comando na
VPS por SSH através do túnel IAP**, autenticado por WIF (sem chave). O deploy tira um
dump do banco antes de migrar, aplica migrações, sobe a stack e valida `/health`.
Um workflow no lugar de três (o `landing-deploy.yml` e o `deploy-stage.yml` foram
absorvidos).

**(i) Rollback.** `deploy.sh --rollback` volta para a tag anterior **que ficou
saudável**. Migração segue **forward-only** (`quality-standards` 2.4): o rollback
devolve o código, não o schema. Para dado, o caminho é o restore do dump.

**(j) Backup.** Dump diário do Postgres para bucket com lifecycle de retenção (30 dias
em homolog, 90 em produção), mais um dump rotulado a cada deploy. Substitui o
point-in-time recovery do Cloud SQL — com honestidade sobre a diferença: **a janela de
perda passa de minutos para até 24 horas** fora dos dumps de deploy.

**(k) Observabilidade.** A ADR-008 continua valendo; muda a origem. Ops Agent na VPS,
com um receiver por serviço lendo o arquivo JSON que cada um escreve — o que dá um
**log name por serviço** (`turni-<env>-api`, `-admin`, `-worker`, `-scheduler`,
`-caddy`) e preserva os filtros das métricas de negócio, que antes se apoiavam em
`resource.type`. Novidade: alertas de **memória e disco da VPS**, porque capacidade
deixou de ser problema do Google.

**(l) Landing.** ADR-012 preservada: apex serve "Em breve", a landing AS IS vive no
path secreto, e o `robots.txt` é gerado do template. O gate migrou do workflow para o
build da imagem — mesmas validações, agora falhando no build em vez de no deploy.

## Consequências

### Positivas
- Custo de homologação de ~US$40–60 para **~US$20/mês**, sem depender de créditos.
- De sete serviços gerenciados para **uma VM**; o `queue:work` e o scheduler viram
  containers comuns e o asterisco da ADR-004 desaparece.
- Três acidentes somem: `__session`, o apply em duas fases do webhook e o agendador de
  liga/desliga do Cloud SQL.
- Um workflow de deploy no lugar de três.
- Portabilidade real: Docker Compose + Postgres rodam em qualquer VPS de qualquer
  provedor. O lock-in cai em relação à ADR-004.

### Negativas / trade-offs aceitos
- **Ponto único de falha por ambiente.** Tudo numa máquina: um OOM derruba as quatro
  superfícies de uma vez. Mitigação: alertas de memória/disco, swap, `restart:
  unless-stopped`, e `systemd` subindo a stack no boot. Não é alta disponibilidade —
  e o SLO de ≥99,5% do WebApp deve ser reavaliado contra isso quando produção subir.
- **Manutenção de SO.** Patches do Debian, do Docker e do Postgres passam a ser nossos.
- **Backup com janela maior.** Ver §j.
- **Sem escala automática.** Crescer é `machine_type` no Terraform e um reboot.
- **Certificado limitado a um nível de subdomínio** (§c), o que fixa o formato dos hosts
  enquanto não houver ACM.
- **O `terraform apply` local depende do token da Cloudflare no `.env`.** É um segredo
  de alto poder (edita DNS da zona inteira, compartilhada com outra aplicação) fora do
  cofre. Aceito porque é o mesmo token que a Cloudflare exige para DNS-01, e ele é
  copiado para o Secret Manager no apply — mas é o candidato número um a rotação.

### Para o time
- **Impacto em ADRs:** substitui a ADR-004 inteira. ADR-002 (topologia) inalterada.
  ADR-008 mantida com origem de log nova (§k). ADR-011 mantida (Resend). ADR-012
  mantida com mecânica nova (§l). ADR-016/PDR-017 mantidas — o fake segue fora de
  produção, agora por profile do compose.
- **IDRs afetadas:** IDR-016 (worker como Cloud Run Job) e IDR-019 (`__session`)
  perdem objeto. IDR-003 (admin interno + IAP) perde o mecanismo: hoje o Backoffice
  fica atrás do proxy da Cloudflare em host próprio — **restringir o acesso ao
  Backoffice é uma decisão em aberto** (Cloudflare Access é o caminho natural).
- **Runbooks:** os cinco anteriores foram substituídos por
  `docs/operacao/runbook-vps.md`.

## Plano de verificação

- Nenhum recurso criado fora do Terraform (`terraform plan` sem drift). O CI roda
  `terraform fmt -check` e `validate` em todo PR.
- Nenhum segredo literal no repositório; os valores chegam por Secret Manager.
- A VPS não responde fora da Cloudflare: `curl` direto no IP deve dar timeout.
- Zona em Full (strict) com certificado válido emitido pelo Caddy.
- **A validar no primeiro bring-up:** que as linhas do Laravel chegam ao Cloud Logging
  já parseadas (`jsonPayload.message`, `jsonPayload.context.*`). Todas as métricas de
  negócio dependem disso e a falha é silenciosa — a métrica fica simplesmente sem dado.
- Recriar do zero: `terraform apply` + publicar uma tag + smoke verde nas quatro
  superfícies.

### Sinais de revisão
- Se a indisponibilidade do ponto único passar a custar mais que a economia → separar
  banco (Cloud SQL ou gerenciado) e/ou duplicar a VPS atrás de um balanceador.
- Se a manutenção de SO consumir > 10% do tempo do time → reavaliar PaaS.
- Se o volume exigir escala elástica → reabrir Cloud Run para as superfícies HTTP,
  mantendo o banco na VPS.

---

## Aprovação humana

> Registro formal do aceite. Preencher quando o humano aprovar.

- **Status final:** pendente
- **Aprovado por:** —
- **Data:** —
- **Forma do aceite:** —
- **Condicionantes do aceite:** —

### Em caso de rejeição
- **Motivo:** ...
- **Próximos passos sugeridos:** reabrir a Opção B (recriar a topologia da ADR-004 no
  FoodHub) ou a Opção C, absorvendo o custo do Cloud NAT.

---

## Histórico

- 2026-07-31 — criada como `proposed` por Arquiteto. Motivada pela desativação dos
  projetos `turni-homol`/`turni-prod`, pela mudança para o projeto compartilhado
  FoodHub e pelo fim dos créditos que sustentavam a ADR-004. Direção (VPS única, três
  ambientes, Cloudflare, subdomínios achatados) definida por Alexandro na sessão de
  2026-07-31; a opção sem IP público foi descartada na mesma sessão, ao custo do
  Cloud NAT.
