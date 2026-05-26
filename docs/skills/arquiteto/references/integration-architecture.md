# Arquitetura de integrações externas

Turni vai integrar com sistemas externos: **Pagar.me** (pré-autorização, captura, Pix split — única integração financeira do MVP, ver PDR-004), provedor de e-mail transacional, push notifications web (PWA), geolocalização (browser API + eventualmente serviço dedicado), e futuramente WhatsApp/SMS e API pública para Enterprise. **Cada integração é decisão arquitetural** — não é "só fazer chamada HTTP".

Esta reference cobre como pensar uma integração de modo durável: encapsular o externo, manter testabilidade local, lidar com falhas graciosamente, evoluir contratos.

---

## A mentalidade

- **O externo é incerto.** Pode estar fora do ar, lento, mudar contrato sem aviso, retornar dado inesperado. **Você desenha pra isso desde o início.**
- **O externo não dita o seu modelo de dados.** Sua aplicação fala o **seu** vocabulário; tradução para o vocabulário do externo acontece em um ponto bem definido.
- **Local funcional 100%.** Princípio arquitetural #6: integração externa **nunca** trava dev local. Mock em container resolve.
- **Custo recorrente.** Integração externa custa — financeiramente, operacionalmente, em risco. Vale a pena? Quanto?

---

## Anti-Corruption Layer (ACL) — o padrão central

ACL = **camada de adaptação** que encapsula o externo. Seu domínio fala com a ACL; ACL fala com o externo.

```
┌──────────────────┐
│  Seu domínio     │   ← seus modelos, seu vocabulário
│  (módulo X)      │
└────────┬─────────┘
         │ chama interface limpa
         ▼
┌──────────────────┐
│  ACL (camada     │   ← traduz seu domínio ↔ formato do externo
│  de adaptação)   │       trata retry, timeout, erros, idempotência
└────────┬─────────┘
         │ chama API do externo
         ▼
┌──────────────────┐
│  Sistema         │   ← shape de dados deles, comportamento deles
│  externo         │
└──────────────────┘
```

### Por que ACL importa

Sem ACL:
- O formato do externo vaza por toda a aplicação.
- Mudança no externo (campo renomeado, endpoint depreciado) atinge dezenas de pontos do código.
- Testar fica difícil — você precisa mockar o externo em N lugares.
- Trocar de fornecedor é refatoração massiva.

Com ACL:
- Mudança do externo afeta **um lugar** (a ACL).
- Testes mockam **a interface da ACL**, não o externo cru.
- Trocar de fornecedor = reescrever a ACL, mantendo a interface.
- O domínio permanece limpo, falando o vocabulário do negócio.

### O que vai na ACL

- **Adapter**: chamadas HTTP, mapeamento de formato.
- **Tradução**: campo `cnpj` do externo é `documento` para você? ACL traduz.
- **Retry**: lógica de retry com backoff (cruza com `error-handling.md` do Programador).
- **Timeout**: definido na ACL, não nas chamadas internas.
- **Tratamento de erro**: erros do externo viram exceções **do seu domínio** (ex: `PreAutorizacaoNegadaError` em vez de `HTTP 402` do Pagar.me).
- **Idempotência**: se aplicável (pagamento, etc).
- **Observabilidade**: métricas e log específicos da integração.

### O que NÃO vai na ACL

- Regras de negócio (essas vivem no domínio).
- Decisões de UX (como mostrar o erro — viva no FE).
- Persistência local do resultado (essa é do módulo de domínio).

---

## Definição do contrato esperado

Antes de codificar a integração, **documente o contrato**:

### Esquema

- Endpoints utilizados + métodos.
- Payload de request (com exemplo).
- Payload de response (com exemplo).
- Códigos de erro esperados.
- Limites de rate, tamanho, formato.

### Versionamento do externo

- Que versão da API estamos usando?
- Como saberemos quando o externo atualizar?
- Política do externo para versões antigas (continua por quanto tempo?).

### Variabilidade

- O externo retorna sempre o mesmo formato? Há campos opcionais?
- Como tratamos campos extras (ignorar, falhar, alertar)?
- Encoding, charset, formatação numérica/data — esperado vs real.

**Bom hábito**: documente o contrato em arquivo versionado junto da ACL (`schema.md` ou JSON Schema). Quando o externo mudar, o diff fica visível.

