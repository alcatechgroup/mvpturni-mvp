---
epic_id: EPIC-004
type: validation-checklist
created_at: 2026-06-09
---

# Checklist de validação — EPIC-004 (avaliação recíproca e fechamento do ciclo)

> Para o **validador**: execute cada item em ordem. Para cada um, registre status `pass | fail | n/a` e evidência verificável (link, screenshot, log, comando executado, hash de release). Não invente resultados. Em caso de falha, **não tente consertar** — registre e devolva para o PO. O validador se atém a evidência + veredito; planejar correções é papel do PO (regra herdada de STORY-011/025/054/067).
>
> **Estado de homologação no início desta validação:** release vigente do WebApp/API/Admin em `app.homolog` é **≥ v0.1.0-rc.99** (telas + perfil + gate), com follow-ups da STORY-088 em **rc.100** (alinhamento de cards) e **rc.101** (marcador "Avaliar" na lista de turnos). Backend de modelo/motor entrou em rc.92; gate em rc.97; telas em rc.98. Régua de homolog = **smoke HTTP pós-deploy** (IDR-004: `integration_test` não roda contra homolog — só local same-origin).
>
> **Outcome a verificar (em 30s):** após turno `finalizado`, ambos os lados são bloqueados em qualquer próxima ação até avaliarem (estrelas obrigatórias + comentário opcional); XP/score/nível do profissional atualizam; score recíproco e depoimentos ficam visíveis no perfil.

## 1. Critérios de aceite das estórias

- [ ] Todas as estórias do épico (STORY-083..088) estão com `status: done` no `index.json`; STORY-089 é esta validação.
- [ ] Cada CA listado em cada `story.md` (085 CA-1..8, 086 CA-1..6, 087 CA-1..7, 088 CA-1..7) foi exercido por pelo menos um teste automatizado **ou** verificação manual com evidência (screenshot/log).
- [ ] Nenhuma estória `done` com CA `[ ]` desmarcado (regra herdada).
- [ ] Os follow-ups pós-aprovação registrados na STORY-088 (rc.100 alinhamento; rc.101 pílula "Avaliar" + correção do `POST /api/login` que não devolvia `id`) estão refletidos no código e em homolog.

## 2. Modelo de avaliação + imutabilidade + unicidade (STORY-085 / ADR-019)

- [ ] Migração do modelo `avaliacoes` é **reversível** (`migrate:rollback` + `migrate` sem erro — rodar e anexar saída) e cria o modelo conforme ADR-019.
- [ ] Unicidade **1 avaliação por direção/turno**: tentativa de 2ª avaliação na mesma direção do mesmo turno é rejeitada (evidência: `AvaliacaoSchemaTest` + reenvio → 409 em `RegistrarAvaliacaoTest`).
- [ ] CHECK de estrelas 1–5 e CHECK autor≠avaliado existem no schema (tentativa fora-de-faixa / autor=avaliado falha — anexar saída do teste ou comando no Postgres).
- [ ] Avaliação é **imutável após persistida** (não há caminho de UPDATE/DELETE exposto; comentário em branco vira `null`).

## 3. Motor de XP/score/nível (STORY-085 — núcleo)

- [ ] Tabela de XP da spec aplicada por `avaliacao_recebida`: turno +30; 5★ +10; 4★ +3; 3★ 0; 1–2★ −5 (evidência: `MotorReputacaoTest`).
- [ ] Score = média das estrelas recebidas, exibido com **1 casa decimal** (evidência: `MotorReputacaoTest` + `PerfilReputacaoTest`).
- [ ] Nível sobe automaticamente ao cruzar **500 / 1000 / 3000** XP; **high-water-mark** — XP negativo não rebaixa (evidência: `NivelProfissionalTest` + `MotorReputacaoTest`).
- [ ] **Idempotência do motor**: reprocessar o mesmo evento `avaliacao_recebida` não soma XP em dobro (evidência: `MotorReputacaoTest`).
- [ ] **Cobertura de núcleo ≥ 98%** em `MotorReputacao` e `NivelProfissional` (a estória declara 100% — confirmar no relatório de cobertura do CI/`pest --coverage`).

## 4. Eventos de domínio + pendência derivada (STORY-085 / ADR-019 D2)

- [ ] `turno_finalizado` gera as **2 pendências** de avaliação (uma por direção) e notifica os 2 lados; **idempotente** (reprocessar não duplica) — evidência: `NotificarAvaliacaoPendenteTest`.
- [ ] Pendência é **derivada** (turno avaliável sem linha de avaliação na direção do papel) — não há tabela de pendência (ADR-019 D2). Confirmar que a mesma fonte alimenta gate, lista de turnos e perfil.
- [ ] Template de e-mail `avaliacao_pendente` carregado/seedado e renderiza no wiring de notificação (evidência: `NotificacoesEmailTemplatesSeederTest` / `NotificacaoTurnoEmailWiringTest`).

