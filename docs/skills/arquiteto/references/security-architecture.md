# Arquitetura de Segurança

Esta reference cobre as decisões **estruturais** de segurança que são do Arquiteto. O Programador tem `docs/skills/programador/references/security-discipline.md` com os hábitos diários (validação, segredos no código, autz por recurso). **Aqui** estão as decisões que **viram ADR** e que enquadram o que o Programador faz no dia a dia.

Turni é marketplace de hospitalidade on-demand — dados de balanço, faturamento, possíveis integrações com gateway de pagamento (Pix) e gateways de pagamento. A régua de segurança é alta. **Segurança não é fase no fim do projeto — é decisão arquitetural cedo, e cedo significa nos primeiros ADRs do EPIC-000.**

---

## A mentalidade do Arquiteto em segurança

- **Defesa em profundidade.** Nenhuma camada confia que a outra fez seu trabalho. FE valida, BE valida, banco tem constraint, gateway tem WAF. Cada camada é uma chance a mais de pegar.
- **Princípio do menor privilégio.** Aplicado a usuários, serviços, credenciais, conexões. Cada um tem **só o necessário**.
- **Fail-secure.** Quando algo falha ou está em estado indefinido, o default é **negar acesso**. Nunca "deixar passar e ver no que dá".
- **Threat model explícito.** Para feature relevante, pense em quem é o adversário, o que ele quer, e como o impede. Não é exercício teórico — é parte do design.
- **Privacy by design.** LGPD não é checkbox no fim. É restrição que molda a estrutura.

---

## Modelo de autenticação

A escolha do modelo é ADR `type: contrato` ou `type: stack` — uma das primeiras a tomar. Opções típicas:

| Modelo | Quando faz sentido | Trade-offs |
|---|---|---|
| **Sessão server-side** (cookie + store no banco/cache) | App tradicional, mesma origem FE/BE, controle fino de logout, baixa complexidade | Stateful (Postgres-first resolve), cookie management, CSRF a tratar |
| **Token Bearer (JWT)** | API consumida por múltiplos clientes (mobile, SPA isolada), stateless | Revogação é difícil (precisa lista de bloqueio ou TTL curto), exposição de claims, refresh token a desenhar |
| **OAuth 2.0 / OIDC com provedor** | Quando há login social ou SSO corporativo | Dependência externa, complexidade de fluxos, ainda precisa de sessão/token interno |
| **Passwordless / magic link / WebAuthn** | UX moderna, sem fricção de senha | Maturidade variada por linguagem/framework, fluxo de recovery a desenhar |

**Para Turni (suposição razoável até ADR formal):** usuário humano via sessão server-side com cookie é o padrão simples e seguro. Token só se a arquitetura realmente precisar (mobile nativo, API pública). **Decisão é via ADR explícita.**

**O ADR de autenticação deve responder:**
- Mecanismo escolhido + por quê (alternativas rejeitadas com motivo).
- Duração da sessão / token + critério.
- Como funciona logout (server-side invalida; client-side só apaga não é suficiente).
- MFA: oferecido? Obrigatório para quais perfis?
- Recovery (esqueci senha): mecanismo, rate limit, expiração.
- Bloqueio após N tentativas falhas.
- Auditoria: login bem-sucedido, falho, troca de senha — viram audit log.

---

## Modelo de autorização

Distinto de autenticação. **Quem você é** ≠ **o que pode fazer**.

### Modelos típicos

- **RBAC (Role-Based Access Control)**: usuário tem **papéis** (admin, contratante, profissional), cada papel tem **permissões**. Simples, eficaz para a maioria.
- **ABAC (Attribute-Based Access Control)**: decisão baseada em atributos do usuário, recurso, ambiente. Mais flexível, mais complexo.
- **ACL (Access Control List)**: lista explícita do que cada usuário acessa em cada recurso. Para casos onde permissão é caso a caso.
- **Híbrido**: RBAC para grosso + verificação de propriedade no recurso ("profissional só vê os turnos das vagas onde foi aceito, contratante só vê suas vagas").

**Para Turni:** RBAC + verificação de propriedade do recurso é provavelmente o ponto certo. Papéis típicos: contratante (gestor de operações), profissional, admin do sistema, suporte. **Decisão via ADR formal.**

### O que o ADR de autorização deve definir

