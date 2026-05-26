---
pdr_id: PDR-003
slug: duas-interfaces-webapp-e-backoffice
title: Duas interfaces — WebApp (Contratante + Profissional) e Backoffice (Admin) separados; backoffice mínimo viável na primeira onda
status: accepted
decided_at: 2026-05-26
decided_by: PO (Alexandro / Claude)
supersedes: null
superseded_by: null
related_epics: []
related_adrs: []
---

# PDR-003 — Duas interfaces (WebApp + Backoffice), backoffice mínimo viável na primeira onda

## Contexto

O protótipo navegável foi construído como um único SPA que serve os três papéis (admin, contratante, profissional) no mesmo bundle, diferenciando o que se vê pelo papel do usuário logado. Para o MVP real, faz sentido separar as preocupações: o público externo (contratantes e profissionais) usa um app pensado para uso mobile-first, contextual, com fluxo de match e turno; a equipe interna Turni opera um backoffice desktop-first focado em aprovação, mediação e métricas. Forçar as duas naturezas num mesmo app gera atrito de UX e mistura concerns de segurança e deploy.

A pergunta de produto não é "uma ou duas?" — é "as duas nascem juntas, ou o backoffice começa mínimo viável e cresce na segunda onda?".

## Opções consideradas

### Opção 1 — WebApp e Backoffice nascem juntos no Foundation
- Descrição: EPIC-000 entrega "hello world" em homologação para ambos, com pipelines independentes.
- Prós: Equipe interna ganha ferramenta desde o dia 1; aprovação de cadastros já em backoffice próprio.
- Contras: Duplica esforço de fundação; atrasa o primeiro épico de valor para o usuário externo; backoffice "completo" no MVP é overkill — equipe ainda é pequena, processo manual cabe.

### Opção 2 — WebApp primeiro; backoffice mínimo viável na primeira onda
- Descrição: Foundation entrega webapp em homologação. Backoffice nasce na primeira onda em versão mínima — só o que destrava operação: aprovação de cadastros e visualização de disputas. Outras funções administrativas (gestão de usuários completa, métricas avançadas, intervenção em turnos) ficam para a segunda onda.
- Prós: Foco no valor central (match + turno + pagamento); equipe Turni opera com ferramenta enxuta enquanto valida o produto; reduz risco de overengineering em ferramenta interna.
- Contras: Equipe Turni vive com UI provisória nas primeiras semanas; intervenções administrativas excepcionais (corrigir dado, cancelar turno em nome do contratante) podem exigir consulta direta ao banco.

### Opção 3 — Tudo em um app único com modos por papel
- Descrição: Manter o modelo do protótipo — um SPA, três papéis, route guard.
- Prós: Menor custo de fundação; familiar para quem viu o protótipo.
- Contras: Mistura segurança (admin junto com público); UX comprometida (mobile-first não serve backoffice; desktop-first não serve profissional na rua); deploy acoplado limita evolução independente; perde a hipótese estratégica de tratar o backoffice como ferramenta operacional dedicada.

## Decisão

> **Optamos pela Opção 2.**

Duas interfaces a partir do MVP:

- **WebApp** (mobile-first, PWA): atende Contratante e Profissional. Login decide qual visão é apresentada. Fluxos centrais — match, candidatura, aceite, check-in, turno, check-out, pagamento, avaliação.
- **Backoffice** (web, desktop-first): atende Admin Turni. Na **primeira onda**, mínimo viável: aprovação de cadastros (filas pendentes de contratante e profissional) e gestão de disputas de check-out. Outras funções administrativas chegam na **segunda onda**: gestão completa de usuários, intervenção excepcional em turnos, dashboards operacionais.

Auth e base de usuários são compartilhadas. O backoffice exige papel `admin` no usuário logado.

## Justificativa

A Opção 2 mantém o foco onde o valor central acontece (entre contratante e profissional) sem deixar a equipe Turni sem ferramenta operacional — só não sobrecarrega a primeira onda com escopo administrativo que pode ser desenvolvido em paralelo conforme a operação real revelar prioridades. Separar as interfaces no MVP, e não depois, evita débito de UX e deploy acoplado que seria caro reverter.

## Consequências

### Positivas
- Webapp mobile-first sem concessões para desktop administrativo.
- Backoffice desktop-first sem concessões para mobile externo.
- Deploy independente — uma interface pode evoluir sem arrastar a outra.
- Pipeline de segurança separado — superfície de ataque do admin não compartilha código do público.

### Negativas / trade-offs aceitos
- Foundation entrega dois deploys, duas URLs, dois pipelines — mais setup inicial.
- Sistema de auth precisa rotear pós-login por papel (admin → backoffice; contratante/profissional → webapp).
- Códigos comuns (design tokens, regras de domínio) precisam de estratégia para não duplicar — mas isso é decisão do Arquiteto, não do PO.
- Equipe Turni convive com backoffice mínimo viável nas primeiras semanas; intervenções excepcionais podem exigir acesso direto ao banco (autorização caso a caso pelo Arquiteto).

### Para o time técnico
- ADRs prováveis: estratégia de monorepo ou polirepo; estratégia de compartilhamento de código entre interfaces; estratégia de auth e roteamento pós-login; modelo de deploy independente.
- Impacto em épicos: EPIC-000 Foundation entrega ambos em homologação; primeiro épico de valor é webapp; primeiro épico do backoffice cobre aprovação + disputas (mínimo viável).

## Sinais de revisão

- Se o overhead de manter dois pipelines virar gargalo (mais de 10% do tempo da equipe gasto em manutenção de infra duplicada), reavaliar consolidação.
- Se a operação Turni precisar de funcionalidade administrativa séria antes da segunda onda (ex: volume de disputas crescer mais rápido que o esperado), acelerar o épico de backoffice completo.
- Se o backoffice mínimo viável bloquear aprovação dentro do SLA público (24h descumprido por limitação de ferramenta), reabrir prioridade.