## 5. Gate bloqueante (STORY-086 / PDR-005 / ADR-019 D5)

- [ ] **Profissional** com avaliação pendente é **bloqueado ao candidatar-se**: resposta 422 `gate_avaliacao` com mensagem clara + `detalhe.turno_id` (turno mais antigo) — evidência: `GateAvaliacaoTest` (CA-1) + `CandidaturaTest`.
- [ ] **Contratante** com avaliação pendente é **bloqueado ao publicar nova vaga**: 422 `gate_avaliacao` + `turno_id`; editar/cancelar vaga **não** são bloqueados (gate é só sobre publicar nova — ADR-019 D5) — evidência: `GateAvaliacaoTest` (CA-2).
- [ ] **Sem pendência, as ações fluem** normalmente (sem regressão de candidatura/publicação da W26/W28) — evidência: `GateAvaliacaoTest` (CA-3) + suíte de regressão verde.
- [ ] **Fail-secure**: erro ao consultar pendência **não libera** a ação (bloqueia com `turno_id` null) — evidência: `GateAvaliacaoFailSecureTest`.
- [ ] **RBAC preservado** (ADR-007): profissional não vê/aciona endpoint de contratante e vice-versa; não há vazamento de pendência entre papéis/contratantes distintos.

## 6. Telas de avaliação recíproca (STORY-087)

- [ ] Tela **profissional→contratante**: estrelas obrigatórias (CTA desabilitado com 0 estrelas), comentário opcional, submete e trata sucesso/erro com retry (evidência: `avaliar_turno_screen_test` + E2E profissional).
- [ ] Tela **contratante→profissional**: idem, com copy "Como foi o trabalho de {1º nome}?" (evidência: `avaliar_turno_screen_test` + E2E contratante).
- [ ] Telas vivem **dentro do shell** (DDR-003), responsivas (mobile rodapé fixo / desktop card centrado), alcançáveis pelo CTA "Avaliar turno" do detalhe **sem digitar rota** e fiéis ao protótipo SCREEN-STORY-084.
- [ ] **Erro de envio recuperável**: banner "Tentar de novo" mantém estrelas+comentário; sucesso confirma (SnackBar), volta ao contexto e o CTA some pós-envio (reload reflete `pendente:false`).
- [ ] **RBAC fail-secure no front**: direção derivada do papel no servidor; 403/404 → "Este turno não é seu.".

## 7. Perfil: score/nível/XP/depoimentos (STORY-088 / DDR-004)

- [ ] Perfil do **profissional** mostra score (1 casa), nível + badge (Iniciante/Confiável/Destaque/Elite), XP atual e XP até o próximo nível, e depoimentos (até 3 mais recentes, mais recentes primeiro) — fiel ao protótipo.
- [ ] Perfil do **contratante** (acessível pelo profissional) mostra score + depoimentos (reciprocidade), **sem nível** (MVP).
- [ ] **Visibilidade DDR-004 / assimetria LGPD**: depoimento sobre o profissional é **nominal**; leitura de depoimento sobre o contratante é **anônima** (não trafega nome do profissional autor) — evidência: `PerfilReputacaoTest` (assimetria) + `perfil_reputacao_service_test`.
- [ ] XP visível **apenas para o dono** do perfil (visibilidade da spec niveis-e-score); demais campos públicos.
- [ ] Estados **vazio** (sem avaliações/depoimentos), **erro** (com retry) e **loading** (skeleton) padronizados pelo DS; selo "Novo" para < 3 avaliações.

## 8. UX do gate bloqueante (STORY-088)

- [ ] Ao ser bloqueado (candidatar/publicar), o usuário vê **mensagem clara + saída para o turno pendente** que abre a tela de avaliação no shell.
- [ ] Caminho **reativo** (tocar Candidatar/Publicar → 422 com `detalhe.turno_id`) deep-linka direto ao turno pendente; caminho **proativo** (banner no feed sem turno_id) leva ao branch Turnos.
- [ ] Pílula **"Avaliar"** no card de turno finalizado-sem-avaliação na lista (rc.101) deep-linka `/turnos/{id}/avaliar` (evidência: testes API `avaliacao_pendente` + widget da pílula).

## 9. Ciclo ponta a ponta em homologação — CA-2/CA-3 da STORY-089 (métrica primária do épico)

> **Este é o coração da validação.** Execute o ciclo completo em homologação operando como personas, com evidência (screenshots + timestamps + leitura de banco/endpoint — não Cloud Logging, conforme régua de homolog).

