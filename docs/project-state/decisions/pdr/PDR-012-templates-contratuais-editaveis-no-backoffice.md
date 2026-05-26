---
pdr_id: PDR-012
slug: templates-contratuais-editaveis-no-backoffice
title: Templates de contrato eletrônico ficam editáveis pelo admin no backoffice; produto entrega texto-seed inicial
status: accepted
decided_at: 2026-05-26
decided_by: PO (Alexandro / Claude)
supersedes: null
superseded_by: null
related_epics: [EPIC-001, EPIC-005]
related_adrs: []
related_pdrs: [PDR-001, PDR-003, PDR-011]
---

# PDR-012 — Templates contratuais editáveis no backoffice

## Contexto

O Turni gera **aceite eletrônico** a cada turno aprovado (PDR-001 e `domain/compliance.md`), com cláusulas distintas por tipo de pessoa: **autônomo eventual** para PF; **B2B PJ↔PJ** para MEI/PJ. O conteúdo desses contratos é matéria jurídica que muda com legislação, jurisprudência e operação real — não é matéria de código.

No planejamento da WAVE-2026-01 (PDR-011), a primeira estória do EPIC-001 era "spike jurídico/contábil" com dependência externa (advogado + contador) para entregar templates antes do cadastro virar real. Essa abordagem cria três problemas:

1. **Bloqueio externo**: o calendário do advogado/contador trava o EPIC-001 inteiro se atrasar.
2. **Responsabilidade mal-alocada**: time de desenvolvimento mantém conteúdo jurídico (hardcoded em código ou em arquivo do repo) que deveria ser de domínio do operador da plataforma.
3. **Custo recorrente de mudança**: cada ajuste no contrato — por jurisprudência nova, exigência da Receita, ou aprendizado operacional — vira PR + deploy + release, em vez de uma edição direta no backoffice.

A alternativa proposta: o produto entrega **texto-seed inicial** dos dois templates (cobertura jurídica mínima razoável, escrita por nós com base em referências públicas), e o **backoffice ganha capability de edição** com versionamento. A equipe Turni, conforme contrate advogado externo, ajusta os textos no backoffice sem depender do time de desenvolvimento.

## Opções consideradas

### Opção 1 — Spike jurídico como dependência bloqueante do EPIC-001
- Descrição: status quo definido em PDR-011. Templates produzidos externamente antes do cadastro real.
- Prós: Texto definitivo desde o primeiro turno; menor risco jurídico no MVP.
- Contras: Bloqueio externo; responsabilidade do conteúdo presa ao dev; custo recorrente alto de revisão.

### Opção 2 — Templates editáveis no backoffice com texto-seed do produto
- Descrição: produto entrega texto-seed inicial; backoffice tem CRUD de templates com versionamento; admin pode editar a qualquer momento; cada aceite eletrônico anexa a versão vigente no momento da aprovação da candidatura.
- Prós: Desbloqueia EPIC-001 imediatamente; responsabilidade do conteúdo migra para o admin/equipe Turni; mudanças posteriores são edição no app, não release; versionamento preserva contratos antigos como assinados.
- Contras: Texto-seed inicial não é definitivo do ponto de vista jurídico — exige clareza para o admin de que ele é responsável por validar e ajustar com assessoria externa antes do primeiro turno real em produção; backoffice ganha capability nova no MVP que exige UI cuidadosa.

### Opção 3 — Hard-coded com migração depois
- Descrição: templates como string/arquivo no código durante MVP; migração para tabela editável em onda futura.
- Prós: Implementação mais simples imediata.
- Contras: Dívida garantida; quando a edição ficar necessária, exige refactoring + migração de dados; viola o princípio "responsabilidade do conteúdo migra para o admin".

## Decisão

> **Optamos pela Opção 2.**

Os templates de contrato eletrônico do Turni (PF autônomo eventual e B2B PJ↔PJ) são **entidades de dados editáveis pelo admin no backoffice**, com versionamento explícito. O produto entrega **texto-seed inicial** durante o EPIC-001 (escrito pelo PO com base em referências públicas e validado pelo Alexandro antes de subir em produção). A partir daí, a evolução do texto fica sob responsabilidade da equipe Turni — que pode contratar advogado externo a qualquer momento sem depender do time de desenvolvimento.

Cada **aceite eletrônico** gerado por um turno anexa a **versão específica** do template que estava vigente no momento da aprovação da candidatura. Mudanças futuras no template não afetam contratos passados.

