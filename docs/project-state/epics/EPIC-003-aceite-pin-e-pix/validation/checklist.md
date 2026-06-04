---
epic_id: EPIC-003
type: validation-checklist
created_at: 2026-06-03
---

# Checklist de validação — EPIC-003

> Para o **validador**: execute cada item em ordem. Para cada um, registre status `pass | fail | n/a` e evidência (link, screenshot, log, comando executado). Não invente resultados. Em caso de falha, **não tente consertar** — registre e devolva para o PO. Aprendizado herdado de STORY-011/025/054: validador se atém a evidência + veredito; planejar correções é papel do PO.

## 1. Critérios de aceite das estórias

- [ ] Todas as estórias (STORY-055..067) estão com `status: done` no `index.json`.
- [ ] Cada CA listado em cada `story.md` foi exercido por pelo menos um teste automatizado **ou** verificação manual com evidência (screenshot/log).
- [ ] Nenhuma estória `done` com CA `[ ]` desmarcado (regra herdada).

## 2. Modelo + máquina de estados (STORY-055 / ADR-015)

- [ ] As 13 transições válidas de `domain/turno.md` são aceitas; 5 transições inválidas representativas (ex: `confirmado → finalizado` direto) levantam erro (teste explícito).
- [ ] AceiteEletronico do turno é imutável — tentativa de `UPDATE` ou `DELETE` direto no Postgres falha (rodar comando, anexar saída).
- [ ] AceiteEletronico aponta para `TemplateVersao` específica vigente no momento da aprovação; mudança posterior do template **não** altera aceite existente.
- [ ] Índice `(estabelecimento_id, profissional_id, data_inicio)` existe e é usado pela consulta de habitualidade (anexar `EXPLAIN ANALYZE`).

## 3. ACL de pagamento + fake genérico (STORY-056 / ADR-016 revisada pós-PDR-017)

- [ ] Fake genérico em container roda localmente (`docker compose up`) sem internet — confirmar que `make setup` continua 100% offline.
- [ ] ~~Contract test consumer-driven contra sandbox real~~ — **REMOVIDO por PDR-017** (Pagar.me sandbox sai do MVP; STORY-056-B abandonada).
- [ ] Idempotência: 2 chamadas de `preAutorizar` com mesma chave geram 1 pré-autorização (teste rodado em homolog ou local).
- [ ] Webhook entrante valida assinatura HMAC; payload com assinatura inválida retorna 401 (teste explícito). **Webhook é emitido pelo fake** (HMAC compartilhado), contrato Pagar.me-compatível.
- [ ] Fake configurável: modos `success`, `fail_capture`, `fail_pix`, `delay_pix` exercitados em testes — caminho de exceção do PDR-010 demonstrado deterministicamente.

## 4. Tempo real + geolocalização (STORY-057 / ADR-017)

- [ ] Prova de conceito da STORY-057 rodando em homolog — turno seedado em `ativo` mostra cronômetro avançando em 2 navegadores simultâneos.
- [ ] Cálculo de Haversine reusa helper `Support\Geo` da STORY-049 (verificar reuso, não duplicação).

## 5. Caminho feliz ponta a ponta — métrica primária

- [ ] **Seedar 20 turnos** percorrendo o caminho `confirmado → aguardando_checkin → ativo → aguardando_checkout → finalizado → Pix simulado` em homolog (fake em modo `success`).
- [ ] **≥ 95% completam** o ciclo (≥ 19 de 20). Documentar resultado.
- [ ] **≥ 95% dos Pix em ≤ 15 min** após captura. Documentar com timestamps reais (criação → captura → Pix).
- [ ] Validação de PIN ≤ 500ms p95 — extrair do log JSON estruturado da última semana de homolog.
- [ ] Cronômetro bilateral em sincronia ≤ 2s — abrir 2 navegadores no mesmo turno `ativo` por 5min, anexar screenshot/vídeo.

## 6. Habitualidade (PDR-002) nos 4 cenários

- [ ] PF profissional 1ª alocação na semana — libera (turno criado).
- [ ] PF profissional 2ª alocação na semana — libera.
- [ ] PF profissional 3ª alocação na semana — bloqueia com mensagem clara em ambos os lados (admin + perfil profissional).
- [ ] PJ profissional 3ª alocação com override — turno criado com cláusula adicional no AceiteEletronico (`habitualidade.override_aceito: true`).
- [ ] Transição de semana (Seg) — contador reseta (teste com travel-time).

## 7. Geofencing (PDR-008)

- [ ] Geofencing OK (dentro do raio 100m): flag `true`, distância < 100m, contratante não vê aviso destacado.
- [ ] Geofencing fora do raio: flag `false`, distância > 100m, contratante vê aviso destacado, **pode validar mesmo assim**.
- [ ] Geolocalização negada pelo navegador: flag `false`, `razao: 'permissao_negada'`, `distancia_metros: null` — contratante vê aviso "localização não disponível", **pode validar mesmo assim**.

## 8. Cancelamento + no_show (STORY-066 / PDR-007 / PDR-010)

- [ ] Cancelamento por profissional em `confirmado` → `cancelado_pro` + pré-autorização liberada (verificar via `pagamento_operacoes` no Postgres: registro de `liberar` com status `concluida`; audit log `pagamento.liberado`).
- [ ] Cancelamento por contratante em `confirmado` → `cancelado_emp` + liberação.
- [ ] `no_show_pro` automático após X horas (decisão registrada) — cron exercitado com `travel(Xh + 1m)` em homolog ou via teste de integração; pré-autorização liberada.
- [ ] Tentativa de cancelar em `ativo`/`aguardando_checkin`/`aguardando_checkout`/`finalizado` → 422 (não permitido por `domain/turno.md`).