- [ ] **Turno finalizado → pendência dupla**: a partir de um turno `finalizado` (ou `finalizado_ajustado`) em homolog, ambos os lados veem a avaliação como pendente (marcador na lista + CTA no detalhe).
- [ ] **Avaliação dupla**: profissional avalia o contratante e contratante avalia o profissional (estrelas obrigatórias; comentário opcional) — ambas submissões aceitas (201), cada uma na sua direção.
- [ ] **XP/score/nível atualizam**: após as avaliações recebidas, o perfil do profissional reflete XP/score/nível recomputados; **subida de nível observável em ≤ 1s** na próxima carga do perfil (motor recompõe síncrono na transação; front não cacheia) — documentar com timestamps.
- [ ] **Score recíproco no perfil**: contratante e profissional veem score atualizado no perfil público após avaliação; depoimentos comentados aparecem (até 3 mais recentes).
- [ ] **Gate fecha o ciclo**: enquanto houver avaliação pendente, a próxima ação (nova candidatura / nova publicação) é **bloqueada com mensagem clara + link para o turno pendente**; após avaliar, a ação **destrava**.
- [ ] **Métrica primária**: 100% dos turnos finalizados exercitados nesta validação geram avaliação recíproca (documentar quantos turnos, quantas avaliações, resultado).

## 10. Cobertura de testes

- [ ] api ≥ 80% no código novo do épico; **≥ 98% no núcleo** (MotorReputacao, NivelProfissional) — evidência: relatório de cobertura do CI / `pest --coverage`.
- [ ] webapp ≥ 80%; regras críticas cobertas (obrigatoriedade de estrela, parsing do gate, visibilidade de depoimento).
- [ ] admin ≥ 80% (se tocado pelo épico; senão `n/a` justificado).
- [ ] Suíte completa verde no último build do branch principal (a estória 088 declara api 1078 / webapp 734 — confirmar no CI).

## 11. E2E (browser real)

- [ ] E2E `integration_test` (Chrome headless, **same-origin**, harness IDR-021) cobre, **por papel**: abrir a tela do turno pendente, submeter sem estrela (bloqueado), submeter com estrela (sucesso) — `avaliar_turno_test` (2 cenários).
- [ ] E2E cobre **perfil exibe score/nível/depoimentos** e **bloqueio ao candidatar/publicar leva ao turno pendente** — `reputacao_e_gate_test`.
- [ ] E2E roda 0-flake na execução de validação (rodar e anexar "All tests passed").
- [ ] Smoke HTTP pós-deploy verde no build deployado em homolog (régua de homolog — IDR-004).

## 12. Automação + deploy

- [ ] `make setup` continua funcionando em máquina limpa, 100% offline (sem regressão do princípio #6).
- [ ] Pipeline CI verde no branch principal nos deploys do épico.
- [ ] Deploy automático em homolog disparado por tag — release vigente ≥ rc.99 (jobs migrate+seed / deploy api/webapp/admin / smoke pós-deploy verdes). Produção permanece **gated por aprovação humana** (esperado — não é fail).

## 13. RBAC + segurança

- [ ] Só quem participou do turno avalia, na direção correta — não-participante → 403 (evidência: `RegistrarAvaliacaoTest`).
- [ ] Profissional A não vê/aciona avaliação de turno alheio; contratante X não vê turno de Y → 403/404.
- [ ] Scanner de segurança do CI (Trivy / gitleaks) limpo nos PRs do épico — sem aviso crítico introduzido.

## 14. LGPD + dados pessoais

- [ ] Assimetria de visibilidade de depoimentos respeitada (DDR-004) — leitura do contratante não vaza nome do profissional autor (cruza com item 7).
- [ ] Sem PII/dado sensível em mensagem de erro do gate ou em log (mensagens do gate são genéricas; ADR-019 / quality-standards).
- [ ] Migrações do épico testadas em homologação e reversíveis (cruza com item 2).

## 15. Documentação

- [ ] ADR-019 (modelo/eventos/gate) e DDR-004 (visibilidade de depoimentos) `accepted` no `index.json`.
- [ ] IDRs eventuais surgidos no épico (ex.: IDR-021 do harness E2E) indexados.
- [ ] "Notas do agente" preenchidas em cada estória 085–088.
- [ ] README/runbook atualizados onde o épico exigiu (se aplicável; senão `n/a` justificado).

## 16. Veredito

- [ ] **APROVADO** — todos os itens acima `pass` ou `n/a` justificado.
- [ ] **APROVADO COM PENDÊNCIAS** — 0 fails bloqueantes; fails não-bloqueantes documentados como `F-NB-N` para carry-forward; PO decide se aceita o veredito como goal-atingido.
- [ ] **REPROVADO** — pelo menos 1 `fail` bloqueante. Liste no relatório quais (classificados por `verdict-criteria.md`). PO abre estórias de correção; **NÃO** sugira correções, apenas registre o fato.

Preencha o relatório final em `report.md`.