- Modelo (RBAC, ABAC, etc) + por quê.
- Catálogo inicial de **papéis** com permissões de cada.
- Como uma operação verifica autorização (camada — middleware? decorator? em cada handler?).
- **Verificação de propriedade**: como garantir que usuário acessa só recursos dele (multi-tenancy do dado).
- Auditoria: operações sensíveis viram audit log (cruza com `nfr-architecture.md` e `security-discipline.md`).
- Como permissões evoluem (migração quando adicionar papel ou permissão).

### Multi-tenancy (separação por empresa/dono)

Turni tem múltiplos donos. Decisão arquitetural: como **isolar** dados entre tenants.

- **Tenant ID na tabela** + filtro obrigatório em todo query (mais comum, mais simples).
- **Schema por tenant** (raro, justifica em casos específicos).
- **Database por tenant** (raríssimo, para casos com requisito forte de isolamento legal).

Cada opção é ADR — registre, justifique. **Para Turni:** tenant ID na tabela é provavelmente certo (princípio simplicidade, princípio Postgres-first).

**Risco a mitigar arquiteturalmente**: query sem filtro de tenant vaza dados. Mecanismos:
- ORM com filtro automático por tenant (middleware ou scope global).
- Row-level security do Postgres (poderoso, complexidade média).
- Linter/teste arquitetural que detecta queries sem filtro.

ADR escolhe o mecanismo. Princípio "automatizável > documentável" — não confie só em "todo dev se lembra de filtrar".

---

## Classificação de dados

Nem todo dado tem mesma sensibilidade. Decisão arquitetural: classificar e tratar diferente.

### Esquema sugerido

| Classe | Exemplos | Tratamento |
|---|---|---|
| **Público** | Logo da empresa, descrição pública do produto | Sem restrição |
| **Interno** | Dados operacionais do app (status de job, contador, etc) | Acesso autenticado |
| **Pessoal (LGPD)** | Nome, e-mail, telefone, endereço, CNPJ pleno | Acesso autorizado, mascaramento em log, retenção definida |
| **Pessoal sensível (LGPD)** | Saúde, religião, opinião política — provável que **não tenhamos** | Restrição forte, base legal específica, criptografia at-rest, audit log obrigatório |
| **Financeiro** | Balanço, faturamento, transação, scoring | Igual a pessoal + audit log de leitura, considerar criptografia at-rest |
| **Credencial** | Senha (hash), token, chave API | Hash apropriado (bcrypt/argon2), nunca em log, não retornado em API |

ADR classifica os tipos de dado do domínio e define tratamento.

### Decisões derivadas

- **Criptografia at-rest**: para classes Pessoal e Financeiro, considere criptografia em coluna sensível (no nível de aplicação ou Postgres com pgcrypto). Justifique no ADR.
- **Criptografia in-transit**: HTTPS obrigatório (já implícito), TLS 1.2+, certificados rotacionados.
- **Mascaramento em log**: lista de campos que viram `[REDACTED]` automaticamente — implementação automatizada, não "lembre de mascarar".
- **Retenção**: cada classe tem prazo. ADR define + mecanismo de purga.

---

## Gestão de segredos

ADR define infraestrutura de segredos. Opções:

- **Variáveis de ambiente** injetadas via plataforma (mais simples).
- **Cofre dedicado** (Vault, AWS Secrets Manager, Doppler, etc).
- **KMS** para criptografar segredos antes de armazenar.

**Para Turni (suposição):** variáveis de ambiente via plataforma do provedor de cloud no início. Cofre dedicado quando complexidade justificar. **Decisão via ADR.**

**O ADR de segredos cobre:**
- Mecanismo.
- Rotação (com qual cadência, processo).
- Quem tem acesso a quais segredos.
- Como o ambiente local recebe segredos (sem credencial real — princípio "100% local").
- Scanner CI para detectar segredo commitado (princípio "automatizável > documentável").

---

## Threat modeling — não como teatro

Para features que envolvem **input externo, dado sensível, dinheiro, ou superfície nova de ataque**, o ADR deve incluir um **threat model leve**. Não precisa ser STRIDE completo formal — basta perguntar e responder:

1. **Quem é o adversário?** Curioso, criminoso oportunista, ex-funcionário, scraper, ataque coordenado.
2. **O que ele quer?** Acessar dado de outra empresa, fraudar pagamento, derrubar serviço, vazar PII, modificar dado.
3. **Como ele tenta?** SQL injection, abuso de API, força bruta, social engineering, exploit de dependência.
4. **Como o impedimos?** Cite o mecanismo concreto.
5. **Como sabemos se ele teve sucesso?** (audit log, alerta, métrica).