## 9. Captura + Pix + alerta de falha (STORY-065 / PDR-010)

- [ ] Captura observada via `pagamento_operacoes` no Postgres + audit log `pagamento.capturado` + evento `PagamentoCapturado` emitido (extrair do log JSON).
- [ ] Pix observado via `pagamento_operacoes` + audit log `pix.enviado` + evento `PixEnviado` emitido. **Fake genérico — Pix não cai em chave real** (PDR-017). Detalhe do turno mostra "Pix enviado em HH:MM" no card de valor (visível ao profissional).
- [ ] Falha simulada de Pix (mock retorna erro) → audit log `pix.falhou` + fila do admin destaca turno + nenhum retry automático (PDR-010).
- [ ] Admin marca "Resolvido manualmente" → audit log registra com nota.

## 10. Notificações (STORY-067)

- [ ] 8 templates `TemplateVersao` ativa carregados (categoria `email`), texto-seed v1 do PO aprovado.
- [ ] 8 listeners disparam notificação correta para o destinatário certo nos 8 eventos.
- [ ] SLA p95 ≤ 60s observado no log-based metric (extrair da última semana).
- [ ] E2E Mailpit em homolog cobre 3 cenários (mínimo): `turno_confirmado`, `checkin_solicitado`, `pix_enviado`. 0 flake em 3 runs.
- [ ] Idempotência: re-emitir evento `TurnoCriado` para o mesmo turno **não** gera 2ª notificação.

## 11. Cobertura de testes

- [ ] api ≥ 80% no código novo; ≥ 98% no núcleo (modelo Turno, máquina de estados, ACL de pagamento + fake, PIN, geofencing, habitualidade).
- [ ] admin ≥ 80%.
- [ ] webapp ≥ 80%; 98% nas regras críticas (geração de PIN, cálculo de duração).
- [ ] E2E `integration_test` cobre ciclo completo do turno em pelo menos 1 cenário em Chrome headless.
- [ ] Playwright smoke HTTP verde no build deployado.

## 12. Automação + deploy

- [ ] `make setup` continua funcionando em máquina limpa, 100% offline (fake genérico em container — princípio #6; PDR-017 mantém o offline-first ao remover sandbox externo).
- [ ] Pipeline CI verde no branch principal nos últimos 5 deploys.
- [ ] Deploy automático em homolog disparado pela tag — testado pelo menos 3 vezes durante o sprint.
- [ ] Provisionamento por Terraform — sem clique manual no Console GCP.

## 13. RBAC + segurança

- [ ] Profissional A não vê turno do profissional B → 403 (teste explícito).
- [ ] Contratante X não vê turno do contratante Y → 403.
- [ ] Profissional não chama endpoints de contratante (e vice-versa) → 403.
- [ ] Admin tem acesso a tudo no Backoffice.
- [ ] Trivy / gitleaks limpos nos últimos 5 PRs.

## 14. LGPD + segurança de dados

- [ ] Dados sensíveis criptografados em repouso (ADR-009) — chave Pix, CPF, CNPJ.
- [ ] PIN guardado server-side hasheado (nunca plaintext em logs após resposta inicial).
- [ ] AceiteEletronico imutável (CA-3 da STORY-055).
- [ ] Audit log imutável (espelha CA da STORY-054 — trigger Postgres).

## 15. Observabilidade

- [ ] Log JSON em todas as operações financeiras com `request_id` propagado `api`→fila→`worker`.
- [ ] Log-based metrics no Cloud Monitoring: taxa de erro de operações financeiras (SLO ≤ 1%), latência p95 captura, latência p95 webhook.
- [ ] Alerta de orçamento GCP ainda operante (herdado de STORY-007).

## 16. Acessibilidade

- [ ] PIN check-in/check-out renderizado em tipografia ≥ 64pt + contraste AAA.
- [ ] Navegação por teclado funcional nas telas críticas (login → lista → detalhe → ação de PIN).
- [ ] Microcopy de erro clara em pt-BR (DDR-002).

## 17. Documentação

- [ ] README do componente atualizado onde relevante.
- [ ] 3 ADRs (015, 016, 017) `accepted` no `index.json`.
- [ ] IDRs eventuais (se algum surgiu) indexados.
- [ ] Notas do agente preenchidas em cada estória.
- [ ] `runbook-homolog.md` atualizado com seção sobre **fake de pagamento em homolog** (deploy + modos configuráveis + segredo HMAC) + reset de cronômetro travado + tratamento manual de Pix com falha (com fake em modo `fail_pix`).
- [ ] **Banner global em homolog "Ambiente de teste — pagamentos simulados" visível** no WebApp e no Backoffice (verificação visual — STORY-075).

## 18. Veredito

- [ ] **APROVADO** — todos os itens acima `pass` ou `n/a` justificado.
- [ ] **APROVADO COM PENDÊNCIAS** — 0 fails bloqueantes; fails não-bloqueantes documentados como `F-NB-N` para carry-forward; PO decide se aceita o veredito como goal-atingido.
- [ ] **REPROVADO** — pelo menos 1 `fail` bloqueante. Liste no relatório quais. PO abre estórias de correção; **NÃO** sugira correções, apenas registre o fato.

Preencha o relatório final em `report.md`.