---

## Estratégia de mock para desenvolvimento local

Princípio arquitetural #6 inegociável: **dev local funciona sem internet**. Para cada integração, escolha estratégia:

| Estratégia | Quando usar | Trade-offs |
|---|---|---|
| **Mock dedicado em container** | Integração intensa, uso frequente | Mais fiel, mais controlável; precisa ser mantido |
| **Lib de stub no app (HTTP recorded)** | Integração leve, uso ocasional | Mais simples; menos fiel |
| **Sandbox público do fornecedor** | Quando o fornecedor tem sandbox confiável | Sem custo de manter; depende de internet (viola princípio #6) |

**Para Turni:** integrações principais (Receita, pagamento) merecem **mock dedicado**. Integrações marginais podem usar stub.

### Manter o mock fiel ao real

Mock que diverge vira mentira. Combata com:

- **Contract test** rodando contra **sandbox real** periodicamente (CI noturno) — quando diverge, alguém é notificado.
- **Versão do contrato registrada no mock**: "este mock simula API v3.2 do fornecedor X capturada em 2026-05-20".
- **Atualização do mock como parte da estória** quando o externo muda — não é "tarefa do futuro".
- **Log explícito**: mock em dev loga `[MOCK]` no payload para programador saber que está em simulação.

---

## Contract testing

Tipo de teste que valida que **dois sistemas falam o mesmo contrato**.

### Como funciona

- **Consumer-driven contract**: você (consumer) define o que espera receber do externo. Esse contrato é verificado contra o externo real periodicamente.
- **Tooling**: Pact, Spring Cloud Contract, schemathesis, etc.

### Quando usar

- Integração **crítica** com fornecedor estável.
- Quando você tem influência no fornecedor (ou ele provê endpoint de testes).
- Quando o custo de divergência é alto.

### Quando não compensa

- Integração marginal, baixo volume.
- Fornecedor opaco, sem suporte a contract testing.
- Stack imatura na nossa linguagem para fazer contract testing limpo.

**Para Turni (sugestão):** contract testing leve para integrações críticas (Receita, pagamento). Para marginais (e-mail transacional, etc), mock dedicado + monitoramento de erro em produção atende.

---

## Circuit breaker no nível arquitetural

Diferente do circuit breaker no código (cruza com `error-handling.md`): aqui é **decisão de design** sobre **quais integrações** merecem circuit breaker.

### Critério

- **Sim, com circuit breaker:**
  - Integração crítica para o fluxo do usuário.
  - Externo conhecido por flutuação (alta latência intermitente).
  - Cliente do externo é caro (handshake TLS pesado, etc).
- **Não, sem circuit breaker (ou simples timeout só):**
  - Integração rápida, confiável.
  - Falha tolerável sem cascata (ex: enviar notificação push — se falhar, registra e segue).

ADR de integração específica decide. Não bote circuit breaker em tudo "por garantia" — adiciona complexidade.

---

## Webhook entrante

Quando o externo te chama (não você que chama). Considerações específicas:

### Segurança

- **Validar assinatura**: HMAC com segredo compartilhado é o padrão. Sem validação, qualquer um pode forjar webhook.
- **Validar IP origem** se o fornecedor publica IPs (defesa em profundidade).
- **HTTPS obrigatório** (já implícito).

### Idempotência

- Fornecedor pode reenviar o mesmo evento (estratégia "at-least-once" deles).
- **Use idempotency key** (geralmente o ID do evento do fornecedor) para detectar duplicata.
- Resposta para duplicata: 200 OK com o resultado anterior, **não** processar de novo.

### Recepção rápida

- Webhook **respondeu rápido** ou fornecedor pode timeoutar e retentar.
- Padrão: **receber, validar, enfileirar para processar async**, responder 200 imediatamente.
- Processamento real acontece em job — beneficia também da retentativa local se job falhar.

### Dead letter queue

- Evento que falha N vezes vai para **DLQ** — não retry infinito.
- Alguém investiga depois (humano + processo definido).

---

## Falha do externo — graceful degradation

Quando o externo está fora, **o seu sistema continua útil**? ADR responde.

### Padrões

- **Fail fast com erro claro ao usuário**: "Não conseguimos validar seu CNPJ no momento. Tente novamente em alguns minutos." Melhor que tela genérica.
- **Cache de resultado anterior**: se a resposta é válida por X tempo, cache reduz dependência.
- **Modo degradado**: o sistema funciona com funcionalidade reduzida (ex: notificação por push fora do ar → cai em e-mail) e completa depois quando o canal principal volta.
- **Filaeamento**: operação não-crítica fica esperando externo voltar.

### O que NÃO fazer

- 500 mudo para o usuário.
- Re-tentar infinitamente travando recursos.
- Bloquear fluxo principal inteiro por falha de integração secundária.

---

## Atualizações do externo — como saber, como reagir

Externos mudam. Você precisa **saber** quando muda — antes que quebre.

### Mecanismos

- **Inscrever em changelog/release notes** do fornecedor (RSS, mailing list).
- **Monitorar campo `deprecation` em response headers** (alguns fornecedores enviam).
- **Contract test no CI** detecta divergência precoce.
- **Alerta de erro elevado** em produção captura quando algo silenciosamente quebrou.

ADR de integração inclui **como monitoramos mudança do externo**.

---

## Custo da integração

Custo financeiro + custo de risco. ADR explicita.

### Categorias

- **Pricing do fornecedor**: por chamada? por mês? por volume? freemium?
- **Rate limits**: quantas chamadas/segundo permitidas? Quanto custa exceder?
- **Custo de migração** se trocar de fornecedor (lock-in).
- **Risco de descontinuação**: empresa do fornecedor é estável? Pequena demais?
- **Custo operacional**: tempo de manter ACL, mock, contract test.

### Decisões derivadas

- Se o custo é alto, vale **cachear agressivamente**.
- Se rate limit é apertado, vale **bachear** (juntar várias chamadas).
- Se lock-in é forte, **mais cuidado com ACL** para facilitar troca eventual.

---

## Documentação da integração no projeto

Cada integração relevante vira:

1. **ADR** descrevendo a decisão de integrar (e como).
2. **Pasta/módulo** dedicado para a ACL no código.
3. **Documento de contrato** versionado (idealmente junto da ACL).
4. **Runbook** para incidente comum (externo fora, lentidão, divergência detectada).

Pasta `docs/project-state/integrations/` (a criar) pode reunir esses runbooks por integração.

---

## Integrações conhecidas do Turni

Lista nominal das integrações que o produto já tem (ou terá no MVP) — para evitar redescoberta. Cada uma vira ADR própria quando entrar em escopo.

- **Pagar.me** (única integração financeira do MVP — PDR-004): pré-autorização no aceite do candidato, captura assíncrona na conclusão do turno, **Pix com janela de até 15 min** para repasse, **captura parcial / estorno parcial** para suportar disputa (PDR-006). Webhook entrante para eventos de pagamento — segurança via HMAC, idempotência via event id. Fora do MVP: tratamento de Pix > 15 min (PDR-010) — apenas alerta no backoffice, sem retry automático.
- **E-mail transacional**: aceite eletrônico (PDR-001), aprovação de cadastro, notificação ao candidato quando vaga muda (PDR-009), recuperação de senha, comunicados ao admin. Provedor a decidir em ADR; templates dinâmicos por `tipo_pessoa`.
- **Push notification web (PWA)**: cronograma de turno, alertas de candidatura, notificação de vaga editada (PDR-009). Decisão cruza com a ADR de Frontend/PWA (Web Push API + VAPID, ou serviço terceiro). Identidade do device (subscription) armazenada por usuário.
- **Geo / mapas** (PDR-008 — geofencing alerta-e-registra): cálculo de distância profissional×estabelecimento no check-in. Decisão a tomar em ADR de **Persistência**: PostGIS no Postgres (princípio #3) ou Haversine simples no app? Para o MVP, com poucas leituras simultâneas e raio fixo, Haversine pode bastar — mas PostGIS abre porta para match geo no futuro.
- **(Futuro, não-MVP)** WhatsApp/SMS para notificação de turnos críticos, API pública para clientes Enterprise (com OAuth e versionamento), integração com POS dos contratantes Enterprise (Stone, principalmente). Cada um vira ADR quando entrar em escopo. **Sem antecipação** — princípio #1. Note que PDR-001 exclui validação automática contra Receita no MVP — manual pela equipe Turni.

ADRs específicas de cada integração herdam o checklist abaixo.

---

## Tempo real entre servidor e cliente

Caso particular de "integração" — mas com o **próprio frontend** como contraparte. No Turni o turno tem **cronômetro bilateral vivo** (lados profissional e contratante veem o mesmo tempo correr) e **eventos cruzados** ("candidato chegou", "contratante validou check-out"). O protótipo simula com `localStorage` storage events; em produção, é decisão arquitetural com 4 opções típicas:

| Mecanismo | Quando faz sentido | Trade-offs |
|---|---|---|
| **Polling curto (5–10s)** | Eventos toleram latência de segundos; baixo volume | Simples, sem servidor especial; tráfego desnecessário em horas mortas |
| **Long polling** | Compatibilidade ampla, sem WebSocket | Conexão segurada — pressão em conexões HTTP |
| **Server-Sent Events (SSE)** | Fluxo um-sentido (servidor → cliente), nativo no browser, sobre HTTP/1.1 ou HTTP/2 | Não bidirecional; precisa keep-alive bem desenhado |
| **WebSocket** | Bidirecional, baixa latência | Outra superfície de servidor; auth/reconexão a tratar; mais complexo |
| **Web Push** (browser push) | Notificação **com app fechado** | Não é tempo real "dentro do app"; UX intrusiva; latência de delivery variável |

**Sugestão default para Turni (sujeita a ADR formal):** SSE para o cronômetro vivo dentro do app + Web Push para notificações com app fechado. WebSocket apenas se aparecer caso bidirecional real (chat ao vivo, etc.). A decisão é do Arquiteto em ADR `type: Frontend / PWA` ou `type: Contrato` (quando o foco é o protocolo). Tem que considerar: como E2E testa, como mock local funciona, como reconecta, como autoriza por usuário.

---

## Stack de notificações (multi-canal)

Conforme PDR-009 (edição de vaga notifica candidatos) e outros fluxos, o Turni precisa enviar notificações em **múltiplos canais**: in-app (badge/lista), push web, e-mail transacional, possivelmente WhatsApp/SMS no futuro. Tratar cada canal isoladamente leva a duplicação. Padrão recomendado:

- **Domínio emite evento** (`VagaEditada`, `CandidaturaAceita`, etc.).
- **Camada de notificação** (`notification` module) decide **quais canais** disparar para qual destinatário, com **preferências do usuário** respeitadas.
- **Adapters** por canal (e-mail, push, in-app) implementam a entrega — cada um com ACL próprio quando o canal envolve externo (e-mail provider, push service).
- **Persistência da notificação** (in-app) é tabela no Postgres com status (não-lida, lida, descartada).
- **Idempotência por evento** — duplicar `VagaEditada` para o mesmo candidato é silenciado.

A ADR específica deve cobrir: matriz **evento × canal × default**, estrutura de preferências do usuário, retenção, política de retry por canal (push falha silenciosamente; e-mail pode ter bounce; etc.), e como o admin debug uma notificação que "sumiu".

---

## Resumo operacional — ADR de integração externa

Para cada integração externa relevante, o ADR responde:

- [ ] **Por que integrar com esse externo** (vs. construir interno, vs. não fazer).
- [ ] **Contrato**: endpoint, payload, response, erros — com exemplos.
- [ ] **ACL** definida — módulo que encapsula, interface limpa para o domínio.
- [ ] **Estratégia de mock local** definida (mock dedicado, stub, sandbox).
- [ ] **Como mantém mock fiel** ao real.
- [ ] **Contract testing** — sim ou não, com motivo.
- [ ] **Circuit breaker** — sim ou não, com motivo.
- [ ] **Idempotência** — como garantir.
- [ ] **Webhook** (se aplicável) — segurança, idempotência, processamento async.
- [ ] **Graceful degradation** — se externo cai, o que o usuário vê.
- [ ] **Monitoramento de mudança do externo** — como ficamos sabendo.
- [ ] **Custo recorrente** estimado + sinal de revisão.
- [ ] **Trade-offs** aceitos.
- [ ] **Segurança** (cruza com `security-architecture.md`): credenciais, HTTPS, logs sem PII.

Integração externa é um dos lugares onde decisão arquitetural rasa vira dívida estrutural rápido. Vale o investimento de pensar bem.