3-5 linhas em uma seção do ADR. Salva muito problema futuro.

**Quando o threat model identificar risco grande** sem mitigação satisfatória: a decisão é `rejected` ou `deferred` — não "aceito com risco".

---

## Defense in depth — em camadas arquiteturais

Pense em segurança como camadas. Cada camada é uma chance a mais de pegar.

```
┌────────────────────────────────────────┐
│ Cliente (FE, mobile, terceiro)         │
│   ↓ HTTPS + CSP + validação de UX      │
├────────────────────────────────────────┤
│ Edge (CDN, WAF, rate limit)            │
│   ↓ rate limit em endpoint sensível    │
├────────────────────────────────────────┤
│ App (BE, framework opinativo)          │
│   ↓ autn + autz + validação + audit    │
├────────────────────────────────────────┤
│ Persistência (Postgres)                │
│   ↓ constraint + row-level security    │
│   ↓ criptografia at-rest se aplicável  │
└────────────────────────────────────────┘
```

Cada camada **assume que a anterior pode ter falhado**. Validação no FE é UX — não é segurança. Rate limit no WAF é proteção de força bruta — mas o BE também tem.

ADR de segurança define **as camadas e o que cada uma faz**.

---

## Integração externa — superfície de ataque

Quando o sistema chama (ou é chamado por) sistema externo, surge superfície de segurança. Veja também `integration-architecture.md`. Foco aqui:

- **Sempre HTTPS** com validação de certificado (nunca desabilite, **nem em dev**).
- **Autenticação no canal**: token de fornecedor, mTLS, assinatura HMAC — decisão por integração.
- **Webhook entrante**: validar assinatura (HMAC com segredo compartilhado), verificar IP origem se possível, idempotency key.
- **Token de API do fornecedor**: tratado como segredo de alta sensibilidade.
- **Logs de integração**: registrar request/response **sem expor segredo, payload de pagamento, ou PII desnecessário**.
- **Falha do externo**: graceful degradation — sistema continua útil quando possível.

ADR de cada integração inclui seção de segurança.

---

## LGPD na arquitetura

LGPD é restrição funcional concreta (`docs/especificacao/non-functional.md` + `docs/especificacao/domain/compliance.md`). No nível arquitetural:

### Direitos do titular (Art. 18 LGPD) — implementáveis por design

- **Acesso**: titular pode ver os dados pessoais que temos sobre ele. Endpoint dedicado, processo claro.
- **Correção**: pode corrigir dado errado.
- **Portabilidade**: pode exportar em formato estruturado.
- **Eliminação**: pode pedir deleção. ADR de **soft vs hard delete por tipo de dado** — alguns têm de ir hard (LGPD); outros são soft com retenção justificada.
- **Revogação de consentimento**: rastreabilidade da base legal de cada dado.

ADR define como cada um é implementado. **Não invente arquitetura LGPD na 1ª estória que precisa** — pense desde o EPIC-000.

### Base legal — registro arquitetural

Cada dado pessoal coletado tem **base legal** (consentimento, execução de contrato, legítimo interesse, etc — Art. 7). ADR pode registrar **mapa de bases legais** por tipo de dado, ou cada feature documenta sua base no PR (com PO validando).

### Retenção e eliminação automática

ADR define **política de retenção** por classe de dado + mecanismo de purga automática. Não dá pra fazer purga manual em SaaS.

### DPO / Encarregado

Não é decisão arquitetural per se — mas o ADR de segurança pode registrar quem é responsável (papel humano), e como o sistema **suporta** as ações dele.

---

## Audit log no design

Audit log **não é** log de aplicação (`observability-discipline.md` faz a distinção). Audit log é fonte da verdade jurídica:

- Registra **quem fez o quê, quando, de onde, antes/antes-e-depois**.
- Em banco mesmo (Postgres-first: tabela append-only, com triggers ou via app).
- Retenção longa (LGPD pode exigir; varia por tipo de operação).
- Imutável após escrita (idealmente — `INSERT ONLY`, sem `UPDATE/DELETE`).

ADR de **persistência** inclui modelo de audit log. ADR de **autorização** inclui o que vira audit log e o que não.

**Operações que típica viram audit:** login, criação/alteração/deleção de dado de negócio, mudança de permissão, exportação de dado, acesso a dado sensível, falha de autenticação.

---

## Segregação de interface administrativa (WebApp vs Backoffice)

Decidido em **PDR-003** (Duas interfaces — WebApp e Backoffice): há **duas superfícies de entrada** no Turni com perfis e riscos distintos. Tratá-las como uma única "app com /admin protegido" é o erro a evitar — admin tem trauma maior se for comprometido.