O **spike jurídico/contábil** sai do caminho crítico da WAVE-2026-01. Vira validação posterior, executável fora de sprint formal — Alexandro pode contratar advogado e, quando vier o parecer, editar diretamente no backoffice.

## Justificativa

A Opção 2 resolve simultaneamente os três problemas da Opção 1: bloqueio externo, responsabilidade mal-alocada, custo recorrente. O custo extra (criar CRUD no backoffice e gerenciar versionamento) é trabalho que cai no MVP de qualquer forma — a alternativa seria criar o mesmo CRUD em onda futura com custo de migração somado.

Sobre o risco do texto-seed inicial não ser juridicamente definitivo: este é um risco **administrado** — não jurídico no sentido absoluto. O texto-seed cobre as cláusulas materiais (natureza eventual, ausência de exclusividade, autonomia, valor, escopo, timestamps, identificação das partes) com base em referências públicas. O Alexandro valida antes de produção. E a partir do primeiro turno real, qualquer ajuste é edição direta — não release. Isso reduz o tempo entre identificação de problema jurídico e correção de **semanas (release cycle)** para **minutos (edição no admin)**.

## Consequências

### Positivas
- EPIC-001 deixa de depender de calendário externo (advogado/contador).
- Responsabilidade do conteúdo migra para a equipe Turni; dev entrega ferramenta.
- Mudanças posteriores não exigem release.
- Versionamento garante validade dos contratos antigos.
- Quando advogado externo for contratado, integração é trivial — ele edita no app.

### Negativas / trade-offs aceitos
- Backoffice ganha capability no MVP que **expande o escopo do "backoffice mínimo viável"** definido em PDR-003 — passa de "fila de aprovação + visão de disputa" para "fila de aprovação + visão de disputa + editor de templates contratuais com versionamento". Não é supersede de PDR-003; é extensão registrada.
- Texto-seed inicial requer validação interna do Alexandro antes de produção (responsabilidade do PO + Alexandro).
- UI do editor precisa ser cuidadosa: o admin precisa entender que está editando documento juridicamente vinculante — confirmação dupla, preview, rollback fácil são bons defaults.
- Modelo de dados ganha entidades novas: `Template`, `TemplateVersao`. Aceite eletrônico do turno passa a referenciar `TemplateVersao` em vez de armazenar string.

### Para o time técnico
- **ADRs prováveis**:
  - Modelo de dados de Template + TemplateVersao (versionamento append-only).
  - Estratégia de renderização do template no momento do aceite (substituição de placeholders por dados do turno: nomes, valores, datas, IP, fingerprint).
  - UI de edição com preview no backoffice (cabe ao Designer em DDR).
- **Impacto em épicos**:
  - **EPIC-001** ganha estória nova: "Editor de templates contratuais no backoffice com texto-seed inicial e versionamento". O spike jurídico **sai** como dependência bloqueante.
  - **EPIC-005** sem impacto direto.
- **Modelo de dados afetado**: `Turno.aceite_eletronico` deixa de ser string e vira `{ template_versao_id, dados_renderizados, timestamp, ip, fingerprint }`.

## Sinais de revisão

- Se a equipe Turni nunca editar os templates após o seed inicial (passados 6+ meses sem edição), avaliar se a capability vale a complexidade — ou se hard-code teria sido suficiente.
- Se aparecerem mais de 3 tipos de contrato necessários (além de PF e MEI/PJ), considerar generalização (catálogo de templates por contexto).
- Se assessoria jurídica vier com recomendação de regras adicionais (campos obrigatórios novos, cláusulas condicionais), avaliar evolução do modelo de placeholders.
- Se houver vazamento de contrato (alguém forjar versão), avaliar elevação da segurança (assinatura digital, hash imutável na escrita).

## Relação com outros PDRs

- **Complementa PDR-003** (duas interfaces + backoffice mínimo viável): expande o escopo do backoffice mínimo viável da WAVE-2026-01.
- **Não supersede PDR-001** (PF/MEI/PJ aceitos): regra de tipos de pessoa continua igual; muda apenas a fonte e o ciclo de manutenção do contrato.
- **Ajusta o escopo definido em PDR-011** (escopo da WAVE-2026-01): o spike jurídico sai do EPIC-001 como bloqueante; o EPIC-001 ganha estória de editor de templates. Total de épicos da onda permanece igual.