### Por que segregar

- **Público × privado.** WebApp é internet aberta (contratante e profissional). Backoffice é uso interno do time Turni — público restrito, IPs e dispositivos controláveis.
- **Risco assimétrico.** Comprometer um contratante atinge **uma conta**. Comprometer admin atinge **todas**.
- **Carga de auditoria diferente.** Ação de admin geralmente precisa de log mais rico (motivo, evidência, contraparte).
- **Velocidade de mudança diferente.** Backoffice evolui com o time interno; WebApp evolui com o produto.

### Decisões derivadas que ADRs específicas precisam responder

- **Subdomínio dedicado:** `app.turni...` vs `admin.turni...` (ou path-based — mais fraco). Subdomínio separado permite CSP, cookies e WAF distintos.
- **Sessões e cookies isolados:** cookie de admin **não** é o mesmo cookie de WebApp; SameSite estrito; domínio do cookie escopado.
- **Auth potencialmente mais forte no admin:** MFA obrigatório, lista de e-mails permitida, possível restrição de IP/VPN. WebApp pode ter MFA opcional.
- **Modelo de autorização específico para admin:** papéis de admin (`admin_financeiro`, `admin_suporte`, `admin_compliance`) com permissões granulares — distintos dos papéis de WebApp.
- **Audit log mais rico no admin:** toda ação destrutiva ou financeira registra **motivo textual + evidência**, não só "quem/quando/o quê" (ver PDR-006 disputa, PDR-009 edição de vaga, PDR-007 cancelamento).
- **Pipeline e deploy podem ser independentes** (a discutir em ADR Topológica/Infra): mesmo monolito servindo dois hosts, ou builds separados a partir do mesmo monorepo. PDR-003 não fixa o how.
- **CSP, headers de segurança e rate-limit calibrados por interface.** Admin pode aceitar regras mais paranoicas; WebApp precisa equilibrar UX.
- **Erro fail-secure no roteamento:** se uma requisição WebApp chega no host admin (ou vice-versa), **bloqueia** — não tenta servir.

### ADRs que tocam essa segregação

- **ADR Topológica** sobre como o backoffice se materializa: monolito único servindo dois hosts? Bundle web separado? Aplicação Django/Rails admin built-in (princípio #4) vs admin custom?
- **ADR de Autenticação:** sessão única ou duas separadas?
- **ADR de Autorização:** RBAC unificado com papéis admin + WebApp, ou dois sistemas?
- **ADR de Infra:** dois subdomínios, certificados, WAF por host.
- **ADR de Política de evolução:** deploys casados ou independentes; feature flags por superfície.

### Anti-padrão a evitar

- "Já que é monolito, deixa /admin no mesmo host com middleware de permissão". Funciona — até alguém esquecer o middleware em **uma rota**. Segregar por host elimina classes inteiras de erro.
- Reusar regras de RBAC do WebApp no admin sem revisão. Papéis de admin existem **para fazer coisas que usuário comum não pode** — herdar permissões silenciosamente é convite para escalonamento de privilégio.

---

## Quando uma ADR de segurança não é necessária

Nem toda decisão arquitetural envolve segurança como tópico principal. Mas **toda ADR significativa** deve perguntar: "isso introduz risco de segurança?". Se a resposta é não, registre brevemente ("Sem impacto de segurança — feature não toca dado pessoal nem cria nova superfície de entrada"). Se sim, vire seção própria ou ADR dedicada.

---

## Resumo operacional

Antes de propor (ou aceitar como `proposed`) uma ADR de segurança:

- [ ] Modelo de autenticação justificado (alternativas rejeitadas com motivo).
- [ ] Modelo de autorização inclui verificação de propriedade do recurso (multi-tenancy).
- [ ] Classificação dos dados envolvidos, com tratamento definido por classe.
- [ ] Gestão de segredos: como funcionam, como rotacionam, como ambiente local recebe (sem credencial real).
- [ ] Threat model leve em prosa (3-5 linhas).
- [ ] Camadas de defesa explícitas (cliente, edge, app, persistência).
- [ ] LGPD: direitos do titular suportáveis por design; bases legais mapeadas; retenção/eliminação automatizada.
- [ ] Audit log no design — operações relevantes registradas.
- [ ] Princípio "automatizável > documentável" aplicado: linter, teste arquitetural, mascaramento de log são automatizações concretas, não promessas.
